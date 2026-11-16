import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/productive_models.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';

/// Pilihan tenggat cepat (kunci, label, tanggal). Tanggal tanpa jam (00.00).
List<(String, String, DateTime?)> dueChoices(AppStore store, [DateTime? now]) {
  final today = dayOnly(now ?? DateTime.now());
  final weekEnd = store.weekStart(today).add(const Duration(days: 6));
  final monthEnd = DateTime(today.year, today.month + 1, 0);
  return [
    ('today', tr('Hari ini'), today),
    ('tomorrow', tr('Besok'), today.add(const Duration(days: 1))),
    ('week', tr('Minggu ini'), weekEnd),
    ('month', tr('Akhir bulan'), monthEnd),
    ('none', tr('Tanpa tenggat'), null),
  ];
}

/// Kunci pilihan tenggat yang cocok dengan [due]; 'custom' kalau tanggal lain.
String dueKeyOf(AppStore store, DateTime? due, [DateTime? now]) {
  if (due == null) return 'none';
  final d = dayOnly(due);
  for (final (k, _, date) in dueChoices(store, now)) {
    if (date != null && date == d) return k;
  }
  return 'custom';
}

/// Warna bendera prioritas.
Color priColor(ZColors z, String pri) => switch (pri) {
      'tinggi' => z.warn,
      'rendah' => z.muted2,
      _ => z.toneFg('amber'),
    };

String priLabel(String pri) => tr(kPriorities.firstWhere((p) => p.$1 == pri, orElse: () => kPriorities[1]).$2);

/// Detail satu tugas: judul, catatan, sub-tugas, kategori, prioritas, tenggat, pengingat, dan pengulangan.
/// Dipakai di lembar bawah (HP) dan panel kanan (Windows). Semua perubahan langsung tersimpan.
class TodoDetail extends StatefulWidget {
  const TodoDetail({super.key, required this.todo, this.onClose, this.scroll = true});

  final Todo todo;
  final VoidCallback? onClose;

  /// false kalau sudah berada di dalam area gulir lain.
  final bool scroll;

  @override
  State<TodoDetail> createState() => _TodoDetailState();
}

class _TodoDetailState extends State<TodoDetail> {
  late final _title = TextEditingController(text: widget.todo.title);
  late final _notes = TextEditingController(text: widget.todo.notes);
  final _sub = TextEditingController();
  final _titleFocus = FocusNode();
  final _notesFocus = FocusNode();
  late AppStore _store;

