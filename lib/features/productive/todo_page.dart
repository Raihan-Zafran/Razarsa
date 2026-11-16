import 'package:flutter/material.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../shell/layout.dart';
import '../../widgets/common.dart';
import 'desktop_prod.dart';
import 'prod_common.dart';
import 'todo_detail.dart';

/// Halaman Tugas (HP), seperti prototipe: ringkasan, cari, saring status, urut / kategori / prioritas,
/// lalu tugas dikelompokkan per tenggat. Ketuk tugas untuk detail (sub-tugas, catatan, pengingat, ulangi).
class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final _query = TaskQuery();

  Future<void> _pick(String title, List<(String, String)> options, String current, void Function(String) on) async {
    final v = await showPickSheet(context, title, options, current);
    if (v != null && mounted) setState(() => on(v));
  }

  @override
  Widget build(BuildContext context) {
    if (isWide(context)) return const DesktopTodos();
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final counts = _query.counts(store);
    final list = _query.apply(store);
    final groups = _query.groups(store, list);

    Widget stat(int n, String label) => Expanded(
          child: ZCard(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$n', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.1)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(label, maxLines: 1, style: TextStyle(fontSize: 12, color: z.muted2)),
              ),
            ]),
          ),
        );

    Widget mini(IconData icon, String label, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Material(
            color: z.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: z.chipBorder)),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 17, color: z.text2),
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: z.text2)),
                  Icon(Icons.expand_more_rounded, size: 18, color: z.muted2),
                ]),
              ),
            ),
          ),
        );

    String labelOf(List<(String, String)> opts, String k) => opts.firstWhere((o) => o.$1 == k, orElse: () => opts.first).$2;

    return ProdScroll(
      header: ProdTitle(tr('Tugas'), onAdd: () => showAddTodo(context), addLabel: tr('Tugas baru')),
      children: [
        Row(children: [
          stat(counts['open']!, tr('Belum selesai')),
          const SizedBox(width: 10),
          stat(counts['late']!, tr('Terlambat')),
          const SizedBox(width: 10),
          stat(counts['today']!, tr('Hari ini')),
        ]),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _query.q = v),
          decoration: InputDecoration(
            hintText: tr('Cari tugas atau catatannya'),
            prefixIcon: Icon(Icons.search_rounded, color: z.muted2),
            filled: true,
            fillColor: z.card,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final (k, l) in [
              ('all', tr('Semua')),
              ('open', tr('Belum selesai')),
              ('today', tr('Hari ini')),
              ('late', tr('Terlambat')),
              ('done', tr('Selesai')),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ZChip(label: '$l  ${counts[k]}', selected: _query.status == k, onTap: () => setState(() => _query.status = k)),
              ),
          ]),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            mini(Icons.sort_rounded, labelOf(TaskQuery.sorts, _query.sort), () => _pick(tr('Urutkan tugas'), TaskQuery.sorts, _query.sort, (v) => _query.sort = v)),
            mini(Icons.sell_outlined, labelOf(TaskQuery.cats, _query.cat), () => _pick(tr('Kategori'), TaskQuery.cats, _query.cat, (v) => _query.cat = v)),
            mini(Icons.flag_outlined, labelOf(TaskQuery.pris, _query.pri), () => _pick(tr('Prioritas'), TaskQuery.pris, _query.pri, (v) => _query.pri = v)),
          ]),
        ),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: EmptyState(
              icon: Icons.task_alt_rounded,
              title: store.todos.isEmpty ? tr('Belum ada tugas') : tr('Tidak ada tugas yang cocok'),
              message: store.todos.isEmpty ? tr('Tekan + untuk menambah tugas.') : tr('Ubah filter atau tekan +.'),
            ),
          )
        else
          for (final (_, title, icon, rows) in groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Row(children: [
                Icon(icon, size: 17, color: z.text2),
                const SizedBox(width: 7),
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: z.text2)),
                const SizedBox(width: 6),
                Text('${rows.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: z.muted2)),
              ]),
            ),
            ZCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Column(children: [
                for (var i = 0; i < rows.length; i++) TodoRow(todo: rows[i], showDivider: i < rows.length - 1),
              ]),
            ),
          ],
        if (list.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(tr('Ketuk tugas untuk detail. Tekan lama untuk menghapus.'), textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: z.muted2)),
        ],
      ],
    );
  }
}
