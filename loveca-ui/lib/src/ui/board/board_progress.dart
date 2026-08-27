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
import '../common/degradation_line.dart';
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
              // ★★ 巻き戻しは進行の逆操作なので隣に置く（M-B5 / 決定 D78）★★
              //   段を増やさない（`Wrap` なので狭い窓では縦へ折り返す / U19）。
              _UndoControls(store: store),
              // ★★ 整理は 9.5.3 のチェックタイミングと同じことを手で回す（M-B6）★★
              //   結果はこのすぐ下の「直前の整理」の帯に出るので、隣に置く。
              _TidyButton(store: store),
            ],
          ),
          if (board.operation case final operation?) ...[
            _LastOperationLine(operation: operation),
            // ★★ 「直前」行に混ぜない ★★
            //   成立した理由が複数あるので、混ぜると通過そのものが読めなくなる。
            _StopReasonLine(stops: operation.stops),
            // ★★ 「直前」行に混ぜない ★★
            //   4 フェイズぶん並ぶことがあるので、混ぜると直前の遷移が読めなくなる。
            _SkippedLine(skipped: operation.skipped),
          ],
          if (board.rewind case final rewind?) _LastRewindLine(rewind: rewind),
        ],
      ),
    );
  }
}

/// ★★ 進行の 2 つのボタン（M-B7 / 決定 D92-4）★★
///
/// | | key | 進む量 |
/// |---|---|---|
/// | 「次へ」 | `advance-step` | ★**次の停止点まで**（主） |
/// | 「1 ステップ」 | `advance-one-step` | ★**1 ステップだけ**（恒久・副） |
///
/// ★8.4.12 のように宣言が要る分岐では、「次へ」が 2 択に置き換わる（既存 / D86）。
/// ★**選んだあとも、そのまま次の停止点まで進む。**
///
/// ★★ 設定で切り替えない ★★
/// 挙動の空間が 2 倍になり、検査が**モード 3 × 設定 2** に増える。
/// M-B4 が [BoardMode] を required にして「どのテストがどのモードを試しているかを
/// 型で見せた」利得（D88）が薄まる。
class _AdvanceControls extends StatelessWidget {
  const _AdvanceControls({required this.store});

  final GameStore store;

  @override
  Widget build(BuildContext context) => Wrap(
        key: const ValueKey('advance-controls'),
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (store.requiresChoice)
            _AdvanceChoice(store: store)
          else
            Tooltip(
              message: '次の停止点まで進みます（決定 D92）。\n'
                  '★止まるのは、条文があなたの選択・判断・盤面操作を求めるステップの'
                  '手前と、\n'
                  '　アプリが自動実行しないルール処理（10.3 / 10.6）が新しく成立した'
                  'とき、\n'
                  '　リフレッシュ（10.2.1）が割り込んだとき、ターンが変わったときです。\n'
                  '★1 押下 = 履歴 1 件なので、「1 つ戻す」で押す前に戻ります。',
              child: FilledButton.icon(
                key: const ValueKey('advance-step'),
                onPressed: store.advanceToStop,
                icon: const Icon(Icons.skip_next, size: 18),
                label: const Text('次へ'),
              ),
            ),
          _AdvanceOneStepButton(store: store),
        ],
      );
}

/// ★★ 8.4.12 の 2 択（既存 / 決定 D86）★★
///
/// ★文言は遷移表の `label` をそのまま出す。UI に選択肢を書くと、
/// 遷移表を直したときに片方だけ古くなる（D-15）。
class _AdvanceChoice extends StatelessWidget {
  const _AdvanceChoice({required this.store});

