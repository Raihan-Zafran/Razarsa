# Keamanan Razarsa

## Melaporkan celah
Gunakan **Security → Report a vulnerability** di GitHub repo ini (pelaporan privat). Jangan membuka issue publik untuk celah keamanan dan jangan melampirkan data pribadi.

## Model ancaman (ringkas)
| Dilindungi | Cara |
|---|---|
| Isi catatan terkunci di penyimpanan | AES-256-GCM, kunci di Android Keystore, terikat ke id catatan |
| PIN | PBKDF2-HMAC-SHA256 + salt acak, 60.000 iterasi; jeda 30 dtk → 1 jam setelah 5 kali salah |
| Backup | Opsional AES-256-GCM, kunci dari kata sandi (PBKDF2 210.000 iterasi); wajib bila ada catatan terkunci |
| Tangkapan layar / daftar aplikasi terbaru | `FLAG_SECURE` saat PIN aktif |
| Jaringan | Aplikasi tidak punya izin INTERNET dan tidak mengirim data apa pun |
| Cadangan Android | `allowBackup=false` |

## Batasan yang diketahui
- Penyerang dengan akses root pada HP yang sedang menyala bisa bertindak sebagai aplikasi dan memakai Keystore. PIN melindungi antarmuka, bukan kunci enkripsi.
- Jeda PIN memakai jam HP; memundurkan jam bisa memperpendek jeda (maksimum jeda tetap dibatasi 1 jam).
- Judul catatan tidak dienkripsi. Backup tanpa kata sandi dan CSV tidak dienkripsi.
- Tidak ada akun online dan tidak ada kata sandi akun. Profil hanya di HP; PIN (opsional, disarankan) adalah satu-satunya kunci dan tidak bisa dipulihkan jika lupa (data harus dipulihkan dari backup).

## Rahasia & rilis
- Kunci rilis hanya di GitHub Secrets (`RELEASE_*`); jangan pernah di-commit. `scripts/check-secrets.sh` dijalankan di CI dan gagal bila ada file/pola rahasia.
- Jika kunci rilis atau password-nya pernah terpapar: buat keystore baru, ganti secret, dan umumkan bahwa pengguna perlu memasang ulang (tanda tangan baru tidak bisa memperbarui yang lama).
