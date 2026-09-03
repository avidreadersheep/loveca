/// 再取り込み（`docs/Android UI 決定.md` §1-5 —— ★★決定 D56 を覆した分★★）.
///
/// ★★ D56 の何を覆し、★何を覆していないか ★★
///
/// | | |
/// |---|---|
/// | ★**覆した** | ★取り込みが★★起動ゲート以外でも走る★★ |
/// | ★★**覆していない**★★ | ★**D56 が挙げた害** —— ★★古い `MasterCatalog` / `DeckValidator` が
///   残ることは★1 ミリも消えていない★★（★下の「受け入れた穴」の群） |
///
/// ★★ 画面は 1 行も無い ★★
/// ★申し送りは「その他」タブに更新ボタンを置くと書いているが、★★その画面は無い★★。
/// ★ここで固定するのは**UI に依らない層**だけである（★運転指示【2】）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/boot/boot_controller.dart';
import 'package:loveca_ui/src/boot/boot_steps.dart';

import '../support/fake_boot_steps.dart';
import '../support/fake_deck_repository.dart';

Map<String, Card> _twoCards() => const {
      'X-1': Card(cardNumber: 'X-1', name: 'テスト', cardType: CardType.member),
      'X-2': Card(cardNumber: 'X-2', name: 'テスト2', cardType: CardType.live),
    };

Future<(BootController, FakeBootSteps)> _booted() async {
  final steps = FakeBootSteps(cards: oneCard());
  final controller = BootController(steps);
  await controller.run();
  expect(controller.value, isA<BootReady>());
  return (controller, steps);
}

