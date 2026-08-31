/// 配信 JSON をローカル DB へ流し込む.
///
/// ★`loveca_core` の `planUpdate` をそのまま使う★
/// 差分の判断（何を取り、何を消すか）はドメイン層の純粋関数の仕事であり、
/// ここに再実装しない。この層がやるのは
/// 「計画に従って読み、パースし、書き、結果を記録する」だけ。
library;

import 'package:drift/drift.dart';
import 'package:loveca_core/loveca_core.dart';

import '../dao/card_dao.dart';
import '../dao/master_state_dao.dart';
import '../schema/database.dart';
import '../schema/enums.dart';
import '../schema/tables.dart';
import 'master_file_source.dart';

class MasterImportResult {
  const MasterImportResult({
    required this.decision,
    required this.dataVersion,
    required this.dataVersionAdvanced,
    this.importedPaths = const [],
    this.skippedPaths = const [],
    this.deletedPaths = const [],
    this.unhandledPaths = const [],
    this.failedPaths = const [],
  });

  final UpdateDecision decision;

  /// 反映後の `master_state.data_version`。
  final int dataVersion;

  /// ★全ファイル成功時のみ真★
  /// 1 件でも失敗が残っているうちは旧 `data_version` を保持する。
  final bool dataVersionAdvanced;

  final List<String> importedPaths;

  /// ハッシュが一致したので**読みにすら行かなかった**ファイル。
  final List<String> skippedPaths;

  final List<String> deletedPaths;

  /// このバージョンの取り込み層が知らない path。
  ///
  /// ★黙って捨てない★ 呼び出し側へ返して見えるようにする。
  /// 将来 `meta/` に新しいファイルが増えても取り込みが止まらないよう、
  /// ハッシュは記録して再取得を繰り返さないようにしてある。
  final List<String> unhandledPaths;

  final List<String> failedPaths;

  bool get hasFailures => failedPaths.isNotEmpty;
}

class MasterImporter {
  const MasterImporter(this.db);

  final LovecaDatabase db;

  /// 差分取り込みを行う。
  ///
  /// [now] は呼び出し側から渡す。層の内側で `DateTime.now()` を呼ばない。
  Future<MasterImportResult> import({
    required VersionInfo remoteVersion,
    required Manifest remoteManifest,
    required MasterFileSource source,
    required String appVersion,
    required DateTime now,
  }) async {
    final state = MasterStateDao(db);
    final localDataVersion = await state.localDataVersion();

    final plan = planUpdate(
      remoteVersion: remoteVersion,
      remoteManifest: remoteManifest,
      appVersion: appVersion,
      localDataVersion: localDataVersion,
      localFileHashes: await state.localFileHashes(),
    );

    if (plan.decision != UpdateDecision.update) {
      return MasterImportResult(
        decision: plan.decision,
        dataVersion: localDataVersion,
        dataVersionAdvanced: false,
        skippedPaths: remoteManifest.files.map((f) => f.path).toList(),
      );
    }

    final toDownload = {for (final f in plan.filesToDownload) f.path};
    final imported = <String>[];
    final failed = <String>[];
    final unhandled = <String>[];

    for (final file in plan.filesToDownload) {
      final outcome = await _importFile(file, source, state, now);
      switch (outcome) {
        case _Outcome.imported:
          imported.add(file.path);
        case _Outcome.unhandled:
          unhandled.add(file.path);
        case _Outcome.failed:
          failed.add(file.path);
      }
    }

    for (final path in plan.filesToDelete) {
      await _deletePath(path);
      await state.forgetFile(path);
    }

    // ★マニフェスト内の全ファイルが揃ったときにだけ data_version を上げる★
    // ★理由の正は `MasterStateDao.setVersion` の doc に置いてある。
    //   ★2026-08-31 に理由が 1 つ消えた（決定 D118-3 = 版-3 / 所見 D-32）が、
    //     規約そのものは変えていない。
    final complete = await _allFilesPresent(remoteManifest, state);
    if (complete) await state.setVersion(remoteVersion);

    return MasterImportResult(
      decision: plan.decision,
      dataVersion:
          complete ? remoteVersion.dataVersion : localDataVersion,
      dataVersionAdvanced: complete,
      importedPaths: imported,
      skippedPaths: remoteManifest.files
          .map((f) => f.path)
          .where((p) => !toDownload.contains(p))
          .toList(),
      deletedPaths: plan.filesToDelete,
      unhandledPaths: unhandled,
      failedPaths: failed,
    );
  }

  Future<bool> _allFilesPresent(
    Manifest manifest,
    MasterStateDao state,
  ) async {
    final local = await state.localFileHashes();
    return manifest.files.every((f) => local[f.path] == f.hash);
  }