  final GameStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            // ★選んだあとも、そのまま次の停止点まで進む（決定 D92 / §15-7）。
            onPressed: () => store.advanceToStop(choice: transition),
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

/// ★★ 「1 ステップ」は恒久である（決定 D92-4）★★
///
/// ★D81 / D87 が `DrawEnergy` を「恒久である。M-B1 限りの足場ではない」と明記したのと
/// 同じ扱いにする。**書かないと、次に「使われていないから消そう」となる。**
///
/// ★★ 日常的に使うものではない。だが正当な用途が 3 つある（§15-7）★★
///
/// | # | 用途 |
/// |---|---|
/// | 1 | **不具合追跡** —— 1 ステップずつ盤面を見る |
/// | 2 | ★**検査が本番の口を通り続ける** —— 73 / 42 ステップの通し（D86 / D88）が、テストだけの別経路を作らずに成立する |
/// | 3 | ★**自動進行の途中へ戻りたいとき**（1 押下 = 1 undo の代償の退避先） |
///
/// ★★ 2 つのボタンは役割分担している ★★
/// 「まとめて進む」と「細かく進む」であり、**細かく戻したいときは細かく進む。**
/// 片方だけを見て消さないこと。
///
/// ★★ 8.4.12 では無効にして理由を出す ★★
/// 宣言が要る分岐なので 1 ステップだけ進める口が無い。
/// **黙って効かないボタンを作らない**（`_UndoButton` / `_DrawEnergyButton` と同じ形）。
class _AdvanceOneStepButton extends StatelessWidget {
  const _AdvanceOneStepButton({required this.store});

  final GameStore store;

  @override
  Widget build(BuildContext context) {
    final blocked = store.requiresChoice;
    return Tooltip(
      message: blocked
          ? 'ここはどちらへ進むかの宣言が要るので、1 ステップだけ進めることは'
              'できません。左の 2 択から選んでください。'
          : '1 ステップだけ進みます（${store.value.state.cursor.step.ruleRef}）。\n'
              '★日常的に使うものではありません。1 ステップずつ盤面を見たいときと、\n'
              '　自動進行の途中へ戻したいとき（細かく戻すには細かく進む）に使います。',
      child: OutlinedButton.icon(
        key: const ValueKey('advance-one-step'),
        onPressed: blocked ? null : () => store.dispatch(const AdvanceStep()),
        icon: const Icon(Icons.chevron_right, size: 18),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: Theme.of(context).textTheme.labelMedium,
        ),
        label: const Text('1 ステップ'),
      ),
    );
  }
}

/// ★★ 整理を手で回す（M-B6 / 決定 D93 / 総合ルール 10.4 / 10.5）★★
///
/// ★★ なぜ手で回す口が要るのか ★★
/// 整理はチェックタイミング（9.5.3）で自動的に走るが、
/// **ソロは 1 ターンに CT が 12 個減る**（後攻フェイズが無い / §14-4）ので、
/// 孤児カード（4.5.5.4.1）や重複メンバー（10.4）が残る時間が長い。
/// ★これは条文どおりの帰結であって不具合ではない。だから**消す口**を別に置く。
///
/// ★★ 10.3 と 10.6 は実行しない ★★
/// 10.3（勝利処理）は決定 D10 により手動、10.6（不正解決領域処理）は
/// 「プレイ中 / 解決中」が観測できない（D-A）ため。**警告に留まる。**
/// ★出さないものを Tooltip に書く —— 押した人が「勝ちになるはずでは」と迷わないように。
///
/// ★★ 当たるものが無くても黙らない ★★
/// `BoardTidyLog.manual` が立つので `TidyFoundNothing` の行が出る。
/// **押して何も起きない形にしない。**
///
/// ★★ 10.3 / 10.6 の警告が出ていても、それとは別に出る（決定 D94-2）★★
/// 警告は**押す前から成立している盤面の条件**であって押した結果ではないので、
/// 「10.4 / 10.5 は空振りだった」を抑止しない。
/// ★**ただしカードデータを引けない札があったときは出さない** ——
/// 当たらなかったのか判定できなかったのかを区別できないため（D-10）。
/// ★Tooltip には**なぜそうなるか**まで書く。結論だけだと、警告が出ているときに
/// 「ありませんでした」が出る / 出ない理由が読めない。
///
/// ★★ 無効にしない ★★
/// 「当たるものがあるか」を先に計算して無効化すると、
/// **押す前に整理を 1 回走らせる**ことになり、毎 build のコストが増える。
/// ★`undo` と違って**着地先を先に見せる価値も薄い**（結果は帯に出る）。
class _TidyButton extends StatelessWidget {
  const _TidyButton({required this.store});

