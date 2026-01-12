# LDAP + Veri Taşıma Rehberi

## Akış Özeti

```
1. Nextcloud kurulumu ─► 2. LDAP bağla ─► 3. Group Folder oluştur ─► 4. Veri kopyala ─► 5. Tarama
```

---

## Adım 1: LDAP Entegrasyonu

### 1.1 LDAP Uygulamasını Etkinleştir

Nextcloud'a admin olarak giriş yap → **Uygulamalar** → **LDAP user and group backend** → **Etkinleştir**

### 1.2 LDAP Ayarları

**Ayarlar → LDAP/AD Entegrasyonu**

#### Sunucu Sekmesi
| Ayar | Değer |
|------|-------|
| Host | `ldap://192.168.1.50` veya `ldaps://` |
| Port | `389` (veya `636` SSL için) |
| User DN | `cn=admin,dc=sirket,dc=local` |
| Password | LDAP admin şifresi |
| Base DN | `dc=sirket,dc=local` |

**"Algıla" butonuna tıkla** → Bağlantı başarılı olmalı

#### Kullanıcılar Sekmesi
| Ayar | Değer |
|------|-------|
| Object class | `inetOrgPerson` veya `user` (AD için) |
| Groups | Sadece belirli gruplar seçilebilir |

**"Kullanıcı sayısını doğrula"** → Kullanıcılar görünmeli

#### Giriş Özellikleri Sekmesi
| Ayar | Değer |
|------|-------|
| LDAP Username | `uid` (veya `sAMAccountName` AD için) |
| LDAP Email | `mail` |

#### Gruplar Sekmesi
| Ayar | Değer |
|------|-------|
| Object class | `groupOfNames` veya `group` (AD için) |

**Kaydet**

### 1.3 Test Et

- Çıkış yap
- LDAP kullanıcısı ile giriş yap
- Başarılı ise kullanıcı klasörü otomatik oluşur

---

## Adım 2: Group Folders Oluştur

### 2.1 Uygulamayı Etkinleştir

**Uygulamalar → Group Folders → Etkinleştir**

### 2.2 Grup Klasörü Oluştur

**Ayarlar → Grup Klasörleri**

1. **+ Klasör ekle** → İsim: `Sirket Verileri`
2. **Grup ekle:**
   - LDAP'tan gelen grubunu seç (örn: `Domain Users`)
   - İzin: **Yazma** veya **Okuma**
3. **Kota:** İsteğe bağlı limit

> **Not:** Klasör ID'si otomatik atanır (genelde `1`)

### 2.3 Klasör ID'sini Öğren (Gerekirse)

```bash
# Nextcloud VM'de
docker exec -u www-data nextcloud-aio-nextcloud php occ groupfolders:list
```

Çıktı:
```
+----+----------------+--------+
| ID | Name           | Groups |
+----+----------------+--------+
| 1  | Sirket Verileri| ...    |
+----+----------------+--------+
```

---

## Adım 3: TrueNAS'ta SMB Paylaşımı

### 3.1 SMB Share Oluştur

**TrueNAS → Shares → SMB → Add**

| Ayar | Değer |
|------|-------|
| Path | `/mnt/storage/nextcloud/data` |
| Name | `ncdata` |

**Save → Enable Service**

### 3.2 Geçici İzin (Kopyalama için)

TrueNAS Shell:
```bash
chmod 777 /mnt/storage/nextcloud/data
```

---

## Adım 4: Windows'tan Veri Kopyala

### 4.1 Klasör Yapısını Anla

```
\\TRUENAS_IP\ncdata\
├── __groupfolders\
│   └── 1\                      ← GRUP VERİLERİ BURAYA
│       ├── Muhasebe\
│       ├── Projeler\
│       └── Arsiv\
├── kullanici1\
│   └── files\                  ← Kişisel dosyalar (LDAP'tan otomatik oluşur)
└── kullanici2\
    └── files\
```

### 4.2 Grup Klasörünü Oluştur (İlk kez)

Windows'tan veya TrueNAS'tan:
```bash
# TrueNAS Shell
mkdir -p /mnt/storage/nextcloud/data/__groupfolders/1
chown 33:33 /mnt/storage/nextcloud/data/__groupfolders
chown 33:33 /mnt/storage/nextcloud/data/__groupfolders/1
```

### 4.3 Robocopy ile Kopyala

**CMD'yi Yönetici olarak aç:**

```cmd
robocopy "D:\Sirket_Verileri" "\\TRUENAS_IP\ncdata\__groupfolders\1" /E /ZB /R:3 /W:10 /MT:8 /LOG:C:\kopya.log /TEE /NP
```

### 4.4 Arka Planda Çalıştırma (Opsiyonel)

```powershell
# PowerShell'de arka planda başlat
Start-Job -ScriptBlock {
    robocopy "D:\Sirket_Verileri" "\\TRUENAS_IP\ncdata\__groupfolders\1" /E /ZB /R:3 /W:10 /MT:8 /LOG:C:\kopya.log
}

# Durumu kontrol et
Get-Job

# Log takibi
Get-Content C:\kopya.log -Tail 20 -Wait
```

---

## Adım 5: İzinleri Düzelt

Kopyalama bittikten sonra **TrueNAS Shell'de:**

```bash
# Tüm data klasörü için
chown -R 33:33 /mnt/storage/nextcloud/data/__groupfolders
chmod -R 770 /mnt/storage/nextcloud/data/__groupfolders

# SMB geçici iznini geri al
chmod 770 /mnt/storage/nextcloud/data
```

---

## Adım 6: Nextcloud Taraması

**Nextcloud VM'de:**

```bash
cd ~/nextcloudaio-truenas/nextcloud

# Tüm dosyaları tara
./scan.sh

# Veya sadece group folders
docker exec -u www-data nextcloud-aio-nextcloud php occ groupfolders:scan 1
```

---

## Adım 7: Doğrulama

1. LDAP kullanıcısı ile Nextcloud'a giriş yap
2. Sol menüde **"Sirket Verileri"** klasörü görünmeli
3. İçindeki dosyalar erişilebilir olmalı

---

## Özet Tablo

| Adım | Nerede | Komut/İşlem |
|------|--------|-------------|
| 1 | Nextcloud Web | LDAP ayarları |
| 2 | Nextcloud Web | Group Folders oluştur |
| 3 | TrueNAS Web | SMB Share oluştur |
| 4 | Windows CMD | `robocopy ... __groupfolders/1` |
| 5 | TrueNAS Shell | `chown -R 33:33 __groupfolders` |
| 6 | Nextcloud VM | `./scan.sh` |
| 7 | Nextcloud Web | Test et |

---

## Sorun Giderme

| Sorun | Çözüm |
|-------|-------|
| LDAP bağlanmıyor | Firewall, port, credentials kontrol |
| Kullanıcı görünmüyor | Base DN ve filter kontrol |
| Group Folder boş | `chown 33:33` + `scan.sh` çalıştır |
| "Permission denied" | TrueNAS'ta izinleri kontrol |
| Dosyalar görünmüyor | `occ groupfolders:scan 1` çalıştır |

---

## Süre Tahmini

| İşlem | Süre |
|-------|------|
| LDAP kurulum | 15-30 dk |
| Group Folders | 5 dk |
| 1 TB kopyalama | 2-3 saat |
| 10 TB kopyalama | 1 gün |
| 76 TB kopyalama | 7-8 gün |
| Tarama (scan) | ~1 TB/saat |
