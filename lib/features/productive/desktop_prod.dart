import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/productive_models.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart' show RowIn;
import '../../shell/desktop_page.dart';
import '../../widgets/common.dart';
import '../../widgets/count_up.dart';
import 'prod_common.dart';
import 'todo_detail.dart';

Widget _addBtn(BuildContext context, String label, VoidCallback onTap) => FilledButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add_rounded, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 20)),
    );

String _longDate(DateTime d) => '${weekdayName(d)}, ${d.day} ${monthLong(d)} ${d.year}';

String weekdayName(DateTime d) {
  const id = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return (L.en ? en : id)[d.weekday - 1];
}

/// Hari ini (Produktif) untuk jendela lebar: fokus, agenda, tugas, dan catatan tersemat.
class DesktopProdHome extends StatefulWidget {
  const DesktopProdHome({super.key, required this.goTo});

  final ValueChanged<int> goTo;

  @override
  State<DesktopProdHome> createState() => _DesktopProdHomeState();
}

class _DesktopProdHomeState extends State<DesktopProdHome> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    final store = StoreScope.read(context);
    final d = dayOnly(DateTime.now());
    store.addTodo(t, cat: kTodoCats[0].$1, tone: kTodoCats[0].$2, due: d);
    _ctrl.clear();
    showZToast(context, tr('Tugas ditambahkan'));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final today = store.todayTodos;
    final done = today.where((t) => t.done).length;
    final waiting = today.length - done;
    final agenda = store.agendaOn(DateTime.now());
    final pinned = store.sortedNotes.where((n) => n.pinned).take(3).toList();
    final name = store.userName.isEmpty ? '' : ', ${store.userName}';

    final hero = GlassPane(
      hero: true,
      color: z.hero,
      color2: z.hero2,
      radius: 22,
      border: Border.all(color: z.heroBorder),
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
      child: Center(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          DRing(
            value: today.isEmpty ? 0 : done / today.length,
            size: 116,
            stroke: 11,
            color: z.hi,
            track: Colors.white.withValues(alpha: 0.14),
            center: Text('$done/${today.length}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(width: 28),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('${greeting()}$name', style: TextStyle(fontSize: 14, color: z.heroMuted)),
              const SizedBox(height: 4),
              Text(trf('{0} tugas menunggu', [waiting]), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.6)),
              const SizedBox(height: 4),
              Text(trf('{0} agenda hari ini', [agenda.length]), style: TextStyle(fontSize: 13, color: z.heroMuted)),
            ]),
          ),
        ]),
      ),
    );

    final agendaCard = DCard(
      title: tr('Agenda hari ini'),
      link: tr('Kalender'),
      onLink: () => widget.goTo(2),
      child: agenda.isEmpty
          ? Text(tr('Tidak ada agenda hari ini'), style: TextStyle(fontSize: 13, color: z.muted))
          : Column(children: [
              for (final (i, a) in agenda.take(5).indexed)
                RowIn(
                  index: i,
                  child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    IconTile(icon: a.reminder ? Icons.notifications_none_rounded : Icons.event_outlined, tone: a.tone, size: 38, radius: 11),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        Text(timeLabel(a.at), style: TextStyle(fontSize: 12.5, color: z.muted2)),
                      ]),
                    ),
                  ]),
                ),
                ),
            ]),
    );

    final tasks = DCard(
      title: tr('Tugas hari ini'),
      link: tr('Semua tugas'),
      onLink: () => widget.goTo(1),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              onSubmitted: (_) => _add(),
              decoration: InputDecoration(
                hintText: tr('Tugas untuk hari ini...'),
                isDense: true,
                filled: true,
                fillColor: z.card,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: z.chipBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: z.primary, width: 2)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(onPressed: _add, style: FilledButton.styleFrom(minimumSize: const Size(0, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(tr('Tambah'), style: const TextStyle(fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 8),
        if (today.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text(tr('Belum ada tugas untuk hari ini'), style: TextStyle(color: z.muted)))
        else
          for (var i = 0; i < today.length; i++) RowIn(index: i, child: TodoRow(todo: today[i], showDivider: i < today.length - 1)),
      ]),
    );

    final notes = DCard(
      title: tr('Catatan tersemat'),
      link: tr('Semua'),
      onLink: () => widget.goTo(3),
      child: pinned.isEmpty
          ? Text(tr('Belum ada catatan tersemat'), style: TextStyle(fontSize: 13, color: z.muted))
          : Column(children: [
              for (final n in pinned)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: z.toneBg(n.tone), borderRadius: BorderRadius.circular(14)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n.title.isEmpty ? tr('Tanpa judul') : n.title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: z.toneFg(n.tone))),
                    if (!n.locked && n.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(n.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, height: 1.4, color: z.toneFg(n.tone))),
                    ],
                  ]),
                ),
            ]),
    );

    return DesktopPage(
      title: tr('Hari ini'),
      subtitle: _longDate(DateTime.now()),
      action: _addBtn(context, tr('Tugas baru'), () => showAddTodo(context)),
      children: [
        DCols(minChild: 340, flex: const [7, 3], children: [hero, agendaCard]),
        const SizedBox(height: 20),
        DCols(minChild: 340, flex: const [7, 3], children: [tasks, notes]),
      ],
    );
  }
}

