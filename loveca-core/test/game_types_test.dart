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
}
