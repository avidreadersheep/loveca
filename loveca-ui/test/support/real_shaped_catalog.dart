/// ★★ 実データから写した fixture（M5）★★
///
/// M4 の実機確認で「区分をまたぐと縮退を誤検知する」を拾ったとき、
/// **テストデータが単純すぎて通ってしまっていた**（1 区分だけのデッキで
/// 並べ替えを見ていた）。同じ失敗をしないため、M5 の fixture は
/// **実データの多様性をそのまま写す。**
///
/// ★ここに並ぶ 6 種 / 9 刷りは**すべて実在**する
/// （`loveca-data/data/dist/cards/*.json` から値をそのまま写した）。
/// 作り話のカードを 1 枚置いて通るテストにしない。
///
/// ## 何を代表させているか（2026-08-24 に実データ 1,708 種 / 2,527 刷りを走査）
///
/// | 刷り | 代表するもの | 実データでの希少さ |
/// |---|---|---|
/// | `LL-bp1-001-R+` | **複数キャラ名 3 + 複数グループ名 3**（2.3.2.1 / 2.4.2.1） | ★**6 種しかない** |
/// | `PL!HS-bp1-002-{P,R,RM}` | **同じ cardNumber の 3 刷り**（P / RM がパラレル、★**商品もまたぐ**） | 3 刷り 51 種 / 4 刷り 84 種 |
/// | `PL!HS-bp1-022-L` | ★★**色ブレードハート `{BLUE:1}` と `bladeHeartEffects {DRAW:1}` の同居** | 59 種 |
/// | `PL!HS-bp1-019-{L,SECL}` | **`bladeHeartEffects {SCORE:1}`** + 2 刷り（片方パラレル） | SCORE 37 種 |
/// | `PL!HS-bp1-020-L` | **`bladeHearts {ALL:1}`**（2.1.1.3） | 126 種 |
/// | `PL!-bp1-000-LLE` | ★**エネルギーは全フィールドが空**（groupNames すら空） | 567 種すべて |
///
/// ## 実データで確かめた分布（fixture の形の根拠）
///
/// | 事実 | 値 |
/// |---|---|
/// | `bladeHeartEffects`（DRAW / SCORE） | **ライブにしか無い**（CLAUDE.md §6 のとおり） |
/// | `hearts` に出る色 | **6 色のみ。`ALL` も `GRAY` も 0 件** |
/// | `requiredHearts` の `GRAY` | 208 種（ライブのみ） |
/// | `bladeHearts` の `ALL` | 126 種（ライブのみ） |
/// | `imageHash` が空の刷り | **0 件** → だから [catalogWithoutImages] で模す |
/// | `illustrator` があるもの | 2,527 中 **185** だけ |
library;

import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/data/card_list_row.dart';
import 'package:loveca_ui/src/data/master_catalog.dart';

/// 複数キャラ名 + 複数グループ名（★実データで 6 種しかない形）。
const String trioMemberPrinting = 'LL-bp1-001-R+';

/// 同じ cardNumber の 3 刷り。`-R` だけが通常刷り。
const String parallelMemberNormal = 'PL!HS-bp1-002-R';
const String parallelMemberParallel = 'PL!HS-bp1-002-P';
const String parallelMemberOtherProduct = 'PL!HS-bp1-002-RM';

/// ★色ブレードハートと DRAW の同居。M5 で「混ざらない」ことを見る本命。
const String drawLivePrinting = 'PL!HS-bp1-022-L';

/// SCORE を持つライブ。
const String scoreLivePrinting = 'PL!HS-bp1-019-L';

/// `bladeHearts` に ALL を持つライブ。
const String allBladeLivePrinting = 'PL!HS-bp1-020-L';

/// ★全フィールドが空のエネルギー。
const String energyPrinting = 'PL!-bp1-000-LLE';

