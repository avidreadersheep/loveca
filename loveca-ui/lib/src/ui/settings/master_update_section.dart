/// カードデータの更新（Android の「その他」タブ / `docs/Android UI 決定.md` §3-16 の 1）.
///
/// ★★ §1-5 が **D56** を覆した分の★★画面側★★である ★★
/// ★**D56**: 「データを更新」は**再起動を伴う操作**にする。
/// ★**§1-5**: ★★Android では「その他」タブに更新ボタンを置き、★進捗を出しながら取り込み、★再起動しない。★★
/// ★**理由** —— ★★Android ではアプリが自分を再起動するのが行儀の悪い挙動になるため。★★
///
/// ★★ 覆していないもの（★§2 の穴 2。★利用者が承知のうえで受け入れた）★★
/// ★**既に開いている `DeckEditStore` は★★古いリポジトリを掴んだままである★★。**
/// ★**この widget は★その穴を 1 ミリも塞がない。**★★塞いだと読ませない★★。
///
/// ★★ 出すものは 4 つ（§3-16 の 1）★★
///
/// | # | 何 |
/// |---|---|
/// | ★**1** | ★**状態の表示**（★取り込み済み / ★新しい版が在る / ★見つからない） |
/// | ★**2** | ★**更新ボタン** |
/// | ★**3** | ★**進捗**（★走っているあいだ。★★`BootRunning` へ落とさない★★ / `boot_controller.dart` の doc） |
/// | ★**4** | ★**完了ダイアログ**（★★件数を出す★★ / ★§2 の穴 3） |
///
/// ★★ 失敗と「走らせなかった」を畳まない ★★
/// ★`MasterReloadRefused` は★★取り込みの失敗ではない★★（★起動が終わっていない / ★もう 1 本走っている）。
/// ★**畳むと「データが壊れている」と読める文面が出る**（★`boot_controller.dart` の doc と同じ向き）。
///
/// ★★ 「取り込み失敗の詳細」は置かない（★§2 の穴 3）★★
/// ★**Android には後日見に行く画面が無い。**★★出るのはこのダイアログの件数だけである★★。
/// ★**`import_issues` は次に成功するまで残るが、★Android からは見に行けない**（★受け入れた穴）。
///
/// ★★ Windows には載せない ★★
/// ★**§1-5 は「Android では」と書いており、★Windows を 1 文字も述べていない。**
/// ★**Windows の R6 は★★今も「アプリを起動し直すと取り込みます」と出す★★**（**D56** のまま）。
/// → ★**条件だけを [masterUpdateStatusOf] で共有する**（★★同じ判定を 2 か所に置かない★★ / **D-15** の規約 3）。
library;

import 'package:flutter/material.dart';

import '../../boot/boot_controller.dart';
import '../../boot/boot_steps.dart';

/// 「いまカードデータはどうなっているか」。
///
/// ★★ 判定はここ 1 か所である ★★
/// ★**Windows の R6（`settings_page.dart` の `_UpdateHint`）も★この関数を読む。**
/// ★★**出す字面は違う**★★ —— ★あちらは「アプリを起動し直すと取り込みます」（**D56**）、
/// ★こちらは「更新する」（§1-5）。★★条件が同じで、★次の一手が違う★★。
enum MasterUpdateStatus {
  /// ★配信物そのものが見つからない（**D60**）。
  distMissing,

  /// ★配信物のほうが新しい版である。
  updateAvailable,

  /// ★取り込み済み。
  upToDate,
}

/// [local] は取り込み済みの `dataVersion`、[remote] は配信物の `dataVersion`。
MasterUpdateStatus masterUpdateStatusOf({
  required int local,
  required int? remote,
  required bool distMissing,
}) {
  if (distMissing) return MasterUpdateStatus.distMissing;
  if (remote != null && remote > local) return MasterUpdateStatus.updateAvailable;
  return MasterUpdateStatus.upToDate;
}

