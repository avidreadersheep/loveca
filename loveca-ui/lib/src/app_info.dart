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
  ///
  /// ★★ 1.0.0 なのは「製品として 1.0 に達したから」ではない ★★
  /// 配信物の `minAppVersion` は
  /// `loveca-data/loveca_data/build_dist.py:84` の関数既定値 `"1.0.0"` で
  /// 固定されており、**CLI に露出していない**。
  /// したがって**これまでに作られた dist はすべて「アプリ 1.0.0 以上」を要求**し、
  /// それ未満だと `planUpdate` が `appTooOld` を返して 1 件も取り込めない
  /// （M1 の実機起動で実際にこれに落ちた）。
  ///
  /// ★**これは「データに合わせてアプリ版を変える」という本来逆の回避である。**
  /// 正す先は `loveca-data` 側（`min_app_version` を CLI へ露出し、既定を実態に）で、
  /// `ルール整合性チェック_v1.06.md` **D-7** に未決として登録してある（判断は Phase 4）。
  /// **この注記を消さないこと。** 消すと次に読む人が「1.0 リリース済み」と誤読する。
  static const String version = '1.0.0';
}
