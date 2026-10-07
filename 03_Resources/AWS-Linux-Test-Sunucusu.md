---
tags: [linux, aws, test, runbook]
guncelleme: 2026-10-07
durum: kismen-dogrulandi
---

# AWS Linux Test Sunucusu (Runbook)

NotDefteri'nin Linux (GTK4) sürümünü denemek için AWS'de bir Ubuntu sunucusu açma,
ona Mac'ten **Windows App** ile görsel olarak bağlanma ve işi bitince kapatma sırası.

Bu belge yalnızca **arayüz yolunu** anlatır: anahtar dosyası, Terminal ve SSH tüneli gerekmez.
Kapsam dışı: uygulamanın Linux'ta derlenmesinin ayrıntıları. Onlar `README.md` →
"NotDefteri'yi Linux'ta çalıştırma" ve `scripts/linux-kur.sh` içinde.

> **Doğrulama durumu (2026-10-07):** Bölüm 1–7 bir kez gerçekten uygulandı ve çalıştı.
> Bölüm 3'teki Bütçe adımı, Bölüm 7'deki kalıcı polkit kuralı, Bölüm 8 (kodu
> çekip derleme) ve Bölüm 9 (SSH ve anahtar çifti) henüz denenmedi. Bunlar **taslak**.
> İlk çalıştıran sonucu bu nota eklesin.
>
> İki bağlantı yolu var: **arayüz yolu** (Bölüm 5–7, önerilen) ve **Terminal/SSH yolu** (Bölüm 9).

## İşaretler

| İşaret | Anlamı |
|---|---|
| 🖱️ | Tarayıcıda, AWS konsolunda yapılan elle adım |
| 💻 | Sunucunun terminalinde çalışan komut |
| 🖥️ | Mac'te, Windows App'te yapılan adım |
| 💰 | Ücret doğurabilir |
| ⚠️ | Geri alınamaz |

## Kısa yol

1. AWS hesabı aç, Zero spend bütçe alarmı kur, bölge olarak Frankfurt'u seç.
2. EC2'de Ubuntu 22.04 sunucusu aç: 30 GiB disk, Free tier eligible tip.
3. Güvenlik grubunda SSH'ı **Anywhere-IPv4**, RDP'yi **My IP** olarak aç.
4. **Connect → EC2 Instance Connect** ile tarayıcıdan sunucuya gir.
5. XFCE ile xrdp'yi kur ve `ubuntu` kullanıcısına parola koy.
6. Windows App'te **Add PC** de, IP'yi gir, kullanıcı adı `ubuntu` olsun.
7. İş bitince sunucuyu **Stop** et.

## Ön koşullar

| Gereken | Kontrol |
|---|---|
| Kredi kartı (AWS hesabı için) | — |
| Mac'te **Windows App** (App Store) | Uygulama açılıyor mu? |
| Mac'te VPN **kapalı** | AWS'deki "My IP", VPN açıkken yanlış IP'yi yakalar. |

**Ubuntu sürümü 22.04 olmalı.** Kod en az GTK 4.6 istiyor (`Sources/CGtk/shim.h`).
Ubuntu 20.04'te GTK4 hiç yok, bu yüzden 20.04 üzerinde derlenemez.

---

## 1. AWS hesabı

1. 🖱️ aws.amazon.com adresinde **Create a free account** seç ve adımları tamamla.
2. 🖱️ Plan sorulursa **Free plan**'ı seç.

## 2. Bölge

1. 🖱️ Konsolun sağ üstündeki bölge menüsünden **Europe (Frankfurt) eu-central-1**'i seç.

Bu belgedeki her şey bu bölgede durur. Bölge değişirse sunucu listede görünmez.

## 3. Harcama alarmı (taslak, denenmedi)

1. 🖱️ Üstteki arama kutusuna `Budgets` yaz ve sonuca tıkla.
2. 🖱️ **Create budget**'a bas, **Zero spend budget** şablonunu seç.
3. 🖱️ E-posta adresini gir ve **Create budget**'a bas.

1 cent bile harcanırsa e-posta gelir.

## 4. Sunucuyu aç 💰