// ---------------------------------------------------------------------------------------------

class DesktopTodos extends StatefulWidget {
  const DesktopTodos({super.key});

  @override
  State<DesktopTodos> createState() => _DesktopTodosState();
}

/// Tugas di Windows (prototipe): ringkasan 4 angka, kartu saring (cari, Daftar/Papan, urut, kategori,
/// prioritas, status), lalu daftar per tenggat atau papan 3 kolom. Panel kanan = detail tugas terpilih
/// atau aktivitas 7 hari.
class _DesktopTodosState extends State<DesktopTodos> {
  final _query = TaskQuery();
  String _view = 'list';
  String? _sel;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final today = dayOnly(DateTime.now());
    final counts = _query.counts(store);
    final list = _query.apply(store);
    final groups = _query.groups(store, list);
    final selected = _sel == null ? null : store.todoById(_sel!);

    void open(Todo t) => setState(() => _sel = _sel == t.id ? null : t.id);

    Widget stat(IconData icon, int n, String label) => DCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(children: [
            IconTile(icon: icon, tone: 'gray', size: 38, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('$n', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1)),
                const SizedBox(height: 3),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: z.muted2)),
              ]),
            ),
          ]),
        );

    Widget dropdown(String value, List<(String, String)> items, ValueChanged<String> on) => Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: z.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: z.border, width: 1.5)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
              icon: Icon(Icons.expand_more_rounded, color: z.muted),
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: z.text, fontFamily: kFont),
              items: [for (final (v, l) in items) DropdownMenuItem(value: v, child: Text(l, overflow: TextOverflow.ellipsis))],
              onChanged: (v) {
                if (v != null) setState(() => on(v));
              },
            ),
          ),
        );

    final filters = DCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _query.q = v),
              decoration: InputDecoration(
                hintText: tr('Cari tugas atau catatannya'),
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: z.muted2),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 220,
            child: Segmented<String>(
              items: [('list', tr('Daftar')), ('board', tr('Papan'))],
              value: _view,
              height: 36,
              onChanged: (v) => setState(() => _view = v),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(flex: 11, child: dropdown(_query.sort, TaskQuery.sorts, (v) => _query.sort = v)),
          const SizedBox(width: 10),
          Expanded(flex: 10, child: dropdown(_query.cat, TaskQuery.cats, (v) => _query.cat = v)),
          const SizedBox(width: 10),
          Expanded(flex: 10, child: dropdown(_query.pri, TaskQuery.pris, (v) => _query.pri = v)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final (k, l) in [
            ('all', tr('Semua')),
            ('open', tr('Belum selesai')),
            ('today', tr('Hari ini')),
            ('late', tr('Terlambat')),
            ('done', tr('Selesai')),
          ])
            ZChip(label: '$l  ${counts[k]}', selected: _query.status == k, onTap: () => setState(() => _query.status = k)),
        ]),
      ]),
    );

    final empty = Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: EmptyState(
        icon: Icons.task_alt_rounded,
        title: store.todos.isEmpty ? tr('Belum ada tugas') : tr('Tidak ada tugas yang cocok'),
        message: store.todos.isEmpty ? tr('Tekan “Tugas baru” untuk menambah.') : tr('Ubah filter atau tekan “Tugas baru”.'),
      ),
    );

    final Widget body;
    if (_view == 'list') {
      var row = 0;
      body = DCard(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: groups.isEmpty
            ? empty
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final (_, title, icon, rows) in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 14, 6, 4),
                    child: Row(children: [
                      Icon(icon, size: 17, color: z.text2),
                      const SizedBox(width: 8),
                      Text(title.toUpperCase(), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1, color: z.text2)),
                    ]),
                  ),
                  for (var i = 0; i < rows.length; i++)
                    RowIn(
                      index: row++,
                      child: TodoRow(todo: rows[i], showDivider: i < rows.length - 1, selected: rows[i].id == _sel, showPriText: true, onOpen: () => open(rows[i])),
                    ),
                ],
              ]),
      );
    } else {
      final now = DateTime.now();
      final pending = list.where((t) => !t.done).toList();
      final cols = [
        (tr('Terlambat & hari ini'), Icons.bolt_rounded, pending.where((t) => const ['late', 'today'].contains(t.bucket(now: now, mondayFirst: store.weekStartMonday))).toList()),
        (tr('Mendatang'), Icons.schedule_rounded, pending.where((t) => !const ['late', 'today'].contains(t.bucket(now: now, mondayFirst: store.weekStartMonday))).toList()),
        (tr('Selesai'), Icons.task_alt_rounded, list.where((t) => t.done).toList()),
      ];
      body = DCols(minChild: 200, gap: 16, children: [
        for (final (title, icon, cards) in cols)
          Container(
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(minHeight: 300),
            decoration: BoxDecoration(color: z.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: z.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
                child: Row(children: [
                  Icon(icon, size: 18, color: z.text2),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: z.toneBg('gray'), borderRadius: BorderRadius.circular(99)),
                    child: Text('${cards.length}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: z.toneFg('gray'))),
                  ),
                ]),
              ),
              for (final t in cards) _BoardCard(todo: t, selected: t.id == _sel, onOpen: () => open(t)),
              if (cards.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(tr('Kosong'), textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: z.muted2)),
                ),
            ]),
          ),
      ]);
    }

    // Aktivitas 7 hari: tugas yang diselesaikan per hari.
    final act = List<int>.filled(7, 0);
    for (final t in store.todos) {
      final d = t.doneAt;
      if (d == null) continue;
      final k = today.difference(dayOnly(d)).inDays;
      if (k >= 0 && k < 7) act[6 - k]++;
    }
    final maxAct = act.fold<int>(1, (a, b) => a > b ? a : b);
    final activity = DCard(
      title: tr('Aktivitas 7 hari'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 120,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  FillIn(
                    // Batang tumbuh bergantian (prototipe growH 0,9 s, tertunda 0,245 s + 45 ms per batang).
                    duration: const Duration(milliseconds: 900),
                    delay: Duration(milliseconds: 245 + 45 * i),
                    value: act[i] == 0 ? 0.08 : (0.2 + 0.8 * act[i] / maxAct),
                    builder: (_, v) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      height: 88 * v,
                      decoration: BoxDecoration(
                        color: z.primary.withValues(alpha: i == 6 ? 1 : 0.55),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(7), bottom: Radius.circular(3)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(weekdayName(today.subtract(Duration(days: 6 - i))).substring(0, 3), style: TextStyle(fontSize: 11.5, color: z.muted2)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 14),
        Text(tr('Klik sebuah tugas untuk melihat detail: sub-tugas, catatan, prioritas, tenggat, pengingat, dan pengulangan.'),
            style: TextStyle(fontSize: 12.5, height: 1.55, color: z.muted)),
      ]),
    );

    final aside = selected == null
        ? activity
        : DCard(
            padding: const EdgeInsets.all(20),
            child: TodoDetail(key: ValueKey(selected.id), todo: selected, scroll: false, onClose: () => setState(() => _sel = null)),
          );

    final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DCols(minChild: 150, gap: 14, children: [
        stat(Icons.radio_button_unchecked_rounded, counts['open']!, tr('Belum selesai')),
        stat(Icons.task_alt_rounded, counts['done']!, tr('Selesai')),
        stat(Icons.warning_amber_rounded, counts['late']!, tr('Terlambat')),
        stat(Icons.today_rounded, counts['today']!, tr('Hari ini')),
      ]),
      const SizedBox(height: 16),
      filters,
      const SizedBox(height: 16),
      body,
    ]);

    return DesktopPage(
      title: tr('Tugas'),
      subtitle: tr('Daftar tugas dan pengingat'),
      action: _addBtn(context, tr('Tugas baru'), () => showAddTodo(context)),
      children: [
        LayoutBuilder(builder: (context, box) {
          if (box.maxWidth < 980) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 20), aside]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: left),
            const SizedBox(width: 20),
            SizedBox(width: 380, child: aside),
          ]);
        }),
      ],
    );
  }
}

