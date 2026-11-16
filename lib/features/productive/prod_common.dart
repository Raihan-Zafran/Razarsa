import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/notifications.dart';
import '../../core/theme.dart';
import '../../data/productive_models.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart' show staggered;
import '../../shell/classroom_background.dart';
import '../../shell/layout.dart';
import '../../widgets/common.dart';
import 'todo_detail.dart';

/// Halaman mode Produktif: judul di atas, lalu ruang kosong supaya kelas di latar terlihat.
class ProdScroll extends StatelessWidget {
  const ProdScroll({super.key, required this.header, required this.children, this.wideHeader});

  final Widget header;

  /// Judul untuk layar lebar kalau [header] berisi tombol mode/tema/profil (yang di desktop sudah ada di bilah atas).
  final Widget? wideHeader;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final wide = isWide(context);
    final scene = ClassroomBackground.heightFor(mq.size.width);
    final gap = !wide && StoreScope.of(context).useBg ? (scene - mq.padding.top - 12 - 48 - 4).clamp(16.0, 400.0) : 12.0;
    return LayoutBuilder(builder: (context, box) {
      final gutter = wide ? sideGutter(box.maxWidth, 820, min: 28) : 20.0;
      return ListView(
        padding: EdgeInsets.fromLTRB(gutter, wide ? 28 : mq.padding.top + 12, gutter, wide ? 36 : mq.padding.bottom + 120),
        children: [
          // Di desktop tombol mode, tema, dan profil sudah ada di bilah atas.
          if (!wide) ...staggered(context, [SizedBox(height: 48, child: header)]),
          if (wide) ...staggered(context, [SizedBox(height: 48, child: wideHeader ?? (header is ProdTitle ? header : const SizedBox.shrink()))]),
          SizedBox(height: gap),
          ...staggered(context, children, start: 1),
        ],
      );
    });
  }
}

/// Judul halaman Produktif dengan tombol tambah di kanan.
class ProdTitle extends StatelessWidget {
  const ProdTitle(this.text, {super.key, this.onAdd, this.addLabel});

  final String text;
  final VoidCallback? onAdd;
  final String? addLabel;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Row(children: [
      Expanded(child: Text(text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
      if (onAdd != null)
        Semantics(
          button: true,
          label: addLabel ?? tr('Tambah'),
          child: Material(
            color: z.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onAdd,
              child: SizedBox(width: 44, height: 44, child: Icon(Icons.add_rounded, color: z.onPrimary)),
            ),
          ),
        ),
    ]);
  }
}

String dueLabel(DateTime? d) {
  if (d == null) return tr('Tanpa tanggal');
  final hasTime = d.hour != 0 || d.minute != 0;
  return hasTime ? '${dayLabel(d)}, ${timeLabel(d)}' : dayLabel(d);
}

/// Satu baris tugas: lingkaran centang, judul, tenggat, jumlah sub-tugas, lonceng pengingat,
/// bendera prioritas, dan kategori. Ketuk = buka detail (HP: lembar bawah); tekan lama = hapus.
class TodoRow extends StatelessWidget {
  const TodoRow({super.key, required this.todo, this.showDivider = true, this.onOpen, this.selected = false, this.showPriText = false});

  final Todo todo;
  final bool showDivider;

  /// Kosong = buka lembar detail.
  final VoidCallback? onOpen;
  final bool selected;

