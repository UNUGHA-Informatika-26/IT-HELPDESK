# Keputusan Implementasi

- Struktur yang sudah tersedia adalah project Flutter Android dengan konfigurasi FlutterFire untuk `it-helpdesk-flutter`; proyek dipertahankan, bukan dibuat ulang.
- Kode registrasi dibaca sebagai ID dokumen dari `company_codes` lewat satu operasi `get`. UI tidak memuat kode awal perusahaan dan tidak membuat dokumen perusahaan.
- `TicketUpdate` digunakan untuk perubahan status yang dilakukan Admin, sesuai aturan data `adminId`/`adminName` dan persyaratan satu `WriteBatch`. Status awal tiket ditampilkan dari tiket itu sendiri; pembatalan oleh karyawan memperbarui status, tanpa membuat catatan admin palsu.
- Statistik ringkasan menggunakan Firestore aggregate `count()` per status. Pencarian tiket dan hitung kategori laporan dilakukan pada data yang sudah dimuat.
- Rentang tanggal laporan inklusif pada tanggal akhir; query Firestore menggunakan batas atas eksklusif pada tengah malam setelah tanggal akhir.
- Profil pengguna yang hilang atau memiliki role di luar `user`/`admin` ditolak aksesnya dan sesi Auth dibersihkan; Rules tetap menjadi batas keamanan utama.
- Karyawan hanya dapat menghapus tiket miliknya berstatus Menunggu. Admin hanya dapat menghapus tiket satu perusahaan berstatus Menunggu atau Dibatalkan dan wajib memberi alasan 1–300 karakter; tiket Diproses/Selesai dipertahankan agar riwayat dan laporan utuh.
- Penghapusan tiket menghapus seluruh subkoleksi `updates` secara permanen. Penghapusan oleh admin membuat pemberitahuan dalam aplikasi untuk pemilik tiket; tidak ada push notification atau Cloud Functions.
