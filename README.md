# Venus JMI Group — Migrasi Android Native ke Flutter

Dokumen inventaris fungsi & fitur aplikasi lama `VenusERPJMGroup_Client` (Android Java) sebagai acuan migrasi ke project Flutter `venus_jmi_group`.

> **Status saat ini:** project Flutter masih template bawaan (`lib/main.dart` = counter app, `pubspec.yaml` hanya `flutter` + `cupertino_icons`). Belum ada fitur bisnis yang dimigrasi.

---

## 1. Ringkasan Aplikasi

Aplikasi **B2B customer self-ordering** untuk grup perusahaan JMI. Customer yang sudah terdaftar dapat:

1. Memilih perusahaan/bisnis (multi-company).
2. Login / registrasi akun customer.
3. Melihat profil & limit piutang (AR Limit).
4. Menelusuri katalog produk, memasukkan ke cart, dan submit Purchase Order (PO).
5. Memantau status pesanan sampai terkirim.
6. Melihat laporan mutasi piutang (AR History / AR Aging).

| Aspek | Aplikasi Lama |
|---|---|
| Nama aplikasi | PT. Jaya Makmur Indonesia (`app_name`) |
| Package / Application ID | `com.Sinergi.VenusERPJMGroup_Client` |
| Versi | `versionName 3.0` / `versionCode 3` |
| Bahasa & UI | Java, XML Layout, Fragment + Navigation Drawer |
| Min / Target SDK | 26 / 35, Java 8, AGP 8.7.2 |
| Backend | SOAP Web Service ASMX (.NET) — `mobileservices.asmx` |
| Total source | 118 file Java, 39 layout XML |

---

## 2. Multi-Company (Pilih Bisnis di Splash)

User memilih logo perusahaan sebelum login. Pilihan ini menentukan database bisnis (`sBisnis`), base URL server, nama perusahaan, logo, dan folder gambar produk.

| Kode Bisnis (`APP_BISNIS`) | Perusahaan (`APP_NAME_COMPANY`) | Singkatan | Folder Gambar |
|---|---|---|---|
| `VenusERP10` | PT Jaya Makmur Indonesia | `JMI` | `JMI_Images/` |
| `VenusERP21` | PT Mega Cahaya Cilacap | `MCC` | `MCC_Images/` |
| `VenusERP25` | PT Mainan Mandiri Indonesia | `MMI` | `MMI_Images/` |

Mapping kode bisnis → server **tidak hardcode**, diambil dari SOAP `GetDataBisnis`:

- `Pref1` → daftar kode bisnis (dipisah `|`)
- `Pref2` → daftar nama bisnis (dipisah `|`)
- `Pref3` → daftar host server (dipisah `|`)

URL efektif per bisnis: `http://<host>/VenusERPJMIGroupClientMServices/mobileservices.asmx`

---

## 3. Arsitektur Aplikasi Lama

```
app/src/main/java/com/Sinergi/VenusERPJMGroup_Client/
├── screen/      (26)  Activity & Fragment — semua layar UI
├── adapter/     (14)  RecyclerView/ListView adapter
├── module/      (21)  Model UI, DBHendle (SQLite), helper (GeneralModul, dsb.)
├── envelopes/   (31)  Builder XML request SOAP per operasi
├── domain/      (19)  Model response SOAP (umumnya field generik Pref1..PrefN)
├── dao/         (2)   RequestFactory + RequestFactoryImpl (definisi semua SOAP call)
└── guice/       (2)   AppPreferences (SharedPreferences + session) & StandardModule
```

### Pola yang dipakai

| Kebutuhan | Implementasi Lama |
|---|---|
| Networking SOAP | IceSOAP (`com.alexgilleran.icesoap`) via `RequestFactoryImpl` |
| Networking lain | Volley (terdaftar, pemakaian minimal) |
| Gambar | Picasso, PhotoView (zoom), ImageSlideshow, AndroidImagePopup |
| Penyimpanan sesi | `SharedPreferences` via `AppPreferences` |
| Database lokal | SQLite mentah via `DBHendle` (nama DB: `VenusERPJMGroup_Client`) |
| Navigasi | `MainActivity.displayView(int)` — routing berbasis integer (`res/values/integer.xml`) |