const _cards = <String, Card>{
  'LL-bp1-001': Card(
    cardNumber: 'LL-bp1-001',
    name: '上原歩夢&澁谷かのん&日野下花帆',
    cardType: CardType.member,
    // 総合ルール 2.3.2.1: カード名の ＆ で区切られたそれぞれの名称。
    characterNames: ['上原歩夢', '澁谷かのん', '日野下花帆'],
    // 総合ルール 2.4.2.1: 1 枚が複数グループに属しうる。
    groupNames: ['虹ヶ咲', 'Liella!', '蓮ノ空'],
    effectText: '【登場】自分の控え室からメンバーカードを1枚手札に加える。\n'
        '【ライブ開始時】手札の「上原歩夢」と「澁谷かのん」と「日野下花帆」を、'
        '好きな組み合わせで合計3枚、控え室に置いてもよい：ライブ終了時まで、'
        '「【常時】ライブの合計スコアを＋３する。」を得る。\n'
        '（手札のこのカードもこの効果で控え室に置ける。）',
    keywords: ['ENTER', 'CONTINUOUS', 'LIVE_START'],
    cost: 20,
    bladeCount: 5,
    hearts: {HeartColor.pink: 3, HeartColor.green: 3, HeartColor.purple: 3},
    heartTotal: 9,
    stats: 14,
  ),
  'PL!HS-bp1-002': Card(
    cardNumber: 'PL!HS-bp1-002',
    name: '村野さやか',
    cardType: CardType.member,
    characterNames: ['村野さやか'],
    groupNames: ['蓮ノ空'],
    unitNames: ['DOLLCHESTRA'],
    effectText: '【起動】[E][E]、このメンバーをステージから控え室に置く：'
        '自分の控え室からコスト15以下の『蓮ノ空』のメンバーカードを1枚、'
        'このメンバーがいたエリアに登場させる。',
    keywords: ['ACTIVATED'],
    cost: 11,
    bladeCount: 2,
    hearts: {HeartColor.pink: 1, HeartColor.green: 1, HeartColor.blue: 2},
    heartTotal: 4,
    stats: 6,
  ),
  'PL!HS-bp1-022': Card(
    cardNumber: 'PL!HS-bp1-022',
    name: 'AWOKE',
    cardType: CardType.live,
    characterNames: ['AWOKE'],
    groupNames: ['蓮ノ空'],
    unitNames: ['DOLLCHESTRA'],
    effectText: '【ライブ成功時】エールにより公開された自分のカードの中に'
        '『蓮ノ空』のメンバーカードが10枚以上ある場合、このカードのスコアを＋１する。\n\n'
        '(エールをすべて行った後、エールで出た[ドロー]1つにつき、カードを1枚引く。)',
    keywords: ['LIVE_SUCCESS'],
    score: 5,
    // 総合ルール 2.11。★GRAY は「色を指定しないハート」（2.1.1.2）。
    requiredHearts: {HeartColor.gray: 6, HeartColor.blue: 6},
    // ★★ 8.3.14 のハート合計に合算するのはこちらだけ ★★
    bladeHearts: {HeartColor.blue: 1},
    // ★★ こちらは合算しない（8.3.12.1 のドロー）★★
    bladeHeartEffects: {BladeHeartEffect.draw: 1},
    requiredHeartTotal: 12,
  ),
  'PL!HS-bp1-019': Card(
    cardNumber: 'PL!HS-bp1-019',
    name: 'Dream Believers',
    cardType: CardType.live,
    characterNames: ['Dream Believers'],
    groupNames: ['蓮ノ空'],
    effectText: '(エールで出た[スコア]1つにつき、成功したライブのスコアの合計に1を加算する。)',
    score: 1,
    requiredHearts: {HeartColor.gray: 4},
    // 8.4.2.1 のスコア。★ハートではない。
    bladeHeartEffects: {BladeHeartEffect.score: 1},
    requiredHeartTotal: 4,
  ),
  'PL!HS-bp1-020': Card(
    cardNumber: 'PL!HS-bp1-020',
    name: '365 Days',
    cardType: CardType.live,
    characterNames: ['365 Days'],
    groupNames: ['蓮ノ空'],
    effectText: '(必要ハートを確認する時、エールで出た[ALLブレード]は任意の色のハートとして扱う。)',
    score: 2,
    requiredHearts: {HeartColor.gray: 6},
    // 総合ルール 2.1.1.3: 任意の 1 色として扱えるハート。
    bladeHearts: {HeartColor.all: 1},
    requiredHeartTotal: 6,
  ),
  // ★★ エネルギーは名前とキャラ名しか無い。グループ名すら空 ★★
  //   実データの 567 種すべてがこの形。詳細画面が「壊れて見えない」ことを見る。
  'PL!-bp1-000': Card(
    cardNumber: 'PL!-bp1-000',
    name: '高坂穂乃果',
    cardType: CardType.energy,
    characterNames: ['高坂穂乃果'],
  ),
};

