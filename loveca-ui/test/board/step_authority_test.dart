/// ★★ ステップの順序と分岐先を UI に持たせない（M-B3 / 決定 D86）★★
///
/// `step.dart` の doc が「遷移の権威は `stepGraph` だけ」と定めており、
/// `step_engine.dart` にすら条番号による遷移先の再記述を禁じている。
/// **UI はなおさら持ってはいけない。**
///
/// 持つと何が起きるか ——
/// - 「分岐は 8.3.6 と 8.4.12 の 2 箇所だけ」という断定が UI 側で古くなる
/// - 8.3.6 の早期終了（8.3.17 へジャンプしない）や 7.7.3 に CT が無いことを
///   UI が独自に再現しはじめ、**core と食い違っても誰も気づかない**
///
/// ★これは `ルール整合性チェック_v1.06.md` D-15（列挙による断定は黙って古くなる）を
/// **足す前に**塞いでおく走査である。
///
/// ★★ 陽性対照を対で置く（D-15 §12-5）★★
/// 0 件は「無い」と「見えていない」の区別がつかない。
library;

import 'package:flutter_test/flutter_test.dart';

import '../support/source_scan.dart';

/// `StepId.s7_4_1` のような**個別のステップの名指し**。
final _stepLiteral = RegExp(r'StepId\.s\d');

/// 遷移表そのもの。
final _stepGraph = RegExp(r'\bstepGraph\b');

void main() {
  test('★★ 陽性対照: 同じ走査が loveca_core では当たる ★★', () {
    // ★これが 0 件なら、下の「0 件」は「無い」ではなく「見えていない」。
    final literals = scanDart(coreLibPath, _stepLiteral);
    expect(literals.keys, contains('step.dart'));
    expect(literals['step.dart'], greaterThan(70),
        reason: '★のべ 73 ステップぶんの宣言と遷移表がある');

    final graph = scanDart(coreLibPath, _stepGraph);
    expect(graph.keys, containsAll(<String>['step.dart', 'step_engine.dart']));
  });

  test('★ UI は個別のステップを名指ししない', () {
    expect(scanDart('lib', _stepLiteral), isEmpty,
        reason: '★ステップの順序や分岐先が UI にも書かれている。'
            'core と食い違っても誰も気づかない');
  });

  test('★ UI は遷移表を直接読まない（GameStore 経由で StepEngine に委ねる）', () {
    expect(scanDart('lib', _stepGraph), isEmpty,
        reason: '★後続候補は `GameStore.transitions`（= `StepEngine`）から取る');
  });
}
