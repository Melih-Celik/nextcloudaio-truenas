# TrueNAS SCALE Kurulum Rehberi

Bu rehber, Nextcloud AIO için TrueNAS SCALE VM kurulumunu adım adım açıklar.

## 📋 Gereksinimler

- **TrueNAS SCALE** 24.04+ (DragonFish veya sonrası)
- **RAM:** Minimum 8GB (16GB+ önerilir, ZFS için)
- **Boot disk:** 32GB+ SSD
- **Data diskleri:** 76TB için yeterli disk (örn: 8x12TB)
- **Network:** Statik IP önerilir

## 🚀 Kurulum Adımları

### 1. TrueNAS SCALE İndirme ve Kurulum

1. [TrueNAS SCALE](https://www.truenas.com/download-truenas-scale/) indirin
2. ISO'yu boot USB'ye yazın (Rufus, balenaEtcher vb.)
3. VM'e boot edin ve kurulumu tamamlayın
4. Admin şifresini ayarlayın
5. Web UI'a erişin: `http://TRUENAS_IP`

### 2. ZFS Pool Oluşturma

**Storage → Create Pool**

#### Önerilen Yapılandırma (76TB için)

| Disk Sayısı | RAID Tipi | Kullanılabilir Alan | Koruma |
|-------------|-----------|---------------------|--------|
| 8x 12TB | RAID-Z2 | ~65TB | 2 disk kaybı |
| 10x 10TB | RAID-Z2 | ~72TB | 2 disk kaybı |
| 12x 8TB | RAID-Z3 | ~65TB | 3 disk kaybı |

**Adımlar:**
1. **Storage** → **Create Pool**
2. Pool adı: `tank`
3. Diskleri seçin
4. Layout: **RAID-Z2** (önerilir)
5. **Create** tıklayın

### 3. Pool Optimizasyonu (Shell)

TrueNAS web UI → **System Settings** → **Shell**

```bash
# Compression aktif et (varsayılan ama kontrol et)
zfs set compression=lz4 tank

# Access time kapatarak performans artır
zfs set atime=off tank

# Extended attributes için optimize et
zfs set xattr=sa tank
zfs set acltype=posixacl tank
```

### 4. Nextcloud Dataset Oluşturma

**Datasets** → **Add Dataset**

```
Name: nextcloud
Parent: tank
```

Sonra içine bir tane daha:
```
Name: data
Parent: tank/nextcloud
```

Veya Shell'den:
```bash
zfs create tank/nextcloud
zfs create tank/nextcloud/data
```

### 5. Dataset İzinlerini Ayarlama

Nextcloud www-data kullanıcısı uid=33 kullanır.

**Shell'de:**
```bash
# Nextcloud data klasörü için izinler
chown -R 33:33 /mnt/tank/nextcloud/data
chmod -R 770 /mnt/tank/nextcloud/data
```

### 6. NFS Share Oluşturma

**Shares** → **NFS** → **Add**

| Ayar | Değer |
|------|-------|
| Path | `/mnt/tank/nextcloud/data` |
| Maproot User | `root` |
| Maproot Group | `wheel` |
| Enabled | ✅ |

**Advanced Options:**
- **Hosts** veya **Networks:** Nextcloud VM'in IP/subnet'i (örn: `192.168.1.0/24`)

#### Veya Shell'den:
```bash
# NFS servisini aktif et
midclt call service.start nfs

# Paylaşımı oluştur (UI'dan yapmak daha kolay)
```

### 7. NFS Servisini Aktif Et

**System Settings** → **Services**

- **NFS:** ✅ Running, ✅ Start Automatically

### 8. Firewall/Network Kontrol

NFS için gerekli portlar:
- **111** (TCP/UDP) - rpcbind
- **2049** (TCP/UDP) - NFS
- **Mountd** - dinamik port (veya sabit port ayarla)

**Test (Nextcloud VM'den):**
```bash
# Showmount ile kontrol
showmount -e TRUENAS_IP

# Beklenen çıktı:
# Export list for TRUENAS_IP:
# /mnt/tank/nextcloud/data 192.168.1.0/24
```

## 📊 76TB Optimizasyon Ayarları

### Büyük Dosyalar İçin Recordsize

Eğer çoğunlukla büyük dosyalar (video, backup vb.) depolanacaksa:

```bash
# Büyük dosyalar için recordsize artır (varsayılan 128K)
zfs set recordsize=1M tank/nextcloud/data
```

### ZFS ARC Cache

TrueNAS varsayılan olarak RAM'in çoğunu ARC için kullanır. 16GB+ RAM önerilir.

**System Settings** → **Advanced** → **Sysctl**

Varsayılanlar genelde yeterli, değiştirmeyin.

### Scrub Zamanlaması

TrueNAS otomatik scrub zamanlar ama kontrol edin:

**Data Protection** → **Scrub Tasks**

- Aylık scrub önerilir (76TB için 24-48 saat sürebilir)

## 🔍 Doğrulama Checklist

- [ ] TrueNAS web UI erişilebilir
- [ ] ZFS pool oluşturuldu ve sağlıklı
- [ ] `tank/nextcloud/data` dataset mevcut
- [ ] İzinler uid=33 için ayarlandı
- [ ] NFS share aktif
- [ ] NFS servisi çalışıyor
- [ ] Nextcloud VM'den `showmount -e` çalışıyor
- [ ] Nextcloud VM'den test mount başarılı

## 🧪 Test Mount (Nextcloud VM'den)

```bash
# NFS utils kur (AlmaLinux)
sudo dnf install nfs-utils -y

# Test mount
sudo mkdir -p /mnt/ncdata
sudo mount -t nfs TRUENAS_IP:/mnt/tank/nextcloud/data /mnt/ncdata

# Yazma testi
sudo touch /mnt/ncdata/test.txt
ls -la /mnt/ncdata/

# Temizle
sudo rm /mnt/ncdata/test.txt
sudo umount /mnt/ncdata
```

Test başarılıysa, Nextcloud kurulumuna geçebilirsiniz.

## 🔧 Sorun Giderme

### "Permission denied" hatası
```bash
# TrueNAS'ta izinleri kontrol et
ls -la /mnt/tank/nextcloud/
# uid=33 olmalı

# NFS export ayarlarını kontrol et
cat /etc/exports
```

### "Connection refused" hatası
```bash
# NFS servisi çalışıyor mu?
midclt call service.query | grep nfs

# Servisi yeniden başlat
midclt call service.restart nfs
```

### Mount çok yavaş
- Network bağlantısını kontrol et
- MTU ayarlarını kontrol et (jumbo frame kullanılıyorsa)
- NFS version'ı kontrol et (NFSv4 önerilir)

```bash
# NFSv4 ile mount
sudo mount -t nfs -o vers=4 TRUENAS_IP:/mnt/tank/nextcloud/data /mnt/ncdata
```

---

**Sonraki adım:** [Nextcloud VM kurulumu](../README.md#2️⃣-nextcloud-vm-kurulumu)
