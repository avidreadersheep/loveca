/// 盤面テストの材料（M-B1）.
///
/// ★★ カードは `real_shaped_catalog.dart` の実在の刷りだけを使う ★★
/// 作り話のカードを 1 枚置いて通るテストにしない（同ファイルの取り決め）。
///
/// ★★ 6.1 を満たすデッキは作れない ★★
/// fixture には実在の 6 種 / 9 刷りしか無く、メンバー 48 + ライブ 12 を
/// 実在のカードだけで並べることができない。
/// → **盤面の UI テストは 6.1 違反の経路を通る。**それ自体を
/// `board_start_dialog_test.dart` が固定している（黙って通していないことの確認）。
///
/// ★★ 検証は `GameSetup` の担当ではない（D28）★★
/// 枚数違反で `GameSetup.begin` は投げない。投げるのは未知の刷りのときだけ。
library;

import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/data/master_catalog.dart';
import 'package:loveca_ui/src/ui/board/board_start_dialog.dart';

import 'real_shaped_catalog.dart';

final _epoch = DateTime.utc(2026, 8, 24);

/// メンバー 4 刷り / ライブ 3 刷り / エネルギー 1 刷り。
///
/// ★エネルギーを 6 枚にしてあるのは、6.2.1.7 で 3 枚出したあと
/// **デッキに 3 枚残る**ようにするため（「まだ出せる」と「空で無効」の両方を見る）。
Deck boardFixtureDeck({String deckId = 'board-deck', String? name}) => Deck(
      deckId: deckId,
      name: name ?? '盤面テスト',
      entries: const [
        DeckEntry(printingId: trioMemberPrinting, count: 2),
        DeckEntry(printingId: parallelMemberNormal, count: 2),
        DeckEntry(printingId: multiNormalFirst, count: 2),
        DeckEntry(printingId: drawLivePrinting, count: 2),
        DeckEntry(printingId: scoreLivePrinting, count: 2),
        DeckEntry(printingId: allBladeLivePrinting, count: 2),
        DeckEntry(printingId: energyPrinting, count: 6),
      ],
      createdAt: _epoch,
      updatedAt: _epoch,
    );

/// ★エネルギーがちょうど 3 枚のデッキ。6.2.1.7 で使い切るので**空になる**。
///
/// ★「エネルギーデッキが空のときボタンが無効になり理由が出る」を見るために要る。
Deck boardFixtureDeckWithExactEnergy() => Deck(
      deckId: 'exact-energy',
      name: 'エネルギーちょうど',
      entries: const [
        DeckEntry(printingId: trioMemberPrinting, count: 4),
        DeckEntry(printingId: drawLivePrinting, count: 4),
        DeckEntry(printingId: energyPrinting, count: 3),
      ],
      createdAt: _epoch,
      updatedAt: _epoch,
    );

/// ★カタログに無い刷りを含むデッキ（決定 D35 / D80）。
Deck boardFixtureDeckWithUnknown() => Deck(
      deckId: 'has-unknown',
      name: '未知を含む',
      entries: const [
        DeckEntry(printingId: trioMemberPrinting, count: 4),
        DeckEntry(printingId: energyPrinting, count: 4),
        DeckEntry(printingId: 'GHOST-bp9-999-X', count: 1),
      ],
      createdAt: _epoch,
      updatedAt: _epoch,
    );

/// 6.2.1 を通した初期状態。★本番（`start_board.dart`）と同じ順で呼ぶ。
GameState boardFixtureState({
  int seed = 1,
  Deck? self,
  Deck? opponent,
  String firstPlayerId = kSelfPlayerId,
  MasterCatalog? catalog,
}) {
  final resolved = catalog ?? realShapedCatalog();
  // ★乱数列は 1 本（決定 D80）。
  final rng = SeededRng(seed);
  return GameSetup.begin(
    players: [
      PlayerDeck(playerId: kSelfPlayerId, deck: self ?? boardFixtureDeck()),
      PlayerDeck(
        playerId: kOpponentPlayerId,
        deck: opponent ?? boardFixtureDeck(deckId: 'board-deck-2'),
      ),
    ],
    cards: resolved.cards,
    printings: resolved.printings,
    rng: rng,
    firstPlayerId: firstPlayerId,
    config: resolved.config,
    // ★ここに 6.2.1.6（マリガン）が入る（M-B5）。順を入れ替えないこと。
  ).dealInitialEnergy(rng: rng);
}

