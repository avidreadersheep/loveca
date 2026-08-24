/// マスタの状態の差し替え（テスト用 / M6）.
///
/// ★`MasterRepository` は `LovecaDatabase` を要求するので、画面のテストでは
/// そのままでは作れない。`FakeDeckRepository` と同じく `implements` で通す。
///
/// ★★ 役割を混ぜない ★★
/// 「取り込み失敗が**実際に起きる**こと」は実 DB で確かめる
/// （`test/data/import_issue_test.dart`）。ここで固定するのは
/// **画面が件数と一覧をどう出すか**だけである。
library;

import 'dart:async';

import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/data/import_issue.dart';
import 'package:loveca_ui/src/data/master_repository.dart';

class FakeMasterRepository implements MasterRepository {
  FakeMasterRepository({
    this.issues = const [],
    this.localDataVersionValue = 2,
    this.failIssues,
  });

  List<ImportIssue> issues;
  final int localDataVersionValue;

  /// ★決定 D53: 失敗を 0 件にすり替えないことを確かめるため。
  Object? failIssues;

  final StreamController<int> issueCount = StreamController<int>.broadcast();

  int issuesCalls = 0;

  @override
  Future<int> outstandingImportIssueCount() async => issues.length;

  @override
  Future<List<ImportIssue>> outstandingImportIssues() async {
    issuesCalls++;
    final failure = failIssues;
    if (failure != null) throw failure;
    return issues;
  }

  @override
  Stream<int> watchOutstandingImportIssueCount() => issueCount.stream;

  @override
  Future<int> localDataVersion() async => localDataVersionValue;

  @override
  Future<RuleConfig> ruleConfig() async => RuleConfig.standard;

  @override
  Future<MasterImportOutcome> import({
    required covariant Object location,
    required String appVersion,
    required covariant Object settings,
    required DateTime now,
    Object? settingsRecoveredFrom,
  }) =>
      throw UnimplementedError('★取り込みは起動ゲートでのみ走る（決定 D56）');
}
