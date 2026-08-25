/// 引く / シャッフル / 上から見る（M-B3 / 総合ルール 5.5 / 5.6 / 5.7 / 10.2.2.2）.
///
/// ★★★ 4.9 に「上から見る」を作っていないことの検査には陽性対照が要る ★★★
/// 「エネルギーデッキのメニューに『上から見る』が無い」を単独で見ると、
/// **メニューがそもそも開いていなくても通る。**
/// → 同じ検査でメインデッキのメニューには**出る**ことを対で見る
/// （`ルール整合性チェック_v1.06.md` D-15 §12-5「0 件は無いと見えていないの区別がつかない」）。
///
/// ★★ 両プレイヤーの山を操作できる（決定 D77 / D84）★★
/// ローカル対戦は 1 人が両プレイヤーを操作する。
/// ★**相手の山を押して自分の手札が増える**ような取り違えを機械で塞ぐ。
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_ui/src/state/board_mode.dart';
import 'package:loveca_ui/src/ui/board/board_page.dart';
import 'package:loveca_ui/src/ui/board/board_start_dialog.dart';

import '../support/board_fixture.dart';
import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';
import '../support/real_shaped_catalog.dart';

const _member = parallelMemberNormal;
const _live = drawLivePrinting;
const _energy = energyPrinting;

/// 6 枚のメインデッキ。★並びが変わったことを見るのに要る。
const _deck = <String>[_member, _live, _member, _live, _member, _live];

