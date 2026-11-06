import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/productive_models.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart';
import '../../widgets/common.dart';
import 'prod_common.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  String _q = '';
  bool _pinnedOnly = false;

  Future<void> _new() async {
    final store = StoreScope.read(context);
    final n = store.addNote(tone: kNoteTones[store.notes.length % kNoteTones.length]);
    await pushPage(context, NoteEditorPage(note: n));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final q = _q.toLowerCase();
    final list = store.sortedNotes
        .where((n) => !_pinnedOnly || n.pinned)
        .where((n) => q.isEmpty || n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q))
        .toList();
    final left = [for (var i = 0; i < list.length; i += 2) list[i]];
    final right = [for (var i = 1; i < list.length; i += 2) list[i]];

    return ProdScroll(
      header: ProdTitle(tr('Catatan'), onAdd: _new, addLabel: tr('Catatan baru')),
      children: [
        TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(
            hintText: tr('Cari catatan'),
            prefixIcon: Icon(Icons.search_rounded, color: z.muted),
            filled: true,
            fillColor: z.card,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: z.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: z.border)),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          ZChip(label: tr('Semua'), selected: !_pinnedOnly, onTap: () => setState(() => _pinnedOnly = false)),
          ZChip(label: tr('Disematkan'), selected: _pinnedOnly, onTap: () => setState(() => _pinnedOnly = true)),
        ]),
        const SizedBox(height: 12),
        if (list.isEmpty)
          EmptyState(
            image: Assets.dragonCurious,
            title: store.notes.isEmpty ? tr('Belum ada catatan') : tr('Catatan tidak ditemukan'),
            message: store.notes.isEmpty ? tr('Tekan + untuk menulis catatan pertamamu.') : tr('Coba kata kunci lain.'),
          )
        else
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(children: [for (final n in left) Padding(padding: const EdgeInsets.only(bottom: 10), child: NoteCard(note: n))])),
            const SizedBox(width: 10),
            Expanded(child: Column(children: [for (final n in right) Padding(padding: const EdgeInsets.only(bottom: 10), child: NoteCard(note: n))])),
          ]),
      ],
    );
  }
}

/// Kartu catatan berwarna.
class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note, this.maxLines = 6});

  final Note note;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final z = ZColors.of(context);
    return Material(
      color: z.toneBg(note.tone),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => pushPage(context, NoteEditorPage(note: note)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(note.title.isEmpty ? tr('Tanpa judul') : note.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: z.text)),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: note.pinned ? tr('Lepas sematan') : tr('Sematkan'),
                onPressed: () => store.updateNote(note, pinned: !note.pinned),
                icon: Icon(note.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, size: 18, color: note.pinned ? z.accentText : z.muted),
              ),
            ]),
            if (note.body.isNotEmpty) ...[
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(note.body, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, height: 1.45, color: z.text2)),
              ),
            ],
            const SizedBox(height: 6),
            Text(dayLabel(note.updatedAt), style: TextStyle(fontSize: 11, color: z.muted)),
          ]),
        ),
      ),
    );
  }
}

/// Halaman menulis / mengubah catatan. Tersimpan otomatis.
class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, required this.note});

  final Note note;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final _title = TextEditingController(text: widget.note.title);
  late final _body = TextEditingController(text: widget.note.body);
  late AppStore _store;
  bool _deleted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store = StoreScope.read(context);
  }

  @override
  void dispose() {
    // Catatan kosong tidak perlu disimpan.
    final n = widget.note;
    if (!_deleted && n.title.trim().isEmpty && n.body.trim().isEmpty) {
      final store = _store;
      Future.microtask(() => store.removeNote(n.id));
    }
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final n = widget.note;
    final pad = MediaQuery.of(context).padding;
    return Scaffold(
      backgroundColor: z.bg,
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, pad.top + 12, 20, pad.bottom + 28),
        children: [
          PageTitle(tr('Catatan'), onBack: () => Navigator.of(context).pop(), actions: [
            IconButton(
              tooltip: n.pinned ? tr('Lepas sematan') : tr('Sematkan'),
              onPressed: () => store.updateNote(n, pinned: !n.pinned),
              icon: Icon(n.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, color: n.pinned ? z.accentText : z.text),
            ),
            IconButton(
              tooltip: tr('Hapus'),
              onPressed: () => confirmDelete(context, n.title.isEmpty ? tr('Catatan ini') : n.title, () {
                _deleted = true;
                store.removeNote(n.id);
                Navigator.of(context).pop();
              }),
              icon: Icon(Icons.delete_outline_rounded, color: z.warn),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 10, children: [
            for (final t in kNoteTones)
              Semantics(
                button: true,
                selected: n.tone == t,
                label: trf('Warna {0}', [t]),
                child: GestureDetector(
                  onTap: () => store.updateNote(n, tone: t),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: z.toneBg(t),
                      shape: BoxShape.circle,
                      border: Border.all(color: n.tone == t ? z.toneFg(t) : z.border, width: n.tone == t ? 3 : 1.5),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: z.toneBg(n.tone), borderRadius: BorderRadius.circular(22)),
            child: Column(children: [
              TextField(
                controller: _title,
                onChanged: (v) => store.updateNote(n, title: v),
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: z.text),
                decoration: InputDecoration(border: InputBorder.none, hintText: tr('Judul'), isDense: true),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _body,
                autofocus: n.title.isEmpty && n.body.isEmpty,
                onChanged: (v) => store.updateNote(n, body: v),
                textCapitalization: TextCapitalization.sentences,
                minLines: 10,
                maxLines: null,
                style: TextStyle(fontSize: 14.5, height: 1.5, color: z.text2),
                decoration: InputDecoration(border: InputBorder.none, hintText: tr('Tulis sesuatu...'), isDense: true),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Text(tr('Tersimpan otomatis'), textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: z.muted2)),
        ],
      ),
    );
  }
}
