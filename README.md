# IT-HELPDESK

## Teknologi dan arsitektur

Aplikasi menggunakan Flutter dan Firebase Authentication/Cloud Firestore. GoRouter menangani navigasi dan redirect berdasarkan sesi yang dikelola oleh `AuthProvider`.

State management dibagi sesuai tanggung jawab:

- **Provider (`AuthProvider`)** menyimpan sesi global dan menyediakan status pengguna untuk GoRouter.
- **Cubit (`LoginCubit`)** mengelola proses Login dan pengiriman ulang email verifikasi. Tombol Masuk memanggil `login()`, lalu UI merespons state yang dipancarkan.

`LoginCubit` tidak memanggil Firebase secara langsung. Proses autentikasi tetap melalui `AuthProvider.signIn()`, sehingga pembaruan sesi dan redirect tetap menggunakan mekanisme aplikasi yang sudah ada.

## Registrasi dan Login

- Field wajib menampilkan tanda `*`. Pesan error, sukses, dan informasi
  menggunakan komponen `AlertBanner` yang seragam.
- Saat pendaftaran karyawan, email dibatasi ke penyedia yang diizinkan.
  Akun lama tetap dapat Login; filter ini tidak diterapkan pada proses Login.
- Setelah karyawan mendaftar dan profilnya tersimpan, aplikasi mengirim email verifikasi lalu mengakhiri sesi. Pengguna kembali ke Login untuk membuka tautan verifikasi (periksa juga folder Spam) sebelum masuk.
- Karyawan dengan akun yang dibuat setelah 29 Oktober 2026 pukul 22.30 WIB wajib memverifikasi email. Jika email belum diverifikasi, Login menolak akses dan menyediakan tombol **Kirim ulang email verifikasi**.
- Akun yang dibuat sebelum cutoff dibebaskan dari kewajiban verifikasi agar akun lama tetap dapat digunakan. Admin juga selalu dibebaskan, termasuk akun admin yang dibuat manual dan belum berstatus terverifikasi.
- Reset password tetap menggunakan alur yang sama seperti sebelumnya.

### Penyedia email pendaftaran

Daftar domain berada di `lib/core/constants/app_constants.dart`, pada
`AppConstants.allowedEmailDomains`:

- `gmail.com`, `googlemail.com`
- `yahoo.com`, `yahoo.co.id`, `ymail.com`
- `outlook.com`, `hotmail.com`, `live.com`, `msn.com`
- `icloud.com`, `me.com`
- `proton.me`, `protonmail.com`

Email dengan domain yang berakhiran `.ac.id`, `.sch.id`, `.go.id`, atau
`.co.id` juga diterima. Tambahkan domain penyedia/perusahaan pada daftar
tersebut untuk mengubah domain yang diizinkan. Pemeriksaan memangkas spasi dan
tidak membedakan huruf besar/kecil. Filter hanya berlaku saat pendaftaran.

### FAQ

**Apakah email wajib aktif?**  
Karyawan baru yang mendaftar setelah cutoff wajib memverifikasi email sebelum Login. Akun lama (dibuat sebelum cutoff) dan akun admin dikecualikan.

## Dependensi

- `provider`: sesi global dan integrasi state dengan GoRouter.
- `flutter_bloc`: Cubit untuk mengelola state proses login.
- `go_router`: navigasi dan redirect berbasis sesi.
- Firebase Authentication dan Cloud Firestore: autentikasi serta data aplikasi.

## Komponen dan navigasi

- `lib/widgets/helpdesk_widgets.dart`: `AlertBanner` (error/success/info),
  `RequiredFieldLabel`, `showConfirmDialog`, `TicketActionButton`, `EmptyState`,
  kartu tiket, dan navigasi bawah.
- `lib/core/constants/app_constants.dart`: konstanta domain email yang
  diizinkan.
- `lib/core/utils/form_validators.dart`: validasi form dan email pendaftaran.
- `lib/services/auth_service.dart`: pemeriksaan domain email kedua sebelum
  pembuatan akun.
- `lib/features/auth/auth_screens.dart`: formulir Login, Daftar, dan Lupa
  Password.
- `lib/features/employee/employee_screens.dart`: formulir tiket, detail,
  profil, dan pemberitahuan.
- `lib/features/admin/admin_screens.dart`: layar dan laporan admin.
- `test/form_validators_test.dart` dan `test/widgets_test.dart`: tes validasi
  dan widget.

Indikator navigasi bawah mengikuti route GoRouter yang sedang aktif untuk
karyawan maupun admin.

## Pengujian dan build APK

Jalankan validasi dan seluruh tes:

```bash
flutter analyze
flutter test
```

Suite saat ini berisi **37 tes**. APK rilis dibuat terpisah per ABI:

```bash
flutter build apk --release --split-per-abi
```

Hasil berada di `build/app/outputs/flutter-apk/`:

- `app-arm64-v8a-release.apk` — **19,99 MB**, untuk kebanyakan HP Android
  modern.
- `app-armeabi-v7a-release.apk` — **17,71 MB**.
- `app-x86_64-release.apk` — **21,41 MB**.

APK universal sebelumnya berukuran **55,50 MB**. Perbandingan build split:

| ABI | Sebelum shrink | Sesudah shrink |
|---|---:|---:|
| `armeabi-v7a` | 17,71 MB | 17,71 MB |
| `arm64-v8a` | 19,99 MB | 19,99 MB |
| `x86_64` | 21,41 MB | 21,41 MB |

Pemisahan ABI mengurangi ukuran unduhan per perangkat; shrink tidak mengurangi
ukuran terukur karena native library mendominasi. Pada analisis arm64, direktori
`lib/arm64-v8a` sekitar 18 MB dari total APK analisis 20,3 MB; simbol Dart AOT
sekitar 7 MB sebelum kompresi. Build memakai consumer rules bawaan Firebase
dan berhasil dibuat dengan shrink aktif.

## Penghapusan Tiket dan Pemberitahuan

- Karyawan dapat menghapus tiket miliknya sendiri hanya saat status Menunggu. Penghapusan bersifat permanen, termasuk seluruh riwayat status, dan tidak mengirim pemberitahuan.
- Admin dapat menghapus tiket dalam perusahaannya saat status Menunggu atau Dibatalkan, dengan alasan wajib sepanjang 1–300 karakter. Tiket Diproses dan Selesai tidak dapat dihapus agar riwayat dan laporan tetap utuh.
- Penghapusan oleh admin membuat pemberitahuan di dalam aplikasi untuk pemilik tiket. Pemberitahuan tidak dikirim melalui push notification atau Cloud Functions.
- Terapkan aturan dan indeks Firestore dengan `firebase deploy --only firestore:rules,firestore:indexes`.

## Keterbatasan validasi

Filter domain email pendaftaran dan kebijakan verifikasi email diperiksa oleh
aplikasi. Keduanya **belum diterapkan di Firestore Rules**; aturan Firestore
tidak diubah oleh perubahan UI/validasi ini.
