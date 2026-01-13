# TrueNAS + Nextcloud AIO Kurulum

## VM Gereksinimleri

### TrueNAS VM (100TB için)
| Özellik | Değer | Açıklama |
|---------|-------|----------|
| CPU | 4-6 vCPU | ZFS ve NFS için |
| RAM | 32GB | ZFS: 1GB per 1TB data (16GB min + ZIL için 16GB) |
| OS Disk | 32GB | Boot pool |
| Data Disk | 10x12TB HDD | 120TB raw = ~96TB kullanılabilir (Stripe) |
| SLOG (opsiyonel) | 2x 32GB SSD | NFS yazma performansı (mirror) |

> 💡 **RAM Hesabı:** 100TB × 0.15GB = 15GB (min) + 16GB (sistem/ZIL) = 32GB

### Nextcloud VM (100TB için)
| Özellik | Değer | Açıklama |
|---------|-------|----------|
| CPU | 6-8 vCPU | Dosya tarama ve önizleme işlemleri için |
| RAM | 16GB | Docker + PostgreSQL + Redis + Nextcloud |
| Disk | 150GB | OS (50GB) + Docker (30GB) + DB (70GB) |
| OS | AlmaLinux 10 | |

> 💡 **DB Boyutu:** 100TB Nextcloud taraması = ~50-70GB PostgreSQL veritabanı
> - Her dosya: ~2KB metadata
> - 50 milyon dosya ≈ 100GB DB
> - Tahmini ortalama: 2MB/dosya → 50M dosya → 50-70GB DB

---

## Kurulum (3 Adım)

### 1. TrueNAS Hazırlığı

```bash
# Dataset oluştur
zfs create storage/nextcloud
zfs create storage/nextcloud/data

# İzinleri ayarla (www-data = uid 33)
chown -R 33:33 /mnt/storage/nextcloud/data
chmod 770 /mnt/storage/nextcloud/data
```

**NFS Share:** `/mnt/storage/nextcloud/data` → Nextcloud VM IP'sine izin ver

---

### 2. Nextcloud VM Kurulumu

```bash
git clone https://github.com/melihi/nextcloudaio-truenas.git
cd nextcloudaio-truenas/nextcloud
chmod +x *.sh
./setup.sh
```

Script soracak:
- Domain (cloud.sirket.com)
- TrueNAS IP
- NFS path (`/mnt/storage/nextcloud/data`)
- Email

---

### 3. AIO Panel Ayarları

1. `https://VM_IP:8080` → Sertifika uyarısını kabul et
2. Domain gir
3. Container seç:
   - ✅ Collabora
   - ✅ Imaginary  
   - ❌ ClamAV
4. **Start containers** → Tamamlanana kadar BEKLE

---

## Kurulum Sonrası

```bash
# 76TB optimizasyonları
./optimize.sh

# Veri taşıma sonrası tarama
./scan.sh
```

---

## Kaldırma

```bash
./uninstall.sh
```

---

## Belgeler

- [TrueNAS Kurulum Detayları](truenas/README.md)
- [LDAP + Veri Taşıma Rehberi](docs/ldap-veri-tasima.md)

---

## Sorun Giderme

| Sorun | Çözüm |
|-------|-------|
| NFS mount hatası | `showmount -e TRUENAS_IP` ile kontrol et |
| Container restart döngüsü | `docker logs CONTAINER_ADI` kontrol et |
| Permission denied | TrueNAS'ta `chown 33:33` kontrol et |
