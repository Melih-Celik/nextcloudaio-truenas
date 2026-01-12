#!/bin/bash

#===============================================================================
# Nextcloud Dosya Tarama Script'i
# 76TB veri seti için optimize edilmiş
# nohup ile arka planda çalışır, log dosyasına yazar
#===============================================================================

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/scan.log"
PID_FILE="${SCRIPT_DIR}/scan.pid"

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
        log_error "Önce AIO panelinden konteynerleri başlatın."
        exit 1
    fi
    log_success "Nextcloud AIO çalışıyor"
}

# Kullanım bilgisi
usage() {
    echo ""
    echo "Kullanım: $0 [seçenek]"
    echo ""
    echo "Seçenekler:"
    echo "  start       Taramayı arka planda başlat"
    echo "  foreground  Taramayı ön planda başlat (test için)"
    echo "  status      Tarama durumunu göster"
    echo "  log         Canlı log takibi"
    echo "  stop        Taramayı durdur"
    echo "  user USER   Belirli bir kullanıcıyı tara"
    echo "  help        Bu yardımı göster"
    echo ""
    echo "Örnekler:"
    echo "  $0 start          # Tüm kullanıcıları tara (arka plan)"
    echo "  $0 foreground     # Tüm kullanıcıları tara (ön plan)"
    echo "  $0 user admin     # Sadece admin kullanıcısını tara"
    echo "  $0 log            # Tarama logunu takip et"
    echo ""
}

# Ana tarama fonksiyonu
do_scan() {
    echo "========================================" >> "$LOG_FILE"
    echo "Tarama başladı: $(date)" >> "$LOG_FILE"
    echo "PID: $$" >> "$LOG_FILE"
    echo "========================================" >> "$LOG_FILE"
    
    # Activity app kapat (performans için)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Activity app kapatılıyor..." >> "$LOG_FILE"
    docker exec --user www-data nextcloud-aio-nextcloud php occ app:disable activity >> "$LOG_FILE" 2>&1 || true
    
    # Temizlik
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Dosya cache temizleniyor..." >> "$LOG_FILE"
    docker exec --user www-data nextcloud-aio-nextcloud php occ files:cleanup >> "$LOG_FILE" 2>&1 || true
    
    # Ana tarama
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Dosya taraması başlıyor (tüm kullanıcılar)..." >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Bu işlem 76TB için GÜNLER sürebilir!" >> "$LOG_FILE"
    
    docker exec --user www-data nextcloud-aio-nextcloud php occ files:scan --all -v >> "$LOG_FILE" 2>&1
    SCAN_RESULT=$?
    
    # Activity app aç
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Activity app açılıyor..." >> "$LOG_FILE"
    docker exec --user www-data nextcloud-aio-nextcloud php occ app:enable activity >> "$LOG_FILE" 2>&1 || true
    
    echo "========================================" >> "$LOG_FILE"
    if [ $SCAN_RESULT -eq 0 ]; then
        echo "Tarama BAŞARIYLA tamamlandı: $(date)" >> "$LOG_FILE"
    else
        echo "Tarama HATAYLA sonlandı (kod: $SCAN_RESULT): $(date)" >> "$LOG_FILE"
    fi
    echo "========================================" >> "$LOG_FILE"
    
    # PID dosyasını temizle
    rm -f "$PID_FILE"
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

# Tarama çalışıyor mu kontrol
is_running() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            return 0
        else
            # PID dosyası var ama process yok, temizle
            rm -f "$PID_FILE"
        fi
    fi
    return 1
}

# Arka planda başlat
start_scan() {
    check_aio_running
    
    if is_running; then
        log_warn "Tarama zaten çalışıyor! (PID: $(cat "$PID_FILE"))"
        log_info "Durumu görmek için: $0 status"
        log_info "Logu takip için: $0 log"
        exit 1
    fi
    
    log_info "Tarama arka planda başlatılıyor..."
    
    # Log dosyası başlat
    echo "" > "$LOG_FILE"
    
    # nohup ile arka planda başlat
    nohup bash -c "$(declare -f do_scan); LOG_FILE='$LOG_FILE'; PID_FILE='$PID_FILE'; do_scan" > /dev/null 2>&1 &
    
    # PID'i kaydet
    echo $! > "$PID_FILE"
    
    sleep 2
    
    if is_running; then
        log_success "Tarama başlatıldı! (PID: $(cat "$PID_FILE"))"
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
        cat "$LOG_FILE" 2>/dev/null
        exit 1
    fi
}

# Ön planda başlat (test için)
start_foreground() {
    check_aio_running
    
    if is_running; then
        log_warn "Arka planda tarama zaten çalışıyor! (PID: $(cat "$PID_FILE"))"
        exit 1
    fi
    
    log_info "Tarama ön planda başlatılıyor..."
    log_warn "Çıkmak için Ctrl+C (tarama yarıda kalır)"
    echo ""
    
    # Log dosyası başlat
    echo "" > "$LOG_FILE"
    
    # Ön planda çalıştır
    LOG_FILE="$LOG_FILE" PID_FILE="$PID_FILE" do_scan
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
    
    # Log dosyası başlat
    echo "" > "$LOG_FILE"
    
    # Foreground'da çalıştır (tek kullanıcı daha hızlı)
    do_user_scan "$USER"
    
    log_success "Kullanıcı taraması tamamlandı: $USER"
}

# Durum kontrolü
check_status() {
    if is_running; then
        PID=$(cat "$PID_FILE")
        log_success "Tarama çalışıyor (PID: $PID)"
        
        # Process bilgisi
        echo ""
        echo "Process bilgisi:"
        ps -p "$PID" -o pid,etime,cmd --no-headers 2>/dev/null || echo "  (bilgi alınamadı)"
        
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
        log_info "Önce taramayı başlatın: $0 start"
        exit 1
    fi
    
    log_info "Log takibi başlatılıyor (Çıkmak için Ctrl+C)..."
    echo ""
    tail -f "$LOG_FILE"
}

# Taramayı durdur
stop_scan() {
    if is_running; then
        PID=$(cat "$PID_FILE")
        log_warn "Tarama durduruluyor (PID: $PID)..."
        
        # Process'i ve child process'leri durdur
        pkill -P "$PID" 2>/dev/null || true
        kill "$PID" 2>/dev/null || true
        
        sleep 2
        
        # Hala çalışıyorsa zorla durdur
        if ps -p "$PID" > /dev/null 2>&1; then
            kill -9 "$PID" 2>/dev/null || true
        fi
        
        rm -f "$PID_FILE"
        
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
    foreground|fg)
        start_foreground
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
