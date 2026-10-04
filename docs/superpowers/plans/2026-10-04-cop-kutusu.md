# Uygulama içi çöp kutusu uygulama planı

> **For agentic workers:** Use executing-plans to implement this plan inline.

**Goal:** Silinen sayfaları alt sayfa ve görselleriyle uygulama içinde geri yüklemek.
**Architecture:** Foundation kullanan `CopKutusu` taşıma, metadata ve güvenli kalıcı silmeyi yönetir. AppKit popover kenar panelden açılır; mevcut ağaç ve önbellek yenilemesi kullanılır.
**Tech Stack:** Swift, Foundation, AppKit, macOS 12+; bağımlılık yok.
**Spec:** Kullanıcının 026 talebi.

## Kısıtlar

Test yazılmayacak, `swift test` çalıştırılmayacak. Kullanıcının mevcut değişiklikleri korunacak; commit yapılmayacak. Markdown içeriği yeniden yazılmadan taşınacak. ⌘Z istekteki istisna kapsamında atlanacak; mevcut metin undo davranışı korunacak.

## İnceleme odağı

- Eski `Ad.md` ve `Ad/` birlikte taşınmalı; ikinci taşıma hatasında ilk taşıma geri alınmalı.
- Çakışan hedef veya bulunmayan üst sayfa kökte benzersiz ada düşmeli.
- `.cop` ve öğe yolları sembolik bağlarla kökün dışına çıkamamalı.
- Başarısız silme editörü boşaltmamalı; kaydedilmemiş metin taşımadan önce saklanmalı.
- Gizli panelin önbelleği de silinen notları derhal düşürmeli.

## İşler

- [x] `Cekirdek/CopKutusu.swift`: metadata, listeleme, taşıma/geri alma, geri yükleme, onay sonrası kalıcı silme ve 30 günlük temizleme.
- [x] `Gorunum/CopKutusuPaneli.swift`, kenar panel ve menü: aramalı popover, göreli tarih, geri yükle, sil/boşalt onayı; açılış temizliği.
- [x] Kod haritasını güncelle; `swift build` ve bağımsız kod incelemesiyle doğrula. Kayıt biçimi değişmez.

## Doğrulama kaydı

Bağımsız incelemenin iki bulgusu giderildi: mevcut kapsayıcı klasöre geri yükleme ve büyük/küçük harfe duyarlı disklerde eski Markdown uzantılarının çakışması. Ana Sayfa, mevcut önbellek değişim bildirimiyle yenilenir. Test yazılmadı ve çalıştırılmadı. `swift build --disable-sandbox --scratch-path /private/tmp/notdefteri-cop-build` için derleyici önbellekleri izinli geçici dizine yönlendirildi.
