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

/// ★★ エネルギーが 1 枚も無いデッキ（決定 D96 / D97）★★
///
/// ★実データでも成立する形である —— 6.1.1.3 を満たさないだけで、
/// 保存も盤面の開始もできる（`canSave` は名前しか見ず、開始を止めるのは未知の刷りだけ）。
/// ★エネルギーが**永久に 1 枚も出ない**のがこのデッキで、それが U23 の要望の実体。
Deck boardFixtureDeckWithoutEnergy() => Deck(
      deckId: 'no-energy',
      name: 'エネルギー 0 枚',
      entries: const [
        DeckEntry(printingId: trioMemberPrinting, count: 4),
        DeckEntry(printingId: drawLivePrinting, count: 4),
      ],
      createdAt: _epoch,
      updatedAt: _epoch,
    );

/// ★★ メンバー / ライブも足りず、かつエネルギーも 0 枚のデッキ ★★
///
/// ★**軸 2 の行を「エネルギーだけが不足しているとき」に限る**ことの対で要る
/// （決定 D96-2）。これで「このまま開始できます」を出すと、
/// **補完が効かない不足まで補われるように読める。**
Deck boardFixtureDeckShortEverything() => Deck(
      deckId: 'short-everything',
      name: 'いろいろ足りない',
      entries: const [
        DeckEntry(printingId: trioMemberPrinting, count: 1),
      ],
      createdAt: _epoch,
      updatedAt: _epoch,
    );

