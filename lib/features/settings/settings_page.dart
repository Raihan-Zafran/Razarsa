import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/notifications.dart';
import '../../core/theme.dart';
import '../../data/backup.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart';
import '../../widgets/common.dart';
import '../../widgets/profile_widgets.dart';
import '../finance/report_page.dart' show editBudget;
import '../security/lock.dart';
import 'manage_pages.dart';
import 'profile_page.dart';
import '../../shell/classroom_background.dart';
import '../../shell/desert_background.dart';
import '../../core/i18n.dart';

/// Pengaturan dipakai bersama untuk semua mode Razarsa.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);

    final themeLabel = switch (store.themeMode) {
      ThemeMode.light => tr('Terang'),
      ThemeMode.dark => tr('Gelap'),
      ThemeMode.system => tr('Ikuti HP'),
    };

    return PageScroll(children: [
      PageTitle(tr('Pengaturan')),
      // Ruang kosong supaya latar (gurun / kelas) terlihat.
      Builder(builder: (context) {
        final mq = MediaQuery.of(context);
        final scene = store.mode == 'productive'
            ? ClassroomBackground.heightFor(mq.size.width) - 4
            : DesertBackground.heightFor(mq.size.width) * 0.76;
        return SizedBox(height: (scene - mq.padding.top - 12 - 48).clamp(12.0, 400.0));
      }),
      Material(
        color: z.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: z.cardBorder)),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => pushPage(context, const ProfilePage()),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              ProfileAvatar(avatarId: store.avatar, frameId: store.effectiveFrame, size: 56),
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
        _Row(icon: Icons.landscape_outlined, tone: 'amber', label: tr('Latar Keuangan'), value: store.financeBg == 'sky' ? tr('Langit') : tr('Gurun'),
            onTap: () => _pick(context, tr('Latar Keuangan'), [('desert', tr('Gurun')), ('sky', tr('Langit'))], store.financeBg, store.setFinanceBg)),
        _Row(icon: Icons.language_rounded, tone: 'blue', label: tr('Bahasa'), value: store.lang == 'en' ? 'English' : 'Indonesia',
            onTap: () => _pick(context, tr('Bahasa'), [('id', 'Indonesia'), ('en', 'English')], store.lang, store.setLang)),
        _Row(icon: Icons.calendar_month_outlined, tone: 'green', label: tr('Awal bulan anggaran'), value: trf('Tanggal {0}', [store.monthStartDay]),
            sub: tr('Samakan dengan tanggal gajian'), onTap: () => _pickMonthStart(context, store)),
        _Row(icon: Icons.view_week_outlined, tone: 'teal', label: tr('Awal minggu'), value: store.weekStartMonday ? tr('Senin') : tr('Hari Minggu'),
            onTap: () => _pick(context, tr('Awal minggu'), [('mon', tr('Senin')), ('sun', tr('Hari Minggu'))],
                store.weekStartMonday ? 'mon' : 'sun', (v) => store.setWeekStartMonday(v == 'mon'))),
      ]),
      _Group(tr('Keuangan'), [
        _Row(icon: Icons.sell_outlined, tone: 'orange', label: tr('Kategori'), value: trf('{0} kategori', [store.categoryCount]),
            onTap: () => pushPage(context, const CategoriesPage())),
        _Row(icon: Icons.bar_chart_rounded, tone: 'green', label: tr('Anggaran bulanan'), value: rpShort(store.monthlyBudget),
            onTap: () => editBudget(context, store)),
        _Row(icon: Icons.donut_small_rounded, tone: 'teal', label: tr('Anggaran per kategori'),
            value: store.catBudgets.isEmpty ? tr('Belum ada') : trf('{0} batas', [store.catBudgets.length]),
            onTap: () => pushPage(context, const CategoryBudgetsPage())),
        _Row(icon: Icons.repeat_rounded, tone: 'blue', label: tr('Transaksi berulang'),
            value: store.recurring.isEmpty ? tr('Belum ada') : trf('{0} aktif', [store.recurring.length]),
            sub: tr('Gaji, kos, langganan otomatis tercatat'), onTap: () => pushPage(context, const RecurringPage())),
        _Row(icon: Icons.bolt_rounded, tone: 'amber', label: tr('Catat Cepat'), value: trf('{0} tombol', [store.quickItems.length]),
            onTap: () => pushPage(context, const QuickItemsPage())),
      ]),
      _Group(tr('Notifikasi'), [
        _Switch(store, 'daily', Icons.notifications_none_rounded, 'purple', tr('Pengingat harian'), tr('Setiap hari pukul 20.00'),
            onChanged: (v) async {
              if (v && !await _allowNotifications(context)) return;
              store.setSwitch('daily', v);
              await Notif.syncDaily(v);
            }),
        _Switch(store, 'budgetAlert', Icons.warning_amber_rounded, 'orange', tr('Peringatan anggaran'), tr('Saat anggaran terpakai 90%'),
            onChanged: (v) async {
              if (v && !await _allowNotifications(context)) return;
              store.setSwitch('budgetAlert', v);
            }),
        _Switch(store, 'agenda', Icons.event_available_outlined, 'blue', tr('Pengingat kalender'), tr('Notifikasi untuk pengingat di mode Produktif'),
            onChanged: (v) async {
              if (v && !await _allowNotifications(context)) return;
              store.setSwitch('agenda', v);
              for (final a in store.agenda) {
                await Notif.syncAgenda(a, enabled: v);
              }
            }),
        _Switch(store, 'bill', Icons.receipt_long_outlined, 'teal', tr('Pengingat tagihan'), tr('Sehari sebelum transaksi berulang jatuh tempo'),
            onChanged: (v) async {
              if (v && !await _allowNotifications(context)) return;
              store.setSwitch('bill', v);
              await Notif.syncBills(store);
            }),
        _Row(icon: Icons.notifications_active_outlined, tone: 'purple', label: tr('Tes notifikasi'),
            sub: tr('Tampil sekarang, lalu satu lagi 1 menit kemudian'), onTap: () => _testNotifications(context)),
      ]),
      _Group(tr('Keamanan & Privasi'), [
        _Switch(store, 'pin', Icons.lock_outline_rounded, 'blue', tr('Kunci aplikasi (PIN)'), null, onChanged: (v) => _togglePin(context, store, v)),
        if (store.pinEnabled)
          _Row(icon: Icons.password_rounded, tone: 'blue', label: tr('Ganti PIN'), value: trf('{0} digit', [store.pinLength]),
              sub: store.pinLength < AppStore.pinNewLength ? tr('Disarankan 6 digit untuk keamanan lebih baik') : null,
              onTap: () => _changePin(context, store)),
        _Switch(store, 'bio', Icons.fingerprint_rounded, 'green', tr('Buka dengan sidik jari'), null, onChanged: (v) => _toggleBio(context, store, v)),
        _Switch(store, 'secure', Icons.screenshot_monitor_rounded, 'purple', tr('Cegah tangkapan layar'),
            tr('Isi aplikasi disembunyikan dari tangkapan layar dan daftar aplikasi terbaru saat PIN aktif')),
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
        _Row(icon: Icons.info_outline_rounded, tone: 'green', label: tr('Tentang Razarsa'), value: kAppVersion,
            onTap: () => pushPage(context, const AboutPage())),
        _Row(icon: Icons.shield_outlined, tone: 'blue', label: tr('Kebijakan privasi'), onTap: () => pushPage(context, LegalPage.privacy())),
        _Row(icon: Icons.description_outlined, tone: 'gray', label: tr('Syarat & ketentuan'), onTap: () => pushPage(context, LegalPage.terms())),
      ]),
      _Group(tr('Profil'), [
        _Row(icon: Icons.badge_outlined, tone: 'green', label: tr('Ubah nama & email'),
            sub: tr('Hanya tersimpan di HP ini'), onTap: () => _editProfile(context, store)),
      ]),
      const SizedBox(height: 14),
      Text(trf('Razarsa versi {0}', [kAppVersion]), textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: z.muted2)),
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

  Future<void> _editProfile(BuildContext context, AppStore store) async {
    final name = TextEditingController(text: store.userName);
    final mail = TextEditingController(text: store.email);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Ubah nama & email')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, maxLength: 30, decoration: InputDecoration(labelText: tr('Nama panggilan'), counterText: '')),
          const SizedBox(height: 8),
          TextField(
            controller: mail,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: tr('Email (opsional)')),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Batal'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Simpan'))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final done = store.updateProfile(name: name.text, email: mail.text);
    showZToast(context, done ? tr('Profil diperbarui') : tr('Isi nama panggilan dan email yang benar (email boleh kosong).'));
  }

  Future<void> _testNotifications(BuildContext context) async {
    if (!await _allowNotifications(context)) return;
    final r = await Notif.selfTest();
    if (!context.mounted) return;
    showZToast(
      context,
      r == 'ok'
          ? tr('Tes dikirim. Satu notifikasi lagi akan muncul sekitar 1 menit.')
          : r == 'notready'
              ? tr('Notifikasi gagal disiapkan di HP ini.')
              : r == 'denied'
                  ? tr('Notifikasi diblokir di Pengaturan HP.')
                  : trf('Penjadwalan gagal: {0}', [r.length > 120 ? r.substring(0, 120) : r]),
    );
  }

  /// Meminta izin notifikasi. Kalau ditolak/diblokir, saklar tidak dinyalakan dan pengguna diberi tahu caranya.
  Future<bool> _allowNotifications(BuildContext context) async {
    final ok = await Notif.requestPermission();
    if (!ok && context.mounted) {
      showZToast(context, tr('Izin notifikasi belum diberikan. Aktifkan di Pengaturan HP → Aplikasi → Razarsa → Notifikasi.'));
    }
    return ok;
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
      if (ok != true || !context.mounted) return;
      if (store.hasLockedNotes) {
        final sure = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(tr('Matikan PIN?')),
            content: Text(tr('Kunci semua catatan terkunci akan dibuka, karena tanpa PIN tidak ada yang melindunginya.')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Batal'))),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Matikan'))),
            ],
          ),
        );
        if (sure != true) return;
      }
      store.setPin(null);
      if (context.mounted) showZToast(context, tr('PIN dimatikan'));
    }
  }

  /// Ganti PIN: PIN lama diperiksa dulu; catatan yang terkunci tetap terkunci.
  Future<void> _changePin(BuildContext context, AppStore store) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const PinVerifyPage()));
    if (ok != true || !context.mounted) return;
    final pin = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const PinSetupPage()));
    if (pin == null) return;
    store.setPin(pin);
    if (context.mounted) showZToast(context, tr('PIN diganti'));
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
          if (store.hasAutoBackup)
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: Text(tr('Pulihkan cadangan otomatis'), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(store.autoBackupAt.length >= 10 ? store.autoBackupAt.substring(0, 10) : ''),
              onTap: () => Navigator.pop(c, 'auto'),
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
    } else if (v == 'auto') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(tr('Pulihkan cadangan otomatis?')),
          content: Text(tr('Data di HP ini akan diganti dengan cadangan otomatis terakhir.')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Batal'))),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Pulihkan'))),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      final done = await store.restoreAutoBackup();
      if (!context.mounted) return;
      showZToast(context, done ? tr('Data berhasil dipulihkan') : tr('File backup tidak valid'));
    }
  }

  String _stamp() => DateTime.now().toIso8601String().substring(0, 10);

  /// Meminta kata sandi backup. '' = tanpa kata sandi (hanya kalau [required] false). null = batal.
  Future<String?> _askNewPassword(BuildContext context, {required bool required}) {
    final a = TextEditingController();
    final b = TextEditingController();
    String? error;
    return showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(tr('Lindungi backup dengan kata sandi')),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(required
                ? tr('Backup ini memuat catatan terkunci, jadi wajib diberi kata sandi.')
                : tr('Disarankan. Tanpa kata sandi, siapa pun yang memegang file ini bisa membacanya.')),
            const SizedBox(height: 8),
            Text(tr('Simpan kata sandi ini baik-baik. Tanpa itu, backup tidak bisa dipulihkan.'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(controller: a, obscureText: true, decoration: InputDecoration(labelText: tr('Kata sandi (min. 8 karakter)'))),
            TextField(controller: b, obscureText: true, decoration: InputDecoration(labelText: tr('Ulangi kata sandi'), errorText: error)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Batal'))),
            if (!required) TextButton(onPressed: () => Navigator.pop(c, ''), child: Text(tr('Tanpa kata sandi'))),
            FilledButton(
              onPressed: () {
                final problem = BackupEnvelope.passwordProblem(a.text);
                if (problem == BackupPasswordProblem.tooShort) {
                  setS(() => error = tr('Kata sandi terlalu pendek'));
                } else if (problem == BackupPasswordProblem.weak) {
                  setS(() => error = tr('Kata sandi terlalu mudah ditebak'));
                } else if (a.text != b.text) {
                  setS(() => error = tr('Kata sandi tidak cocok'));
                } else {
                  Navigator.pop(c, a.text);
                }
              },
              child: Text(tr('Lanjut')),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askPassword(BuildContext context, {bool wrong = false}) {
    final a = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Masukkan kata sandi backup')),
        content: TextField(
          controller: a,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(labelText: tr('Kata sandi'), errorText: wrong ? tr('Kata sandi salah') : null),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Batal'))),
          FilledButton(onPressed: () => Navigator.pop(c, a.text), child: Text(tr('Lanjut'))),
        ],
      ),
    );
  }

  Future<void> _backup(BuildContext context, AppStore store) async {
    try {
      final pw = await _askNewPassword(context, required: store.hasLockedNotes);
      if (pw == null) return;
      final text = pw.isEmpty ? store.exportJson() : await store.exportEncrypted(pw);
      final uri = await FilePicker.saveFile(
        fileName: 'razarsa-backup-${_stamp()}.json',
        bytes: utf8.encode(text),
        mimeType: 'application/json',
      );
      if (uri == null) return;
      store.markBackup();
      if (context.mounted) showZToast(context, tr('Backup tersimpan'));
    } catch (e) {
      debugPrint('Razarsa: operasi file gagal: $e');
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
    } catch (e) {
      debugPrint('Razarsa: operasi file gagal: $e');
      if (context.mounted) showZToast(context, tr('Gagal menyimpan file'));
    }
  }

  /// Pulihkan dari file: buka dulu (minta kata sandi bila terenkripsi), tampilkan isinya, baru
  /// minta persetujuan mengganti data di HP ini.
  Future<void> _restore(BuildContext context, AppStore store) async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (files.isEmpty || !context.mounted) return;
      final file = files.first.xFile;
      if (await file.length() > AppStore.maxBackupChars) {
        if (context.mounted) showZToast(context, tr('File backup terlalu besar'));
        return;
      }
      final raw = await file.readAsString();
      var insp = await store.inspectBackup(raw);
      var wrong = false;
      while (insp.result == BackupResult.needPassword || insp.result == BackupResult.wrongPassword) {
        if (!context.mounted) return;
        final pw = await _askPassword(context, wrong: wrong);
        if (pw == null) return;
        insp = await store.inspectBackup(raw, password: pw);
        wrong = true;
      }
      if (!context.mounted) return;
      if (insp.result != BackupResult.ok) {
        showZToast(
            context,
            insp.result == BackupResult.tooNew
                ? tr('Backup ini dibuat aplikasi versi lebih baru. Perbarui Razarsa dulu.')
                : tr('File backup tidak valid'));
        return;
      }
      final made = insp.exportedAt;
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(tr('Pulihkan dari backup?')),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(trf('Isi backup: {0} transaksi, {1} target, {2} tugas, {3} agenda, {4} catatan, {5} transaksi berulang.', [
              insp.count('txns'), insp.count('goals'), insp.count('todos'), insp.count('agenda'), insp.count('notes'), insp.count('recurring'),
            ])),
            if (made != null) ...[const SizedBox(height: 6), Text(trf('Dibuat {0}.', [shortDate(made)]))],
            const SizedBox(height: 10),
            Text(trf('Data di HP ini ({0} transaksi, {1} catatan) akan diganti. Satu salinan cadangan otomatis dibuat dulu, jadi masih bisa dibatalkan.', [store.txns.length, store.notes.length])),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Batal'))),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Pulihkan'))),
          ],
        ),
      );
      if (ok != true) return;
      final result = await store.restoreFrom(insp);
      if (!context.mounted) return;
      showZToast(
          context,
          switch (result) {
            BackupResult.ok => tr('Data berhasil dipulihkan'),
            BackupResult.saveFailed => tr('Gagal menyimpan data ke HP. Coba lagi.'),
            _ => tr('File backup tidak valid'),
          });
    } catch (e) {
      debugPrint('Razarsa: operasi file gagal: $e');
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
    // null = batal, true = hapus + simpan cadangan, false = hapus permanen.
    final keep = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Hapus semua data?')),
        content: Text(tr('Semua data (transaksi, target, kategori, transaksi berulang, tugas, agenda, catatan, Catat Cepat, dan bio) akan dihapus dari HP ini. Pilih "Hapus, simpan cadangan" untuk menyimpan satu salinan yang masih bisa dipulihkan lewat Backup & Pulihkan, atau "Hapus permanen" untuk menghapus salinan itu juga.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Batal'))),
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Hapus permanen'))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Hapus, simpan cadangan'))),
        ],
      ),
    );
    if (keep == null) return;
    await store.clearAll(keepSafetyCopy: keep);
    if (context.mounted) showZToast(context, tr('Semua data sudah dihapus'));
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