/// ★★ 領域ごとに刷りを指定して盤面を手で組む（M-B2）★★
///
/// `GameSetup` の出力ではシャッフルの結果に依存するので、
/// 「ライブの札がライブカード置き場にある」といった**特定の配置**を作れない。
/// D46 の帯（絵の外・箱の中）を掴む試験は種別ごとに置き場を決める必要がある。
///
/// ★[zones] のキーに [Zone.memberArea] / [Zone.stage] / [Zone.resolution] は使えない
///   （それぞれ [members] / 実体無し / [resolution] が受け持つ）。
GameState handcraftedBoard({
  Map<Zone, List<String>> selfZones = const {},
  Map<Zone, List<String>> opponentZones = const {},
  Map<MemberAreaSlot, List<String>> selfMembers = const {},
  Map<MemberAreaSlot, List<String>> opponentMembers = const {},

  /// 各スロットの**末尾のメンバー**の下に重ねるカード（4.5.5.1）。
  Map<MemberAreaSlot, List<String>> selfBeneath = const {},

  /// 上にメンバーが居ないカード（4.5.5.4.1 / 4.5.5.4.2）。
  Map<MemberAreaSlot, List<String>> selfOrphans = const {},
  List<String> selfResolution = const [],
  List<String> selfFreeArea = const [],
  String firstPlayerId = kSelfPlayerId,
}) {
  final catalog = realShapedCatalog();
  final serial = <String, int>{};

  CardInstance make(String printingId, String playerId) {
    final n = (serial[playerId] ?? 0) + 1;
    serial[playerId] = n;
    return CardInstance(
      instanceId: '$playerId:$printingId:$n',
      printingId: printingId,
      cardNumber: catalog.printings[printingId]!.cardNumber,
      ownerId: playerId,
    );
  }

  List<CardInstance> build(List<String> ids, String playerId) =>
      [for (final id in ids) make(id, playerId)];

  PlayerState player(
    String playerId,
    Map<Zone, List<String>> zones,
    Map<MemberAreaSlot, List<String>> members,
    Map<MemberAreaSlot, List<String>> beneath,
    Map<MemberAreaSlot, List<String>> orphans,
    List<String> freeArea,
  ) {
    List<CardInstance> zone(Zone z) => build(zones[z] ?? const [], playerId);

    final areas = <MemberArea>[];
    for (final slot in MemberAreaSlot.values) {
      final placed = build(members[slot] ?? const [], playerId);
      final under = build(beneath[slot] ?? const [], playerId);
      areas.add(MemberArea(
        slot: slot,
        stacks: [
          for (var i = 0; i < placed.length; i++)
            MemberStack(
              // ★4.3.2.3: 配置状態が指定される領域なので既定はアクティブ状態。
              member: placed[i].copyWith(orientation: CardOrientation.active),
              // ★末尾のメンバーの下に置く（4.5.5.1）。
              beneath: i == placed.length - 1 ? under : const [],
            ),
        ],
        orphans: build(orphans[slot] ?? const [], playerId),
      ));
    }

    return PlayerState(
      playerId: playerId,
      memberAreas: areas,
      hand: zone(Zone.hand),
      mainDeck: zone(Zone.mainDeck),
      energyDeck: zone(Zone.energyDeck),
      energyField: zone(Zone.energyField),
      liveStage: zone(Zone.liveStage),
      successLive: zone(Zone.successLive),
      waitingRoom: zone(Zone.waitingRoom),
      exile: zone(Zone.exile),
      freeArea: build(freeArea, playerId),
    );
  }

  return GameState(
    players: [
      player(kSelfPlayerId, selfZones, selfMembers, selfBeneath, selfOrphans,
          selfFreeArea),
      player(kOpponentPlayerId, opponentZones, opponentMembers, const {},
          const {}, const []),
    ],
    firstPlayerId: firstPlayerId,
    cursor: const StepCursor(PhaseId.firstActive, StepId.s7_4_1),
    resolution: build(selfResolution, kSelfPlayerId),
  );
}
