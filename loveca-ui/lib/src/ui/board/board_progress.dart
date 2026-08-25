/// 進行バーと「次へ」（M-B3 / 決定 D86 / 盤面設計メモ §11）.
///
/// ★★ ステップの順序も分岐先も、ここには 1 つも書かない ★★
/// 遷移の権威は `step.dart` の遷移表だけである（`step.dart` の doc）。
/// このファイルは `GameStore.transitions` / `GameStore.requiresChoice` を読むだけで、
/// **条番号による遷移先を再記述しない。**
/// `test/board/step_authority_test.dart` が走査で固定している。
///
/// ★★ 視点と手番を混ぜない（決定 D75）★★
/// `AdvanceStep` の対象は `turnPlayerOf(state, phase)` から決まり、`viewerId` とは無関係。
/// 7.2.1.2 により手番を指定しないフェイズ（8.2 / 8.4）のアクティブプレイヤーは
/// **先攻**であって視点ではない。**混ぜると 8.4.13 の入れ替え後に手番が誤る。**
///
/// ★★ 分岐は 2 種類あり、扱いが違う ★★
///
/// | 分岐 | 判定主体 | 画面 |
/// |---|---|---|
/// | 8.3.6 | `StepDecision.automatic`（盤面の観測のみ） | ★**選ばせない。**進んだあとに「どちらへ行ったか」を出す |
/// | 8.4.12 | `StepDecision.playerDeclared`（自動能力の誘発有無を含む / D-A） | ★**2 択を出す。**文言は遷移表の `label` をそのまま使う |
///
/// ★どちらの条番号もここに書かない。`requiresChoice` が答える。
///
/// ★★ `Wrap` で組む ★★
/// 盤面は最小幅を下回ると横スクロールするが（D75）、この行はスクロールしない。
/// 固定の `Row` にすると窓を狭めたときに溢れ、`kBoardMinWidth`（D83）を押し上げる。
/// ★★ 飛ばしたステップを黙らない（決定 D88 / 盤面設計メモ §14-3）★★
/// ソロでは 1 回の「次へ」で**4 フェイズを跨ぐ**ことがある。出さないと
/// 「勝手に飛んだ」ように見える。★8.3.6 の早期終了で既に学んだ形である（D86）。
/// ★**フェイズ単位にまとめて条番号のまま出す。**`StepId` の enum 名を UI に書かない
/// （`test/board/step_authority_test.dart` が走査で禁じている）。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart';

import '../../state/game_store.dart';
import 'board_view.dart';

/// 進行バー。ターン / フェイズ / ステップ（条番号）/ 手番 / 先攻 / 次へ。
class BoardProgressBar extends StatelessWidget {
  const BoardProgressBar({super.key, required this.board, required this.store});

  final BoardState board;
  final GameStore store;

  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);
    final theme = Theme.of(context);
    final state = board.state;
    // ★手番は `turnPlayerOf` から取る。`viewerId` から取らない（決定 D75）。
    final turnPlayer = turnPlayerOf(state, state.cursor.phase);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            key: const ValueKey('progress-bar'),
            spacing: 16,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('ターン ${state.turnNumber}', style: theme.textTheme.labelLarge),
              // ★フェイズ名は網羅 switch。内部語彙（enum の名前）を出さない。
              Text('${phaseLabel(state.cursor.phase)} ${state.cursor.phase.ruleRef}',
                  style: theme.textTheme.labelMedium),
              // ★条番号をそのまま出す。ステップ ID は条番号そのもの（3a-3）。
              Text('ステップ ${state.cursor.step.ruleRef}',
                  style: theme.textTheme.labelMedium),
              Text(
                turnPlayer == null
                    ? '手番: なし（7.2.1.2）'
                    : '手番: ${view.labelOf(turnPlayer)}',
                style: theme.textTheme.labelMedium,
              ),
              Text('先攻: ${view.labelOf(state.firstPlayerId)}',
                  style: theme.textTheme.labelMedium),
              _AdvanceControls(store: store),
            ],
          ),
          if (board.operation case final operation?) ...[
            _LastOperationLine(operation: operation),
            // ★★ 「直前」行に混ぜない ★★
            //   4 フェイズぶん並ぶことがあるので、混ぜると直前の遷移が読めなくなる。
            _SkippedLine(skipped: operation.skipped),
          ],
        ],
      ),
    );
  }
}

/// 「次へ」。★8.4.12 のように宣言が要る分岐では 2 択に置き換わる。
class _AdvanceControls extends StatelessWidget {
  const _AdvanceControls({required this.store});

