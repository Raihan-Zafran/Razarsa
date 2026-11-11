import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';
import 'prod_common.dart';

/// Kalender + pengingat dalam satu halaman.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  String _view = 'month';
  DateTime _sel = dayOnly(DateTime.now());
  late DateTime _month = DateTime(_sel.year, _sel.month);

  void _shift(int dir) => setState(() {
        if (_view == 'week') {
          _sel = _sel.add(Duration(days: 7 * dir));
          _month = DateTime(_sel.year, _sel.month);
        } else if (_view == 'day') {
          _sel = _sel.add(Duration(days: dir));
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
    final items = store.agendaOn(_sel);

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

    return ProdScroll(
      header: ProdTitle(tr('Kalender')),
      children: [
        Segmented<String>(
          items: [('month', tr('Bulan')), ('week', tr('Minggu')), ('day', tr('Hari'))],
          value: _view,
          onChanged: (v) => setState(() => _view = v),
        ),
        const SizedBox(height: 12),
        ZCard(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
          radius: 24,
          child: Column(children: [
            Row(children: [
              IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded), tooltip: tr('Sebelumnya')),
              Expanded(child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
              IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right_rounded), tooltip: tr('Berikutnya')),
            ]),
            if (_view != 'day') ...[
              Row(children: [
                for (final n in names)
                  Expanded(child: Text(n, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: z.muted2))),
              ]),
              const SizedBox(height: 4),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.95,
                children: [
                  for (final d in cells)
                    d == null ? const SizedBox() : _DayCell(day: d, selected: d == _sel, today: d == today, dots: store.agendaOn(d).take(3).map((a) => a.tone).toList(),
                        onTap: () => setState(() => _sel = d)),
                ],
              ),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dayLabel(_sel), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(trf('{0} agenda dan pengingat', [items.length]), style: TextStyle(fontSize: 12, color: z.muted2)),
            ]),
          ),
          Semantics(
            button: true,
            label: tr('Tambah acara atau pengingat'),
            child: Material(
              color: z.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => showAddAgenda(context, _sel),
                child: SizedBox(width: 44, height: 44, child: Icon(Icons.add_rounded, color: z.onPrimary)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (items.isEmpty)
          EmptyState(image: Assets.dragonCurious, title: tr('Tidak ada agenda'), message: tr('Santai dulu, atau tekan + untuk menambah.'))
        else ...[
          for (final a in items) AgendaRow(item: a),
          const SizedBox(height: 4),
          Text(tr('Tekan lama agenda untuk menghapus.'), textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: z.muted2)),
        ],
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.selected, required this.today, required this.dots, required this.onTap});

  final DateTime day;
  final bool selected;
  final bool today;
  final List<String> dots;
  final VoidCallback onTap;

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
            borderRadius: BorderRadius.circular(14),
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
                    decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? z.onPrimary : z.toneFg(t)),
                  ),
              ]),
            ),
          ])),
        ),
      ),
    );
  }
}
