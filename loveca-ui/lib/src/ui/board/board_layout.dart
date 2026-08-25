/// 盤面のレイアウト（決定 D75 / D85 / 盤面設計メモ §4 / §6）.
///
/// ## 置き場の数え（★根拠のない数を書かない）
///
/// 総合ルール 4 章が定義する領域は **11 種**（4.4〜4.14 が 1 節 1 領域）。
/// - **ステージ（4.4）は実体を持たない** —— 4.4.1「メンバーエリアを統合した領域」
/// - **解決領域（4.14）だけが共有** —— 4.14.1「両プレイヤーが共有して使用する領域が 1 つだけ」
/// - **メンバーエリア（4.5）は 3 スロット** —— 4.5.2.1
///
/// | 区分 | 数 | 内訳 |
/// |---|---:|---|
/// | プレイヤーごと | **11** | メンバーエリア 3 / 4.6 / 4.10 / 4.7 / 4.9 / 4.8 / 4.11 / 4.12 / 4.13 |
/// | 共有 | **1** | 解決領域（4.14.1） |
/// | ★ルール外 | **2** | 6.2.1.6 の脇置き / フリーエリア（`OutOfRuleZone`） |
///
/// ★★ ルール外の 2 つを 4 章の領域と同じ見た目にしない ★★
/// `Zone` と `OutOfRuleZone` を別の型に分けた 3a-1 の拘束を UI でも守る。
/// **盤の外**に置き、「ルールの領域ではありません」と断る。
///
/// ## ★ 4.5.7.1 が鏡像配置を要求している
///
/// ```
///   相手:  右サイド    センター    左サイド
///            │          │          │       ← 4.5.7.1 の「正面」が縦に並ぶ
///   自分:  左サイド    センター    右サイド
/// ```
///
/// ★これは見た目の都合ではなく条文の要求である。揃っていないと、
/// 「正面のエリア」を参照する効果を手で処理するときに毎回読み替えが要る。
///
/// ## ★ 共有解決領域は中央 1 本
///
/// プレイヤーごとに 2 本置かない（4.14.1）。★カードごとに `ownerId` が読めるようにする——
/// 8.3.14 は「解決領域の**自分の**カード」のブレードハートだけを合算するので、
/// **どちらのカードかが見えないと手で数えられない。**
///
/// ★★ `PaneScaffold` を使わない（決定 D75）★★
/// 唯一の判断点が「幅で 1/2 ペインを切り替える」ことだが、**盤面は 1 ペインに
/// 縮退できない**（置き場が同時に見えないと物理操作にならない）。
/// 使うと「1 ペインのとき盤面はどうなるか」という**答えの無い分岐**が生まれる。
/// 最小幅を下回ったら盤面ごとスクロールする。
///
/// ## ★★ M-B2: 掴む側と落とす側（決定 D46 / D85）★★
///
/// 札は必ず [BoardPiece]（`CardDragSource` の `background` で矩形を作る）、
/// 落とし先は必ず [BoardDropSlot] / [BoardDropRegion] を通す。
/// **素の `Draggable` / `DragTarget` をここに書かない。**
///
/// ★4.8 / 4.9 は落とせるが中身は出さない（[HiddenPile] は枚数しか受け取らない / D77）。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;

import '../common/card_drag.dart';
import '../common/card_thumb.dart';
import 'board_card_menu.dart';
import 'board_drag.dart';
import 'board_drop.dart';
import 'board_piece.dart';
import 'board_slot.dart';
import 'board_view.dart';
import 'hidden_pile.dart';

/// 小さく出す札の幅（あふれた札 / 束の中身）。
const double _kMiniWidth = kBoardSlotWidth * 0.5;

/// 手札の帯の札の幅。
const double _kHandWidth = kBoardSlotWidth * 0.72;

/// 解決領域の札の幅。
const double _kResolutionWidth = kBoardSlotWidth * 0.6;

