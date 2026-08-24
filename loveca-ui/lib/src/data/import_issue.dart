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

  /// ★★ この記録は「いま壊れている」のか「壊れた記録が残っている」のか ★★
  ///
  /// `MasterStateDao` の「未解消」は
  /// `NOT EXISTS (master_files WHERE path = ? AND hash = ?)` で判定する
  /// （`master_state_dao.dart:127-131`）。`master_files` の主キーは `{path}` で
  /// **現在のハッシュ 1 件しか持たない**のに、`import_issues` の主キーは
  /// `{path, hash}` である。
  ///
  /// したがって配信側がファイルを直すと**内容が変わるのでハッシュも変わり**、
  /// 取り込みに成功しても古いハッシュの記録は永久に未解消のまま残る。
  /// 消す API も無い（`ルール整合性チェック_v1.06.md` D-13）。
  ///
  /// → `loveca_db` は変更しないので、**UI 側で見分けて添える。**
  /// 「いま壊れている」と「壊れた記録が残っている」を混ぜない。
  bool get supersededByNewerFile =>
      currentHash != null && currentHash != hash;

  String get kindLabel => switch (kind) {
        // ★内部語彙（fromKey / ArgumentError）を出さない。対処が分かる言葉にする。
        ImportIssueKind.readFailure => 'ファイルを読めませんでした',
        ImportIssueKind.unknownKey => 'このアプリが知らない値が入っていました',
        ImportIssueKind.parseFailure => 'ファイルの中身を解釈できませんでした',
      };
}
