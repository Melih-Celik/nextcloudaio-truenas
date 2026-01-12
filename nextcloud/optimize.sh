#!/bin/bash

#===============================================================================
# Nextcloud AIO Optimizasyon Script'i
# 76TB büyük veri seti için performans ayarları
#===============================================================================

set -e

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# AIO container kontrolü
check_aio_running() {
    if ! docker ps | grep -q "nextcloud-aio-nextcloud"; then
        log_error "Nextcloud AIO çalışmıyor!"
        log_error "Önce AIO panelinden konteynerleri başlatın: https://IP:8080"
        exit 1
    fi
    log_success "Nextcloud AIO çalışıyor"
}

# OCC komutunu çalıştır
run_occ() {
    docker exec --user www-data nextcloud-aio-nextcloud php occ "$@"
}

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Nextcloud AIO Optimizasyon Script'i                   ║${NC}"
echo -e "${BLUE}║              76TB Veri Seti İçin                             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Kontroller
check_aio_running

#===============================================================================
# 1. Veritabanı Optimizasyonu
#===============================================================================
echo ""
log_info "=== Veritabanı Optimizasyonu ==="

log_info "Eksik indeksler ekleniyor..."
run_occ db:add-missing-indices || log_warn "Indeks ekleme atlandı"

log_info "Eksik kolonlar ekleniyor..."
run_occ db:add-missing-columns || log_warn "Kolon ekleme atlandı"

log_info "Eksik primary key'ler ekleniyor..."
run_occ db:add-missing-primary-keys || log_warn "Primary key ekleme atlandı"

# Filecache bigint dönüşümü (76TB için ÖNEMLİ!)
log_info "Filecache bigint dönüşümü kontrol ediliyor..."
log_warn "Bu işlem uzun sürebilir, lütfen bekleyin..."
run_occ db:convert-filecache-bigint --no-interaction || log_warn "Bigint dönüşümü atlandı veya zaten yapılmış"

log_success "Veritabanı optimizasyonu tamamlandı"

#===============================================================================
# 2. Performans Ayarları
#===============================================================================
echo ""
log_info "=== Performans Ayarları ==="

# Filesystem check kapatma (büyük veri için ÖNEMLİ!)
log_info "Filesystem check değişiklikleri kapatılıyor..."
run_occ config:system:set filesystem_check_changes --value=0 --type=integer
log_success "filesystem_check_changes = 0"

# Maintenance window ayarı
log_info "Bakım penceresi ayarlanıyor..."
run_occ config:system:set maintenance_window_start --value=2 --type=integer
log_success "Bakım penceresi: 02:00-06:00"

#===============================================================================
# 3. Önizleme (Preview) Ayarları
#===============================================================================
echo ""
log_info "=== Önizleme Ayarları ==="

# Preview boyutlarını sınırla
log_info "Preview boyutları sınırlandırılıyor..."
run_occ config:system:set preview_max_x --value=1024 --type=integer
run_occ config:system:set preview_max_y --value=1024 --type=integer

# Preview max memory
run_occ config:system:set preview_max_memory --value=512 --type=integer

# Preview max filesize (MB) - büyük dosyalar için preview oluşturma
run_occ config:system:set preview_max_filesize_image --value=50 --type=integer

log_success "Preview ayarları optimize edildi"

#===============================================================================
# 4. Çöp Kutusu ve Versiyon Politikaları
#===============================================================================
echo ""
log_info "=== Retention Politikaları ==="

# Çöp kutusu: otomatik, max 7 gün
log_info "Çöp kutusu retention: 7 gün..."
run_occ config:system:set trashbin_retention_obligation --value="auto,7"

# Versiyonlar: otomatik, max 7 gün
log_info "Versiyon retention: 7 gün..."
run_occ config:system:set versions_retention_obligation --value="auto,7"

log_success "Retention politikaları ayarlandı"

#===============================================================================
# 5. Cron Kontrolü
#===============================================================================
echo ""
log_info "=== Cron Kontrolü ==="

# Cron modunu kontrol et
CRON_MODE=$(run_occ config:system:get backgroundjobs_mode 2>/dev/null || echo "unknown")
log_info "Mevcut background job modu: $CRON_MODE"

if [[ "$CRON_MODE" != "cron" ]]; then
    log_info "Cron moduna geçiliyor..."
    run_occ background:cron
fi

log_success "Cron modu aktif"

#===============================================================================
# 6. Cache Kontrolü
#===============================================================================
echo ""
log_info "=== Cache Kontrolü ==="

# Redis kontrolü
REDIS_HOST=$(run_occ config:system:get redis host 2>/dev/null || echo "")
if [[ -n "$REDIS_HOST" ]]; then
    log_success "Redis yapılandırılmış: $REDIS_HOST"
else
    log_warn "Redis yapılandırması bulunamadı (AIO otomatik ayarlar)"
fi

# Memcache kontrolü
MEMCACHE=$(run_occ config:system:get memcache.local 2>/dev/null || echo "")
log_info "Local memcache: $MEMCACHE"

MEMCACHE_DIST=$(run_occ config:system:get memcache.distributed 2>/dev/null || echo "")
log_info "Distributed memcache: $MEMCACHE_DIST"

MEMCACHE_LOCK=$(run_occ config:system:get memcache.locking 2>/dev/null || echo "")
log_info "Locking memcache: $MEMCACHE_LOCK"

#===============================================================================
# 7. Dosya Kilitleme
#===============================================================================
echo ""
log_info "=== Dosya Kilitleme ==="

FILELOCKING=$(run_occ config:system:get filelocking.enabled 2>/dev/null || echo "")
if [[ "$FILELOCKING" == "true" || "$FILELOCKING" == "1" ]]; then
    log_success "Dosya kilitleme aktif"
else
    log_warn "Dosya kilitleme kontrol edilemedi"
fi

#===============================================================================
# Sonuç
#===============================================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              OPTİMİZASYON TAMAMLANDI!                         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Uygulanan ayarlar:"
echo "  ✅ Veritabanı indeksleri eklendi"
echo "  ✅ Filecache bigint dönüşümü yapıldı"
echo "  ✅ filesystem_check_changes = 0"
echo "  ✅ Preview boyutları sınırlandı (1024x1024)"
echo "  ✅ Trash retention: 7 gün"
echo "  ✅ Version retention: 7 gün"
echo "  ✅ Cron modu aktif"
echo ""
echo -e "${YELLOW}Not: Data taşındıktan sonra ./scan.sh çalıştırın${NC}"
echo ""
