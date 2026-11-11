# Laporan audit & pembangunan ulang Razarsa

> Dokumen teknis tentang perbaikan keamanan, penyimpanan, dan kestabilan sebelum rilis **v1.0.0**. Penyebutan "v1.2.1" berarti kode lama yang diaudit, dan "v2.0.0" berarti hasil pembangunan ulang yang dirilis sebagai v1.0.0.

## 1. Temuan dan perbaikan

Tingkat: **T** tinggi, **S** sedang, **R** rendah. Setiap perbaikan punya regression test (`test/security_test.dart`, `test/pin_pad_test.dart`, `test/store_test.dart`).

### Keamanan
| # | Tk | Temuan di v1.2.1 | Perbaikan v2.0.0 |
|---|---|---|---|
| S1 | T | Catatan "terkunci" tersimpan **polos** di penyimpanan, di cadangan otomatis, dan di file backup | AES-256-GCM per catatan (terikat ke id), kunci acak 256-bit di Android Keystore (`flutter_secure_storage`). Migrasi otomatis termasuk cadangan lama. Kunci hilang → catatan ditandai tak terbaca tapi **ciphertext tetap disimpan** |
| S2 | T | PIN tanpa batas percobaan, hanya 4 digit | Jeda 30 dtk/1/5/15/60 mnt setelah 5 salah (bertahan walau app ditutup), PIN baru 6 digit, PBKDF2 60.000 iterasi (hash lama otomatis naik), validasi 4–6 digit |
| S3 | S | Backup polos membocorkan isi catatan terkunci | Backup polos tidak memuat isinya; backup berkata sandi (AES-256-GCM, PBKDF2 210.000) wajib bila ada catatan terkunci |
| S4 | S | Isi aplikasi tampak di tangkapan layar & daftar aplikasi terbaru | `FLAG_SECURE` saat PIN aktif (ada saklar) |
| S5 | S | Notifikasi menampilkan judul agenda/tagihan di layar kunci | Visibilitas notifikasi `private` |
| S6 | S | CSV rawan injeksi rumus Excel (`=HYPERLINK(...)`) | Sel berawalan `= + - @` diberi petik |
| S7 | S | Impor backup tanpa validasi (ukuran, nominal, id kembar, versi) | Batas ukuran, nominal ±1 triliun, dedup id, tolak versi lebih baru, atomik; KDF dibatasi (anti file jebakan) |
| S8 | S | Mematikan PIN meninggalkan catatan terkunci yang tak bisa dibuka | Konfirmasi + kunci catatan otomatis dibuka; menu **Ganti PIN** tidak melepas kunci |
| S9 | R | Teks Kebijakan Privasi menyebut catatan belum dienkripsi | Diperbarui (ID/EN) sesuai perilaku baru |

### Penyimpanan & data
| # | Tk | Temuan | Perbaikan |
|---|---|---|---|
| D1 | T | **Crash saat start** bila `themeMode` di luar rentang / nilai salah tipe | Semua pembacaan bertipe-aman dengan nilai bawaan |
| D2 | S | Setiap perubahan menulis ±30 kunci tanpa antre, kegagalan diam | Antrean tunggal, hanya kunci berubah, `lastSaveError` |
| D3 | S | `newId()` bisa kembar (mikrodetik sama) → hapus satu menghapus dua | Id monoton |
| D4 | S | `firstWhere` melempar bila id sudah hilang (tekan ganda) | Aman: diabaikan |
| D5 | S | Nominal tanpa batas (overflow hitungan) | Dibatasi ±1 triliun |
| D6 | R | `rusak_*` (salinan data rusak) tidak ikut terhapus di "Hapus semua data" | Ikut dihapus |
| D7 | S | Data dari versi aplikasi lebih baru bisa tertimpa | Mode baca-saja bila `dataVersion` lebih tinggi |