1. 🖱️ Arama kutusuna `EC2` yaz → **EC2** → **Launch instance**.
2. 🖱️ Alanları doldur:

| Alan | Değer |
|---|---|
| Name | `notdefteri-test` |
| AMI | **Ubuntu Server 22.04 LTS**, **64-bit (x86)** |
| Instance type | "Free tier eligible" etiketlilerden RAM'i en yüksek olan (ör. `c7i-flex.large`, 4 GB). Yalnızca `t3.micro` varsa onu seç ve Bölüm 6.2'yi uygula. |
| Key pair | Arayüz yolunda gerekmez. Mac Terminal'den SSH ile bağlanacaksan Bölüm 9.1'deki gibi oluştur. |
| Allow SSH traffic from | Şimdilik varsayılan kalsın. Bölüm 5'te düzeltilecek. |
| Storage | **30 GiB gp3**. Swift araç zinciri yaklaşık 3 GB yer tutar. |

3. 🖱️ **Launch instance**'a bas.
4. 🖱️ **Instances** listesinde **Instance state** değeri **Running** olana kadar bekle.
5. 🖱️ Sunucuya tıkla ve **Public IPv4 address** değerini not al.

> Sunucu her durdurulup başlatıldığında IP değişir. Her açılışta bu adresi yeniden kontrol et.

## 5. Güvenlik kuralları

1. 🖱️ Sunucuya tıkla → **Security** sekmesi → **Security groups** altındaki `sg-...` bağlantısı.
2. 🖱️ **Edit inbound rules**'a bas.
3. 🖱️ **SSH** satırında Source'u **Anywhere-IPv4** (`0.0.0.0/0`) yap.
   Tarayıcı terminali senin IP'nden değil, AWS'nin kendi sunucularından bağlanır.
   SSH yalnızca "My IP"ye açıksa Instance Connect bağlanamaz.
   Bu ayar güvenli: Ubuntu SSH'ta parolayla girişi kabul etmez.
4. 🖱️ **Add rule** de: Type **RDP**, Source **My IP**.
5. 🖱️ **Save rules**'a bas.

## 6. Tarayıcıdan sunucuya gir ve masaüstünü kur

### 6.1 Gir
1. 🖱️ **Instances**'ta `notdefteri-test`'i işaretle → **Connect**.
2. 🖱️ **EC2 Instance Connect** sekmesinde kullanıcı adı `ubuntu` olsun → **Connect**.
3. Tarayıcıda siyah bir terminal açılır.

### 6.2 Takas alanı (yalnızca 1 GB RAM'li tipte)
RAM az olunca Swift derlemesi yarıda kesilir.

```bash
# 💻 bir kez
sudo fallocate -l 4G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
```

### 6.3 Masaüstü ve RDP
Komutları teker teker yapıştır:

```bash
# 💻 bir kez — ikinci komut 5–10 dakika sürebilir
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xfce4 xrdp dbus-x11
echo xfce4-session > ~/.xsession
sudo adduser xrdp ssl-cert
sudo systemctl enable --now xrdp
sudo passwd ubuntu
```

`sudo passwd ubuntu` parolayı iki kez sorar. Yazarken ekranda hiçbir şey görünmez, bu normal.
Bu parolayı not al: Windows App girişinde kullanılacak.

Kontrol:
```bash
# 💻
systemctl is-active xrdp
```
Çıktı `active` olmalı.

## 7. Windows App ile bağlan

1. 🖥️ Windows App'i aç → **+** → **Add PC**.
2. 🖥️ Alanları doldur:
   - **PC name:** Bölüm 4.5'teki IP, örneğin `3.120.45.67`. Port yazma.
   - **Credentials** → **Add Credentials...** → Username `ubuntu`, Password Bölüm 6.3'teki parola → **Add**.
   - **Friendly name:** `NotDefteri Linux`
3. 🖥️ **Add**'e bas. Listede bir kutucuk belirir.
4. 🖥️ Kutucuğa çift tıkla. Sertifika uyarısı gelirse **Continue**'ya bas.
5. 🖥️ xrdp giriş ekranı gelirse Session `Xorg`, kullanıcı adı `ubuntu`, parola gir → **OK**.
6. XFCE masaüstü açılır.