  final GameStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!store.requiresChoice) {
      return FilledButton.icon(
        key: const ValueKey('advance-step'),
        onPressed: () => store.dispatch(const AdvanceStep()),
        icon: const Icon(Icons.skip_next, size: 18),
        label: const Text('次へ'),
      );
    }

    // ★★ 文言は遷移表の `label` をそのまま出す ★★
    //   UI に選択肢を書くと、遷移表を直したときに片方だけ古くなる（D-15）。
    return Wrap(
      key: const ValueKey('advance-choice'),
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Tooltip(
          message: '自動能力の誘発があるかはアプリが判定しません（CLAUDE.md §1 / D-A）。'
              'あなたが宣言してください。',
          child: Text('${store.value.state.cursor.step.ruleRef} の判定:',
              style: theme.textTheme.labelMedium),
        ),
        for (final transition in store.transitions)
          FilledButton.tonal(
            key: ValueKey('advance-choice-${transition.label}'),
            onPressed: () => store.dispatch(AdvanceStep(choice: transition)),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              textStyle: theme.textTheme.labelMedium,
            ),
            child: Text(transition.label),
          ),
      ],
    );
  }
}

/// 直前の 1 操作で何が起きたか。
///
/// ★★ 8.3.6 の早期終了がここで読める ★★
/// 盤面の観測だけで自動判定した分岐なので、**どちらへ行ったかを出さないと
/// 「勝手に飛んだ」ように見える。**
///
/// ★★ 割り込みリフレッシュ（10.2.1）も出す ★★
/// エールの途中で起きうる（8.3.11）。ステップの境界を無視して割り込むので、
/// 出さないと「いつのまにか控え室が空になっている」ように見える。
class _LastOperationLine extends StatelessWidget {
  const _LastOperationLine({required this.operation});

  final BoardOperationLog operation;

  @override
  Widget build(BuildContext context) {
    if (operation.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    final parts = <String>[
      if (operation.taken case final taken?)
        '${operation.cursorBefore.step.ruleRef} → '
            '${taken.endsPhase ? 'フェイズ終了' : taken.target!.ruleRef}'
            '${taken.label.isEmpty ? '' : '（${taken.label}）'}',
      if (operation.refreshCount > 0)
        'リフレッシュが ${operation.refreshCount} 回割り込みました'
            '（10.2.1。処理を中断して実行し、続きを実行します）',
    ];

    return Padding(
      // ★キーは外側に置く。`Text` 自身に付けると `find.descendant` で辿れない。
      key: const ValueKey('last-operation'),
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        '直前: ${parts.join(' / ')}',
        style: theme.textTheme.labelSmall,
      ),
    );
  }
}

/// フェイズの呼び名。
///
/// ★★ 網羅 switch にする ★★
/// `Map` や `name` の加工にすると、`PhaseId` に枝が増えたとき
/// **コンパイルが通ったまま無言で穴が空く**。12 個ちょうどであること（7.1.2 / 7.3.3 /
/// 8.1.2）は `loveca_core` 側のテストが固定しているので、ここは名前だけを持つ。
///
/// ★条番号はここに書かない。`PhaseId.ruleRef` から取る（同じ数を 2 箇所に書かない）。
String phaseLabel(PhaseId phase) => switch (phase) {
      PhaseId.firstActive => '先攻アクティブ',
      PhaseId.firstEnergy => '先攻エネルギー',
      PhaseId.firstDraw => '先攻ドロー',
      PhaseId.firstMain => '先攻メイン',
      PhaseId.secondActive => '後攻アクティブ',
      PhaseId.secondEnergy => '後攻エネルギー',
      PhaseId.secondDraw => '後攻ドロー',
      PhaseId.secondMain => '後攻メイン',
      PhaseId.liveCardSet => 'ライブカードセット',
      PhaseId.firstPerformance => '先攻パフォーマンス',
      PhaseId.secondPerformance => '後攻パフォーマンス',
      PhaseId.liveJudgement => 'ライブ勝敗判定',
    };

/// ★★ ソロで通らなかったステップ（決定 D88 / 盤面設計メモ §14-4）★★
///
/// ★フェイズ単位にまとめる。のべ 31 ステップを 1 行に並べると読めない。
/// ★条文が定める分岐（8.3.6 の早期終了 / 8.4.12 のループ）とは**別物**なので、
/// 「相手が居ないため」という理由を必ず添える。混ぜて読まれると D86 の意味が消える。
class _SkippedLine extends StatelessWidget {
  const _SkippedLine({required this.skipped});

  final List<StepCursor> skipped;

  @override
  Widget build(BuildContext context) {
    if (skipped.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    // ★並び順は通る順のまま保つ（どこを飛んだかが読めるように）。
    final byPhase = <PhaseId, List<String>>{};
    for (final cursor in skipped) {
      (byPhase[cursor.phase] ??= []).add(cursor.step.ruleRef);
    }

    final parts = [
      for (final entry in byPhase.entries)
        // ★フェイズを丸ごと飛ばしたか、その中の一部かで書き分ける。
        entry.value.length == entry.key.steps.length
            ? '${phaseLabel(entry.key)} ${entry.key.ruleRef}（全体）'
            : '${phaseLabel(entry.key)} ${entry.key.ruleRef} の '
                '${entry.value.join(' / ')}',
    ];

    return Padding(
      key: const ValueKey('skipped-steps'),
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        '通らなかった手順（ソロには相手が居ないため）: ${parts.join(' / ')}',
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.outline),
      ),
    );
  }
}