/// 盤面の本体。★上段が相手、下段が視点（決定 D75）。
class BoardLayout extends StatelessWidget {
  const BoardLayout({
    super.key,
    required this.onDrawEnergy,
    this.minWidth = kBoardMinWidth,
  });

  /// 「エネルギーを1枚出す」（決定 D73 / D81）。null なら押せない。
  final VoidCallback? onDrawEnergy;

  /// ★★ 未決 **U16** を実測するための口である ★★
  /// 既定は [kBoardMinWidth]。**本番でこれを渡さない。**
  ///
  /// 下のクランプがあるかぎり、窓をいくら狭めても盤面は
  /// [kBoardMinWidth] のまま横スクロールになり、**溢れない**。
  /// つまり「その幅で本当に収まるのか」を外から測れない。
  /// → `test/board/board_min_width_test.dart` だけが 0 を渡して
  /// **溢れの下限**を二分探索する（U8 / D61 と同じ手順）。
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);

    // ★★ 幅をここで確定させる ★★
    //   横スクロールの中は幅が無限になるので、`Expanded` を使う前に
    //   **必ず有限の幅を与える**。`ConstrainedBox(minWidth:)` では足りない
    //   （下限は決まるが上限が無限のまま）。
    return LayoutBuilder(
      builder: (context, constraints) {
        // ★最小幅を下回ったら盤面ごとスクロールする（1 ペインに縮退しない / D75）。
        final width = constraints.maxWidth < minWidth
            ? minWidth
            : constraints.maxWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---- 左の袖: 相手 ----
                    _Sleeve(
                      playerId: view.opponent.playerId,
                      onDrawEnergy: null,
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        children: [
                          // ---- 相手 後列 → 前列（★上段は相手）----
                          _BackRow(
                            playerId: view.opponent.playerId,
                            mirrored: true,
                          ),
                          const SizedBox(height: 8),
                          _MemberRow(
                            playerId: view.opponent.playerId,
                            slots: BoardView.opponentRow,
                          ),

                          const SizedBox(height: 10),
                          // ---- ★共有解決領域は中央に 1 本だけ（4.14.1）----
                          const _ResolutionRow(),
                          const SizedBox(height: 10),

                          // ---- 自分 前列 → 後列 ----
                          _MemberRow(
                            playerId: view.viewer.playerId,
                            slots: BoardView.viewerRow,
                          ),
                          const SizedBox(height: 8),
                          _BackRow(
                            playerId: view.viewer.playerId,
                            mirrored: false,
                          ),

                          const SizedBox(height: 10),
                          // ---- 自分の手札（4.11）----
                          _HandStrip(playerId: view.viewer.playerId),
                          const SizedBox(height: 6),
                          // ---- ★相手の手札。一人回しでは中身も見える（D77 / D84）----
                          _HandStrip(playerId: view.opponent.playerId),

                          const SizedBox(height: 10),
                          // ---- ★ルール外の 2 置き場は盤の外 ----
                          const _OutOfRuleRow(),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),
                    // ---- 右の袖: 自分 ----
                    _Sleeve(
                      playerId: view.viewer.playerId,
                      onDrawEnergy: onDrawEnergy,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 袖: メインデッキ（4.8）/ エネルギーデッキ（4.9）/ エネルギー置き場（4.7）/
/// 控え室（4.12）/ 除外領域（4.13）。
class _Sleeve extends StatelessWidget {
  const _Sleeve({required this.playerId, required this.onDrawEnergy});

  final String playerId;
  final VoidCallback? onDrawEnergy;

  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);
    final player = view.state.playerOf(playerId);
    final label = view.labelOf(playerId);

    return SizedBox(
      width: kBoardSlotWidth + 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),

          // ★★ 4.8 / 4.9 は枚数だけを渡す（決定 D77）★★
          //   ★落とすことはできる（10.5.4 の戻り経路を手で通せる）。
          HiddenPile(
            key: ValueKey('pile-main-$playerId'),
            playerId: playerId,
            zone: Zone.mainDeck,
            title: 'メインデッキ',
            count: player.mainDeck.length,
          ),
          const SizedBox(height: 8),
          HiddenPile(
            key: ValueKey('pile-energy-$playerId'),
            playerId: playerId,
            zone: Zone.energyDeck,
            title: 'エネルギーデッキ',
            count: player.energyDeck.length,
          ),

          if (onDrawEnergy != null || player.energyDeck.isEmpty) ...[
            const SizedBox(height: 4),
            _DrawEnergyButton(
              playerId: playerId,
              onPressed: onDrawEnergy,
              deckIsEmpty: player.energyDeck.isEmpty,
            ),
          ],

          const SizedBox(height: 8),
          _ZonePile(
            playerId: playerId,
            zone: Zone.energyField,
            title: 'エネルギー',
            cards: player.energyField,
          ),
          const SizedBox(height: 8),
          _ZonePile(
            playerId: playerId,
            zone: Zone.waitingRoom,
            title: '控え室',
            cards: player.waitingRoom,
          ),
          const SizedBox(height: 8),
          _ZonePile(
            playerId: playerId,
            zone: Zone.exile,
            title: '除外',
            cards: player.exile,
          ),
        ],
      ),
    );
  }
}

