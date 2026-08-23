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
    required this.searchedPaths,
    required this.appVersion,
    this.result,
    this.remoteMinAppVersion,
    this.settingsRecoveredFrom,
  });

  final bool distMissing;

  /// dist を探した場所（決定 D60）。★不在のとき利用者に全部見せる。
  final List<String> searchedPaths;

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
  Future<MasterImportOutcome> import({
    required Directory distDir,
    required List<String> searchedPaths,
    required String appVersion,
    required DateTime now,
    Object? settingsRecoveredFrom,
  }) =>
      guardRepository('master.import', () async {
        final version = VersionInfo.parse(
          await File('${distDir.path}/version.json').readAsString(),
        );
        final manifest = Manifest.parse(
          await File('${distDir.path}/manifest.json').readAsString(),
        );

        final result = await MasterImporter(_db).import(
          remoteVersion: version,
          remoteManifest: manifest,
          source: LocalDirectoryMasterFileSource(distDir),
          appVersion: appVersion,
          now: now,
        );

        return MasterImportOutcome(
          distMissing: false,
          searchedPaths: searchedPaths,
          appVersion: appVersion,
          result: result,
          remoteMinAppVersion: version.minAppVersion,
          settingsRecoveredFrom: settingsRecoveredFrom,
        );
      });

  Future<int> localDataVersion() =>
      guardRepository('master.localDataVersion',
          () => MasterStateDao(_db).localDataVersion());

  Future<RuleConfig> ruleConfig() =>
      guardRepository('master.ruleConfig', () => DeckDao(_db).ruleConfig());

  /// ★決定 D39: 記録するだけで誰も見ない状態にしない。
  /// M1 では起動サマリに件数を出し、詳細の画面（R6）は M6 で作る。
  Future<int> outstandingImportIssueCount() =>
      guardRepository('master.outstandingImportIssueCount',
          () => MasterStateDao(_db).outstandingImportIssueCount());
}