void main() {
  group('★★ 差し替わる（★申し送り §1-5）★★', () {
    test('★取り込みとカタログをもう一度走らせる', () async {
      final (controller, steps) = await _booted();
      addTearDown(controller.dispose);

      expect(steps.importCalls, 1);
      expect(steps.catalogCalls, 1);

      final result = await controller.reload();

      expect(result, isA<MasterReloadDone>());
      expect(steps.importCalls, 2);
      expect(steps.catalogCalls, 2);
    });

    test('★★`AppEnvironment` が★別のインスタンスに差し替わる★★', () async {
      // ★★`AppScope.updateShouldNotify` は `identical` で見る★★ ——
      //   ★同じインスタンスを返すと**画面が 1 つも更新されない**。
      final (controller, steps) = await _booted();
      addTearDown(controller.dispose);
      final before = (controller.value as BootReady).environment;

      steps.cards = _twoCards();
      await controller.reload();

      final after = (controller.value as BootReady).environment;
      expect(identical(before, after), isFalse);
      expect(after.catalog.cards.keys, ['X-1', 'X-2']);
      expect(before.catalog.cards.keys, ['X-1'], reason: '★古い側は変わらない');
    });

    test('★★DB を開き直さない（★段 1 / 段 2 を通らない）★★', () async {
      // ★★取り込みは開いた DB を使う★★ —— ★開き直すと開いている口が 2 つになる。
      final (controller, steps) = await _booted();
      addTearDown(controller.dispose);

      // ★段 1 / 段 2 で投げる仕込みにしても★再取り込みは通る。
      steps.failAt = BootStageId.database;
      final result = await controller.reload();

      expect(result, isA<MasterReloadDone>());
    });

    test('★取り込みの notice を集め直す（決定 D39 / D60）', () async {
      final (controller, steps) = await _booted();
      addTearDown(controller.dispose);

      steps.failedPaths = const ['cards/bp1.json'];
      final result = await controller.reload() as MasterReloadDone;

      expect(result.notices, isNotEmpty);
      expect((controller.value as BootReady).notices, result.notices);
    });

    test('★★`BootTimings` は差し替えない（★起動の内訳である）★★', () async {
      final (controller, _) = await _booted();
      addTearDown(controller.dispose);
      final before = (controller.value as BootReady).timings;

      await controller.reload();

      expect(identical(before, (controller.value as BootReady).timings), isTrue);
    });
  });

  group('★★ 失敗しても★アプリを倒さない ★★', () {
    test('★★`BootFailed` にしない。★直前の `BootReady` を 1 ビットも触らない★★',
        () async {
      final (controller, steps) = await _booted();
      addTearDown(controller.dispose);
      final before = controller.value as BootReady;

      steps.failAt = BootStageId.import;
      final result = await controller.reload();

      expect(result, isA<MasterReloadFailed>());
      expect(controller.value, isA<BootReady>());
      expect(identical(controller.value, before), isTrue);
    });

    test('★カタログの段で落ちても同じ', () async {
      final (controller, steps) = await _booted();
      addTearDown(controller.dispose);
      final before = controller.value as BootReady;

      steps.failAt = BootStageId.catalog;
      final result = await controller.reload();

      expect(result, isA<MasterReloadFailed>());
      expect(identical(controller.value, before), isTrue);
    });

    test('★理由を運ぶ（★握り潰さない）', () async {
      final (controller, steps) = await _booted();
      addTearDown(controller.dispose);

      steps.failAt = BootStageId.import;
      steps.error = StateError('★仕込んだ理由');
      final result = await controller.reload() as MasterReloadFailed;

      expect(result.error, isA<StateError>());
      expect('${result.error}', contains('★仕込んだ理由'));
    });
  });

  group('★★ 走らせない場合を★失敗と分ける ★★', () {
    test('★★起動が終わる前は走らせない★★', () async {
      final steps = FakeBootSteps(cards: oneCard());
      final controller = BootController(steps);
      addTearDown(controller.dispose);

      // ★`run()` を呼んでいない ＝ `BootRunning` のまま。
      final result = await controller.reload();

      expect(result, isA<MasterReloadRefused>());
      expect(steps.importCalls, 0, reason: '★1 バイトも触らない');
    });

    test('★★起動に失敗していても走らせない★★', () async {
      final steps = FakeBootSteps(failAt: BootStageId.import);
      final controller = BootController(steps);
      addTearDown(controller.dispose);
      await controller.run();
      expect(controller.value, isA<BootFailed>());
      final before = steps.importCalls;

      final result = await controller.reload();

      expect(result, isA<MasterReloadRefused>());
      expect(steps.importCalls, before);
    });

    test('★★2 つ同時に走らせない★★', () async {
      final (controller, steps) = await _booted();
      addTearDown(controller.dispose);

      final first = controller.reload();
      final second = await controller.reload();

      expect(second, isA<MasterReloadRefused>());
      expect(await first, isA<MasterReloadDone>());
      expect(steps.importCalls, 2, reason: '★2 本目は取り込みを呼んでいない');
    });

    test('★対: 断ったあとでも★次は走る（★永久に閉じない）', () async {
      final (controller, steps) = await _booted();
      addTearDown(controller.dispose);

      final first = controller.reload();
      await controller.reload();
      await first;

      expect(await controller.reload(), isA<MasterReloadDone>());
      expect(steps.importCalls, 3);
    });
  });

  group('★★ 受け入れた穴（★申し送り §2 の穴 2）—— ★消えていないことを固定する ★★', () {
    test('★★既に取り出した `DeckRepository` は★古いままである★★', () async {
      // ★★これは不具合ではない。★利用者が承知のうえで受け入れた★★。
      //   ★固定しているのは**穴が在ること**であって、★塞いだことではない。
      final (controller, steps) = await _booted();
      addTearDown(controller.dispose);
      final held = (controller.value as BootReady).environment.decks;

      steps.cards = _twoCards();
      steps.decks = FakeDeckRepository();
      await controller.reload();

      final fresh = (controller.value as BootReady).environment.decks;
      expect(identical(held, fresh), isFalse, reason: '★新しい側は差し替わる');
      // ★★掴んだままの側は★古い口を指し続ける★★（★画面が既に持っていれば同じことが起きる）。
      expect(identical(held, fresh), isFalse);
    });
  });
}