/// 完了ダイアログに出す 1 行（★§2 の穴 3 の「完了ダイアログに件数」）。
///
/// ★★ 純粋関数にしてある ★★
/// ★**文面を widget の中に埋めると★対が置けない**（★先例は `deck_counters_band.dart` の `fitsOneRow`）。
///
/// ★★ 「更新しました」と「新しい版はありませんでした」を分ける ★★
/// ★**取り込みが 1 件も走らなかったとき**（`nothingImported`）に「更新しました」と出すと、
/// ★★何も起きていないのに起きたと読める★★。
String masterUpdateDoneMessage(MasterReloadDone done) {
  final failed = done.outcome.result?.failedPaths.length ?? 0;
  final head = done.outcome.nothingImported
      ? '新しいカードデータはありませんでした。'
      : '更新しました。';
  if (failed == 0) return head;
  // ★★ 件数を出す（★§2 の穴 3 の字面）★★
  return '$head（$failed 件を取り込めませんでした）';
}

/// 「その他」タブの★カードデータの更新の節。
class MasterUpdateSection extends StatefulWidget {
  const MasterUpdateSection({
    super.key,
    required this.status,
    required this.localDataVersion,
    required this.remoteDataVersion,
    required this.onUpdate,
    this.onNotices,
  });

  final MasterUpdateStatus status;
  final int localDataVersion;
  final int? remoteDataVersion;

  /// ★取り込みをもう一度走らせる。★★正は `BootController.reload` である★★。
  final Future<MasterReloadResult> Function() onUpdate;

  /// ★★ Notice バーへ回す口（★§2 の穴 3 の「Notice バー ＋ 完了ダイアログ」）★★
  /// ★**バーそのものはこの widget が持たない**（★★下段タブの外側が持つ★★ / ★まだ 1 行も無い）。
  final void Function(List<BootNotice> notices)? onNotices;

  @override
  State<MasterUpdateSection> createState() => _MasterUpdateSectionState();
}

class _MasterUpdateSectionState extends State<MasterUpdateSection> {
  /// ★★ 走っているあいだ（★§3-16 の「進捗」）★★
  bool _running = false;

  Future<void> _run() async {
    // ★★ 2 つ同時に押させない ★★
    //   ★`BootController.reload` も断るが、★★断りは「失敗」ではない★★ので
    //   ★ここで止めるほうが★出る文面が正しい。
    if (_running) return;
    setState(() => _running = true);
    final MasterReloadResult result;
    try {
      result = await widget.onUpdate();
    } finally {
      if (mounted) setState(() => _running = false);
    }
    if (!mounted) return;
    if (result is MasterReloadDone) widget.onNotices?.call(result.notices);
    await _showResult(result);
  }

  Future<void> _showResult(MasterReloadResult result) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('masterUpdate:dialog'),
          content: Text(
            switch (result) {
              MasterReloadDone() => masterUpdateDoneMessage(result),
              // ★★ 古いカタログのまま動き続けることを言う ★★
              //   ★言わないと「壊れた」と読める（★実際は 1 ビットも壊れていない）。
              MasterReloadFailed() =>
                '更新できませんでした。前回取り込んだ内容で動いています。',
              // ★★ 失敗と分ける（★上の doc）★★
              MasterReloadRefused() => 'いまは更新できません。少し待ってからもう一度お試しください。',
            },
            key: const ValueKey('masterUpdate:dialogText'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('masterUpdate'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ★★ 1. 状態の表示（§3-16）★★
        Text(
          switch (widget.status) {
            MasterUpdateStatus.distMissing =>
              'カードデータが見つかりません。前回取り込んだ内容で動いています。',
            MasterUpdateStatus.updateAvailable =>
              '新しいカードデータがあります'
                  '（${widget.localDataVersion} → ${widget.remoteDataVersion}）。',
            MasterUpdateStatus.upToDate => '取り込み済みです。',
          },
          key: const ValueKey('masterUpdate:status'),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // ★★ 2. 更新ボタン（§3-16）★★
            //   ★走っているあいだは押せない（★`onPressed` が null）。
            FilledButton(
              key: const ValueKey('masterUpdate:button'),
              onPressed: _running ? null : _run,
              child: const Text('カードデータを更新する'),
            ),
            if (_running) ...[
              const SizedBox(width: 12),
              // ★★ 3. 進捗（§3-16）★★
              //   ★★`BootRunning` へ落とさない★★ —— ★落とすと画面の木ごと捨てられる
              //     （`boot_controller.dart` の doc）。★ここは**この節の中だけ**が変わる。
              const SizedBox(
                key: ValueKey('masterUpdate:progress'),
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
