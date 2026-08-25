/// ポジションチェンジ 11.10 / フォーメーションチェンジ 11.11（決定 D74 / D93 / §3）.
///
/// ## ★★ これはカード効果の自動処理ではない（CLAUDE.md §1 / D-A）★★
///
/// 11.10 / 11.11 は `【】` のキーワード能力ではなく**効果テキスト中の動詞**である。
/// **いつ起きるかを決めるのは効果**であり、アプリは読まない。
/// **プレイヤーが宣言して押す。**アプリがやるのは
/// **複数の移動をまとめて 1 回で適用すること**だけで、D-A の許す「移動」に収まる。
///
/// ★★ 置く理由 ★★ 11.11.1（全員の再配置）を素のドラッグでやると 3〜5 回になり、
/// そのあいだ 1 エリアに 2 人並ぶ中間状態が続く。
/// **うっかり「整理する」を押すと 10.4 で片方が控え室へ行く。**
///
/// ## ★★ 範囲は片側 3 エリアである —— 条文から導ける（決定 D93-1）★★
///
/// 「読み」ではない。**4.1.6 が既に絞っている。**
///
/// > **4.1.6** あるカードが持つテキストや能力や効果において、その中でなんらかの領域を
/// > 参照していて、**その領域が属するプレイヤーが特に指名されていない場合、
/// > そのカードのマスターに属する領域を参照します**
/// >
/// > **3.1.2** マスターとは、カードや能力や効果などを現在使用しているプレイヤーを
/// > 意味します。**いずれかの領域に置かれているカードのマスターとは、
/// > その領域が属しているプレイヤーを指します**
///
/// 11.11.1 の「ステージ」も 11.10.1 の「エリア」（4.5.1.1 によりメンバーエリア）も
/// **プレイヤーを指名していない**ので、4.1.6 によりマスターの領域＝**片側**に絞られる。
///
/// ★★ 実データ 29 刷り（24 種の効果テキスト）で裏を取った ★★
/// 「読み」で終わらせず観測にした（`loveca-data/data/dist/cards/*.json` の走査）。
///
/// | 観測 | 意味 |
/// |---|---|
/// | フォーメーションチェンジは**すべて**「**自分の**ステージにいるメンバー」と書く | 1 コマンドが 6 エリアを跨ぐ形は**実在しない** |
/// | ★両プレイヤーに及ぶ効果は**実在する**（「【登場】**自分と相手は、自身の**ステージのセンターにいるメンバーをポジションチェンジする。」） | ★**「自身の」と書いて各自の領域に分けている。**別の操作を 2 回押すのが正しい（D92 §15-9 の「1 押下 = 履歴 1 件」と整合する） |
/// | ★相手のメンバーを動かす効果も実在する（「相手のステージにいるメンバー1人を**このメンバーの正面のエリア**に…」） | 4.5.7.1 により正面は**相手側のエリア**なので、これも**片側で完結する**。★領域が明示されているので 4.1.6 の「指名されていない場合」に当たらない（矛盾ではない） |
///
/// ★**型が既に正しい** —— [MoveMemberBetweenAreas] は `playerId` を 1 つしか持たず、
/// 素のドラッグも「メンバーは自分のメンバーエリアの中でだけ動かせます（4.5.5.3）」で
/// 拒否している（`board_drag.dart`）。4.1.6 はその根拠を説明する。
///
/// ## ★★ 制約はコマンドの中だけに置く（決定 D74 / §3-4）★★
///
/// 11.10.2 の入れ替えも 11.11.2 の「1 エリアに 2 人以上不可」も
/// **その効果の中での制約**であって盤面の不変条件ではない。
/// ★**素のドラッグに課してはいけない** —— 課すと 4.5.5 / 10.4 の中間状態を作れなくなり、
/// `MemberArea` が型で表現できるようにした状態（孤児カード / 2 人並んだエリア）を
/// **サンドボックスから削ることになる。**
///
/// ## ★★【要確認】1 エリアに 2 人以上いるとき（決定 D74 / §3-5）★★
///
/// 11.10.2 は移動先のメンバーを**単数**で書いており（「移動先にいるメンバーは」）、
/// **2 人以上いる場合を定めていない。** 11.11.2 も同じで、既に 2 人並んでいると
/// 「すべてのメンバーを 1 エリア 1 人ずつ」が**不可能**になる。
/// → ★**推測で埋めない。**コマンドを無効にし、**理由を出す**（[formationRefusal]）。
/// ★**黙って効かないボタンにしない。**公式 Q&A で裏が取れたら再確認する。
///
/// ## ★★ 合成の途中に `Tidy` を挟まない（§3-3）★★
///
/// 挟むと 10.4 が走って中間状態が壊れる。★`GameStore.dispatchAll` は
/// `reduce` を N 回回して `record` を 1 回だけ呼ぶので、**履歴 1 件 = 1 undo** になる。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;