/// Kartu tugas di tampilan Papan.
class _BoardCard extends StatelessWidget {
  const _BoardCard({required this.todo, required this.selected, required this.onOpen});

  final Todo todo;
  final bool selected;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final store = StoreScope.read(context);
    final doneSubs = todo.subs.where((x) => x.done).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: z.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? z.primary : z.border, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Semantics(
                  button: true,
                  checked: todo.done,
                  label: todo.done ? trf('Batalkan selesai: {0}', [todo.title]) : trf('Tandai selesai: {0}', [todo.title]),
                  child: GestureDetector(
                    onTap: () => store.toggleTodo(todo.id),
                    child: Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(top: 1, right: 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: todo.done ? z.primary : Colors.transparent,
                        border: Border.all(color: todo.done ? z.primary : z.chipBorder, width: 2),
                      ),
                      child: todo.done ? Icon(Icons.check_rounded, size: 14, color: z.onPrimary) : null,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(todo.title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: todo.done ? z.muted2 : z.text,
                            decoration: todo.done ? TextDecoration.lineThrough : null)),
                    const SizedBox(height: 2),
                    Text(todoDueText(todo), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: todo.isOverdue() ? z.warn : z.muted)),
                  ]),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: z.toneBg(todo.tone), borderRadius: BorderRadius.circular(99)),
                  child: Text(tr(todo.cat), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: z.toneFg(todo.tone))),
                ),
                const SizedBox(width: 8),
                Icon(Icons.flag_rounded, size: 15, color: priColor(z, todo.pri)),
                const SizedBox(width: 3),
                Text(priLabel(todo.pri), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: priColor(z, todo.pri))),
                const Spacer(),
                if (todo.subs.isNotEmpty) ...[
                  Icon(Icons.checklist_rounded, size: 15, color: z.muted2),
                  const SizedBox(width: 3),
                  Text('$doneSubs/${todo.subs.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: z.muted2)),
                ],
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------

/// Kalender untuk jendela lebar: grid bulan penuh dengan agenda per hari, dan panel jadwal hari terpilih di kanan.
class DesktopCalendar extends StatefulWidget {
  const DesktopCalendar({super.key});

  @override
  State<DesktopCalendar> createState() => _DesktopCalendarState();
}

class _DesktopCalendarState extends State<DesktopCalendar> {
  String _view = 'month'; // month, week, agenda
  DateTime _sel = dayOnly(DateTime.now());
  late DateTime _month = DateTime(_sel.year, _sel.month);
  bool _tasks = true;
  String _tone = 'all';

  List<Agenda> _on(AppStore store, DateTime d) => store.agendaOn(d).where((a) => _tone == 'all' || a.tone == _tone).toList();

  void _shift(int dir) => setState(() {
        if (_view == 'week') {
          _sel = _sel.add(Duration(days: 7 * dir));
          _month = DateTime(_sel.year, _sel.month);
        } else {
          _month = DateTime(_month.year, _month.month + dir);
        }
      });

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final today = dayOnly(DateTime.now());
    final weekdayNames = L.en ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'] : ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final names = store.weekStartMonday ? weekdayNames : [weekdayNames[6], ...weekdayNames.take(6)];

    final DateTime gridStart;
    final int weeks;
    if (_view == 'week') {
      gridStart = store.weekStart(_sel);
      weeks = 1;
    } else {
      final first = _month;
      final lead = store.weekStartMonday ? first.weekday - 1 : first.weekday % 7;
      gridStart = first.subtract(Duration(days: lead));
      final days = DateTime(first.year, first.month + 1, 0).day;
      weeks = ((lead + days) / 7).ceil();
    }
    final title = _view == 'week' ? '${monthLong(_sel)} ${_sel.year}' : '${monthLong(_month)} ${_month.year}';

    Widget cell(DateTime d) {
      final inMonth = _view == 'week' || d.month == _month.month;
      final items = _on(store, d);
      final due = _tasks ? store.todos.where((t) => !t.done && t.due != null && dayOnly(t.due!) == d).length : 0;
      final isToday = d == today, isSel = d == _sel;
      // Prototipe: akhir pekan berlatar sedikit gelap (.mcell.wk), tanggal di luar bulan dipudarkan (.out).
      final weekend = d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
      return Opacity(
        opacity: inMonth ? 1 : 0.45,
        child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: weekend ? Color.alphaBlend(z.track.withValues(alpha: 0.6), z.card) : z.card,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() {
              _sel = d;
              if (_view == 'month' && d.month != _month.month) _month = DateTime(d.year, d.month);
            }),
            child: Container(
              // Prototipe .mcell: tinggi minimal 80, ikut memanjang kalau isinya banyak.
              constraints: BoxConstraints(minHeight: _view == 'week' ? 260 : 82),
              padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: isSel ? z.primary : z.border, width: isSel ? 2 : 1)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: isToday ? z.primary : Colors.transparent),
                    child: Text('${d.day}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isToday ? z.onPrimary : (inMonth ? z.text : z.muted2))),
                  ),
                  const Spacer(),
                  if (due > 0) ...[Icon(Icons.task_alt_rounded, size: 13, color: z.text2), const SizedBox(width: 2), Text('$due', style: TextStyle(fontSize: 11, color: z.text2))],
                ]),
                const SizedBox(height: 3),
                for (final a in items.take(_view == 'week' ? 8 : 2))
                  Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(color: z.toneBg(a.tone), borderRadius: BorderRadius.circular(5)),
                    child: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: z.toneFg(a.tone))),
                  ),
                if (_view == 'month' && items.length > 2) Text('+${items.length - 2} ${tr('lagi')}', style: TextStyle(fontSize: 10, color: z.muted)),
              ]),
            ),
          ),
        ),
        ),
      );
    }

    final controls = DCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 10, children: [
        IconButton.outlined(onPressed: () => _shift(-1), tooltip: tr('Sebelumnya'), icon: const Icon(Icons.chevron_left_rounded)),
        IconButton.outlined(onPressed: () => _shift(1), tooltip: tr('Berikutnya'), icon: const Icon(Icons.chevron_right_rounded)),
        Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        FilledButton.tonal(
          onPressed: () => setState(() {
            _sel = today;
            _month = DateTime(today.year, today.month);
          }),
          child: Text(tr('Hari ini'), style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        SizedBox(
          width: 270,
          child: Segmented<String>(
            height: 40,
            items: [('month', tr('Bulan')), ('week', tr('Minggu')), ('agenda', tr('Agenda'))],
            value: _view,
            onChanged: (v) => setState(() => _view = v),
          ),
        ),
        ZChip(label: tr('Tugas'), icon: Icons.task_alt_rounded, selected: _tasks, onTap: () => setState(() => _tasks = !_tasks)),
        // Saring warna (prototipe: "Warna" + titik warna). Tiap butir anak Wrap supaya bisa turun baris.
        Text(tr('Warna'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: z.muted2)),
          for (final (k, l) in [('all', tr('Semua')), for (final (k, l) in kAgendaTones) (k, tr(l))])
            Padding(
              padding: EdgeInsets.zero,
              child: Tooltip(
                message: l,
                child: Semantics(
                  button: true,
                  selected: _tone == k,
                  label: trf('Warna {0}', [l]),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: () => setState(() => _tone = k),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: _tone == k ? z.primary : z.card,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: _tone == k ? z.primary : z.chipBorder),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: k == 'all' ? z.muted2 : z.chart(k))),
                        if (k == 'all') ...[
                          const SizedBox(width: 6),
                          Text(l, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _tone == k ? z.onPrimary : z.text2)),
                        ],
                      ]),
                    ),
                  ),
                ),
              ),
            ),
      ]),
    );

    final Widget main;
    if (_view == 'agenda') {
      final start = _month;
      final end = DateTime(_month.year, _month.month + 1, 0);
      final days = [for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) d];
      main = DCard(
        title: '${monthLong(_month)} ${_month.year}',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final d in days)
            if (_on(store, d).isNotEmpty) ...[
              Padding(padding: const EdgeInsets.only(top: 10, bottom: 6), child: Text(_longDate(d), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: z.text2))),
              for (final (i, a) in _on(store, d).indexed) RowIn(index: i, child: AgendaRow(item: a)),
            ],
          if (days.every((d) => _on(store, d).isEmpty))
            Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text(tr('Belum ada agenda bulan ini'), textAlign: TextAlign.center, style: TextStyle(color: z.muted))),
        ]),
      );
    } else {
      main = DCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(children: [
          Row(children: [for (final n in names) Expanded(child: Center(child: Text(n, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: z.text2))))]),
          const SizedBox(height: 6),
          for (var w = 0; w < weeks; w++)
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < 7; i++) Expanded(child: cell(gridStart.add(Duration(days: w * 7 + i))))]),
            ),
        ]),
      );
    }

    final items = _on(store, _sel);
    // Tugas yang tenggatnya jatuh di hari terpilih (bukan semua tugas terlambat).
    final overdue = _tasks ? store.todos.where((t) => !t.done && t.due != null && dayOnly(t.due!) == _sel).toList() : <Todo>[];
    final side = DCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(color: z.primary, borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              Text(monthShort(_sel).toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: z.onPrimary)),
              Text('${_sel.day}', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: z.onPrimary, height: 1.1)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_longDate(_sel), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              Text(trf('{0} agenda · {1} tugas bertenggat', [items.length, overdue.length]), style: TextStyle(fontSize: 12.5, color: z.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => showAddAgenda(context, _sel),
          icon: const Icon(Icons.add_rounded, size: 19),
          label: Text(tr('Tambah agenda di hari ini'), style: const TextStyle(fontWeight: FontWeight.w800)),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
        ),
        const SizedBox(height: 16),
        Text(tr('Jadwal'), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(tr('Belum ada agenda'), style: TextStyle(color: z.muted)))
        else ...[
          // Garis waktu harian (prototipe): jam 06.00–22.00, agenda ditempatkan sesuai jam mulai dan lamanya.
          _DayTimeline(items: items),
        ],
        if (overdue.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(tr('Tugas bertenggat'), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          for (var i = 0; i < overdue.length; i++) RowIn(index: i, child: TodoRow(todo: overdue[i], showDivider: i < overdue.length - 1)),
        ],
      ]),
    );

    return DesktopPage(
      title: tr('Kalender'),
      subtitle: tr('Agenda bulan ini'),
      action: _addBtn(context, tr('Agenda baru'), () => showAddAgenda(context, _sel)),
      children: [
        LayoutBuilder(builder: (context, box) {
          if (box.maxWidth < 900) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [controls, const SizedBox(height: 16), main, const SizedBox(height: 16), side]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 7, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [controls, const SizedBox(height: 16), main])),
            const SizedBox(width: 20),
            Expanded(flex: 3, child: side),
          ]);
        }),
      ],
    );
  }
}


