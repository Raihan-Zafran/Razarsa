import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/productive_models.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart';
import '../../widgets/common.dart';
import '../../widgets/mode_widgets.dart';
import '../settings/profile_page.dart';
import 'notes_page.dart';
import 'prod_common.dart';

class ProdHomePage extends StatelessWidget {
  const ProdHomePage({super.key, required this.goTo});

  final ValueChanged<int> goTo;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final today = store.todayTodos;
    // Fokus hari ini: tugas yang belum selesai (yang terlambat di atas), maksimal 3.
    final remaining = today.where((t) => !t.done).toList()
      ..sort((a, b) => (b.isOverdue() ? 1 : 0) - (a.isOverdue() ? 1 : 0));
    final agenda = store.agendaOn(DateTime.now());
    final next = store.sortedTodos.where((t) => !t.done).take(3).toList();
    final pinned = store.sortedNotes.where((n) => n.pinned).toList();

    return ProdScroll(
      header: Row(children: [
        const Expanded(child: Align(alignment: Alignment.centerLeft, child: ModeSwitch())),
        const ThemeToggle(),
        const SizedBox(width: 8),
        RoundIconButton(
          icon: Icons.person_outline_rounded,
          tooltip: tr('Buka profil'),
          filled: true,
          onTap: () => pushPage(context, const ProfilePage()),
        ),
      ]),
      children: [
        // Fokus hari ini: jumlah tugas tersisa + daftar yang bisa langsung diselesaikan.
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: z.hero,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: z.heroBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text('${remaining.length}',
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  remaining.isNotEmpty
                      ? tr('tugas tersisa hari ini')
                      : (today.isEmpty ? tr('Belum ada tugas') : tr('tugas hari ini selesai')),
                  style: TextStyle(fontSize: 14, color: z.heroMuted),
                ),
              ),
            ]),
            if (remaining.isNotEmpty) ...[
              const SizedBox(height: 4),
              for (final t in remaining.take(3)) _FocusRow(todo: t),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        const _QuickAdd(),
        const SizedBox(height: 22),
        SectionTitle(tr('Jadwal Hari Ini'),
            trailing: TextButton(
              onPressed: () => goTo(2),
              child: Text(tr('Kalender'), style: TextStyle(color: z.accentText, fontWeight: FontWeight.w700)),
            )),
        const SizedBox(height: 6),
        if (agenda.isEmpty)
          ZCard(child: Text(tr('Belum ada agenda hari ini. Tambahkan lewat Kalender.'), style: TextStyle(fontSize: 13, color: z.muted)))
        else
          for (final a in agenda) AgendaRow(item: a),
        const SizedBox(height: 16),
        SectionTitle(tr('Tugas Berikutnya'),
            trailing: TextButton(
              onPressed: () => goTo(1),
              child: Text(tr('Lihat semua'), style: TextStyle(color: z.accentText, fontWeight: FontWeight.w700)),
            )),
        const SizedBox(height: 6),
        ZCard(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: next.isEmpty
              ? EmptyState(
                  image: Assets.dragonWin,
                  title: tr('Semua tugas selesai!'),
                  message: tr('Tambah tugas baru lewat kolom di atas.'),
                )
              : Column(children: [
                  for (var i = 0; i < next.length; i++) TodoRow(todo: next[i], showDivider: i < next.length - 1),
                ]),
        ),
        if (pinned.isNotEmpty) ...[
          const SizedBox(height: 22),
          SectionTitle(tr('Catatan Disematkan')),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: pinned.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => SizedBox(width: 170, child: NoteCard(note: pinned[i], maxLines: 3)),
            ),
          ),
        ],
      ],
    );
  }
}

class _FocusRow extends StatelessWidget {
  const _FocusRow({required this.todo});

  final Todo todo;

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    final late = todo.isOverdue();
    final due = todo.due;
    final time = due != null && !(due.hour == 0 && due.minute == 0) ? timeLabel(due) : '';
    return Row(children: [
      Semantics(
        container: true,
        button: true,
        label: trf('Tandai selesai: {0}', [todo.title]),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => StoreScope.read(context).toggleTodo(todo.id),
          // Area ketuk 44 px; lingkarannya 18 px.
          child: const SizedBox(
            width: 44,
            height: 40,
            child: Center(child: _FocusCircle()),
          ),
        ),
      ),
      Expanded(
        child: Text(todo.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, color: Colors.white)),
      ),
      if (late || time.isNotEmpty) ...[
        const SizedBox(width: 8),
        Text(late ? tr('terlambat') : time,
            style: TextStyle(fontSize: 12, color: late ? const Color(0xFFFDBA74) : z.heroMuted)),
      ],
    ]);
  }
}

class _FocusCircle extends StatelessWidget {
  const _FocusCircle();

  @override
  Widget build(BuildContext context) => Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF86EFAC), width: 2)),
      );
}

class _QuickAdd extends StatefulWidget {
  const _QuickAdd();

  @override
  State<_QuickAdd> createState() => _QuickAddState();
}

class _QuickAddState extends State<_QuickAdd> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _add() {
    final text = _c.text.trim();
    if (text.isEmpty) {
      showAddTodo(context);
      return;
    }
    StoreScope.read(context).addTodo(text, cat: 'Pribadi', tone: 'teal', due: dayOnly(DateTime.now()));
    _c.clear();
    FocusScope.of(context).unfocus();
    showZToast(context, tr('Tugas ditambahkan'));
  }

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return ZCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Tambah Cepat'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _c,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _add(),
              decoration: InputDecoration(
                hintText: tr('Tugas untuk hari ini...'),
                filled: true,
                fillColor: z.bg,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: z.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: z.border)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: tr('Tambah tugas'),
            child: Material(
              color: z.primary,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _add,
                child: SizedBox(width: 48, height: 48, child: Icon(Icons.add_rounded, color: z.onPrimary)),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}
