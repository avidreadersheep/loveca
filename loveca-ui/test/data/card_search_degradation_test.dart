/// ★★ M3 の本命テスト — 縮退が「実際に起きる」入力で固定する ★★
///
/// D-10 の教訓:
/// > 検知手段を書いたら必ず「見つかるはずのもの」を仕込んで動かす。
/// > 0 件は「無い」と「見えていない」の区別がつかない。
///
/// M3 は**縮退を見せる**マイルストーンなので、**見せる仕組み自体が同じ罠に落ちうる。**
/// フェイクに `truncated: true` を返させるテストは配線しか見ていない。
/// ここでは実 DB（本番と同じ `openAppDatabase` / 決定 D45）に対して
///
/// - `limit` を下げて**本当に打ち切り**（決定 D50）
/// - 2 文字の語で**本当に `likeFallback` へ落ち**（決定 D40）
/// - `deleteExpansion` で**本当に孤児を作る**（D-8 / 決定 D63）
///
/// を起こし、`CardBrowseStore` の縮退に出ることを確かめる。
///
/// ★★ 「起きない入力で出ないこと」も必ず対で固定する ★★
/// 出る側だけ見ると、**常に出す実装**でも通ってしまう。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_ui/src/data/app_database.dart';
import 'package:loveca_ui/src/data/card_catalog_repository.dart';
import 'package:loveca_ui/src/data/card_list_row.dart';
import 'package:loveca_ui/src/data/repository_exception.dart';
import 'package:loveca_ui/src/data/search_limit.dart';
import 'package:loveca_ui/src/state/card_browse_store.dart';
import 'package:loveca_ui/src/state/search_degradation.dart';
import 'package:loveca_ui/src/state/store.dart';
import 'package:path/path.dart' as p;

/// 3 文字以上あるので trigram 経路に乗る語。
const String _trigramWord = 'スクールアイドル';

/// bp1 に入れるカード。★[_trigramWord] を効果に持つので同じ語で全部当たる。
CardSet _mainSet() => CardSet(
      expansion: 'bp1',
      cards: [
        for (var i = 1; i <= 5; i++)
          Card(
            cardNumber: 'BP1-00$i',
            name: 'メンバー$i',
            cardType: CardType.member,
            effectText: '$_trigramWord を応援する。',
          ),
        // ★2 文字の語（花帆）と 3 文字以上の語（花帆さん）の両方が当たる。
        //   likeFallback が「出る／出ない」を同じデータで対にするために要る。
        const Card(
          cardNumber: 'BP1-100',
          name: '花帆さんの応援',
          cardType: CardType.live,
        ),
      ],
      printings: [
        for (var i = 1; i <= 5; i++)
          Printing(
            printingId: 'BP1-00$i-N',
            cardNumber: 'BP1-00$i',
            expansion: 'bp1',
            rarity: 'N',
            isParallel: false,
          ),
        const Printing(
          printingId: 'BP1-100-N',
          cardNumber: 'BP1-100',
          expansion: 'bp1',
          rarity: 'N',
          isParallel: false,
        ),
      ],
    );

/// bp2 に入れるカード。★この商品を消すと孤児になる（D-8）。
CardSet _doomedSet() => CardSet(
      expansion: 'bp2',
      cards: const [
        Card(
          cardNumber: 'BP2-001',
          name: '消える商品のカード',
          cardType: CardType.member,
          effectText: '$_trigramWord を応援する。',
        ),
      ],
      printings: const [
        Printing(
          printingId: 'BP2-001-N',
          cardNumber: 'BP2-001',
          expansion: 'bp2',
          rarity: 'N',
          isParallel: false,
        ),
      ],
    );

