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
import 'master_image_sink.dart';

/// 配信物のうち画像の path かどうか。
///
/// ★★ 前置で分ける (決定 D121-1 の代償への受け皿) ★★
/// カードとメタは `cards/` `meta/`、画像は `images/`。
/// 取り込みの振り分けは元から前置で分けているので、同じ機構で切り分く。
bool _isImage(String path) => path.startsWith('images/');

/// 画像の取り込み計画。
///
/// ★`loveca_core` の `planUpdate` に足さない —— 判定の材料が
/// 「取り込み済みのハッシュ」だけで、版ゲートも `dataVersion` も関わらない。
class _ImagePlan {
  const _ImagePlan({this.toWrite = const [], this.toDelete = const []});

  final List<ManifestFile> toWrite;
  final List<String> toDelete;
}

/// 画像の計画を立てる。
///
/// ★★ マニフェストが無ければ 1 件も計画しない ★★
///   ★「まだ無い」と「0 枚である」は別である（決定 D121-1 の生成側と対）。
///   ★空として扱うと、**取り込み済みの画像を全部消せ**という計画になる。
///
/// ★★ 保存先が無くても 1 件も計画しない ★★
///   ★置き場は門 キ（**N-1**）待ちである。★計画だけ立てても置く先が無い。
_ImagePlan _planImages({
  required Manifest? remoteImageManifest,
  required Map<String, String> localImageHashes,
  required bool hasSink,
}) {
  if (remoteImageManifest == null || !hasSink) return const _ImagePlan();

  final remote = remoteImageManifest.byPath;
  return _ImagePlan(
    toWrite: [
      for (final file in remoteImageManifest.files)
        if (localImageHashes[file.path] != file.hash) file,
    ],
    toDelete: [
      for (final path in localImageHashes.keys)
        if (!remote.containsKey(path)) path,
    ]..sort(),
  );
}

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
    Manifest? remoteImageManifest,
    MasterImageSink? imageSink,
  }) async {
    final state = MasterStateDao(db);
    final localDataVersion = await state.localDataVersion();

    // ★★ 画像は別のマニフェストに載る (決定 D121-1 = 画-5) ★★
    //   ★カードの計画に画像の path を混ぜない。混ぜると
    //   `planUpdate` の削除計画が **画像を全部消せ** と言う
    //   （カードのマニフェストには画像の行が 1 つも無いため）。
    final localHashes = await state.localFileHashes();
    final localCardHashes = {
      for (final e in localHashes.entries)
        if (!_isImage(e.key)) e.key: e.value,
    };
    final localImageHashes = {
      for (final e in localHashes.entries)
        if (_isImage(e.key)) e.key: e.value,
    };

    final plan = planUpdate(
      remoteVersion: remoteVersion,
      remoteManifest: remoteManifest,
      appVersion: appVersion,
      localDataVersion: localDataVersion,
      localFileHashes: localCardHashes,
    );

    if (plan.decision != UpdateDecision.update) {
      return MasterImportResult(
        decision: plan.decision,
        dataVersion: localDataVersion,
        dataVersionAdvanced: false,
        skippedPaths: [
          ...remoteManifest.files.map((f) => f.path),
          ...?remoteImageManifest?.files.map((f) => f.path),
        ],
      );
    }

    // ★★ 画像の計画をここで立てる (決定 D121-1 の受け取り側 3／4) ★★
    //   ★`loveca_core` に足さない —— 判定の材料が「取り込み済みの
    //   ハッシュ」だけで、版ゲートも `dataVersion` も関わらない。
    //   ★★保存先が無ければ画像は 1 件も計画しない★★（門 キ / N-1）。
    final imagePlan = _planImages(
      remoteImageManifest: remoteImageManifest,
      localImageHashes: localImageHashes,
      hasSink: imageSink != null,
    );

    final toDownload = {
      for (final f in plan.filesToDownload) f.path,
      for (final f in imagePlan.toWrite) f.path,
    };
    final imported = <String>[];
    final failed = <String>[];
    final unhandled = <String>[];

    for (final file in [...plan.filesToDownload, ...imagePlan.toWrite]) {
      final outcome = await _importFile(file, source, state, now,
          imageSink: imageSink);
      switch (outcome) {
        case _Outcome.imported:
          imported.add(file.path);
        case _Outcome.unhandled:
          unhandled.add(file.path);
        case _Outcome.failed:
          failed.add(file.path);
      }
    }

    for (final path in [...plan.filesToDelete, ...imagePlan.toDelete]) {
      await _deletePath(path, imageSink: imageSink);
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
      skippedPaths: [
        ...remoteManifest.files.map((f) => f.path),
        ...?remoteImageManifest?.files.map((f) => f.path),
      ].where((p) => !toDownload.contains(p)).toList(),
      deletedPaths: [...plan.filesToDelete, ...imagePlan.toDelete],
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
    DateTime now, {
    MasterImageSink? imageSink,
  }) async {
    // ★★ 画像はバイト列で運ぶ (決定 D121-1 = 画-5) ★★
    //   ★テキスト経路に通さない —— WebP は UTF-8 として復号できず、
    //     `dart:io` の実装では **その場で例外になる**（実測）。
    //   ★失敗の記録の仕方はカードと同じにする（決定 D39 の隔離）。
    if (_isImage(file.path)) {
      return _importImage(file, source, state, now, imageSink);
    }

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

  /// 画像 1 件を取り込む。
  ///
  /// ★カードと同じく **隔離** する（決定 D39）——
  /// 1 枚読めなくても他の取り込みは進み、ハッシュを記録しないので
  /// 次回の計画に残る。
  Future<_Outcome> _importImage(
    ManifestFile file,
    MasterFileSource source,
    MasterStateDao state,
    DateTime now,
    MasterImageSink? imageSink,
  ) async {
    // ★保存先が無ければ「未対応」。★今までどおりの扱いである
    //   （置き場は門 キ / N-1 待ち）。
    if (imageSink == null) {
      await state.recordFile(file, now);
      return _Outcome.unhandled;
    }

    List<int> bytes;
    try {
      bytes = await source.readBytes(file.path);
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
      await imageSink.write(file.path, bytes);
    } on Object catch (error) {
      // ★書けなかったのは「解釈できなかった」ではない。
      //   ★それでも隔離の形は同じにする（1 枚で全体を止めない）。
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

  Future<void> _deletePath(String path, {MasterImageSink? imageSink}) async {
    if (_isImage(path)) {
      // ★保存先が無ければ何もしない。★計画も立てていないのでここへ来ない。
      await imageSink?.delete(path);
      return;
    }
    if (!path.startsWith('cards/')) return;
    final expansion =
        path.substring('cards/'.length).replaceAll('.json', '');
    await CardDao(db).deleteExpansion(expansion);
  }
}

enum _Outcome { imported, unhandled, failed }