const _printings = <String, Printing>{
  trioMemberPrinting: Printing(
    printingId: trioMemberPrinting,
    cardNumber: 'LL-bp1-001',
    expansion: 'BP01',
    rarity: 'R+',
    isParallel: false,
    // ★実データで illustrator が入っているのは 2,527 中 185 だけ。
    illustrator: 'オペラハウス',
    imageHash: '2637683a982e97d6217371d8728b4b6c',
  ),
  parallelMemberParallel: Printing(
    printingId: parallelMemberParallel,
    cardNumber: 'PL!HS-bp1-002',
    expansion: 'BP01',
    rarity: 'P',
    isParallel: true,
    imageHash: '439a1f3e7adf1885119af08a961efaf3',
  ),
  parallelMemberNormal: Printing(
    printingId: parallelMemberNormal,
    cardNumber: 'PL!HS-bp1-002',
    expansion: 'BP01',
    rarity: 'R',
    isParallel: false,
    imageHash: 'db65063ff08434716d503ce2953dbf87',
  ),
  // ★同じ cardNumber でも商品が違う（BP05）。再録は実在する。
  parallelMemberOtherProduct: Printing(
    printingId: parallelMemberOtherProduct,
    cardNumber: 'PL!HS-bp1-002',
    expansion: 'BP05',
    rarity: 'RM',
    isParallel: true,
    imageHash: 'ffa78da109706d8aa52e7369d6391c6a',
  ),
  drawLivePrinting: Printing(
    printingId: drawLivePrinting,
    cardNumber: 'PL!HS-bp1-022',
    expansion: 'BP01',
    rarity: 'L',
    isParallel: false,
    imageHash: 'eb37cd1dcab44c4c855f5f42b6d90ce3',
  ),
  scoreLivePrinting: Printing(
    printingId: scoreLivePrinting,
    cardNumber: 'PL!HS-bp1-019',
    expansion: 'BP01',
    rarity: 'L',
    isParallel: false,
    imageHash: '9f952345b273fc0444cae1f3e078270e',
  ),
  'PL!HS-bp1-019-SECL': Printing(
    printingId: 'PL!HS-bp1-019-SECL',
    cardNumber: 'PL!HS-bp1-019',
    expansion: 'BP05',
    rarity: 'SECL',
    isParallel: true,
    imageHash: 'da5a56bb5fdc00ececb21a0a8c490067',
  ),
  allBladeLivePrinting: Printing(
    printingId: allBladeLivePrinting,
    cardNumber: 'PL!HS-bp1-020',
    expansion: 'BP01',
    rarity: 'L',
    isParallel: false,
    imageHash: 'ab8a1ff7de7ebc1f448d6ba02c08f243',
  ),
  energyPrinting: Printing(
    printingId: energyPrinting,
    cardNumber: 'PL!-bp1-000',
    expansion: 'BP01',
    rarity: 'LLE',
    isParallel: false,
    imageHash: '66aaea84d46ec559680b76a8f62422e0',
  ),
};

/// 一覧の投影行（決定 D48）。★`_printings` と 1 対 1。
List<CardListRow> _rowsOf(Map<String, Printing> printings) => [
      for (final printing in printings.values)
        CardListRow(
          printingId: printing.printingId,
          cardNumber: printing.cardNumber,
          name: _cards[printing.cardNumber]!.name,
          cardType: _cards[printing.cardNumber]!.cardType,
          expansion: printing.expansion,
          rarity: printing.rarity,
          isParallel: printing.isParallel,
          imageHash: printing.imageHash,
          // ★コストはメンバーにしか値が無い（`normalize.py:362-363`）。
          cost: _cards[printing.cardNumber]!.cost,
        ),
    ];

/// 実データから写したカタログ。
MasterCatalog realShapedCatalog() => MasterCatalog(
      cards: _cards,
      printings: _printings,
      config: RuleConfig.standard,
      rows: _rowsOf(_printings),
      dataVersion: 2,
    );

/// ★★ `build --skip-images` で作った dist を模したカタログ（§5-2(4)）★★
///
/// 画像を読まないので **`imageHash` が全刷りで空になる**。
/// 実データ（`dist`）には空の刷りが **0 件**なので、この形はテストでしか作れない。
/// **作れないからといって確かめないと、プレースホルダの経路が腐る。**
MasterCatalog realShapedCatalogWithoutImages() {
  final stripped = {
    for (final entry in _printings.entries)
      entry.key: Printing(
        printingId: entry.value.printingId,
        cardNumber: entry.value.cardNumber,
        expansion: entry.value.expansion,
        rarity: entry.value.rarity,
        isParallel: entry.value.isParallel,
        illustrator: entry.value.illustrator,
        // ★ここだけが違い。
      ),
  };
  return MasterCatalog(
    cards: _cards,
    printings: stripped,
    config: RuleConfig.standard,
    rows: _rowsOf(stripped),
    dataVersion: 2,
  );
}
