import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/productive_models.dart';
import '../../data/store.dart';
import '../../shell/app_shell.dart';
import '../../widgets/common.dart';
import '../security/lock.dart';
import '../../shell/desktop_page.dart';
import '../../shell/layout.dart';
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
    if (n.unreadable) {
      showZToast(context, tr('Catatan ini tidak bisa dibuka karena kunci enkripsi di HP ini hilang. Kamu masih bisa menghapusnya.'));
      return false;
    }
    if (isOpen(n)) return true;
    final store = StoreScope.read(context);
    if (!store.pinEnabled) {
      // Mis. catatan terkunci hasil restore di HP baru: belum ada PIN untuk membukanya.
      // Buat PIN dulu (kunci catatan tetap), lalu catatan langsung terbuka.
      final created = await Navigator.of(context).push<String>(slideInRoute(const PinSetupPage()));
      if (created == null || !context.mounted) return false;
      store.setPin(created);
      open.value = {...open.value, n.id};
      showZToast(context, tr('PIN aktif'));
      return true;
    }
    final ok = await Navigator.of(context).push<bool>(slideInRoute(const PinVerifyPage()));
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

  /// Catatan yang terbuka di panel editor (Windows).
  String? _sel;

  @override
  void dispose() {
    // Ditunda sampai pohon widget selesai dibongkar supaya tidak memicu build di tengah proses.
    Future.microtask(NoteLock.closeAll);
    super.dispose();
  }

  Future<void> _new() async {
    final store = StoreScope.read(context);
    final n = store.addNote(tone: kNoteTones[store.notes.length % kNoteTones.length], folder: _folder);
    if (isWide(context)) {
      setState(() => _sel = n.id);
      return;
    }
    await pushPage(context, NoteEditorPage(note: n));
  }

  Future<void> _addFolder() async {
    final store = StoreScope.read(context);
    final ctrl = TextEditingController();
    final name = await showZDialog<String>(
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
    final done = await confirmDelete(
      context,
      name,
      () => store.removeNoteFolder(name),
      title: tr('Hapus folder?'),
      message: trf('Folder "{0}" dihapus. Catatan di dalamnya tidak dihapus.', [name]),
    );
    if (done && mounted && _folder == name) setState(() => _folder = '');
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
        final Widget search = TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: tr('Cari catatan'),
                prefixIcon: Icon(Icons.search_rounded, color: z.muted),
                filled: true,
                fillColor: z.card,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: z.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: z.border)),
              ),
            );
        final Widget chips = SingleChildScrollView(
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
            );
        final wide = isWide(context);
        Widget grid(int cols) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var c = 0; c < cols; c++) ...[
                if (c > 0) const SizedBox(width: 12),
                Expanded(
                  child: Column(children: [
                    for (var i = c; i < list.length; i += cols)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: NoteCard(
                          note: list[i],
                          maxLines: 8,
                          selected: wide && list[i].id == _sel,
                          onOpen: wide ? (n) => setState(() => _sel = n.id) : null,
                        ),
                      ),
                  ]),
                ),
              ],
            ]);
        final Widget empty = EmptyState(
          icon: Icons.sticky_note_2_outlined,
          title: store.notes.isEmpty ? tr('Belum ada catatan') : tr('Catatan tidak ditemukan'),
          message: store.notes.isEmpty ? tr('Tekan + untuk menulis catatan pertamamu.') : tr('Coba kata kunci lain.'),
        );
        if (isWide(context)) {
          return DesktopPage(
            title: tr('Catatan'),
            subtitle: tr('Catatan cepat, tersimpan otomatis'),
            action: FilledButton.icon(
              onPressed: _new,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(tr('Catatan baru'), style: const TextStyle(fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 20)),
            ),
            children: [
              Row(children: [
                Expanded(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: search)),
              ]),
              const SizedBox(height: 14),
              chips,
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, box) {
                Note? sel;
                for (final n in store.notes) {
                  if (n.id == _sel) sel = n;
                }
                // Catatan terkunci yang kuncinya ditutup lagi tidak boleh tetap terbuka di panel.
                if (sel != null && !NoteLock.isOpen(sel)) sel = null;
                final panel = DCard(
                  padding: const EdgeInsets.all(20),
                  child: sel == null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 34),
                          child: Column(children: [
                            Icon(Icons.sticky_note_2_outlined, size: 40, color: z.text2),
                            const SizedBox(height: 10),
                            Text(tr('Pilih atau buat catatan'), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(tr('Perubahan tersimpan otomatis.'), style: TextStyle(fontSize: 12.5, color: z.muted)),
                          ]),
                        )
                      : NoteEditorPanel(key: ValueKey(sel.id), note: sel, onClose: () => setState(() => _sel = null)),
                );
                final gridArea = list.isEmpty ? empty : LayoutBuilder(builder: (context, b) => grid((b.maxWidth / 240).floor().clamp(1, 5)));
                if (box.maxWidth < 900) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [panel, const SizedBox(height: 16), gridArea]);
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: gridArea),
                  const SizedBox(width: 20),
                  SizedBox(width: 380, child: panel),
                ]);
              }),
            ],
          );
        }
        return ProdScroll(
          header: ProdTitle(tr('Catatan'), onAdd: _new, addLabel: tr('Catatan baru')),
          children: [
            search,
            const SizedBox(height: 12),
            chips,
            const SizedBox(height: 12),
            if (list.isEmpty) empty else grid(2),
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
    sheetAnimationStyle: kSheetAnimation,
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
                  if (!store.updateNote(note, locked: v)) {
                    showZToast(ctx, tr('Penyimpanan aman tidak tersedia di HP ini, catatan tidak bisa dikunci'));
                    return;
                  }
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
  const NoteCard({super.key, required this.note, this.maxLines = 6, this.onOpen, this.selected = false});

  final Note note;
  final int maxLines;

  /// Kosong = buka halaman editor. Windows: pilih catatan untuk panel editor di kanan.
  final ValueChanged<Note>? onOpen;
  final bool selected;

  Future<void> _open(BuildContext context) async {
    if (!await NoteLock.ensure(context, note)) return;
    if (!context.mounted) return;
    if (onOpen != null) {
      onOpen!(note);
      return;
    }
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: selected ? BorderSide(color: z.toneFg(note.tone), width: 2) : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
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
                if (!store.updateNote(n, locked: !n.locked)) {
                  showZToast(context, tr('Penyimpanan aman tidak tersedia di HP ini, catatan tidak bisa dikunci'));
                }
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
            decoration: BoxDecoration(color: z.toneBg(n.tone), borderRadius: BorderRadius.circular(13)),
            child: Column(children: [
              TextField(
                controller: _title,
                onChanged: (v) => store.updateNote(n, title: v),
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: z.text),
                decoration: InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, hintText: tr('Judul'), isDense: true),
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
                decoration: InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, hintText: tr('Tulis sesuatu...'), isDense: true),
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


/// Editor catatan di panel kanan (Windows, prototipe): judul, isi, warna, sematkan, kunci, hapus.
/// Tersimpan otomatis; catatan baru yang dibiarkan kosong dihapus saat panel ditutup / berganti.
class NoteEditorPanel extends StatefulWidget {
  const NoteEditorPanel({super.key, required this.note, required this.onClose});

  final Note note;
  final VoidCallback onClose;

  @override
  State<NoteEditorPanel> createState() => _NoteEditorPanelState();
}

class _NoteEditorPanelState extends State<NoteEditorPanel> {
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(tr('Edit catatan'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: z.muted))),
        IconButton(
          tooltip: n.pinned ? tr('Lepas sematan') : tr('Sematkan'),
          onPressed: () => store.updateNote(n, pinned: !n.pinned),
          icon: Icon(n.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, size: 20, color: n.pinned ? z.accentText : z.text2),
        ),
        IconButton(
          tooltip: n.locked ? tr('Buka kunci') : tr('Kunci dengan PIN'),
          onPressed: () {
            if (!store.pinEnabled) {
              showZToast(context, tr('Aktifkan Kunci PIN di Pengaturan dulu'));
              return;
            }
            if (!store.updateNote(n, locked: !n.locked)) {
              showZToast(context, tr('Penyimpanan aman tidak tersedia di HP ini, catatan tidak bisa dikunci'));
            }
          },
          icon: Icon(n.locked ? Icons.lock_rounded : Icons.lock_open_rounded, size: 20, color: n.locked ? z.accentText : z.text2),
        ),
        IconButton(
          tooltip: tr('Hapus'),
          onPressed: () => confirmDelete(context, n.title.isEmpty ? tr('Catatan ini') : n.title, () {
            _deleted = true;
            store.removeNote(n.id);
            widget.onClose();
          }),
          icon: Icon(Icons.delete_outline_rounded, size: 20, color: z.warn),
        ),
        IconButton(tooltip: tr('Tutup'), onPressed: widget.onClose, icon: Icon(Icons.close_rounded, size: 20, color: z.text2)),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        for (final t in kNoteTones)
          Semantics(
            button: true,
            selected: n.tone == t,
            label: trf('Warna {0}', [t]),
            child: GestureDetector(
              onTap: () => store.updateNote(n, tone: t),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: z.toneBg(t),
                  shape: BoxShape.circle,
                  border: Border.all(color: n.tone == t ? z.toneFg(t) : z.border, width: n.tone == t ? 3 : 1.5),
                ),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: z.toneBg(n.tone), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          TextField(
            controller: _title,
            autofocus: n.title.isEmpty && n.body.isEmpty,
            onChanged: (v) => store.updateNote(n, title: v),
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: z.text),
            decoration: InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, hintText: tr('Judul'), isDense: true),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _body,
            onChanged: (v) => store.updateNote(n, body: v),
            textCapitalization: TextCapitalization.sentences,
            minLines: 12,
            maxLines: null,
            style: TextStyle(fontSize: 14, height: 1.55, color: z.text2),
            decoration: InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, hintText: tr('Tulis sesuatu...'), isDense: true),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Text(trf('Tersimpan otomatis · {0}', [dayLabel(n.updatedAt)]), textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: z.muted2)),
    ]);
  }
}