  /// Tampilkan teks prioritas di samping bendera (Windows).
  final bool showPriText;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final z = ZColors.of(context);
    final late = todo.isOverdue();
    final doneSubs = todo.subs.where((x) => x.done).length;
    final meta = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: z.muted2);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onOpen ?? () => showTodoDetail(context, todo),
      onLongPress: () => confirmDelete(context, todo.title, () => store.removeTodo(todo.id)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? z.primary.withValues(alpha: 0.07) : null,
          borderRadius: selected ? BorderRadius.circular(10) : null,
          border: showDivider && !selected ? Border(bottom: BorderSide(color: z.divider)) : null,
        ),
        child: Row(children: [
          Semantics(
            button: true,
            checked: todo.done,
            label: todo.done ? trf('Batalkan selesai: {0}', [todo.title]) : trf('Tandai selesai: {0}', [todo.title]),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => store.toggleTodo(todo.id),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: todo.done ? z.primary : Colors.transparent,
                    border: Border.all(color: todo.done ? z.primary : z.chipBorder, width: 2),
                  ),
                  child: todo.done ? Icon(Icons.check_rounded, size: 16, color: z.onPrimary) : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                todo.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: todo.done ? z.muted2 : z.text,
                  decoration: todo.done ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 3),
              Row(children: [
                Flexible(
                  child: Text(todoDueText(todo),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: late ? z.warn : z.muted)),
                ),
                if (todo.subs.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Icon(Icons.checklist_rounded, size: 15, color: z.muted2),
                  const SizedBox(width: 3),
                  Text('$doneSubs/${todo.subs.length}', style: meta),
                ],
                if (todo.remind > 0) ...[
                  const SizedBox(width: 10),
                  Icon(Icons.notifications_none_rounded, size: 15, color: z.muted2, semanticLabel: tr('Ada pengingat')),
                ],
                if (todo.repeat != 'none') ...[
                  const SizedBox(width: 8),
                  Icon(Icons.repeat_rounded, size: 15, color: z.muted2, semanticLabel: tr('Berulang')),
                ],
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Icon(Icons.flag_rounded, size: 17, color: priColor(z, todo.pri), semanticLabel: trf('Prioritas {0}', [priLabel(todo.pri)])),
          if (showPriText) ...[
            const SizedBox(width: 3),
            Text(priLabel(todo.pri), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: priColor(z, todo.pri))),
          ],
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: z.toneBg(todo.tone), borderRadius: BorderRadius.circular(999)),
            child: Text(tr(todo.cat), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: z.toneFg(todo.tone))),
          ),
          const SizedBox(width: 2),
        ]),
      ),
    );
  }
}

String repeatLabel(String r) => tr(kRepeatOpts.firstWhere((o) => o.$1 == r, orElse: () => kRepeatOpts.first).$2);

String remindLabel(Agenda a) {
  if (!a.reminder) return tr('Tanpa pengingat');
  if (a.remindMin == 0) return tr('Saat mulai');
  return trf('{0} sebelumnya', [tr(kRemindOpts.firstWhere((o) => o.$1 == a.remindMin, orElse: () => (a.remindMin, '${a.remindMin} menit')).$2)]);
}

/// Satu agenda di garis waktu (prototipe `.evc`): jam mulai dan selesai di kiri, kartu berwarna berisi
/// judul, lokasi, dan tanda berulang / pengingat. Ketuk = rincian; tekan lama = hapus.
class AgendaRow extends StatelessWidget {
  const AgendaRow({super.key, required this.item});

  final Agenda item;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final z = ZColors.of(context);
    final dim = item.reminder && !item.on;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: dim ? 0.55 : 1,
        child: Material(
          color: z.toneBg(item.tone),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => showAgendaSheet(context, item),
            onLongPress: () => confirmDelete(context, item.title, () => store.removeAgenda(item.id)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(children: [
                SizedBox(
                  width: 46,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(timeLabel(item.at), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: z.text, fontFeatures: const [FontFeature.tabularFigures()])),
                    Text(timeLabel(item.end), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: z.text2.withValues(alpha: 0.75), fontFeatures: const [FontFeature.tabularFigures()])),
                  ]),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: z.text)),
                    if (item.loc.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Row(children: [
                          Icon(Icons.place_outlined, size: 14, color: z.toneFg(item.tone)),
                          const SizedBox(width: 3),
                          Flexible(child: Text(item.loc, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: z.text2))),
                        ]),
                      ),
                  ]),
                ),
                if (item.repeat != 'none') ...[
                  Icon(Icons.repeat_rounded, size: 15, color: z.toneFg(item.tone)),
                  const SizedBox(width: 3),
                  Text(repeatLabel(item.repeat), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: z.toneFg(item.tone))),
                  const SizedBox(width: 6),
                ],
                if (item.reminder)
                  Icon(item.on ? Icons.notifications_active_outlined : Icons.notifications_off_outlined, size: 17, color: z.toneFg(item.tone),
                      semanticLabel: item.on ? tr('Pengingat aktif') : tr('Pengingat mati')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rincian agenda: waktu, lokasi, pengingat (bisa dinyalakan / dimatikan), pengulangan, dan hapus.
Future<void> showAgendaSheet(BuildContext context, Agenda a) {
  final store = StoreScope.read(context);
  return showModalBottomSheet<void>(
    sheetAnimationStyle: kSheetAnimation,
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      final z = ZColors.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: z.chart(a.tone), shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Text(a.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.schedule_rounded, color: z.text2),
              title: Text('${dayLabel(a.at)} · ${timeLabel(a.at)} – ${timeLabel(a.end)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: a.loc.isEmpty ? null : Text(a.loc),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.repeat_rounded, color: z.text2),
              title: Text(trf('Ulangi: {0}', [repeatLabel(a.repeat)]), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(Icons.notifications_none_rounded, color: z.text2),
              title: Text(tr('Pengingat'), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(remindLabel(a)),
              value: a.reminder && a.on,
              onChanged: (v) {
                set(() {
                  if (!a.reminder) {
                    a.reminder = true;
                    a.on = true;
                  } else {
                    a.on = v;
                  }
                });
                store.updateAgenda(a);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline_rounded, color: z.warn),
              title: Text(tr('Hapus agenda'), style: TextStyle(fontWeight: FontWeight.w700, color: z.warn)),
              onTap: () {
                Navigator.pop(ctx);
                store.removeAgenda(a.id);
                showZToast(context, tr('Agenda dihapus'));
              },
            ),
          ]),
        ),
      );
    }),
  );
}