### Usulan padanan di Flutter

| Lama | Flutter |
|---|---|
| `screen/*Activity/Fragment` | `lib/features/<fitur>/presentation/pages/` |
| `dao/RequestFactory(Impl)` | `lib/features/<fitur>/data/datasources/` (SOAP client) |
| `envelopes/*` | Builder XML request di datasource / `lib/core/network/soap/` |
| `domain/*Pref` | `lib/features/<fitur>/data/models/` + entity di `domain/` |
| `module/*Item` | Model/entity Dart |
| `adapter/*` | `ListView.builder` / `GridView.builder` + widget item |
| `AppPreferences` | `shared_preferences` (non-sensitif) + `flutter_secure_storage` (kredensial) |
| `DBHendle` (SQLite) | `sqflite` dengan skema tabel yang sama |
| Picasso / PhotoView / Slideshow | `cached_network_image` / `photo_view` / `carousel_slider` |

---

## 4. Alur Aplikasi

```
SplashActivity
  ├─ getVersi() → cek versi; jika versi server lebih baru & wajib → buka Play Store
  ├─ getBisnis() → muat mapping kode bisnis → server
  ├─ Pilih logo perusahaan (JMI / MCC / MMI) → simpan APP_SERVER, APP_BISNIS, APP_BISNISNAME
  └─ Cek M_LOGIN → sesi "YES" ? MainActivity : LoginActivity

LoginActivity
  ├─ onLogin → getCatagory() (cache M_CATEGORY) → getLogin(user, pwd)
  ├─ onRegis → RegActivity → (wajib centang) RegulasiActivity (Syarat & Ketentuan)
  └─ Sukses → MainActivity

MainActivity (Navigation Drawer + ActionBar: Cart, Logout)
  ├─ 0  Profile          → HomeFragment
  ├─ 1  Pemesanan        → ListProduct → DetailProductFragment
  ├─ 2  Status Pemesanan → StatusMainFragment (4 tab)
  ├─ 3  Mutasi Rekening  → FilteringMutationFragment → ReportARHistoryFragment
  ├─ 4  Cart List        → ListCart → SubmitOrderFragment
  └─ 5  Pengaturan       → SettingFragment → ChangePwdFragment
```

Routing internal non-drawer (integer → layar): `50` Detail Produk, `51` Submit Order, `52` Data Order, `53` Data Proses, `54` Data Delivery, `55` Data History, `56` Change Password, `31` AR History, `101` Home.

Logout: hapus **semua** tabel SQLite (`deleteTable "All"`) + `clearDataLogin()` → kembali ke Splash.

---

## 5. Detail Fitur per Layar

### 5.1 Splash (`SplashActivity`)
- Cek versi aplikasi ke server (`Versi`, parameter `packageName`); format response `versionCode/versionName/forceUpdate`. Jika lebih baru dan `forceUpdate = True` → arahkan ke Play Store.
- Ambil daftar bisnis (`GetDataBisnis`) untuk mapping kode bisnis → host server.
- Pilih perusahaan via logo JMI / MCC / MMI; sebelum memilih, sesi lama dibersihkan (`clearData()`).
- Auto-login: jika tabel `M_LOGIN` berisi `Login = YES`, sesi dipulihkan dari SQLite ke `AppPreferences` lalu masuk `MainActivity`.

### 5.2 Login (`LoginActivity`)
- Input username & password; validasi tidak boleh kosong dan perangkat harus online.
- Urutan call: `GetDataProdCat` (kategori disimpan ke `M_CATEGORY`) → `Login`.
- Response `Login` (`Pref1..Pref15`) disimpan sebagai sesi:

