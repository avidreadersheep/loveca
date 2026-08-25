/// 札 1 枚にできる操作のメニュー（M-B2 / 決定 D85）.
///
/// ★★ その札の**居場所で合法な操作だけ**を出す ★★
/// 4.3.1 は配置状態が指定されるのを「**一部の領域において**」と限定しており、
/// 表示面も向きも、どの領域でも持てるわけではない。
///
/// | 操作 | 出す場所 | 出さない場所と理由 |
/// |---|---|---|
/// | 表裏の反転（5.3.1 / 4.3.3） | 4.6 / 4.7 / 4.10 / 4.12 / 4.13 | ★**4.11 手札には出さない**——4.11 に表示面の規定が無く、盤面は 4.11.2 に従って**常に中身を出す**ので反転しても観測差が無い。★4.5 / 4.14 は `reduce` が弾く（`card_move.dart`）ので構造的に出せない（未決 **U14**） |
/// | 向き（5.2.1 / 4.7.3） | 4.7 エネルギー置き場**のみ** | ★4.7.3 が向きを与える唯一の [Zone] |
/// | メンバーの向き（5.2.1 / 4.5.4） | メンバーエリアのメンバー | ★**下に重ねられたカードには出さない**（4.5.5.2 が配置状態を持たないと定める） |
/// | 下から剥がす（4.5.5.4.1 / 4.5.5.4.2） | 下に重ねられたカード | — |
///
/// ★★ できることが無いときも黙って閉じない ★★
/// 空のメニューが出ると「壊れている」と読まれる。**なぜ何も無いのか**を条番号つきで出す。
/// このリポジトリで一貫している「黙って効かないボタンを作らない」の裏返しである。
///
/// ★★ M-B6 で 1 つ足した（決定 D74 / D93）★★
/// メンバーの札に**ポジションチェンジ 11.10** を出す。
/// ★11.10.1 が「**そのメンバーを**」と対象を 1 人指名する動詞なので、
/// 札から始めるのが条文の構造と一致する。
/// ★**フォーメーションチェンジ 11.11 はここではない** —— 11.11.1 は
/// 「**ステージにいるすべてのメンバーを**」なので袖（プレイヤー単位）に置く。
/// 主語が違うものに同じ入口を与えると、UI が条文の構造を潰す。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;

import 'board_drag.dart';
import 'board_formation.dart';
import 'board_view.dart';

/// 掴める札（[BoardPiece]）のメニュー。
Future<void> showBoardCardMenu(BuildContext context, BoardDrag drag) {
  final card = drag.card;

  final entries = switch (drag) {
    ZoneCardDrag(:final playerId, :final zone) => [
        ..._flipEntry(playerId, zone, card),
        ..._orientationEntry(playerId, zone, card),
      ],
    MemberCardDrag(:final playerId, :final slot) => [
        _MenuEntry(
          label: card.orientation == CardOrientation.active
              ? '横向き（ウェイト）にする 5.2.1 / 4.5.4'
              : '縦向き（アクティブ）にする 5.2.1 / 4.5.4',
          action: SetMemberOrientation(
            instanceId: card.instanceId,
            playerId: playerId,
            slot: slot,
            orientation: card.orientation == CardOrientation.active
                ? CardOrientation.wait
                : CardOrientation.active,
          ),
        ),
        // ★★ ポジションチェンジ 11.10（決定 D74 / D93）★★
        //   ★これはカード効果の自動処理ではない。プレイヤーが宣言して押す（D-A）。
        //   ★入れ替え（11.10.2）は 2 アクションの合成で、**1 undo で戻る**。
        _MenuEntry(
          label: 'ポジションチェンジする 11.10',
          run: (context) => showPositionChange(
            context,
            // ★描くプレイヤーの一覧から受け取る（`state.players` を引き直さない / D88）。
            player: BoardView.of(context).drawnPlayerOf(playerId),
            slot: slot,
            member: card,
          ),
        ),
        const _MenuEntry(
          label: '★裏向きにはできません。4.5 に表示面の規定がありません（4.5.3 は公開領域）',
        ),
      ],
    ResolutionCardDrag() => const [
        _MenuEntry(
          label: '★解決領域（4.14.2）は公開領域で、向きも表示面も持ちません',
        ),
      ],
    OutOfRuleCardDrag() => const [
        _MenuEntry(
          label: '★盤の外は総合ルール 4 章の領域ではありません。'
              '向きも表示面も規定がありません',
        ),
      ],
  };

  return _present(context, entries);
}

