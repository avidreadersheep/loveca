/// 6.2.1.6 マリガン（決定 D93 / M-B6 / 盤面設計メモ §9-2）.
///
/// > **6.2.1.6** 先攻プレイヤーから順に、各プレイヤーは自身の手札のカードを
/// > 任意の枚数選んで裏向きに脇に置き、置いた枚数と同じ枚数のカードを
/// > 自身のメインデッキ置き場の上から自身の手札に移動し、
/// > 脇に置いたカードをメインデッキ置き場に移動し、
/// > 1 枚以上移動した場合はシャッフルします。
///
/// ## ★★ ここは盤面ではない。`GameStore` はまだ存在しない ★★
///
/// マリガンは `GameSetup.begin` と `dealInitialEnergy` の**あいだ**に入る（D80）。
/// その時点で `GameStore` も `BoardView` も無いので、
/// **`BoardPiece` / `BoardDropSlot` / `applyBoardMove` は 1 つも使えない。**
/// → 選択は**タップのトグル**で行い、移動は `loveca_core` の
/// `GameSetup.mulligan` が担う。
///
/// ## ★★ 脇置き（`OutOfRuleZone.mulliganAside`）の落とし先を盤面に作らない（決定 D93-2）★★
///
/// `zone.dart` が「この置き場は **6.2.1.6 の手順内にのみ存在し**、置いたカードは
/// 同じ手順の中でメインデッキ置き場へ戻る」と定めている。
/// 盤面に恒久の落とし先を置くと、**6.2.1.6 の外で脇置きにカードが残る**という
/// 条文が定めていない状態を実装が作れてしまう（D-B）。
/// ★`CLAUDE.md` §8 と盤面設計メモ §7-3 が「M-B6 で置く」と書いていたのは**誤り**である。
/// 訂正の経緯は `ルール整合性チェック_v1.06.md` **D-15 (i)**。
///
/// ## ★★ ソロでは相手のぶんを 0 枚として扱う ★★
///
/// ソロでも `GameState.players` は 2 人である（1.1.1 / §14-5）が、
/// **相手はプレイヤーではない**ので選ばせようがない。
/// ★**黙って飛ばさない。**0 枚として扱うことと、その帰結
/// （0 枚なので 5.5.1 のシャッフルが起きず、**乱数も消費しない**）を画面に出す。
/// 6.2.1.4 の 2 段をソロで飛ばすときに理由を出したのと同じ作法（D88）。
///
/// ## ★★ 「やめる」は「0 枚」ではない ★★
///
/// キャンセルしたら**盤面を開かない**。0 枚として開始すると、
/// 選ばなかったのか選ぶのをやめたのかが区別できない。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;

import '../../data/card_image_source.dart';
import '../../data/master_catalog.dart';
import '../../state/board_mode.dart';
import '../common/card_thumb.dart';
import 'board_slot.dart';

/// マリガンのダイアログで 1 枚に使う幅。★盤面のスロットより大きく出す
/// （6 枚を並べて**選ぶ**ための画面であり、盤面のように詰めない）。
const double _kMulliganCardWidth = 96;

/// 6.2.1.6 を選ばせる。
///
/// ★戻り値 `null` = やめる（**盤面を開かない**）。
/// ★[hands] は `GameSetup.handsForMulligan`。**先攻から順**に並んでいる。
Future<List<MulliganChoice>?> showMulliganDialog(
  BuildContext context, {
  required List<MulliganHand> hands,
  required BoardMode mode,
  required MasterCatalog catalog,
  required CardImageSource imageSource,
}) =>
    showDialog<List<MulliganChoice>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MulliganDialog(
        hands: hands,
        mode: mode,
        catalog: catalog,
        imageSource: imageSource,
      ),
    );

class _MulliganDialog extends StatefulWidget {
  const _MulliganDialog({
    required this.hands,
    required this.mode,
    required this.catalog,
    required this.imageSource,
  });

  final List<MulliganHand> hands;
  final BoardMode mode;
  final MasterCatalog catalog;
  final CardImageSource imageSource;

  @override
  State<_MulliganDialog> createState() => _MulliganDialogState();
}

class _MulliganDialogState extends State<_MulliganDialog> {
  /// いま選ばせている段。★0 = 先攻。
  int _index = 0;

  /// playerId -> 脇に置く instanceId。
  final _selected = <String, Set<String>>{};

  /// ★★ 選ばせる相手（決定 D88 / §14-5）★★
  /// ソロは**先攻（＝ 自分）だけ**。相手側は 0 枚として扱う。
  List<MulliganHand> get _asked =>
      widget.mode.hasOpponent ? widget.hands : widget.hands.take(1).toList();

  MulliganHand get _current => _asked[_index];

  Set<String> get _currentSelection =>
      _selected.putIfAbsent(_current.playerId, () => <String>{});

  bool get _isLast => _index == _asked.length - 1;

  /// ★選ばなかったプレイヤーも `choices` に載せる（0 枚として明示する）。
  List<MulliganChoice> get _result => [
        for (final hand in widget.hands)
          MulliganChoice(
            playerId: hand.playerId,
            // ★手札のリスト順に並べ替えて渡す。
            //   ★`GameSetup.mulligan` 側もリスト順で置くので結果は変わらないが、
            //   **渡す側でも順を決めておく**（選んだ順を運ばない）。
            instanceIds: [
              for (final card in hand.hand)
                if (_selected[hand.playerId]?.contains(card.instanceId) ?? false)
                  card.instanceId,
            ],
          ),
      ];

