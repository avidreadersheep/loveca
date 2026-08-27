/// 取り込みに失敗した商品ファイルの記録（決定 D39 / `docs/UI設計メモ.md` §2-6）.
///
/// ★★ 記録するだけで誰も見ない状態にしない ★★
/// D39 は「商品ファイル単位で隔離し `import_issues` に記録する」と定めたが、
/// M5 まで**呼び出し元が 1 つも無かった**。R6（M6）がその出口である。
///
/// ★★ drift の `ImportIssueRow` を UI へ通さない ★★
/// `deck_repository.dart` の規約（リポジトリが返すのは `loveca_core` の型と
/// UI 用の値だけ）に揃える。`ImportIssueRow` は drift の `DataClass` である。
library;

import 'package:loveca_db/loveca_db.dart';

/// 1 件の取り込み失敗。
class ImportIssue {
  const ImportIssue({
    required this.path,
    required this.hash,
    required this.kind,
    required this.message,
    required this.occurrenceCount,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.currentHash,
  });

  /// マニフェスト上の path（例 `cards/BP01.json`）。
  final String path;

  /// 失敗したときのファイルのハッシュ（`sha256:...`）。
  final String hash;

  final ImportIssueKind kind;

  /// 例外の `toString()`。★内部語彙が出るので、そのままは見せず折りたたむ。
  final String message;

  final int occurrenceCount;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;

  /// ★同じ path について **いま** `master_files` に記録されているハッシュ。
  /// 一度も取り込めていなければ null。
  final String? currentHash;

  // ★★ 2026-08-27: `supersededByNewerFile` を撤去した（D-13 の根治）★★
  //   当座の手当てとして「そのあと別の版で取り込めています」を添えていた。
  //   `MasterStateDao.recordFile` が同じ path の過去の失敗を消すようになり、
  //   **その状態そのものが作れなくなった。**
  //
  //   ★★ 残しておくと逆に嘘をつく ★★
  //   いま `currentHash != hash` になるのは
  //   「**古い**版が取り込まれていて、**新しい**版で失敗した」ときだけである。
  //   「新しい版で取り込めています」は**向きが逆**になる。
  //   ★死んだだけでなく、意味が反転していた（撤去の理由はこちらのほうが強い）。

  String get kindLabel => switch (kind) {
        // ★内部語彙（fromKey / ArgumentError）を出さない。対処が分かる言葉にする。
        ImportIssueKind.readFailure => 'ファイルを読めませんでした',
        ImportIssueKind.unknownKey => 'このアプリが知らない値が入っていました',
        ImportIssueKind.parseFailure => 'ファイルの中身を解釈できませんでした',
      };
}
