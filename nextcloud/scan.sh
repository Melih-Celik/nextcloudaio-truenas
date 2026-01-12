#!/bin/bash

#===============================================================================
# Nextcloud Dosya Tarama Script'i
# 76TB veri seti için optimize edilmiş
# Screen ile arka planda çalışır, log dosyasına yazar
#===============================================================================

set -e

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/scan.log"
SCREEN_NAME="nextcloud-scan"

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

# OCC komutunu çalıştır
run_occ() {
    docker exec --user www-data nextcloud-aio-nextcloud php occ "$@"
}

# AIO container kontrolü
check_aio_running() {
    if ! docker ps | grep -q "nextcloud-aio-nextcloud"; then
        log_error "Nextcloud AIO çalışmıyor!"
        exit 1
    fi
}

# Kullanım bilgisi
usage() {
    echo ""
    echo "Kullanım: $0 [seçenek]"
    echo ""
    echo "Seçenekler:"
    echo "  start       Taramayı arka planda başlat"
    echo "  status      Tarama durumunu göster"
    echo "  log         Canlı log takibi"
    echo "  stop        Taramayı durdur"
    echo "  user USER   Belirli bir kullanıcıyı tara"
    echo "  help        Bu yardımı göster"
    echo ""
    echo "Örnekler:"
    echo "  $0 start          # Tüm kullanıcıları tara"
    echo "  $0 user admin     # Sadece admin kullanıcısını tara"
    echo "  $0 log            # Tarama logunu takip et"
    echo ""
}

# Ana tarama fonksiyonu (screen içinde çalışacak)
do_scan() {
    echo "========================================" >> "$LOG_FILE"
    echo "Tarama başladı: $(date)" >> "$LOG_FILE"
    echo "========================================" >> "$LOG_FILE"
    
    # Activity app kapat (performans için)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Activity app kapatılıyor..." >> "$LOG_FILE"
    docker exec --user www-data nextcloud-aio-nextcloud php occ app:disable activity 2>> "$LOG_FILE" || true
    
    # Temizlik
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Dosya cache temizleniyor..." >> "$LOG_FILE"
    docker exec --user www-data nextcloud-aio-nextcloud php occ files:cleanup 2>> "$LOG_FILE" || true
    
    # Ana tarama
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Dosya taraması başlıyor (tüm kullanıcılar)..." >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Bu işlem 76TB için GÜNLER sürebilir!" >> "$LOG_FILE"
    
    docker exec --user www-data nextcloud-aio-nextcloud php occ files:scan --all -v >> "$LOG_FILE" 2>&1
    SCAN_RESULT=$?
    
    # Activity app aç
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Activity app açılıyor..." >> "$LOG_FILE"
    docker exec --user www-data nextcloud-aio-nextcloud php occ app:enable activity 2>> "$LOG_FILE" || true
    
    echo "========================================" >> "$LOG_FILE"
    if [ $SCAN_RESULT -eq 0 ]; then
        echo "Tarama BAŞARIYLA tamamlandı: $(date)" >> "$LOG_FILE"
    else
        echo "Tarama HATAYLA sonlandı (kod: $SCAN_RESULT): $(date)" >> "$LOG_FILE"
    fi
    echo "========================================" >> "$LOG_FILE"
}

# Kullanıcı tarama fonksiyonu
do_user_scan() {
    local USER=$1
    echo "========================================" >> "$LOG_FILE"
    echo "Kullanıcı taraması başladı: $USER - $(date)" >> "$LOG_FILE"
    echo "========================================" >> "$LOG_FILE"
    
    docker exec --user www-data nextcloud-aio-nextcloud php occ files:scan "$USER" -v >> "$LOG_FILE" 2>&1
    
    echo "Kullanıcı taraması tamamlandı: $USER - $(date)" >> "$LOG_FILE"
}

# Screen başlat
start_scan() {
    check_aio_running
    
    if screen -list | grep -q "$SCREEN_NAME"; then
        log_warn "Tarama zaten çalışıyor!"
        log_info "Durumu görmek için: $0 status"
        log_info "Logu takip için: $0 log"
        exit 1
    fi
    
    log_info "Tarama arka planda başlatılıyor..."
    
    # Log dosyası başlat
    echo "" > "$LOG_FILE"
    
    # Screen'de başlat
    screen -dmS "$SCREEN_NAME" bash -c "$(declare -f do_scan); LOG_FILE='$LOG_FILE'; do_scan"
    
    sleep 2
    
    if screen -list | grep -q "$SCREEN_NAME"; then
        log_success "Tarama başlatıldı!"
        echo ""
        echo "Log dosyası: $LOG_FILE"
        echo ""
        echo "Komutlar:"
        echo "  $0 log      - Canlı log takibi"
        echo "  $0 status   - Durum kontrolü"
        echo "  $0 stop     - Taramayı durdur"
        echo ""
        log_warn "76TB için tarama GÜNLER sürebilir!"
    else
        log_error "Tarama başlatılamadı!"
        exit 1
    fi
}

# Kullanıcı tarama başlat
start_user_scan() {
    local USER=$1
    check_aio_running
    
    if [ -z "$USER" ]; then
        log_error "Kullanıcı adı belirtilmedi!"
        usage
        exit 1
    fi
    
    log_info "Kullanıcı taraması başlatılıyor: $USER"
    
    # Foreground'da çalıştır (tek kullanıcı daha hızlı)
    do_user_scan "$USER"
    
    log_success "Kullanıcı taraması tamamlandı: $USER"
}

# Durum kontrolü
check_status() {
    if screen -list | grep -q "$SCREEN_NAME"; then
        log_success "Tarama çalışıyor"
        echo ""
        echo "Son 10 satır log:"
        echo "─────────────────────────────────────"
        tail -10 "$LOG_FILE" 2>/dev/null || echo "(Log henüz oluşmadı)"
        echo "─────────────────────────────────────"
        echo ""
        echo "Canlı takip için: $0 log"
    else
        log_info "Tarama çalışmıyor"
        if [ -f "$LOG_FILE" ]; then
            echo ""
            echo "Son tarama sonucu:"
            echo "─────────────────────────────────────"
            tail -20 "$LOG_FILE"
            echo "─────────────────────────────────────"
        fi
    fi
}

# Log takibi
follow_log() {
    if [ ! -f "$LOG_FILE" ]; then
        log_error "Log dosyası bulunamadı: $LOG_FILE"
        exit 1
    fi
    
    log_info "Log takibi başlatılıyor (Çıkmak için Ctrl+C)..."
    echo ""
    tail -f "$LOG_FILE"
}

# Taramayı durdur
stop_scan() {
    if screen -list | grep -q "$SCREEN_NAME"; then
        log_warn "Tarama durduruluyor..."
        screen -S "$SCREEN_NAME" -X quit
        
        # Activity app'i aç
        docker exec --user www-data nextcloud-aio-nextcloud php occ app:enable activity 2>/dev/null || true
        
        log_success "Tarama durduruldu"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Tarama manuel olarak durduruldu" >> "$LOG_FILE"
    else
        log_info "Çalışan tarama yok"
    fi
}

#===============================================================================
# Ana Program
#===============================================================================

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Nextcloud Dosya Tarama Script'i                    ║${NC}"
echo -e "${BLUE}║                 76TB Optimize                                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

case "${1:-start}" in
    start)
        start_scan
        ;;
    status)
        check_status
        ;;
    log)
        follow_log
        ;;
    stop)
        stop_scan
        ;;
    user)
        start_user_scan "$2"
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        log_error "Bilinmeyen komut: $1"
        usage
        exit 1
        ;;
esac