  final GameStore store;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'いまの盤面にルール処理（10.4 重複メンバー / 10.5 不正なカード）を'
            '1 回適用します。\n'
            '★10.3 勝利処理と 10.6 不正解決領域処理は実行しません（警告だけ出します）。\n'
            '★10.4 / 10.5 が空振りなら「ありませんでした」と出ます。\n'
            '　上の警告が出ていても、それとは別に出ます'
            '（警告は押す前から成立している盤面の条件で、押した結果ではありません）。\n'
            '★ただしカードデータを引けない札があったときは出しません'
            '（当たらなかったのか判定できなかったのかを区別できないため）。',
        child: OutlinedButton.icon(
          key: const ValueKey('tidy-button'),
          onPressed: () => store.dispatch(const Tidy()),
          icon: const Icon(Icons.cleaning_services_outlined, size: 18),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            textStyle: Theme.of(context).textTheme.labelMedium,
          ),
          // ★条番号はラベルに出す（D90-3。Tooltip はマウスを乗せないと出ない）。
          label: const Text('整理する 10.4 / 10.5'),
        ),
      );
}

/// ★★ 巻き戻し（決定 D78 / 盤面設計メモ §8-1）★★
///
/// ★★ 2 つを 1 つのボタンにしない ★★
/// `undo` は直前の 1 操作を取り消し、`undoStep` は**そのステップの入口**または
/// **1 つ前のステップ**へ着地する。**着地先が違うものを同じボタンにしない。**
///
/// ★★ 着地先を Tooltip だけに置かない ★★
/// D78 の目的は「**押す前に**着地先が分かる」ことだが、Tooltip はマウスを
/// 乗せないと出ない。→ **条番号はボタンのラベル自身に出し**、
/// フェイズ名・ターン番号・「入口かどうか」を Tooltip に置く。
/// ★タッチ環境（Phase 5）では Tooltip が出ない。着地先は読めるが**無効の理由が
/// 読めなくなる** → `docs/UI設計メモ.md` §7 に記録した（判断は Phase 5）。
///
/// ★★ 戻せないときも消さない ★★
/// 無効にして理由を出す（`_DrawEnergyButton` と同じ形）。
/// 黙って効かないボタンを作らない。
///
/// ★★ `StepId` の enum 名をここに書かない ★★
/// `test/board/step_authority_test.dart` が走査で禁じている。
/// 着地先は `StepCursor` の `ruleRef` と [phaseLabel] から組む。
class _UndoControls extends StatelessWidget {
  const _UndoControls({required this.store});

  final GameStore store;

  @override
  Widget build(BuildContext context) {
    final canUndo = store.canUndo;
    final current = store.value.state.cursor;
    final undoTarget = canUndo ? store.undoTarget : null;
    final stepTarget = canUndo ? store.undoStepTarget : null;
    final stepIsEntrance = stepTarget != null && stepTarget.cursor == current;

    return Wrap(
      key: const ValueKey('undo-controls'),
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _UndoButton(
          buttonKey: const ValueKey('undo-button'),
          icon: Icons.undo,
          label: '1 つ戻す',
          target: undoTarget,
          // ★1 操作戻すときの着地先は「その操作を行った時点」であり、
          //   ステップの入口とは限らない。
          entrance: false,
          onPressed: canUndo ? store.undo : null,
        ),
        _UndoButton(
          buttonKey: const ValueKey('undo-step-button'),
          icon: Icons.first_page,
          label: '1 ステップ戻す',
          target: stepTarget,
          entrance: stepIsEntrance,
          onPressed: canUndo ? store.undoStep : null,
        ),
      ],
    );
  }
}

