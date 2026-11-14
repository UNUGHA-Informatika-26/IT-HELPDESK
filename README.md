# IT-HELPDESK

## Teknologi dan arsitektur

Aplikasi menggunakan Flutter dan Firebase Authentication/Cloud Firestore. GoRouter menangani navigasi dan redirect berdasarkan sesi yang dikelola oleh `AuthProvider`.

**Platform utama: Android (native, dikompilasi dari Flutter). Versi web hanya tambahan untuk uji cepat.**

State management dibagi sesuai tanggung jawab:

- **Provider (`AuthProvider`)** menyimpan sesi global dan menyediakan status pengguna untuk GoRouter.
- **Cubit (`LoginCubit`)** mengelola proses Login dan pengiriman ulang email verifikasi. Tombol Masuk memanggil `login()`, lalu UI merespons state yang dipancarkan.
- **Cubit (`ConnectivityCubit`)** melaporkan perubahan konektivitas; kegagalan Firestore juga menandai aplikasi offline.
- **TicketProvider** memuat cache lokal lebih dahulu, lalu menyegarkan tiket dari stream Firestore.

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
- `sqflite` dan `path`: cache SQLite lokal di Android/iOS.
- `connectivity_plus`: perubahan status konektivitas.
- `sqflite_common_ffi` (dev): menjalankan tes SQLite desktop.

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
- `lib/data/local/`: database SQLite, cache lokal, mapper, serta pemilih cache SQLite/no-op untuk web.
- `lib/features/connectivity/connectivity_cubit.dart`: status jaringan online/offline.
- `test/local_cache_test.dart` dan `test/ticket_provider_offline_test.dart`: tes penyimpanan lokal dan antrean offline.
- `test/form_validators_test.dart` dan `test/widgets_test.dart`: tes validasi
  dan widget.

Indikator navigasi bawah mengikuti route GoRouter yang sedang aktif untuk
karyawan maupun admin.

## Penyimpanan Offline dan Mitigasi Risiko

Fitur offline mengurangi risiko koneksi internet terputus saat karyawan melihat atau mengirim perubahan tiket. Cache tiket dan hitungan disimpan lokal; `TicketProvider` menampilkan cache terlebih dahulu (stale-while-revalidate), lalu mendengarkan stream Firestore dan memperbarui cache ketika data server tersedia. Data lokal dan antrean dipisahkan berdasarkan UID. Saat logout, cache dan antrean UID tersebut dibersihkan agar tidak terbawa ke akun berikutnya. Aturan dan struktur dokumen Firestore serta logika bisnis yang ada tidak diubah.

### Teknologi dan tabel lokal

Android/iOS memakai SQLite melalui `sqflite`; mapper pada `lib/data/local/local_model_mapper.dart` menjadi satu tempat konversi model ke/dari map SQLite. Database `helpdesk.db` memiliki tabel:

| Tabel | Data yang disimpan |
| --- | --- |
| `tickets` | Salinan tiket, UID pemilik, perusahaan, nomor, isi, kategori, prioritas, status, waktu dibuat/diubah, dan waktu sinkronisasi. |
| `ticket_updates` | Riwayat perubahan tiket yang telah tersedia. |
| `profile` | JSON profil per UID. |
| `counts` | Hitungan dashboard per UID dan status (termasuk total). |
| `outbox` | Aksi offline, payload, waktu antre, status `pending`/`failed`, jumlah percobaan, dan pesan kesalahan. |

### Antrean dan sinkronisasi

Buat, edit, dan batalkan tiket karyawan saat offline akan mengubah tampilan secara optimistis dan menyimpan aksi ke `outbox`. Tiket lokal muncul di bagian atas daftar dengan ikon jam. Setelah Firestore mengonfirmasi, indikator centang tampil singkat; kegagalan permanen menampilkan ikon seru dan pilihan untuk mencoba lagi atau membuang antrean. ID dokumen tiket dibuat di klien dan dipakai ulang saat sinkronisasi supaya retry pembuatan tidak menghasilkan tiket duplikat.

