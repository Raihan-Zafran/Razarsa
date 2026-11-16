import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/productive_models.dart';
import '../../data/store.dart';
import '../../shell/layout.dart';
import '../../widgets/common.dart';
import 'desktop_prod.dart';
import 'prod_common.dart';

/// Kalender HP (prototipe): tampilan Bulan / Minggu / Agenda, saring warna, tampilkan tugas bertenggat,
/// lalu daftar agenda hari terpilih (jam mulai–selesai, lokasi, berulang).
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  String _view = 'month';
  DateTime _sel = dayOnly(DateTime.now());
  late DateTime _month = DateTime(_sel.year, _sel.month);
  String _tone = 'all';
  bool _tasks = true;

  void _shift(int dir) => setState(() {
        if (_view == 'week') {
          _sel = _sel.add(Duration(days: 7 * dir));
          _month = DateTime(_sel.year, _sel.month);
        } else {
          _month = DateTime(_month.year, _month.month + dir);
        }
      });

  List<Agenda> _agendaOn(AppStore store, DateTime d) => store.agendaOn(d).where((a) => _tone == 'all' || a.tone == _tone).toList();

  List<Todo> _tasksOn(AppStore store, DateTime d) =>
      _tasks ? store.todos.where((t) => !t.done && t.due != null && dayOnly(t.due!) == d).toList() : const [];

  @override
  Widget build(BuildContext context) {
    if (isWide(context)) return const DesktopCalendar();
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final today = dayOnly(DateTime.now());
    final items = _agendaOn(store, _sel);
    final dayTasks = _tasksOn(store, _sel);

    // Hari dalam grid.
    final List<DateTime?> cells = [];
    if (_view == 'week') {
      final start = store.weekStart(_sel);
      for (var i = 0; i < 7; i++) {
        cells.add(start.add(Duration(days: i)));
      }
    } else if (_view == 'month') {
      final first = _month;
      final lead = store.weekStartMonday ? first.weekday - 1 : first.weekday % 7;
      for (var i = 0; i < lead; i++) {
        cells.add(null);
      }
      final days = DateTime(first.year, first.month + 1, 0).day;
      for (var d = 1; d <= days; d++) {
        cells.add(DateTime(first.year, first.month, d));
      }
    }
    final weekdayNames = L.en
        ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        : ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final names = store.weekStartMonday ? weekdayNames : [weekdayNames[6], ...weekdayNames.take(6)];
    final title = _view == 'month' ? '${monthLong(_month)} ${_month.year}' : '${monthLong(_sel)} ${_sel.year}';

    Widget addButton() => Semantics(
          button: true,
          label: tr('Tambah agenda'),
          child: Material(
            color: z.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => showAddAgenda(context, _sel),
              child: SizedBox(width: 44, height: 44, child: Icon(Icons.add_rounded, color: z.onPrimary)),
            ),
          ),
        );

    final filters = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ZChip(label: tr('Tugas'), icon: Icons.task_alt_rounded, selected: _tasks, onTap: () => setState(() => _tasks = !_tasks)),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ZChip(label: tr('Semua'), selected: _tone == 'all', onTap: () => setState(() => _tone = 'all')),
        ),
        for (final (k, l) in kAgendaTones)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Semantics(
              button: true,
              selected: _tone == k,
              label: trf('Warna {0}', [tr(l)]),
              child: GestureDetector(
                onTap: () => setState(() => _tone = _tone == k ? 'all' : k),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _tone == k ? z.primary : z.card,
                    border: Border.all(color: _tone == k ? z.primary : z.chipBorder),
                  ),
                  child: Center(child: Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: z.chart(k)))),
                ),
              ),
            ),
          ),
      ]),
    );

    final List<Widget> body;
    if (_view == 'agenda') {
      // Agenda 30 hari ke depan, dikelompokkan per tanggal.
      final groups = <(DateTime, List<Agenda>)>[];
      for (var i = 0; i < 30; i++) {
        final d = today.add(Duration(days: i));
        final evs = _agendaOn(store, d);
        if (evs.isNotEmpty) groups.add((d, evs));
      }
      body = [
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: EmptyState(icon: Icons.event_busy_outlined, title: tr('Belum ada agenda'), message: tr('Tekan + untuk menambah.')),
          )
        else
          for (final (d, evs) in groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
              child: Row(children: [
                Icon(Icons.event_outlined, size: 17, color: z.text2),
                const SizedBox(width: 7),
                Text(dayLabel(d), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: z.text2)),
              ]),
            ),
            for (final a in evs) AgendaRow(item: a),
          ],
      ];
    } else {
      body = [
        ZCard(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
          child: Column(children: [
            Row(children: [
              IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded), tooltip: tr('Sebelumnya')),
              Expanded(child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right_rounded), tooltip: tr('Berikutnya')),
            ]),
            Row(children: [
              for (final n in names)
                Expanded(child: Text(n.toUpperCase(), textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: z.muted2))),
            ]),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.95,
              children: [
                for (final d in cells)
                  d == null
                      ? const SizedBox()
                      : _DayCell(
                          day: d,
                          selected: d == _sel,
                          today: d == today,
                          dots: _agendaOn(store, d).take(3).map((a) => a.tone).toList(),
                          task: _tasksOn(store, d).isNotEmpty,
                          onTap: () => setState(() => _sel = d),
                        ),
              ],
            ),
            Center(
              child: TextButton(
                onPressed: () => setState(() {
                  _sel = today;
                  _month = DateTime(today.year, today.month);
                }),
                child: Text(tr('Ke hari ini'), style: const TextStyle(fontSize: 12.5)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dayLabel(_sel), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(trf('{0} agenda · {1} tugas bertenggat', [items.length, dayTasks.length]), style: TextStyle(fontSize: 12.5, color: z.muted2)),
            ]),
          ),
          addButton(),
        ]),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
            child: Text(tr('Belum ada agenda di hari ini. Tekan + untuk menambah.'), style: TextStyle(fontSize: 13, color: z.muted2)),
          )
        else
          for (final a in items) AgendaRow(item: a),
        if (dayTasks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
            child: Row(children: [
              Icon(Icons.task_alt_rounded, size: 17, color: z.text2),
              const SizedBox(width: 7),
              Text(tr('Tugas bertenggat'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: z.text2)),
            ]),
          ),
          ZCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Column(children: [
              for (var i = 0; i < dayTasks.length; i++) TodoRow(todo: dayTasks[i], showDivider: i < dayTasks.length - 1),
            ]),
          ),
        ],
      ];
    }

    return ProdScroll(
      header: ProdTitle(tr('Kalender'), onAdd: () => showAddAgenda(context, _sel), addLabel: tr('Tambah agenda')),
      children: [
        Segmented<String>(
          items: [('month', tr('Bulan')), ('week', tr('Minggu')), ('agenda', tr('Agenda'))],
          value: _view,
          onChanged: (v) => setState(() => _view = v),
        ),
        const SizedBox(height: 10),
        filters,
        const SizedBox(height: 8),
        ...body,
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.selected, required this.today, required this.dots, required this.onTap, this.task = false});

  final DateTime day;
  final bool selected;
  final bool today;
  final List<String> dots;
  final VoidCallback onTap;

  /// Ada tugas bertenggat di hari ini (garis kecil di bawah titik agenda).
  final bool task;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: shortDate(day),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: selected ? z.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: today && !selected ? Border.all(color: z.primary, width: 2) : null,
          ),
          child: FittedBox(fit: BoxFit.scaleDown, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${day.day}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? z.onPrimary : (today ? z.accentText : z.text),
                )),
            const SizedBox(height: 3),
            SizedBox(
              height: 5,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final t in dots)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? z.onPrimary : z.chart(t)),
                  ),
              ]),
            ),
            const SizedBox(height: 2),
            Container(
              width: 12,
              height: 2.5,
              decoration: BoxDecoration(color: task ? (selected ? z.onPrimary : z.text2) : Colors.transparent, borderRadius: BorderRadius.circular(2)),
            ),
          ])),
        ),
      ),
    );
  }
}
