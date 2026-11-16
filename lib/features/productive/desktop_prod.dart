import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/productive_models.dart';
import '../../data/store.dart';
import '../../shell/desktop_page.dart';
import '../../widgets/common.dart';
import '../../widgets/count_up.dart';
import 'prod_common.dart';

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
      radius: 20,
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
              for (final a in agenda.take(5))
                Padding(
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
          for (var i = 0; i < today.length; i++) TodoRow(todo: today[i], showDivider: i < today.length - 1),
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

enum _Group { late, today, tomorrow, week, later, none, done }

/// Tugas untuk jendela lebar: ringkasan angka, pencarian, penyaring, daftar bergrup, dan grafik aktivitas.
class DesktopTodos extends StatefulWidget {
  const DesktopTodos({super.key});

  @override
  State<DesktopTodos> createState() => _DesktopTodosState();
}

class _DesktopTodosState extends State<DesktopTodos> {
  String _q = '';
  String _status = 'all'; // all, open, today, late, done
  String _cat = '';
  String _sort = 'due'; // due, name

  _Group _groupOf(Todo t, DateTime today) {
    if (t.done) return _Group.done;
    if (t.isOverdue()) return _Group.late;
    final d = t.due;
    if (d == null) return _Group.none;
    final day = dayOnly(d);
    final diff = day.difference(today).inDays;
    if (diff <= 0) return _Group.today;
    if (diff == 1) return _Group.tomorrow;
    if (diff <= 7) return _Group.week;
    return _Group.later;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final today = dayOnly(DateTime.now());
    final all = store.todos;
    final late = all.where((t) => t.isOverdue()).length;
    final doneN = all.where((t) => t.done).length;
    final openN = all.length - doneN;
    final todayN = all.where((t) => !t.done && t.due != null && dayOnly(t.due!) == today).length;

    final q = _q.trim().toLowerCase();
    var list = all.where((t) {
      if (q.isNotEmpty && !t.title.toLowerCase().contains(q)) return false;
      if (_cat.isNotEmpty && t.cat != _cat) return false;
      switch (_status) {
        case 'open':
          return !t.done;
        case 'today':
          return !t.done && t.due != null && dayOnly(t.due!) == today;
        case 'late':
          return t.isOverdue();
        case 'done':
          return t.done;
      }
      return true;
    }).toList();
    list.sort((a, b) {
      if (_sort == 'name') return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      final ad = a.due, bd = b.due;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
    final groups = <_Group, List<Todo>>{};
    for (final t in list) {
      groups.putIfAbsent(_groupOf(t, today), () => []).add(t);
    }
    String gTitle(_Group g) => switch (g) {
          _Group.late => tr('Terlambat'),
          _Group.today => tr('Hari ini'),
          _Group.tomorrow => tr('Besok'),
          _Group.week => tr('Minggu ini'),
          _Group.later => tr('Nanti'),
          _Group.none => tr('Tanpa tenggat'),
          _Group.done => tr('Selesai'),
        };
    IconData gIcon(_Group g) => switch (g) {
          _Group.late => Icons.warning_amber_rounded,
          _Group.today || _Group.tomorrow || _Group.week => Icons.event_outlined,
          _Group.later => Icons.schedule_rounded,
          _Group.none => Icons.inbox_outlined,
          _Group.done => Icons.check_circle_outline_rounded,
        };

    Widget stat(IconData icon, String tone, int n, String label) => DCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(children: [
            IconTile(icon: icon, tone: tone, size: 40, radius: 12),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('$n', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.1)),
              Text(label, style: TextStyle(fontSize: 12, color: z.muted2)),
            ]),
          ]),
        );

    Widget chip(String k, String label, int n) => ZChip(label: '$label  $n', selected: _status == k, onTap: () => setState(() => _status = k));

    Widget dropdown<T>(T value, List<(T, String)> items, ValueChanged<T> on) => Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: z.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: z.chipBorder)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
              icon: Icon(Icons.expand_more_rounded, color: z.muted),
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: z.text, fontFamily: kFont),
              items: [for (final (v, l) in items) DropdownMenuItem(value: v, child: Text(l))],
              onChanged: (v) {
                if (v != null) on(v);
              },
            ),
          ),
        );

    final filters = DCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(
            hintText: tr('Cari tugas'),
            isDense: true,
            prefixIcon: Icon(Icons.search_rounded, size: 20, color: z.muted2),
            filled: true,
            fillColor: z.card,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: z.chipBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: z.primary, width: 2)),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: dropdown<String>(_sort, [('due', tr('Urut: Tenggat terdekat')), ('name', tr('Urut: Nama'))], (v) => setState(() => _sort = v))),
          const SizedBox(width: 12),
          Expanded(child: dropdown<String>(_cat, [('', tr('Semua kategori')), for (final c in kTodoCats) (c.$1, tr(c.$1))], (v) => setState(() => _cat = v))),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          chip('all', tr('Semua'), all.length),
          chip('open', tr('Belum selesai'), openN),
          chip('today', tr('Hari ini'), todayN),
          chip('late', tr('Terlambat'), late),
          chip('done', tr('Selesai'), doneN),
        ]),
      ]),
    );

    final listCard = DCard(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
      child: list.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: EmptyState(icon: Icons.checklist_rounded, title: tr('Belum ada tugas di sini'), message: tr('Tekan + untuk menambah tugas.')),
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final g in _Group.values)
                if (groups[g] != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 2),
                    child: Row(children: [
                      Icon(gIcon(g), size: 17, color: z.text2),
                      const SizedBox(width: 8),
                      Text(gTitle(g).toUpperCase(), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1, color: z.text2)),
                    ]),
                  ),
                  for (var i = 0; i < groups[g]!.length; i++) TodoRow(todo: groups[g]![i], showDivider: i < groups[g]!.length - 1),
                ],
            ]),
    );

    // Aktivitas 7 hari: tugas yang diselesaikan per hari.
    final act = List<int>.filled(7, 0);
    for (final t in all) {
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
          height: 110,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  FillIn(
                    value: act[i] == 0 ? 0.08 : (0.2 + 0.8 * act[i] / maxAct),
                    builder: (_, v) => Container(
                      width: 34,
                      height: 78 * v,
                      decoration: BoxDecoration(color: z.primary, borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(weekdayName(today.subtract(Duration(days: 6 - i))).substring(0, 3), style: TextStyle(fontSize: 11, color: z.muted2)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 14),
        Text(tr('Tekan lama sebuah tugas untuk menghapusnya. Ketuk lingkaran untuk menandai selesai.'), style: TextStyle(fontSize: 12.5, height: 1.45, color: z.muted)),
      ]),
    );

    return DesktopPage(
      title: tr('Tugas'),
      subtitle: tr('Daftar tugas dan pengingat'),
      action: _addBtn(context, tr('Tugas baru'), () => showAddTodo(context)),
      children: [
        DCols(minChild: 190, children: [
          stat(Icons.radio_button_unchecked_rounded, 'gray', openN, tr('Belum selesai')),
          stat(Icons.check_circle_outline_rounded, 'green', doneN, tr('Selesai')),
          stat(Icons.warning_amber_rounded, 'orange', late, tr('Terlambat')),
          stat(Icons.event_outlined, 'blue', todayN, tr('Hari ini')),
        ]),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, box) {
          if (box.maxWidth < 900) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [filters, const SizedBox(height: 20), listCard, const SizedBox(height: 20), activity]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 7, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [filters, const SizedBox(height: 20), listCard])),
            const SizedBox(width: 20),
            Expanded(flex: 3, child: activity),
          ]);
        }),
      ],
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
      final items = store.agendaOn(d);
      final due = _tasks ? store.todos.where((t) => !t.done && t.due != null && dayOnly(t.due!) == d).length : 0;
      final isToday = d == today, isSel = d == _sel;
      return Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: inMonth ? z.card : z.track.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() {
              _sel = d;
              if (_view == 'month' && d.month != _month.month) _month = DateTime(d.year, d.month);
            }),
            child: Container(
              height: _view == 'week' ? 260 : 82,
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: isSel ? z.primary : z.divider, width: isSel ? 2 : 1)),
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
        FilterChip(label: Text(tr('Tugas')), avatar: const Icon(Icons.task_alt_rounded, size: 17), selected: _tasks, onSelected: (v) => setState(() => _tasks = v)),
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
            if (store.agendaOn(d).isNotEmpty) ...[
              Padding(padding: const EdgeInsets.only(top: 10, bottom: 6), child: Text(_longDate(d), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: z.text2))),
              for (final a in store.agendaOn(d)) AgendaRow(item: a),
            ],
        ]),
      );
    } else {
      main = DCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(children: [
          Row(children: [for (final n in names) Expanded(child: Center(child: Text(n, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: z.text2))))]),
          const SizedBox(height: 6),
          for (var w = 0; w < weeks; w++) Row(children: [for (var i = 0; i < 7; i++) Expanded(child: cell(gridStart.add(Duration(days: w * 7 + i))))]),
        ]),
      );
    }

    final items = store.agendaOn(_sel);
    final overdue = store.todos.where((t) => t.isOverdue()).toList();
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
        if (items.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(tr('Belum ada agenda'), style: TextStyle(color: z.muted))) else for (final a in items) AgendaRow(item: a),
        if (overdue.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(tr('Tugas bertenggat'), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          for (var i = 0; i < overdue.length; i++) TodoRow(todo: overdue[i], showDivider: i < overdue.length - 1),
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
