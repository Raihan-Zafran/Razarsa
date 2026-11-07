<p align="center">
  <img src="docs/app_icon.png" width="120" alt="Ikon aplikasi Razarsa">
</p>

<h1 align="center">Razarsa</h1>
<p align="center"><b>Satu aplikasi untuk mengatur hidup.</b><br>Keuangan dan produktivitas dalam satu tempat.</p>
<p align="center"><a href="../../releases/latest"><b>⬇️ Unduh APK terbaru</b></a></p>

---

## Tentang

Aplikasi Android (Flutter) dengan beberapa **mode**. Satu aplikasi, satu pengaturan, satu maskot naga hijau. Semua data tersimpan **di HP**, tanpa server.

Nama berasal dari pembuatnya: **Ra**ihan **Za**fran Sy**a**ddat.

## Fitur

**💰 Keuangan**
- Catat pemasukan dan pengeluaran, **Catat Cepat** sekali tap
- Laporan, anggaran bulanan, target tabungan
- Kategori khas Indonesia, bisa buat sendiri

**✅ Produktif**
- To-do, kalender dengan pengingat
- Catatan dengan **folder**, sematan, dan **kunci PIN**

**Untuk semua mode**
- Ganti mode dengan animasi bulatan
- Terang/gelap, Indonesia/English, Rupiah/Dolar
- Kunci PIN + sidik jari, sembunyikan saldo
- Backup, pulihkan, dan ekspor CSV
- Profil dengan level dan XP
- Latar beranimasi siang/malam

## Visi

- **1.3** Cek pembaruan, pengaturan kategori, anggaran per kategori
- **1.4** Profil seru: lencana, bingkai, kartu bagikan
- **1.5** Widget layar utama, enkripsi data
- **1.6** Ringkasan bulanan, tantangan mingguan
- **2.0** Dashboard Utama yang merangkum semua mode

## Pasang

1. Buka halaman [**Releases**](../../releases/latest).
2. Unduh **`…-arm64.apk`** (hampir semua HP modern) atau `…-universal.apk`.
3. Pasang. Izinkan "sumber tidak dikenal" jika diminta.

Pasang di atas versi lama, data tetap aman.

> Login saat ini masih lokal dan kata sandi tidak diperiksa. Jangan pakai kata sandi penting.

## Pengembangan

Butuh Flutter 3.47.

```bash
flutter pub get
flutter run
flutter test
```

APK dan Release dibuat otomatis oleh GitHub Actions saat versi di `pubspec.yaml` naik. File kunci (`*.jks`, `google-services.json`) **jangan** di-commit; simpan di GitHub Secrets.

## Lisensi

Font Plus Jakarta Sans: SIL Open Font License. Maskot dan ilustrasi: milik pemilik proyek.
