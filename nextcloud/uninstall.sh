#!/bin/bash

#===============================================================================
# Nextcloud AIO + NPM Kaldırma Script'i
# ⚠️  DİKKAT: Bu işlem geri alınamaz!
#===============================================================================

set -e

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Banner
clear
echo -e "${RED}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║     ⚠️   NEXTCLOUD AIO KALDIRMA SCRİPT'İ   ⚠️                ║"
echo "║                                                              ║"
echo "║           BU İŞLEM GERİ ALINAMAZ!                            ║"
echo "║                                                              ║"
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
        echo "Kullanım: sudo ./uninstall.sh"
        exit 1
    fi
}

#===============================================================================
# Dinamik Doğrulama
#===============================================================================

dynamic_verification() {
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}                    GÜVENLİK DOĞRULAMASI                        ${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Rastgele doğrulama tipi seç
    VERIFY_TYPE=$((RANDOM % 3))
    
    case $VERIFY_TYPE in
        0)
            # Matematik sorusu
            NUM1=$((RANDOM % 20 + 10))
            NUM2=$((RANDOM % 20 + 10))
            ANSWER=$((NUM1 + NUM2))
            
            echo -e "${CYAN}🔢 Matematik Doğrulaması${NC}"
            echo ""
            echo -e "   Şu soruyu cevaplayın: ${MAGENTA}${NUM1} + ${NUM2} = ?${NC}"
            echo ""
            read -p "   Cevabınız: " USER_ANSWER
            
            if [[ "$USER_ANSWER" != "$ANSWER" ]]; then
                echo ""
                log_error "Yanlış cevap! Kaldırma iptal edildi."
                exit 1
            fi
            ;;
        1)
            # Rastgele kelime
            WORDS=("KALDIR" "SİL" "ONAYLA" "DEVAM" "TAMAM" "EVET" "SIFIRLA" "TEMİZLE")
            RANDOM_WORD=${WORDS[$((RANDOM % ${#WORDS[@]}))]}
            
            echo -e "${CYAN}📝 Kelime Doğrulaması${NC}"
            echo ""
            echo -e "   Devam etmek için şu kelimeyi yazın: ${MAGENTA}${RANDOM_WORD}${NC}"
            echo ""
            read -p "   Yazın: " USER_WORD
            
            if [[ "$USER_WORD" != "$RANDOM_WORD" ]]; then
                echo ""
                log_error "Kelime eşleşmedi! Kaldırma iptal edildi."
                exit 1
            fi
            ;;
        2)
            # Rastgele kod
            RANDOM_CODE=$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 6 | head -n 1)
            
            echo -e "${CYAN}🔐 Kod Doğrulaması${NC}"
            echo ""
            echo -e "   Devam etmek için şu kodu girin: ${MAGENTA}${RANDOM_CODE}${NC}"
            echo ""
            read -p "   Kod: " USER_CODE
            
            if [[ "$USER_CODE" != "$RANDOM_CODE" ]]; then
                echo ""
                log_error "Kod eşleşmedi! Kaldırma iptal edildi."
                exit 1
            fi
            ;;
    esac
    
    echo ""
    log_success "Doğrulama başarılı!"
    echo ""
}

#===============================================================================
# Ne Silinecek Göster
#===============================================================================

show_what_will_be_deleted() {
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}                    SİLİNECEK ÖĞELER                            ${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  🐳 Docker Containers:"
    echo "     - nextcloud-aio-mastercontainer"
    echo "     - nextcloud-aio-* (tüm AIO konteynerleri)"
    echo "     - nginx-proxy-manager (kurulduysa)"
    echo ""
    echo "  📦 Docker Volumes:"
    echo "     - nextcloud_aio_mastercontainer"
    echo "     - nextcloud_aio_* (tüm AIO volume'ları)"
    echo "     - npm_data, npm_letsencrypt (NPM kurulduysa)"
    echo ""
    echo "  🌐 Docker Networks:"
    echo "     - nextcloud-aio (AIO network)"
    echo "     - proxy_network"
    echo ""
    echo "  📁 Dosyalar:"
    echo "     - .env (yapılandırma dosyası)"
    echo ""
    echo -e "  ${CYAN}💾 VERİLER İÇİN:${NC}"
    echo -e "  ${CYAN}   Mount edilen verileri silmek isteyip istemediğiniz sorulacak${NC}"
    echo ""
}

#===============================================================================
# Son Onay
#===============================================================================

final_confirmation() {
    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}                      SON UYARI!                                ${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${RED}Bu işlem:${NC}"
    echo -e "  - Nextcloud AIO'yu tamamen kaldıracak"
    echo -e "  - Nginx Proxy Manager'ı kaldıracak"
    echo -e "  - SSL sertifikalarını silecek"
    echo -e "  - Veritabanını silecek (PostgreSQL)"
    echo -e "  - Redis cache'i silecek"
    echo ""
    echo -e "  ${GREEN}Korunacak:${NC}"
    echo -e "  - /mnt/ncdata içindeki dosyalar (TrueNAS)"
    echo -e "  - Docker kurulumu"
    echo ""
    
    read -p "Devam etmek istediğinizden EMİN MİSİNİZ? (evet/hayır): " FINAL_ANSWER
    
    if [[ "$FINAL_ANSWER" != "evet" ]]; then
        echo ""
        log_warn "Kaldırma iptal edildi."
        exit 0
    fi
}

#===============================================================================
# Kaldırma İşlemleri
#===============================================================================

stop_containers() {
    log_info "Konteynerler durduruluyor..."
    
    # Tüm profilleri durdur
    cd "$SCRIPT_DIR"
    docker compose --profile npm down 2>/dev/null || true
    docker compose down 2>/dev/null || true
    
    log_success "Compose servisleri durduruldu"
}

remove_aio_containers() {
    log_info "AIO konteynerleri kaldırılıyor..."
    
    # Tüm AIO konteynerlerini bul ve sil
    AIO_CONTAINERS=$(docker ps -a --filter "name=nextcloud-aio" --format "{{.Names}}" 2>/dev/null || true)
    
    if [[ -n "$AIO_CONTAINERS" ]]; then
        echo "$AIO_CONTAINERS" | while read container; do
            log_info "  Siliniyor: $container"
            docker rm -f "$container" 2>/dev/null || true
        done
    fi
    
    # NPM container
    docker rm -f nginx-proxy-manager 2>/dev/null || true
    
    log_success "Konteynerler kaldırıldı"
}

remove_volumes() {
    log_info "Docker volume'ları kaldırılıyor..."
    
    # AIO volume'ları
    AIO_VOLUMES=$(docker volume ls --filter "name=nextcloud_aio" --format "{{.Name}}" 2>/dev/null || true)
    
    if [[ -n "$AIO_VOLUMES" ]]; then
        echo "$AIO_VOLUMES" | while read volume; do
            log_info "  Siliniyor: $volume"
            docker volume rm "$volume" 2>/dev/null || true
        done
    fi
    
    # NPM volume'ları
    docker volume rm npm_data 2>/dev/null || true
    docker volume rm npm_letsencrypt 2>/dev/null || true
    
    log_success "Volume'lar kaldırıldı"
}

remove_networks() {
    log_info "Docker network'leri kaldırılıyor..."
    
    # Ortak proxy network
    docker network rm proxy_network 2>/dev/null || true
    
    # AIO network
    docker network rm nextcloud-aio 2>/dev/null || true
    
    log_success "Network'ler kaldırıldı"
}

remove_images() {
    log_info "Docker image'ları kaldırılsın mı?"
    read -p "Image'ları da silmek istiyor musunuz? (e/h): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Ee]$ ]]; then
        log_info "Image'lar kaldırılıyor..."
        
        # AIO images
        docker images --filter "reference=nextcloud/*" --format "{{.Repository}}:{{.Tag}}" | while read image; do
            log_info "  Siliniyor: $image"
            docker rmi "$image" 2>/dev/null || true
        done
        
        # NPM image
        docker rmi jc21/nginx-proxy-manager:latest 2>/dev/null || true
        
        # Prune
        docker image prune -f 2>/dev/null || true
        
        log_success "Image'lar kaldırıldı"
    else
        log_warn "Image'lar korundu"
    fi
}

cleanup_files() {
    log_info "Yapılandırma dosyaları temizleniyor..."
    
    cd "$SCRIPT_DIR"
    
    # .env dosyası
    if [[ -f .env ]]; then
        rm -f .env
        log_info "  .env silindi"
    fi
    
    # Log dosyaları
    rm -f scan.log 2>/dev/null || true
    rm -f *.log 2>/dev/null || true
    
    log_success "Dosyalar temizlendi"
}

unmount_nfs() {
    log_info "NFS mount kontrol ediliyor..."
    
    if mount | grep -q "/mnt/ncdata"; then
        # Önce veri silme seçeneğini sor
        echo ""
        echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${RED}                    ⚠️  VERİ SİLME SEÇENEĞİ  ⚠️                    ${NC}"
        echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        # Mevcut veri boyutunu göster
        if [[ -d /mnt/ncdata ]]; then
            DATA_SIZE=$(du -sh /mnt/ncdata 2>/dev/null | awk '{print $1}' || echo "bilinmiyor")
            DATA_FILES=$(find /mnt/ncdata -type f 2>/dev/null | wc -l || echo "bilinmiyor")
            echo -e "  ${CYAN}Mount konumu:${NC} /mnt/ncdata"
            echo -e "  ${CYAN}Toplam boyut:${NC} ${DATA_SIZE}"
            echo -e "  ${CYAN}Dosya sayısı:${NC} ${DATA_FILES}"
            echo ""
        fi
        
        echo -e "  ${RED}DİKKAT: Bu işlem tüm Nextcloud verilerinizi silecek!${NC}"
        echo -e "  ${RED}        Kullanıcı dosyaları, fotoğraflar, dokümanlar...${NC}"
        echo -e "  ${RED}        BU İŞLEM GERİ ALINAMAZ!${NC}"
        echo ""
        
        read -p "Mount edilen verileri de silmek istiyor musunuz? (e/h): " -n 1 -r DELETE_DATA
        echo
        
        if [[ $DELETE_DATA =~ ^[Ee]$ ]]; then
            echo ""
            echo -e "${RED}Son onay gerekli!${NC}"
            echo -e "Tüm verileri silmek için '${MAGENTA}TÜM VERİLERİ SİL${NC}' yazın:"
            read -p "> " CONFIRM_DELETE
            
            if [[ "$CONFIRM_DELETE" == "TÜM VERİLERİ SİL" ]]; then
                log_warn "Veriler siliniyor (NFS üzerinden)..."
                
                # ÖNCE mount'lu iken sil (NFS üzerindeki dosyalar silinir)
                rm -rf /mnt/ncdata/* 2>/dev/null || true
                rm -rf /mnt/ncdata/.* 2>/dev/null || true
                
                log_success "Veriler silindi"
                DATA_DELETED=true
            else
                log_warn "Yanlış giriş - veriler KORUNDU"
                DATA_DELETED=false
            fi
        else
            log_info "Veriler korunacak"
            DATA_DELETED=false
        fi
        
        # NFS mount'ı kaldır
        echo ""
        read -p "NFS mount'ı kaldırılsın mı? (fstab'dan çıkarılır) (e/h): " -n 1 -r UNMOUNT_NFS
        echo
        
        if [[ $UNMOUNT_NFS =~ ^[Ee]$ ]]; then
            umount /mnt/ncdata 2>/dev/null || true
            
            # fstab'dan kaldır
            sed -i '/\/mnt\/ncdata/d' /etc/fstab 2>/dev/null || true
            
            log_success "NFS mount kaldırıldı"
        else
            log_warn "NFS mount korundu"
        fi
    else
        log_info "Aktif NFS mount bulunamadı"
        
        # Yine de /mnt/ncdata dizini varsa silmeyi sor
        if [[ -d /mnt/ncdata ]] && [[ -n "$(ls -A /mnt/ncdata 2>/dev/null)" ]]; then
            echo ""
            DATA_SIZE=$(du -sh /mnt/ncdata 2>/dev/null | awk '{print $1}' || echo "bilinmiyor")
            echo -e "${YELLOW}/mnt/ncdata dizininde veri bulundu (${DATA_SIZE})${NC}"
            read -p "Bu verileri silmek istiyor musunuz? (e/h): " -n 1 -r DELETE_LOCAL
            echo
            
            if [[ $DELETE_LOCAL =~ ^[Ee]$ ]]; then
                echo -e "Silmek için '${MAGENTA}SİL${NC}' yazın:"
                read -p "> " CONFIRM_LOCAL
                
                if [[ "$CONFIRM_LOCAL" == "SİL" ]]; then
                    rm -rf /mnt/ncdata/* 2>/dev/null || true
                    log_success "Yerel veriler silindi"
                    DATA_DELETED=true
                else
                    log_warn "Veriler korundu"
                fi
            fi
        fi
    fi
}

#===============================================================================
# Özet
#===============================================================================

print_summary() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                   KALDIRMA TAMAMLANDI!                        ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Kaldırılan öğeler:"
    echo "  ✅ Nextcloud AIO konteynerleri"
    echo "  ✅ Nginx Proxy Manager (kuruluysa)"
    echo "  ✅ Docker volume'ları"
    echo "  ✅ Docker network'leri"
    echo "  ✅ Yapılandırma dosyaları"
    echo ""
    
    if [[ "$DATA_DELETED" == "true" ]]; then
        echo -e "${RED}Silinen veriler:${NC}"
        echo "  🗑️  /mnt/ncdata içeriği"
        echo ""
    else
        echo -e "${YELLOW}Korunan öğeler:${NC}"
        echo "  📁 /mnt/ncdata verileri"
    fi
    
    echo "  🐳 Docker kurulumu"
    echo ""
    echo -e "${BLUE}Yeniden kurmak için:${NC}"
    echo "  ./setup.sh"
    echo ""
}

#===============================================================================
# Ana Program
#===============================================================================

main() {
    DATA_DELETED=false
    
    check_root
    show_what_will_be_deleted
    dynamic_verification
    final_confirmation
    
    echo ""
    log_info "Kaldırma işlemi başlıyor..."
    echo ""
    
    stop_containers
    remove_aio_containers
    remove_volumes
    remove_networks
    remove_images
    cleanup_files
    unmount_nfs
    
    print_summary
}

# Script'i başlat
main "$@"
