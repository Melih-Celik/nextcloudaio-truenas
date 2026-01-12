# TrueNAS Kurulum Rehberi

## ZFS Pool Oluşturma

**Storage → Create Pool**

| Disk | RAID | Kullanılabilir |
|------|------|----------------|
| 8x12TB | RAID-Z2 | ~65TB |
| 10x10TB | RAID-Z2 | ~72TB |

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