| Pref | Arti | Key `AppPreferences` |
|---|---|---|
| Pref1 | Kode cabang (BusCode) | `USER_BUSCODE` |
| Pref2 | Nama cabang (BusName) | `USER_BUSNAME` |
| — (input) | Username | `USER_USERNAM` |
| Pref4 | Kode customer | `USER_CUSTCODE` |
| Pref5 | Nama customer | `USER_CUSTNAME` |
| Pref6 | Nama user (SName) | `USER_SNAME` |
| Pref7 | Telepon | `USER_PHONE` |
| Pref8 | Email | `USER_EMAIL` |
| Pref9 | Alamat | `USER_ADDRESS` |
| Pref10 | TOP (term of payment) | `USER_TOP` |
| Pref11 | Group/AR global limit | `USER_GROUPLIMIT` |
| Pref12 | Individual limit | `USER_INDLIMIT` |
| Pref13 | Sisa AR limit | `USER_ARLIMIT` |
| Pref14 | Kode sales | `USER_SALESCODE` |
| Pref15 | AR overdue | `USER_AROVERDUE` |

- Sesi juga ditulis ke tabel `M_LOGIN` untuk auto-login.
- Tombol registrasi → `RegActivity`; tombol back → Splash (ganti perusahaan).

### 5.3 Registrasi (`RegActivity` + `RegulasiActivity`)
- Field: ID Number, Username, Password + konfirmasi, Nama, Telepon, Email, Tanggal Lahir (date picker), Alamat, TOP (spinner dari `GetDataTOP`).
- Wajib mencentang persetujuan Syarat & Ketentuan (`RegulasiActivity`, teks regulasi statis di layout) sebelum submit.
- Submit via `UploadUserReg` (9 parameter + `sBisnis`).

### 5.4 Profile / Home (`HomeFragment`)
- Header logo sesuai perusahaan terpilih; menampilkan nama bisnis, nama user, username, customer, telepon, email, alamat.
- Kartu limit piutang diperbarui realtime via `GetDataARLimit(branch, custCode)`:
  - `Pref1` AR Global, `Pref2` AR Limit, `Pref3` AR Overdue, dan sisa limit (dihitung dari ketiganya).

### 5.5 Pemesanan — Daftar Produk (`ListProduct`)
- Grid 2 kolom; pencarian berdasarkan nama / kode / alias produk (tombol search di keyboard / clear search).
- **Cache-first:** data dibaca dulu dari SQLite `M_PRODUCT`; jika kosong/sedikit, ambil dari server `GetDataProductList200902` lalu disimpan ke `M_PRODUCT`.
- Pagination *endless scroll* berbasis kode produk terakhir (`prmLastCode`).
- Filter gabungan:
  - Kategori favorit: hanya `M_CATEGORY.IsFavorite = 1` (diatur di Pengaturan).
  - Status stok sesuai preferensi tampil: In Stock (`Stock > 0`), Sold Out (`Stock = 0`), Coming Soon (`Stock = -1`).
- Klik produk → Detail Produk.

### 5.6 Detail Produk (`DetailProductFragment`)
- Image slider dari daftar `ImageURL` (dipisah `|`) pada folder gambar sesuai perusahaan; klik gambar → popup zoom.
- Detail tambahan dari `GetDataProductDetail`: `Pref1` Dimensi, `Pref2` Kubikasi, `Pref3` UOM Primer, `Pref4` List Price, `Pref5` Stok.
- Atur QTY (+/−), divalidasi terhadap stok/QTY2.
- **Add/Update Cart** → simpan ke `H_CART`; **Buy Now** → langsung ke Submit Order dengan bundle produk tsb.

### 5.7 Cart (`ListCart`)
- Daftar isi `H_CART`, ubah QTY per item, hapus item, total harga otomatis.
- Klik gambar item → kembali ke Detail Produk mode edit (`FromCart = true`).
- Checkout (total > 0) → Submit Order.

### 5.8 Submit Order (`SubmitOrderFragment`)
- Sumber item: seluruh `H_CART`, atau 1 produk dari Buy Now.
- Stok semua item dicek ulang via `GetDataStock`; item stok `0`/`-1` memblokir order ("Invalid stock!").
- Form: Tanggal Pengiriman (date picker), Periode (`Pagi/Siang/Sore`), Interval (`1x/2x/3x/Titip dengan proforma Inv`), TOP (dari `GetDataTOP`, default TOP user), Notes.
- Total = Σ (QTY × faktor UOM × harga). Banyak item digabung menjadi string: kode dipisah `,`, QTY & harga dipisah `|`.
- Submit 1x call `UploadPOCustomer` dengan `prmEONumber = ""` (order baru).
- `DataOrderFragment` memakai call yang sama dengan `prmEONumber` terisi untuk **mengubah order** yang sudah ada.