### Keuangan, notifikasi, UI, CI/CD
| # | Tk | Temuan | Perbaikan |
|---|---|---|---|
| D8 | T | Impor backup, Pulihkan cadangan, dan Hapus semua data melaporkan "berhasil" **sebelum** tertulis ke penyimpanan (app mati tepat setelahnya = data lama/tak berubah, tanpa tanda gagal) | Baru dianggap sukses setelah penulisan selesai; gagal tulis dilaporkan (`saveFailed`) |
| D9 | S | "Hapus semua data" tidak lengkap: Catat Cepat buatan sendiri, bio, hari aktif/XP, dan jejak lain tersisa; cadangan otomatis berisi salinan penuh tanpa pilihan menghapusnya | Semua data pengguna direset; dialog menawarkan "Hapus, simpan cadangan" atau "Hapus permanen" (cadangan ikut hilang) |
| D10 | S | Backup/cadangan melewatkan pengaturan yang memengaruhi laporan (awal bulan anggaran, awal minggu, mata uang, bahasa, latar) dan profil (bio, hari bergabung, hari aktif) | Ikut dicadangkan (divalidasi saat impor); pengaturan keamanan (PIN, sidik jari, layar aman) sengaja tidak ikut |
| D11 | S | Cadangan otomatis tidak dibuat bila hanya ada transaksi berulang atau kategori buatan sendiri | Termasuk dalam pemeriksaan "ada data" |
| D12 | S | Migrasi v1->v2: bila cadangan hari itu sudah ada, kondisi sebelum migrasi tidak diamankan | Salinan pra-migrasi (catatan terkunci terenkripsi) selalu dibuat, kecuali ada data rusak (cadangan lama yang bagus tidak ditimpa) |
| F1 | T | Transaksi berulang **hilang** untuk bulan yang terlewat saat app tidak dibuka | Dicatat susulan (maks. 12 bulan), tidak ganda |
| F2 | R | Peringatan anggaran tak tersimpan → bisa berulang setelah restart | Disimpan |
| N1 | S | Notifikasi tagihan/agenda **menggantung** setelah hapus, impor, atau hapus semua data | Dibatalkan di semua jalur |
| N2 | R | Pengingat tagihan tanggal 1 jatuh di tanggal 1 tapi bertuliskan "Besok" | Teks "Hari ini" pukul 08.00 |
| U1 | S | Papan PIN overflow di layar pendek/landscape (tombol tak terjangkau) | Bisa digulir (terdeteksi tes widget) |
| U2 | T | Restore backup berisi catatan terkunci di HP **tanpa PIN**: catatan minta "Masukkan PIN" yang tidak ada, jadi tak bisa dibuka selamanya (terdeteksi saat uji UI) | Bila PIN belum ada, app menawarkan membuat PIN dulu lalu membuka catatan |
| U3 | R | Setelah PIN dibuat, app langsung meminta PIN itu lagi | Sesi tetap terbuka sampai app ditinggal >30 dtk |
| U4 | S | Pop up Catat Cepat (dengan tombol Batalkan) tidak pernah hilang: Flutter 3.29+ membuat SnackBar beraksi menetap | `persist: false` |
| U5 | S | Layout terpotong/overflow di font besar (1,5x) dan layar kecil: Beranda, Laporan, Target, Kalender, Tambah transaksi, Berulang, Beranda Produktif (banyak tombol/teks tak terjangkau) | Wadah tinggi-tetap kini ikut ukuran font; teks/tombol mengecil, bukan terpotong. Sapuan 20 halaman x 3 ukuran layar x 2 ukuran font x 2 tema x ID/EN |
| U8 | S | Layar masuk/daftar: saat keyboard terbuka seluruh kanvas 390x844 ikut mengecil (isian turun dari 23 ke ±10 px, 57% lebih kecil, tombol hampir tak terjangkau) | Hanya bagian isian + tombol yang ditampilkan dan tetap berukuran hampir normal di atas keyboard (layar 320-411 px, keyboard 250-320 px); tanpa keyboard tidak berubah |
| U9 | S | Kategori buatan sendiri bisa kembar (nama sama, beda huruf besar/kecil/spasi, atau sama dengan kategori bawaan) | Nama sama dengan kategori yang ada dipakai ulang (tanpa membedakan huruf/spasi), nama kosong jatuh ke "Lainnya", maksimal 16 karakter; UI memberi tahu "sudah ada, langsung dipilih" |
| U10 | S | Tombol Kembali sistem di tab selain Beranda langsung keluar aplikasi | Kembali ke Beranda dulu; dari Beranda baru keluar |
| U11 | R | Hapus tidak seragam: transaksi berulang dan tombol Catat Cepat terhapus tanpa konfirmasi, sedangkan hapus lain selalu meminta; dialog hapus berbeda-beda; istilah campur "To-do"/"Tugas" | Satu dialog hapus seragam (`confirmDelete`) di semua tempat; istilah "Tugas" (Tasks) di dock, judul, dan deskripsi mode |
| A1 | S | Login berpura-pura jadi akun: kolom kata sandi tidak diperiksa dan tidak disimpan, pesan "Email atau kata sandi belum benar" menyiratkan perlindungan, tombol Google/Lupa kata sandi hanya placeholder, dan "Keluar" bisa dimasuki lagi dengan email apa saja | Layar awal jadi **profil lokal** (nama, email opsional, PIN 6 angka + ulangi, karakter tetap beranimasi). Tidak ada akun/kata sandi/Google/Keluar; "Ubah nama & email" di Pengaturan. Kebijakan privasi dan ketentuan disesuaikan |
| F3 | S | Target tabungan hanya bisa ditambah; salah input tidak bisa dikoreksi, nama/target tidak bisa diubah | Ketuk: Tambah atau **Kurangi** (tidak boleh melebihi tabungan); tekan lama: **Ubah target** atau Hapus |
| F4 | S | CSV: nama berawalan baris baru, atau spasi lalu `=`/`+`/`-`/`@`, lolos dari penyaringan formula | Penyaringan memeriksa setelah spasi/tab/CR/LF di depan |
| F5 | S | Restore langsung mengganti data setelah satu konfirmasi umum, tanpa menunjukkan isi file | Pratinjau: jumlah transaksi/target/tugas/agenda/catatan/berulang, tanggal dibuat, dan data HP yang akan diganti; file terenkripsi didekripsi sekali; file raksasa ditolak sebelum dibaca |
| F6 | R | Kata sandi backup hanya dicek panjang (mis. `12345678` diterima) | Menolak yang terlalu mudah ditebak (karakter terlalu sedikit ragam, daftar sandi umum) |
| N3 | S | Zona waktu gagal terbaca → semua pengingat dijadwalkan dalam UTC (bergeser jam) tanpa peringatan | Cadangan: zona dengan offset sama dengan jam HP (Asia/Jakarta untuk +7) |
| U6 | S | Tugas yang dibuat lewat Tambah Cepat ("hari ini") langsung berlabel "Terlambat" (tanggal tersimpan 00:00 dan dibandingkan dengan jam sekarang) | Tugas tanpa jam baru terlambat setelah harinya lewat (`Todo.isOverdue`) |
| U7 | R | Konfirmasi "Hapus semua data" hanya menyebut transaksi, target, kategori, padahal tugas, agenda, catatan, dan transaksi berulang ikut terhapus | Teks menyebut semuanya dan menjelaskan salinan cadangan otomatis |
| N4 | S | Transaksi berulang hanya diproses saat app dimulai dari nol; app yang tetap hidup di latar belakang melewati pergantian bulan tanpa mencatat, dan hasil susulan tidak memperbarui layar | Diproses setiap app dibuka kembali (`AppLifecycleListener.onResume`), layar diperbarui, peringatan anggaran ikut diperiksa untuk pengeluaran otomatis |
| N5 | S | Izin notifikasi ditolak diam-diam (saklar tak menyala tanpa penjelasan); hasil izin saat membuat pengingat kalender diabaikan | Pesan jelas + petunjuk jalur Pengaturan HP; status izin dibaca ulang setelah permintaan |
| N6 | S | `Notif.init()` dipanggil bersamaan dari beberapa tempat saat app mulai: penyiapan bisa jalan dobel | Penyiapan dimemoisasi (hanya sekali, ulang bila gagal) |
| C1 | T | `versionCode = nomor run`: di repo baru mulai dari 1 → **HP terpasang tidak bisa memperbarui** | Offset +1000 |
| C2 | S | Input `rilis` disisipkan langsung ke shell (injeksi) | Lewat env + validasi regex tag |
| C3 | S | Izin `contents: write` untuk semua job & event | Default read; write hanya job release |
| C4 | S | Build bisa dibatalkan di tengah rilis (cancel-in-progress) | Tidak berlaku di branch utama/tag |
| C5 | S | Keystore & `key.properties` ditulis di folder kerja, tidak dibersihkan | Ke `$RUNNER_TEMP`, dihapus `if: always()`; checkout tanpa kredensial |
| C6 | R | `pub get` bisa mengubah versi; analyze tak ketat | `--enforce-lockfile`, `--fatal-infos`, `scripts/check-secrets.sh`, APK + `SHA256SUMS.txt`, Dependabot |

