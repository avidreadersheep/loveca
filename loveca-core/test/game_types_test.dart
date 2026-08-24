import 'package:loveca_core/loveca_core.dart';
import 'package:test/test.dart';

/// ★静的カナリア (1): [Zone] 専用の網羅 switch.
///
/// この関数は [Zone] しか受けない。[Zone] と [OutOfRuleZone] に共通の親型を導入して
/// 引数を親型へ広げると、exhaustiveness チェックが落ちてコンパイルできなくなる。
/// 落ちたときに緩めて回避しないこと。
String _zoneRuleRef(Zone zone) => switch (zone) {
      Zone.stage => '4.4',
      Zone.memberArea => '4.5',
      Zone.liveStage => '4.6',
      Zone.energyField => '4.7',
      Zone.mainDeck => '4.8',
      Zone.energyDeck => '4.9',
      Zone.successLive => '4.10',
      Zone.hand => '4.11',
      Zone.waitingRoom => '4.12',
      Zone.exile => '4.13',
      Zone.resolution => '4.14',
    };

/// ★静的カナリア (2): [OutOfRuleZone] 専用の網羅 switch。
String _outOfRuleName(OutOfRuleZone zone) => switch (zone) {
      OutOfRuleZone.mulliganAside => 'mulliganAside',
      OutOfRuleZone.freeArea => 'freeArea',
    };

/// テスト用の盤面カードを 1 枚作る。
///
/// [orientation] を省略すると向きを持たないカードになる。
/// メンバーの下に重ねられたカード (4.5.5.2) はこちら。
CardInstance _card(
  String id, {
  CardOrientation? orientation,
  String ownerId = 'A',
}) =>
    CardInstance(
      instanceId: id,
      printingId: '$id-R',
      cardNumber: id,
      ownerId: ownerId,
      orientation: orientation,
    );