  Todo get t => widget.todo;

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(() {
      if (!_titleFocus.hasFocus) _commitText();
    });
    _notesFocus.addListener(() {
      if (!_notesFocus.hasFocus) _commitText();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store = StoreScope.read(context);
  }

  @override
  void didUpdateWidget(TodoDetail old) {
    super.didUpdateWidget(old);
    if (old.todo.id != widget.todo.id) {
      _commitText(old.todo);
      _title.text = widget.todo.title;
      _notes.text = widget.todo.notes;
      _sub.clear();
    }
  }

  /// Judul dan catatan disimpan saat isian ditinggalkan (bukan tiap ketikan, supaya ringan).
  void _commitText([Todo? target]) {
    final x = target ?? t;
    final title = _title.text.trim();
    final notes = _notes.text.trim();
    if ((title.isEmpty || title == x.title) && notes == x.notes) return;
    if (title.isNotEmpty) x.title = title;
    x.notes = notes;
    _store.updateTodo(x);
  }

  @override
  void dispose() {
    _commitText();
    _title.dispose();
    _notes.dispose();
    _sub.dispose();
    _titleFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  void _save(void Function() change) {
    setState(change);
    _store.updateTodo(t);
  }

  void _addSub() {
    final v = _sub.text.trim();
    if (v.isEmpty) return;
    _save(() => t.subs.add(SubTask(v)));
    _sub.clear();
  }

  void _delete() {
    final store = _store;
    final gone = t;
    final messenger = ScaffoldMessenger.maybeOf(context);
    widget.onClose?.call();
    store.removeTodo(gone.id);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(
      content: Text(tr('Tugas dihapus')),
      action: SnackBarAction(label: tr('Urungkan'), onPressed: () => store.restoreTodo(gone)),
    ));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: t.due ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (d == null) return;
    final old = t.due;
    _save(() => t.due = old != null && t.hasTime ? DateTime(d.year, d.month, d.day, old.hour, old.minute) : d);
  }

  Future<void> _pickTime() async {
    final base = t.due ?? dayOnly(DateTime.now());
    final picked = await showTimePicker(context: context, initialTime: t.hasTime ? TimeOfDay.fromDateTime(base) : const TimeOfDay(hour: 9, minute: 0));
    if (picked == null) return;
    _save(() => t.due = DateTime(base.year, base.month, base.day, picked.hour, picked.minute));
  }

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final store = StoreScope.of(context);
    final doneSubs = t.subs.where((x) => x.done).length;
    final dueKey = dueKeyOf(store, t.due);

    Widget cap(String text, {String? extra}) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(children: [
            Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
            if (extra != null) ...[const SizedBox(width: 8), Text(extra, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: z.muted2))],
          ]),
        );
    Widget chips(List<Widget> children) => Wrap(spacing: 8, runSpacing: 4, children: children);

    final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        _Check(done: t.done, size: 28, label: t.title, onTap: () => setState(() => store.toggleTodo(t.id))),
        const SizedBox(width: 8),
        Expanded(child: Text(tr('Detail tugas'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: z.muted))),
        IconButton(tooltip: tr('Hapus tugas'), onPressed: _delete, icon: Icon(Icons.delete_outline_rounded, size: 20, color: z.text2)),
        if (widget.onClose != null) IconButton(tooltip: tr('Tutup'), onPressed: widget.onClose, icon: Icon(Icons.close_rounded, size: 20, color: z.text2)),
      ]),
      const SizedBox(height: 8),
      TextField(
        controller: _title,
        focusNode: _titleFocus,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        decoration: InputDecoration(hintText: tr('Judul tugas')),
        onSubmitted: (_) => _commitText(),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _notes,
        focusNode: _notesFocus,
        minLines: 3,
        maxLines: 6,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: tr('Tambahkan catatan…')),
      ),
      cap(tr('Sub-tugas'), extra: trf('{0} dari {1}', [doneSubs, t.subs.length])),
      if (t.subs.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: doneSubs / t.subs.length, minHeight: 5, backgroundColor: z.track, color: z.primary),
          ),
        ),
      for (var i = 0; i < t.subs.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            _Check(done: t.subs[i].done, size: 22, square: true, label: t.subs[i].t, onTap: () => _save(() => t.subs[i].done = !t.subs[i].done)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(t.subs[i].t,
                  style: TextStyle(fontSize: 14, color: t.subs[i].done ? z.muted2 : z.text, decoration: t.subs[i].done ? TextDecoration.lineThrough : null)),
            ),
            IconButton(
              tooltip: trf('Hapus sub-tugas {0}', [t.subs[i].t]),
              visualDensity: VisualDensity.compact,
              onPressed: () => _save(() => t.subs.removeAt(i)),
              icon: Icon(Icons.close_rounded, size: 18, color: z.muted2),
            ),
          ]),
        ),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _sub,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(hintText: tr('Tambah sub-tugas'), isDense: true),
            onSubmitted: (_) => _addSub(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          onPressed: _addSub,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 42), backgroundColor: z.track, foregroundColor: z.text2),
          child: Text(tr('Tambah')),
        ),
      ]),
      cap(tr('Kategori')),
      chips([
        for (final (c, tone) in kTodoCats)
          ZChip(label: tr(c), selected: t.cat == c, onTap: () => _save(() {
                t.cat = c;
                t.tone = tone;
              })),
      ]),
      cap(tr('Prioritas')),
      chips([
        for (final (k, l) in kPriorities) ZChip(label: tr(l), selected: t.pri == k, onTap: () => _save(() => t.pri = k)),
      ]),
      cap(tr('Tenggat'), extra: t.due == null ? null : (t.hasTime ? '${dayLabel(t.due!)}, ${timeLabel(t.due!)}' : dayLabel(t.due!))),
      chips([
        for (final (k, l, date) in dueChoices(store))
          ZChip(
            label: k == 'none' ? tr('Tanpa') : l,
            selected: dueKey == k,
            onTap: () => _save(() {
              final old = t.due;
              t.due = date == null ? null : (old != null && t.hasTime ? DateTime(date.year, date.month, date.day, old.hour, old.minute) : date);
            }),
          ),
        ZChip(label: dueKey == 'custom' ? dayLabel(t.due!) : tr('Pilih tanggal'), icon: Icons.event_outlined, selected: dueKey == 'custom', onTap: _pickDate),
        if (t.due != null)
          ZChip(label: t.hasTime ? timeLabel(t.due!) : tr('Atur jam'), icon: Icons.schedule_rounded, selected: t.hasTime, onTap: _pickTime),
      ]),
      cap(tr('Pengingat')),
      chips([
        for (final (m, l) in kRemindOpts) ZChip(label: tr(l), selected: t.remind == m, onTap: () => _save(() => t.remind = m)),
      ]),
      if (t.remind > 0 && t.due == null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(tr('Atur tenggat dulu supaya pengingat bisa dikirim.'), style: TextStyle(fontSize: 12, color: z.warn)),
        ),
      cap(tr('Ulangi')),
      chips([
        for (final (k, l) in kRepeatOpts) ZChip(label: tr(l), selected: t.repeat == k, onTap: () => _save(() => t.repeat = k)),
      ]),
      if (t.repeat != 'none')
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(tr('Saat ditandai selesai, tugas berikutnya dibuat otomatis.'), style: TextStyle(fontSize: 12, color: z.muted2)),
        ),
    ]);
    if (!widget.scroll) return body;
    return SingleChildScrollView(child: body);
  }
}

