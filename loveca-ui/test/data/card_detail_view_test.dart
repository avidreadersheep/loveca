/// カード詳細の材料（R5 / 決定 D55 / M5）.
///
/// ★★ ここで見るのは「カタログから正しく引けること」だけ ★★
/// 画面の見た目は `test/ui/card_detail_test.dart`。役割を混ぜない。
///
/// ★fixture は実データから写したもの（`test/support/real_shaped_catalog.dart`）。
/// 作り話のカード 1 枚で通るテストにしない（M4 の教訓）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/data/card_detail.dart';

import '../support/real_shaped_catalog.dart';

void main() {
  final view = CardDetailView(realShapedCatalog());

  group('刷りとカードを結びつける（決定 D11 の 2 階層）', () {
    test('printingId から カード + 刷り が引ける', () {
      final detail = view.of(trioMemberPrinting)!;

      expect(detail.printing.printingId, trioMemberPrinting);
      expect(detail.card.cardNumber, 'LL-bp1-001');
      expect(detail.card.cardType, CardType.member);
      expect(detail.printing.rarity, 'R+');
      expect(detail.printing.illustrator, 'オペラハウス');
    });

    test('★実データの多様性が落ちていない（複数キャラ名 / 複数グループ名）', () {
      // 総合ルール 2.3.2.1 / 2.4.2.1。実データで 6 種しかない形。
      final card = view.of(trioMemberPrinting)!.card;

      expect(card.characterNames, ['上原歩夢', '澁谷かのん', '日野下花帆']);
      expect(card.groupNames, ['虹ヶ咲', 'Liella!', '蓮ノ空']);
    });
  });

  group('★★ 同じ cardNumber の刷り（siblings）★★', () {
    test('自分を含み、printingId 昇順で並ぶ', () {
      final detail = view.of(parallelMemberNormal)!;

      expect(
        detail.siblings.map((p) => p.printingId),
        [
          parallelMemberParallel, // -P
          parallelMemberNormal, // -R
          parallelMemberOtherProduct, // -RM
        ],
      );
      expect(detail.hasOtherPrintings, isTrue);
    });

    test('★ほかの cardNumber の刷りは混ざらない', () {
      final detail = view.of(parallelMemberNormal)!;

      expect(
        detail.siblings.every((p) => p.cardNumber == 'PL!HS-bp1-002'),
        isTrue,
      );
    });

    test('★通常刷りが 1 枚とは限らない前提を壊していない（CLAUDE.md §5-(4)）', () {
      // 「代表 1 枚」は誤りとして廃止済み。パラレルかどうかは刷りの属性。
      final detail = view.of(parallelMemberNormal)!;

      expect(
        {for (final p in detail.siblings) p.printingId: p.isParallel},
        {
          parallelMemberParallel: true,
          parallelMemberNormal: false,
          parallelMemberOtherProduct: true,
        },
      );
      // ★同じ cardNumber でも商品はまたぐ（再録）。
      expect(
        detail.siblings.map((p) => p.expansion).toSet(),
        {'BP01', 'BP05'},
      );
    });

    test('刷りが 1 つなら hasOtherPrintings は false（出ない側）', () {
      expect(view.of(drawLivePrinting)!.hasOtherPrintings, isFalse);
      expect(view.of(drawLivePrinting)!.siblings, hasLength(1));
    });
  });

  group('★★ 見つからないときは null（空の詳細を作らない）★★', () {
    // ★★ この経路は「いま」UI から到達しない ★★
    //   R3 / R4 の一覧セルは MasterCatalog.rows（printings JOIN cards）から
    //   作られるので、必ずカタログに在る printingId しか渡ってこない。
    //
    // ★★ それでも残す理由（消してよいかの判断材料）★★
    //   到達させる予定のある経路が 2 つある。
    //   1. Phase 4（同期）: 他端末が新しいマスタで作ったデッキが降ってくる。
    //      Deck.masterDataVersion（決定 D35）と決定 D35 はまさにこれを検出するためにあり、
    //      M4 のデッキペインは未知の刷りを「表示できないカード」として出している。
    //      **そこから詳細を開けるようにした瞬間に到達する。**
    //   2. M6（共有形式インポート / 設計メモ §2-5）: cardNumber → printingId の
    //      逆写像が一意でなく、マスタに無い cardNumber もありうる。
    //
    //   → **消してよいのは上の 2 つが「未知の printingId を持ち込まない」と
    //     確定したときだけ。** どちらも未決なので残す（「念のため」ではない）。
    test('カタログに無い printingId は null', () {
      expect(view.of('存在しない刷り'), isNull);
    });

    test('★空文字でも落ちない', () {
      expect(view.of(''), isNull);
    });
  });

  group('★ 種別ごとに埋まるフィールドが違う（実データの形）', () {
    test('メンバー: cost / bladeCount / hearts があり、score は無い', () {
      final card = view.of(parallelMemberNormal)!.card;

      expect(card.cost, 11);
      expect(card.bladeCount, 2);
      expect(card.score, isNull);
      expect(card.hearts, isNotEmpty);
      expect(card.requiredHearts, isEmpty);
      // ★実データの hearts に ALL / GRAY は 1 件も無い（6 色のみ）。
      expect(
        card.hearts.keys.every(HeartColor.sixColors.contains),
        isTrue,
      );
    });

    test('ライブ: score / requiredHearts があり、cost は無い', () {
      final card = view.of(drawLivePrinting)!.card;

      expect(card.score, 5);
      expect(card.cost, isNull);
      expect(card.requiredHearts[HeartColor.gray], 6);
      expect(card.requiredHeartTotal, 12);
    });

    test('★★ エネルギーは全フィールドが空（グループ名すら空）★★', () {
      // 実データの 567 種すべてがこの形。詳細画面はこれで壊れて見えてはいけない。
      final card = view.of(energyPrinting)!.card;

      expect(card.cardType, CardType.energy);
      expect(card.characterNames, ['高坂穂乃果']);
      expect(card.groupNames, isEmpty);
      expect(card.unitNames, isEmpty);
      expect(card.effectText, isEmpty);
      expect(card.keywords, isEmpty);
      expect(card.cost, isNull);
      expect(card.bladeCount, isNull);
      expect(card.score, isNull);
      expect(card.hearts, isEmpty);
      expect(card.requiredHearts, isEmpty);
      expect(card.bladeHearts, isEmpty);
      expect(card.bladeHeartEffects, isEmpty);
    });
  });

  group('★★ 色ハートと非色アイコンは別の入れ物のまま（CLAUDE.md §6）★★', () {
    test('DRAW を持つライブでも bladeHearts は色だけ', () {
      final card = view.of(drawLivePrinting)!.card;

      // 8.3.14 のハート合計に合算するのはこちら。
      expect(card.bladeHearts, {HeartColor.blue: 1});
      // 8.3.12.1 のドロー。★合算しない。
      expect(card.bladeHeartEffects, {BladeHeartEffect.draw: 1});
    });

    test('SCORE は bladeHearts に混ざらない', () {
      final card = view.of(scoreLivePrinting)!.card;

      expect(card.bladeHearts, isEmpty);
      expect(card.bladeHeartEffects, {BladeHeartEffect.score: 1});
    });

    test('ALL は色の側（2.1.1.3）', () {
      final card = view.of(allBladeLivePrinting)!.card;

      expect(card.bladeHearts, {HeartColor.all: 1});
      expect(card.bladeHeartEffects, isEmpty);
    });
  });

  test('★ imageHash が空のカタログも組める（`build --skip-images` / §5-2(4)）', () {
    final stripped = CardDetailView(realShapedCatalogWithoutImages());

    expect(stripped.of(trioMemberPrinting)!.printing.imageHash, isEmpty);
    // ★ほかの情報は落ちない。落ちるのは絵だけ。
    expect(stripped.of(trioMemberPrinting)!.card.characterNames, hasLength(3));
  });
}