## 2. Fitur yang dipertahankan
Semua: Keuangan (Catat Cepat, laporan, anggaran, target, berulang, kategori), Produktif (tugas, kalender, catatan + folder + sematan + kunci), profil/XP, mode & animasi, tema, bahasa ID/EN, mata uang, PIN + sidik jari, backup/pulihkan/CSV, pengingat. Kode UI tidak ditulis ulang; yang diubah hanya lapisan data, keamanan, notifikasi, layar PIN/Pengaturan, dan CI.

## 3. Kompatibilitas data lama
- Kunci penyimpanan sama; `applicationId` kini `com.razarsa` (aplikasi baru bagi Android: tidak menimpa versi lama, data dipindah lewat backup); `dataVersion` 1 → 2 (migrasi otomatis).
- PIN lama (SHA-256 polos & PBKDF2 30.000) tetap berlaku, di-upgrade saat PIN benar dimasukkan. PIN 4 digit tetap 4 digit sampai diganti.
- Backup lama (`zevra`, tanpa `version`, v1) tetap bisa dipulihkan; catatan terkunci di dalamnya dienkripsi saat masuk.
- Cadangan otomatis lama tidak dibuang: isi catatan terkunci di dalamnya dienkripsi di tempat.
- Diuji: `test/security_test.dart` (fixture data v1, hash PIN lama dari vektor independen, backup lama).