/// 「エネルギーを1枚出す」（決定 D73 / D81）。
///
/// ★★ このボタンは恒久である。M-B1 限りの足場ではない ★★
/// 7.5.2 の自動進行（エネルギーフェイズ）とは別に、効果由来の
/// 「エネルギーデッキから 1 枚」を手で出す口が要る（D-A のサンドボックス）。
///
/// ★★ 出せないときに消さず、無効にして理由を出す ★★
/// エネルギーは控え室を経由しない閉ループ（10.5.4）なので、メインデッキのような
/// リフレッシュ（10.2）が無い。6.1.1.3 の 12 枚を使い切ると出せなくなる。
/// **黙って何も起きない形にしない。**
class _DrawEnergyButton extends StatelessWidget {
  const _DrawEnergyButton({
    required this.playerId,
    required this.onPressed,
    required this.deckIsEmpty,
  });

  final String playerId;
  final VoidCallback? onPressed;
  final bool deckIsEmpty;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: deckIsEmpty
            ? 'エネルギーデッキが空です。エネルギーは控え室を経由しない'
                '閉ループ（10.5.4）なので、リフレッシュ（10.2）は起きません。'
            : 'エネルギーデッキから無作為に 1 枚（4.9.2 / 4.9.3）',
        child: FilledButton.tonal(
          key: ValueKey('draw-energy-$playerId'),
          onPressed: deckIsEmpty ? null : onPressed,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
            minimumSize: const Size(0, 28),
            textStyle: Theme.of(context).textTheme.labelSmall,
          ),
          child: Text(deckIsEmpty ? 'エネルギーが空' : 'エネルギーを1枚出す'),
        ),
      );
}

/// 後列: ライブカード置き場（4.6）と 成功ライブカード置き場（4.10）。
///
/// ★[mirrored] のときは左右を入れ替える。★これは 4.5.7.1 の要求ではなく、
/// 「相手の盤面は自分から見て上下逆さに置かれている」という物理の写しである。
class _BackRow extends StatelessWidget {
  const _BackRow({required this.playerId, required this.mirrored});

  final String playerId;
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);
    final player = view.state.playerOf(playerId);

    final cells = <Widget>[
      _ZonePile(
        playerId: playerId,
        zone: Zone.liveStage,
        title: 'ライブ 4.6',
        cards: player.liveStage,
      ),
      _ZonePile(
        playerId: playerId,
        zone: Zone.successLive,
        title: '成功ライブ 4.10',
        cards: player.successLive,
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final cell in mirrored ? cells.reversed : cells) ...[
          cell,
          const SizedBox(width: 10),
        ],
      ],
    );
  }
}