class _UndoButton extends StatelessWidget {
  const _UndoButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.target,
    required this.entrance,
    required this.onPressed,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final GameState? target;
  final bool entrance;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final landing = target;
    final where = landing == null
        ? null
        : entrance
            ? 'このステップ（${landing.cursor.step.ruleRef}）の入口へ戻ります'
                '（ターン ${landing.turnNumber}）'
            : '${phaseLabel(landing.cursor.phase)} ${landing.cursor.phase.ruleRef} の '
                '${landing.cursor.step.ruleRef} へ戻ります'
                '（ターン ${landing.turnNumber}）';

    return Tooltip(
      message: where ?? 'まだ戻せる操作がありません。',
      child: OutlinedButton.icon(
        key: buttonKey,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: theme.textTheme.labelMedium,
        ),
        // ★条番号はラベルに出す（Tooltip に隠さない）。
        label: Text(
          landing == null
              ? label
              : '$label（${landing.cursor.step.ruleRef}${entrance ? ' の入口' : ''}）',
        ),
      ),
    );
  }
}

/// 直前の巻き戻しで何が起きたか（M-B5 / 決定 D78）。
///
/// ★★ 乱数の注記は毎回出さない ★★
/// 出しっぱなしにすると M3 の縮退 3 種と同じく「なんか出てる」で無視される。
/// → **取り消した操作が実際に乱数を消費したときだけ出す。**
/// ★判定は列挙ではなく実測（`state/counting_rng.dart`）。
///
/// ★★ 文面は「壊れている」ではなく「紙のカードと同じ」★★
/// 巻き戻しても乱数は戻らない（`SeededRng` は内部状態を持ち、`GameHistory` は
/// `GameState` しか持たない）。これは不具合ではなく、決定 D78 が
/// **明示するだけにする**と決めた挙動である（張り直しは未決 U15）。
class _LastRewindLine extends StatelessWidget {
  const _LastRewindLine({required this.rewind});

  final BoardRewindLog rewind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final what = rewind.wholeStep ? '1 ステップ戻しました' : '1 つ戻しました';
    final where = rewind.landedOnSameStep
        ? '${rewind.landedCursor.step.ruleRef} の入口'
        : '${phaseLabel(rewind.landedCursor.phase)} '
            '${rewind.landedCursor.phase.ruleRef} の '
            '${rewind.landedCursor.step.ruleRef}';