## 4. Hasil pengujian
| Pemeriksaan | Hasil |
|---|---|
| `flutter pub get --enforce-lockfile` | OK |
| `flutter analyze --fatal-infos` | 0 temuan |
| `flutter test` | **281+ tes lulus** (keamanan, enkripsi, backup, migrasi data lama, notifikasi, zona waktu, keuangan, kategori, anggaran per kategori, profil, layar PIN, alur kunci, pop up, sapuan layout 22 halaman × ukuran layar × font × tema × bahasa) |
| Uji UI nyata (build web + Chromium) | PIN 6 digit, jeda salah 5x (bertahan setelah reload), catatan terkunci (tidak ada teks polos di penyimpanan), migrasi data v1.2.1 + PIN 4 digit lama, backup/restore berkata sandi, semua tab 2 mode: lulus tanpa error |
| `scripts/check-secrets.sh` | OK |
| Uji mutasi (enkripsi dimatikan sementara) | 4+ tes gagal sebagaimana mestinya, lulus lagi setelah dipulihkan |
| `flutter build apk --release` | Tidak bisa dijalankan di lingkungan audit (tanpa Android SDK); **dibuktikan oleh CI** (run hijau, termasuk R8 + aturan keep notifikasi) |
| Uji di HP asli | Catatan terkunci, PIN + jeda, backup/pulihkan, notifikasi dan pengingat (Tes notifikasi), Kelola Kategori: lulus. Sidik jari/FLAG_SECURE tidak dilaporkan terpisah |

