/// 設定の書き込みの差し替え（テスト用 / M6）.
///
/// ★`AppSettingsStore` はファイルを持つ。画面のテストでファイル I/O を
/// 走らせたくないので `implements` で通す。
/// ファイルそのものの往復は `test/data/app_settings_test.dart` が実ファイルで固定している。
library;

import 'dart:io';

import 'package:loveca_ui/src/data/app_settings.dart';

class FakeAppSettingsStore implements AppSettingsStore {
  FakeAppSettingsStore([this.stored = AppSettings.defaults]);

  AppSettings stored;
  final List<AppSettings> saved = [];

  @override
  File get file => throw UnimplementedError('画面のテストでは使わない');

  @override
  Future<AppSettingsLoad> load() async => AppSettingsLoad(stored);

  @override
  Future<void> save(AppSettings settings) async {
    stored = settings;
    saved.add(settings);
  }
}