Sinkronisasi berjalan satu proses pada satu waktu, berurutan FIFO. Pemicu sinkronisasi adalah aplikasi dibuka, jaringan kembali online, dan aplikasi masuk foreground. Item gagal dicoba kembali dengan jeda 5, 15, lalu 60 detik selama aplikasi tetap terbuka. Gangguan jaringan mempertahankan item untuk dicoba ulang. Jika edit/batal ditolak karena tiket sudah diproses admin atau tiket tidak ditemukan, item ditandai gagal dan tampilan dikembalikan ke data server terbaru; kegagalan konflik tidak diulang tanpa batas.

Penghapusan tiket karyawan, semua aksi admin, dan laporan tidak masuk antrean. Aksi tersebut membutuhkan internet; ketika offline tombol dinonaktifkan dan aplikasi menjelaskan bahwa koneksi diperlukan karena tindakan dapat sulit dibatalkan atau menimbulkan konflik. Di daftar tiket, banner offline berbunyi **“Mode offline - menampilkan data tersimpan.”** Hitungan dashboard menggunakan nilai tersimpan ketika query Firestore gagal.

### Keterbatasan dan demo

Pengiriman otomatis hanya berjalan ketika aplikasi terbuka atau dibuka kembali; pengiriman latar belakang ketika aplikasi ditutup belum didukung. Pada Web, `NoopLocalCache` dipakai agar build web tetap tersedia, sehingga cache SQLite dan antrean offline tidak tersedia di sana. Konektivitas yang terdeteksi tidak menjamin internet benar-benar dapat menjangkau Firestore; kegagalan Firestore tetap diperlakukan sebagai offline. Notifikasi lokal tidak disertakan.

Untuk demo mode pesawat di Android: buka aplikasi dan muat data tiket saat online; aktifkan mode pesawat; buat atau ubah/batalkan tiket berstatus Menunggu dan amati ikon jam; matikan mode pesawat dan tunggu sinkronisasi; pastikan tiket muncul dari server dengan ikon centang sementara, lalu ikon menghilang. Pengiriman otomatis juga dapat dipicu dengan membawa aplikasi kembali ke foreground.

## Pengujian dan build APK

Jalankan validasi dan seluruh tes:

```bash
flutter analyze
flutter test
```

Seluruh **55 tes Flutter** lulus, termasuk cache SQLite, isolasi UID/logout,
konektivitas, antrean FIFO, retry, konflik, serta komponen UI offline. Build web
dan APK rilis split juga diverifikasi:

```bash
flutter build web
flutter build apk --release --split-per-abi
```

Hasil berada di `build/app/outputs/flutter-apk/`:

| ABI | Sebelum perubahan (bytes / MiB) | Sesudah perubahan (bytes / MiB) |
|---|---:|---:|
| `armeabi-v7a` | 18.567.767 / 17,70 | 18.843.385 / 17,97 |
| `arm64-v8a` | 21.027.981 / 20,05 | 21.254.447 / 20,27 |
| `x86_64` | 22.446.224 / 21,41 | 22.738.222 / 21,68 |

Ukuran sebelum diambil dari APK yang tersedia sebelum build ulang; ukuran
sesudah diambil dari artefak hasil build rilis di atas. Tiap ABI bertambah
sekitar 0,22–0,28 MiB, terutama karena dependensi SQLite/konektivitas dan
kode offline. MiB dihitung dari byte dibagi 1.048.576.

## Penghapusan Tiket dan Pemberitahuan

- Karyawan dapat menghapus tiket miliknya sendiri hanya saat status Menunggu. Penghapusan bersifat permanen, termasuk seluruh riwayat status, dan tidak mengirim pemberitahuan.
- Admin dapat menghapus tiket dalam perusahaannya saat status Menunggu atau Dibatalkan, dengan alasan wajib sepanjang 1–300 karakter. Tiket Diproses dan Selesai tidak dapat dihapus agar riwayat dan laporan tetap utuh.
- Penghapusan oleh admin membuat pemberitahuan di dalam aplikasi untuk pemilik tiket. Pemberitahuan tidak dikirim melalui push notification atau Cloud Functions.
- Terapkan aturan dan indeks Firestore dengan `firebase deploy --only firestore:rules,firestore:indexes`.

## Keterbatasan validasi

Filter domain email pendaftaran dan kebijakan verifikasi email diperiksa oleh
aplikasi. Keduanya **belum diterapkan di Firestore Rules**; aturan Firestore
tidak diubah oleh perubahan UI/validasi ini.