/// メンバーエリアの 1 行（4.5.2.1）。
///
/// ★[slots] の並びが列の並びである。上段は `BoardView.opponentRow`（= 鏡像）。
class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.playerId, required this.slots});

  final String playerId;
  final List<MemberAreaSlot> slots;

  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);
    final player = view.state.playerOf(playerId);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final slot in slots) ...[
          _MemberSlot(
            playerId: playerId,
            area: player.memberAreas.firstWhere(
              (a) => a.slot == slot,
              orElse: () => MemberArea(slot: slot),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ],
    );
  }
}

/// メンバーエリア 1 つ（4.5）。
///
/// ★★ 箱に出すのは「最も後から置かれたメンバー」（`stacks.last`）★★
/// `MemberArea.stacks` のリスト順は配置順で、末尾が 10.4.1 の
/// 「最も後から置かれたメンバー」である（`member_area.dart` の規約）。
///
/// ★★ 上下の帯は「順番」ではない ★★
/// 4.5.3 はメンバーエリアの順番を管理しないと定める。ここの上下は
/// **4.5.1（置く）と 4.5.5 / 5.10.1（下に置く）の撃ち分け**である。
/// ★メンバーが 0 人なら 2 通りにならないので帯は出ない（`board_drop.dart` が導く）。
class _MemberSlot extends StatelessWidget {
  const _MemberSlot({required this.playerId, required this.area});

  final String playerId;
  final MemberArea area;

  @override
  Widget build(BuildContext context) {
    final top = area.stacks.isEmpty ? null : area.stacks.last.member;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BoardDropSlot(
          key: ValueKey('member-$playerId-${area.slot.name}'),
          label: area.slot.label,
          resolve: (drag, edge) => moveToMemberSlot(
            drag,
            playerId: playerId,
            slot: area.slot,
            edge: edge,
            area: area,
          ),
          child: top == null
              ? null
              : BoardPiece(
                  drag: MemberCardDrag(
                    playerId: playerId,
                    slot: area.slot,
                    card: top,
                  ),
                ),
        ),
        _AreaContents(playerId: playerId, area: area),
      ],
    );
  }
}

/// エリアの中身のうち、箱に出ていないもの。
///
/// ★★ 孤児（4.5.5.4.1 / 4.5.5.4.2）と重複メンバー（10.4）は正規の中間状態である ★★
/// エラーとして出さない。ただし**束と区別できる形**で出す（盤面設計メモ §10-2）。
///
/// | 中身 | 掴めるか |
/// |---|---|
/// | ほかのメンバー（10.4 待ち） | ○ `MoveMemberBetweenAreas` / `MoveMemberOut` |
/// | 下に重ねられたカード（4.5.5.1） | ★**✗** —— 動かす `GameAction` は `DetachFromMember` だけで、落とす先が無い |
/// | 孤児（上にメンバーが居ない） | ★**✗** —— 解消は 10.5.3 / 10.5.4 のルール処理（整理 / M-B5） |
class _AreaContents extends StatelessWidget {
  const _AreaContents({required this.playerId, required this.area});

  final String playerId;
  final MemberArea area;

  @override
  Widget build(BuildContext context) {
    final items = <_MiniCard>[
      // ★末尾（箱に出ている 1 人）を除く。
      for (final stack in area.stacks.take(
        area.stacks.isEmpty ? 0 : area.stacks.length - 1,
      ))
        _MiniCard(
          card: stack.member,
          tag: 'ほか',
          drag: MemberCardDrag(
            playerId: playerId,
            slot: area.slot,
            card: stack.member,
          ),
        ),
      for (final stack in area.stacks)
        for (final beneath in stack.beneath)
          // ★4.5.5.2: 下に重ねられたカードは向きを示す配置状態を持たない。
          //   ★掴ませない（動かす `GameAction` は `DetachFromMember` だけで
          //   落とす先が無い）。剥がすのはメニュー。
          _MiniCard(
            card: beneath,
            tag: '下',
            onTap: (context) => showBeneathCardMenu(
              context,
              playerId: playerId,
              slot: area.slot,
              card: beneath,
            ),
          ),
      for (final orphan in area.orphans)
        _MiniCard(
          card: orphan,
          tag: '孤児',
          // ★できることが無い。だからこそ理由を出す（整理は M-B5）。
          onTap: showOrphanCardMenu,
        ),
    ];

    if (items.isEmpty) return const SizedBox.shrink();
    return _MiniStrip(items: items);
  }
}

