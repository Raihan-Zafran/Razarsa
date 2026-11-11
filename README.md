<p align="center">
  <img src="docs/app_icon.png" width="120" alt="Ikon aplikasi Razarsa">
</p>

<h1 align="center">Razarsa</h1>
<p align="center"><b>Satu aplikasi untuk mengatur hidup.</b><br>Keuangan dan produktivitas dalam satu tempat.</p>
<p align="center"><a href="../../releases/latest"><b>⬇️ Unduh APK terbaru</b></a></p>

---

Aplikasi Android (Flutter) dengan dua mode: **Keuangan** dan **Produktif**. Semua data tersimpan di HP, tanpa akun dan tanpa server.

## Fitur

**💰 Keuangan**
- Catat pemasukan dan pengeluaran, Catat Cepat sekali tap
- Laporan, anggaran bulanan dan per kategori, target tabungan
- Transaksi berulang dan pengingat tagihan

**✅ Produktif**
- Tugas, kalender dengan pengingat
- Catatan dengan folder, sematan, dan kunci PIN (terenkripsi)

**Umum**
- Terang/gelap, Indonesia/English
- Kunci PIN dan sidik jari
- Backup berkata sandi, pulihkan, ekspor CSV
- Profil dengan level, avatar, bingkai, dan lencana

## Pasang

1. Buka halaman [**Releases**](../../releases/latest).
2. Unduh **`…-arm64.apk`** (hampir semua HP modern) atau `…-universal.apk`.
3. Pasang. Izinkan "sumber tidak dikenal" jika diminta.

## Pengembangan

Butuh Flutter 3.47.

```bash
flutter pub get --enforce-lockfile
flutter analyze --fatal-infos
flutter test
flutter run
```

Dokumen: [Keamanan](SECURITY.md) · [Laporan audit](docs/AUDIT.md)

## Lisensi

Font Plus Jakarta Sans: SIL Open Font License. Maskot dan ilustrasi: milik pemilik proyek.
