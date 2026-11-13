import 'dart:math' as math;

import '../../data/models.dart';

/// Batas tampilan graph Saldo per sumber.
const kGraphMaxTxns = 200;
const kGraphMaxCats = 50;
const kGraphMaxWallets = 10;
const kGraphMaxHistory = 90;

/// Ukuran kanvas logis graph; tampilan diskalakan ke lebar layar.
const kGraphW = 390.0;
const kGraphH = 480.0;
const kGraphZoom = 1.2;

enum GKind { wallet, category, txn }

/// Satu titik graph: sumber (besar), kategori (sedang), atau transaksi (kecil).
class GNode {
  GNode(this.id, this.kind);

  final String id;
  final GKind kind;
  double x = 0, y = 0, vx = 0, vy = 0, fx = 0, fy = 0;
  double ax = 0, ay = 0; // titik tarik sumber (dikelompokkan per jenis)
  bool pin = false;
  double born = 0;
  int cnt = 0;
  int li = 0;
  String label = '';
  String cat = '';
  String walletId = '';
  Wallet? wallet;
  Txn? txn;
  String firstWallet = '';
  double big = -1;
}

class GLink {
  GLink(this.a, this.b, {this.walletToCat = false});
  final GNode a, b;
  final bool walletToCat;
}

/// Hasil pengolahan data: apa yang digambar, belum ada posisi.
class GraphData {
  GraphData({
    required this.wallets,
    required this.cats,
    required this.txns,
    required this.links,
    required this.history,
    required this.count,
    required this.catCount,
    required this.year,
    required this.quarter,
    required this.scale,
    required this.canPrev,
    required this.canNext,
  });

  final List<GNode> wallets, cats, txns;
  final List<GLink> links;

  /// Id transaksi yang tidak tampil (di luar kuartal atau di atas batas 200), dipakai sebagai titik redup di tepi.
  final List<String> history;
  final int count, catCount;
  final int year, quarter; // quarter 0..3
  final double scale;
  final bool canPrev, canNext;

  List<GNode> get nodes => [...wallets, ...cats, ...txns];
  /// Berubah kalau ada titik yang bertambah/berkurang atau isinya berubah (nama sumber, kategori, jumlah).
  String get sig {
    final b = StringBuffer();
    for (final n in wallets) {
      b.write('${n.id}|${n.label}|${n.wallet!.type};');
    }
    for (final n in cats) {
      b.write('${n.id}|${n.label};');
    }
    for (final n in txns) {
      final t = n.txn!;
      b.write('${n.id}|${t.cat}|${t.wallet}|${t.amount};');
    }
    return b.toString();
  }
}

int _hash32(String s) {
  var h = 2166136261;
  for (var i = 0; i < s.length; i++) {
    h ^= s.codeUnitAt(i);
    h = (h * 16777619) & 0xFFFFFFFF;
  }
  return h;
}

/// Angka 0..1 yang tetap untuk teks yang sama (supaya susunan tidak berubah tiap dibuka).
double hashUnit(String s) => (_hash32(s) % 10000) / 10000;

String _shortName(String s, int max) => s.length > max ? '${s.substring(0, max - 1)}…' : s;