InputDecoration _field(BuildContext context, String hint) {
  final z = ZColors.of(context);
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: z.bg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: z.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: z.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: z.primary, width: 2)),
  );
}

Widget _sheetLabel(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ZColors.of(context).muted)),
    );

Widget _sheetFrame(BuildContext context, String title, List<Widget> children, VoidCallback onSave) {
  final z = ZColors.of(context);
  return Padding(
    padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
    child: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        ...children,
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: onSave,
            style: FilledButton.styleFrom(
              backgroundColor: z.primary,
              foregroundColor: z.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(tr('Simpan'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    ),
  );
}

/// Lembar tambah tugas (prototipe "Tugas baru"): nama, catatan, kategori, prioritas, tenggat, jam, pengingat.
Future<void> showAddTodo(BuildContext context, {String initial = ''}) {
  final store = StoreScope.read(context);
  final ctrl = TextEditingController(text: initial);
  final notes = TextEditingController();
  var cat = 0;
  var pri = 'sedang';
  var dueKey = 'today';
  DateTime? custom;
  TimeOfDay? time;
  var remind = 0;
  return showModalBottomSheet<void>(
    sheetAnimationStyle: kSheetAnimation,
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      final choices = dueChoices(store);
      DateTime? dueDay() => dueKey == 'custom' ? custom : choices.firstWhere((c) => c.$1 == dueKey).$3;
      return _sheetFrame(ctx, tr('Tugas baru'), [
        TextField(controller: ctrl, autofocus: true, textCapitalization: TextCapitalization.sentences,
            decoration: _field(ctx, tr('Apa yang mau dikerjakan?'))),
        const SizedBox(height: 10),
        TextField(controller: notes, textCapitalization: TextCapitalization.sentences, minLines: 1, maxLines: 3,
            decoration: _field(ctx, tr('Catatan (opsional)'))),
        _sheetLabel(ctx, tr('Kategori')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < kTodoCats.length; i++)
            ZChip(label: tr(kTodoCats[i].$1), selected: cat == i, onTap: () => set(() => cat = i)),
        ]),
        _sheetLabel(ctx, tr('Prioritas')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (k, l) in kPriorities) ZChip(label: tr(l), selected: pri == k, onTap: () => set(() => pri = k)),
        ]),
        _sheetLabel(ctx, tr('Tenggat')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (k, l, _) in choices) ZChip(label: l, selected: dueKey == k, onTap: () => set(() => dueKey = k)),
          ZChip(
            label: dueKey == 'custom' && custom != null ? dayLabel(custom!) : tr('Pilih tanggal'),
            icon: Icons.event_outlined,
            selected: dueKey == 'custom',
            onTap: () async {
              final now = DateTime.now();
              final d = await showDatePicker(context: ctx, initialDate: custom ?? now, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 5));
              if (d != null) {
                set(() {
                  custom = d;
                  dueKey = 'custom';
                });
              }
            },
          ),
          if (dueKey != 'none')
            ZChip(
              label: time == null ? tr('Atur jam') : time!.format(ctx),
              icon: Icons.schedule_rounded,
              selected: time != null,
              onTap: () async {
                final picked = await showTimePicker(context: ctx, initialTime: time ?? const TimeOfDay(hour: 9, minute: 0));
                if (picked != null) set(() => time = picked);
              },
            ),
        ]),
        _sheetLabel(ctx, tr('Pengingat')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (m, l) in kRemindOpts) ZChip(label: tr(l), selected: remind == m, onTap: () => set(() => remind = m)),
        ]),
      ], () async {
        final title = ctrl.text.trim();
        if (title.isEmpty) {
          showZToast(ctx, tr('Isi nama tugas dulu'));
          return;
        }
        final d = dueDay();
        final due = d == null ? null : (time == null ? d : DateTime(d.year, d.month, d.day, time!.hour, time!.minute));
        final wantsNotif = remind > 0 && due != null && store.switches['agenda'] == true;
        final allowed = !wantsNotif || await Notif.requestPermission();
        store.addTodo(title, cat: kTodoCats[cat].$1, tone: kTodoCats[cat].$2, due: due, pri: pri, notes: notes.text, remind: due == null ? 0 : remind);
        if (ctx.mounted) Navigator.pop(ctx);
        if (context.mounted) {
          showZToast(context, allowed ? tr('Tugas ditambahkan') : tr('Tugas tersimpan, tapi notifikasi diblokir. Aktifkan di pengaturan perangkat.'));
        }
      });
    }),
  );
}