void main() {
  group('Zone — 総合ルール 4 章の領域', () {
    test('4 章が定義する領域は 11 種ちょうど (4.4〜4.14)', () {
      expect(Zone.values.length, 11);

      // 条番号が 4.4〜4.14 と重複なく 1 対 1 で対応すること。
      final refs = Zone.values.map((z) => z.ruleRef).toList();
      expect(refs.toSet().length, refs.length, reason: '条番号の重複');
      expect(
        refs.toSet(),
        {'4.4', '4.5', '4.6', '4.7', '4.8', '4.9', '4.10', '4.11', '4.12', '4.13', '4.14'},
      );
      for (final zone in Zone.values) {
        expect(zone.ruleRef, startsWith('4.'));
        expect(zone.ruleRef, _zoneRuleRef(zone));
      }
    });

    test('★解決領域だけが両プレイヤー共有で 1 つだけ (4.14.1)', () {
      // 4.14.1「解決領域は両プレイヤーが共有して使用する領域が 1 つだけ存在します」
      // 他の 10 種は 4.1.1 により各プレイヤーがそれぞれ持つ。
      expect(
        Zone.values.where((z) => z.isShared).toList(),
        [Zone.resolution],
      );
    });

    test('★順番が管理されるのはメインデッキ置き場と成功ライブカード置き場だけ', () {
      // 4.8.2 メインデッキ置き場 / 4.10.2 成功ライブカード置き場
      // ★4.9.2 エネルギーデッキ置き場は非公開だが順番は管理されない
      expect(
        Zone.values.where((z) => z.isOrdered == true).toSet(),
        {Zone.mainDeck, Zone.successLive},
      );
      expect(Zone.energyDeck.isOrdered, isFalse);
    });

    test('非公開領域はメインデッキ置き場・エネルギーデッキ置き場・手札 (4.8.2 / 4.9.2 / 4.11.2)', () {
      expect(
        Zone.values.where((z) => z.visibility == ZoneVisibility.private).toSet(),
        {Zone.mainDeck, Zone.energyDeck, Zone.hand},
      );
    });

    test('★ステージだけは 4.4 が可視状態も順番管理も規定していない', () {
      // 4.4.1「プレイヤーのメンバーエリアを統合した領域です」としか書かれていない。
      // 根拠のない値をコードに書かないため null で持つ (CLAUDE.md §1)。
      expect(Zone.stage.visibility, isNull);
      expect(Zone.stage.isOrdered, isNull);
      for (final zone in Zone.values.where((z) => z != Zone.stage)) {
        expect(zone.visibility, isNotNull, reason: '${zone.ruleRef} の可視状態');
        expect(zone.isOrdered, isNotNull, reason: '${zone.ruleRef} の順番管理');
      }
    });
  });

  group('OutOfRuleZone — ルール外の置き場', () {
    test('マリガンの脇置き (6.2.1.6) とフリーエリアの 2 つ', () {
      expect(OutOfRuleZone.values.length, 2);
      expect(
        OutOfRuleZone.values.toSet(),
        {OutOfRuleZone.mulliganAside, OutOfRuleZone.freeArea},
      );
      for (final zone in OutOfRuleZone.values) {
        expect(_outOfRuleName(zone), isNotEmpty);
      }
    });
  });

  group('★Zone と OutOfRuleZone の分離', () {
    // 次セッションで移動関数を書くとき、dynamic や共通の親型を導入して
    // 分離が崩れるのを防ぐ。3 段で担保する。

    test('(a) 相互に代入できない', () {
      for (final zone in Zone.values) {
        expect(zone, isNot(isA<OutOfRuleZone>()));
      }
      for (final zone in OutOfRuleZone.values) {
        expect(zone, isNot(isA<Zone>()));
      }
    });

    test('(b) 共通の上位型が Enum のままである', () {
      // Dart ではすべての enum が Enum と Object を継承するため、
      // 「共通のスーパータイプを持たない」を字義どおり表明することはできない。
      // 固定すべきは「独自の共通親型を導入していないこと」なので、
      // 型注釈を付けずに推論させた最小共通上位型 (LUB) を見る。

      // 先にこの判定手法自体がこのランタイムで成立することを確認する。
      expect(<Object>[].runtimeType.toString(), 'List<Object>',
          reason: 'runtimeType の文字列表現が期待どおりの形式であること (Dart VM 前提)');

      // ★型注釈を付けないこと。付けると下向き推論が働き、この検査が無意味になる。
      final inferred = [Zone.stage, OutOfRuleZone.freeArea];

      // LUB が enum の基底型であること = 独自の共通親型が無いということ。
      // 共通の親型 P (例: sealed class CardPlace) を足すと 'List<P>' になって落ちる。
      //
      // Dart VM は enum の基底として dart:core の非公開クラス _Enum を報告する。
      // Enum / _Enum のどちらを報告するかは実装詳細なので両方を許し、
      // 「名前の付いた独自の型ではない」ことだけを固定する。
      expect(
        inferred.runtimeType.toString(),
        matches(RegExp(r'^List<_?Enum>$')),
        reason: 'Zone と OutOfRuleZone に独自の共通親型が導入されている',
      );
    });

    // (c) 静的カナリアはこのファイル冒頭の _zoneRuleRef / _outOfRuleName。
    //     共通の親型を導入して引数を広げると exhaustiveness チェックが落ちる。
  });

  group('MemberAreaSlot — 総合ルール 4.5.2.1', () {
    test('3 つのエリアが固有の領域名称を持つ', () {
      expect(MemberAreaSlot.values.length, 3);
      expect(MemberAreaSlot.leftSide.label, '左サイドエリア');
      expect(MemberAreaSlot.center.label, 'センターエリア');
      expect(MemberAreaSlot.rightSide.label, '右サイドエリア');
    });

    test('★正面のエリアは鏡像 (4.5.7.1)', () {
      // 4.5.7.1「左サイドエリアの正面は他プレイヤーの右サイドエリアが、
      //          センターエリアは他プレイヤーのセンターエリアが、
      //          右サイドエリアは他プレイヤーの左サイドエリアがそれぞれ該当します」
      expect(MemberAreaSlot.leftSide.opposing, MemberAreaSlot.rightSide);
      expect(MemberAreaSlot.center.opposing, MemberAreaSlot.center);
      expect(MemberAreaSlot.rightSide.opposing, MemberAreaSlot.leftSide);

      // 正面の正面は自分自身。
      for (final slot in MemberAreaSlot.values) {
        expect(slot.opposing.opposing, slot);
      }
    });
  });

  group('CardInstance — 総合ルール 4.3', () {
    test('★向きを示す配置状態は null を取れる (4.3.1 / 4.5.5.2)', () {
      // 4.5.5.2「メンバーカードの下に重ねられているメンバーカードやエネルギーカードは
      //          向きを示す配置状態を持ちません」
      const beneath = CardInstance(
        instanceId: 'i1',
        printingId: 'PL!N-bp1-001-R',
        cardNumber: 'PL!N-bp1-001',
        ownerId: 'A',
      );
      expect(beneath.orientation, isNull);
      expect(beneath.face, FaceState.faceUp);
    });

    test('配置状態を持つ場合はアクティブかウェイトのいずれか (4.3.2)', () {
      const member = CardInstance(
        instanceId: 'i2',
        printingId: 'PL!N-bp1-002-R',
        cardNumber: 'PL!N-bp1-002',
        ownerId: 'A',
        orientation: CardOrientation.active,
      );
      expect(member.orientation, CardOrientation.active);
      expect(member.copyWith(orientation: CardOrientation.wait).orientation,
          CardOrientation.wait);

      // メンバーの下へ移す際は向きを落とす (4.5.5.2)。
      expect(member.copyWith(clearOrientation: true).orientation, isNull);
    });

    test('ownerId を保持する (4.1.7 / 8.3.14 の共有解決領域の絞り込み)', () {
      const card = CardInstance(
        instanceId: 'i3',
        printingId: 'PL!-bp4-022-L',
        cardNumber: 'PL!-bp4-022',
        ownerId: 'B',
      );
      expect(card.ownerId, 'B');
      // 向きを変えてもオーナーは変わらない。
      expect(card.copyWith(face: FaceState.faceDown).ownerId, 'B');
    });
  });

  group('MemberArea — 総合ルール 4.5.5', () {
    test('通常はメンバー 1 枚 + その下のカード', () {
      final area = MemberArea(
        slot: MemberAreaSlot.center,
        stacks: [
          MemberStack(
            member: _card('m1', orientation: CardOrientation.active),
            beneath: [_card('e1')],
          ),
        ],
      );

      expect(area.stacks.length, 1);
      expect(area.hasNoMember, isFalse);
      expect(area.hasDuplicateMembers, isFalse);
      expect(area.orphans, isEmpty);
    });

    test('★メンバーが 0 枚で孤児カードだけが残っている状態を表現できる', () {
      // 4.5.5.4「メンバーがメンバーエリア以外の領域に移動する場合、
      //          そのメンバーカードのみが移動します」
      // 4.5.5.4.2「重ねられていたエネルギーカードはそのままそのメンバーエリアに残り、
      //            その後にルール処理によりエネルギーデッキに移動します」
      // 10.1.2「ルール処理は、リフレッシュを除き、チェックタイミングにおいてのみ
      //         条件を満たしているかを確認し、実行されます」
      //
      // → 次のチェックタイミングまで、この状態は正規に存在する。
      final area = MemberArea(
        slot: MemberAreaSlot.leftSide,
        stacks: const [],
        orphans: [_card('e1')],
      );

      expect(area.stacks, isEmpty);
      expect(area.hasNoMember, isTrue);
      expect(area.orphans.length, 1);
    });

    test('★メンバーが 2 枚以上ある状態を表現できる (10.4 の重複メンバー処理待ち)', () {
      final area = MemberArea(
        slot: MemberAreaSlot.rightSide,
        stacks: [
          MemberStack(member: _card('m1', orientation: CardOrientation.active)),
          MemberStack(member: _card('m2', orientation: CardOrientation.wait)),
        ],
      );

      expect(area.stacks.length, 2);
      expect(area.hasDuplicateMembers, isTrue);
    });

    test('★下に重ねられたカードは向きを示す配置状態を持たない (4.5.5.2)', () {
      final stack = MemberStack(
        member: _card('m1', orientation: CardOrientation.active),
        beneath: [_card('e1'), _card('m2')],
      );

      expect(stack.member.orientation, isNotNull, reason: '4.5.4 メンバーは向きを持つ');
      for (final card in stack.beneath) {
        expect(card.orientation, isNull, reason: '4.5.5.2 下のカードは向きを持たない');
      }
    });

    test('孤児カードとメンバーが同時に存在しうる', () {
      // 別のメンバーが去った直後に、まだ他のメンバーが残っているケース。
      final area = MemberArea(
        slot: MemberAreaSlot.center,
        stacks: [MemberStack(member: _card('m1', orientation: CardOrientation.active))],
        orphans: [_card('e1')],
      );

      expect(area.hasNoMember, isFalse);
      expect(area.orphans, isNotEmpty);
    });

    test('空のエリアを作れる', () {
      const area = MemberArea(slot: MemberAreaSlot.center);
      expect(area.stacks, isEmpty);
      expect(area.orphans, isEmpty);
      expect(area.hasNoMember, isTrue);
    });
  });

  group('PhaseId — 総合ルール 7.1.2 / 7.3.3 / 8.1.2', () {
    test('★リーフフェイズは 12 個。13 ではない', () {
      // 条文に 13 番目に相当するフェイズは存在しない。
      // 「フェイズ」と名の付く語を数えるとリーフ 12 + コンテナ 3 = 15。
      // 12 と 15 はありえるが 13 はありえない。
      expect(PhaseId.values.length, 12);
      expect(PhaseGroup.values.length, 3);
    });

    test('コンテナごとの内訳は 4 / 4 / 4', () {
      for (final group in PhaseGroup.values) {
        expect(
          PhaseId.values.where((p) => p.group == group).length,
          4,
          reason: '$group の配下',
        );
      }
    });

    test('★手番プレイヤーが居ないのは 2 つだけ (7.2.1.2)', () {
      // 8.2.2 / 8.2.4 も 8.4.2 以降も両プレイヤーを動かすため手番が定まらない。
      // このときアクティブプレイヤーは先攻プレイヤーになる。
      final noTurnPlayer =
          PhaseId.values.where((p) => !p.hasTurnPlayer).toSet();
      expect(noTurnPlayer, {PhaseId.liveCardSet, PhaseId.liveJudgement});
      expect(PhaseId.values.where((p) => p.hasTurnPlayer).length, 10);
    });

    test('★フェイズは実プレイヤー ID を持たずロールで定義される (8.4.13)', () {
      // 8.4.13 で先攻・後攻が入れ替わるため。
      // 実プレイヤーは GameState.firstPlayerId から実行時に解決する。
      for (final phase in PhaseId.values) {
        expect(phase.turnPlayerRole, isA<PhaseRole>());
      }
      expect(PhaseId.firstMain.turnPlayerRole, PhaseRole.first);
      expect(PhaseId.secondMain.turnPlayerRole, PhaseRole.second);
      expect(PhaseId.liveCardSet.turnPlayerRole, PhaseRole.none);
      expect(PhaseId.liveJudgement.turnPlayerRole, PhaseRole.none);
    });

    test('★先攻・後攻の同名フェイズは同じ条番号を共有する', () {
      // 7.4〜7.7 は 2 インスタンス、8.3 も 8.3.2.1 により 2 インスタンス。
      expect(PhaseId.firstActive.ruleRef, PhaseId.secondActive.ruleRef);
      expect(PhaseId.firstPerformance.ruleRef, '8.3');
      expect(PhaseId.secondPerformance.ruleRef, '8.3');
    });

    test('★フェイズの巡回順が条文どおり (7.1.2 / 7.3.3 / 8.1.2)', () {
      expect(phaseCycle.length, 12);
      expect(phaseCycle.toSet().length, 12, reason: '重複が無い');
      expect(phaseCycle.toSet(), PhaseId.values.toSet(), reason: '漏れが無い');

      // 7.1.2: 先攻通常 → 後攻通常 → ライブ
      expect(phaseCycle.sublist(0, 4).map((p) => p.group).toSet(),
          {PhaseGroup.firstNormal});
      expect(phaseCycle.sublist(4, 8).map((p) => p.group).toSet(),
          {PhaseGroup.secondNormal});
      expect(phaseCycle.sublist(8, 12).map((p) => p.group).toSet(),
          {PhaseGroup.live});

      // 7.3.3: アクティブ → エネルギー → ドロー → メイン
      expect(phaseCycle.sublist(0, 4).map((p) => p.ruleRef).toList(),
          ['7.4', '7.5', '7.6', '7.7']);
      expect(phaseCycle.sublist(4, 8).map((p) => p.ruleRef).toList(),
          ['7.4', '7.5', '7.6', '7.7']);

      // 8.1.2: セット → 先攻パフォ → 後攻パフォ → 勝敗判定
      expect(phaseCycle.sublist(8, 12).toList(), [
        PhaseId.liveCardSet,
        PhaseId.firstPerformance,
        PhaseId.secondPerformance,
        PhaseId.liveJudgement,
      ]);
    });

    test('★巡回は 12 個で閉じ、最終フェイズの次はターン先頭へ戻る', () {
      expect(PhaseId.liveJudgement.next, PhaseId.firstActive);
      expect(PhaseId.liveJudgement.isLastOfTurn, isTrue);
      expect(PhaseId.firstMain.next, PhaseId.secondActive);
      expect(PhaseId.secondMain.next, PhaseId.liveCardSet);

      // 12 回たどると元に戻る。
      var phase = PhaseId.firstActive;
      final visited = <PhaseId>[];
      for (var i = 0; i < 12; i++) {
        visited.add(phase);
        phase = phase.next;
      }
      expect(phase, PhaseId.firstActive);
      expect(visited.toSet().length, 12);

      // ターンの最終フェイズは 1 つだけ。
      expect(PhaseId.values.where((p) => p.isLastOfTurn).toList(),
          [PhaseId.liveJudgement]);
    });

    test('★turnEnd フェイズは存在しない (8.4.13 / 8.4.14 は 8.4 のステップ)', () {
      expect(
        PhaseId.values.map((p) => p.ruleRef).toSet(),
        {'7.4', '7.5', '7.6', '7.7', '8.2', '8.3', '8.4'},
      );
      expect(PhaseId.liveJudgement.steps, contains(StepId.s8_4_13));
      expect(PhaseId.liveJudgement.steps, contains(StepId.s8_4_14));
    });
  });

  group('StepId — 条番号をそのまま ID にしたステップ', () {
    test('ステップは 46 個', () {
      expect(StepId.values.length, 46);
      for (final step in StepId.values) {
        // 値名 sX_Y_Z と条番号 X.Y.Z が対応していること。
        expect(step.name, 's${step.ruleRef.replaceAll('.', '_')}');
      }
    });

    test('フェイズごとのステップ数が条文どおり', () {
      expect(PhaseId.firstActive.steps.length, 3); // 7.4.1〜7.4.3
      expect(PhaseId.firstEnergy.steps.length, 3); // 7.5.1〜7.5.3
      expect(PhaseId.firstDraw.steps.length, 3); // 7.6.1〜7.6.3
      expect(PhaseId.firstMain.steps.length, 3); // 7.7.1〜7.7.3
      expect(PhaseId.liveCardSet.steps.length, 5); // 8.2.1〜8.2.5
      expect(PhaseId.firstPerformance.steps.length, 15); // 8.3.3〜8.3.17
      expect(PhaseId.liveJudgement.steps.length, 14); // 8.4.1〜8.4.14

      // ★8.3.1 / 8.3.2 は定義条なのでステップにしない。
      expect(PhaseId.firstPerformance.steps.first, StepId.s8_3_3);
    });

    test('先攻・後攻の同名フェイズは同じステップ列を共有する', () {
      expect(PhaseId.firstActive.steps, PhaseId.secondActive.steps);
      expect(PhaseId.firstPerformance.steps, PhaseId.secondPerformance.steps);
    });

    test('すべてのステップがちょうど 1 つのフェイズ定義に現れる', () {
      final seen = <StepId>[];
      for (final phase in PhaseId.values) {
        seen.addAll(phase.steps);
      }
      expect(seen.toSet(), StepId.values.toSet(), reason: 'グラフに漏れがある');
      // 先攻・後攻で共有されるため、延べ回数は 2 倍になるものがある。
      expect(seen.length, 46 + 12 + 15, reason: '7.4〜7.7 の 12 と 8.3 の 15 が 2 回ずつ');
    });
  });

  group('★ステップの有向グラフ', () {
    test('すべてのステップがグラフに登録されている', () {
      expect(stepGraph.keys.toSet(), StepId.values.toSet());
      for (final entry in stepGraph.entries) {
        expect(entry.value, isNotEmpty, reason: '${entry.key.ruleRef} の後続候補が空');
      }
    });

    test('★分岐 (後続候補 2 つ) は 8.3.6 と 8.4.12 の 2 箇所だけ', () {
      final branches = stepGraph.entries
          .where((e) => e.value.length > 1)
          .map((e) => e.key)
          .toSet();
      expect(branches, {StepId.s8_3_6, StepId.s8_4_12});

      // 分岐点だけが判定主体を持つ。
      final withDecision =
          StepId.values.where((s) => s.decision != null).toSet();
      expect(withDecision, branches, reason: '分岐と判定主体の対応がずれている');
    });

    test('★8.3.6 の早期終了はフェイズ終了へ直接遷移する (8.3.17 へ跳ばない)', () {
      // 8.3.17 へジャンプさせると 8.3.17 のチェックタイミングが余分に走る。
      // 11.5.2.1 により「ライブ開始時」(8.3.8) の事象も発生しない。
      final transitions = stepGraph[StepId.s8_3_6]!;
      expect(transitions.length, 2);
      expect(transitions.map((t) => t.target).toSet(), {StepId.s8_3_7, null});
      expect(transitions.any((t) => t.target == StepId.s8_3_17), isFalse);

      // 盤面の観測だけで決まるのでアプリが自動判定してよい。
      expect(StepId.s8_3_6.decision, StepDecision.automatic);
    });

    test('★8.4.12 は 8.4.9 へ戻るループを持ち、判定はプレイヤーが宣言する', () {
      final transitions = stepGraph[StepId.s8_4_12]!;
      expect(transitions.length, 2);
      expect(
        transitions.map((t) => t.target).toSet(),
        {StepId.s8_4_9, StepId.s8_4_13},
      );

      // 自動能力の誘発有無を含むため、アプリが判定してはいけない (CLAUDE.md §1)。
      expect(StepId.s8_4_12.decision, StepDecision.playerDeclared);

      // 分岐はプレイヤーに提示できるよう選択肢名を持つ。
      for (final transition in transitions) {
        expect(transition.label, isNotEmpty);
      }
    });

    test('★8.4.9 の前任が 2 つある = 静的グラフの逆辺では 1 つ戻れない', () {
      // 2 周目の 8.4.9 から 1 つ戻る先は 1 周目の 8.4.12 であって 8.4.8 ではない。
      // 巻き戻しは通過履歴スタックから行う必要がある (設計メモ §6)。
      final predecessors = stepGraph.entries
          .where((e) => e.value.any((t) => t.target == StepId.s8_4_9))
          .map((e) => e.key)
          .toSet();
      expect(predecessors, {StepId.s8_4_8, StepId.s8_4_12});
    });

    test('フェイズを終了する遷移を持つのは終端 7 ステップと 8.3.6 だけ', () {
      final ending = stepGraph.entries
          .where((e) => e.value.any((t) => t.endsPhase))
          .map((e) => e.key)
          .toSet();
      expect(ending, {
        StepId.s7_4_3,
        StepId.s7_5_3,
        StepId.s7_6_3,
        StepId.s7_7_3,
        StepId.s8_2_5,
        StepId.s8_3_17,
        StepId.s8_4_14,
        StepId.s8_3_6, // ★早期終了
      });
    });

    test('遷移先はすべて実在のステップで、同じフェイズ内に閉じている', () {
      for (final phase in PhaseId.values) {
        final inPhase = phase.steps.toSet();
        for (final step in phase.steps) {
          for (final transition in stepGraph[step]!) {
            final target = transition.target;
            if (target == null) continue;
            expect(inPhase, contains(target),
                reason: '${step.ruleRef} → ${target.ruleRef} がフェイズを跨いでいる');
          }
        }
      }
    });

    test('すべての遷移が根拠の条番号を持つ', () {
      for (final transitions in stepGraph.values) {
        for (final transition in transitions) {
          expect(transition.ruleRef, isNotEmpty);
        }
      }
    });
  });

  group('StepCursor — (PhaseId, StepId) で一意', () {
    test('★StepId 単体では一意にならない', () {
      // 8.3.3〜8.3.17 は先攻・後攻パフォーマンスフェイズの 2 インスタンスある。
      const first = StepCursor(PhaseId.firstPerformance, StepId.s8_3_10);
      const second = StepCursor(PhaseId.secondPerformance, StepId.s8_3_10);

      expect(first.step, second.step);
      expect(first, isNot(second));
    });

    test('値として等価比較できる (巻き戻しの履歴スタック用)', () {
      const a = StepCursor(PhaseId.liveJudgement, StepId.s8_4_9);
      const b = StepCursor(PhaseId.liveJudgement, StepId.s8_4_9);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      // ★★ 意図的に等しい 2 つを並べている ★★
      //   `StepCursor` が値として等価なら Set が 1 つに畳むこと自体が検査対象。
      //   直すと**この検査が消える**ので、ルールのほうを 1 行だけ黙らせる。
      // ignore: equal_elements_in_set
      expect({a, b}.length, 1);
      expect(a.toString(), 'liveJudgement@8.4.9');
    });
  });

  group('LiveJudgementRecord — 総合ルール 8.4', () {
    test('★勝敗と 8.4.7 の移動実績は一致しない', () {
      // 設計メモの具体例:
      //   同点で A はライブ置き場に 1 枚、B は 2 枚。
      //   8.4.6.2 により両者勝利だが、8.4.7.1 により B は移動しない。
      //   → 8.4.13 は「一方のプレイヤーのみが移動」に該当し A が先攻になる。
      const record = LiveJudgementRecord(
        winnerIds: {'A', 'B'},
        movedToSuccessIds: {'A'},
      );

      expect(record.winnerIds.length, 2, reason: '8.4.6.2 同点は両者勝利');
      expect(record.movedToSuccessIds, {'A'}, reason: '8.4.7.1 で B は移動しない');
      expect(record.hasSoleMover, isTrue, reason: '8.4.13 の条件を満たす');

      // ★勝敗で判定すると「勝者が 1 人に定まらない」として誤る。
      expect(record.winnerIds.length == 1, isFalse);
    });

    test('8.4.6.1 両者カード無しなら勝者なし', () {
      const record = LiveJudgementRecord();
      expect(record.winnerIds, isEmpty);
      expect(record.movedToSuccessIds, isEmpty);
      expect(record.hasSoleMover, isFalse);
    });

    test('両者が移動した場合は 8.4.13 の条件を満たさない', () {
      const record = LiveJudgementRecord(
        winnerIds: {'A', 'B'},
        movedToSuccessIds: {'A', 'B'},
      );
      expect(record.hasSoleMover, isFalse, reason: '現在の先攻が継続する');
    });
  });

  group('GameState', () {
    GameState build() => GameState(
          players: const [PlayerState(playerId: 'A'), PlayerState(playerId: 'B')],
          firstPlayerId: 'A',
          cursor: const StepCursor(PhaseId.firstActive, StepId.s7_4_1),
        );

    test('★解決領域は GameState が 1 つだけ持つ (4.14.1)', () {
      final state = build();

      // 両プレイヤー共有なので PlayerState 側には無い。
      expect(state.resolution, isEmpty);
      expect(
        state.copyWith(resolution: [_card('y1', ownerId: 'A')]).resolution.length,
        1,
      );
    });

    test('★解決領域のカードは ownerId で絞れる (8.3.14)', () {
      // 先攻パフォーマンス後も先攻のエールカードが残ったまま
      // 後攻パフォーマンスに入るため、絞り込みが必須になる。
      final state = build().copyWith(resolution: [
        _card('y1', ownerId: 'A'),
        _card('y2', ownerId: 'A'),
        _card('y3', ownerId: 'B'),
      ]);

      expect(state.resolution.where((c) => c.ownerId == 'A').length, 2);
      expect(state.resolution.where((c) => c.ownerId == 'B').length, 1);
    });

    test('★firstPlayerId を持ち、ロールから実プレイヤーを解決できる', () {
      final state = build();
      expect(state.firstPlayerId, 'A');

      // 8.4.13 で入れ替わる。書き換えるのはこの 1 箇所だけ。
      expect(state.copyWith(firstPlayerId: 'B').firstPlayerId, 'B');
    });

    test('RuleConfig を再利用している (総合ルール 6.1)', () {
      final state = build();
      // 6.2.1.5 の初期手札 6 枚 / 6.2.1.7 の初期エネルギー 3 枚 /
      // 4.5.2 のメンバーエリア 3 つ / 1.2.1.1 の勝利条件 3 枚。
      expect(state.config.initialHandSize, 6);
      expect(state.config.initialEnergyOnField, 3);
      expect(state.config.stageAreaCount, 3);
      expect(state.config.winCondition, 3);
    });

    test('liveJudgement は 8.4 の外では null', () {
      final state = build();
      expect(state.liveJudgement, isNull);

      final judging = state.copyWith(
        cursor: const StepCursor(PhaseId.liveJudgement, StepId.s8_4_7),
        liveJudgement: const LiveJudgementRecord(movedToSuccessIds: {'A'}),
      );
      expect(judging.liveJudgement!.hasSoleMover, isTrue);

      // ターンを跨ぐ際に落とせること。
      expect(judging.copyWith(clearLiveJudgement: true).liveJudgement, isNull);
    });

    test('★ルール外の置き場は PlayerState 上で 4 章の領域と分かれている', () {
      const player = PlayerState(playerId: 'A');
      expect(player.mulliganAside, isEmpty); // 6.2.1.6
      expect(player.freeArea, isEmpty); // ルール外

      final withAside = player.copyWith(mulliganAside: [_card('h1')]);
      expect(withAside.mulliganAside.length, 1);
      // 4 章の領域は影響を受けない。
      expect(withAside.hand, isEmpty);
      expect(withAside.mainDeck, isEmpty);
    });
  });
}