/// メンバーの下に重ねられたカードのメニュー。総合ルール 4.5.5.1。
///
/// ★掴ませていないのでここが唯一の口である（`board_drag.dart` の [BoardDrag] を参照）。
Future<void> showBeneathCardMenu(
  BuildContext context, {
  required String playerId,
  required MemberAreaSlot slot,
  required CardInstance card,
}) =>
    _present(context, [
      _MenuEntry(
        label: '下から剥がす 4.5.5.4.1',
        action: DetachFromMember(
          instanceId: card.instanceId,
          playerId: playerId,
          slot: slot,
        ),
      ),
      const _MenuEntry(
        // ★剥がした先は「孤児」。行き先を決めるのはルール処理（10.1.2 のチェックタイミング）。
        label: '★剥がすとエリアに残ります。'
            '控え室 / エネルギーデッキへは整理（10.5.3 / 10.5.4）で移ります',
      ),
      const _MenuEntry(
        // ★4.5.5.2: 下に重ねられたカードは向きを示す配置状態を持たない。
        label: '★向きは変えられません（4.5.5.2）',
      ),
    ]);

/// 上にメンバーが居なくなったカード（孤児）のメニュー。4.5.5.4.1 / 4.5.5.4.2。
///
/// ★★ できることが無い。だからこそ理由を出す ★★
/// 解消は 10.5.3 / 10.5.4 のルール処理であり、10.1.2 により
/// **チェックタイミングでのみ**実行される。整理は M-B6。
Future<void> showOrphanCardMenu(BuildContext context) => _present(context, const [
      _MenuEntry(
        label: '★上にメンバーが居ないカードです（4.5.5.4.1 / 4.5.5.4.2）。'
            'これは正規の中間状態で、不具合ではありません',
      ),
      _MenuEntry(
        label: '★整理（10.4 / 10.5）で控え室 / エネルギーデッキへ移ります',
      ),
    ]);

/// 4.11 手札に反転を出さない理由も含めて組む。
List<_MenuEntry> _flipEntry(String playerId, Zone zone, CardInstance card) {
  if (zone == Zone.hand) {
    return const [
      _MenuEntry(
        label: '★手札は常に中身を出しています（4.11.2）。'
            '4.11 に表示面の規定がないので、裏返しても見え方は変わりません',
      ),
    ];
  }
  final faceUp = card.face == FaceState.faceUp;
  return [
    _MenuEntry(
      label: faceUp ? '裏向きにする 5.3.1 / 4.3.3.2' : '表向きにする 5.3.1 / 4.3.3.1',
      action: FlipCard(
        instanceId: card.instanceId,
        playerId: playerId,
        zone: zone,
        face: faceUp ? FaceState.faceDown : FaceState.faceUp,
      ),
    ),
  ];
}

/// ★向きを持つ [Zone] は 4.7 だけ（4.7.3）。
List<_MenuEntry> _orientationEntry(
  String playerId,
  Zone zone,
  CardInstance card,
) {
  if (zone != Zone.energyField) return const [];
  final active = card.orientation != CardOrientation.wait;
  return [
    _MenuEntry(
      label: active
          ? '横向き（ウェイト）にする 5.2.1 / 4.7.3'
          : '縦向き（アクティブ）にする 5.2.1 / 4.7.3',
      action: SetOrientation(
        instanceId: card.instanceId,
        playerId: playerId,
        zone: zone,
        orientation: active ? CardOrientation.wait : CardOrientation.active,
      ),
    ),
  ];
}

class _MenuEntry {
  const _MenuEntry({required this.label, this.action, this.run});

  final String label;

  /// 押したら `dispatch` する 1 件のアクション。
  final GameAction? action;

  /// ★★ ダイアログを開くなど、1 アクションで表せない行（M-B6）★★
  /// ポジションチェンジ 11.10 は移動先を選ばせ、**2 アクションの合成**になる。
  /// ★[action] と両方を渡さないこと（どちらが走るか読めなくなる）。
  final Future<void> Function(BuildContext context)? run;

  /// null / null なら**説明だけ**の行（押せない）。
  bool get isEnabled => action != null || run != null;
}

Future<void> _present(BuildContext context, List<_MenuEntry> entries) async {
  final store = BoardView.of(context).store;
  final box = context.findRenderObject();
  final overlay = Overlay.of(context).context.findRenderObject();
  if (box is! RenderBox || overlay is! RenderBox) return;

  final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
  // ★値ではなく**添字**を返す（[_MenuEntry.run] を持つ行があるため）。
  final chosen = await showMenu<int>(
    context: context,
    position: RelativeRect.fromLTRB(
      topLeft.dx,
      topLeft.dy + box.size.height,
      overlay.size.width - topLeft.dx - box.size.width,
      0,
    ),
    items: [
      for (var i = 0; i < entries.length; i++)
        PopupMenuItem<int>(
          key: ValueKey('card-menu-$i'),
          value: i,
          // ★説明だけの行は押せない。**が、消さない**（理由が読めなくなる）。
          enabled: entries[i].isEnabled,
          child: Text(entries[i].label,
              style: Theme.of(context).textTheme.bodySmall),
        ),
    ],
  );

  if (chosen == null) return;
  final entry = entries[chosen];
  if (entry.action case final action?) store.dispatch(action);
  if (!context.mounted) return;
  await entry.run?.call(context);
}