import 'board_view.dart';

/// ★★ 11.10 / 11.11 を実行できない理由。null なら実行できる ★★
///
/// ★**判定を 2 箇所に置かない。**11.10.2 と 11.11.2 の【要確認】は
/// どちらのコマンドにも効くので、分けて書くと片方だけ直される（D-15 の型）。
String? formationRefusal(PlayerState player) {
  final crowded = [
    for (final area in player.memberAreas)
      if (area.hasDuplicateMembers) area.slot.label,
  ];
  if (crowded.isEmpty) return null;

  return '${crowded.join(' / ')}にメンバーが 2 人以上います。'
      '11.10.2 は移動先のメンバーを単数で書いており（「移動先にいるメンバーは」）、'
      '2 人以上いる場合を定めていません（11.11.2 も同じ）。'
      '★推測で埋めないため、このコマンドは無効にしています。'
      '先に「整理する 10.4 / 10.5」を押してください。';
}

/// そのプレイヤーのメンバー（1 エリア 1 人であることが前提）。
///
/// ★[formationRefusal] が null のときだけ意味を持つ。
List<({MemberAreaSlot slot, CardInstance member})> _membersOf(
  PlayerState player,
) =>
    [
      for (final area in player.memberAreas)
        for (final stack in area.stacks) (slot: area.slot, member: stack.member),
    ];

/// ポジションチェンジ 11.10。★[member] を [slot] 以外のエリアへ移す。
///
/// > **11.10.1** ポジションチェンジするとは、そのメンバーを今いるエリア以外のエリアに
/// > 移動させることである。
/// > **11.10.2** メンバーを移動させた先のエリアにすでにメンバーがいる場合、
/// > 移動先にいるメンバーは、移動してきたメンバーがいたエリアに移動する。
Future<void> showPositionChange(
  BuildContext context, {
  required PlayerState player,
  required MemberAreaSlot slot,
  required CardInstance member,
}) async {
  final view = BoardView.of(context);
  final refusal = formationRefusal(player);

  final target = await showDialog<MemberAreaSlot>(
    context: context,
    // ★ダイアログは別のサブツリーなので視点を配り直す。
    builder: (context) => view.provideTo(_PositionChangeDialog(
      player: player,
      slot: slot,
      member: member,
      refusal: refusal,
    )),
  );
  if (target == null) return;

  final occupant = player.memberAreas
      .firstWhere((area) => area.slot == target)
      .stacks
      .map((stack) => stack.member)
      .firstOrNull;

  // ★★ 1 押下 = 履歴 1 件（M-B5 の合成 / §8-2）★★
  //   1 件ずつ適用すると undo が 2 回要る。
  //   ★間に `Tidy` を挟まないこと（10.4 が走って中間状態が壊れる / §3-3）。
  view.store.dispatchAll([
    MoveMemberBetweenAreas(
      instanceId: member.instanceId,
      playerId: player.playerId,
      fromSlot: slot,
      toSlot: target,
    ),
    // 11.10.2: 移動先にいるメンバーは、移動してきたメンバーがいたエリアへ。
    if (occupant != null)
      MoveMemberBetweenAreas(
        instanceId: occupant.instanceId,
        playerId: player.playerId,
        fromSlot: target,
        toSlot: slot,
      ),
  ]);
}

