import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/notifications.dart';
import '../../core/theme.dart';
import '../../data/productive_models.dart';
import '../../data/store.dart';
import '../../shell/classroom_background.dart';
import '../../widgets/common.dart';

/// Halaman mode Produktif: judul di atas, lalu ruang kosong supaya kelas di latar terlihat.
class ProdScroll extends StatelessWidget {
  const ProdScroll({super.key, required this.header, required this.children});

  final Widget header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scene = ClassroomBackground.heightFor(mq.size.width);
    final gap = (scene - mq.padding.top - 12 - 48 - 4).clamp(16.0, 400.0);
    return ListView(
      padding: EdgeInsets.fromLTRB(20, mq.padding.top + 12, 20, mq.padding.bottom + 120),
      children: [
        SizedBox(height: 48, child: header),
        SizedBox(height: gap),
        ...children,
      ],
    );
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

/// Satu baris tugas dengan lingkaran centang.
class TodoRow extends StatelessWidget {
  const TodoRow({super.key, required this.todo, this.showDivider = true});

  final Todo todo;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final z = ZColors.of(context);
    final late = todo.isOverdue();
    return InkWell(
      onLongPress: () => confirmDelete(context, todo.title, () => store.removeTodo(todo.id)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(border: showDivider ? Border(bottom: BorderSide(color: z.divider)) : null),
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
                  width: 28,
                  height: 28,
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
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: todo.done ? z.muted2 : z.text,
                  decoration: todo.done ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(late ? trf('Terlambat · {0}', [dueLabel(todo.due)]) : dueLabel(todo.due),
                  style: TextStyle(fontSize: 12, color: late ? z.warn : z.muted2)),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: z.toneBg(todo.tone), borderRadius: BorderRadius.circular(999)),
            child: Text(tr(todo.cat), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: z.toneFg(todo.tone))),
          ),
        ]),
      ),
    );
  }
}

/// Satu agenda di garis waktu: jam di kiri, kartu berwarna di kanan.
class AgendaRow extends StatelessWidget {
  const AgendaRow({super.key, required this.item});

  final Agenda item;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final z = ZColors.of(context);
    final dim = item.reminder && !item.on;
    final sub = item.reminder ? (item.daily ? tr('Pengingat · setiap hari') : tr('Pengingat · sekali')) : tr('Acara');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(
          width: 50,
          child: Text(timeLabel(item.at), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: z.text2)),
        ),
        Expanded(
          child: GestureDetector(
            onLongPress: () => confirmDelete(context, item.title, () => store.removeAgenda(item.id)),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: dim ? 0.55 : 1,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                decoration: BoxDecoration(color: z.toneBg(item.tone), borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Icon(item.reminder ? Icons.notifications_none_rounded : Icons.event_outlined, size: 19, color: z.toneFg(item.tone)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: z.text)),
                      const SizedBox(height: 1),
                      Text(sub, style: TextStyle(fontSize: 11.5, color: z.text2)),
                    ]),
                  ),
                  if (item.reminder)
                    Transform.scale(
                      scale: 0.85,
                      child: Switch(
                        value: item.on,
                        onChanged: (_) => store.toggleAgenda(item.id),
                        activeThumbColor: Colors.white,
                        activeTrackColor: z.primary,
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

InputDecoration _field(BuildContext context, String hint) {
  final z = ZColors.of(context);
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: z.bg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: z.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: z.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: z.primary, width: 2)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(tr('Simpan'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    ),
  );
}

/// Lembar tambah tugas.
Future<void> showAddTodo(BuildContext context, {String initial = ''}) {
  final store = StoreScope.read(context);
  final ctrl = TextEditingController(text: initial);
  var cat = 0;
  var day = 0; // 0 hari ini, 1 besok, 2 tanpa tanggal
  TimeOfDay? time;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      return _sheetFrame(ctx, tr('Tugas baru'), [
        TextField(controller: ctrl, autofocus: true, textCapitalization: TextCapitalization.sentences,
            decoration: _field(ctx, tr('Apa yang mau dikerjakan?'))),
        _sheetLabel(ctx, tr('Kategori')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < kTodoCats.length; i++)
            ZChip(label: tr(kTodoCats[i].$1), selected: cat == i, onTap: () => set(() => cat = i)),
        ]),
        _sheetLabel(ctx, tr('Kapan')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (i, l) in [(0, tr('Hari ini')), (1, tr('Besok')), (2, tr('Tanpa tanggal'))])
            ZChip(label: l, selected: day == i, onTap: () => set(() => day = i)),
          if (day != 2)
            ZChip(
              label: time == null ? tr('Atur jam') : time!.format(ctx),
              selected: time != null,
              onTap: () async {
                final picked = await showTimePicker(context: ctx, initialTime: time ?? TimeOfDay.now());
                if (picked != null) set(() => time = picked);
              },
            ),
        ]),
      ], () {
        final title = ctrl.text.trim();
        if (title.isEmpty) return;
        DateTime? due;
        if (day != 2) {
          final d = dayOnly(DateTime.now()).add(Duration(days: day));
          due = time == null ? d : DateTime(d.year, d.month, d.day, time!.hour, time!.minute);
        }
        store.addTodo(title, cat: kTodoCats[cat].$1, tone: kTodoCats[cat].$2, due: due);
        Navigator.pop(ctx);
        showZToast(context, tr('Tugas ditambahkan'));
      });
    }),
  );
}

/// Lembar tambah acara / pengingat pada tanggal [day].
Future<void> showAddAgenda(BuildContext context, DateTime day) {
  final store = StoreScope.read(context);
  final ctrl = TextEditingController();
  var reminder = false;
  var daily = false;
  final now = TimeOfDay.now();
  var time = TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      return _sheetFrame(ctx, trf('Tambah ke {0}', [dayLabel(day)]), [
        Segmented<bool>(
          items: [(false, tr('Acara')), (true, tr('Pengingat'))],
          value: reminder,
          onChanged: (v) => set(() => reminder = v),
        ),
        const SizedBox(height: 12),
        TextField(controller: ctrl, autofocus: true, textCapitalization: TextCapitalization.sentences,
            decoration: _field(ctx, reminder ? tr('Ingatkan aku untuk...') : tr('Nama acara'))),
        _sheetLabel(ctx, tr('Jam')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ZChip(
            label: time.format(ctx),
            selected: true,
            onTap: () async {
              final picked = await showTimePicker(context: ctx, initialTime: time);
              if (picked != null) set(() => time = picked);
            },
          ),
        ]),
        if (reminder) ...[
          _sheetLabel(ctx, tr('Ulangi')),
          Wrap(spacing: 8, children: [
            ZChip(label: tr('Sekali'), selected: !daily, onTap: () => set(() => daily = false)),
            ZChip(label: tr('Setiap hari'), selected: daily, onTap: () => set(() => daily = true)),
          ]),
        ],
      ], () async {
        final title = ctrl.text.trim();
        if (title.isEmpty) return;
        final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
        final allowed = !(reminder && store.switches['agenda'] == true) || await Notif.requestPermission();
        store.addAgenda(title, at, reminder: reminder, daily: reminder && daily);
        if (ctx.mounted) Navigator.pop(ctx);
        if (context.mounted) {
          showZToast(
              context,
              !allowed
                  ? tr('Pengingat tersimpan, tapi notifikasi diblokir. Aktifkan di Pengaturan HP → Aplikasi → Razarsa → Notifikasi.')
                  : (reminder ? tr('Pengingat dibuat') : tr('Acara ditambahkan')));
        }
      });
    }),
  );
}
