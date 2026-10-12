import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/theme/theme_mode_store.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('theme_mode'));
  tearDown(() => dir.deleteSync(recursive: true));

  ThemeModeStore store() => ThemeModeStore(directory: () async => dir);

  test('starts light, and stays light with no file', () async {
    final s = store();
    expect(s.value, ThemeMode.light);
    await s.load();
    expect(s.value, ThemeMode.light);
  });

  test('a saved choice comes back in a new store', () async {
    for (final mode in ThemeMode.values) {
      await store().save(mode);
      expect(File('${dir.path}/theme_mode.txt').readAsStringSync(), mode.name);
      final again = store();
      await again.load();
      expect(again.value, mode);
    }
  });

  test('save notifies listeners', () async {
    final s = store();
    var calls = 0;
    s.addListener(() => calls++);
    await s.save(ThemeMode.dark);
    expect(calls, 1);
  });

  test('a garbled or unreadable file falls back to light', () async {
    File('${dir.path}/theme_mode.txt').writeAsStringSync('purple');
    final garbled = store();
    await garbled.load();
    expect(garbled.value, ThemeMode.light);

    // A directory where the file should be cannot be read as text.
    File('${dir.path}/theme_mode.txt').deleteSync();
    Directory('${dir.path}/theme_mode.txt').createSync();
    final unreadable = store();
    await unreadable.load();
    expect(unreadable.value, ThemeMode.light);
    await unreadable.save(ThemeMode.dark); // write fails quietly
    expect(unreadable.value, ThemeMode.dark);
  });
}