/// Lingkaran / kotak centang.
class _Check extends StatelessWidget {
  const _Check({required this.done, required this.onTap, required this.label, this.size = 28, this.square = false});

  final bool done;
  final VoidCallback onTap;
  final String label;
  final double size;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Semantics(
      button: true,
      checked: done,
      label: done ? trf('Batalkan selesai: {0}', [label]) : trf('Tandai selesai: {0}', [label]),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: square ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: square ? BorderRadius.circular(6) : null,
              color: done ? z.primary : Colors.transparent,
              border: Border.all(color: done ? z.primary : z.chipBorder, width: 2),
            ),
            child: done ? Icon(Icons.check_rounded, size: size * 0.6, color: z.onPrimary) : null,
          ),
        ),
      ),
    );
  }
}

/// Detail tugas: lembar bawah di HP, dialog di jendela lebar.
Future<void> showTodoDetail(BuildContext context, Todo todo) {
  if (MediaQuery.sizeOf(context).width >= 900) {
    return showZDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 460, maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: TodoDetail(todo: todo, onClose: () => Navigator.of(ctx).maybePop()),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    sheetAnimationStyle: kSheetAnimation,
    context: context,
    isScrollControlled: true,
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.9),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
        child: TodoDetail(todo: todo, onClose: () => Navigator.of(ctx).maybePop()),
      ),
    ),
  );
}

/// Label tenggat untuk baris tugas (mis. "Hari ini, 10.00", "Terlambat · Kemarin").
String todoDueText(Todo t) {
  if (t.due == null) return tr('Tanpa tenggat');
  final base = t.hasTime ? '${dayLabel(t.due!)}, ${timeLabel(t.due!)}' : dayLabel(t.due!);
  return t.isOverdue() ? trf('Terlambat · {0}', [base]) : base;
}

/// Saring, urutkan, dan kelompokkan tugas (dipakai halaman Tugas HP dan Windows).
class TaskQuery {
  String q = '';

  /// 'all' | 'open' | 'today' | 'late' | 'done'
  String status = 'all';

  /// 'due' (tenggat terdekat) | 'pri' (prioritas tertinggi) | 'name' (A–Z)
  String sort = 'due';

