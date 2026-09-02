/// マスタの取り込みと状態（決定 D55 / D56 / D39）.
///
/// ★★ 取り込みは起動ゲートでのみ走らせる（決定 D56）★★
/// 実行中に取り込むと、メモリ上の `MasterCatalog`（`cards` / `printings` / `rows`）が
/// **静かに古くなる。** 間違った答えを返すが例外は出ない——A-3 と同じ型。
/// 「データを更新」は**再起動を伴う操作**にする。
library;

import 'dart:io';

import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_db/native.dart';

import 'app_settings.dart';
import 'dist_locator.dart';
import 'import_issue.dart';
import 'repository_exception.dart';

/// 取り込みを試みた結果。
///
/// ★★ 「やらなかった」と「やって失敗した」を区別する ★★
/// dist が無いときは [MasterImporter] を呼ばない（決定 D60）ので、
/// [result] は null になり [distMissing] が立つ。
/// 一緒くたにすると原因が「dist が無い」から「読めない」に化ける。
class MasterImportOutcome {
  const MasterImportOutcome({
    required this.distMissing,
    required this.location,
    required this.appVersion,
    required this.settings,
    this.result,
    this.remoteMinAppVersion,
    this.remoteDataVersion,
    this.settingsRecoveredFrom,
  });

  final bool distMissing;

  /// dist をどこで探し、**どの段で見つけたか**（決定 D60 / R6）。
  final DistLocation location;

  /// このセッションで効いている設定（R6 が初期値に使う）。
  final AppSettings settings;

  /// dist を探した場所（決定 D60）。★不在のとき利用者に全部見せる。
  List<String> get searchedPaths => location.searchedPaths;

  /// このアプリの版。★`appTooOld` のとき最小版と並べて出す。
  final String appVersion;

  /// ★設定ファイルが壊れていて既定に戻したときの理由（設計メモ §4-6(5)）。
  ///
  /// ★★ 黙って既定に戻さない ★★
  /// 戻したことを言わないと「設定したのに効かない」が原因不明のまま残る。
  /// `AppSettingsStore.load()` が理由を返すのに、それを捨てていた（M1 の穴）。
  final Object? settingsRecoveredFrom;

  /// dist があったときだけ入る。
  final MasterImportResult? result;

  /// 配信物が要求するアプリの最小版。
  ///
  /// ★★ `appTooOld` のとき「実際の値」を出すために要る ★★
  /// 「アプリが古い」だけでは利用者は直せない。
  /// 決定 D60 が「探した場所を並べる」と定めたのと同じ理屈である。
  final String? remoteMinAppVersion;

  /// 配信物が持つ `dataVersion`。★取り込み済みの版と並べて出す（R6）。
  /// これが取り込み済みより大きければ「再起動すると取り込まれます」と言える。
  final int? remoteDataVersion;

  /// ★取り込みが 1 件も行われなかったか。
  /// `appTooOld` / `upToDate` は例外を投げずに戻るので、これを見ないと
  /// 「取り込んだ結果 0 件」と区別できない。
  bool get nothingImported =>
      distMissing || result == null || result!.decision != UpdateDecision.update;

  UpdateDecision? get decision => result?.decision;
}

class MasterRepository {
  const MasterRepository(this._db);

  final LovecaDatabase _db;

