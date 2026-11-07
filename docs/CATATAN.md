# Catatan serah-terima Razarsa (untuk sesi berikutnya)

Terakhir diperbarui: 7 Nov 2026, disiapkan rilis **v1.2.1** (animasi ganti mode, toggle ikon, folder dan kunci catatan).

## Pemilik & cara kerja
- Pemilik: **Raihan Zafran Syaddat**. Jawab dalam bahasa Indonesia sederhana, sebut namanya, istilah asing dijelaskan di bagian bawah, berani mengingatkan kalau ada langkah berisiko.
- **Desain dulu, baru kode.** Perubahan tampilan dibuat di kanvas desain, tunggu "oke" dari Raihan, baru masuk ke Flutter.
- **Jangan menambah papan baru di kanvas.** Ubah papan yang sudah ada. Kalau perlu eksperimen, tanya dulu dan hapus setelah selesai.
- Raihan tidak suka token terbuang untuk pengecekan manual berulang. Dia tes sendiri di HP.
- **Desain selalu diputuskan lewat Artifact.** Jangan menebak tampilan, tunjukkan dulu di Artifact.
- **Hindari penjelasan panjang.** Kalau terpaksa panjang, buat ringkas atau pakai tabel/daftar. Hemat token dengan cara apa pun (alat, skrip, plugin).
- **Berani proaktif:** sarankan tools/plugin yang membantu, minta aset (gambar, ikon, font) kalau perlu, kritik terus terang, dan cari desain yang lebih profesional daripada yang diminta.

## Tautan
- Repo: https://github.com/Raihan-Zafran/Razarsa (nama lama: Zevra). Branch utama saat ini: `ccr-85eddd7b-dfef8b`.
- Kanvas desain (artifact Claude): https://claude.ai/artifact/Njih5nDimL871fLCyemXBn
  - Baris 1–2: Keuangan terang/gelap (semua dari satu prototipe `Main.dc.html`).
  - Baris 3: `Produktif.dc.html`, `Profil.dc.html`, `LiquidGlass.dc.html` (eksperimen sementara).

## Aplikasi
- Flutter 3.47, paket `com.raihan.razarsa`, versi di `pubspec.yaml`.
- Mode: **Keuangan** (latar gurun bawaan, langit pilihan) dan **Produktif** (latar kelas). Gym & Health sudah dihapus atas permintaan Raihan.
- Kode penting: `lib/shell/` (latar & dock), `lib/features/finance`, `lib/features/productive`, `lib/features/settings` (termasuk `manage_pages.dart`: Catat Cepat, Transaksi berulang, Tentang, Privasi, Ketentuan), `lib/data/store.dart`.
- Latar gurun: `lib/shell/desert_art.dart` dihasilkan dari SVG desain (flutter_svg); ubah desain dulu lalu ekspor ulang.
- Cek sebelum push: `flutter analyze` (harus 0 masalah) dan `flutter test`.

## Rilis
- Push ke branch utama dengan versi baru di `pubspec.yaml` → GitHub Actions membuat APK dan **Release otomatis**. Catatan rilis di `docs/rilis/vX.Y.Z.md`, versi tampilan di `kAppVersion` (`manage_pages.dart`).
- Kunci rilis ada di GitHub Secrets (`RELEASE_*`). File keystore dan `google-services.json` **tidak boleh** di-commit.
- Build Gradle lokal sering kena batas Maven (429), jadi andalkan CI.

## Belum selesai / menunggu keputusan
- **Liquid Glass**: Raihan belum memutuskan. Kalau suka → jadikan pilihan tema di Pengaturan (di `Main.dc.html`), hapus papan eksperimen. Peringatkan bahwa blur berat di Android.
- Cek hasil v1.1.3 di HP: apakah ganti tema masih tersendat, dan apakah transisi ganti mode enak.
- Raihan pernah bilang ada beberapa bug yang mau dijelaskan.
- Pengaturan **Kategori** masih "segera hadir". Login masih lokal (rencana Firebase; `google-services.json` lama terdaftar untuk `com.raihan.zevra`, perlu didaftarkan ulang).

## Hasil kritik kode (7 Nov 2026)
Sudah (v1.2.0): PIN PBKDF2 + salt, `allowBackup=false`, versi data, cadangan otomatis harian, impor atomik, data rusak diselamatkan (`rusak_<nama>`), terjemahan Inggris lengkap + tes pemeriksanya, 12 tes baru di `test/store_test.dart`. Perlu dites di HP.

Antrean, urut prioritas:
1. (Selesai di v1.2.0) versi data, cadangan otomatis, tes inti, tes terjemahan. Kalau model data berubah, tulis migrasinya di `_migrate` (`store.dart`) dan naikkan `dataVersion`.
3. **Enkripsi data** di HP (butuh `flutter_secure_storage`, uji lewat CI dan HP). PIN 4–6 digit tetap lemah tanpa ini.
4. Ganti `catch (_)` yang diam dengan log; kurangi rebuild `AppStore`; login/Firebase; perbarui deskripsi `pubspec.yaml` (masih menyebut "kesehatan").
5. File latar besar (`classroom_background.dart`, `sky_background.dart`): jangan diubah sebelum soal Liquid Glass diputuskan.

Kunci rilis: **aman**. Workflow menggagalkan rilis kalau 4 secret `RELEASE_*` kosong. Kunci debug hanya dipakai build cabang biasa (bukan rilis).

## Desain 1.3 (sudah digambar di Artifact, belum dikodekan)
Kanvas kini satu prototipe terhubung: Main (Keuangan) mengimpor Produktif dan Profil, jadi ubah di komponen aslinya. Liquid Glass sudah dihapus (diputuskan: tidak dipakai).
- **Login/daftar/lupa sandi**: desain ada di papan Login. Butuh Firebase dulu (`google-services.json` untuk `com.raihan.razarsa`, simpan sebagai GitHub Secret, jangan di-commit).
- **Kebijakan Privasi/Ketentuan/Tentang**: desain ada di papan Profil. Masih ada isian `[KURUNG SIKU]` yang harus diputuskan Raihan (penyedia login, e-mail kontak, batas usia, masa hapus data). Jangan dikodekan sebelum diisi.
- **Profil** (bingkai, cover GIF, lencana pajangan, usia akun, kelengkapan profil, Akun dan Data): ditunda oleh Raihan. Saran: pajang 3 lencana, kartu bagikan tanpa nominal uang, bingkai Pelangi animasinya hanya saat profil terbuka.
- **Syarat unggahan** (usulan, belum disetujui): foto maks 2 MB (JPG/PNG/WebP, min 256x256, 1:1, tanpa GIF); cover maks 5 MB (JPG/PNG/WebP/GIF, 3:1, GIF maks 10 detik).
- **Aset yang diminta**: ikon notifikasi Android (putih polos 96x96), 8-12 avatar bawaan 512x512, 4-6 cover 1200x400, logo vektor, ilustrasi layar kosong. Prompt gaya dasar naga hijau sudah diberikan.
- Catatan terkunci PIN hanya disembunyikan di layar, belum dienkripsi (tertulis di Kebijakan Privasi).