/// Menyusun data graph untuk satu kuartal kalender. [quarterOffset] 0 = kuartal berjalan, -1 = sebelumnya, dst.
/// Hanya transaksi di kuartal itu yang tampil (maks 200 terbaru); sisanya tetap tersimpan dan jadi titik riwayat.
GraphData buildGraphData({
  required List<Txn> txns,
  required List<Wallet> wallets,
  required String Function(String catId) catLabel,
  required DateTime now,
  int quarterOffset = 0,
}) {
  final base = now.year * 4 + (now.month - 1) ~/ 3;
  final off = math.min(0, quarterOffset);
  final cur = base + off;
  final qs = DateTime(cur ~/ 4, (cur % 4) * 3 + 1, 1);
  final qe = DateTime(cur ~/ 4, (cur % 4) * 3 + 4, 1);
  final ids = {for (final w in wallets) w.id};
  var oldest = base;
  for (final t in txns) {
    final idx = t.at.year * 4 + (t.at.month - 1) ~/ 3;
    if (idx < oldest) oldest = idx;
  }
  final inQ = <Txn>[
    for (final t in txns)
      if (!t.at.isBefore(qs) && t.at.isBefore(qe) && ids.contains(t.wallet)) t,
  ];
  // Terbaru dulu; dengan waktu sama, urutan di daftar. Sort Dart tidak stabil, jadi indeks ikut jadi pembeda.
  final indexed = [for (var i = 0; i < inQ.length; i++) (inQ[i], i)];
  indexed.sort((a, b) {
    final c = b.$1.at.compareTo(a.$1.at);
    return c != 0 ? c : a.$2.compareTo(b.$2);
  });
  final last = [for (final e in indexed.take(kGraphMaxTxns)) e.$1];

  // Satu hub per kategori, dipakai bersama semua sumber. Lebih dari 50: yang paling jarang digabung ke "Lainnya".
  final catCount = <String, int>{};
  for (final t in last) {
    catCount[t.cat] = (catCount[t.cat] ?? 0) + 1;
  }
  var keep = catCount.keys.toList();
  if (keep.length > kGraphMaxCats) {
    keep.sort((x, y) {
      final c = catCount[y]!.compareTo(catCount[x]!);
      return c != 0 ? c : x.compareTo(y);
    });
    keep = keep.take(kGraphMaxCats - 1).toList();
  }
  final keepSet = keep.toSet();
  final groups = <String, List<Txn>>{};
  for (final t in last) {
    groups.putIfAbsent(keepSet.contains(t.cat) ? t.cat : '_more', () => []).add(t);
  }

  final wNodes = <GNode>[];
  final cNodes = <GNode>[];
  final tNodes = <GNode>[];
  final links = <GLink>[];
  final wById = <String, GNode>{};
  for (final w in wallets.take(kGraphMaxWallets)) {
    final n = GNode('w:${w.id}', GKind.wallet)
      ..wallet = w
      ..walletId = w.id
      ..label = _shortName(w.name, 14);
    wNodes.add(n);
    wById[w.id] = n;
  }
  final perWallet = <String, int>{};
  for (final e in groups.entries) {
    final c = e.key, list = e.value;
    final cn = GNode('c:$c', GKind.category)
      ..cat = c
      ..cnt = list.length
      ..label = c == '_more' ? 'Lainnya' : catLabel(c);
    final ws = <String>[];
    for (final t in list) {
      if (!ws.contains(t.wallet)) ws.add(t.wallet);
    }
    cn.firstWallet = ws.first;
    cNodes.add(cn);
    for (final w in ws) {
      final wn = wById[w];
      if (wn != null) links.add(GLink(wn, cn, walletToCat: true));
    }
    // Transaksi boleh bercabang dari transaksi lain di kategori yang sama, tidak harus dari hub.
    final asc = [...list]..sort((x, y) {
        final c = y.at.compareTo(x.at);
        return c != 0 ? c : x.id.compareTo(y.id);
      });
    final made = <GNode>[];
    for (var k = 0; k < asc.length; k++) {
      final t = asc[k];
      final tn = GNode('t:${t.id}', GKind.txn)
        ..txn = t
        ..walletId = t.wallet
        ..cat = c;
      final parent = (k == 0 || hashUnit(t.id) < 0.1) ? cn : made[(hashUnit('${t.id}p') * k).floor().clamp(0, k - 1)];
      links.add(GLink(parent, tn));
      made.add(tn);
      tNodes.add(tn);
      perWallet[t.wallet] = (perWallet[t.wallet] ?? 0) + 1;
    }
  }
  for (final n in wNodes) {
    n.cnt = perWallet[n.walletId] ?? 0;
  }
  final shown = {for (final t in last) t.id};
  final hist = [
    for (final t in txns)
      if (ids.contains(t.wallet) && !shown.contains(t.id)) t,
  ]..sort((a, b) => a.at.compareTo(b.at));
  final total = wNodes.length + cNodes.length + tNodes.length;
  return GraphData(
    wallets: wNodes,
    cats: cNodes,
    txns: tNodes,
    links: links,
    history: [for (final t in hist.take(kGraphMaxHistory)) t.id],
    count: last.length,
    catCount: groups.length,
    year: cur ~/ 4,
    quarter: cur % 4,
    scale: math.max(0.36, math.min(1.0, math.sqrt(70 / math.max(1, total)))),
    canPrev: cur - 1 >= oldest,
    canNext: off < 0,
  );
}

/// Simulasi gaya (tolak-tarik) ala graph Obsidian. Murni Dart supaya bisa diuji tanpa layar.
class GraphSim {
  GraphSim._(this.data, this.nodes, this.byId, this.links);

  final GraphData data;
  final List<GNode> nodes;
  final Map<String, GNode> byId;
  final List<GLink> links;
  late final List<GNode> hubs;
  late final List<GNode> leaves;
  late final List<({double x, double y})> history;
  double alpha = 1;
  double scale = 1;
  double maxWallet = 1, maxCat = 1;
  double maxBorn = 0;
  bool get empty => data.count == 0;
  bool get settled => alpha <= 0.02;