    return Column(
      key: const ValueKey('last-rewind'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '$what（${rewind.entriesPopped} 操作）→ '
            'ターン ${rewind.landedTurnNumber} / $where',
            style: theme.textTheme.labelSmall,
          ),
        ),
        if (rewind.rngConsumed)
          const DegradationLine(
            key: ValueKey('rewind-rng-note'),
            icon: Icons.casino_outlined,
            severity: DegradationSeverity.report,
            text: 'シャッフルは引き直せません。'
                'もう一度シャッフルすると別の結果になります。'
                '（ソロとローカル対戦だけの話です。オンライン対戦では seed をサーバが持ち、'
                'この端末は乱数を回しません）',
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

    final steps = operation.steps;
    // ★★ 1 ステップと複数ステップで書き分ける ★★
    //   1 ステップのときに歩数やフェイズ名を足すと、毎回同じ語が並んで読み飛ばされる。
    final passed = switch (steps.length) {
      0 => null,
      1 => '${steps.first.cursor.step.ruleRef} → '
          '${steps.first.taken.endsPhase ? 'フェイズ終了' : steps.first.taken.target!.ruleRef}'
          '${steps.first.taken.label.isEmpty ? '' : '（${steps.first.taken.label}）'}',
      // ★★ 何ステップ進んだか / どのフェイズからどのフェイズへ（§15-10）★★
      //   1 押下で平均 6 ステップ進むので、出さないと「勝手に進んだ」になる。
      _ => '${operation.cursorBefore.step.ruleRef} → '
          '${operation.cursorAfter.step.ruleRef}'
          '（${steps.length} ステップ / '
          '${phaseLabel(operation.cursorBefore.phase)} '
          '${operation.cursorBefore.phase.ruleRef} → '
          '${phaseLabel(operation.cursorAfter.phase)} '
          '${operation.cursorAfter.phase.ruleRef}）',
    };

    // ★★ 条文が定める分岐は個別に出す（既存 / D86）★★
    //   ★8.3.6 の早期終了は 11 ステップ飛ぶので、1 押下にまとめると読めなくなる。
    //   ★1 ステップのときは上の行に出ているので繰り返さない。
    final branches = steps.length == 1
        ? const <String>[]
        : [
            for (final step in steps.where((s) => s.isBranch))
              '分岐 ${step.cursor.step.ruleRef}: '
                  '${step.taken.label.isEmpty ? '（記録なし）' : step.taken.label}',
          ];

    // ★★ リフレッシュはステップ別に出す（§15-10）★★
    //   10.2.1 はステップ境界を無視して割り込むので、合計だけだと
    //   「どのステップの途中で起きたか」が失われる。
    final refreshed = steps.where((step) => step.refreshCount > 0).toList();

    final parts = <String>[
      ?passed,
      ...branches,
      if (refreshed.isNotEmpty)
        'リフレッシュが割り込みました'
            '（10.2.1。処理を中断して実行し、続きを実行します）: '
            '${refreshed.map((s) => '${s.cursor.step.ruleRef} で ${s.refreshCount} 回').join(' / ')}'
      else if (operation.refreshCount > 0)
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

/// ★★ 自動進行が止まった理由（M-B7 / 決定 D98-1）★★
///
/// ★★ 成立したものを**全部**出す。1 つに絞らない ★★
/// 新規警告とターン変化が同じ押下で成立することはある（盤面設計メモ §15-6）。
///
/// ★★ 5 つを 1 行にまとめない ★★
/// 原因も「次に何をすればよいか」も違う。**まとめると次の一手が消える。**
///
/// ★★ 格を出す（条文由来 / 実装判断）★★
/// 混ぜると、次に問われたときに**存在しない条文を探すことになる**（D73 / D92-3）。
/// ★判定は `BoardStopReasonKind.isFromRules` から取る。ここで振り分けない。
class _StopReasonLine extends StatelessWidget {
  const _StopReasonLine({required this.stops});

  final List<BoardStopReason> stops;

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      key: const ValueKey('stop-reason'),
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        '止まった理由: ${stops.map(_stopReasonText).join(' / ')}',
        style: theme.textTheme.labelSmall,
      ),
    );
  }
}

/// 停止理由 1 件の文面。★網羅 switch（[phaseLabel] と同じ作法）。
///
/// ★条番号は `ruleRef` から取る。ここに書かない。
String _stopReasonText(BoardStopReason stop) {
  final where = stop.cursor.step.ruleRef;
  final grade = stop.kind.isFromRules ? '' : '★条文由来ではなく実装の判断です';
  final body = switch (stop.kind) {
    BoardStopReasonKind.playerAction =>
      '$where の手前（この手順は、あなたの選択・判断・盤面操作を求めています）',
    BoardStopReasonKind.playerDeclaration =>
      '$where の手前（どちらへ進むかをあなたが宣言してください）',
    BoardStopReasonKind.newWarning =>
      '新しい警告が出ました（${stop.warnings.map((k) => k.ruleRef).join(' / ')}）。'
          '手で処理してください',
    BoardStopReasonKind.refreshed =>
      '$where でリフレッシュが ${stop.refreshCount} 回割り込みました'
          '（10.2.1。控え室が空になり、メインデッキが組み直されています）',
    BoardStopReasonKind.turnChanged => 'ターン ${stop.turnNumber} になりました（8.4.14）',
  };
  return grade.isEmpty ? body : '$body。$grade';
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
