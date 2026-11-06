import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart';
import '../../widgets/common.dart';
import '../finance/report_page.dart' show editBudget;
import 'profile_page.dart';

/// Pengaturan dipakai bersama untuk semua mode Razarsa.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    void soon() => showZToast(context, 'Fitur ini segera hadir');

    final themeLabel = switch (store.themeMode) {
      ThemeMode.light => 'Terang',
      ThemeMode.dark => 'Gelap',
      ThemeMode.system => 'Ikuti HP',
    };

    return PageScroll(children: [
      const PageTitle('Pengaturan'),
      const SizedBox(height: 12),
      Material(
        color: z.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: z.cardBorder)),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => pushPage(context, const ProfilePage()),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(radius: 26, backgroundColor: z.track, child: Icon(Icons.person_outline_rounded, color: z.muted, size: 26)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(store.userName.isEmpty ? 'Pengguna Razarsa' : store.userName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(store.email.isEmpty ? 'Atur profil & akun' : store.email,
                      style: TextStyle(fontSize: 12, color: z.muted2)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: z.muted2),
            ]),
          ),
        ),
      ),
      _Group('Umum', [
        _Row(icon: Icons.dark_mode_outlined, tone: 'purple', label: 'Tampilan', value: themeLabel, onTap: () => _pickTheme(context, store)),
        _Row(icon: Icons.language_rounded, tone: 'blue', label: 'Bahasa', value: 'Indonesia', onTap: soon),
        _Row(icon: Icons.payments_outlined, tone: 'amber', label: 'Mata uang', value: 'Rupiah (Rp)', onTap: soon),
        _Row(icon: Icons.calendar_month_outlined, tone: 'green', label: 'Awal bulan anggaran', value: 'Tanggal 1',
            sub: 'Samakan dengan tanggal gajian', onTap: soon),
        _Row(icon: Icons.view_week_outlined, tone: 'teal', label: 'Awal minggu', value: 'Senin', onTap: soon),
      ]),
      _Group('Keuangan', [
        _Row(icon: Icons.sell_outlined, tone: 'orange', label: 'Kategori', value: '${store.categoryCount} kategori', onTap: soon),
        _Row(icon: Icons.bar_chart_rounded, tone: 'green', label: 'Anggaran bulanan', value: rpShort(store.monthlyBudget),
            onTap: () => editBudget(context, store)),
        _Row(icon: Icons.repeat_rounded, tone: 'blue', label: 'Transaksi berulang', value: 'Belum ada',
            sub: 'Gaji, kos, langganan otomatis tercatat', onTap: soon),
        _Row(icon: Icons.bolt_rounded, tone: 'amber', label: 'Catat Cepat', value: '${kQuickItems.length} tombol', onTap: soon),
      ]),
      _Group('Notifikasi', [
        _Switch(store, 'daily', Icons.notifications_none_rounded, 'purple', 'Pengingat harian', 'Setiap hari pukul 20.00'),
        _Switch(store, 'budgetAlert', Icons.warning_amber_rounded, 'orange', 'Peringatan anggaran', 'Saat anggaran terpakai 90%'),
        _Switch(store, 'bill', Icons.receipt_long_outlined, 'teal', 'Pengingat tagihan', '3 hari sebelum jatuh tempo'),
      ]),
      _Group('Keamanan & Privasi', [
        _Switch(store, 'pin', Icons.lock_outline_rounded, 'blue', 'Kunci aplikasi (PIN)', null),
        _Switch(store, 'bio', Icons.fingerprint_rounded, 'green', 'Buka dengan sidik jari', null),
        _Switch(store, 'hide', Icons.visibility_off_outlined, 'gray', 'Sembunyikan saldo', 'Saldo di Beranda tampil sebagai ••••'),
      ]),
      _Group('Data', [
        _Row(icon: Icons.cloud_upload_outlined, tone: 'blue', label: 'Backup & Pulihkan', sub: 'Belum pernah backup', onTap: soon),
        _Row(icon: Icons.file_upload_outlined, tone: 'green', label: 'Ekspor data', value: 'CSV / Excel', onTap: soon),
        _Row(icon: Icons.file_download_outlined, tone: 'purple', label: 'Impor data', onTap: soon),
        _Row(icon: Icons.delete_outline_rounded, tone: 'warn', label: 'Hapus semua data', sub: 'Tidak bisa dibatalkan',
            danger: true, onTap: () => _confirmClear(context, store)),
      ]),
      _Group('Tentang', [
        _Row(icon: Icons.star_outline_rounded, tone: 'amber', label: 'Beri rating', onTap: soon),
        _Row(icon: Icons.chat_bubble_outline_rounded, tone: 'blue', label: 'Kirim masukan', onTap: soon),
        _Row(icon: Icons.shield_outlined, tone: 'green', label: 'Kebijakan privasi', onTap: soon),
        _Row(icon: Icons.description_outlined, tone: 'gray', label: 'Syarat & ketentuan', onTap: soon),
        _Row(icon: Icons.info_outline_rounded, tone: 'gray', label: 'Versi aplikasi', value: '1.0.0', onTap: () {}),
      ]),
      _Group('Akun', [
        _Row(icon: Icons.logout_rounded, tone: 'warn', label: 'Keluar', sub: 'Kembali ke halaman masuk', danger: true,
            onTap: store.logout),
      ]),
      const SizedBox(height: 14),
      Text('Razarsa versi 1.0.0-beta', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: z.muted2)),
    ]);
  }

  Future<void> _pickTheme(BuildContext context, AppStore store) async {
    final m = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (mode, label, icon) in [
            (ThemeMode.light, 'Terang', Icons.light_mode_outlined),
            (ThemeMode.dark, 'Gelap', Icons.dark_mode_outlined),
            (ThemeMode.system, 'Ikuti HP', Icons.phone_android_rounded),
          ])
            ListTile(
              leading: Icon(icon),
              title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: store.themeMode == mode ? const Icon(Icons.check_rounded) : null,
              onTap: () => Navigator.pop(c, mode),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (m != null) store.setThemeMode(m);
  }

  Future<void> _confirmClear(BuildContext context, AppStore store) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus semua data?'),
        content: const Text('Semua transaksi, target, dan kategori buatanmu akan dihapus dari HP ini. Ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus semua')),
        ],
      ),
    );
    if (ok == true) {
      await store.clearAll();
      if (context.mounted) showZToast(context, 'Semua data sudah dihapus');
    }
  }
}