  /// Membangun simulasi. Titik yang sudah ada di [previous] mempertahankan posisinya.
  factory GraphSim.build(GraphData data, {GraphSim? previous, double t = 0}) {
    final nodes = data.nodes;
    final byId = {for (final n in nodes) n.id: n};
    final old = previous == null ? <String, GNode>{} : previous.byId;
    var sd = 7;
    double rnd() {
      sd = (sd * 16807) % 2147483647;
      return sd / 2147483647 - 0.5;
    }

    const w = kGraphW, h = kGraphH;
    final wl = data.wallets;
    for (final n in nodes) {
      final o = old[n.id];
      if (o != null) {
        n.x = o.x;
        n.y = o.y;
        n.born = o.born;
        continue;
      }
      n.born = t;
      if (n.kind == GKind.wallet) {
        final i = wl.indexOf(n);
        final a = i * 2.39996 + 0.4, r = 105 * math.sqrt((i + 0.5) / wl.length);
        n.x = w / 2 + math.cos(a) * r;
        n.y = h / 2 + math.sin(a) * r;
      } else {
        // Posisi awal di dekat induknya (nanti dirapikan simulasi).
        GNode? par;
        if (n.kind == GKind.category) {
          par = byId['w:${n.firstWallet}'];
        } else {
          par = byId['c:${n.cat}'];
        }
        par ??= wl.isNotEmpty ? wl.first : null;
        n.x = (par?.x ?? w / 2) + rnd() * 44;
        n.y = (par?.y ?? h / 2) + rnd() * 44;
      }
    }
    // Titik tarik per jenis: bank di kiri, e-wallet di kanan, tunai di bawah.
    final grp = <String, List<GNode>>{'bank': [], 'ewallet': [], 'cash': []};
    for (final n in wl) {
      (grp[n.wallet!.type] ?? grp['bank']!).add(n);
    }
    final present = [for (final k in ['bank', 'ewallet', 'cash']) if (grp[k]!.isNotEmpty) k];
    final centers = <String, (double, double)>{};
    if (present.length == 3) {
      centers['bank'] = (w / 2 - 66, h / 2 - 24);
      centers['ewallet'] = (w / 2 + 66, h / 2 - 24);
      centers['cash'] = (w / 2, h / 2 + 88);
    } else if (present.length == 2) {
      centers[present[0]] = (w / 2 - 62, h / 2);
      centers[present[1]] = (w / 2 + 62, h / 2);
    } else if (present.length == 1) {
      centers[present[0]] = (w / 2, h / 2);
    }
    for (final k in present) {
      final arr = grp[k]!, c = centers[k]!;
      final rg = present.length == 1 ? 118.0 : math.min(92.0, 30 + 24 * math.sqrt(arr.length));
      for (var i = 0; i < arr.length; i++) {
        final r = rg * math.sqrt((i + 0.5) / arr.length);
        arr[i].ax = c.$1 + math.cos(i * 2.39996 + 0.4) * r;
        arr[i].ay = c.$2 + math.sin(i * 2.39996 + 0.4) * r;
      }
    }
    final g = GraphSim._(data, nodes, byId, data.links);
    g.hubs = [...data.wallets, ...data.cats];
    g.leaves = data.txns;
    g.scale = data.scale;
    g.history = [
      for (final id in data.history)
        () {
          final a = hashUnit(id) * 6.2832, r = 134 + 26 * math.pow(hashUnit('${id}r'), 0.7);
          return (x: w / 2 + math.cos(a) * r, y: h / 2 + math.sin(a) * r);
        }(),
    ];
    g.maxWallet = math.max(1, wl.fold<int>(0, (m, n) => math.max(m, n.cnt))).toDouble();
    g.maxCat = math.max(1, data.cats.fold<int>(0, (m, n) => math.max(m, n.cnt))).toDouble();
    g.maxBorn = nodes.fold<double>(0, (m, n) => math.max(m, n.born));
    final steps = old.isNotEmpty ? 40 : (nodes.length > 150 ? 130 : 300);
    for (var i = 0; i < steps; i++) {
      g.step();
    }
    g.alpha = old.isNotEmpty ? 0.4 : 0.15;
    return g;
  }

  static double _w(GNode n) => switch (n.kind) { GKind.wallet => 8, GKind.category => 4, GKind.txn => 1 };

  void _rep(GNode a, GNode b, double cut, double kr) {
    final dx = a.x - b.x, dy = a.y - b.y, d2 = dx * dx + dy * dy + 0.5;
    if (d2 > cut) return;
    final d = math.sqrt(d2);
    var f = kr * _w(a) * _w(b) / d2;
    if (f > 5) f = 5;
    final ux = dx / d * f, uy = dy / d * f;
    a.fx += ux;
    a.fy += uy;
    b.fx -= ux;
    b.fy -= uy;
  }

