import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/notifications.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart';
import '../../widgets/common.dart';
import '../finance/report_page.dart' show editBudget;
import '../security/lock.dart';
import 'profile_page.dart';
import '../../core/i18n.dart';

/// Pengaturan dipakai bersama untuk semua mode Razarsa.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    void soon() => showZToast(context, tr('Fitur ini segera hadir'));

    final themeLabel = switch (store.themeMode) {
      ThemeMode.light => tr('Terang'),
      ThemeMode.dark => tr('Gelap'),
      ThemeMode.system => tr('Ikuti HP'),
    };

    return PageScroll(children: [
      PageTitle(tr('Pengaturan')),
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
                  Text(store.userName.isEmpty ? tr('Pengguna Razarsa') : store.userName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(store.email.isEmpty ? tr('Atur profil & akun') : store.email,
                      style: TextStyle(fontSize: 12, color: z.muted2)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: z.muted2),
            ]),
          ),
        ),
      ),
      _Group(tr('Umum'), [
        _Row(icon: Icons.dark_mode_outlined, tone: 'purple', label: tr('Tampilan'), value: themeLabel, onTap: () => _pickTheme(context, store)),
        _Row(icon: Icons.language_rounded, tone: 'blue', label: tr('Bahasa'), value: store.lang == 'en' ? 'English' : 'Indonesia',
            onTap: () => _pick(context, tr('Bahasa'), [('id', 'Indonesia'), ('en', 'English')], store.lang, store.setLang)),
        _Row(icon: Icons.payments_outlined, tone: 'amber', label: tr('Mata uang'), value: store.currency == 'USD' ? 'US Dollar (\$)' : 'Rupiah (Rp)',
            onTap: () => _pick(context, tr('Mata uang'), [('IDR', 'Rupiah (Rp)'), ('USD', 'US Dollar (\$)')], store.currency, store.setCurrency)),
        _Row(icon: Icons.calendar_month_outlined, tone: 'green', label: tr('Awal bulan anggaran'), value: trf('Tanggal {0}', [store.monthStartDay]),
            sub: tr('Samakan dengan tanggal gajian'), onTap: () => _pickMonthStart(context, store)),
        _Row(icon: Icons.view_week_outlined, tone: 'teal', label: tr('Awal minggu'), value: store.weekStartMonday ? tr('Senin') : tr('Hari Minggu'),
            onTap: () => _pick(context, tr('Awal minggu'), [('mon', tr('Senin')), ('sun', tr('Hari Minggu'))],
                store.weekStartMonday ? 'mon' : 'sun', (v) => store.setWeekStartMonday(v == 'mon'))),
      ]),
      _Group(tr('Keuangan'), [
        _Row(icon: Icons.sell_outlined, tone: 'orange', label: tr('Kategori'), value: trf('{0} kategori', [store.categoryCount]), onTap: soon),
        _Row(icon: Icons.bar_chart_rounded, tone: 'green', label: tr('Anggaran bulanan'), value: rpShort(store.monthlyBudget),
            onTap: () => editBudget(context, store)),
        _Row(icon: Icons.repeat_rounded, tone: 'blue', label: tr('Transaksi berulang'), value: tr('Belum ada'),
            sub: tr('Gaji, kos, langganan otomatis tercatat'), onTap: soon),
        _Row(icon: Icons.bolt_rounded, tone: 'amber', label: tr('Catat Cepat'), value: trf('{0} tombol', [kQuickItems.length]), onTap: soon),
      ]),
      _Group(tr('Notifikasi'), [
        _Switch(store, 'daily', Icons.notifications_none_rounded, 'purple', tr('Pengingat harian'), tr('Setiap hari pukul 20.00'),
            onChanged: (v) async {
              if (v && !await Notif.requestPermission()) return;
              store.setSwitch('daily', v);
              await Notif.syncDaily(v);
            }),
        _Switch(store, 'budgetAlert', Icons.warning_amber_rounded, 'orange', tr('Peringatan anggaran'), tr('Saat anggaran terpakai 90%'),
            onChanged: (v) async {
              if (v && !await Notif.requestPermission()) return;
              store.setSwitch('budgetAlert', v);
            }),
        _Switch(store, 'agenda', Icons.event_available_outlined, 'blue', tr('Pengingat kalender'), tr('Notifikasi untuk pengingat di mode Produktif'),
            onChanged: (v) async {
              if (v && !await Notif.requestPermission()) return;
              store.setSwitch('agenda', v);
              for (final a in store.agenda) {
                await Notif.syncAgenda(a, enabled: v);
              }
            }),
        _Switch(store, 'bill', Icons.receipt_long_outlined, 'teal', tr('Pengingat tagihan'), tr('Butuh fitur transaksi berulang (segera hadir)'),
            onChanged: (_) async => soon()),
      ]),
      _Group(tr('Keamanan & Privasi'), [
        _Switch(store, 'pin', Icons.lock_outline_rounded, 'blue', tr('Kunci aplikasi (PIN)'), null, onChanged: (v) => _togglePin(context, store, v)),
        _Switch(store, 'bio', Icons.fingerprint_rounded, 'green', tr('Buka dengan sidik jari'), null, onChanged: (v) => _toggleBio(context, store, v)),
        _Switch(store, 'hide', Icons.visibility_off_outlined, 'gray', tr('Sembunyikan saldo'), tr('Saldo di Beranda tampil sebagai ••••')),
      ]),
      _Group('Data', [
        _Row(icon: Icons.cloud_upload_outlined, tone: 'blue', label: tr('Backup & Pulihkan'), sub: store.lastBackup.isEmpty ? tr('Belum pernah backup') : trf('Backup terakhir: {0}', [shortDate(DateTime.parse(store.lastBackup))]),
            onTap: () => _backupSheet(context, store)),
        _Row(icon: Icons.file_upload_outlined, tone: 'green', label: tr('Ekspor data'), value: 'CSV / Excel', onTap: () => _exportCsv(context, store)),
        _Row(icon: Icons.file_download_outlined, tone: 'purple', label: tr('Impor data'), onTap: () => _restore(context, store)),
        _Row(icon: Icons.delete_outline_rounded, tone: 'warn', label: tr('Hapus semua data'), sub: tr('Tidak bisa dibatalkan'),
            danger: true, onTap: () => _confirmClear(context, store)),
      ]),
      _Group(tr('Tentang'), [
        _Row(icon: Icons.star_outline_rounded, tone: 'amber', label: tr('Beri rating'), onTap: soon),
        _Row(icon: Icons.chat_bubble_outline_rounded, tone: 'blue', label: tr('Kirim masukan'), onTap: soon),
        _Row(icon: Icons.shield_outlined, tone: 'green', label: tr('Kebijakan privasi'), onTap: soon),
        _Row(icon: Icons.description_outlined, tone: 'gray', label: tr('Syarat & ketentuan'), onTap: soon),
        _Row(icon: Icons.info_outline_rounded, tone: 'gray', label: tr('Versi aplikasi'), value: '1.1.0', onTap: () {}),
      ]),
      _Group(tr('Akun'), [
        _Row(icon: Icons.logout_rounded, tone: 'warn', label: tr('Keluar'), sub: tr('Kembali ke halaman masuk'), danger: true,
            onTap: store.logout),
      ]),
      const SizedBox(height: 14),
      Text(tr('Razarsa versi 1.1.0'), textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: z.muted2)),
    ]);
  }


  Future<void> _pick(BuildContext context, String title, List<(String, String)> options, String current,
      void Function(String) onPick) async {
    final store = StoreScope.read(context);
    final v = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final (id, label) in options)
            ListTile(
              title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: id == current ? const Icon(Icons.check_rounded) : null,
              onTap: () => Navigator.pop(c, id),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (v != null && v != current) {
      onPick(v);
      Notif.syncDaily(store.switches['daily'] == true);
    }
  }

  Future<void> _pickMonthStart(BuildContext context, AppStore store) async {
    final z = ZColors.of(context);
    final day = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Pilih tanggal awal bulan anggaran')),
        content: SizedBox(
          width: 300,
          child: GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              for (var d = 1; d <= 28; d++)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.pop(c, d),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: d == store.monthStartDay ? z.primary : z.track,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$d',
                        style: TextStyle(fontWeight: FontWeight.w700, color: d == store.monthStartDay ? z.onPrimary : z.text)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (day != null) store.setMonthStart(day);
  }

  Future<void> _togglePin(BuildContext context, AppStore store, bool on) async {
    if (on) {
      final pin = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const PinSetupPage()));
      if (pin != null) {
        store.setPin(pin);
        if (context.mounted) showZToast(context, tr('PIN aktif'));
      }
    } else {
      final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const PinVerifyPage()));
      if (ok == true) {
        store.setPin(null);
        if (context.mounted) showZToast(context, tr('PIN dimatikan'));
      }
    }
  }

  Future<void> _toggleBio(BuildContext context, AppStore store, bool on) async {
    if (!on) return store.setSwitch('bio', false);
    if (!store.pinEnabled) return showZToast(context, tr('Aktifkan PIN dulu'));
    if (!await biometricAvailable()) {
      if (context.mounted) showZToast(context, tr('HP ini tidak mendukung sidik jari'));
      return;
    }
    if (await authenticateBiometric()) store.setSwitch('bio', true);
  }

  Future<void> _backupSheet(BuildContext context, AppStore store) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.save_alt_rounded),
            title: Text(tr('Buat backup'), style: const TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => Navigator.pop(c, 'backup'),
          ),
          ListTile(
            leading: const Icon(Icons.restore_rounded),
            title: Text(tr('Pulihkan dari file'), style: const TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => Navigator.pop(c, 'restore'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!context.mounted) return;
    if (v == 'backup') {
      await _backup(context, store);
    } else if (v == 'restore') {
      await _restore(context, store);
    }
  }

  String _stamp() => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _backup(BuildContext context, AppStore store) async {
    try {
      final uri = await FilePicker.saveFile(
        fileName: 'razarsa-backup-${_stamp()}.json',
        bytes: utf8.encode(store.exportJson()),
        mimeType: 'application/json',
      );
      if (uri == null) return;
      store.markBackup();
      if (context.mounted) showZToast(context, tr('Backup tersimpan'));
    } catch (_) {
      if (context.mounted) showZToast(context, tr('Gagal menyimpan file'));
    }
  }

  Future<void> _exportCsv(BuildContext context, AppStore store) async {
    try {
      final uri = await FilePicker.saveFile(
        fileName: 'razarsa-transaksi-${_stamp()}.csv',
        bytes: utf8.encode('\uFEFF${store.exportCsv()}'),
        mimeType: 'text/csv',
      );
      if (uri != null && context.mounted) showZToast(context, tr('File CSV tersimpan'));
    } catch (_) {
      if (context.mounted) showZToast(context, tr('Gagal menyimpan file'));
    }
  }

  Future<void> _restore(BuildContext context, AppStore store) async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (files.isEmpty || !context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(tr('Pulihkan dari backup?')),
          content: Text(tr('Data di HP ini akan diganti dengan isi file backup.')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Batal'))),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Pulihkan'))),
          ],
        ),
      );
      if (ok != true) return;
      final raw = await files.first.xFile.readAsString();
      final done = store.importJson(raw);
      if (context.mounted) showZToast(context, done ? tr('Data berhasil dipulihkan') : tr('File backup tidak valid'));
    } catch (_) {
      if (context.mounted) showZToast(context, tr('File backup tidak valid'));
    }
  }

  Future<void> _pickTheme(BuildContext context, AppStore store) async {
    final m = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (mode, label, icon) in [
            (ThemeMode.light, tr('Terang'), Icons.light_mode_outlined),
            (ThemeMode.dark, tr('Gelap'), Icons.dark_mode_outlined),
            (ThemeMode.system, tr('Ikuti HP'), Icons.phone_android_rounded),
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
        title: Text(tr('Hapus semua data?')),
        content: Text(tr('Semua transaksi, target, dan kategori buatanmu akan dihapus dari HP ini. Ini tidak bisa dibatalkan.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Batal'))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Hapus semua'))),
        ],
      ),
    );
    if (ok == true) {
      await store.clearAll();
      if (context.mounted) showZToast(context, tr('Semua data sudah dihapus'));
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
  const _Switch(this.store, this.keyName, this.icon, this.tone, this.label, this.sub, {this.onChanged});

  final Future<void> Function(bool)? onChanged;

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
    void setV(bool v) => onChanged != null ? onChanged!(v) : store.setSwitch(keyName, v);
    return InkWell(
      onTap: () => setV(!on),
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
            onChanged: setV,
            activeThumbColor: Colors.white,
            activeTrackColor: z.primary,
          ),
        ]),
      ),
    );
  }
}
