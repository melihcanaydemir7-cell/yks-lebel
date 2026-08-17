# Gizlilik Politikası — YKS Level

> **TEMPLATE / ŞABLON.** Bu belge bir taslaktır ve hukuki tavsiye değildir.
> Yayına çıkmadan önce bir hukuk danışmanına inceletin, şirket bilgilerinizi
> doldurun ve `https://ykslevel.app/gizlilik` adresinde yayınlayın. Uygulama
> içindeki bağlantı `lib/core/config/app_config.dart` içindeki
> `privacyPolicyUrl` değerinden okunur.

**Son güncelleme:** _[TARİH]_
**Veri sorumlusu:** _[ŞİRKET / GELİŞTİRİCİ ADI]_
**İletişim:** destek@ykslevel.app

---

## 1. Kısaca

YKS Level, YKS/TYT/AYT hazırlığını oyunlaştıran bir mobil uygulamadır.
Uygulamayı **hesap açmadan (misafir modunda)** kullanabilirsiniz. Misafir
modunda ilerlemeniz yalnızca cihazınızda saklanır.

Kredi kartı veya banka kartı bilgilerinizi **hiçbir zaman** toplamıyor,
görmüyor ve saklamıyoruz. Tüm ödeme işlemleri Google Play Faturalandırma
altyapısı üzerinden yürütülür.

## 2. Topladığımız veriler

### 2.1 Hesap açtığınızda

| Veri | Amaç | Yasal dayanak |
| --- | --- | --- |
| E-posta adresi | Kimlik doğrulama, hesap kurtarma | Sözleşmenin ifası |
| Kullanıcı adı | Profil ve lig sıralaması | Sözleşmenin ifası |
| Avatar seçimi | Profil görünümü | Sözleşmenin ifası |
| Google hesabı kimliği (Google ile giriş kullanılırsa) | Kimlik doğrulama | Sözleşmenin ifası |

### 2.2 Uygulamayı kullanırken

| Veri | Amaç |
| --- | --- |
| Çözülen sorular, verilen cevaplar, doğru/yanlış bilgisi | İlerleme takibi, istatistikler |
| Cevap süresi | İstatistikler |
| Kazanılan XP, seviye, seri (streak), rozetler | Oyunlaştırma |
| Haftalık XP | Lig sıralaması |
| Seçtiğiniz alan (TYT / Sayısal / Eşit Ağırlık / Sözel / Dil) | İçerik önceliklendirme |
| Uygulama ayarlarınız (tema, bildirim saati, ses, titreşim) | Tercihlerinizi hatırlamak |

### 2.3 Otomatik toplanan veriler

| Veri | Kaynak | Amaç |
| --- | --- | --- |
| Uygulama kullanım olayları (ekran açılışı, quiz başlatma/bitirme, reklam izleme, satın alma denemesi) | Firebase Analytics | Ürün geliştirme, elde tutma ölçümü |
| Cihaz modeli, işletim sistemi sürümü, uygulama sürümü, yaklaşık ülke/bölge | Firebase Analytics | Toplu istatistik |
| Çökme kayıtları ve hata yığınları | Firebase Crashlytics | Hata giderme |
| Reklam kimliği ve reklam etkileşimleri | Google AdMob | Reklam gösterimi ve ölçümü |
| Satın alma durumu (abone / abone değil) | Google Play Faturalandırma | Premium erişimi |

Analitik olaylarına **ad, e-posta veya serbest metin gibi kişisel bilgiler
eklenmez**; yalnızca ders adı, konu, soru sayısı, doğruluk oranı, süre ve
kazanılan XP gibi oyun içi ölçütler gönderilir.

## 3. Toplamadığımız veriler

- Kredi kartı / banka kartı bilgileri
- Konum verisi (GPS)
- Rehber, çağrı kaydı, SMS
- Fotoğraf, kamera veya mikrofon verisi
- Sağlık verileri

## 4. Verileri kimlerle paylaşıyoruz

Verilerinizi satmıyoruz. Aşağıdaki hizmet sağlayıcıları, yalnızca uygulamanın
çalışması için gerekli ölçüde veri işler:

| Hizmet | Amaç | Gizlilik politikası |
| --- | --- | --- |
| Supabase | Hesap yönetimi ve veri saklama | https://supabase.com/privacy |
| Google Firebase (Analytics, Crashlytics) | Analitik ve çökme raporlama | https://firebase.google.com/support/privacy |
| Google AdMob | Reklam gösterimi | https://policies.google.com/technologies/ads |
| Google Play Faturalandırma | Abonelik işlemleri | https://policies.google.com/privacy |

## 5. Reklamlar

Ücretsiz sürümde ödüllü (rewarded) ve zaman zaman geçiş (interstitial)
reklamları gösterilir. Reklamlar Google AdMob tarafından sunulur ve
kişiselleştirilmiş olabilir. Cihaz ayarlarınızdan reklam kimliğinizi
sıfırlayabilir veya kişiselleştirmeyi kapatabilirsiniz.

**Premium abonelere hiçbir reklam gösterilmez.**

## 6. Saklama süresi

- Hesabınız aktif olduğu sürece hesap ve ilerleme verileriniz saklanır.
- Hesabınızı sildiğinizde tüm hesap verileriniz kalıcı olarak silinir.
- Analitik ve çökme verileri, Firebase varsayılan saklama sürelerine tabidir
  (varsayılan: 2 aya kadar çökme verisi, 14 aya kadar analitik).

## 7. Haklarınız (KVKK ve GDPR)

Şu haklara sahipsiniz:

- Verilerinize erişme
- Düzeltilmesini isteme
- **Silinmesini isteme**
- İşlemeye itiraz etme
- Verilerinizin taşınmasını isteme

**Hesabınızı uygulama içinden silebilirsiniz:**
`Profil → Ayarlar → Hesabı Sil`

Bu işlem hesabınızı ve buluttaki tüm verilerinizi kalıcı olarak siler ve geri
alınamaz. Alternatif olarak destek@ykslevel.app adresine yazabilirsiniz;
talebinize en geç 30 gün içinde yanıt veririz.

## 8. Çocukların gizliliği

YKS Level, üniversite sınavına hazırlanan öğrencilere yöneliktir ve **13 yaş
altındaki çocuklara yönelik değildir**. 13 yaşından küçük bir kullanıcıya ait
veri topladığımızı fark edersek bu veriyi sileriz.

## 9. Güvenlik

- Tüm ağ trafiği TLS ile şifrelenir.
- Veritabanı erişimi Supabase Row Level Security ile satır bazında kısıtlanır;
  bir kullanıcı yalnızca kendi verisine erişebilir.
- Şifreler Supabase tarafından karma (hash) olarak saklanır; düz metin şifreye
  erişimimiz yoktur.

## 10. Değişiklikler

Bu politikada değişiklik yaptığımızda güncellenmiş sürümü bu adreste
yayınlarız ve önemli değişiklikleri uygulama içinde duyururuz.

## 11. İletişim

destek@ykslevel.app
_[ŞİRKET ADRESİ]_
