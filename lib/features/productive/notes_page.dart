import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/productive_models.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart';
import '../../widgets/common.dart';
import '../security/lock.dart';
import 'prod_common.dart';

/// Catatan terkunci yang sudah dibuka dengan PIN. Terkunci lagi saat keluar dari tab Catatan.
class NoteLock {
  static final ValueNotifier<Set<String>> open = ValueNotifier<Set<String>>(<String>{});

  static bool isOpen(Note n) => !n.locked || open.value.contains(n.id);

  static void close(String id) => open.value = {...open.value}..remove(id);

  static void closeAll() {
    if (open.value.isNotEmpty) open.value = <String>{};
  }

  /// Minta PIN kalau catatan terkunci. true = boleh dibuka.
  static Future<bool> ensure(BuildContext context, Note n) async {
    if (isOpen(n)) return true;
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const PinVerifyPage()));
    if (ok == true) open.value = {...open.value, n.id};
    return ok == true;
  }
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  String _q = '';
  bool _pinnedOnly = false;
  String _folder = '';

  @override
  void dispose() {
    // Ditunda sampai pohon widget selesai dibongkar supaya tidak memicu build di tengah proses.
    Future.microtask(NoteLock.closeAll);
    super.dispose();
  }

  Future<void> _new() async {
    final store = StoreScope.read(context);
    final n = store.addNote(tone: kNoteTones[store.notes.length % kNoteTones.length], folder: _folder);
    await pushPage(context, NoteEditorPage(note: n));
  }

  Future<void> _addFolder() async {
    final store = StoreScope.read(context);
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Folder baru')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 20,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: tr('Nama folder'), hintText: tr('Misal Kerja, Resep')),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Batal'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: Text(tr('Buat folder'))),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || !mounted) return;
    if (name.trim().isEmpty) {
      showZToast(context, tr('Isi nama folder dulu'));
      return;
    }
    if (!store.addNoteFolder(name)) {
      showZToast(context, tr('Folder sudah ada'));
      return;
    }
    setState(() {
      _folder = name.trim();
      _pinnedOnly = false;
    });
    showZToast(context, tr('Folder dibuat'));
  }

  Future<void> _deleteFolder(String name) async {
    final store = StoreScope.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Hapus folder?')),
        content: Text(trf('Folder "{0}" dihapus. Catatan di dalamnya tidak dihapus.', [name])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Batal'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Hapus'))),
        ],
      ),
    );
    if (ok != true) return;
    store.removeNoteFolder(name);
    if (mounted && _folder == name) setState(() => _folder = '');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = ZColors.of(context);
    final q = _q.toLowerCase();
    return ValueListenableBuilder<Set<String>>(
      valueListenable: NoteLock.open,
      builder: (context, _, _) {
        final list = store.sortedNotes
            .where((n) => !_pinnedOnly || n.pinned)
            .where((n) => _folder.isEmpty || n.folder == _folder)
            // Isi catatan terkunci tidak ikut dicari selama masih terkunci.
            .where((n) => q.isEmpty || n.title.toLowerCase().contains(q) || (NoteLock.isOpen(n) && n.body.toLowerCase().contains(q)))
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                ZChip(label: tr('Semua'), selected: !_pinnedOnly && _folder.isEmpty, onTap: () => setState(() {
                  _pinnedOnly = false;
                  _folder = '';
                })),
                const SizedBox(width: 8),
                ZChip(label: tr('Disematkan'), selected: _pinnedOnly, onTap: () => setState(() {
                  _pinnedOnly = true;
                  _folder = '';
                })),
                for (final f in store.noteFolders) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onLongPress: () => _deleteFolder(f),
                    child: ZChip(
                      label: '$f · ${store.notes.where((n) => n.folder == f).length}',
                      selected: _folder == f,
                      onTap: () => setState(() {
                        _pinnedOnly = false;
                        _folder = f;
                      }),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: tr('Folder baru'),
                  child: GestureDetector(
                    onTap: _addFolder,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: z.chipBorder)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add_rounded, size: 16, color: z.text2),
                        const SizedBox(width: 4),
                        Text(tr('Folder'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: z.text2)),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
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
      },
    );
  }
}

