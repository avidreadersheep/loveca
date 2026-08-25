/// メインデッキ置き場を上から見る（M-B3 / 総合ルール 5.7.1 / 10.2.2.2）.
///
/// ★★ これは「一時的な開示」であって常設の一覧ではない（決定 D77 / 盤面設計メモ §5-3）★★
/// 4.8.2 によりメインデッキ置き場は**すべてのプレイヤーに対して非公開領域**で、
/// 盤面は中身を出さない。5.7.1「指定プレイヤーはそのメインデッキ置き場の
/// 一番上から（数値）枚の情報を知ることができます」がこの開示の唯一の根拠である。
/// → **ダイアログで出し、閉じたら消える。**盤面には残さない。
///
/// ★★ 順番は変わらない ★★
/// 5.7.1 は「情報を知ることができます」としか書いていない。並べ替えも移動もしない。
/// ★見たあとに何をするかはプレイヤーが別の操作で行う（`LookAtTop` の doc）。
///
/// ★★ 10.2.2.2 のリフレッシュは**見る前**に起きる ★★
/// 「メインデッキ置き場を上から見る指示があり、メインデッキ置き場にあるカードの枚数が、
/// その指示で指定された数値未満の場合に実行されます」。
/// → `LookAtTop` を dispatch してから中身を読む。順を逆にすると足りないまま読む。
///
/// ★★ 足りなければ「足りない」と出す ★★
/// 控え室も空ならリフレッシュできず、引ける枚数は指定より少なくなる（`refresh.dart`）。
/// **黙って少なく出さない。**
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;

import '../common/card_thumb.dart';
import 'board_deck_menu.dart';
import 'board_slot.dart';
import 'board_view.dart';

/// 枚数を尋ね、10.2.2.2 を通してから上から N 枚を出す。
Future<void> lookAtTopOfMainDeck(
  BuildContext context, {
  required String playerId,
}) async {
  final view = BoardView.of(context);
  final store = view.store;

  final count = await promptCardCount(
    context,
    title: 'メインデッキ置き場を上から何枚見ますか',
    description: '5.7.1 は「一番上から（数値）枚の情報を知ることができます」。'
        '見ても並びは変わりません。'
        '枚数が足りない場合は 10.2.2.2 によりリフレッシュしてから見ます。',
  );
  if (count == null || !context.mounted) return;

  // ★★ 順を逆にしない。先に 10.2.2.2 を通す ★★
  store.dispatch(LookAtTop(playerId: playerId, count: count));
  final refreshed = store.value.operation?.refreshCount ?? 0;
  final cards = store.topOfMainDeck(playerId, count);

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    // ★★ ダイアログは `Navigator` の別のサブツリーなので視点を配り直す ★★
    //   ★ここで `BoardView.of(context)` を呼ばない —— その context の祖先に
    //   `BoardView` は無く、**開いた瞬間に落ちる**（実際に落ちた）。
    //   外で掴んだ `view` を配る（`board_stack_choice.dart` と同じ形）。
    builder: (context) => view.provideTo(
      _LookAtTopDialog(
        playerId: playerId,
        requested: count,
        cards: cards,
        refreshCount: refreshed,
      ),
    ),
  );
}

class _LookAtTopDialog extends StatelessWidget {
  const _LookAtTopDialog({
    required this.playerId,
    required this.requested,
    required this.cards,
    required this.refreshCount,
  });

  final String playerId;
  final int requested;
  final List<CardInstance> cards;
  final int refreshCount;

  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      key: const ValueKey('look-at-top'),
      title: Text('${view.labelOf(playerId)}のメインデッキ置き場の上から '
          '${cards.length} 枚（4.8 / 5.7.1）'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (refreshCount > 0)
              Text(
                '★枚数が足りなかったのでリフレッシュしました'
                '（10.2.2.2 → 10.2.3。控え室をシャッフルしてメインデッキ置き場の下へ）。',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            if (cards.length < requested)
              Text(
                // ★黙って少なく出さない。
                '★$requested 枚を指定しましたが ${cards.length} 枚しかありません。'
                '控え室も空なのでリフレッシュ（10.2）できません。',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            const SizedBox(height: 8),
            if (cards.isEmpty)
              Text('メインデッキ置き場は空です。', style: theme.textTheme.bodySmall)
            else
              SizedBox(
                height: kBoardSlotWidth / kCardAspectRatio + 20,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: cards.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, i) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BoardSlot(
                        // ★4.3.3.2 の裏向きのまま描くと中身が読めない。
                        //   5.7.1 の開示なので表として出す。
                        child: BoardCard(
                          card: cards[i].copyWith(face: FaceState.faceUp),
                        ),
                      ),
                      SizedBox(
                        width: kBoardSlotWidth,
                        child: Text('${i + 1} 枚目',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              '★見ただけでは並びは変わりません（5.7.1）。'
              '動かすときは閉じてから盤面で操作してください。',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          key: const ValueKey('look-at-top-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
