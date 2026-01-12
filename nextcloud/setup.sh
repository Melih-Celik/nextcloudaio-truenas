#!/bin/bash

#===============================================================================
# Nextcloud AIO + Nginx Proxy Manager Kurulum Script'i
# AlmaLinux 10 için - TrueNAS NFS mount ile çalışır
#===============================================================================

set -e

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         Nextcloud AIO + NPM Kurulum Script'i                 ║"
echo "║           AlmaLinux 10 - TrueNAS NFS Entegrasyonu           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

#===============================================================================
# Fonksiyonlar
#===============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[UYARI]${NC} $1"
}

log_error() {
    echo -e "${RED}[HATA]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Bu script root olarak çalıştırılmalı!"
        echo "Kullanım: sudo ./setup.sh"
        exit 1
    fi
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        log_info "İşletim sistemi: $PRETTY_NAME"
    else
        log_error "Desteklenmeyen işletim sistemi!"
        exit 1
    fi

    # AlmaLinux, Rocky, CentOS, RHEL kontrolü
    if [[ "$OS" != "almalinux" && "$OS" != "rocky" && "$OS" != "centos" && "$OS" != "rhel" ]]; then
        log_warn "Bu script AlmaLinux/Rocky/RHEL için optimize edilmiştir."
        log_warn "Tespit edilen OS: $OS"
        read -p "Devam etmek istiyor musunuz? (e/h): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ee]$ ]]; then
            exit 1
        fi
    fi
}

#===============================================================================
# Kullanıcı Girdileri
#===============================================================================

