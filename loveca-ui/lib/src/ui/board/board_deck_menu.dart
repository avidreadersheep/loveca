/// 山を押したときのメニュー（M-B3 / 総合ルール 5.5 / 5.6 / 5.7 / 決定 D73 / D86）.
///
/// ★★ 4.8 と 4.9 は見た目が同じ山だが、できることが違う ★★
/// 同じ形の箱が 2 つ並んでいて中身の違う操作が出る以上、
/// **なぜ違うのかがその場で読めなければならない。**だから両方に理由を書く。
///
/// | | メインデッキ置き場 4.8 | エネルギーデッキ置き場 4.9 |
/// |---|---|---|
/// | 引く 5.6.1 / 5.6.2 | ○ | ★別の口（袖の「エネルギーを1枚出す」/ 4.9.3・D73） |
/// | シャッフル 5.5.1 | ○ | ★**出さない**（下記の理由 2） |
/// | 上から見る 5.7.1 / 10.2.2.2 | ○ | ★**出さない**（下記の理由 1） |
///
/// ★★★ 理由 1 と理由 2 は**格が違う**。混ぜて書かない ★★★
///
/// **理由 1（条文が定めていない）** —— 5.7.1 / 5.7.2 / 10.2.2.2 はいずれも
/// **メインデッキ置き場についての規定**で、エネルギーデッキ置き場を対象にした条は
/// 存在しない。★**禁止する条があるのではない。**
/// 「条文が定めていない操作を実装が足さない」という判断である。
/// ★将来「なぜ付けないのか」を問われて禁止条を探しても見つからない。だから明記する。
///
/// **理由 2（実装の判断）** —— 5.5.1 は「指定されたカード群」への指示であって
/// 4.9 を除外していない。**条文の上ではシャッフルできる。**
/// 出さないのは実装の判断で、4.9.2 が「カードの順番は管理されません」と定める以上
/// **観測できる差が出ない**ため（黙って効かないボタンを作らない）。
/// ★D85 で「順番があるように見せない」ために帯を出さないと決めたのと同じ向き。
///
/// ★★ できることが無いときも空のメニューにしない ★★
/// `board_card_menu.dart` と同じ方針。**なぜ何も無いのか**を条番号つきで出す。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;

import 'board_look_at_top.dart';
import 'board_view.dart';

/// メインデッキ置き場（4.8）のメニュー。
Future<void> showMainDeckMenu(
  BuildContext context, {
  required String playerId,
}) {
  final store = BoardView.of(context).store;

  return _present(context, [
    _DeckMenuEntry(
      label: '1 枚引く 5.6.1',
      run: (context) async =>
          store.dispatch(DrawCards(playerId: playerId, count: 1)),
    ),
    _DeckMenuEntry(
      label: '枚数を指定して引く… 5.6.2',
      run: (context) async {
        final count = await promptCardCount(
          context,
          title: '何枚引きますか',
          // 5.6.2「カードを 1 枚引く行動を（数値）回繰り返します」
          description: '5.6.2 は「1 枚引く」を指定回数くり返します。'
              '途中でメインデッキ置き場が尽きたら、その場でリフレッシュして続けます（10.2.1）。',
        );
        if (count == null || !context.mounted) return;
        store.dispatch(DrawCards(playerId: playerId, count: count));
      },
    ),
    _DeckMenuEntry(
      label: 'シャッフルする 5.5.1',
      run: (context) async =>
          store.dispatch(ShuffleZone(playerId: playerId, zone: Zone.mainDeck)),
    ),
    _DeckMenuEntry(
      label: '上から見る… 5.7.1 / 10.2.2.2',
      run: (context) => lookAtTopOfMainDeck(context, playerId: playerId),
    ),
    // ★4.9 と並んでいるので、こちら側にも違いを書いておく。
    const _DeckMenuEntry(
      label: '★これらはメインデッキ置き場（4.8）の規定です。'
          'エネルギーデッキ置き場（4.9）には同じ操作がありません',
    ),
  ]);
}