  /// ★商品ファイル 1 件を隔離して取り込む（決定 D39）★
  ///
  /// `HeartColor.fromKey` / `BladeHeartEffect.fromKey` / `CardType.fromJa` は
  /// 未知のキーで `ArgumentError` を投げる（D-1）。この厳格さは契約として正しく、
  /// **`loveca_core` 側は一切変えない。** D-1 は判断時期を Phase 4 と定めており、
  /// ここで寛容化すると前倒しになる。
  ///
  /// 代わりにファイル単位で隔離する。
  ///
  /// - 失敗しても**ハッシュを記録しない** → 次回の計画で再取得対象に残る
  /// - 失敗しても**既存の行は消さない** → 前回取り込めた内容で動き続ける
  /// - `import_issues` に残す → 黙って捨てない（A-3 と同じ失敗の型を避ける）
  Future<_Outcome> _importFile(
    ManifestFile file,
    MasterFileSource source,
    MasterStateDao state,
    DateTime now,
  ) async {
    String content;
    try {
      content = await source.read(file.path);
    } on Object catch (error) {
      await state.recordIssue(
        path: file.path,
        hash: file.hash,
        kind: ImportIssueKind.readFailure,
        message: '$error',
        at: now,
      );
      return _Outcome.failed;
    }

    try {
      final handled = await _apply(file.path, content);
      if (!handled) {
        // 未対応の path。ハッシュは記録して再取得を繰り返さないようにし、
        // 事実は結果に載せて呼び出し側へ返す。
        await state.recordFile(file, now);
        return _Outcome.unhandled;
      }
    } on ArgumentError catch (error) {
      // ★fromKey / fromJa の契約違反。配信側が新しいキーを足した場合にここへ来る。
      await state.recordIssue(
        path: file.path,
        hash: file.hash,
        kind: ImportIssueKind.unknownKey,
        message: '$error',
        at: now,
      );
      return _Outcome.failed;
    } on Object catch (error) {
      await state.recordIssue(
        path: file.path,
        hash: file.hash,
        kind: ImportIssueKind.parseFailure,
        message: '$error',
        at: now,
      );
      return _Outcome.failed;
    }

    await state.recordFile(file, now);
    return _Outcome.imported;
  }

  /// 取り込めたら真、未対応の path なら偽。
  Future<bool> _apply(String path, String content) async {
    if (path.startsWith('cards/')) {
      // ★パースを先に済ませてから書く★
      // 途中で例外が出ても既存の行に手が付いていない状態で止まる。
      final set = CardSet.parse(content);
      await CardDao(db).replaceExpansion(set);
      return true;
    }

    switch (path) {
      case 'meta/products.json':
        final products = MasterMeta.parseProducts(content);
        await db.transaction(() async {
          await db.delete(db.products).go();
          await db.batch((batch) {
            batch.insertAll(db.products, [
              for (final p in products)
                ProductsCompanion.insert(
                  expansionId: p.expansionId,
                  name: Value(p.name),
                  releaseDate: Value(p.releaseDate),
                  slug: Value(p.slug),
                  url: Value(p.url),
                ),
            ]);
          });
        });
        return true;

      case 'meta/faqs.json':
        final faqs = MasterMeta.parseFaqs(content);
        await db.transaction(() async {
          await db.delete(db.faqPrintings).go();
          await db.delete(db.faqs).go();
          await db.batch((batch) {
            batch.insertAll(db.faqs, [
              for (final q in faqs)
                FaqsCompanion.insert(
                  qaId: q.qaId,
                  faqId: Value(q.faqId),
                  question: Value(q.question),
                  answer: Value(q.answer),
                  registTime: Value(q.registTime),
                  updateTime: Value(q.updateTime),
                ),
            ]);
            batch.insertAll(db.faqPrintings, [
              for (final q in faqs)
                // ★Faq.cardNumbers の中身は cardNumber ではなく printingId。
                for (final printingId in q.cardNumbers)
                  FaqPrintingsCompanion.insert(
                    qaId: q.qaId,
                    printingId: printingId,
                  ),
            ]);
          });
        });
        return true;

      case 'meta/ruleConfig.json':
        final config = MasterMeta.parseRuleConfig(content);
        await db.into(db.ruleConfigs).insertOnConflictUpdate(
              RuleConfigsCompanion.insert(
                // ★単一行テーブルなので id を明示する（tables.dart の注記）。
                id: const Value(singletonRowId),
                mainDeckSize: config.mainDeckSize,
                memberCount: config.memberCount,
                liveCount: config.liveCount,
                energyDeckSize: config.energyDeckSize,
                maxCopiesPerCardNumber: config.maxCopiesPerCardNumber,
                initialHandSize: config.initialHandSize,
                initialEnergyOnField: config.initialEnergyOnField,
                liveSlotMax: config.liveSlotMax,
                winCondition: config.winCondition,
                stageAreaCount: config.stageAreaCount,
              ),
            );
        return true;
    }

    return false;
  }

  Future<void> _deletePath(String path) async {
    if (!path.startsWith('cards/')) return;
    final expansion =
        path.substring('cards/'.length).replaceAll('.json', '');
    await CardDao(db).deleteExpansion(expansion);
  }
}

enum _Outcome { imported, unhandled, failed }
