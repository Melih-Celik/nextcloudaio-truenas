# TrueNAS + Nextcloud AIO Kurulum Rehberi

Bu repo, TrueNAS VM üzerinde depolama ve ayrı bir VM'de Nextcloud AIO + Nginx Proxy Manager kurulumu için gerekli tüm dosyaları içerir.

## 🏗️ Mimari

```
┌─────────────────────────────────────────────────────────────┐
│                        İnternet                              │
└──────────────────────────┬──────────────────────────────────┘
                           │ Port 443 (HTTPS)
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              Nextcloud VM (AlmaLinux 10)                     │
│  ┌─────────────────────────────────────────────────────┐    │
│  │         Nginx Proxy Manager (Docker)                 │    │
│  │         - SSL Termination (Let's Encrypt)            │    │
│  │         - Port 80, 443, 81 (admin)                   │    │
│  └──────────────────────────┬──────────────────────────┘    │
│                             │ Port 11000                     │
│  ┌──────────────────────────▼──────────────────────────┐    │
│  │         Nextcloud AIO (Docker)                       │    │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────┐          │    │
│  │  │ Nextcloud │ │ PostgreSQL│ │   Redis   │          │    │
│  │  └───────────┘ └───────────┘ └───────────┘          │    │
│  │  ┌───────────┐ ┌───────────┐                        │    │
│  │  │ Collabora │ │ Imaginary │                        │    │
│  │  └───────────┘ └───────────┘                        │    │
│  └─────────────────────────────────────────────────────┘    │
│                             │                                │
│                    /mnt/ncdata (NFS mount)                   │
└──────────────────────────┬──────────────────────────────────┘
                           │ NFS
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                     TrueNAS VM                               │
│           ┌────────────────────────────────┐                 │
│           │    ZFS Pool (RAID-Z2)          │                 │
│           │    - compression=lz4           │                 │
│           │    - atime=off                 │                 │
│           │    - /mnt/tank/nextcloud/data  │                 │
│           └────────────────────────────────┘                 │
└─────────────────────────────────────────────────────────────┘
```

## 📋 Kurulum Sırası

### 1️⃣ TrueNAS VM Kurulumu
TrueNAS VM'i kurun ve yapılandırın. Detaylı rehber için:
- 📖 [truenas/README.md](truenas/README.md)

**Özet:**
- TrueNAS SCALE kurulumu
- ZFS pool oluşturma (RAID-Z2 önerilir)
- Dataset oluşturma: `tank/nextcloud/data`
- NFS share yapılandırma

### 2️⃣ Nextcloud VM Kurulumu
Nextcloud VM'de otomatik kurulum script'ini çalıştırın:

```bash
# Repo'yu klonla
git clone https://github.com/KULLANICI/nextcloudaio-truenas.git
cd nextcloudaio-truenas/nextcloud

# Kurulum script'ini çalıştır
chmod +x *.sh
./setup.sh

# Kaldırmak için (opsiyonel)
./uninstall.sh
```

Script sizden şu bilgileri isteyecek:
- **Domain adı** (örn: cloud.sirketiniz.com)
- **TrueNAS NFS IP** (örn: 192.168.1.100)
- **NFS path** (örn: /mnt/tank/nextcloud/data)
- **Email** (Let's Encrypt için)
- **Timezone** (örn: Europe/Istanbul)

### 3️⃣ AIO Web Paneli Yapılandırma
Kurulum tamamlandıktan sonra:

1. **AIO paneline git:** `https://SUNUCU_IP:8080`
2. Tarayıcı sertifika uyarısını kabul et (self-signed)
3. Domain adını gir
4. **Opsiyonel konteynerler** bölümünden seç:
   - ✅ Collabora (Office düzenleme)
   - ✅ Imaginary (Gelişmiş önizlemeler)
   - ❌ ClamAV (Antivirus - kapalı)
   - ❌ Fulltextsearch (Kapalı)
   - ❌ Talk (Gerekirse aç)
5. **Start containers** butonuna tıkla

### 4️⃣ Nginx Proxy Manager Yapılandırma
NPM admin paneline git: `http://SUNUCU_IP:81`

**İlk giriş:**
- Email: `admin@example.com`
- Şifre: `changeme`

**Proxy Host oluştur:**
1. **Hosts → Proxy Hosts → Add Proxy Host**
2. Domain: `cloud.sirketiniz.com`
3. Scheme: `http`
4. Forward Hostname: `localhost`
5. Forward Port: `11000`
6. ✅ Websockets Support
7. ✅ Block Common Exploits
8. **SSL sekmesi:**
   - Request a new SSL Certificate
   - ✅ Force SSL
   - ✅ HTTP/2 Support
   - Email gir, Let's Encrypt şartlarını kabul et

### 5️⃣ Optimizasyonları Uygula
AIO tamamen başladıktan sonra (tüm konteynerler yeşil):

```bash
cd nextcloud
chmod +x optimize.sh
./optimize.sh
```

### 6️⃣ Data Taşıma ve Scan
Müşteri 76TB veriyi TrueNAS'a taşıdıktan sonra:

```bash
cd nextcloud
chmod +x scan.sh
./scan.sh
```

> ⚠️ **Not:** 76TB için tarama işlemi **günler** sürebilir. Script arka planda çalışır ve ilerlemeyi `scan.log` dosyasına yazar.

## 📁 Repo Yapısı

```
nextcloudaio-truenas/
├── README.md                    # Bu dosya
├── truenas/
│   └── README.md               # TrueNAS kurulum rehberi
└── nextcloud/
    ├── setup.sh                # Ana interaktif kurulum script'i
    ├── uninstall.sh            # Kaldırma script'i
    ├── docker-compose.npm.yml  # Nginx Proxy Manager
    ├── docker-compose.yml      # Nextcloud AIO
    ├── .env.example            # Environment değişkenleri şablonu
    ├── optimize.sh             # Post-install optimizasyonlar
    └── scan.sh                 # Data taşıma sonrası scan
```

## 🔧 Sorun Giderme

### NFS mount hatası
```bash
# Mount'u kontrol et
mount | grep ncdata

# Manuel mount dene
sudo mount -t nfs TRUENAS_IP:/mnt/tank/nextcloud/data /mnt/ncdata -v
```

### AIO konteynerları başlamıyor
```bash
# Logları kontrol et
docker logs nextcloud-aio-mastercontainer

# Docker network kontrol
docker network ls
```

### Collabora çalışmıyor
TrueNAS'ta Docker dataset'inde `exec=on` olmalı:
```bash
# TrueNAS shell'de
zfs set exec=on tank/docker
```

### Scan uzun sürüyor
76TB için normal. İlerlemeyi takip et:
```bash
tail -f scan.log
```

## 📞 Destek

Sorun yaşarsanız:
1. İlgili README dosyasını tekrar okuyun
2. Docker loglarını kontrol edin
3. TrueNAS NFS erişimini test edin

---

**Son güncelleme:** Ocak 2026