/// 共有の解決領域（4.14.1）。★中央に 1 本だけ。
class _ResolutionRow extends StatelessWidget {
  const _ResolutionRow();

  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);
    final theme = Theme.of(context);

    // ★★ ownerId で寄せて並べる（8.3.14）★★
    // 「解決領域の**自分の**カード」だけを合算するので、どちらのものかが
    // 見えないと手で数えられない。★枚数だけの表示にしない。
    final mine = view.state.resolution
        .where((c) => c.ownerId == view.viewerId)
        .toList();
    final theirs = view.state.resolution
        .where((c) => c.ownerId != view.viewerId)
        .toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.tertiary),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          key: const ValueKey('resolution-shared'),
          children: [
            Text('解決領域 4.14\n★共有 1 つ', style: theme.textTheme.labelSmall),
            const SizedBox(width: 10),
            Expanded(child: _OwnerSide(label: '相手のカード', cards: theirs)),
            const SizedBox(width: 8),
            Expanded(child: _OwnerSide(label: '自分のカード', cards: mine)),
          ],
        ),
      ),
    );
  }
}

/// 解決領域の片側。
///
/// ★4.14.2 は順番を管理しないので帯を持たない（[BoardDropRegion]）。
class _OwnerSide extends StatelessWidget {
  const _OwnerSide({required this.label, required this.cards});

  final String label;
  final List<CardInstance> cards;

  @override
  Widget build(BuildContext context) => BoardDropRegion(
        resolve: moveToResolution,
        builder: (context, hovering) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hovering ? '$label — ここへ移す 4.14.1' : '$label（${cards.length}）',
              style: Theme.of(context).textTheme.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: _kResolutionWidth / kCardAspectRatio,
              child: cards.isEmpty
                  ? const SizedBox.expand()
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: cards.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 4),
                      itemBuilder: (_, i) => BoardSlot(
                        width: _kResolutionWidth,
                        child: BoardPiece(
                          drag: ResolutionCardDrag(card: cards[i]),
                          width: _kResolutionWidth,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      );
}

/// 4 章の領域の山（4.6 / 4.7 / 4.10 / 4.12 / 4.13）。
///
/// ★★ 箱には 1 枚、残りは下の帯に出す ★★
/// 順番を管理しない領域（4.1.3）で「一番上」に意味は無いが、
/// 箱に 1 枚しか出せない以上どれかを出すことになる。★リストの先頭を出す。
/// ★4.10 は順番が管理される（4.10.2）ので、先頭が本当に「一番上」である。
class _ZonePile extends StatelessWidget {
  const _ZonePile({
    required this.playerId,
    required this.zone,
    required this.title,
    required this.cards,
  });