/// エネルギーデッキ置き場（4.9）のメニュー。★操作は 1 つも無い。
Future<void> showEnergyDeckMenu(BuildContext context) => _present(context, const [
      _DeckMenuEntry(
        label: 'エネルギーを出すときは、袖の「エネルギーを1枚出す」を押します'
            '（4.9.2 / 4.9.3 により無作為に 1 枚）',
      ),
      _DeckMenuEntry(
        // ★★ 理由 1: 条文が定めていない（禁止ではない）★★
        label: '★「上から見る」はありません。5.7.1 / 5.7.2 / 10.2.2.2 はいずれも'
            'メインデッキ置き場（4.8）についての規定で、'
            'エネルギーデッキ置き場（4.9）を対象にした条がありません。'
            '禁止されているのではなく、条文が定めていない操作を足していません',
      ),
      _DeckMenuEntry(
        // ★★ 理由 2: 実装の判断（条文はシャッフルを除外していない）★★
        label: '★「シャッフル」もありません。5.5.1 は指定されたカード群への指示なので'
            '4.9 を除外してはいません。出していないのは実装の判断で、'
            '4.9.2 が「カードの順番は管理されません」と定める以上、'
            'シャッフルしても観測できる差が出ないためです',
      ),
    ]);

/// 枚数を尋ねる。★不正な値（0 / 負数 / 非数値）を弾いて理由を出す。
///
/// ★キャンセルなら null。
Future<int?> promptCardCount(
  BuildContext context, {
  required String title,
  required String description,
  int initial = 1,
}) {
  final view = BoardView.of(context);
  return showDialog<int>(
    context: context,
    // ★ダイアログは別のサブツリーなので視点を配り直す。
    builder: (context) => view.provideTo(
      _CountPrompt(
        title: title,
        description: description,
        initial: initial,
      ),
    ),
  );
}

class _CountPrompt extends StatefulWidget {
  const _CountPrompt({
    required this.title,
    required this.description,
    required this.initial,
  });

  final String title;
  final String description;
  final int initial;

  @override
  State<_CountPrompt> createState() => _CountPromptState();
}

class _CountPromptState extends State<_CountPrompt> {
  late final _controller =
      TextEditingController(text: '${widget.initial}');

  /// null なら不正。
  int? get _value {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null || parsed < 1) return null;
    return parsed;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = _value;

    return AlertDialog(
      key: const ValueKey('card-count-prompt'),
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.description, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('card-count-field'),
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: '枚数',
                // ★★ 黙って弾かない ★★
                errorText: value == null ? '1 以上の数を入れてください' : null,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('card-count-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('やめる'),
        ),
        FilledButton(
          key: const ValueKey('card-count-ok'),
          // ★不正なら押せない。★消さずに無効にして理由を出す。
          onPressed: value == null ? null : () => Navigator.of(context).pop(value),
          child: const Text('決定'),
        ),
      ],
    );
  }
}

class _DeckMenuEntry {
  const _DeckMenuEntry({required this.label, this.run});

  final String label;

  /// null なら**説明だけ**の行（押せない）。
  final Future<void> Function(BuildContext context)? run;
}

Future<void> _present(BuildContext context, List<_DeckMenuEntry> entries) async {
  final box = context.findRenderObject();
  final overlay = Overlay.of(context).context.findRenderObject();
  if (box is! RenderBox || overlay is! RenderBox) return;

  final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
  final chosen = await showMenu<int>(
    context: context,
    position: RelativeRect.fromLTRB(
      topLeft.dx,
      topLeft.dy + box.size.height,
      overlay.size.width - topLeft.dx - box.size.width,
      0,
    ),
    constraints: const BoxConstraints(minWidth: 240, maxWidth: 420),
    items: [
      for (var i = 0; i < entries.length; i++)
        PopupMenuItem<int>(
          key: ValueKey('deck-menu-$i'),
          value: i,
          // ★説明だけの行は押せない。**が、消さない**（理由が読めなくなる）。
          enabled: entries[i].run != null,
          child: Text(entries[i].label,
              style: Theme.of(context).textTheme.bodySmall),
        ),
    ],
  );

  if (chosen == null || !context.mounted) return;
  await entries[chosen].run?.call(context);
}