  /// 表示用の呼び名。★playerId を画面に出さない（内部語彙）。
  ///
  /// ★★ 盤面の `BoardView.labelOf` は `viewerId` を基準にするが、ここは違う ★★
  /// マリガンは 6.2.1.4 の**あと**なので、意味を持つのは**先攻 / 後攻**である。
  /// ★開始ダイアログで先攻を決めた直後にこの画面が出るので、その語のまま続ける。
  String _labelOf(int index) => index == 0 ? '先攻' : '後攻';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hand = _current;
    final selection = _currentSelection;

    return AlertDialog(
      key: const ValueKey('mulligan-dialog'),
      title: Text('${_labelOf(_index)}のマリガン 6.2.1.6'
          '（${_index + 1} / ${_asked.length}）'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '手札のカードを**任意の枚数**選んで裏向きに脇に置き、'
                '同じ枚数をメインデッキ置き場の上から引き直します。'
                '★選ばなかった場合（0 枚）も 6.2.1.6 は成立します。',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                // ★★ 何が起きるかを枚数に応じて出す ★★
                //   「1 枚以上移動した場合はシャッフルします」は**分岐**なので、
                //   起きる側と起きない側の両方を読めるようにする。
                selection.isEmpty
                    ? '★いまは 0 枚です。1 枚も戻さないので、'
                        'メインデッキ置き場のシャッフル（5.5.1）は行われません。'
                    : '★${selection.length} 枚を戻すので、'
                        'そのあとメインデッキ置き場をシャッフルします（5.5.1）。',
                key: const ValueKey('mulligan-shuffle-note'),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
              if (!widget.mode.hasOpponent) ...[
                const SizedBox(height: 4),
                Text(
                  // ★★ 黙って飛ばさない（決定 D88）★★
                  'ソロでは相手がいないので、相手側は 0 枚として扱います。'
                  '★0 枚なのでシャッフル（5.5.1）は行われず、乱数も消費しません。',
                  key: const ValueKey('mulligan-solo-note'),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
              const SizedBox(height: 10),
              Text('手札 ${hand.hand.length} 枚 / 選択 ${selection.length} 枚',
                  key: const ValueKey('mulligan-count'),
                  style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              if (hand.hand.isEmpty)
                Text('手札がありません。', style: theme.textTheme.bodySmall)
              else
                Wrap(
                  key: ValueKey('mulligan-hand-${hand.playerId}'),
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final card in hand.hand)
                      _MulliganCard(
                        card: card,
                        catalog: widget.catalog,
                        imageSource: widget.imageSource,
                        chosen: selection.contains(card.instanceId),
                        onTap: () => setState(() {
                          if (!selection.remove(card.instanceId)) {
                            selection.add(card.instanceId);
                          }
                        }),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              Text(
                '★脇に置いたカードは同じ手順の中でメインデッキ置き場へ戻ります。'
                'この置き場は 6.2.1.6 の手順内にしか存在しないので、盤面には出ません。',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('mulligan-cancel'),
          // ★★ 「やめる」は「0 枚」ではない ★★ 盤面を開かない。
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('やめる'),
        ),
        if (!_isLast)
          FilledButton(
            key: const ValueKey('mulligan-next'),
            onPressed: () => setState(() => _index++),
            // ★次が誰かをラベルに出す（6.2.1.6「先攻プレイヤーから順に」）。
            child: Text('${_labelOf(_index + 1)}へ'),
          )
        else
          FilledButton(
            key: const ValueKey('mulligan-done'),
            onPressed: () => Navigator.of(context).pop(_result),
            child: Text(selection.isEmpty ? '0 枚で決定' : '${selection.length} 枚で決定'),
          ),
      ],
    );
  }
}

/// 手札の 1 枚。★選ぶ / 選ばないをタップでトグルする。
///
/// ★★ 4.11.2 により手札は本人が確認できる ★★
/// 配られた札は 4.1.2.1 により裏向き（4.11.2 は非公開領域）だが、
/// **選ぶ本人には見えていなければならない**ので表として描く。
/// 盤面の手札の帯が `copyWith(face: faceUp)` しているのと同じ扱い。
class _MulliganCard extends StatelessWidget {
  const _MulliganCard({
    required this.card,
    required this.catalog,
    required this.imageSource,
    required this.chosen,
    required this.onTap,
  });

  final CardInstance card;
  final MasterCatalog catalog;
  final CardImageSource imageSource;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      key: ValueKey('mulligan-card-${card.instanceId}'),
      onTap: onTap,
      // ★★ 押せる矩形を絵に頼らない（決定 D46）★★
      //   ライブの札は枠の上下に透明な帯が残るので、絵だけでは押せない。
      child: Container(
        color: chosen ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        padding: const EdgeInsets.all(3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _kMulliganCardWidth,
              height: _kMulliganCardWidth / kCardAspectRatio,
              child: BoardCardArt(
                card: card,
                catalog: catalog,
                imageSource: imageSource,
                width: _kMulliganCardWidth,
              ),
            ),
            SizedBox(
              width: _kMulliganCardWidth,
              child: Text(
                chosen ? '★脇に置く' : '手札に残す',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
