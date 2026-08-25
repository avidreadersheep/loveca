/// どのメンバーの下に置くかを選ぶ（総合ルール 4.5.5 / 5.10.1 / 決定 D85）.
///
/// ★★ 2 択では足りない ★★
/// [StackUnderMember] は `memberInstanceId` を要る。
/// メンバーが 2 人以上いるエリアは 10.4 の重複メンバー処理を待っている
/// **正規の中間状態**（`member_area.dart`）なので、いつでも起こりうる。
/// [DropEdge] の上下だけでは「どのメンバーの下か」を表せない。
///
/// ★★ 黙って末尾のメンバーの下に入れない ★★
/// `MemberArea.stacks` のリスト順は配置順で、末尾が 10.4.1 の
/// 「最も後から置かれたメンバー」である。**それを勝手に選ぶ理由が条文に無い。**
///
/// ★キャンセルできること。キャンセルしたら `dispatch` しない（履歴が増えない）。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;

import '../common/card_thumb.dart';
import 'board_drag.dart';
import 'board_slot.dart';
import 'board_view.dart';

/// 選ばれたメンバーの `instanceId`。★キャンセルなら null。
Future<String?> showStackUnderChoice(
  BuildContext context,
  NeedsMemberChoice choice,
) {
  final view = BoardView.of(context);

  return showDialog<String>(
    context: context,
    // ★★ ダイアログは別のサブツリーなので視点を配り直す ★★
    builder: (context) => view.provideTo(
      AlertDialog(
        key: const ValueKey('stack-under-choice'),
        title: const Text('どのメンバーの下に置きますか'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${choice.slot.label}にメンバーが ${choice.candidates.length} 人います。'
                '10.4 の重複メンバー処理を待っている状態です（4.5.5 / 5.10.1）。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final member in choice.candidates)
                      _MemberChoiceTile(member: member),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('stack-under-cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('やめる'),
          ),
        ],
      ),
    ),
  );
}

class _MemberChoiceTile extends StatelessWidget {
  const _MemberChoiceTile({required this.member});

  final CardInstance member;

  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);
    final printing = view.catalog.printings[member.printingId];
    final card = printing == null
        ? null
        : view.catalog.cards[printing.cardNumber];

    return ListTile(
      key: ValueKey('stack-under-${member.instanceId}'),
      leading: SizedBox(
        width: 40,
        height: 40 / kCardAspectRatio,
        child: BoardCard(card: member, width: 40),
      ),
      title: Text(card?.name ?? 'カードデータが未取得'),
      subtitle: Text(
        member.printingId,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => Navigator.of(context).pop(member.instanceId),
    );
  }
}
