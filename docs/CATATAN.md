# Catatan serah-terima Razarsa (untuk sesi berikutnya)

Terakhir diperbarui: 7 Nov 2026, disiapkan rilis **v1.2.0** (fix bug dan lain-lain).

## Pemilik & cara kerja
- Pemilik: **Raihan Zafran Syaddat**. Jawab dalam bahasa Indonesia sederhana, sebut namanya, istilah asing dijelaskan di bagian bawah, berani mengingatkan kalau ada langkah berisiko.
- **Desain dulu, baru kode.** Perubahan tampilan dibuat di kanvas desain, tunggu "oke" dari Raihan, baru masuk ke Flutter.
- **Jangan menambah papan baru di kanvas.** Ubah papan yang sudah ada. Kalau perlu eksperimen, tanya dulu dan hapus setelah selesai.
- Raihan tidak suka token terbuang untuk pengecekan manual berulang. Dia tes sendiri di HP.

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
