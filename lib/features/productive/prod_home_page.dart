import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
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
    final done = today.where((t) => t.done).length;
    final pct = today.isEmpty ? 0.0 : done / today.length;
    final agenda = store.agendaOn(DateTime.now());
    final next = store.sortedTodos.where((t) => !t.done).take(3).toList();
    final pinned = store.sortedNotes.where((n) => n.pinned).toList();

    return ProdScroll(
      header: Row(children: [
        // Tombol mode mengecil (bukan overflow) di layar sempit / font besar.
        const Expanded(child: Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, child: ModeButton()))),
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
        // Fokus hari ini
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: z.hero,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: z.heroBorder),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Fokus Hari Ini'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: z.heroMuted)),
                const SizedBox(height: 6),
                Text(
                  today.isEmpty ? tr('Belum ada tugas') : trf('{0} dari {1} selesai', [done, today.length]),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: z.heroInner,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF86EFAC)),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 66,
              height: 66,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: pct),
                    duration: const Duration(milliseconds: 500),
                    builder: (_, v, _) => CircularProgressIndicator(
                      value: v,
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      backgroundColor: z.heroInner,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF86EFAC)),
                    ),
                  ),
                ),
                Text('${(pct * 100).round()}%',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              ]),
            ),
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