### Profil (fitur baru v2.0.0)
Avatar/bingkai/sampul dipilih dari daftar tetap dan divalidasi saat dimuat dan saat impor backup (id tak dikenal → bawaan). Bingkai terkunci per level, ditegakkan di `AppStore`, bukan hanya UI. Kartu bagikan sengaja tidak memuat nominal/saldo/transaksi (dijaga tes). Aset: 26 WebP transparan (<1 MB), dibuat dengan `tools/prepare_profile_assets.py`; PNG mentah tidak disimpan di repo. Ilustrasi/maskot milik pemilik proyek. Tes: `test/profile_test.dart` (29).

### Setelah uji di HP
- Pengingat/notifikasi tidak jalan di APK rilis. Dugaan kuat: R8 membuang informasi tipe Gson yang dipakai `flutter_local_notifications` untuk menyimpan jadwal. Perbaikan: `android/app/proguard-rules.pro` + tombol **Tes notifikasi** (menampilkan sekarang dan menjadwalkan 1 menit lagi, melaporkan galat). **Belum terverifikasi di HP**: build CI dan uji ulang diperlukan.
- Mode USD dihapus (nominal tidak pernah dikonversi). Kelola Kategori selesai. Backup membawa tema, mode, dan (hanya berkata sandi) nama/email.

## 5. Belum selesai / tidak terverifikasi
- Action GitHub kini dipin ke **SHA penuh** (komentar versi di sampingnya); Dependabot menaikkannya lewat PR. Tanda tangan/verifikasi tag action tidak diperiksa.
- R8 aktif di build rilis dengan aturan keep untuk plugin notifikasi (`android/app/proguard-rules.pro`); plugin lain tidak diuji khusus selain lewat uji manual.
- Penulisan ke penyimpanan tidak atomik antar-kunci (SharedPreferences menulis per kunci). Tiap kunci selalu valid, tapi app mati di tengah penulisan bisa menyisakan sebagian data baru dan sebagian lama (mis. transaksi berulang tercatat ganda). Jarang; tidak ada kehilangan data.
- Jangan downgrade ke v1.2.1 setelah memakai v2: v1.2.1 tidak mengenal catatan terenkripsi dan akan menimpanya dengan isi kosong. Pulihkan dari backup bila terlanjur.
- Transaksi berulang tidak diproses saat app benar-benar tertutup (tidak ada pekerja latar); dicatat susulan begitu app dibuka lagi. Pengingat bisa terlambat beberapa menit (alarm tidak presisi, hemat baterai). Mencabut izin notifikasi lewat Pengaturan HP setelah saklar menyala tidak terdeteksi otomatis; saklar tetap tampak menyala.
- Nomor notifikasi tagihan/agenda diturunkan dari id (modulo) sehingga tabrakan sangat jarang mungkin terjadi; tidak diubah agar notifikasi lama tetap bisa dibatalkan.
- Backup tanpa kata sandi tidak punya tanda keutuhan (checksum): file yang rusak tapi masih JSON valid tidak terdeteksi. Backup berkata sandi sudah terautentikasi (GCM). Restore selalu mengganti seluruh data (tidak ada gabung); salinan cadangan dibuat dulu.
- Pergantian mata uang tetap hanya mengubah simbol/format (tidak mengonversi nominal): sengaja ditunda.
- Jeda PIN memakai jam HP (bisa dipercepat dengan memundurkan jam, tapi jeda maksimum dibatasi).
- Tidak ada akun online (sengaja): profil dan data hanya di HP, PIN adalah satu-satunya kunci dan tidak bisa dipulihkan bila lupa. Nominal tidak dikonversi saat ganti IDR↔USD; judul catatan terkunci tidak dienkripsi.
