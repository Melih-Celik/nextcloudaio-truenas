# Windows'tan Nextcloud'a Veri Taşıma (Local Ağ)

## Özet

Windows → TrueNAS SMB → Nextcloud taraması

---

## Adım 1: TrueNAS'ta SMB Share Oluştur

### Web UI'dan:
**Shares → SMB → Add**

| Ayar | Değer |
|------|-------|
| Path | `/mnt/storage/nextcloud/data` |
| Name | `ncdata` |
| Purpose | Default |

**Save → Confirm Enable Service**

### İzinler (TrueNAS Shell):
```bash
# SMB erişimi için ACL
chmod 777 /mnt/storage/nextcloud/data
```

---

## Adım 2: Windows'tan Bağlan

1. **Dosya Gezgini** aç
2. Adres çubuğuna yaz:
   ```
   \\TRUENAS_IP\ncdata
   ```
3. Kullanıcı: `root` (veya TrueNAS kullanıcısı)
4. Şifre: TrueNAS şifresi

---

## Adım 3: Doğru Klasöre Kopyala

### Klasör Yapısı

```
\\TRUENAS_IP\ncdata\
├── admin/
│   └── files/          ← admin kullanıcısı için BURAYA kopyala
│       ├── Belgeler/
│       ├── Fotograflar/
│       └── ...
├── kullanici2/
│   └── files/          ← kullanici2 için BURAYA kopyala
└── ...
```

⚠️ **ÖNEMLİ:** 
- Dosyaları `files/` klasörünün İÇİNE koy
- `files/` klasörünün kendisini silme/değiştirme

### Robocopy ile Kopyala (Önerilen)

**CMD aç (Yönetici olarak):**

```cmd
robocopy "D:\TasinacakVeriler" "\\TRUENAS_IP\ncdata\admin\files\Eski Veriler" /E /ZB /R:3 /W:10 /MT:8 /LOG:C:\kopya.log /TEE /NP
```

| Parametre | Açıklama |
|-----------|----------|
| /E | Boş klasörler dahil tümünü kopyala |
| /ZB | Kesintide kaldığı yerden devam |
| /R:3 | Hata durumunda 3 kez dene |
| /W:10 | Denemeler arası 10 saniye bekle |
| /MT:8 | 8 paralel iş parçacığı |
| /LOG | Log dosyası |
| /TEE | Ekranda da göster |
| /NP | Yüzde gösterme (log temiz olsun) |

### Örnek Senaryolar

**Tek kullanıcının tüm verileri:**
```cmd
robocopy "D:\Firma\Veriler" "\\192.168.1.100\ncdata\admin\files" /E /ZB /R:3 /W:10 /MT:8 /LOG:C:\kopya.log /TEE
```

**Birden fazla klasör:**
```cmd
robocopy "D:\Belgeler" "\\192.168.1.100\ncdata\admin\files\Belgeler" /E /ZB /R:3 /W:10 /MT:8
robocopy "D:\Fotograflar" "\\192.168.1.100\ncdata\admin\files\Fotograflar" /E /ZB /R:3 /W:10 /MT:8
robocopy "D:\Projeler" "\\192.168.1.100\ncdata\admin\files\Projeler" /E /ZB /R:3 /W:10 /MT:8
```

---

## Adım 4: Doğrulama

### Dosya Sayısı Kontrolü

**Windows (PowerShell):**
```powershell
(Get-ChildItem -Path "D:\TasinacakVeriler" -Recurse -File).Count
```

**TrueNAS Shell:**
```bash
find /mnt/storage/nextcloud/data/admin/files -type f | wc -l
```

Sayılar eşleşmeli!

### Boyut Kontrolü

**Windows:**
```powershell
(Get-ChildItem -Path "D:\TasinacakVeriler" -Recurse | Measure-Object -Property Length -Sum).Sum / 1GB
```

**TrueNAS:**
```bash
du -sh /mnt/storage/nextcloud/data/admin/files
```

---

## Adım 5: İzinleri Düzelt

Kopyalama bittikten sonra TrueNAS'ta:

```bash
# www-data (uid 33) sahipliği
chown -R 33:33 /mnt/storage/nextcloud/data/admin/files

# İzinler
chmod -R 755 /mnt/storage/nextcloud/data/admin/files
find /mnt/storage/nextcloud/data/admin/files -type f -exec chmod 644 {} \;
```

---

## Adım 6: Nextcloud Taraması

**Nextcloud VM'de:**

```bash
cd ~/nextcloudaio-truenas/nextcloud
./scan.sh
```

Veya manuel:
```bash
docker exec -u www-data nextcloud-aio-nextcloud php occ files:scan admin
```

Tüm kullanıcılar için:
```bash
docker exec -u www-data nextcloud-aio-nextcloud php occ files:scan --all
```

---

## Süre Tahmini

| Veri Boyutu | Gigabit Ağ | 
|-------------|------------|
| 1 TB | ~2-3 saat |
| 10 TB | ~1 gün |
| 50 TB | ~5 gün |
| 76 TB | ~7-8 gün |

💡 **İpucu:** Gece başlat, sabah kontrol et

---

## Sorun Giderme

| Sorun | Çözüm |
|-------|-------|
| SMB bağlanamıyor | Firewall kontrol, `ping TRUENAS_IP` |
| "Erişim engellendi" | TrueNAS'ta SMB izinleri kontrol |
| Kopyalama yarıda kaldı | Aynı robocopy komutunu tekrar çalıştır (devam eder) |
| Nextcloud dosyaları görmüyor | `chown -R 33:33` ve `scan.sh` çalıştır |
| Yavaş transfer | Kablolu bağlantı kullan, MT:16 dene |

---

## Kopyalama Sonrası Kontrol Listesi

- [ ] Dosya sayısı eşleşiyor
- [ ] Toplam boyut eşleşiyor
- [ ] TrueNAS'ta izinler düzeltildi (chown 33:33)
- [ ] Nextcloud taraması yapıldı
- [ ] Nextcloud web'den dosyalar görünüyor
- [ ] Birkaç dosya açılıp kontrol edildi