get_user_input() {
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}                    YAPILANDIRMA BİLGİLERİ                      ${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # NPM kurulacak mı?
    echo -e "${CYAN}Nginx Proxy Manager (NPM) SSL/reverse proxy için kullanılır.${NC}"
    echo -e "${CYAN}Zaten bir reverse proxy varsa (Traefik, Caddy vb.) kurmayın.${NC}"
    read -p "NPM kurulsun mu? (e/h) [e]: " -n 1 -r INSTALL_NPM
    echo
    INSTALL_NPM=${INSTALL_NPM:-e}
    
    echo ""

    # Domain
    while true; do
        read -p "Nextcloud domain adı (örn: cloud.sirket.com): " DOMAIN
        if [[ -n "$DOMAIN" ]]; then
            break
        fi
        log_error "Domain adı boş olamaz!"
    done

    # TrueNAS NFS IP
    while true; do
        read -p "TrueNAS IP adresi (örn: 192.168.1.100): " NFS_SERVER
        if [[ $NFS_SERVER =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        fi
        log_error "Geçerli bir IP adresi girin!"
    done

    # NFS Path
    read -p "TrueNAS NFS path [/mnt/storage/nextcloud/data]: " NFS_PATH
    NFS_PATH=${NFS_PATH:-/mnt/storage/nextcloud/data}

    # Email
    while true; do
        read -p "Email adresi (SSL sertifikası için): " EMAIL
        if [[ "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        fi
        log_error "Geçerli bir email adresi girin!"
    done

    # Timezone
    read -p "Timezone [Europe/Istanbul]: " TIMEZONE
    TIMEZONE=${TIMEZONE:-Europe/Istanbul}

    # Özet
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                         ÖZET                                   ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  Domain:        $DOMAIN"
    echo "  TrueNAS IP:    $NFS_SERVER"
    echo "  NFS Path:      $NFS_PATH"
    echo "  Email:         $EMAIL"
    echo "  Timezone:      $TIMEZONE"
    if [[ $INSTALL_NPM =~ ^[Ee]$ ]]; then
        echo "  NPM:           ✅ Kurulacak"
    else
        echo "  NPM:           ❌ Kurulmayacak"
    fi
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    read -p "Bu ayarlarla devam edilsin mi? (e/h): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ee]$ ]]; then
        log_warn "Kurulum iptal edildi."
        exit 0
    fi
}

#===============================================================================
# Sistem Güncelleme
#===============================================================================

update_system() {
    log_info "Sistem güncelleniyor..."
    dnf update -y
    log_success "Sistem güncellendi"
}

#===============================================================================
# Gerekli Paketler
#===============================================================================

install_dependencies() {
    log_info "Gerekli paketler kuruluyor..."
    dnf install -y \
        curl \
        wget \
        git \
        nfs-utils \
        ca-certificates \
        gnupg2 \
        screen \
        htop \
        tar \
        dnf-plugins-core
    log_success "Paketler kuruldu"
}

#===============================================================================
# SELinux Ayarları
#===============================================================================

configure_selinux() {
    log_info "SELinux ayarları yapılıyor..."
    
    # SELinux durumunu kontrol et
    if command -v getenforce &> /dev/null; then
        SELINUX_STATUS=$(getenforce)
        log_info "SELinux durumu: $SELINUX_STATUS"
        
        if [[ "$SELINUX_STATUS" == "Enforcing" ]]; then
            # NFS için SELinux boolean ayarları
            setsebool -P container_use_nfs on 2>/dev/null || true
            setsebool -P virt_use_nfs on 2>/dev/null || true
            
            # Container için SELinux ayarları
            setsebool -P container_manage_cgroup on 2>/dev/null || true
            
            log_success "SELinux boolean ayarları yapıldı"
        fi
    fi
}

#===============================================================================
# Firewall Ayarları
#===============================================================================

configure_firewall() {
    log_info "Firewall ayarları yapılıyor..."
    
    if systemctl is-active --quiet firewalld; then
        # HTTP/HTTPS
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        
        # NPM Admin
        firewall-cmd --permanent --add-port=81/tcp
        
        # AIO Interface
        firewall-cmd --permanent --add-port=8080/tcp
        firewall-cmd --permanent --add-port=8443/tcp
        
        # Nextcloud Apache (internal)
        firewall-cmd --permanent --add-port=11000/tcp
        
        # NFS client
        firewall-cmd --permanent --add-service=nfs
        
        # Reload
        firewall-cmd --reload
        
        log_success "Firewall kuralları eklendi"
    else
        log_warn "firewalld çalışmıyor, firewall ayarları atlandı"
    fi
}

#===============================================================================
# Docker Kurulumu
#===============================================================================

install_docker() {
    if command -v docker &> /dev/null; then
        log_warn "Docker zaten kurulu"
        docker --version
        return
    fi

    log_info "Docker kuruluyor..."

    # Eski versiyonları kaldır
    dnf remove -y docker \
        docker-client \
        docker-client-latest \
        docker-common \
        docker-latest \
        docker-latest-logrotate \
        docker-logrotate \
        docker-engine \
        podman \
        runc 2>/dev/null || true

    # Docker repo ekle (CentOS repo AlmaLinux için çalışır)
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

    # Docker kurulum
    dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Docker servisini başlat
    systemctl enable docker
    systemctl start docker

    log_success "Docker kuruldu"
    docker --version
}

#===============================================================================
# NFS Mount
#===============================================================================

setup_nfs_mount() {
    log_info "NFS mount ayarlanıyor..."

    # Mount noktası oluştur
    mkdir -p /mnt/ncdata

    # NFS servisleri
    systemctl enable nfs-client.target
    systemctl start nfs-client.target

    # Önce test et
    log_info "NFS bağlantısı test ediliyor..."
    if ! showmount -e "$NFS_SERVER" &> /dev/null; then
        log_error "TrueNAS NFS sunucusuna ulaşılamıyor: $NFS_SERVER"
        log_error "TrueNAS'ta NFS servisinin çalıştığından emin olun."
        exit 1
    fi

    # Mount et
    log_info "NFS mount ediliyor..."
    mount -t nfs -o vers=4,noatime "$NFS_SERVER:$NFS_PATH" /mnt/ncdata

    # Yazma testi
    if touch /mnt/ncdata/.write_test 2>/dev/null; then
        rm /mnt/ncdata/.write_test
        log_success "NFS yazma testi başarılı"
    else
        log_error "NFS yazma hatası! TrueNAS izinlerini kontrol edin."
        exit 1
    fi

    # fstab'a ekle (kalıcı mount)
    if ! grep -q "$NFS_SERVER:$NFS_PATH" /etc/fstab; then
        echo "$NFS_SERVER:$NFS_PATH /mnt/ncdata nfs vers=4,noatime,_netdev 0 0" >> /etc/fstab
        log_success "fstab'a eklendi (kalıcı mount)"
    else
        log_warn "fstab girişi zaten mevcut"
    fi

    log_success "NFS mount tamamlandı"
}

#===============================================================================
# Environment Dosyası Oluştur
#===============================================================================

create_env_file() {
    log_info ".env dosyası oluşturuluyor..."

    cat > .env << EOF
# Nextcloud AIO Yapılandırma
# Oluşturulma: $(date)
# OS: AlmaLinux 10

# Domain ayarları
DOMAIN=${DOMAIN}
EMAIL=${EMAIL}

# TrueNAS NFS
NFS_SERVER=${NFS_SERVER}
NFS_PATH=${NFS_PATH}

# Nextcloud ayarları
NEXTCLOUD_DATADIR=/mnt/ncdata
NEXTCLOUD_MOUNT=/mnt/
NEXTCLOUD_MEMORY_LIMIT=2048M
NEXTCLOUD_UPLOAD_LIMIT=16G
NEXTCLOUD_MAX_TIME=3600

# Timezone
TZ=${TIMEZONE}

# Apache port (reverse proxy için)
APACHE_PORT=11000
APACHE_IP_BINDING=0.0.0.0
EOF

    log_success ".env dosyası oluşturuldu"
}

#===============================================================================
# Nginx Proxy Manager Başlat
#===============================================================================

start_npm() {
    if [[ ! $INSTALL_NPM =~ ^[Ee]$ ]]; then
        log_info "NPM kurulumu atlanıyor..."
        return
    fi

    log_info "Nginx Proxy Manager başlatılıyor..."

    # NPM'i profile ile başlat
    docker compose --profile npm up -d nginx-proxy-manager

    # Network'ün oluştuğunu doğrula
    if docker network ls | grep -q "proxy_network"; then
        log_success "proxy_network oluşturuldu"
    fi

    log_success "NPM başlatıldı"
    echo ""
    echo -e "${GREEN}NPM Admin Panel: http://$(hostname -I | awk '{print $1}'):81${NC}"
    echo -e "${YELLOW}İlk giriş: admin@example.com / changeme${NC}"
    echo ""
}

#===============================================================================
# Nextcloud AIO Başlat
#===============================================================================

start_nextcloud_aio() {
    log_info "Nextcloud AIO başlatılıyor..."

    # .env dosyasını yükle
    source .env

    # AIO'yu başlat (NPM dahilse profile ile)
    if [[ $INSTALL_NPM =~ ^[Ee]$ ]]; then
        docker compose --profile npm up -d
    else
        docker compose up -d
    fi

    log_success "Nextcloud AIO başlatıldı"
    echo ""
    echo -e "${GREEN}AIO Panel: https://$(hostname -I | awk '{print $1}'):8080${NC}"
    echo -e "${YELLOW}Tarayıcıda sertifika uyarısını kabul edin (self-signed)${NC}"
    echo ""
}

#===============================================================================
# Kurulum Sonrası Bilgiler
#===============================================================================

print_post_install() {
    IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    KURULUM TAMAMLANDI!                        ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}SONRAKİ ADIMLAR:${NC}"
    echo ""
    echo "1. ${YELLOW}AIO Paneline git:${NC} https://${IP}:8080"
    echo "   - Sertifika uyarısını kabul et"
    echo "   - Domain gir: ${DOMAIN}"
    echo "   - Opsiyonel konteynerler:"
    echo "     ✅ Collabora"
    echo "     ✅ Imaginary"
    echo "     ❌ ClamAV"
    echo "     ❌ OnlyOffice"
    echo "   - 'Start containers' tıkla"
    echo ""
    
    if [[ $INSTALL_NPM =~ ^[Ee]$ ]]; then
        echo "2. ${YELLOW}NPM Paneline git:${NC} http://${IP}:81"
        echo "   - Giriş: admin@example.com / changeme"
        echo "   - Şifreyi değiştir"
        echo "   - Proxy Host ekle:"
        echo "     Domain: ${DOMAIN}"
        echo "     Forward: localhost:11000"
        echo "     SSL: Let's Encrypt"
        echo ""
        echo "3. ${YELLOW}DNS ayarı:${NC}"
    else
        echo "2. ${YELLOW}Reverse Proxy ayarı:${NC}"
        echo "   - Mevcut proxy'nizi ${IP}:11000 adresine yönlendirin"
        echo "   - SSL sertifikası ayarlayın"
        echo ""
        echo "3. ${YELLOW}DNS ayarı:${NC}"
    fi
    echo "   ${DOMAIN} -> ${IP} (A kaydı)"
    echo ""
    echo "4. ${YELLOW}Optimizasyonları uygula:${NC}"
    echo "   ./optimize.sh"
    echo ""
    echo "5. ${YELLOW}Data taşındıktan sonra:${NC}"
    echo "   ./scan.sh"
    echo ""
    echo -e "${RED}Sistemi kaldırmak için:${NC}"
    echo "   ./uninstall.sh"
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

#===============================================================================
# Ana Program
#===============================================================================

main() {
    check_root
    check_os
    get_user_input
    update_system
    install_dependencies
    configure_selinux
    configure_firewall
    install_docker
    setup_nfs_mount
    create_env_file
    start_npm
    
    # NPM kurulduysa bekle
    if [[ $INSTALL_NPM =~ ^[Ee]$ ]]; then
        log_info "NPM başlatılıyor, 10 saniye bekleniyor..."
        sleep 10
    fi
    
    start_nextcloud_aio
    
    # AIO'nun başlaması için bekle
    log_info "AIO başlatılıyor, 15 saniye bekleniyor..."
    sleep 15
    
    print_post_install
}

# Script'i başlat
main "$@"
