/// アプリ版の供給元（`docs/UI設計メモ.md` §9-2）.
///
/// `MasterImporter.import(appVersion:)` が要る。`planUpdate` がこれを
/// 配信側の `minAppVersion` と比べ、**古ければ取り込みを拒否する**。
///
/// `package_info_plus` を入れない。依存を 1 つ増やす価値が無い。
///
/// ★★ 手で揃えるものは必ずズレる。テストで固定する ★★
/// `test/app_info_test.dart` が `pubspec.yaml` の `version:` を読んで
/// [AppInfo.version] と突き合わせる。定数のコメントに「揃えること」と
/// 書くだけでは守られない（決定 D58 と同じ手当て）。
library;

abstract final class AppInfo {
  /// ★`pubspec.yaml` の `version:` と揃える。ズレると `minAppVersion` の判定が誤る。
  static const String version = '0.1.0';
}