### 5.9 Status Pemesanan (`StatusMainFragment`)
4 tab, masing-masing daftar header order → klik masuk ke detail itemnya:

| Tab | SOAP List | SOAP Detail | Keterangan |
|---|---|---|---|
| Order Received | `GetDataStatusOrder` | `GetDataOrder` | Order masuk |
| Order on Process | `GetDataStatusProses` | `GetDataProses` | Sedang diproses |
| Order has been sent | `GetDataStatusDelivery` | `GetDataDelivery` | Terkirim |
| Order History | `GetDataStatusHistory` | `GetDataHistory` | Riwayat selesai |

Model list: `StatusOrderItem`, `StatusProsesItem`, `StatusDeliveryItem`, `StatusHistoryItem`; model detail memakai `OrderItem`/`CartItem`.

### 5.10 Mutasi Rekening (`FilteringMutationFragment` → `ReportARHistoryFragment`)
- Filter: Jenis Laporan (`AR History` / `AR Aging`), Tanggal Awal, Tanggal Akhir (default: awal–akhir bulan berjalan; date picker).
- Call: `GetRpt6Pref` (AR History, response `Report6Pref`) atau `GetRpt3Pref` (AR Aging, response `Report3Pref`), parameter `prm1 = branch`, `prm2 = custCode`, `prm3 = "1"`.
- Hasil dirender sebagai tabel dinamis (`TableLayout`) dari array `Pref1..Pref6` / `Pref1..Pref3` yang dipisah `|`, disimpan sementara di `AppPreferences` (`saveData6PrefReport` / `saveData3PrefReport`).

### 5.11 Pengaturan (`SettingFragment` + `ChangePwdFragment`)
- Toggle tampil produk: In Stock / Sold Out / Coming Soon → `VIEWINSTOCK` / `VIEWSOLDOUT` / `VIEWCOMINGSOON`.
- Grid kategori favorit (checkbox) → `M_CATEGORY.IsFavorite`; dipakai sebagai filter di Daftar Produk. Jika lokal kosong, ambil dari `GetDataProdCat`.
- Tombol Change Password → `ChangePwdFragment`: input password baru → `UploadNewPassword(user, newPassword)`.

---

## 6. API SOAP (Backend)

**Endpoint default (versi & bisnis):**
`http://production2.sinergiteknologi.co.id/VenusERPJMIGroupClientMServices/mobileservices.asmx`

**Endpoint per bisnis (semua call lain):** `http://<APP_SERVER>/VenusERPJMIGroupClientMServices/mobileservices.asmx`

Namespace SOAPAction: `http://VenusERPJMIGroupClientMServices.org/<Operasi>`. Semua request selalu menyertakan parameter pertama `sBisnis`, kecuali `Versi` & `GetDataBisnis` yang memakai `packageName`.

Response bersifat generik: field bernama `Pref1..PrefN` (atau `Code`/`Name`, `Versi`, `Status`) berisi string yang sering dikodekan lagi dengan pemisah `|` — arti tiap posisi Pref **hanya diketahui dari pemakaiannya di UI** (lihat tabel Login & fitur di atas sebagai referensi awal).

### 6.1 Operasi yang terdaftar di `RequestFactory` (29)