### İlk girişte "Authentication is required to create a color managed device"
Zararsız bir uyarı. Parolayı girip **Authenticate**'e ya da **Cancel**'a bas.

Bir daha sorulmasın istersen (taslak, denenmedi):
```bash
# 💻 tek blok halinde yapıştır; sonraki girişten itibaren geçerli
sudo tee /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla <<'EOF'
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF
```

## 8. Kodu çek, derle, çalıştır (taslak, denenmedi)

Önce `linux-destegi` dalının GitHub'a push edilmiş olması gerekir. Sonra XFCE içinde bir terminal aç:

```bash
# 💻
git clone -b linux-destegi https://github.com/olcayalkan/NotDefteri.git ~/NotDefteri
cd ~/NotDefteri
./scripts/linux-kur.sh
```

Betik GTK4 ve Swift'i kurar, ardından `swift build` ve `swift run` çalıştırır.
Sonraki açılışlarda yalnızca şunu çalıştır:

```bash
# 💻
cd ~/NotDefteri && swift run
```

Pencere siyah kalırsa ya da çizim bozuksa GPU'suz ortamda GTK4'ün yazılım çiziciyle çalışmasını sağla:
```bash
# 💻
GSK_RENDERER=cairo swift run
```

## 9. SSH ile bağlanma ve anahtar çifti (taslak, denenmedi)

Arayüz yolunun alternatifi: Mac'teki **Terminal** uygulamasından sunucuya komut satırıyla bağlanmak.
SSH parola değil **anahtar çifti** ile çalışır:
- **Gizli anahtar** (`.pem` dosyası) Mac'te durur. Kimseyle paylaşılmaz.
- **Açık anahtar** sunucudaki `~/.ssh/authorized_keys` dosyasında durur.

İkisi eşleşirse giriş olur. AWS konsolundaki "Key pair" yalnızca sunucu **ilk açılırken**
açık anahtarı bu dosyaya bir kez yazar. Sonradan konsoldan değiştirilemez (bkz. 9.4).

### 9.1 Anahtar çifti oluştur

**Yeni sunucu açarken (önerilen):**
1. 🖱️ **Launch instance** ekranında **Key pair (login)** → **Create new key pair**.
2. 🖱️ Name `notdefteri`, Key pair type **RSA**, Private key file format **.pem** → **Create key pair**.
3. `notdefteri.pem` dosyası hemen **İndirilenler**'e iner.

**Sunucudan bağımsız, Key Pairs sayfasından:**
1. 🖱️ EC2 → sol menü **Network & Security** → **Key Pairs** → **Create key pair**.
2. 🖱️ Aynı alanları doldur → **Create key pair**.
   Aynı ad zaten varsa AWS kabul etmez. Ya başka bir ad ver ya da eskisini işaretleyip
   **Actions → Delete** ile sil. Silme yalnızca AWS'deki kaydı kaldırır, sunucuya dokunmaz.
3. Bu yolla oluşturulan anahtar **yalnızca bundan sonra açılan** sunuculara konabilir.
   Var olan sunucu için 9.4'ü uygula.

> ⚠️ AWS `.pem` dosyasını yalnızca bu anda bir kez verir. İndirilenler'de olduğunu hemen kontrol et.

### 9.2 Anahtarı Mac'te yerine koy (bir kez)
1. 🖥️ **Cmd + Boşluk** → `Terminal` → **Enter**.
2. Komutları teker teker çalıştır:

```bash
# Mac Terminal
mkdir -p ~/.ssh
mv ~/Downloads/notdefteri.pem ~/.ssh/
chmod 400 ~/.ssh/notdefteri.pem
ls -l ~/.ssh/notdefteri.pem
```

Son satırın çıktısı `-r--------` ile başlamalı.
`No such file or directory` hatası alırsan tarayıcı dosyanın adını değiştirmiştir
(`notdefteri (1).pem`, `notdefteri.pem.txt`). Finder'da adını `notdefteri.pem` yap ve tekrar çalıştır.

### 9.3 Mac'ten bağlan
Ön koşul: Bölüm 5'teki SSH kuralı açık olmalı. **My IP** ya da **Anywhere-IPv4** olabilir.

