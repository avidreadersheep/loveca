/// 盤面のレイアウト（決定 D75 / 盤面設計メモ §4）.
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
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart';

import '../common/card_thumb.dart';
import 'board_slot.dart';
import 'board_view.dart';
import 'hidden_pile.dart';

/// 盤面の本体。★上段が相手、下段が視点（決定 D75）。
class BoardLayout extends StatelessWidget {
  const BoardLayout({super.key, required this.onDrawEnergy});

  /// 「エネルギーを1枚出す」（決定 D73 / D81）。null なら押せない。
  final VoidCallback? onDrawEnergy;

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
        final width = constraints.maxWidth < kBoardMinWidth
            ? kBoardMinWidth
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
                          // ---- ★相手の手札。一人回しでは中身も見える（D77）----
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
          HiddenPile(
            key: ValueKey('pile-main-$playerId'),
            title: 'メインデッキ',
            ruleRef: '4.8',
            count: player.mainDeck.length,
          ),
          const SizedBox(height: 8),
          HiddenPile(
            key: ValueKey('pile-energy-$playerId'),
            title: 'エネルギーデッキ',
            ruleRef: '4.9',
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
          _ZoneStack(
            playerId: playerId,
            zone: Zone.energyField,
            title: 'エネルギー',
            cards: player.energyField,
          ),
          const SizedBox(height: 8),
          _ZoneStack(
            playerId: playerId,
            zone: Zone.waitingRoom,
            title: '控え室',
            cards: player.waitingRoom,
          ),
          const SizedBox(height: 8),
          _ZoneStack(
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
      _ZoneStack(
        playerId: playerId,
        zone: Zone.liveStage,
        title: 'ライブ 4.6',
        cards: player.liveStage,
      ),
      _ZoneStack(
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

class _MemberSlot extends StatelessWidget {
  const _MemberSlot({required this.playerId, required this.area});

  final String playerId;
  final MemberArea area;

  @override
  Widget build(BuildContext context) {
    // ★4.5.5.4.1 / 4.5.5.4.2 の孤児カードと 10.4 待ちの重複メンバーは
    //   **正規の中間状態**であってエラーではない（`member_area.dart`）。
    //   M-B1 では枚数だけ添える。整理の案内は M-B5。
    final extra = area.stacks.length > 1 || area.orphans.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BoardSlot(
          key: ValueKey('member-$playerId-${area.slot.name}'),
          label: area.slot.label,
          child: area.stacks.isEmpty
              ? null
              : BoardCard(card: area.stacks.last.member),
        ),
        if (extra)
          Text(
            'ほか ${area.stacks.length - 1 + area.orphans.length}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
      ],
    );
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
            Expanded(
              child: _OwnerSide(label: '相手のカード', cards: theirs),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OwnerSide(label: '自分のカード', cards: mine),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerSide extends StatelessWidget {
  const _OwnerSide({required this.label, required this.cards});

  final String label;
  final List<CardInstance> cards;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$label（${cards.length}）',
        style: Theme.of(context).textTheme.labelSmall,
      ),
      const SizedBox(height: 2),
      SizedBox(
        height: kBoardSlotWidth / kCardAspectRatio * 0.6,
        child: cards.isEmpty
            ? const SizedBox.shrink()
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cards.length,
                separatorBuilder: (_, _) => const SizedBox(width: 4),
                itemBuilder: (_, i) => BoardSlot(
                  width: kBoardSlotWidth * 0.6,
                  child: BoardCard(
                    card: cards[i],
                    width: kBoardSlotWidth * 0.6,
                  ),
                ),
              ),
      ),
    ],
  );
}

/// 順番を管理しない領域を「重ねずに横に並べる」帯。
///
/// ★4.7.2 / 4.12.2 / 4.13.2 / 4.6.2 はいずれも順番を管理しない。
/// **並べ替えの口を作らない**（D47 の帯も M-B2 で出さない / 盤面設計メモ §6-5）。
class _ZoneStack extends StatelessWidget {
  const _ZoneStack({
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
      BoardSlot(
        key: ValueKey('zone-${zone.name}-$playerId'),
        // ★一番上の 1 枚だけ見せる。M-B2 で展開の口を作る。
        child: cards.isEmpty ? null : BoardCard(card: cards.first),
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
    ],
  );
}

/// 手札（4.11）の帯。
///
/// ★★ 一人回しでは両者の手札が見える（決定 D77）★★
/// 4.11.2 は「自分の手札のカードは自分のみが自由に確認できます」だが、
/// **一人回しは 1 人が両プレイヤーを操作する**。`redact` を掛けると
/// 相手側を操作できなくなる。対戦（Phase 6）ではサーバが `redact` を掛けて配る。
class _HandStrip extends StatelessWidget {
  const _HandStrip({required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);
    final player = view.state.playerOf(playerId);
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
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
                height: kBoardSlotWidth / kCardAspectRatio * 0.72,
                child: player.hand.isEmpty
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '手札がありません',
                          style: theme.textTheme.labelSmall,
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: player.hand.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 4),
                        itemBuilder: (_, i) => BoardSlot(
                          width: kBoardSlotWidth * 0.72,
                          child: BoardCard(
                            // ★4.11 は手札。裏向きで配られていても
                            //   持ち主は見られるので表として出す（D37 / D77）。
                            card: player.hand[i].copyWith(
                              face: FaceState.faceUp,
                            ),
                            width: kBoardSlotWidth * 0.72,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ★ルール外の 2 置き場（6.2.1.6 の脇置き / フリーエリア）。
///
/// ★★ 4 章の領域と同じ見た目にしない ★★
/// `Zone` と `OutOfRuleZone` を別の型に分けた 3a-1 の拘束を UI でも守る。
class _OutOfRuleRow extends StatelessWidget {
  const _OutOfRuleRow();

  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);
    final theme = Theme.of(context);

    int count(OutOfRuleZone zone) => [
      for (final player in view.state.players)
        cardsInOutOfRule(view.state, player.playerId, zone).length,
    ].fold(0, (a, b) => a + b);

    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        '盤の外（ルールの領域ではありません）: '
        '脇置き 6.2.1.6 = ${count(OutOfRuleZone.mulliganAside)} 枚 / '
        'フリーエリア = ${count(OutOfRuleZone.freeArea)} 枚',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}