  /// Satu langkah simulasi. Transaksi hanya dihitung terhadap tetangga dekat (grid), bukan semua pasangan.
  void step() {
    const w = kGraphW, h = kGraphH;
    final s = scale, kr = 150 * s, rw = 42 * math.pow(s, 0.7), rt = 15 * s;
    for (final n in nodes) {
      n.fx = 0;
      n.fy = 0;
    }
    for (var i = 0; i < hubs.length; i++) {
      for (var j = i + 1; j < hubs.length; j++) {
        _rep(hubs[i], hubs[j], 1e9, kr);
      }
    }
    for (final l in leaves) {
      for (final hb in hubs) {
        _rep(l, hb, 1300, kr);
      }
    }
    const cs = 24.0;
    final grid = <int, List<GNode>>{};
    for (var i = 0; i < leaves.length; i++) {
      final n = leaves[i];
      n.li = i;
      grid.putIfAbsent((n.x / cs).floor() * 64 + (n.y / cs).floor(), () => []).add(n);
    }
    for (final a in leaves) {
      final cx = (a.x / cs).floor(), cy = (a.y / cs).floor();
      for (var ox = -1; ox <= 1; ox++) {
        for (var oy = -1; oy <= 1; oy++) {
          final arr = grid[(cx + ox) * 64 + (cy + oy)];
          if (arr == null) continue;
          for (final b in arr) {
            if (b.li > a.li) _rep(a, b, 576, kr);
          }
        }
      }
    }
    for (final l in links) {
      final a = l.a, b = l.b;
      final dx = b.x - a.x, dy = b.y - a.y, d = math.sqrt(dx * dx + dy * dy) + 0.01;
      double rest, kk;
      if (l.walletToCat) {
        rest = 62 * math.pow(s, 0.7).toDouble();
        kk = 0.03;
      } else {
        rest = a.kind == GKind.wallet ? rw.toDouble() : rt;
        kk = a.kind == GKind.wallet ? 0.09 : 0.12;
      }
      final f = kk * (d - rest);
      final ux = dx / d * f, uy = dy / d * f;
      a.fx += ux;
      a.fy += uy;
      b.fx -= ux;
      b.fy -= uy;
    }
    for (final a in nodes) {
      final dx = a.x - w / 2, dy = a.y - h / 2, d = math.sqrt(dx * dx + dy * dy) + 0.01;
      if (d > 138) {
        final f = (d - 138) * 0.1;
        a.fx -= dx / d * f;
        a.fy -= dy / d * f;
      }
    }
    for (final a in nodes) {
      if (a.kind == GKind.wallet) {
        a.fx += (a.ax - a.x) * 0.12;
        a.fy += (a.ay - a.y) * 0.12;
      } else {
        a.fx += (w / 2 - a.x) * 0.003;
        a.fy += (h / 2 - a.y) * 0.003;
      }
      if (a.pin) {
        a.vx = 0;
        a.vy = 0;
        continue;
      }
      a.vx = (a.vx + a.fx * alpha) * 0.8;
      a.vy = (a.vy + a.fy * alpha) * 0.8;
      a.x = (a.x + a.vx).clamp(58.0, w - 58).toDouble();
      a.y = (a.y + a.vy).clamp(52.0, h - 72).toDouble();
    }
    alpha = math.max(0.012, alpha * 0.993);
  }

  /// Titik yang ikut menyala saat [id] dipilih: sumber → transaksi dan kategorinya, dan seterusnya.
  Set<String>? neighbors(String id) {
    final n = byId[id];
    if (n == null) return null;
    final set = {id};
    void add(GNode? x) {
      if (x != null) set.add(x.id);
    }

    if (n.kind == GKind.txn) {
      add(byId['c:${n.cat}']);
      add(byId['w:${n.walletId}']);
    } else {
      for (final m in leaves) {
        if (n.kind == GKind.wallet ? m.walletId == n.walletId : m.cat == n.cat) {
          add(m);
          add(byId[n.kind == GKind.wallet ? 'c:${m.cat}' : 'w:${m.walletId}']);
        }
      }
    }
    return set;
  }

  /// Titik yang terkena sentuhan di (x, y) pada ruang kanvas, atau null.
  GNode? hit(double px, double py) {
    GNode? best;
    var bd = 1e9;
    final s = scale;
    for (final n in nodes) {
      final r = switch (n.kind) {
        GKind.wallet => 22 * math.max(s, 0.7),
        GKind.category => 15 * math.max(s, 0.6),
        GKind.txn => math.max(8.0, 11 * s),
      };
      final d = math.sqrt((n.x - px) * (n.x - px) + (n.y - py) * (n.y - py));
      if (d < r && d - r * 0.15 < bd - (n.kind == GKind.txn ? 0 : 3)) {
        best = n;
        bd = d;
      }
    }
    return best;
  }
}