```bash
# Mac Terminal — IP'yi kendi Public IPv4 adresinle değiştir
ssh -i ~/.ssh/notdefteri.pem ubuntu@3.120.45.67
```

1. İlk bağlantıda `Are you sure you want to continue connecting (yes/no/[fingerprint])?` sorusu gelir. `yes` yaz.
2. Komut satırı `ubuntu@ip-172-31-...:~$` olursa sunucudasın. Bundan sonraki komutlar sunucuda çalışır.
3. Çıkmak için `exit` yaz.

### 9.4 Var olan sunucunun anahtarını değiştir (sunucuyu silmeden)
`.pem` kaybolduysa ya da anahtarı yenilemek istiyorsan bu adımları uygula.

1. Mac'te yeni bir anahtar çifti üret ve açık anahtarı panoya kopyala:
   ```bash
   # Mac Terminal
   ssh-keygen -t ed25519 -f ~/.ssh/notdefteri_yeni -N ""
   pbcopy < ~/.ssh/notdefteri_yeni.pub
   ```
   Bu komut iki dosya oluşturur: `~/.ssh/notdefteri_yeni` (gizli) ve `~/.ssh/notdefteri_yeni.pub` (açık).
2. 🖱️ Bölüm 6.1'deki gibi **EC2 Instance Connect** ile tarayıcıdan sunucuya gir.
3. 💻 Tarayıcı terminalinde `echo '` yaz, **Cmd + V** ile panodakini yapıştır ve komutu tamamla:
   ```bash
   # eski anahtarı da korumak için: >> (ekler)
   echo 'ssh-ed25519 AAAA...yapıştırılan metin...' >> ~/.ssh/authorized_keys

   # eski anahtarı geçersiz kılmak için: > (üzerine yazar)
   echo 'ssh-ed25519 AAAA...yapıştırılan metin...' > ~/.ssh/authorized_keys
   ```
   Tek `>` ile hatalı bir satır yazarsan Mac'ten giremezsin. Tarayıcı terminali yine çalışır,
   oradan komutu düzeltip tekrar çalıştırırsın.
4. 💻 Kontrol et:
   ```bash
   cat ~/.ssh/authorized_keys
   ```
   Yeni satır `ssh-ed25519 AAAA` ile başlamalı.
5. Mac'ten yeni anahtarla bağlan:
   ```bash
   # Mac Terminal
   ssh -i ~/.ssh/notdefteri_yeni ubuntu@3.120.45.67
   ```

AWS konsolundaki "Key pair name" alanı eski adı göstermeye devam eder. Bu yalnızca bir etiket, girişi etkilemez.

### 9.5 Windows App'i SSH tüneliyle bağla (RDP portu açmadan)
Bu yol Bölüm 5'teki RDP kuralının yerine geçer. Port 3389 internete açılmaz,
masaüstü trafiği şifreli SSH bağlantısının içinden geçer.

1. 🖥️ Terminal'de **Cmd + N** ile yeni bir pencere aç ve çalıştır:
   ```bash
   # Mac Terminal — bu pencere açık kaldığı sürece tünel çalışır
   ssh -i ~/.ssh/notdefteri.pem -L 3390:localhost:3389 ubuntu@3.120.45.67
   ```
2. 🖥️ Windows App → **+** → **Add PC** → PC name `localhost:3390`. Kimlik bilgileri Bölüm 7'deki gibi.
3. 🖥️ Kutucuğa çift tıkla.

`bind: Address already in use` hatası alırsan iki yerde de `3390` yerine `3391` kullan.
IP değiştiğinde yalnızca 1. adımdaki komutu güncellersin. Windows App'teki `localhost:3390` hep aynı kalır.

### 9.6 SSH hataları

