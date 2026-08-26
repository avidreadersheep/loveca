/// ライブ勝敗の記録 8.4.6 / 8.4.7（決定 D10 / D18 / D25 / D93 / 盤面設計メモ §10-1）.
///
/// ## ★★ アプリは勝敗を計算しない（決定 D10 / D18）★★
///
/// 効果によってライブカードのスコア値が増減しうるので、
/// **アプリは 8.4.3 の比較を代行できない。**8.3.15 / 8.3.16 も出さない。
/// → **プレイヤーが判定して記録する。**アプリが持つのは記録の箱だけである。
///
/// ## ★★ 入力欄を 2 つに分ける（決定 D25 の訂正 / §10-1）★★
///
/// | 欄 | 条 | 何を入れるか |
/// |---|---|---|
/// | **勝者** | 8.4.6 | 8.4.6.1 両者カード無し＝勝者なし / 8.4.6.2 大きい方、★**同点なら両者勝利** |
/// | **移動実績** | 8.4.7 | ★**実際に成功ライブカード置き場へ移動したプレイヤー** |
///
/// ★★ 8.4.13 が参照するのは**勝敗ではなく移動実績**である ★★
/// 「8.4.7 において、**一方のプレイヤーのみが**成功ライブカード置き場にカードを
/// 移動していた場合、そのプレイヤーが先攻プレイヤーとなり…」。
/// 8.4.7.1 により「両者勝利かつライブ置き場に 2 枚あるプレイヤー」は移動しないので、
/// **勝敗で判定すると、同点で片方だけが移動したケースを取りこぼす。**
/// → **1 つの欄にまとめてはいけない。**
///
/// ## ★★ ソロでは口を出さない（決定 D88 / §14-7 の持ち越し 1）★★
///
/// ソロは **8.4.6 と 8.4.13 を飛ばす**（`StepId.requiresOpponent` / §14-4）ので、
/// **記録する対象がどちらも残らない** —— 勝敗は比較相手が居らず、
/// 移動実績を読む 8.4.13 は通らない。
/// ★**黙って消さない。**集計パネルに理由を 1 行残す。
///
/// ## ★★ 恒久で出す。ステップで出し分けない ★★
///
/// `DrawEnergy` と同じ（D81）。★特定のステップでだけ出す形にすると
/// **UI が `StepId` を名指しする**ことになり、`step_authority_test.dart` が
/// 走査で禁じている形になる（遷移の権威は `step.dart` だけ）。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;

import 'board_view.dart';

/// 8.4.6 / 8.4.7 の記録を編集する。
Future<void> showLiveJudgement(BuildContext context) async {
  final view = BoardView.of(context);

  final record = await showDialog<LiveJudgementRecord?>(
    context: context,
    // ★ダイアログは別のサブツリーなので視点を配り直す。
    builder: (context) => view.provideTo(const _LiveJudgementDialog()),
  );
  if (record == null) return;

  // ★★ 「勝者なし・移動なし」は消去ではない ★★
  //   8.4.6.1 は「両方のプレイヤーのライブカード置き場にカードが無い場合、
  //   勝者なし」と定めており、**それ自体が記録である**。
  //   消したいときはダイアログの「記録を消す」を押す（`_cleared` を返す）。
  view.store.dispatch(
      SetLiveJudgement(identical(record, _cleared) ? null : record));
}

/// 「記録を消す」を表す番兵。★`null` は「やめる」に使うので分ける。
const _cleared = LiveJudgementRecord();

class _LiveJudgementDialog extends StatefulWidget {
  const _LiveJudgementDialog();

  @override
  State<_LiveJudgementDialog> createState() => _LiveJudgementDialogState();
}

class _LiveJudgementDialogState extends State<_LiveJudgementDialog> {
  late final _winners = <String>{
    ...?BoardView.of(context).state.liveJudgement?.winnerIds,
  };
  late final _movers = <String>{
    ...?BoardView.of(context).state.liveJudgement?.movedToSuccessIds,
  };

  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      key: const ValueKey('live-judgement'),
      title: const Text('ライブ勝敗の記録 8.4.6 / 8.4.7'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'アプリは勝敗を判定しません（効果でスコアが増減しうるため）。'
                'あなたが判定した結果をここに記録します。',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              _Section(
                ruleRef: '8.4.6',
                title: 'ライブに勝利したプレイヤー',
                note: '★8.4.6.1 両方のライブカード置き場にカードが無ければ「勝者なし」。'
                    '★8.4.6.2 同点なら「両者勝利」（両方を選びます）。',
                keyPrefix: 'winner',
                selected: _winners,
                onToggle: (id) => setState(() =>
                    _winners.contains(id) ? _winners.remove(id) : _winners.add(id)),
              ),
              const SizedBox(height: 12),
              _Section(
                ruleRef: '8.4.7',
                title: '成功ライブカード置き場へ実際に移動したプレイヤー',
                // ★★ ここが 8.4.13 の入力である（決定 D25 の訂正）★★
                note: '★★8.4.13 が参照するのは勝敗ではなくこちらです。★★'
                    '8.4.7.1 により、両者勝利でライブカード置き場に 2 枚ある'
                    'プレイヤーは移動しません。'
                    '★勝者と一致しないことがあるので、欄を分けてあります。',
                keyPrefix: 'mover',
                selected: _movers,
                onToggle: (id) => setState(() =>
                    _movers.contains(id) ? _movers.remove(id) : _movers.add(id)),
              ),
              const SizedBox(height: 12),
              Text(
                _movers.length == 1
                    ? '★いまの記録なら 8.4.13 で先攻が'
                        '${view.labelOf(_movers.single)}になります。'
                    : '★いまの記録では 8.4.13 の入れ替えは起きません'
                        '（「一方のプレイヤーのみが移動していた場合」に当たりません）。',
                key: const ValueKey('live-judgement-effect'),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('live-judgement-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('やめる'),
        ),
        TextButton(
          key: const ValueKey('live-judgement-clear'),
          // ★「勝者なし」（8.4.6.1）と区別する。★消すのは別の操作。
          onPressed: () => Navigator.of(context).pop(_cleared),
          child: const Text('記録を消す'),
        ),
        FilledButton(
          key: const ValueKey('live-judgement-apply'),
          onPressed: () => Navigator.of(context).pop(LiveJudgementRecord(
            winnerIds: _winners,
            movedToSuccessIds: _movers,
          )),
          child: const Text('記録する'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.ruleRef,
    required this.title,
    required this.note,
    required this.keyPrefix,
    required this.selected,
    required this.onToggle,
  });

  final String ruleRef;
  final String title;
  final String note;
  final String keyPrefix;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title $ruleRef', style: theme.textTheme.labelLarge),
        Text(note,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.outline)),
        // ★★ 描くプレイヤーを回す（決定 D88）★★ ソロではここに来ない。
        for (final player in view.drawnPlayers)
          CheckboxListTile(
            key: ValueKey('$keyPrefix-${player.playerId}'),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: selected.contains(player.playerId),
            onChanged: (_) => onToggle(player.playerId),
            title: Text(view.labelOf(player.playerId)),
          ),
      ],
    );
  }
}
