# TrueNAS + Nextcloud AIO Kurulum

## VM Gereksinimleri

### TrueNAS VM
| Özellik | Değer |
|---------|-------|
| CPU | 4 vCPU |
| RAM | 16GB (ZFS için) |
| OS Disk | 32GB |
| Data Disk | İhtiyaca göre (RAID-Z2) |

### Nextcloud VM
| Özellik | Değer |
|---------|-------|
| CPU | 4 vCPU |
| RAM | 8GB |
| Disk | 50GB |
| OS | AlmaLinux 10 |

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
- [Windows'tan Veri Taşıma](docs/windows-veri-tasima.md)

---

## Sorun Giderme

| Sorun | Çözüm |
|-------|-------|
| NFS mount hatası | `showmount -e TRUENAS_IP` ile kontrol et |
| Container restart döngüsü | `docker logs CONTAINER_ADI` kontrol et |
| Permission denied | TrueNAS'ta `chown 33:33` kontrol et |
