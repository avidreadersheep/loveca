/// `AppInfo.version` と `pubspec.yaml` の突き合わせ（`docs/UI設計メモ.md` §9-2）.
///
/// ★手で揃えるものは必ずズレる。コメントに「揃えること」と書くだけでは守られない。
/// ズレると `planUpdate` の `minAppVersion` 判定が誤る。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_ui/src/app_info.dart';

void main() {
  test('AppInfo.version が pubspec.yaml の version と一致する', () {
    final pubspec = File('pubspec.yaml');
    expect(
      pubspec.existsSync(),
      isTrue,
      reason: 'テストの作業ディレクトリはパッケージのルートである前提',
    );

    final line = pubspec
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'), orElse: () => '');
    expect(line, isNotEmpty, reason: 'pubspec.yaml に version: が無い');

    final pubspecVersion = line.substring('version:'.length).trim();
    expect(
      AppInfo.version,
      pubspecVersion,
      reason: 'AppInfo.version と pubspec.yaml の version を揃えること',
    );
  });
}
