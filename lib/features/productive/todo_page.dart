import 'package:flutter/material.dart';

import '../../core/i18n.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';
import 'prod_common.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final all = store.sortedTodos;
    final list = all.where((t) => _filter == 'all' || (_filter == 'done' ? t.done : !t.done)).toList();
    final allDone = all.isNotEmpty && all.every((t) => t.done);

    Widget empty() {
      if (_filter == 'open' && allDone) {
        return EmptyState(image: Assets.dragonWin, title: tr('Semua tugas selesai!'), message: tr('Kerja bagus. Waktunya istirahat.'));
      }
      return EmptyState(
        image: Assets.dragonCurious,
        title: tr('Belum ada tugas di sini'),
        message: tr('Tekan + untuk menambah tugas.'),
      );
    }

    return ProdScroll(
      header: ProdTitle(tr('To-do'), onAdd: () => showAddTodo(context), addLabel: tr('Tugas baru')),
      children: [
        Wrap(spacing: 8, children: [
          for (final (k, l) in [('all', tr('Semua')), ('open', tr('Belum')), ('done', tr('Selesai'))])
            ZChip(label: l, selected: _filter == k, onTap: () => setState(() => _filter = k)),
        ]),
        const SizedBox(height: 12),
        if (list.isEmpty)
          empty()
        else
          ZCard(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: Column(children: [
              for (var i = 0; i < list.length; i++) TodoRow(todo: list[i], showDivider: i < list.length - 1),
            ]),
          ),
        const SizedBox(height: 12),
        if (list.isNotEmpty)
          Text(tr('Tekan lama tugas untuk menghapus.'), textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
      ],
    );
  }
}