void main() {
  late Directory tmp;
  late LovecaDatabase db;
  late CardCatalogRepository repository;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('loveca_search_test');
    // ★本番と同じ経路で開く。テストだけ別経路にすると、決定 D45 が
    //   本経路で成立することがテストからは検証されない状態になる。
    db = await openAppDatabase(File(p.join(tmp.path, 'loveca.db')));
    repository = CardCatalogRepository(db);
    await CardDao(db).replaceExpansion(_mainSet());
  });

  tearDown(() async {
    try {
      await db.close();
    } on Object catch (_) {
      // 既に閉じているテストがある。
    }
    // ★Windows は開いたままだと消せない。
    tmp.deleteSync(recursive: true);
  });

  /// 実 DB の投影行から Store を組む。★本番と同じ組み立て。
  Future<CardBrowseStore> storeFor({
    SearchLimitSetting searchLimit = SearchLimitSetting.standard,
  }) async {
    final store = CardBrowseStore(
      rows: await repository.loadListRows(),
      catalog: repository,
      searchLimit: searchLimit,
    );
    addTearDown(store.dispose);
    return store;
  }

  group('前提（仕込みが効いていること）', () {
    test('★同じ語に複数のカードが当たる。当たらなければ以降が無意味', () async {
      final result =
          await repository.search(_trigramWord, limit: CardSearchDao.defaultLimit);
      expect(result.mode, CardSearchMode.trigram);
      expect(result.cardNumbers.length, greaterThan(1),
          reason: '打ち切りを起こすには 2 件以上当たる必要がある');
    });
  });

  group('★打ち切り（決定 D50）', () {
    test('limit を下げると実際に打ち切られ、縮退に出る', () async {
      final store = await storeFor(
        searchLimit: resolveSearchLimit('1'),
      );
      await store.search(_trigramWord);

      final truncated = store.value.degradations.whereType<SearchTruncated>();
      expect(truncated, hasLength(1), reason: '実際に打ち切られている');
      expect(truncated.first.shown, 1);
      expect(truncated.first.limit, 1);
      expect(truncated.first.limitOverridden, isTrue);
    });

    test('★上限が十分なら打ち切りは起きない（出ない側）', () async {
      final store = await storeFor();
      await store.search(_trigramWord);

      expect(store.value.degradations.whereType<SearchTruncated>(), isEmpty,
          reason: '出る側だけ見ると「常に出す」実装でも通ってしまう');
      expect(store.value.visible, isA<Ready<List<CardListRow>>>());
    });
  });

  group('★経路の切り替え（決定 D40）', () {
    test('2 文字は実際に likeFallback へ落ち、縮退に出る', () async {
      final store = await storeFor();
      await store.search('花帆');

      final result = await repository.search('花帆',
          limit: CardSearchDao.defaultLimit);
      expect(result.mode, CardSearchMode.likeFallback,
          reason: '仕込みが効いていること自体をまず確かめる');
      expect(result.cardNumbers, contains('BP1-100'));

      expect(store.value.degradations.whereType<SearchLikeFallback>(),
          hasLength(1));
      expect(store.value.visibleCount, greaterThan(0),
          reason: 'LIKE 経路でも当たること。0 件なら D40 の目的が果たせていない');
    });

    test('★3 文字以上では出ない（出ない側）', () async {
      final store = await storeFor();
      await store.search('花帆さん');

      final result = await repository.search('花帆さん',
          limit: CardSearchDao.defaultLimit);
      expect(result.mode, CardSearchMode.trigram);

      expect(store.value.degradations.whereType<SearchLikeFallback>(), isEmpty);
      expect(store.value.visibleCount, greaterThan(0));
    });
  });

  group('★刷りの無いカード（D-8 / 決定 D63）', () {
    test('deleteExpansion で実際に孤児を作ると、表示できない件数が出る', () async {
      await CardDao(db).replaceExpansion(_doomedSet());

      // ★★ 孤児をここで実際に作る ★★
      // deleteExpansion は printings だけを消し、cards と card_search を残す
      // （`card_dao.dart:80-83` / D-8）。deleteOrphanCards は本番から呼ばれていない。
      await CardDao(db).deleteExpansion('bp2');

      // 仕込みが効いていることを先に確かめる。
      final result = await repository
          .search(_trigramWord, limit: CardSearchDao.defaultLimit);
      expect(result.cardNumbers, contains('BP2-001'),
          reason: '検索は「存在しない刷りの cardNumber」を返しうる（D-8 の実在）');

      final store = await storeFor();
      await store.search(_trigramWord);

      final missing = store.value.degradations.whereType<SearchMissingCards>();
      expect(missing, hasLength(1));
      expect(missing.first.count, 1);

      // ★一覧（printings JOIN cards）には出てこない。だから黙ると気づけない。
      expect(
        store.value.all.where((r) => r.cardNumber == 'BP2-001'),
        isEmpty,
      );
    });

    test('★孤児が無ければ出ない（出ない側）', () async {
      await CardDao(db).replaceExpansion(_doomedSet());
      // ★消さない。刷りがあるので孤児にならない。

      final store = await storeFor();
      await store.search(_trigramWord);

      expect(store.value.degradations.whereType<SearchMissingCards>(), isEmpty);
    });
  });

  group('失敗は 0 件にすり替えない（決定 D53）', () {
    test('DB が閉じていれば RepositoryException が届く', () async {
      await db.close();

      await expectLater(
        repository.search(_trigramWord, limit: 10),
        throwsA(isA<RepositoryException>()
            .having((e) => e.op, 'op', 'cardCatalog.search')),
      );
    });

    test('Store は Failed になり、Ready の空リストにならない', () async {
      final store = await storeFor();
      await db.close();
      await store.search(_trigramWord);

      expect(store.value.visible, isA<Failed<List<CardListRow>>>());
      expect(store.value.visibleCount, isNull,
          reason: '「0 件だった」と読める値を出さない');
    });
  });
}