| # | Method Dart/Java | SOAP Action | Parameter (selain `sBisnis`) | Response | Dipakai di |
|---|---|---|---|---|---|
| 1 | `getVersi` | `Versi` | `packageName` | `Versi` | Splash |
| 2 | `getBisnis` | `GetDataBisnis` | `packageName`, `sBisnis` | `Report3Pref` | Splash |
| 3 | `getLogin` | `Login` | `sUser`, `sPwd` | `Login` (Pref1–15) | Login |
| 4 | `getProductList` | `GetDataProductList200902` | `prmUser`, `prmLastCode`, `prmParam`, `prmOrderBy`, `prmWhere`, `prmHaving` | `Report10Pref` | ListProduct |
| 5 | `getStock` | `GetDataStock` | `prmProdCode` (list `'KODE',...`) | `DataStock` | SubmitOrder |
| 6 | `getTOP` | `GetDataTOP` | — | `CodeName` | Reg, SubmitOrder, DataOrder |
| 7 | `getCatagory` | `GetDataProdCat` | — | `CodeName` | Login, Setting |
| 8 | `getDataARLimit` | `GetDataARLimit` | `prmBranchCode`, `prmCustCode` | `Report4Pref` | Home |
| 9 | `uploadPOCustomer` | `UploadPOCustomer` | `prmUserNam`, `prmBranchCode`, `prmCustCode`, `prmSendingPeriode`, `prmSendingInterval`, `prmDelDate`, `prmNotes`, `prmProdCode`, `prmQTY2`, `prmPrice`, `prmEONumber`, `prmTOP`, `prmSalesCode` | `Status` | SubmitOrder, DataOrder |
| 10 | `getDataProductDetail` | `GetDataProductDetail` | `prmUserNam`, `prmBranchCode`, `prmCode` | `Report5Pref` | Detail Produk |
| 11 | `getStatusOrder` | `GetDataStatusOrder` | `prmUserNam`, `prmBranchCode`, `prmCustCode` | `Report9Pref` | Status tab 1 |
| 12 | `uploadNewPassword` | `UploadNewPassword` | `prmUser`, `prmNewPassword` | `Status` | Change Password |
| 13 | `getDataOrder` | `GetDataOrder` | `prmUserNam`, `prmBranchCode`, `prmEONumber` | `Report8Pref` | Detail Order/Delivery/History |
| 14 | `getStatusProses` | `GetDataStatusProses` | `prmUserNam`, `prmBranchCode`, `prmCustCode` | `Report9Pref` | Status tab 2 |
| 15 | `getDataProses` | `GetDataProses` | `prmUserNam`, `prmBranchCode`, `prmEONumber` | `Report8Pref` | Detail Proses |
| 16 | `getStatusDelivery` | `GetDataStatusDelivery` | `prmUserNam`, `prmBranchCode`, `prmCustCode` | `Report10Pref` | Status tab 3 |
| 17 | `getDataDelivery` | `GetDataDelivery` | `prmUserNam`, `prmBranchCode`, `prmEONumber` | `Report8Pref` | Detail Delivery |
| 18 | `getStatusHistory` | `GetDataStatusHistory` | `prmUserNam`, `prmBranchCode`, `prmCustCode` | `Report10Pref` | Status tab 4 |
| 19 | `getDataHistory` | `GetDataHistory`* | `prmUserNam`, `prmBranchCode`, `prmEONumber` | `Report8Pref` | Detail History |
| 20 | `UploadUserReg` | `UploadUserReg` | `prmUserNam`, `prmUserPwd`, `prmIDNumber`, `prmCustName`, `prmPhone`, `prmEmail`, `prmBDay`, `prmAddress`, `prmTOP` | `Report1Pref` | Registrasi |
| 21 | `getReportARHistory` | `GetRpt6Pref` | `prmType`, `prmDate1`, `prmDate2`, `prm1`, `prm2`, `prm3` | `Report6Pref` | Mutasi Rekening |
| 22 | `getReportARAging` | `GetRpt3Pref` | `prmType`, `prmDate1`, `prmDate2`, `prm1`, `prm2`, `prm3` | `Report3Pref` | Mutasi Rekening |
| 23 | `UserStatus` | `GetStatusUser` | `prmBranch`, `prmUserNam` | `Status` | Terdaftar, tidak aktif dipakai |
| 24 | `getBranch` | `GetDataBranch` | — | `Branch` | Terdaftar, tidak dipakai UI |
| 25 | `getEmail` | `GetDataEmail` | — | `CodeName` | Terdaftar, tidak dipakai UI |
| 26 | `getCity` | `GetDataCity` | `prmProvince`, `prmLike` | `CodeName` | Terdaftar, tidak dipakai UI |
| 27 | `getRegion` | `GetDataRegion` | `prmProvince`, `prmCity`, `prmLike` | `CodeName` | Terdaftar, tidak dipakai UI |
| 28 | `getReport5Pref` | `GetRpt5Pref` | `prmType`, `prmDate1`, `prmDate2`, `prmProdCode`, `prmBranch`, `prmCustomer` | `Report5Pref` | Terdaftar, tidak dipakai UI |
| 29 | `getStatus` | `GetStatus` | — | `Status` | Terdaftar, tidak dipakai UI |

