import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// The person's System / Light / Dark choice, saved as 'system' | 'light' | 'dark' in a small
/// file. Starts as Light, and stays Light when the file is missing or unreadable.
class ThemeModeStore extends ValueNotifier<ThemeMode> {
  ThemeModeStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory,
      super(ThemeMode.light);

  final Future<Directory> Function() _directory;

  Future<File> get _file async =>
      File('${(await _directory()).path}/theme_mode.txt');

  Future<void> load() async {
    try {
      final saved = (await (await _file).readAsString()).trim();
      value = ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => value,
      );
    } catch (_) {
      // Missing or unreadable: keep the current mode.
    }
  }

  /// Applies [mode] now and saves it; a failed write only means it is not remembered.
  Future<void> save(ThemeMode mode) async {
    value = mode;
    try {
      await (await _file).writeAsString(mode.name, flush: true);
    } catch (_) {}
  }
}

/// Makes the store reachable from More → Appearance: `ThemeModeScope.of(context)`.
class ThemeModeScope extends InheritedNotifier<ThemeModeStore> {
  const ThemeModeScope({
    super.key,
    required ThemeModeStore store,
    required super.child,
  }) : super(notifier: store);

  /// Null where the app is not around (a screen pumped alone in a test).
  static ThemeModeStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeModeScope>()?.notifier;
}
