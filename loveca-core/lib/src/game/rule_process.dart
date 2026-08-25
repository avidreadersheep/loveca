/// 整理コマンド（ルール処理 10.3〜10.6）.
///
/// 総合ルール 10.1 / 10.4 / 10.5 に対応。
///
/// ★★ リフレッシュ (10.2) はここに入れない ★★
///   10.1.2「ルール処理は、リフレッシュ (10.2) を除き、チェックタイミングにおいてのみ
///   条件を満たしているかを確認し、満たされている場合に実行されます」
///   リフレッシュだけは処理の途中に割り込むため `refresh.dart` が持つ。
///
/// ★★ 1 回の整理 = 同時実行 → 再判定のループ ★★
///   10.1.3「ルール処理が複数同時に実行を求められる場合、それらをすべて同時に実行します」
///   9.5.3.1「現在処理を行うべきルール処理すべてを同時に実行します。その結果新たに
///   行うべきルール処理が発生している場合、この手順を…繰り返します」
///
/// ★★ 自動実行しないルール処理が 2 つある ★★
///   10.3 勝利処理           … 決定 D10「勝敗確定は手動ボタン」と競合するため警告のみ
///   10.6 不正解決領域処理   … 下記の理由により警告のみ
///
///   10.6.1 は「現在プレイ中または解決中であるまたはエール処理中である以外のカード」を
///   控え室へ送れと定めるが、「プレイ中 / 解決中」の判定には効果の解決状態の管理が要り、
///   D-A（カード効果の自動処理は実装しない）に抵触する。
///   D-A のもとでプレイヤーは効果を手動処理するために解決領域へカードを置くため、
///   自動で控え室へ送るとプレイヤーの作業を破壊する。10.3 と同じ扱いにする。

library;

import '../entities/card.dart';
import 'card_instance.dart';
import 'card_move.dart';
import 'game_state.dart';
import 'member_area.dart';
import 'zone.dart';

/// 実行したルール処理の種別。
enum RuleProcessKind {
  /// 10.4.1 重複メンバー処理。
  duplicateMember('10.4.1'),

  /// 10.5.1 ライブカード置き場のライブでない表向きのカード。
  invalidLiveStage('10.5.1'),

  /// 10.5.2 エネルギー置き場のエネルギーでないカード。
  invalidEnergyField('10.5.2'),

  /// 10.5.3 上に重なっているメンバーの無いメンバーカード。
  orphanMember('10.5.3'),

  /// 10.5.4 上に重なっているメンバーの無いエネルギーカード。
  orphanEnergy('10.5.4');

  const RuleProcessKind(this.ruleRef);

  final String ruleRef;
}

/// 自動実行せず警告に留めるルール処理の種別。
enum RuleProcessWarningKind {
  /// 10.3 勝利処理。決定 D10 の手動確定に委ねる。
  ///
  /// ★1.2.1.2 により両者同時に 3 枚以上なら引き分け。
  ///   D10 の手動確定には引き分けの選択肢が要る。
  victory('10.3'),

  /// 10.6 不正解決領域処理。「プレイ中 / 解決中」が観測できないため (D-A)。
  invalidResolution('10.6');

  const RuleProcessWarningKind(this.ruleRef);

  final String ruleRef;
}

/// 整理コマンドの結果。
class RuleProcessResult {
  const RuleProcessResult({
    required this.state,
    this.applied = const [],
    this.warnings = const [],
    this.rounds = 0,
    this.excludedCount = 0,
    this.unknownCardNumbers = const [],
  });

  final GameState state;

  /// 実行したルール処理。10.1.3 により 1 ラウンド内は同時実行。
  final List<RuleProcessKind> applied;

  /// 自動実行せず警告に留めたもの。UI に出す。
  final List<RuleProcessWarningKind> warnings;

  /// 9.5.3.1 の再判定ループを回った回数。
  final int rounds;

  /// カードマスタに無く種別を判定できなかったため処理しなかった枚数。
  final int excludedCount;

  /// 除外の原因になった cardNumber（重複排除・昇順）。
  final List<String> unknownCardNumbers;

  bool get hasExclusions => excludedCount > 0;

  bool get hasWarnings => warnings.isNotEmpty;
}

/// ルール処理の実行。
class RuleProcessor {
  const RuleProcessor({required this.cards, this.maxRounds = 64});

  /// cardNumber -> Card。10.5.2 / 10.5.3 / 10.5.4 の種別判定に要る。
  final Map<String, Card> cards;

  /// 9.5.3.1 のループの上限。条文上は自然に収束するが、暴走を止める安全弁。
  final int maxRounds;