\* Di kode lama `getDataHistory()` keliru memakai envelope & SOAPAction `GetDataDelivery` — verifikasi ke backend sebelum dimigrasi (lihat §10).

### 6.2 URL Media (hardcode di `strings.xml`)

| Kebutuhan | URL |
|---|---|
| Gambar umum | `http://production2.sinergiteknologi.co.id/VenusERPJMIGroupClientMServices/Images/` |
| Gambar JMI | `.../JMI_Images/` |
| Gambar MCC | `.../MCC_Images/` |
| Gambar MMI | `.../MMI_Images/` |
| Video | `.../Video/` |

---

## 7. Penyimpanan Lokal

### 7.1 SQLite — `DBHendle` (7 tabel)

| Tabel | Kolom | Fungsi |
|---|---|---|
| `M_VERSION` | `Version` | Versi data lokal |
| `M_LOGIN` | `Login, BusCode, BusName, UserName, CustCode, CustName, SName, Phone, Email, Address, TOP, UserAut, BranchAut, Password` | Sesi auto-login |
| `H_CART` | `Code, Name, Price, Desc, QTY, ImageURL, UOM, Stock, Alias` | Keranjang belanja |
| `T_DETAILORDER` | `EONumber, Code, Name, Price, Desc, QTY, ImageURL, UOM` | Detail order |
| `M_PRODUCT` | `Code, Name, Price, Desc, DescUOM, Stock, ImageUrl, Category, SpecialPrice, Alias` | Cache katalog produk |
| `M_TOP` | `TOPCode, TOPName` | Cache term of payment |
| `M_CATEGORY` | `CatCode, CatName, IsFavorite` | Kategori + favorit |

### 7.2 SharedPreferences — `AppPreferences`

Key terpenting: `APP_SERVER`, `APP_BISNIS`, `APP_BISNISNAME`, `APP_NAME_COMPANY`, `APP_NAME_COMPANY_SINGKATAN`, `ISLOGIN`, `USER_*` (lihat tabel Login), `VIEWINSTOCK`, `VIEWSOLDOUT`, `VIEWCOMINGSOON`, `DATA_PRODLIST`, `MENU_NAME`, `MENU_POSITION`, `RPT_PREF1..11` (hasil laporan), `APP_RPT_RESULT`.

---

## 8. Inventaris File Lama → Target Migrasi

| Folder Lama | Jumlah | Isi | Target Flutter |
|---|---|---|---|
| `screen/` | 26 | 5 Activity (`Splash`, `Login`, `Reg`, `Regulasi`, `Main`) + 21 Fragment/helper | `features/*/presentation/pages/` |
| `adapter/` | 14 | Product, Cart, Order, Status (4), Category, NavDrawer, ImageSlider, dsb. | Widget item per fitur |
| `module/` | 21 | `ProductItem`, `CartItem`, `OrderItem`, `Status*Item`, `DBHendle`, `GeneralModul`, dsb. | `core/` + model per fitur |
| `envelopes/` | 31 | Builder XML SOAP (termasuk 2 tak terpakai: `ProductEnvelope`, `RegCustomerEnvelope`) | `core/network/soap/` |
| `domain/` | 19 | `Login`, `Versi`, `Status`, `CodeName`, `Branch`, `DataStock`, `Report1/3/4/5/6/8/9/10/11Pref`, dsb. | `data/models/` per fitur |
| `dao/` | 2 | `RequestFactory`, `RequestFactoryImpl` | `core/network/soap_client.dart` + repository |
| `guice/` | 2 | `AppPreferences`, `StandardModule` | `core/storage/` + DI |
| `res/layout/` | 39 | Layout per layar + item | Widget per fitur |