/// Lembar tambah agenda pada tanggal [day] (prototipe): nama, lokasi, jam mulai, durasi, warna, pengingat, ulangi.
Future<void> showAddAgenda(BuildContext context, DateTime day) {
  final store = StoreScope.read(context);
  final ctrl = TextEditingController();
  final loc = TextEditingController();
  final now = TimeOfDay.now();
  var time = TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
  var dur = 60;
  var tone = 'blue';
  var remind = 10; // -1 = tanpa pengingat
  var repeat = 'none';
  const durs = [(30, '30 menit'), (60, '1 jam'), (120, '2 jam'), (180, '3 jam')];
  final reminds = [(-1, 'Tidak'), (0, 'Saat mulai'), for (final (m, l) in kRemindOpts.skip(1)) (m, l)];
  return showModalBottomSheet<void>(
    sheetAnimationStyle: kSheetAnimation,
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      final z = ZColors.of(ctx);
      return _sheetFrame(ctx, trf('Agenda · {0}', [shortDate(day)]), [
        TextField(controller: ctrl, autofocus: true, textCapitalization: TextCapitalization.sentences,
            decoration: _field(ctx, tr('Nama agenda, misalnya Rapat tim'))),
        const SizedBox(height: 10),
        TextField(controller: loc, textCapitalization: TextCapitalization.sentences,
            decoration: _field(ctx, tr('Lokasi (opsional)'))),
        _sheetLabel(ctx, tr('Mulai')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ZChip(
            label: time.format(ctx),
            icon: Icons.schedule_rounded,
            selected: true,
            onTap: () async {
              final picked = await showTimePicker(context: ctx, initialTime: time);
              if (picked != null) set(() => time = picked);
            },
          ),
        ]),
        _sheetLabel(ctx, tr('Durasi')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (m, l) in durs) ZChip(label: tr(l), selected: dur == m, onTap: () => set(() => dur = m)),
        ]),
        _sheetLabel(ctx, tr('Warna')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (k, l) in kAgendaTones)
            Semantics(
              button: true,
              selected: tone == k,
              label: tr(l),
              child: GestureDetector(
                onTap: () => set(() => tone = k),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: z.chart(k),
                    border: Border.all(color: tone == k ? z.text : Colors.transparent, width: 2.5),
                  ),
                  child: tone == k ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
                ),
              ),
            ),
        ]),
        _sheetLabel(ctx, tr('Pengingat')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (m, l) in reminds) ZChip(label: tr(l), selected: remind == m, onTap: () => set(() => remind = m)),
        ]),
        _sheetLabel(ctx, tr('Ulangi')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (k, l) in kRepeatOpts) ZChip(label: tr(l), selected: repeat == k, onTap: () => set(() => repeat = k)),
        ]),
      ], () async {
        final title = ctrl.text.trim();
        if (title.isEmpty) {
          showZToast(ctx, tr('Isi nama agenda dulu'));
          return;
        }
        final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
        final reminder = remind >= 0;
        final allowed = !(reminder && store.switches['agenda'] == true) || await Notif.requestPermission();
        store.addAgenda(title, at, reminder: reminder, repeat: repeat, tone: tone, loc: loc.text, durMin: dur, remindMin: reminder ? remind : 0);
        if (ctx.mounted) Navigator.pop(ctx);
        if (context.mounted) {
          showZToast(
              context,
              !allowed
                  ? tr('Pengingat tersimpan, tapi notifikasi diblokir. Aktifkan di Pengaturan HP → Aplikasi → Razarsa → Notifikasi.')
                  : tr('Agenda ditambahkan'));
        }
      });
    }),
  );
}
