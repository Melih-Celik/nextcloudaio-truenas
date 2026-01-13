# TrueNAS Kurulum Rehberi

## ZFS Pool Oluşturma

**Storage → Create Pool**

### Data VDev (Ana Depolama)

| Disk | Layout | Kullanılabilir |
|------|--------|----------------|
| 8x12TB | Stripe (RAID0) | ~96TB |
| 10x12TB | Stripe (RAID0) | ~120TB |
| 12x10TB | Stripe (RAID0) | ~120TB |

> ⚠️ **RAID kullanılmıyor** - Backup stratejisi önemli!

### Opsiyonel VDev'ler (Performans için)

#### 🔵 Log (SLOG) - Yazma Performansı
**Ne İşe Yarar:** Senkron yazma işlemlerini hızlandırır (NFS, iSCSI)  
**Tavsiye:** 2x 32GB SSD (mirror)  
**Zorunlu mu?** Hayır, ancak NFS için önerilir

#### 🟢 Cache (L2ARC) - Okuma Performansı
**Ne İşe Yarar:** Sık erişilen dosyaları RAM'e ek olarak önbelleğe alır  
**Tavsiye:** 1-2x 256GB+ SSD  
**Zorunlu mu?** Hayır, yeterli RAM varsa gereksiz (16GB+ yeterli)

#### 🟡 Spare - Yedek Disk
**Ne İşe Yarar:** RAID kullanırken bozulan diski otomatik değiştirir  
**Tavsiye:** ❌ RAID kullanmıyorsanız gereksiz

#### 🟣 Metadata - Metadata Performansı
**Ne İşe Yarar:** Küçük dosyalar için metadata'yı SSD'de tutar  
**Tavsiye:** 2x 64GB+ SSD (mirror) - çok sayıda küçük dosya varsa  
**Zorunlu mu?** Hayır, Nextcloud için genelde gereksiz

#### 🔴 Dedup - Deduplikasyon
**Ne İşe Yarar:** Aynı veriden birden fazla kopyayı tek seferde depolar  
**Tavsiye:** ❌ KULLANMA! Her 1TB veri için ~5GB RAM gerekir  
**100TB için:** 500GB RAM gerekir - pratikte kullanılamaz

### 💡 100TB Nextcloud için Önerilen Yapı

```
📦 Data VDev: 10x12TB HDD (Stripe) = ~120TB kullanılabilir
📝 Log (SLOG): 2x 32GB SSD (Mirror) = NFS performansı için
🚫 Cache: Yok (16GB RAM yeterli)
🚫 Spare: Yok (RAID yok)
🚫 Metadata: Yok (Nextcloud büyük dosyalar)
🚫 Dedup: Yok (çok fazla RAM gerekir)
```

---

## Dataset ve İzinler

```bash
# Dataset oluştur
zfs create storage/nextcloud
zfs create storage/nextcloud/data

# Optimizasyon
zfs set compression=lz4 storage
zfs set atime=off storage

# Nextcloud izinleri (www-data = uid 33)
chown -R 33:33 /mnt/storage/nextcloud/data
chmod 770 /mnt/storage/nextcloud/data
```

---

## NFS Share

**Shares → NFS → Add**

| Ayar | Değer |
|------|-------|
| Path | `/mnt/storage/nextcloud/data` |
| Maproot User | `root` |
| Maproot Group | `wheel` |
| Networks | `192.168.x.0/24` (Nextcloud subnet) |

**Services → NFS → Start + Autostart**

---

## Test (Nextcloud VM'den)

```bash
showmount -e TRUENAS_IP
# Çıktı: /mnt/storage/nextcloud/data ...

# Mount testi
mount -t nfs TRUENAS_IP:/mnt/storage/nextcloud/data /mnt/test
touch /mnt/test/deneme && rm /mnt/test/deneme
umount /mnt/test
```

✅ Başarılıysa Nextcloud kurulumuna geç