/// Opsi satu catatan: pindah folder, kunci PIN, hapus. Catatan terkunci perlu PIN dulu.
Future<void> showNoteOptions(BuildContext context, Note note) async {
  final store = StoreScope.read(context);
  if (!await NoteLock.ensure(context, note)) return;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: ListenableBuilder(
          listenable: store,
          builder: (ctx, _) {
            final z = ZColors.of(ctx);
            return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Opsi catatan'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(note.title.isEmpty ? tr('Tanpa judul') : note.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: z.muted2)),
              const SizedBox(height: 16),
              Text(tr('Pindahkan ke folder'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: z.muted)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ZChip(label: tr('Tanpa folder'), selected: note.folder.isEmpty, onTap: () => store.updateNote(note, folder: '')),
                for (final f in store.noteFolders) ZChip(label: f, selected: note.folder == f, onTap: () => store.updateNote(note, folder: f)),
              ]),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: note.locked,
                title: Text(tr('Kunci dengan PIN'), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(store.pinEnabled ? tr('Isi catatan disembunyikan sampai PIN dimasukkan') : tr('Aktifkan Kunci PIN di Pengaturan dulu')),
                onChanged: (v) {
                  if (!store.pinEnabled) {
                    showZToast(ctx, tr('Aktifkan Kunci PIN di Pengaturan dulu'));
                    return;
                  }
                  store.updateNote(note, locked: v);
                  if (v) NoteLock.close(note.id);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline_rounded, color: z.warn),
                title: Text(tr('Hapus'), style: TextStyle(fontWeight: FontWeight.w800, color: z.warn)),
                onTap: () {
                  Navigator.pop(ctx);
                  confirmDelete(context, note.title.isEmpty ? tr('Catatan ini') : note.title, () => store.removeNote(note.id));
                },
              ),
            ]);
          },
        ),
      ),
    ),
  );
}

/// Kartu catatan berwarna.
class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note, this.maxLines = 6});

  final Note note;
  final int maxLines;

  Future<void> _open(BuildContext context) async {
    if (!await NoteLock.ensure(context, note)) return;
    if (!context.mounted) return;
    await pushPage(context, NoteEditorPage(note: note));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final z = ZColors.of(context);
    return ValueListenableBuilder<Set<String>>(
      valueListenable: NoteLock.open,
      builder: (context, _, _) {
        final hidden = !NoteLock.isOpen(note);
        return Material(
          color: z.toneBg(note.tone),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _open(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 2, 12),
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
                    tooltip: tr('Opsi catatan'),
                    onPressed: () => showNoteOptions(context, note),
                    icon: Icon(Icons.more_horiz_rounded, size: 18, color: z.muted),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: note.pinned ? tr('Lepas sematan') : tr('Sematkan'),
                    onPressed: () => store.updateNote(note, pinned: !note.pinned),
                    icon: Icon(note.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, size: 18, color: note.pinned ? z.accentText : z.muted),
                  ),
                ]),
                if (hidden) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Row(children: [
                      Icon(Icons.lock_rounded, size: 15, color: z.text2),
                      const SizedBox(width: 6),
                      Expanded(child: Text(tr('Terkunci · ketuk untuk buka'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: z.text2))),
                    ]),
                  ),
                ] else if (note.body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(note.body, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, height: 1.45, color: z.text2)),
                  ),
                ],
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    note.folder.isEmpty ? dayLabel(note.updatedAt) : '${dayLabel(note.updatedAt)} · ${note.folder}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: z.muted),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
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
              tooltip: n.locked ? tr('Buka kunci') : tr('Kunci dengan PIN'),
              onPressed: () {
                if (!store.pinEnabled) {
                  showZToast(context, tr('Aktifkan Kunci PIN di Pengaturan dulu'));
                  return;
                }
                store.updateNote(n, locked: !n.locked);
              },
              icon: Icon(n.locked ? Icons.lock_rounded : Icons.lock_open_rounded, color: n.locked ? z.accentText : z.text),
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
