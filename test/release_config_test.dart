import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Penjaga konfigurasi rilis: build rilis tidak boleh diam-diam memakai kunci debug.
void main() {
  test('Gradle: build rilis tanpa key.properties gagal kecuali diizinkan sengaja', () {
    final g = File('android/app/build.gradle.kts').readAsStringSync();
    expect(g, contains('allowDebugSigning'));
    expect(g, contains('taskGraph.whenReady'));
    expect(g, contains('GradleException'));
    expect(g, contains('!keystorePropertiesFile.exists() && !allowDebugSigning'));
  });

  test('Workflow: izin kunci debug hanya menyala kalau kunci rilis tidak terpasang', () {
    final w = File('.github/workflows/build-apk.yml').readAsStringSync();
    expect(w, contains("ORG_GRADLE_PROJECT_allowDebugSigning: \${{ steps.sign.outputs.signed == 'true' && 'false' || 'true' }}"));
  });

  test('tidak ada kunci rilis atau kata sandi di pohon proyek', () {
    final bad = <String>[];
    for (final f in Directory('.').listSync(recursive: true).whereType<File>()) {
      final p = f.path;
      if (p.contains('/.git/') || p.contains('/build/') || p.contains('/.dart_tool/') || p.contains('/.pub-cache/')) continue;
      if (p.endsWith('.jks') || p.endsWith('.keystore') || p.endsWith('key.properties')) bad.add(p);
    }
    expect(bad, isEmpty);
  });
}