  /// dist から差分取り込みを行う。
  ///
  /// [now] は呼び出し側から渡す（`Clock` / `docs/UI設計メモ.md` §9-1）。
  /// ★★ [imageSink] —— ★端末へ写すか（★§32-6 の **8** の 3 / 決定 **D149-3**）★★
  ///
  /// ## ★★ ローカルの dist から取り込むときは★渡さない ★★
  ///
  /// ★**画像は★★既に読み先に在る★★**（★`resolveCardImagesRoot` の★段 1 ＝ `dist/images`）。
  /// ★**写すと★★571 MB を二重に持つ★★**（★§59-4 の 理由 3 —— ★画経-2 を採らなかった理由そのもの）。
  /// ★★**「今日は使わない引数」ではない。★★渡さないことが答えである★★**（★対で固定した）。
  ///
  /// ## ★★ 渡す相手は★HTTP から取り込むときである（★★まだ 1 行も無い★★）★★
  ///
  /// ★**`HttpMasterFileSource` を使う経路は★★§32-6 の 8 の 5 である★★**（★★モバイルの UI の形★★ / ★未着手）。
  /// ★**その経路が★段 2 の読み先を作る。**
  Future<MasterImportOutcome> import({
    required DistLocation location,
    required String appVersion,
    required AppSettings settings,
    required DateTime now,
    Object? settingsRecoveredFrom,
    MasterImageSink? imageSink,
  }) =>
      guardRepository('master.import', () async {
        final distDir = location.directory!;
        final version = VersionInfo.parse(
          await File('${distDir.path}/version.json').readAsString(),
        );
        final manifest = Manifest.parse(
          await File('${distDir.path}/manifest.json').readAsString(),
        );

        // ★★ 画像は★別のマニフェストに載る（決定 **D121-1** ＝ 画-5）★★
        //   ★**「まだ無い」と「0 枚である」を書き分ける**（★生成側が `--skip-images` なら書かない）——
        //     ★★[VersionInfo.hasImageManifest] が偽なら★1 バイトも読まない★★。
        //   ★**読む先は★配信物の根である** —— ★`version.json` の
        //     `imageManifestPath` は★★配る側のパスであって★ローカルの置き場ではない★★
        //     （★カードのマニフェストと★同じ扱い / ★上の 2 行と揃えてある）。
        final imageManifest = version.hasImageManifest
            ? Manifest.parseImages(
                await File('${distDir.path}/image_manifest.json')
                    .readAsString(),
              )
            : null;

        final result = await MasterImporter(_db).import(
          remoteVersion: version,
          remoteManifest: manifest,
          remoteImageManifest: imageManifest,
          source: LocalDirectoryMasterFileSource(distDir),
          appVersion: appVersion,
          now: now,
          imageSink: imageSink,
        );

        return MasterImportOutcome(
          distMissing: false,
          location: location,
          appVersion: appVersion,
          settings: settings,
          result: result,
          remoteMinAppVersion: version.minAppVersion,
          remoteDataVersion: version.dataVersion,
          settingsRecoveredFrom: settingsRecoveredFrom,
        );
      });

  Future<int> localDataVersion() =>
      guardRepository('master.localDataVersion',
          () => MasterStateDao(_db).localDataVersion());

  Future<RuleConfig> ruleConfig() =>
      guardRepository('master.ruleConfig', () => DeckDao(_db).ruleConfig());

  /// ★決定 D39: 記録するだけで誰も見ない状態にしない。
  /// M1 では起動サマリに件数を出し、詳細の画面（R6）は M6 で作った。
  Future<int> outstandingImportIssueCount() =>
      guardRepository('master.outstandingImportIssueCount',
          () => MasterStateDao(_db).outstandingImportIssueCount());

  /// 未解消の取り込み失敗の一覧（R6 / P2）。
  ///
  /// ★★ `master_files` の現在ハッシュを一緒に引く ★★
  /// 「いま何の版が取り込まれているか」は、失敗を調べるときの手がかりになる
  /// （R6 の「詳しい内容」に出す）。
  ///
  /// ★★ 2026-08-27: D-13 は根治した ★★
  /// 以前ここは `ImportIssue.supersededByNewerFile` を立てるためにあった。
  /// **配信側が直すとハッシュが変わり、古い失敗が永久に未解消のまま残る**
  /// という穴の当座の手当てである。
  /// `MasterStateDao.recordFile` が同じ path の過去の失敗を消すようになったので
  /// **その状態そのものが作れなくなり、フラグは撤去した。**
  /// ★現在ハッシュ自体は手がかりとして残す。
  Future<List<ImportIssue>> outstandingImportIssues() =>
      guardRepository('master.outstandingImportIssues', () async {
        final dao = MasterStateDao(_db);
        final rows = await dao.outstandingImportIssues();
        final current = await dao.localFileHashes();
        return [
          for (final row in rows)
            ImportIssue(
              path: row.path,
              hash: row.hash,
              kind: row.kind,
              message: row.message,
              occurrenceCount: row.occurrenceCount,
              firstSeenAt: row.firstSeenAt,
              lastSeenAt: row.lastSeenAt,
              currentHash: current[row.path],
            ),
        ];
      });

  /// バッジ用（R2 の設定アイコン）。
  ///
  /// ★`Stream<int>` は drift の型ではないので、そのまま通してよい
  /// （`docs/UI設計メモ.md` §4-2）。
  Stream<int> watchOutstandingImportIssueCount() =>
      MasterStateDao(_db).watchOutstandingImportIssueCount();
}