/// Garis waktu satu hari: baris per jam, agenda sebagai balok berwarna setinggi lamanya. Ketuk = rincian.
class _DayTimeline extends StatelessWidget {
  const _DayTimeline({required this.items});

  final List<Agenda> items;

  static const rowH = 22.0;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    var first = 6, last = 22;
    for (final a in items) {
      first = a.at.hour < first ? a.at.hour : first;
      final endH = a.end.day != a.at.day ? 24 : (a.end.hour + (a.end.minute > 0 ? 1 : 0));
      last = endH > last ? endH.clamp(0, 24) : last;
    }
    final hours = last - first;
    return SizedBox(
      height: hours * rowH + 14,
      child: Stack(children: [
        for (var h = 0; h <= hours; h++)
          Positioned(
            top: h * rowH,
            left: 0,
            right: 0,
            child: Row(children: [
              SizedBox(width: 40, child: Text('${(first + h).toString().padLeft(2, '0')}.00', style: TextStyle(fontSize: 10.5, color: z.muted2, height: 1))),
              Expanded(child: Container(height: 1, color: z.divider)),
            ]),
          ),
        for (final a in items)
          Positioned(
            top: ((a.at.hour - first) * 60 + a.at.minute) / 60 * rowH + 1,
            left: 44,
            right: 0,
            height: (a.durMin / 60 * rowH).clamp(rowH - 2, double.infinity) - 2,
            child: Material(
              color: z.toneBg(a.tone),
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => showAgendaSheet(context, a),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${timeLabel(a.at)}  ${a.title}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: z.toneFg(a.tone))),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