/// 6.2.1 を通した初期状態。★本番（`start_board.dart`）と同じ順で呼ぶ。
///
/// ★★ 6.2.1.6（マリガン）を 0 枚で通してある（決定 D93 / M-B6）★★
/// **飛ばさない。**本番の経路は必ず 6.2.1.6 を通るので、fixture が飛ばすと
/// 「盤面テストが通る経路」と「実機の経路」が分かれる。
/// ★0 枚は**乱数を 1 つも消費しない**ので、この fixture を使う既存の盤面テストは
/// 1 件も影響を受けない —— **影響したらそれ自体が回帰の合図**である。
GameState boardFixtureState({
  int seed = 1,
  Deck? self,
  Deck? opponent,
  String firstPlayerId = kSelfPlayerId,
  MasterCatalog? catalog,

  /// ★脇に置くカード（6.2.1.6）。★既定は 0 枚。
  List<MulliganChoice> mulligan = const [],
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
    // ★順を入れ替えないこと（決定 D80）。
  ).mulligan(choices: mulligan, rng: rng).dealInitialEnergy(rng: rng);
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

  /// ★ウェイト状態（4.3.2.2）で置くメンバー。アクティブのぶんの**後ろ**に積む。
  ///
  /// ★8.3.10（アクティブのみ）と 8.3.14（全員）の参照範囲の違いを見るために要る。
  Map<MemberAreaSlot, List<String>> selfWaitMembers = const {},
  Map<MemberAreaSlot, List<String>> opponentWaitMembers = const {},

  /// 各スロットの**末尾のメンバー**の下に重ねるカード（4.5.5.1）。
  Map<MemberAreaSlot, List<String>> selfBeneath = const {},

  /// 上にメンバーが居ないカード（4.5.5.4.1 / 4.5.5.4.2）。
  Map<MemberAreaSlot, List<String>> selfOrphans = const {},
  Map<MemberAreaSlot, List<String>> opponentOrphans = const {},
  List<String> selfResolution = const [],

  /// ★★ 解決領域は両プレイヤー共有で 1 つだけ（4.14.1）★★
  /// 8.3.12（所有者で絞らない）と 8.3.14（絞る）の対比に**相手のカードが要る**。
  List<String> opponentResolution = const [],
  List<String> selfFreeArea = const [],
  String firstPlayerId = kSelfPlayerId,

  /// ★進行のテストは途中のステップから始めたい（先頭から 73 回進めると遅い）。
  StepCursor cursor = const StepCursor(PhaseId.firstActive, StepId.s7_4_1),
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
    Map<MemberAreaSlot, List<String>> waitMembers,
    Map<MemberAreaSlot, List<String>> beneath,
    Map<MemberAreaSlot, List<String>> orphans,
    List<String> freeArea,
  ) {
    // ★★ 4.1.2.1 を通す。手で組んだ盤面でも `reduce` が作れる状態だけを作る ★★
    //   通さないと、たとえば手札 (4.11.2 非公開領域) の札が**表向き**で生まれ、
    //   「手札 → 控え室で表向きになる」試験が**素通しで緑になる**。
    //   `docs/...` D-10「0 件は『無い』と『見えていない』の区別がつかない」と同じ形。
    //   ★4.6 ライブカード置き場は `placedIn` が触らない (4.6.2) ので表向きのまま。
    //     裏向きの札が要る試験は 5.3.1 (`FlipCard`) で作ること。
    List<CardInstance> zone(Zone z) =>
        [for (final c in build(zones[z] ?? const [], playerId)) placedIn(c, z)];

    final areas = <MemberArea>[];
    for (final slot in MemberAreaSlot.values) {
      final placed = [
        // ★4.3.2.3: 配置状態が指定される領域なので既定はアクティブ状態。
        for (final card in build(members[slot] ?? const [], playerId))
          card.copyWith(orientation: CardOrientation.active),
        // ★4.3.2.2 ウェイト状態。8.3.10 は数えず 8.3.14 は数える。
        for (final card in build(waitMembers[slot] ?? const [], playerId))
          card.copyWith(orientation: CardOrientation.wait),
      ];
      // ★4.1.2.1 / 4.5.3: メンバーエリアは公開領域なので表向き（`make` の既定）。
      //   4.5.5.2 により向きは持たない。`placedIn` はメンバーエリアを受けない。
      final under = build(beneath[slot] ?? const [], playerId);
      areas.add(MemberArea(
        slot: slot,
        stacks: [
          for (var i = 0; i < placed.length; i++)
            MemberStack(
              member: placed[i],
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
      player(kSelfPlayerId, selfZones, selfMembers, selfWaitMembers,
          selfBeneath, selfOrphans, selfFreeArea),
      player(kOpponentPlayerId, opponentZones, opponentMembers,
          opponentWaitMembers, const {}, opponentOrphans, const []),
    ],
    firstPlayerId: firstPlayerId,
    cursor: cursor,
    // ★共有 1 つ（4.14.1）。★`ownerId` で分かれるだけで領域は 1 本。
    resolution: [
      // 4.14.2: 解決領域は公開領域 → 4.1.2.1 により表向き。
      for (final c in build(selfResolution, kSelfPlayerId))
        placedIn(c, Zone.resolution),
      for (final c in build(opponentResolution, kOpponentPlayerId))
        placedIn(c, Zone.resolution),
    ],
  );
}

/// ★★ カタログに無い刷り（M-B6 の実機確認 / 決定 D94-2）★★
///
/// 集計も整理もこれを引けないので、`excludedCount` を**実際に立てられる**。
/// ★実データは完全なので、この形は fixture でしか作れない。
///
/// ★`board_notice_test.dart` と `board_tidy_test.dart` の両方が使う。
/// 同じ材料を 2 箇所に書かない（`ルール整合性チェック_v1.06.md` D-15）。
const ghostCardNumber = 'GHOST-bp9-999';

CardInstance ghostCard(String playerId, int n) => CardInstance(
      instanceId: '$playerId:ghost:$n',
      printingId: '$ghostCardNumber-X',
      cardNumber: ghostCardNumber,
      ownerId: playerId,
    );

/// 解決領域（共有 / 4.14.1）にカタログに無い札を混ぜる。
GameState withGhostInResolution(GameState state, String playerId) =>
    state.copyWith(resolution: [...state.resolution, ghostCard(playerId, 1)]);

/// メンバーエリアに、上にメンバーが居ないカタログ外の札を置く。
///
/// ★10.5.3 は種別で行き先が変わるので、カタログを引けないと**動かせない**。
/// → 整理は `applied` が空のまま `excludedCount` だけが立つ。
GameState withGhostOrphan(
  GameState state,
  String playerId,
  MemberAreaSlot slot,
) {
  final areas = [
    for (final area in state.playerOf(playerId).memberAreas)
      if (area.slot == slot)
        area.copyWith(orphans: [...area.orphans, ghostCard(playerId, 2)])
      else
        area,
  ];
  return state.copyWith(players: [
    for (final player in state.players)
      if (player.playerId == playerId)
        player.copyWith(memberAreas: areas)
      else
        player,
  ]);
}