  /// '' = semua kategori.
  String cat = '';

  /// '' = semua prioritas.
  String pri = '';

  static const bucketOrder = ['late', 'today', 'tomorrow', 'week', 'later', 'none'];

  static List<(String, String)> get sorts => [('due', tr('Tenggat terdekat')), ('pri', tr('Prioritas tertinggi')), ('name', tr('Nama A–Z'))];
  static List<(String, String)> get cats => [('', tr('Semua kategori')), for (final c in kTodoCats) (c.$1, tr(c.$1))];
  static List<(String, String)> get pris => [('', tr('Semua prioritas')), for (final (k, l) in kPriorities) (k, trf('Prioritas {0}', [tr(l).toLowerCase()]))];

  bool _matchStatus(Todo t, String st, String b) => switch (st) {
        'open' => !t.done,
        'today' => !t.done && b == 'today',
        'late' => b == 'late',
        'done' => t.done,
        _ => true,
      };

  /// Jumlah tugas per status (untuk angka di chip penyaring), tanpa memperhitungkan status terpilih.
  Map<String, int> counts(AppStore store) {
    final now = DateTime.now();
    final m = {'all': 0, 'open': 0, 'today': 0, 'late': 0, 'done': 0};
    for (final t in store.todos) {
      final b = t.bucket(now: now, mondayFirst: store.weekStartMonday);
      for (final k in m.keys.toList()) {
        if (_matchStatus(t, k, b)) m[k] = m[k]! + 1;
      }
    }
    return m;
  }

  List<Todo> apply(AppStore store) {
    final now = DateTime.now();
    final query = q.trim().toLowerCase();
    final out = store.todos.where((t) {
      if (cat.isNotEmpty && t.cat != cat) return false;
      if (pri.isNotEmpty && t.pri != pri) return false;
      if (query.isNotEmpty && !t.title.toLowerCase().contains(query) && !t.notes.toLowerCase().contains(query)) return false;
      return _matchStatus(t, status, t.bucket(now: now, mondayFirst: store.weekStartMonday));
    }).toList();
    int byDue(Todo a, Todo b) {
      final ba = bucketOrder.indexOf(a.bucket(now: now, mondayFirst: store.weekStartMonday));
      final bb = bucketOrder.indexOf(b.bucket(now: now, mondayFirst: store.weekStartMonday));
      if (ba != bb) return ba - bb;
      final ad = a.due, bd = b.due;
      if (ad != null && bd != null && ad != bd) return ad.compareTo(bd);
      return 0;
    }

    out.sort((a, b) {
      switch (sort) {
        case 'name':
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case 'pri':
          final p = priRank(b.pri) - priRank(a.pri);
          return p != 0 ? p : byDue(a, b);
      }
      final d = byDue(a, b);
      return d != 0 ? d : priRank(b.pri) - priRank(a.pri);
    });
    return out;
  }

  /// Kelompok (kunci, judul, ikon, tugas): belum selesai per tenggat, lalu "Selesai".
  List<(String, String, IconData, List<Todo>)> groups(AppStore store, List<Todo> list) {
    final now = DateTime.now();
    const titles = {
      'late': ('Terlambat', Icons.warning_amber_rounded),
      'today': ('Hari ini', Icons.today_rounded),
      'tomorrow': ('Besok', Icons.event_outlined),
      'week': ('Minggu ini', Icons.date_range_rounded),
      'later': ('Nanti', Icons.schedule_rounded),
      'none': ('Tanpa tenggat', Icons.all_inbox_outlined),
    };
    final out = <(String, String, IconData, List<Todo>)>[];
    for (final k in bucketOrder) {
      final rows = list.where((t) => !t.done && t.bucket(now: now, mondayFirst: store.weekStartMonday) == k).toList();
      if (rows.isNotEmpty) out.add((k, tr(titles[k]!.$1), titles[k]!.$2, rows));
    }
    final done = list.where((t) => t.done).toList();
    if (done.isNotEmpty) out.add(('done', tr('Selesai'), Icons.task_alt_rounded, done));
    return out;
  }
}
