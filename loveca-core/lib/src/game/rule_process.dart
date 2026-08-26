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

/// ★★ 整理が「動かせなかった」理由。2 つを混ぜないこと ★★
///
/// ★★ 原因も、利用者にできることも違う ★★
///   | 理由 | 何の問題か | 利用者にできること |
///   |---|---|---|
///   | [unknownCard] | **データ**の問題 | カードデータを取り込み直す |
///   | [noRuleForCardType] | **条文**の問題 | 無い（手で動かすしかない） |
///
///   1 行にまとめると、直せるものと直せないものが同じ文面になる。
///   `docs/UI設計メモ.md` §3-4 で縮退の系統を分けたのと同じ理由である。
enum UnmovableReason {
  /// カードマスタを引けず、種別が分からない。
  ///
  /// ★10.5.2 / 10.5.3 / 10.5.4 も 10.5.5 も種別で行き先が変わるので、
  ///   引けないと行き先が決まらない。
  ///   → 10.1.2「条件を満たしている場合に実行されます」を満たせない。
  unknownCard,

  /// 種別は分かるが、10.5.3（メンバーカード）/ 10.5.4（エネルギーカード）の
  /// どちらの条件にも当てはまらない。
  ///
  /// ★★ 条文が行き先を定めていない ★★
  ///   4.5.5 は「メンバーカードの下に、メンバーカードやエネルギーカードが
  ///   重ねて置かれる場合があります」と**2 種別に限って**書いており、
  ///   ライブカードが下に来る状態を条文は想定していない。
  ///
  ///   アプリはサンドボックス（CLAUDE.md §1 / D-A）なのでその状態を作れるが、
  ///   ★**条文が定めていない移動を実装が決めない**（D-B）。動かさずに残す。
  noRuleForCardType,
}

/// 整理が動かせなかった 1 枚。
///
/// ★★ 「動かせなかった」と言う以上、その札は**元の場所に在る**こと ★★
///   どこにも置かないまま元から消すと、報告が事実に反する
///   （`ルール整合性チェック_v1.06.md` **D-22**）。
class UnmovableCard {
  const UnmovableCard({
    required this.instanceId,
    required this.cardNumber,
    required this.reason,
  });

  /// ★同じ札を何ラウンド走査しても 1 枚と数えるための同一性。
  final String instanceId;

  final String cardNumber;