| Belirti | Neden | Çözüm |
|---|---|---|
| `Operation timed out` | SSH kuralı senin IP'ne kapalı ya da sunucu durmuş. | Sunucunun **Running** olduğunu kontrol et. Bölüm 5'te SSH satırını **My IP** ya da **Anywhere-IPv4** yap. |
| `Permission denied (publickey)` | Kullanıcı adı ya da anahtar yanlış. | Kullanıcı `ubuntu` olmalı. `-i` ile verilen dosya sunucuya konan anahtar olmalı (9.4). |
| `UNPROTECTED PRIVATE KEY FILE!` | Dosya izinleri fazla açık. | `chmod 400 ~/.ssh/notdefteri.pem` |
| `Identity file ... not accessible: No such file or directory` | Dosya yolu yanlış. | `ls ~/.ssh/` ile dosya adını kontrol et. |
| `REMOTE HOST IDENTIFICATION HAS CHANGED!` | Aynı IP'ye yeni bir sunucu açılmış. | `ssh-keygen -R 3.120.45.67`, sonra yeniden bağlan. |

## Çalıştığını doğrula

| Beklenen | Nasıl görülür |
|---|---|
| Sunucu açık | EC2 → Instances → **Running** |
| RDP servisi çalışıyor | 💻 `systemctl is-active xrdp` → `active` |
| Masaüstü geliyor | 🖥️ Windows App'te XFCE masaüstü açılıyor |
| Uygulama açılıyor | Başlığı "NotDefteri" olan pencere; alt sayfalar girintili listeleniyor |

---

## Sonraki girişler

1. 🖱️ EC2'de sunucuyu seç → **Instance state** → **Start instance**.
2. 🖱️ Yeni **Public IPv4 address**'i not al.
3. 🖥️ Windows App'te kutucuğa sağ tıkla → **Edit** → PC name'i yeni IP yap → **Save**.
4. 🖥️ Kutucuğa çift tıkla.

Ev internetinin IP'si değiştiyse önce Bölüm 5'te RDP satırının Source'unu yeniden **My IP** yap.

## Kapatma ve silme

| İşlem | Nerede | Sonuç | Geri alınır mı |
|---|---|---|---|
| **Stop** | EC2 → Instance state → Stop instance | Sunucu durur. İşlem ücreti biter, 30 GB disk kotadan saymaya devam eder. | Evet, **Start** ile |
| **Terminate** ⚠️ | EC2 → Instance state → Terminate (delete) instance | Sunucu ve diski kalıcı olarak silinir. | **Hayır** |

İş her bittiğinde **Stop** et. Testler tamamen bitince **Terminate** et.

---

## Sorun giderme

En ucuz kontrolden başlayarak sıralı.

### Tarayıcı terminali açılmıyor
**Belirti:** `Failed to connect to your instance` / `Error establishing SSH connection to your instance`
**Neden:** SSH kuralı yalnızca "My IP"ye açık. Instance Connect AWS'nin kendi sunucularından bağlanır.
**Çözüm:** Bölüm 5, adım 3.

### Windows App bağlanamıyor
**Belirti:** `We couldn't connect to the remote PC`
**Neden (sırayla kontrol et):**
1. Mac'te VPN açık ya da ev IP'si değişmiş. VPN'i kapat, Bölüm 5'te RDP satırını yeniden **My IP** yap.
2. Sunucu durmuş ya da IP değişmiş. Bölüm 4.4–4.5'i kontrol et.
3. RDP kuralı yok. Bölüm 5, adım 4.
4. xrdp çalışmıyor. 💻 `sudo systemctl restart xrdp`, ardından `systemctl is-active xrdp`.

### Ekran kararıp bağlantı kapanıyor
**Neden:** `~/.xsession` dosyası eksik.
**Çözüm:** 💻 `echo xfce4-session > ~/.xsession`, sonra yeniden bağlan.

### Giriş reddediliyor
**Belirti:** `Login failed`
**Çözüm:** 💻 `sudo passwd ubuntu` ile yeni bir parola koy ve Windows App'te kimlik bilgisini güncelle.

### Anahtar dosyası (`.pem`) kayboldu
AWS bir anahtarı yalnızca oluşturulduğu anda bir kez indirir. Sonradan yeniden indirilemez.
Arayüz yolu anahtarsız çalışır. SSH için sunucuyu silmeden yeni anahtar ekle: Bölüm 9.4.

### SSH hataları
Bölüm 9.6.

### Derleme `Killed` ile duruyor
**Neden:** Bellek yetmiyor.
**Çözüm:** Bölüm 6.2 (takas alanı).