/// フォーメーションチェンジ 11.11。★そのプレイヤーの全メンバーを再配置する。
///
/// > **11.11.1** フォーメーションチェンジするとは、ステージにいるすべてのメンバーを、
/// > それぞれ好きなエリアに移動させることである。
/// > **11.11.2** この効果で 1 つのエリアに 2 人以上のメンバーを移動させることはできない。
Future<void> showFormationChange(
  BuildContext context, {
  required PlayerState player,
}) async {
  final view = BoardView.of(context);

  final plan = await showDialog<Map<String, MemberAreaSlot>>(
    context: context,
    builder: (context) => view.provideTo(_FormationChangeDialog(player: player)),
  );
  if (plan == null) return;

  // ★★ 動かない人はアクションに入れない ★★
  //   入れると `fromSlot == toSlot` の無意味な移動が履歴に混ざる。
  final actions = [
    for (final entry in _membersOf(player))
      if (plan[entry.member.instanceId] case final target?)
        if (target != entry.slot)
          MoveMemberBetweenAreas(
            instanceId: entry.member.instanceId,
            playerId: player.playerId,
            fromSlot: entry.slot,
            toSlot: target,
          ),
  ];
  if (actions.isEmpty) return;

  // ★★ 途中で 1 エリアに 2 人並ぶ中間状態は正規である（10.1.2 / §3-3 の根拠 2）★★
  //   各メンバーは 1 回しか動かないので、どの順で適用しても `fromSlot` は元のまま。
  view.store.dispatchAll(actions);
}

/// 11.10 の移動先を選ぶ。
class _PositionChangeDialog extends StatelessWidget {
  const _PositionChangeDialog({
    required this.player,
    required this.slot,
    required this.member,
    required this.refusal,
  });

  final PlayerState player;
  final MemberAreaSlot slot;
  final CardInstance member;
  final String? refusal;

  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      key: const ValueKey('position-change'),
      title: Text('${view.labelOf(player.playerId)}のポジションチェンジ 11.10'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '11.10.1「そのメンバーを今いるエリア以外のエリアに移動させる」。'
              '★移動先にメンバーがいる場合、そのメンバーは 11.10.2 により'
              '${slot.label}へ移ります（入れ替え）。',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              // ★★ 範囲を書く（決定 D93-1）★★
              '★移動先は${view.labelOf(player.playerId)}のエリアだけです'
              '（4.1.6 により、効果が領域のプレイヤーを指名していなければ'
              'そのカードのマスターの領域を指します）。',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 12),
            if (refusal case final reason?)
              // ★★ 黙って効かないボタンにしない ★★
              Text(
                reason,
                key: const ValueKey('position-change-refusal'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              )
            else
              for (final target in MemberAreaSlot.values)
                if (target != slot)
                  _TargetTile(player: player, slot: target),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('position-change-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('やめる'),
        ),
      ],
    );
  }
}

class _TargetTile extends StatelessWidget {
  const _TargetTile({required this.player, required this.slot});

  final PlayerState player;
  final MemberAreaSlot slot;

  @override
  Widget build(BuildContext context) {
    final occupied = player.memberAreas
        .firstWhere((area) => area.slot == slot)
        .stacks
        .isNotEmpty;

    return ListTile(
      key: ValueKey('position-change-${slot.name}'),
      title: Text(slot.label),
      subtitle: Text(occupied
          ? '★メンバーがいます。11.10.2 により入れ替わります'
          : '空いています（11.10.1 の移動だけ）'),
      onTap: () => Navigator.of(context).pop(slot),
    );
  }
}

/// 11.11 の割り当てを決める。
class _FormationChangeDialog extends StatefulWidget {
  const _FormationChangeDialog({required this.player});

