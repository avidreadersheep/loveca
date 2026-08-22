import 'package:loveca_core/loveca_core.dart';
import 'package:test/test.dart';

var _seq = 0;
CardInstance _on(String cardNumber) => CardInstance(
      instanceId: 'i${_seq++}',
      printingId: '$cardNumber-R',
      cardNumber: cardNumber,
      ownerId: 'A',
      orientation: CardOrientation.active,
      face: FaceState.faceUp,
    );

List<CardInstance> _cards(String prefix, int count) =>
    [for (var i = 0; i < count; i++) _on('$prefix$i')];

GameState _state({
  List<CardInstance> aDeck = const [],
  List<CardInstance> aRoom = const [],
  List<CardInstance> bDeck = const [],
  List<CardInstance> bRoom = const [],
  String firstPlayerId = 'A',
}) =>
    GameState(
      players: [
        PlayerState(playerId: 'A', mainDeck: aDeck, waitingRoom: aRoom),
        PlayerState(playerId: 'B', mainDeck: bDeck, waitingRoom: bRoom),
      ],
      firstPlayerId: firstPlayerId,
      cursor: const StepCursor(PhaseId.firstPerformance, StepId.s8_3_11),
    );

void main() {
  final refresher = Refresher(rng: SeededRng(42));

  group('発動条件 — 総合ルール 10.2.2', () {
    test('10.2.2.1 メインデッキが空かつ控え室にカードがある', () {
      expect(refresher.needsRefresh(_state(aRoom: _cards('W', 3)), 'A'), isTrue);
    });

    test('メインデッキにカードがあれば発動しない', () {
      expect(
        refresher.needsRefresh(
            _state(aDeck: _cards('D', 1), aRoom: _cards('W', 3)), 'A'),
        isFalse,
      );
    });

    test('控え室が空なら発動しない', () {
      expect(refresher.needsRefresh(_state(), 'A'), isFalse);
    });

    test('10.2.2.2 上から見る指示の枚数に足りない場合', () {
      final state = _state(aDeck: _cards('D', 2), aRoom: _cards('W', 5));
      expect(refresher.needsRefreshForLook(state, 'A', 3), isTrue);
      expect(refresher.needsRefreshForLook(state, 'A', 2), isFalse);
    });
  });

  group('実行 — 総合ルール 10.2.3', () {
    test('控え室をシャッフルしてメインデッキへ移し、控え室は空になる', () {
      final after = refresher.refreshPlayer(_state(aRoom: _cards('W', 5)), 'A');
      expect(cardsIn(after, 'A', Zone.mainDeck).length, 5);
      expect(cardsIn(after, 'A', Zone.waitingRoom), isEmpty);
    });

    test('★残デッキの「下」へ差し込む (10.2.3)', () {
      final state = _state(aDeck: [_on('TOP')], aRoom: _cards('W', 3));
      final deck = cardsIn(refresher.refreshPlayer(state, 'A'), 'A', Zone.mainDeck);

      expect(deck.length, 4);
      expect(deck.first.cardNumber, 'TOP', reason: '既存のカードが一番上のまま');
      expect(deck.sublist(1).map((c) => c.cardNumber).toSet(), {'W0', 'W1', 'W2'});
    });

    test('★非公開状態にする (4.8.2 メインデッキ置き場は非公開領域)', () {
      final after = refresher.refreshPlayer(_state(aRoom: _cards('W', 3)), 'A');
      for (final card in cardsIn(after, 'A', Zone.mainDeck)) {
        expect(card.face, FaceState.faceDown);
        // 4.3.1 により配置状態が指定されるのは一部の領域だけ。
        expect(card.orientation, isNull);
      }
    });

    test('同じ seed なら同じ並びになる', () {
      final state = _state(aRoom: _cards('W', 10));
      final a = Refresher(rng: SeededRng(7)).refreshPlayer(state, 'A');
      final b = Refresher(rng: SeededRng(7)).refreshPlayer(state, 'A');
      expect(
        cardsIn(a, 'A', Zone.mainDeck).map((c) => c.instanceId).toList(),
        cardsIn(b, 'A', Zone.mainDeck).map((c) => c.instanceId).toList(),
      );
    });
  });

  group('★10.2.4 両者同時なら現ターンの先攻が先', () {
    test('両者が条件を満たせば両方処理される', () {
      final after = refresher.refreshIfNeeded(
          _state(aRoom: _cards('WA', 2), bRoom: _cards('WB', 2)));
      expect(cardsIn(after, 'A', Zone.mainDeck).length, 2);
      expect(cardsIn(after, 'B', Zone.mainDeck).length, 2);
      expect(cardsIn(after, 'A', Zone.waitingRoom), isEmpty);
      expect(cardsIn(after, 'B', Zone.waitingRoom), isEmpty);
    });

    test('★処理順は firstPlayerId に従う (10.2.4)', () {
      // 順序を観測するため、同じ乱数源を共有する Refresher を使う。
      // 先に処理された側が先に乱数を消費するので、並びが入れ替わる。
      final state = _state(aRoom: _cards('WA', 6), bRoom: _cards('WB', 6));

      final aFirst = Refresher(rng: SeededRng(3))
          .refreshIfNeeded(state.copyWith(firstPlayerId: 'A'));
      final bFirst = Refresher(rng: SeededRng(3))
          .refreshIfNeeded(state.copyWith(firstPlayerId: 'B'));

      // 先攻側が先に乱数を引くため、A の並びは両者で異なる。
      expect(
        cardsIn(aFirst, 'A', Zone.mainDeck).map((c) => c.instanceId).toList(),
        isNot(cardsIn(bFirst, 'A', Zone.mainDeck).map((c) => c.instanceId).toList()),
        reason: '先攻が先に乱数を消費していない',
      );
    });

    test('条件を満たさないプレイヤーは処理しない', () {
      final after = refresher
          .refreshIfNeeded(_state(aRoom: _cards('WA', 2), bDeck: _cards('DB', 1)));
      expect(cardsIn(after, 'A', Zone.mainDeck).length, 2);
      expect(cardsIn(after, 'B', Zone.mainDeck).length, 1);
    });
  });

  group('★takeFromMainDeck — 処理の途中で割り込む (10.2.1)', () {
    test('足りていれば上から順に取る', () {
      final taken = refresher.takeFromMainDeck(_state(aDeck: _cards('D', 5)), 'A', 3);
      expect(taken.drawn.map((c) => c.cardNumber).toList(), ['D0', 'D1', 'D2']);
      expect(cardsIn(taken.state, 'A', Zone.mainDeck).length, 2);
      expect(taken.refreshCount, 0);
    });

    test('★★エール途中でデッキが尽きたらリフレッシュして残り回数を続行する★★', () {
      // 8.3.11 のエールは合計ブレード数と同じ回数の繰り返し。
      // 10.2.1「その処理を一時中断し、リフレッシュを実行した後に、
      //         その処理の続きを実行します」
      //
      // メインデッキ 2 枚 / 控え室 4 枚 で 5 枚エールする。
      final state = _state(aDeck: _cards('D', 2), aRoom: _cards('W', 4));
      final taken = refresher.takeFromMainDeck(state, 'A', 5);

      expect(taken.drawn.length, 5, reason: '中断せず 5 枚取り切る');
      expect(taken.refreshCount, 1, reason: '途中で 1 回だけ割り込む');
      expect(taken.wasInterrupted(5), isFalse);

      // 最初の 2 枚は元のデッキ、残り 3 枚はリフレッシュ後の山。
      expect(taken.drawn.take(2).map((c) => c.cardNumber).toList(), ['D0', 'D1']);
      expect(taken.drawn.skip(2).map((c) => c.cardNumber).toSet(),
          everyElement(startsWith('W')));

      // 控え室は空になり、残りはデッキに 1 枚。
      expect(cardsIn(taken.state, 'A', Zone.waitingRoom), isEmpty);
      expect(cardsIn(taken.state, 'A', Zone.mainDeck).length, 1);
    });

    test('★チェックタイミングを待たない (10.1.2 の例外)', () {
      // 8.3.11 の途中はチェックタイミングではない。それでも実行される。
      final state = _state(aRoom: _cards('W', 3));
      expect(state.cursor.step, StepId.s8_3_11);

      final taken = refresher.takeFromMainDeck(state, 'A', 2);
      expect(taken.drawn.length, 2);
      expect(taken.refreshCount, 1);
    });

    test('控え室も空なら取れた分だけ返して終了する', () {
      final taken = refresher.takeFromMainDeck(_state(aDeck: _cards('D', 2)), 'A', 5);
      expect(taken.drawn.length, 2);
      expect(taken.wasInterrupted(5), isTrue);
      expect(taken.refreshCount, 0);
    });

    test('0 枚の指示では何も起きない', () {
      final taken = refresher.takeFromMainDeck(_state(aDeck: _cards('D', 2)), 'A', 0);
      expect(taken.drawn, isEmpty);
      expect(cardsIn(taken.state, 'A', Zone.mainDeck).length, 2);
    });
  });
}