Future<void> _pump(WidgetTester tester, GameState state) async {
  tester.view.physicalSize = const Size(1800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await pumpInAppScope(
    tester,
    BoardPage(
      initialState: state,
      viewerId: kSelfPlayerId,
      mode: BoardMode.localVersus,
      seed: 1,
    ),
    decks: FakeDeckRepository(),
    catalog: realShapedCatalog(),
  );
}

Future<void> _openMainDeckMenu(WidgetTester tester, String playerId) async {
  await tester.tap(find.byKey(ValueKey('pile-main-$playerId')));
  await tester.pumpAndSettle();
}

Future<void> _openEnergyDeckMenu(WidgetTester tester, String playerId) async {
  await tester.tap(find.byKey(ValueKey('pile-energy-$playerId')));
  await tester.pumpAndSettle();
}

/// 開いているメニューの行の文言をすべて集める。
List<String> _menuLabels(WidgetTester tester) => [
      for (final item
          in tester.widgetList<PopupMenuItem<int>>(find.byType(PopupMenuItem<int>)))
        (item.child! as Text).data!,
    ];

GameState _board() => handcraftedBoard(
      selfZones: const {Zone.mainDeck: _deck, Zone.energyDeck: [_energy]},
      opponentZones: const {Zone.mainDeck: _deck, Zone.energyDeck: [_energy]},
    );

void main() {
  group('★ 引く 5.6.1 / 5.6.2', () {
    testWidgets('1 枚引くと手札が +1 / メインデッキが -1', (tester) async {
      await _pump(tester, _board());
      await _openMainDeckMenu(tester, kSelfPlayerId);

      await tester.tap(find.text('1 枚引く 5.6.1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('自分の手札 4.11\n1 枚'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pile-main-$kSelfPlayerId')),
          matching: find.text('5'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('★★ 相手の山を押すと増えるのは相手の手札 ★★', (tester) async {
      await _pump(tester, _board());
      await _openMainDeckMenu(tester, kOpponentPlayerId);

      await tester.tap(find.text('1 枚引く 5.6.1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('相手の手札 4.11\n1 枚'), findsOneWidget);
      // ★対: 自分の手札は増えていない（取り違えの検査）。
      expect(find.textContaining('自分の手札 4.11\n0 枚'), findsOneWidget);
    });

    testWidgets('★枚数を指定して引ける（5.6.2）', (tester) async {
      await _pump(tester, _board());
      await _openMainDeckMenu(tester, kSelfPlayerId);

      await tester.tap(find.textContaining('枚数を指定して引く'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('card-count-field')), '3');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('card-count-ok')));
      await tester.pumpAndSettle();

      expect(find.textContaining('自分の手札 4.11\n3 枚'), findsOneWidget);
    });

    testWidgets('★不正な枚数は決定できず、理由が出る', (tester) async {
      await _pump(tester, _board());
      await _openMainDeckMenu(tester, kSelfPlayerId);
      await tester.tap(find.textContaining('枚数を指定して引く'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('card-count-field')), '0');
      await tester.pumpAndSettle();

      // ★★ 消さずに無効にして理由を出す ★★
      final ok = find.byKey(const ValueKey('card-count-ok'));
      expect(ok, findsOneWidget);
      expect(tester.widget<FilledButton>(ok).onPressed, isNull);
      expect(find.text('1 以上の数を入れてください'), findsOneWidget);
    });
  });

  group('★ シャッフル 5.5.1', () {
    testWidgets('枚数は変わらず並びが変わる', (tester) async {
      // ★中身は画面に出ない（4.8.2 / D77）ので、盤面の状態で見る。
      final before = _board();
      await _pump(tester, before);
      await _openMainDeckMenu(tester, kSelfPlayerId);

      await tester.tap(find.text('シャッフルする 5.5.1'));
      await tester.pumpAndSettle();

      // 枚数は変わらない。
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pile-main-$kSelfPlayerId')),
          matching: find.text('6'),
        ),
        findsOneWidget,
      );
      // ★対: 相手のメインデッキは触っていない。
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pile-main-$kOpponentPlayerId')),
          matching: find.text('6'),
        ),
        findsOneWidget,
      );
    });

    test('★seed によって並びが変わる（5.5.1「無作為に変更」）', () {
      // ★画面を通さずに写像だけ見る（並びは秘匿されていて画面から読めない）。
      String orderWith(int seed) {
        final context = ReduceContext(
          cards: realShapedCatalog().cards,
          rng: SeededRng(seed),
        );
        final next = reduce(
          handcraftedBoard(selfZones: const {Zone.mainDeck: _deck}),
          const ShuffleZone(playerId: kSelfPlayerId, zone: Zone.mainDeck),
          context: context,
        );
        return next
            .playerOf(kSelfPlayerId)
            .mainDeck
            .map((c) => c.instanceId)
            .join(',');
      }

      expect(orderWith(3), orderWith(3), reason: '★同じ seed なら同じ並び');
      expect({for (var s = 1; s <= 8; s++) orderWith(s)}, hasLength(greaterThan(1)),
          reason: '★seed で並びが変わる');
    });
  });

  group('★★ 上から見る 5.7.1 / 10.2.2.2 ★★', () {
    testWidgets('開くと上から N 枚が出て、閉じると消える', (tester) async {
      final state = _board();
      final top = state.playerOf(kSelfPlayerId).mainDeck.first;
      await _pump(tester, state);

      // ★★ 対: 開く前は中身が 1 つも出ていない（4.8.2 の秘匿 / D77）★★
      expect(find.byKey(ValueKey('board-card-${top.instanceId}')), findsNothing);

      await _openMainDeckMenu(tester, kSelfPlayerId);
      await tester.tap(find.textContaining('上から見る'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('card-count-field')), '2');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('card-count-ok')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('look-at-top')), findsOneWidget);
      expect(find.text('1 枚目'), findsOneWidget);
      expect(find.text('2 枚目'), findsOneWidget);
      expect(find.text('3 枚目'), findsNothing);
      expect(find.byKey(ValueKey('board-card-${top.instanceId}')), findsOneWidget,
          reason: '★一番上の札が表として出ている');
      expect(find.textContaining('見ただけでは並びは変わりません'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('look-at-top-close')));
      await tester.pumpAndSettle();

      // ★★ 閉じたら消える（常設の一覧にしない）★★
      expect(find.byKey(const ValueKey('look-at-top')), findsNothing);
      expect(find.byKey(ValueKey('board-card-${top.instanceId}')), findsNothing);
    });

    testWidgets('★見ても並びは変わらない（5.7.1）', (tester) async {
      final state = _board();
      final order =
          state.playerOf(kSelfPlayerId).mainDeck.map((c) => c.instanceId).toList();
      await _pump(tester, state);

      await _openMainDeckMenu(tester, kSelfPlayerId);
      await tester.tap(find.textContaining('上から見る'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('card-count-ok')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('look-at-top-close')));
      await tester.pumpAndSettle();

      // 山の枚数が変わっていないことで見る（中身は画面に出ない）。
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pile-main-$kSelfPlayerId')),
          matching: find.text('${order.length}'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('★10.2.2.2: 足りなければリフレッシュしてから見る', (tester) async {
      await _pump(
        tester,
        handcraftedBoard(
          selfZones: const {
            Zone.mainDeck: [_member],
            Zone.waitingRoom: [_live, _live, _live],
          },
        ),
      );

      await _openMainDeckMenu(tester, kSelfPlayerId);
      await tester.tap(find.textContaining('上から見る'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('card-count-field')), '3');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('card-count-ok')));
      await tester.pumpAndSettle();

      expect(find.textContaining('リフレッシュしました'), findsOneWidget);
      expect(find.text('3 枚目'), findsOneWidget);
    });

    testWidgets('★対: 足りていればリフレッシュの断りは出ない', (tester) async {
      await _pump(tester, _board());

      await _openMainDeckMenu(tester, kSelfPlayerId);
      await tester.tap(find.textContaining('上から見る'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('card-count-field')), '3');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('card-count-ok')));
      await tester.pumpAndSettle();

      expect(find.textContaining('リフレッシュしました'), findsNothing);
      expect(find.text('3 枚目'), findsOneWidget);
    });

    testWidgets('★足りず控え室も空なら、足りないことを出す', (tester) async {
      await _pump(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.mainDeck: [_member],
        }),
      );

      await _openMainDeckMenu(tester, kSelfPlayerId);
      await tester.tap(find.textContaining('上から見る'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('card-count-field')), '3');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('card-count-ok')));
      await tester.pumpAndSettle();

      expect(find.textContaining('3 枚を指定しましたが 1 枚しかありません'), findsOneWidget);
      expect(find.text('1 枚目'), findsOneWidget);
      expect(find.text('2 枚目'), findsNothing);
    });
  });

  group('★★★ エネルギーデッキ置き場（4.9）に「上から見る」を作らない ★★★', () {
    testWidgets('★陽性対照: メインデッキ（4.8）には両方出る', (tester) async {
      await _pump(tester, _board());
      await _openMainDeckMenu(tester, kSelfPlayerId);

      final labels = _menuLabels(tester);
      // ★これが出ていなければ、下の「無い」は「見えていない」だけである。
      expect(labels.where((l) => l.contains('上から見る')), hasLength(1));
      expect(labels.where((l) => l.contains('シャッフル')), hasLength(1));
    });

    testWidgets('★★ 4.9 には「上から見る」も「シャッフル」も無い ★★', (tester) async {
      await _pump(tester, _board());
      await _openEnergyDeckMenu(tester, kSelfPlayerId);

      final labels = _menuLabels(tester);
      // ★メニューは開いている（空でない）。
      expect(labels, isNotEmpty);
      // ★「上から見る」を**操作として**持たない行だけがある。
      expect(
        labels.where((l) => l.contains('上から見る') && !l.startsWith('★')),
        isEmpty,
      );
      expect(
        labels.where((l) => l.contains('シャッフル') && !l.startsWith('★')),
        isEmpty,
      );
      // ★押せる行が 1 つも無い。
      for (final item
          in tester.widgetList<PopupMenuItem<int>>(find.byType(PopupMenuItem<int>))) {
        expect(item.enabled, isFalse);
      }
    });

    testWidgets('★★ 理由 2 つが格を分けて読める（空メニューにしない）★★', (tester) async {
      await _pump(tester, _board());
      await _openEnergyDeckMenu(tester, kSelfPlayerId);

      final joined = _menuLabels(tester).join('\n');
      // 理由 1: 条文が定めていない（禁止ではない）。
      expect(joined, contains('5.7.1 / 5.7.2 / 10.2.2.2'));
      expect(joined, contains('禁止されているのではなく'));
      // 理由 2: 実装の判断（5.5.1 は 4.9 を除外していない）。
      expect(joined, contains('4.9 を除外してはいません'));
      expect(joined, contains('実装の判断'));
      // ★出す口は案内する（黙って何も無い形にしない）。
      expect(joined, contains('エネルギーを1枚出す'));
    });

    testWidgets('★4.8 側からも違いが読める（同じ見た目の山が 2 つあるため）',
        (tester) async {
      await _pump(tester, _board());
      await _openMainDeckMenu(tester, kSelfPlayerId);

      expect(
        _menuLabels(tester).join('\n'),
        contains('エネルギーデッキ置き場（4.9）には同じ操作がありません'),
      );
    });
  });
}
