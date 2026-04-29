# 🏭 Tunç Nur Branda - Dijital Sipariş ve Üretim Yönetim Sistemi

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com/)
[![Web App](https://img.shields.io/badge/Web_App-Platform-blue?style=for-the-badge)](https://tuncnurbranda-a93a5.web.app)

Bu proje, açık hava ekipmanları ve branda üretimi yapan ticari bir işletmenin geleneksel kağıt-kalem tabanlı sipariş süreçlerini modernize etmek amacıyla geliştirilmiş, uçtan uca bir **B2B SaaS (Hizmet Yazılımı)** çözümüdür. 

Fiziksel defterlere yazılan siparişlerin takibi, çizilen krokilerin kaybolması ve geçmiş verilere ulaşım zorluğu gibi operasyonel darboğazlar, bu proje ile tamamen dijitalleştirilmiş ve bulut tabanlı bir sisteme entegre edilmiştir.

---

## 🔗 Canlı Önizleme ve Demo Hesabı

Uygulamanın canlı sürümünü aşağıdaki bağlantıdan test edebilirsiniz:
👉 **[tuncnurbranda-a93a5.web.app](https://tuncnurbranda-a93a5.web.app)**

Projeyi ve sistemi içeriden inceleyebilmeniz için yetkileri sınırlandırılmış bir test personeli hesabı oluşturulmuştur:
* **E-posta:** `demo@tuncnurbranda.com`
* **Şifre:** `demo12345`
*(Not: Bu hesap sadece "Personel" yetkilerine sahiptir. Veri silme veya admin paneline erişim gibi kritik fonksiyonlar güvenlik sebebiyle kapatılmıştır.)*

---

## 🌟 Öne Çıkan Mühendislik Çözümleri

* **Rol Bazlı Erişim Kontrolü (RBAC):** Firebase Authentication ve Firestore kuralları ile entegre edilmiş, "Admin" ve "Personel" olmak üzere iki farklı kullanıcı tipi için izole edilmiş arayüzler.
* **Dijital Kroki Modülü:** Müşteri sipariş ölçülerinin fiziksel kağıtlardan kurtarılarak, dokunmatik ekran üzerinden doğrudan vektörel olarak çizilip sisteme kaydedilmesi (`signature` altyapısı).
* **Otonom PDF Fatura Üretimi:** Her sipariş kaydı tamamlandığında, müşteri ve kroki bilgilerini derleyerek anında kurumsal şablonda PDF çıktısı/faturası oluşturma ve yazdırma (`pdf` ve `printing` entegrasyonu).
* **Görsel Optimizasyonu & Maliyet Yönetimi:** Kullanıcı tarafından yüklenen sipariş fotoğraflarının Firebase Storage'a iletilmeden önce `flutter_image_compress` ile otomatik sıkıştırılması (5MB -> ~200KB). Bu sayede bulut depolama maliyetleri %90 oranında düşürülmüştür.
* **Gerçek Zamanlı Senkronizasyon:** Firestore'un NoSQL yapısı sayesinde, sahadaki personelin girdiği siparişin saniyeler içinde yönetim panelinde güncellenmesi.

---

## 🛠 Kullanılan Teknolojiler ve Mimari

**Kullanıcı Arayüzü (Frontend)**
* **Framework:** Flutter (Web Derlemesi)
* **Dil:** Dart
* **Durum Yönetimi (State Management):** Uygulama mimarisine uygun standart yönetim (Provider/Riverpod vb. kullanıldıysa buraya ekle)

**Arka Plan ve Bulut Hizmetleri (Backend & Cloud)**
* **Veritabanı:** Google Firebase Firestore
* **Dosya Depolama:** Google Firebase Storage
* **Kimlik Doğrulama:** Google Firebase Authentication
* **Dağıtım (CI/CD):** Firebase Hosting

---

## 📸 Ekran Görüntüleri ve İşleyiş

*(Projenin işleyişini gösteren GIF veya ekran görüntüleri eklenecek)*

| Sipariş Oluşturma & Çizim | Oluşturulan PDF Dökümü | Yönetim Paneli |
|:---:|:---:|:---:|
| <img src="[BURAYA_SIPARIS_EKRAN_GORUNTUSU_LINKINI_KOY]" width="250"> | <img src="[BURAYA_PDF_EKRAN_GORUNTUSU_LINKINI_KOY]" width="250"> | <img src="[BURAYA_YONETIM_PANELI_LINKINI_KOY]" width="250"> |

---

👨‍💻 Geliştirici : 
Umutcan Tunç

LinkedIn: https://www.linkedin.com/in/umutcan-tunç-b44979331/?skipRedirect=true
GitHub: @umutcantunc