class _Group extends StatelessWidget {
  const _Group(this.title, this.rows);

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title.toUpperCase(),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: z.muted)),
        ),
        ZCard(
          radius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(children: [
            for (var i = 0; i < rows.length; i++) ...[
              rows[i],
              if (i < rows.length - 1) Divider(height: 1, color: z.divider),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.tone, required this.label, this.value, this.sub, this.danger = false, required this.onTap});

  final IconData icon;
  final String tone;
  final String label;
  final String? value;
  final String? sub;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final bg = danger ? z['warnBg'] : z.toneBg(tone);
    final fg = danger ? z.warn : z.toneFg(tone);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: danger ? z.warn : z.text)),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub!, style: TextStyle(fontSize: 12, color: z.muted2)),
                ],
              ]),
            ),
          ),
          if (value != null) Text(value!, style: TextStyle(fontSize: 13, color: z.muted2)),
          if (!danger) Icon(Icons.chevron_right_rounded, color: z.muted2, size: 20),
        ]),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch(this.store, this.keyName, this.icon, this.tone, this.label, this.sub);

  final AppStore store;
  final String keyName;
  final IconData icon;
  final String tone;
  final String label;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final on = store.switches[keyName] == true;
    return InkWell(
      onTap: () => store.setSwitch(keyName, !on),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: z.toneBg(tone), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: z.toneFg(tone)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub!, style: TextStyle(fontSize: 12, color: z.muted2)),
                ],
              ]),
            ),
          ),
          Switch(
            value: on,
            onChanged: (v) => store.setSwitch(keyName, v),
            activeThumbColor: Colors.white,
            activeTrackColor: z.primary,
          ),
        ]),
      ),
    );
  }
}