  final UnmovableReason reason;
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
    this.unmovable = const [],
  });

  final GameState state;

  /// 実行したルール処理。10.1.3 により 1 ラウンド内は同時実行。
  final List<RuleProcessKind> applied;

  /// 自動実行せず警告に留めたもの。UI に出す。
  final List<RuleProcessWarningKind> warnings;

  /// 9.5.3.1 の再判定ループを回った回数。
  final int rounds;

  /// ★★ 動かせなかった札。**元の置き場に残っている** ★★
  ///
  /// ★件数だけにしない。理由が 2 つあり、利用者にできることが違う
  ///   （[UnmovableReason]）。並びは instanceId 昇順で決定的。
  final List<UnmovableCard> unmovable;

  bool get hasUnmovable => unmovable.isNotEmpty;

  /// [reason] の札だけを取り出す。★UI が理由ごとに 1 行を作るため。
  List<UnmovableCard> unmovableFor(UnmovableReason reason) =>
      [for (final c in unmovable) if (c.reason == reason) c];

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
    // ★★ 累積器はループの外に置く（`ルール整合性チェック_v1.06.md` D-22）★★
    //   動かせなかった札は動かないので、次のラウンドでも走査に当たる。
    //   ラウンドごとに数えると「1 枚を 2 枚」と報告するため、instanceId で畳む。
    final unmovable = _Unmovable();
    var rounds = 0;

    while (rounds < maxRounds) {
      final round = _applyOnce(next, unmovable);

      // ★★ break で記録を落とさない ★★
      //   [_applyOnce] は `unmovable` を直接書くので、ここで取りこぼす経路は無い。
      //   ★以前は `_Round` が件数を運んでおり、`applied` が空だと
      //     break で**除外の記録ごと落ちていた**（動かせなかったことすら黙る = A-3）。
      if (round.applied.isEmpty) break;

      next = round.state;
      applied.addAll(round.applied);
      rounds++;
    }

    return RuleProcessResult(
      state: next,
      applied: applied,
      warnings: warningsFor(next),
      rounds: rounds,
      unmovable: unmovable.sorted,
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

  /// ★★ この孤児を 10.5.3 / 10.5.4 で動かせない理由。動かせるなら null ★★
  ///
  /// ★★ 整理の実行とまったく同じ判定である。2 箇所に書かないこと ★★
  ///   盤面は「整理を待っている孤児」と「整理しても動かない孤児」を
  ///   見た目で区別する必要がある（区別できないと、押すたびに同じ帯が出る）。
  ///   その分類をここから取る。UI 側で `cardType` を見て書き直さない。
  UnmovableReason? orphanUnmovableReason(CardInstance instance) =>
      switch (cards[instance.cardNumber]?.cardType) {
        // 10.5.3「上に重なっているメンバーの無いメンバーカード」→ 控え室
        CardType.member => null,
        // 10.5.4「上に重なっているメンバーの無いエネルギーカード」→ エネルギーデッキ置き場
        CardType.energy => null,
        // ★条文に行き先が無い（4.5.5 は下に重ねられるのを 2 種別に限る）。
        CardType.live => UnmovableReason.noRuleForCardType,
        // ★カードマスタを引けない。種別が分からない。
        null => UnmovableReason.unknownCard,
      };

  /// 1 ラウンド分。該当するルール処理を同時に実行する (10.1.3)。
  _Round _applyOnce(GameState state, _Unmovable unmovable) {
    var next = state;
    final applied = <RuleProcessKind>[];

    // カードを行き先の領域へ送る。
    //
    // ★行き先はオーナーの領域 (4.1.7)。エリアが属するプレイヤーではない。
    // ★10.5.5 を広義に読み、エネルギーカードは控え室ではなくエネルギーデッキ置き場へ。
    //   ルール処理でエネルギーが控え室へ行く経路は存在しない（設計メモ §9）。
    //
    // ★★ 引けなかったら **動かさない**。返り値を捨てないこと ★★
    //   種別が分からないと行き先が決まらないので、10.1.2 の「条件を満たしている
    //   場合に実行されます」を満たせない。**元の置き場に残す責任は呼び出し側にある。**
    //   元を無条件に消すと、その札は盤面のどこにも存在しなくなる（D-22）。
    CardType? sendToOwner(CardInstance instance) {
      final card = cards[instance.cardNumber];
      if (card == null) {
        unmovable.add(instance, UnmovableReason.unknownCard);
        return null;
      }
      final zone =
          card.cardType == CardType.energy ? Zone.energyDeck : Zone.waitingRoom;
      // 4.1.2.1: 控え室 (4.12.2) は公開領域、エネルギーデッキ置き場 (4.9.2) は
      //   非公開領域。★行き先で表示面が割れるので `placedIn` に決めさせる。
      // 4.3.1: 向きもあわせて落ちる（どちらの行き先も向きを持たない）。
      final cleaned = placedIn(instance, zone);
      next = replaceZone(
        next,
        instance.ownerId,
        zone,
        insertInto(
            cardsIn(next, instance.ownerId, zone), [cleaned], ZonePosition.top),
      );
      return card.cardType;
    }

    // 送れた札だけを動かし、★**送れなかった札をそのまま返す**。
    //
    // ★返り値を捨てると D-22 が再発する。呼び出し側は必ず元の場所へ戻すこと。
    List<CardInstance> sendAllToOwner(Iterable<CardInstance> instances) => [
          for (final instance in instances)
            if (sendToOwner(instance) == null) instance,
        ];

    for (final player in state.players) {
      final playerId = player.playerId;
      final areas = <MemberArea>[];
      var areasChanged = false;

      for (final area in next.playerOf(playerId).memberAreas) {
        var stacks = area.stacks;
        var orphans = area.orphans;
        // ★10.4.1 でメンバーが去ったあと、動かせずに取り残された下のカード。
        //   4.5.5.4 のとおりエリアに残る = 孤児になる。
        //   ★このラウンドの 10.5.3 / 10.5.4 の走査には**入れない**
        //     （引けないから残っているので、同じラウンドで見ても結果は変わらない）。
        var freedByDuplicate = const <CardInstance>[];

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
        //
        // ★★ 10.4.1 は種別を条件にしていない（10.5.3 / 10.5.4 との格の違い）★★
        //   「それ以外のそのメンバーエリアの**カード**を…控え室に置きます」であり、
        //   10.5.5 が行き先だけを振り替える。★ライブカードでも控え室へ送る。
        //   → ここで動かせないのは**カタログを引けない札だけ**である。
        if (stacks.length > 1) {
          final survivor = stacks.last;
          final keptStacks = <MemberStack>[];
          final keptBeneathAll = <CardInstance>[];
          var movedAny = false;

          for (final stack in stacks) {
            if (identical(stack, survivor)) {
              keptStacks.add(stack);
              continue;
            }
            final memberType = sendToOwner(stack.member);
            final keptBeneath = sendAllToOwner(stack.beneath);
            if (memberType != null ||
                keptBeneath.length != stack.beneath.length) {
              movedAny = true;
            }
            if (memberType == null) {
              // ★★ 引けなかったメンバーは動かせない。束のままエリアに残す ★★
              //   消すと盤面のどこにも存在しなくなる（D-22）。
              //   ★`stacks` に残るので次のチェックタイミングでも 10.4.1 に当たるが、
              //     動く札が無ければ `applied` が空になりループは止まる。
              keptStacks.add(stack.copyWith(beneath: keptBeneath));
            } else {
              // 4.5.5.4: メンバーが去った下のカードは**そのままエリアに残る**。
              keptBeneathAll.addAll(keptBeneath);
            }
          }

          // ★★ 1 枚でも実際に動いたときだけ「実行した」と言う ★★
          //   何も動いていないのに積むと、9.5.3.1 の再判定ループが空回りし、
          //   `maxRounds` まで回ったうえで「64 件実行した」と報告する。
          //
          // ★★ 動いたぶんは必ず盤面へ書き戻す ★★
          //   束の**中身だけ**が変わることがある（メンバーは引けないが下の札は動く）。
          //   束の**数**で判定すると、その変化を取りこぼして
          //   **控え室と束の両方に同じ札が居る**状態を作る。
          //   ★これは実装中に実際に踏んだ。「1 枚も消えない」の検査が
          //     増える側で落ちて見つかった（`rule_process_test.dart`）。
          if (movedAny) {
            applied.add(RuleProcessKind.duplicateMember);
            stacks = keptStacks;
            freedByDuplicate = keptBeneathAll;
            areasChanged = true;
          }
        }

        // ---- 10.5.3 / 10.5.4 上に重なっているメンバーの無いカード ----
        //
        // ★★ 種別を確かめてから動かす。推測で断定しない ★★
        //   条文は種別で行き先を分ける（10.5.3 メンバー→控え室 /
        //   10.5.4 エネルギー→エネルギーデッキ置き場）。
        //   種別が分からない札も、条文が行き先を定めていない種別の札も、
        //   **どちらとも断定できない**ので動かさず元の場所に残す（D-22 / 決定 D95）。
        if (orphans.isNotEmpty) {
          final keptOrphans = <CardInstance>[];
          for (final orphan in orphans) {
            final reason = orphanUnmovableReason(orphan);
            if (reason != null) {
              unmovable.add(orphan, reason);
              keptOrphans.add(orphan);
              continue;
            }
            // ★ここへ来る = カタログを引けて、種別が 10.5.3 / 10.5.4 のどちらか。
            //   ★同じ判定を 2 度書かないため、条番号は送った先の種別から導く。
            final type = sendToOwner(orphan);
            applied.add(type == CardType.energy
                ? RuleProcessKind.orphanEnergy
                : RuleProcessKind.orphanMember);
          }
          if (keptOrphans.length != orphans.length) {
            areasChanged = true;
          }
          orphans = keptOrphans;
        }

        if (freedByDuplicate.isNotEmpty) {
          orphans = [...orphans, ...freedByDuplicate];
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
        // ★★ 送れなかった札はライブカード置き場に残す ★★
        //   [_isInvalidOnLiveStage] が引けない札を選ばないので今日は空になるが、
        //   **作れないからと条件を落とさない**（決定 D94-2 と同じ扱い）。
        //   選び方が緩んだ瞬間に札が消える形を残さない。
        final kept = sendAllToOwner(invalidLive);
        next = replaceZone(next, playerId, Zone.liveStage, [
          ...liveStage.where((c) => !invalidLive.contains(c)),
          ...kept,
        ]);
        if (kept.length != invalidLive.length) {
          applied.add(RuleProcessKind.invalidLiveStage);
        }
      }

      // ---- 10.5.2 エネルギー置き場のエネルギーでないカード ----
      final energyField = cardsIn(next, playerId, Zone.energyField);
      final invalidEnergy = energyField.where(_isInvalidOnEnergyField).toList();
      if (invalidEnergy.isNotEmpty) {
        // ★10.5.2 の対象は定義上エネルギーではないので 10.5.5 は効かない。控え室へ。
        // ★10.5.1 と同じ理由で、送れなかった札は元の置き場に残す。
        final kept = sendAllToOwner(invalidEnergy);
        next = replaceZone(next, playerId, Zone.energyField, [
          ...energyField.where((c) => !invalidEnergy.contains(c)),
          ...kept,
        ]);
        if (kept.length != invalidEnergy.length) {
          applied.add(RuleProcessKind.invalidEnergyField);
        }
      }
    }

    return _Round(state: next, applied: applied);
  }

  /// 10.5.1 の対象か。★裏向きのカードは対象外（8.2.2 のブラフは正規戦術）。
  ///
  /// ★引けない札は選ばない。選ばなければ元の置き場に残る（10.5.3 / 10.5.4 とは
  ///   格が違い、ここは「選ぶ側」で先に弾く形になっている）。
  bool _isInvalidOnLiveStage(CardInstance instance) {
    if (instance.face != FaceState.faceUp) return false;
    final card = cards[instance.cardNumber];
    return card != null && card.cardType != CardType.live;
  }

  /// 10.5.2 の対象か。★引けない札は選ばない（[_isInvalidOnLiveStage] と同じ）。
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

/// 動かせなかった札の記録。
///
/// ★★ instanceId で畳む ★★
///   動かせない札は動かないので、9.5.3.1 の再判定で**次のラウンドでも走査に当たる**。
///   出現回数で数えると「1 枚を 2 枚」と報告する。
class _Unmovable {
  final _byInstanceId = <String, UnmovableCard>{};

  void add(CardInstance instance, UnmovableReason reason) {
    _byInstanceId[instance.instanceId] = UnmovableCard(
      instanceId: instance.instanceId,
      cardNumber: instance.cardNumber,
      reason: reason,
    );
  }

  /// ★並びを決定的にする（同じ入力から同じ報告が出ること）。
  List<UnmovableCard> get sorted {
    final keys = _byInstanceId.keys.toList()..sort();
    return [for (final key in keys) _byInstanceId[key]!];
  }
}

class _Round {
  const _Round({required this.state, required this.applied});

  final GameState state;
  final List<RuleProcessKind> applied;
}