File di root package (`MainActivity.java`, `ExcampleItem.java`, `ExcampleAdaper.java`) adalah sisa contoh/duplikat — tidak perlu dimigrasi.

---

## 9. Rencana Tahapan Migrasi

- [x] **Fase 0 — Fondasi:** struktur folder fitur, routing, tema (warna/logo per perusahaan), env config (base URL & URL media), SOAP client (POST XML + parse response), format Rupiah/tanggal (`intl`).
- [x] **Fase 1 — Sesi:** Splash (cek versi + pilih bisnis + auto-login), Login, Registrasi + Regulasi, simpan sesi (secure storage untuk password/token).
- [x] **Fase 2 — Katalog:** cache SQLite produk/kategori, Daftar Produk (search, filter kategori favorit & stok, pagination), Detail Produk (slider, zoom, stok).
- [x] **Fase 3 — Order:** Cart lokal, Submit Order (cek stok, form pengiriman, `UploadPOCustomer`), edit order.
- [x] **Fase 4 — Status:** 4 tab status pesanan + detail per tahap.
- [x] **Fase 5 — Laporan & Akun:** Mutasi Rekening (AR History/Aging + tabel dinamis), Pengaturan (filter stok & kategori favorit), Change Password, Profile + AR Limit.
- [x] **Fase 6 — Hardening:** parameterized query, error handling SOAP, widget test untuk parser SOAP & model produk, build APK terverifikasi. HTTPS belum aktif di backend (masih HTTP + cleartext), menunggu kesiapan server.

Dependency Flutter yang perlu ditambahkan ke `pubspec.yaml` (padanan library lama): `http` (SOAP), `xml`, `sqflite`, `shared_preferences`, `flutter_secure_storage`, `cached_network_image`, `photo_view`, `carousel_slider`, `intl`.

---

## 10. Catatan & Risiko Migrasi

1. **Response `Pref1..PrefN` tidak terdokumentasi.** Arti setiap posisi hanya bisa dipastikan dari kode UI lama dan/atau contoh response asli server. Ambil sample response tiap operasi sebelum menulis model Dart.
2. **Bug lama jangan disalin mentah:**
   - `getDataHistory()` memakai SOAPAction `GetDataDelivery`.
   - Tab Order History membuka layar Data Delivery.
   - `DataDeliveryFragment` & `DataHistoryFragment` memanggil `getDataOrder()`.
   - Alur `CheckUser()` di Splash perlu diuji ulang (percabangan auto-login membingungkan).
3. **Keamanan:** password disimpan plaintext di SharedPreferences & SQLite; semua trafik `http://` (cleartext, perlu `networkSecurityConfig` di Android / ATS di iOS). Di Flutter gunakan secure storage & pertimbangkan HTTPS.
4. **SQL rawan injection:** query lama dibangun dengan string concatenation (search, filter kategori, cart). Gunakan parameterized query di `sqflite`.
5. **Format tanggal tidak konsisten:** UI memakai `M/d/yyyy` untuk parameter SOAP laporan & tanggal kirim — pertahankan format yang sama sampai backend dikonfirmasi.
6. **Encoding multi-item order:** `UploadPOCustomer` mengharapkan string gabungan (kode `'A','B'`, QTY `1|2`, harga `1000|2000`) — format ini kontrak backend, jangan diubah.
7. **Stok semantik khusus:** `Stock = -1` berarti *coming soon*, `0` *sold out*, `> 0` *in stock* — dipakai untuk filter & validasi order.

---

## 11. Menjalankan Project Flutter

```bash
flutter pub get
flutter run
```

Target awal migrasi adalah Android (`applicationId` lama `com.Sinergi.VenusERPJMGroup_Client`, minSdk 26); folder platform lain (`ios/`, `web/`, `windows/`, `macos/`, `linux/`) masih bawaan template.