  /// 整理を 1 回実行する。
  ///
  /// 10.1.3 で該当するものを同時実行し、9.5.3.1 で新たに生じたものが
  /// 無くなるまで再判定する。
  RuleProcessResult tidy(GameState state) {
    var next = state;
    final applied = <RuleProcessKind>[];
    final excluded = <String>{};
    var excludedCount = 0;
    var rounds = 0;

    while (rounds < maxRounds) {
      final round = _applyOnce(next);
      if (round.applied.isEmpty) break;

      next = round.state;
      applied.addAll(round.applied);
      excluded.addAll(round.unknownCardNumbers);
      excludedCount += round.excludedCount;
      rounds++;
    }

    return RuleProcessResult(
      state: next,
      applied: applied,
      warnings: warningsFor(next),
      rounds: rounds,
      excludedCount: excludedCount,
      unknownCardNumbers: excluded.toList()..sort(),
    );
  }

  /// ★自動実行しないルール処理の検出。10.3 / 10.6。
  ///
  /// 盤面を変更せず、該当する事象があることだけを返す。
  List<RuleProcessWarningKind> warningsFor(GameState state) {
    final warnings = <RuleProcessWarningKind>[];

    // 10.3.1: 成功ライブカード置き場にカードが 3 枚以上ある。
    // ★10.3.1 は「勝利ライブカード置き場」と書くが誤記。1.2.1.1 / 4.10 が正。
    // ★決定 D10 により勝敗確定は手動ボタン。ここでは検出だけ行う。
    //   1.2.1.2 により両者同時に 3 枚以上なら引き分けになる。
    if (state.players
        .any((p) => p.successLive.length >= state.config.winCondition)) {
      warnings.add(RuleProcessWarningKind.victory);
    }

    // 10.6.1: 解決領域にプレイ中・解決中・エール処理中でないカードがある。
    // ★「プレイ中 / 解決中」は効果の解決状態であり観測できない (D-A)。
    //   カードが存在することだけを検出し、送るかどうかはプレイヤーに委ねる。
    if (state.resolution.isNotEmpty) {
      warnings.add(RuleProcessWarningKind.invalidResolution);
    }

    return warnings;
  }