  final String playerId;
  final Zone zone;
  final String title;
  final List<CardInstance> cards;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BoardDropSlot(
            key: ValueKey('zone-${zone.name}-$playerId'),
            resolve: (drag, edge) =>
                moveToZone(drag, toPlayerId: playerId, to: zone, edge: edge),
            child: cards.isEmpty
                ? null
                : BoardPiece(
                    drag: ZoneCardDrag(
                      playerId: playerId,
                      zone: zone,
                      card: cards.first,
                    ),
                  ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: kBoardSlotWidth,
            child: Text(
              '$title\n${cards.length}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          if (cards.length > 1)
            _MiniStrip(
              items: [
                for (final card in cards.skip(1))
                  _MiniCard(
                    card: card,
                    drag: ZoneCardDrag(
                      playerId: playerId,
                      zone: zone,
                      card: card,
                    ),
                  ),
              ],
            ),
        ],
      );
}

/// 手札（4.11）の帯。
///
/// ★★ 一人回しでは両者の手札が見える（決定 D77 / D84）★★
/// 4.11.2 は「自分の手札のカードは自分のみが自由に確認できます」だが、
/// **一人回しは 1 人が両プレイヤーを操作する**。`redact` を掛けると
/// 相手側を操作できなくなる。対戦（Phase 6）ではサーバが `redact` を掛けて配る。
///
/// ★★ 秘匿に `viewerId` を使っていない ★★
/// この帯は上段でも下段でも同じものを出す。**視点は向きだけを決める**（D75 / D77）。
/// `test/board/board_secrecy_test.dart` が、視点を切り替えても
/// どちらの手札も隠れないこと・4.8 / 4.9 は隠れたままであることを固定している。
///
/// ★★ 「Phase 6 で分岐が要らない」が成立する条件（未決 **U18**）★★
/// 対戦ではサーバが `redact` を掛けた `GameState` を配るので、
/// 相手の手札は **`isRedacted == true` の [CardInstance]** として届く。
/// `HiddenPile` は枚数しか受け取らない設計（D77）だが、**この帯は
/// [CardInstance] のリストを受け取る。**秘匿された札が混ざったときに
/// 何を描くかは**まだ決めていない**（判断時期は Phase 6 / 盤面設計メモ §13）。
/// ★決めていないことを書いておかないと、Phase 6 で「話が違う」になる。
class _HandStrip extends StatelessWidget {
  const _HandStrip({required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);
    final player = view.state.playerOf(playerId);
    final theme = Theme.of(context);

    return BoardDropRegion(
      resolve: (drag) => moveToZone(
        drag,
        toPlayerId: playerId,
        to: Zone.hand,
        // ★4.11.2 は順番を管理しないので上下に意味が無い。
        edge: DropEdge.leading,
      ),
      builder: (context, hovering) => DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          border: Border.all(
            color: hovering ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            key: ValueKey('hand-$playerId'),
            children: [
              SizedBox(
                width: 84,
                child: Text(
                  '${view.labelOf(playerId)}の手札 4.11\n${player.hand.length} 枚',
                  style: theme.textTheme.labelSmall,
                ),
              ),
              Expanded(
                child: SizedBox(
                  height: _kHandWidth / kCardAspectRatio,
                  child: player.hand.isEmpty
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            hovering ? 'ここへ入れる 4.11' : '手札がありません',
                            style: theme.textTheme.labelSmall,
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: player.hand.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 4),
                          itemBuilder: (_, i) => BoardSlot(
                            width: _kHandWidth,
                            child: BoardPiece(
                              // ★4.11 は手札。裏向きで配られていても
                              //   持ち主は見られるので表として出す（D37 / D77）。
                              //   ★だから 4.11 に反転の口を出さない（観測差が無い）。
                              drag: ZoneCardDrag(
                                playerId: playerId,
                                zone: Zone.hand,
                                card: player.hand[i]
                                    .copyWith(face: FaceState.faceUp),
                              ),
                              width: _kHandWidth,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ★ルール外の 2 置き場（6.2.1.6 の脇置き / フリーエリア）。
///
/// ★★ 4 章の領域と同じ見た目にしない ★★
/// `Zone` と `OutOfRuleZone` を別の型に分けた 3a-1 の拘束を UI でも守る。
///
/// ★★ 落とせるのはフリーエリアだけ（M-B2）★★
/// 6.2.1.6 の脇置きは**その手順の中にしか存在しない**（`zone.dart`）。
/// マリガンは M-B5 なので、いまは枚数だけ出す。
class _OutOfRuleRow extends StatelessWidget {
  const _OutOfRuleRow();

  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);
    final theme = Theme.of(context);

    int asideCount(String playerId) =>
        cardsInOutOfRule(view.state, playerId, OutOfRuleZone.mulliganAside)
            .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '盤の外（ルールの領域ではありません）: '
          '脇置き 6.2.1.6 = ${asideCount(view.viewerId) + asideCount(view.opponent.playerId)} 枚',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final playerId in [
              view.viewer.playerId,
              view.opponent.playerId,
            ]) ...[
              Expanded(child: _FreeArea(playerId: playerId)),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}

/// フリーエリア。★ルールにはまったく存在しない置き場（`zone.dart`）。
class _FreeArea extends StatelessWidget {
  const _FreeArea({required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);
    final theme = Theme.of(context);
    final cards =
        cardsInOutOfRule(view.state, playerId, OutOfRuleZone.freeArea);

    return BoardDropRegion(
      resolve: (drag) => moveToOutOfRule(
        drag,
        playerId: playerId,
        to: OutOfRuleZone.freeArea,
      ),
      builder: (context, hovering) => DecoratedBox(
        decoration: BoxDecoration(
          // ★4 章の領域と見た目を変える（枠を破線ではなく点線風の薄い色に）。
          border: Border.all(
            color: hovering
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: hovering ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            key: ValueKey('free-area-$playerId'),
            children: [
              SizedBox(
                width: 96,
                child: Text(
                  '${view.labelOf(playerId)}のフリーエリア\n'
                  '★ルール外 / ${cards.length} 枚',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
              Expanded(
                child: SizedBox(
                  height: _kMiniWidth / kCardAspectRatio,
                  child: cards.isEmpty
                      ? const SizedBox.expand()
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: cards.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 4),
                          itemBuilder: (_, i) => BoardSlot(
                            width: _kMiniWidth,
                            child: BoardPiece(
                              drag: OutOfRuleCardDrag(
                                playerId: playerId,
                                zone: OutOfRuleZone.freeArea,
                                card: cards[i],
                              ),
                              width: _kMiniWidth,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 箱に入りきらない札 1 枚ぶん。
///
/// ★[drag] が null なら掴めない。★**描画は変えない**——
/// 「掴めないこと」を薄い色で表すと、読み込み中と区別がつかなくなる。
/// 掴めない理由は [tag] が示す（「下」= 4.5.5.1 / 「孤児」= 4.5.5.4.1）。
class _MiniCard {
  const _MiniCard({required this.card, this.tag, this.drag, this.onTap});

  final CardInstance card;

  /// 「ほか」/「下」/「孤児」。null なら見出しを出さない。
  final String? tag;

  final BoardDrag? drag;

  /// ★掴めない札にも口を残す。**押しても何も起きない形にしない。**
  final void Function(BuildContext context)? onTap;
}

/// [_MiniCard] を横に並べる帯。★スロットの幅を超えない。
class _MiniStrip extends StatelessWidget {
  const _MiniStrip({required this.items});

  final List<_MiniCard> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ★見出しの高さは実測値に依存させない。
    //   フォントが変わると 1〜2px で溢れる（テスト用フォントで実際に溢れた）。
    const tagHeight = 16.0;

    return SizedBox(
      width: kBoardSlotWidth,
      height: _kMiniWidth / kCardAspectRatio + tagHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 3),
        itemBuilder: (_, i) {
          final item = items[i];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BoardSlot(
                width: _kMiniWidth,
                child: item.drag != null
                    ? BoardPiece(drag: item.drag!, width: _kMiniWidth)
                    : GestureDetector(
                        // ★決定 D46: 押す側も矩形を作る（帯を叩いても開く）。
                        behavior: HitTestBehavior.opaque,
                        onTap: item.onTap == null
                            ? null
                            : () => item.onTap!(context),
                        child: BoardCard(card: item.card, width: _kMiniWidth),
                      ),
              ),
              if (item.tag != null)
                SizedBox(
                  height: tagHeight,
                  // ★`FittedBox` で縮める。溢れをフォント任せにしない。
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(item.tag!, style: theme.textTheme.labelSmall),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
