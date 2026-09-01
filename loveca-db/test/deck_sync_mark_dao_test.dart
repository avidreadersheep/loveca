/// 前回同期時点の器の読み書き —— ★★§32-6 の **23** の一部（決定 **D114-1** / **D140-1**）.
///
/// ★★ この版で固定するのは「器を引く経路」だけである ★★
/// ★**送信も判定も解決も無い。**★**呼ぶ側が★今日 1 人も居ない。**
/// → ★**それらを固定するテストを書かない。**★書くと決めたことになる。
///
/// ★★ 「決めていないこと」を型で決めないための対も置く ★★
/// (1) ★**目印そのものを外へ出さない**（★有無に畳む / **D140-1** を呼ぶ側へ漏らさない）/
/// (2) ★**`decks` を 1 度も触らない**（**D114-4** の 3）/
/// (3) ★**ログには触れない**（**N-16** は別の問いである）。
library;

import 'package:drift/drift.dart' show Value;
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_db/native.dart';
import 'package:test/test.dart';

void main() {
  late LovecaDatabase db;

  const deckId = 'deck-sync-mark';
  const otherDeckId = 'deck-other';
  const hash = 'sha256:'
      '1111111111111111111111111111111111111111111111111111111111111111';

  Future<int> addOp(String id, {DeckEditOpKind kind = DeckEditOpKind.setName}) =>
      db.into(db.deckEditOps).insert(
            DeckEditOpsCompanion.insert(
              deckId: id,
              kind: kind.key,
              at: DateTime.utc(2026, 9, 2),
            ),
          );

  setUp(() async {
    db = LovecaDatabase(openInMemoryExecutor());
    await db.customSelect('SELECT 1').get();
  });

  tearDown(() => db.close());

  group('★★ 行が無い ＝ まだ一度も同期していない（決定 D114-3）★★', () {
    test('★ `null` を返す', () async {
      expect(await DeckSyncMarkDao(db).baselineFor(deckId), isNull);
    });

    test('★★ 対: ログが在っても★行が無ければ `null` である ★★', () async {
      // ★★ ログの有無と★器の行の有無を混ぜない ★★
      //   ★**行の不在は「まだ一度も同期していない」であって「操作が無い」ではない。**
      await addOp(deckId);

      expect(await DeckSyncMarkDao(db).baselineFor(deckId), isNull);
    });
  });

  group('★★ 目印は「最後に送った操作の id」である（決定 D140-1 ＝ 印-1）★★', () {
    test('★★ 目印より後ろに操作が在れば `hasOpsSinceMark` が真 ★★', () async {
      final first = await addOp(deckId);
      await DeckSyncMarkDao(db)
          .record(deckId: deckId, logMark: first, baselineHash: hash);
      await addOp(deckId);

      final got = await DeckSyncMarkDao(db).baselineFor(deckId);

      expect(got, isNotNull);
      expect(got!.hasOpsSinceMark, isTrue);
      expect(got.contentHash, hash);
    });

    test('★★ 目印そのものの操作は★「後ろ」に数えない（★★印-1 と 印-2 を分ける 1 件★★）★★',
        () async {
      // ★★ これが **D140-1** の実物である ★★
      //   ★**印-2（次に送る）なら `id >= mark` なので、★★この 1 件で真になる★★。**
      final only = await addOp(deckId);
      await DeckSyncMarkDao(db)
          .record(deckId: deckId, logMark: only, baselineHash: hash);

      final got = await DeckSyncMarkDao(db).baselineFor(deckId);

      expect(got!.hasOpsSinceMark, isFalse);
    });

    test('★★ 対: 目印を 1 つ下げれば★真になる（★走査そのものが効いていること）★★',
        () async {
      final only = await addOp(deckId);
      await DeckSyncMarkDao(db)
          .record(deckId: deckId, logMark: only - 1, baselineHash: hash);

      final got = await DeckSyncMarkDao(db).baselineFor(deckId);

      expect(got!.hasOpsSinceMark, isTrue);
    });

    test('★★ 別のデッキの操作は★数えない ★★', () async {
      final mine = await addOp(deckId);
      await DeckSyncMarkDao(db)
          .record(deckId: deckId, logMark: mine, baselineHash: hash);
      // ★★ 別のデッキに★あとから 1 件足す（★id は大きくなる）★★
      await addOp(otherDeckId);

      final got = await DeckSyncMarkDao(db).baselineFor(deckId);

      expect(got!.hasOpsSinceMark, isFalse,
          reason: '★★デッキで絞っていない ＝ 他のデッキの編集で同期が起きる★★');
    });
  });

  group('★★ 目印に書くべき値（`latestLogMark`）★★', () {
    test('★★ ログが 1 件も無ければ 0 である ★★', () async {
      // ★★ `create` / `duplicate` はログを 1 件も残さない（★事実 16）★★
      expect(await DeckSyncMarkDao(db).latestLogMark(deckId), 0);
    });

    test('★★ 0 を書けば★どの操作も「後ろ」になる（★上の 0 が使える値であること）★★',
        () async {
      await addOp(deckId);
      await DeckSyncMarkDao(db)
          .record(deckId: deckId, logMark: 0, baselineHash: hash);

      final got = await DeckSyncMarkDao(db).baselineFor(deckId);

      expect(got!.hasOpsSinceMark, isTrue);
    });

    test('★ 最後の id を返す', () async {
      await addOp(deckId);
      final second = await addOp(deckId);

      expect(await DeckSyncMarkDao(db).latestLogMark(deckId), second);
    });

    test('★★ 対: 別のデッキの id を返さない ★★', () async {
      final mine = await addOp(deckId);
      await addOp(otherDeckId);

      expect(await DeckSyncMarkDao(db).latestLogMark(deckId), mine);
    });

    test('★★ 書いた直後は★「後ろ」が空である（★★往復させて確かめる★★）★★', () async {
      await addOp(deckId);
      await addOp(deckId);
      final dao = DeckSyncMarkDao(db);

      await dao.record(
        deckId: deckId,
        logMark: await dao.latestLogMark(deckId),
        baselineHash: hash,
      );

      expect((await dao.baselineFor(deckId))!.hasOpsSinceMark, isFalse);
    });
  });

  group('★★ 書き込み（決定 D114-1 / D114-4）★★', () {
    test('★★ 2 度目は上書きする（★行は 1 つのままである）★★', () async {
      final dao = DeckSyncMarkDao(db);
      await dao.record(deckId: deckId, logMark: 1, baselineHash: hash);
      await dao.record(deckId: deckId, logMark: 9, baselineHash: 'sha256:zz');

      final rows = await db.select(db.deckSyncMarks).get();

      expect(rows, hasLength(1));
      expect(rows.single.logMark, 9);
      expect(rows.single.baselineHash, 'sha256:zz');
    });

    test('★★ `decks` を 1 度も触らない（決定 D114-4 の 3）★★', () async {
      // ★★ 器への書き込みが `decks` に触れないことが★この表を選んだ根拠の 1 つである ★★
      await DeckDao(db).save(
        Deck(
          deckId: deckId,
          name: 'なまえ',
          entries: const [],
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 2),
          revision: 3,
        ),
        ops: const [],
      );

      await DeckSyncMarkDao(db)
          .record(deckId: deckId, logMark: 0, baselineHash: hash);

      final restored = await DeckDao(db).byId(deckId);
      expect(restored!.updatedAt, DateTime.utc(2026, 1, 2));
      expect(restored.revision, 3);
    });

    test('★★ ログに 1 件も足さない（★★N-16 は別の問いである★★）★★', () async {
      await addOp(deckId);

      await DeckSyncMarkDao(db)
          .record(deckId: deckId, logMark: 0, baselineHash: hash);

      expect(await db.select(db.deckEditOps).get(), hasLength(1));
    });
  });

  group('★★ 行を消して「まだ一度も同期していない」に戻す（決定 D119-5 ＝ 失-1）★★', () {
    test('★ 消すと `null` に戻る', () async {
      final dao = DeckSyncMarkDao(db);
      await dao.record(deckId: deckId, logMark: 1, baselineHash: hash);

      await dao.forget(deckId);

      expect(await dao.baselineFor(deckId), isNull);
    });

    test('★★ ログには触れない（★★新しい状態を 1 つも作らない★★）★★', () async {
      final dao = DeckSyncMarkDao(db);
      await addOp(deckId);
      await dao.record(deckId: deckId, logMark: 1, baselineHash: hash);

      await dao.forget(deckId);

      expect(await db.select(db.deckEditOps).get(), hasLength(1));
    });

    test('★★ 対: 別のデッキの行は残る ★★', () async {
      final dao = DeckSyncMarkDao(db);
      await dao.record(deckId: deckId, logMark: 1, baselineHash: hash);
      await dao.record(deckId: otherDeckId, logMark: 2, baselineHash: hash);

      await dao.forget(deckId);

      final rows = await db.select(db.deckSyncMarks).get();
      expect(rows, hasLength(1));
      expect(rows.single.deckId, otherDeckId);
    });
  });

  group('★★ 決めていないことを型で決めない ★★', () {
    test('★★ 目印そのものを外へ出さない（★有無に畳む）★★', () async {
      // ★★ **D140-1** の値の意味を★呼ぶ側へ漏らさない ★★
      //   ★**`DeckSyncBaseline` が持つのは `hasOpsSinceMark` と `contentHash` の 2 つだけである。**
      //   ★**この期待値が増えたら「何かを決めた」はずである。★黙って増やさないこと。**
      await DeckSyncMarkDao(db)
          .record(deckId: deckId, logMark: 42, baselineHash: hash);

      final got = await DeckSyncMarkDao(db).baselineFor(deckId);

      expect(got, isA<DeckSyncBaseline>());
      expect(got!.contentHash, hash);
      // ★★ 目印の値そのものは★この型のどこにも無い ★★
      expect(got.hasOpsSinceMark, isFalse);
    });

    test('★★ 判定を呼ばない（★段が違う）★★', () async {
      // ★★ 判定は `loveca_core` の純粋関数である（**D111-2**）★★
      //   ★**DAO は★引いて畳むだけで、★★答えを 1 つも出さない★★。**
      final dao = DeckSyncMarkDao(db);
      await dao.record(deckId: deckId, logMark: 0, baselineHash: hash);

      final baseline = await dao.baselineFor(deckId);
      final judgement = judgeDeckConflict(
        baseline: baseline,
        localContentHash: hash,
        remoteContentHash: hash,
      );

      expect(judgement.verdict, DeckConflictVerdict.unchanged,
          reason: '★★判定は★呼ぶ側が★別に行う★★');
    });
  });

  group('★★ 器の行と★同定の量は★別である（決定 D125-9）★★', () {
    test('★★ 器はデッキごと。★同定は DB 全体で 1 つ ★★', () async {
      // ★★ 2 つを混ぜない（★§32-6 の 19 と 22 は別のコミットである）★★
      await DeckSyncMarkDao(db)
          .record(deckId: deckId, logMark: 0, baselineHash: hash);
      await db.into(db.syncIdentities).insert(
          SyncIdentitiesCompanion.insert(
              id: const Value(0), userName: 'みつき'));

      expect(await db.select(db.deckSyncMarks).get(), hasLength(1));
      expect(await db.select(db.syncIdentities).get(), hasLength(1));
    });
  });
}