  /// 1 ラウンド分。該当するルール処理を同時に実行する (10.1.3)。
  _Round _applyOnce(GameState state) {
    var next = state;
    final applied = <RuleProcessKind>[];
    final excluded = <String>{};
    var excludedCount = 0;

    // カードを行き先の領域へ送る。
    //
    // ★行き先はオーナーの領域 (4.1.7)。エリアが属するプレイヤーではない。
    // ★10.5.5 を広義に読み、エネルギーカードは控え室ではなくエネルギーデッキ置き場へ。
    //   ルール処理でエネルギーが控え室へ行く経路は存在しない（設計メモ §9）。
    void sendToOwner(CardInstance instance) {
      final card = cards[instance.cardNumber];
      if (card == null) {
        excluded.add(instance.cardNumber);
        excludedCount++;
        return;
      }
      final zone =
          card.cardType == CardType.energy ? Zone.energyDeck : Zone.waitingRoom;
      // 4.1.2.1: 控え室 (4.12.2) は公開領域、エネルギーデッキ置き場 (4.9.2) は
      //   非公開領域。★行き先で表示面が割れるので `placedIn` に決めさせる。
      final cleaned =
          placedIn(instance.copyWith(clearOrientation: true), zone);
      next = replaceZone(
        next,
        instance.ownerId,
        zone,
        insertInto(
            cardsIn(next, instance.ownerId, zone), [cleaned], ZonePosition.top),
      );
    }

    for (final player in state.players) {
      final playerId = player.playerId;
      final areas = <MemberArea>[];
      var areasChanged = false;

      for (final area in next.playerOf(playerId).memberAreas) {
        var stacks = area.stacks;
        var orphans = area.orphans;

        // 総合ルール 10.4.1（重複メンバー処理）:
        //   「最も後から置かれたメンバーを 1 枚選び、それ以外のそのメンバーエリアのカードを
        //    オーナーの控え室に置きます」
        //
        // ★ここは 10.4.1 の字面とは意図的に異なる。
        //   字面どおりなら「それ以外のカード」に残すメンバーの下のスタックも含まれるが、
        //   4.5.5.3（メンバーがエリア間を移動する際は下のカードも重なったまま同時に移動する）
        //   との整合を優先し、残すメンバーのスタックは維持する。
        //   剥がすのは他のメンバーと、その下に重なっていたカードだけ。
        //
        //   取り残されたカードの行き先は種別で分かれる:
        //     メンバーカード   → 控え室                 (4.5.5.4.1 / 10.5.3)
        //     エネルギーカード → エネルギーデッキ置き場 (4.5.5.4.2 / 10.5.4 / 10.5.5)
        //
        //   エネルギーが控え室へ行かないのは 10.5.5 を広義に読んでいるため。
        //   エネルギーカードは控え室を経由しない閉ループとして設計されている
        //   (4.9 / 4.7 / 5.9.1 / 10.5.4)。10.4.1 だけがその閉ループを破りうる。
        //
        //   公式 Q&A で裏が取れたら再確認する。docs/PhaseEngine設計メモ.md §9-§10 参照。
        //
        // ★「最も後から置かれた」は MemberArea.stacks のリスト順を配置順とする規約で
        //   解決する（追加は末尾）。4.5.3 は「メンバーエリアは…カードの順番は管理されません」
        //   と定めており条文上は衝突する。設計メモ §10 の【要確認】を参照。
        if (stacks.length > 1) {
          final survivor = stacks.last;
          for (final stack in stacks) {
            if (identical(stack, survivor)) continue;
            sendToOwner(stack.member);
            stack.beneath.forEach(sendToOwner);
          }
          stacks = [survivor];
          applied.add(RuleProcessKind.duplicateMember);
          areasChanged = true;
        }

        // ---- 10.5.3 / 10.5.4 上に重なっているメンバーの無いカード ----
        if (orphans.isNotEmpty) {
          for (final orphan in orphans) {
            final card = cards[orphan.cardNumber];
            applied.add(card?.cardType == CardType.energy
                ? RuleProcessKind.orphanEnergy
                : RuleProcessKind.orphanMember);
            sendToOwner(orphan);
          }
          orphans = const [];
          areasChanged = true;
        }

        areas.add(area.copyWith(stacks: stacks, orphans: orphans));
      }

      if (areasChanged) {
        next = _replaceMemberAreas(next, playerId, areas);
      }

      // ---- 10.5.1 ライブカード置き場のライブでない表向きのカード ----
      final liveStage = cardsIn(next, playerId, Zone.liveStage);
      final invalidLive = liveStage.where(_isInvalidOnLiveStage).toList();
      if (invalidLive.isNotEmpty) {
        next = replaceZone(next, playerId, Zone.liveStage,
            liveStage.where((c) => !invalidLive.contains(c)).toList());
        invalidLive.forEach(sendToOwner);
        applied.add(RuleProcessKind.invalidLiveStage);
      }

      // ---- 10.5.2 エネルギー置き場のエネルギーでないカード ----
      final energyField = cardsIn(next, playerId, Zone.energyField);
      final invalidEnergy = energyField.where(_isInvalidOnEnergyField).toList();
      if (invalidEnergy.isNotEmpty) {
        next = replaceZone(next, playerId, Zone.energyField,
            energyField.where((c) => !invalidEnergy.contains(c)).toList());
        // ★10.5.2 の対象は定義上エネルギーではないので 10.5.5 は効かない。控え室へ。
        invalidEnergy.forEach(sendToOwner);
        applied.add(RuleProcessKind.invalidEnergyField);
      }
    }

    return _Round(
      state: next,
      applied: applied,
      excludedCount: excludedCount,
      unknownCardNumbers: excluded.toList(),
    );
  }

  /// 10.5.1 の対象か。★裏向きのカードは対象外（8.2.2 のブラフは正規戦術）。
  bool _isInvalidOnLiveStage(CardInstance instance) {
    if (instance.face != FaceState.faceUp) return false;
    final card = cards[instance.cardNumber];
    return card != null && card.cardType != CardType.live;
  }

  /// 10.5.2 の対象か。
  bool _isInvalidOnEnergyField(CardInstance instance) {
    final card = cards[instance.cardNumber];
    return card != null && card.cardType != CardType.energy;
  }

  GameState _replaceMemberAreas(
    GameState state,
    String playerId,
    List<MemberArea> areas,
  ) =>
      state.copyWith(
        players: [
          for (final p in state.players)
            p.playerId == playerId ? p.copyWith(memberAreas: areas) : p,
        ],
      );
}

class _Round {
  const _Round({
    required this.state,
    required this.applied,
    required this.excludedCount,
    required this.unknownCardNumbers,
  });

  final GameState state;
  final List<RuleProcessKind> applied;
  final int excludedCount;
  final List<String> unknownCardNumbers;
}