  final PlayerState player;

  @override
  State<_FormationChangeDialog> createState() => _FormationChangeDialogState();
}

class _FormationChangeDialogState extends State<_FormationChangeDialog> {
  late final Map<String, MemberAreaSlot> _plan = {
    for (final entry in _membersOf(widget.player))
      entry.member.instanceId: entry.slot,
  };

  /// 11.11.2「1 つのエリアに 2 人以上のメンバーを移動させることはできない」。
  List<MemberAreaSlot> get _conflicts {
    final counts = <MemberAreaSlot, int>{};
    for (final slot in _plan.values) {
      counts[slot] = (counts[slot] ?? 0) + 1;
    }
    return [
      for (final entry in counts.entries)
        if (entry.value > 1) entry.key,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);
    final theme = Theme.of(context);
    final refusal = formationRefusal(widget.player);
    final members = _membersOf(widget.player);
    final conflicts = _conflicts;

    return AlertDialog(
      key: const ValueKey('formation-change'),
      title: Text('${view.labelOf(widget.player.playerId)}の'
          'フォーメーションチェンジ 11.11'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '11.11.1「ステージにいるすべてのメンバーを、それぞれ好きなエリアに'
              '移動させる」。★11.11.2 により 1 つのエリアに 2 人以上は置けません。',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              // ★★ 範囲を書く（決定 D93-1）★★
              '★対象は${view.labelOf(widget.player.playerId)}のステージだけです'
              '（4.4.2「プレイヤーはステージ内に自身のメンバーエリアを持ちます」＋ 4.1.6）。'
              '両プレイヤーに及ぶ効果は「自分と相手は、自身のステージの…」と'
              '各自の領域に分けて書かれるので、その場合はもう一方の袖でもう一度押します。',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 12),
            if (refusal case final reason?)
              Text(
                reason,
                key: const ValueKey('formation-change-refusal'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              )
            else if (members.isEmpty)
              Text('ステージにメンバーがいません。', style: theme.textTheme.bodySmall)
            else ...[
              for (final entry in members)
                _AssignRow(
                  member: entry.member,
                  from: entry.slot,
                  to: _plan[entry.member.instanceId]!,
                  onChanged: (slot) => setState(
                      () => _plan[entry.member.instanceId] = slot),
                ),
              if (conflicts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    // ★★ 黙って弾かない ★★
                    '★${conflicts.map((s) => s.label).join(' / ')}に 2 人以上を'
                    '割り当てています。11.11.2 によりこの効果では置けません。',
                    key: const ValueKey('formation-change-conflict'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('formation-change-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('やめる'),
        ),
        FilledButton(
          key: const ValueKey('formation-change-apply'),
          // ★消さずに無効にする（理由はすぐ上に出ている）。
          onPressed: refusal != null || members.isEmpty || conflicts.isNotEmpty
              ? null
              : () => Navigator.of(context).pop(_plan),
          child: const Text('この配置にする'),
        ),
      ],
    );
  }
}

class _AssignRow extends StatelessWidget {
  const _AssignRow({
    required this.member,
    required this.from,
    required this.to,
    required this.onChanged,
  });

  final CardInstance member;
  final MemberAreaSlot from;
  final MemberAreaSlot to;
  final ValueChanged<MemberAreaSlot> onChanged;

  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);
    final printing = view.catalog.printings[member.printingId];
    final card = printing == null ? null : view.catalog.cards[printing.cardNumber];

    return Padding(
      key: ValueKey('formation-row-${member.instanceId}'),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 190,
            child: Text(
              '${card?.name ?? 'カードデータが未取得'}（${from.label}）',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<MemberAreaSlot>(
              key: ValueKey('formation-target-${member.instanceId}'),
              isExpanded: true,
              value: to,
              onChanged: (slot) => slot == null ? null : onChanged(slot),
              items: [
                for (final slot in MemberAreaSlot.values)
                  DropdownMenuItem(value: slot, child: Text(slot.label)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
