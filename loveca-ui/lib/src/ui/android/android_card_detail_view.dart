/// カード詳細（★Android / `docs/Android UI 決定.md` §3-14）.
///
/// ★★ Windows の `card_detail_pane.dart` とは★別の形である ★★
/// ★**あちらは★★2 ペインの右側★★**（★一覧と同時に見える）。
/// ★**こちらは★★1 画面である★★**（★電話は 411 論理px で、★しきい値 840 を大きく下回る / §3-1）。
/// → ★**Windows の側は★★1 行も変えていない★★。**
///
/// ★★ この層が★決めないもの（★言い切る）★★
///
/// | # | ★何 | ★誰が決めるか |
/// |---|---|---|
/// | ★**1** | ★**隣のカードが何か** | ★★**呼ぶ側**★★（★この層は「★次へ / 前へ」を渡すだけ） |
/// | ★**2** | ★**絵を拡大したときの見た目** | ★★**呼ぶ側**★★（★★1 行も無い★★） |
/// | ★**3** | ★**長押しで何をコピーするか** | ★★**呼ぶ側**★★ —— ★§3-14 は「★カード情報」としか書いていない |
/// | ★**4** | ★**枚数の帯** | ★**差し込み口**（★§3-8 の `DeckCountBand` を★呼ぶ側が渡す）。★★渡さなければ出さない★★ |
///
/// ★★ 「3 / 25」は★呼ぶ側から受け取る ★★
/// ★**この層は★★一覧を 1 つも持たない★★**（★★並べ替えも絞り込みもしない★★）。
///
/// ★★ エネルギーは数値の欄ごと消える ★★
/// ★**§3-14 が明示している**（★実装メモ §9-9 #9 の実測と同じ）。
/// ★**「値が無いので空欄」ではない** —— ★★行そのものを出さない★★。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_core/loveca_core.dart' as core show Card;

import '../common/heart_chips.dart';

/// 属性の 1 行（★★絵の右横★★ / §3-14 の絵）。
typedef CardAttributeRow = ({String label, Widget value});

/// 属性の表を組む（★★純粋関数 —— ★合成の入力で当てられる★★）。
///
/// ★★ 種別で行が変わる ★★
/// ★**コスト / ブレード / ハートは★★メンバーだけ★★**（総合ルール 2.6 / 2.8 / 2.9）。
/// ★**スコア / 必要ハートは★★ライブだけ★★**（総合ルール 2.10 / 2.11）。
/// ★**エネルギーは★★レアリティと種別しか残らない★★**（★§3-14）。
List<String> cardAttributeLabels(core.Card card) => <String>[
      'レアリティ',
      '種別',
      if (card.cardType == CardType.member) ...<String>[
        'コスト',
        'ブレード',
        'ハート',
      ],
      if (card.cardType == CardType.live) ...<String>[
        'スコア',
        '必要ハート',
      ],
    ];

/// 種別の字面（総合ルール 2.2.2）。
String cardTypeLabel(CardType type) => switch (type) {
      CardType.member => 'メンバー',
      CardType.live => 'ライブ',
      CardType.energy => 'エネルギー',
    };

/// 「3 / 25」の字面。
///
/// ★★ 1 始まりである（★人が読む数である）★★
String cardPositionLabel(int index, int total) => '${index + 1} / $total';

class AndroidCardDetailView extends StatefulWidget {
  const AndroidCardDetailView({
    super.key,
    required this.card,
    required this.printing,
    required this.index,
    required this.total,
    this.otherPrintings = const <Printing>[],
    this.copies,
    this.maxCopies,
    this.countBand,
    this.onPrevious,
    this.onNext,
    this.onExpandImage,
    this.onCopyInfo,
    this.onSelectPrinting,
  });

  final core.Card card;
  final Printing printing;

  /// 「3 / 25」の 3（★★0 始まり★★）。
  final int index;
  final int total;

  /// ほかの刷り（★§3-14 —— ★Windows にある機能）。★★自分を含めない★★のは呼ぶ側の仕事。
  final List<Printing> otherPrintings;

  /// いま何枚入っているか（★★デッキ編集から入ったときだけ★★）。
  final int? copies;

  /// 4 枚制限（★★総合ルール 6.1.1.2★★）。★[copies] と対で渡す。
  final int? maxCopies;

  /// 枚数の帯（★§3-8）。★★渡さなければ出さない★★。
  final Widget? countBand;

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onExpandImage;
  final VoidCallback? onCopyInfo;
  final ValueChanged<Printing>? onSelectPrinting;

  @override
  State<AndroidCardDetailView> createState() => _AndroidCardDetailViewState();
}

class _AndroidCardDetailViewState extends State<AndroidCardDetailView> {
  /// ★★ テキストは折り畳める（§3-14 の ▼）★★
  ///
  /// ★**既定は★★開いている★★** —— ★§3-14 は述べていない。★★決めた既定値である★★。
  /// ★**閉じて始めると「テキストが無いカード」と区別がつかない。**
  bool _textExpanded = true;

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    return GestureDetector(
      // ★★ 左右スワイプで隣のカードへ（§3-14）★★
      //   ★**左へ払うと★次へ / ★右へ払うと★前へ**（★★本を送るのと同じ向き★★）。
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < 0) widget.onNext?.call();
        if (v > 0) widget.onPrevious?.call();
      },
      child: ListView(
        children: [
          _Header(index: widget.index, total: widget.total),
          _NameRow(
              name: card.name, copies: widget.copies, maxCopies: widget.maxCopies),
          _ArtAndAttributes(
            card: card,
            printing: widget.printing,
            onExpandImage: widget.onExpandImage,
          ),
          _FeatureRow(card: card),
          _TextSection(
            text: card.effectText,
            expanded: _textExpanded,
            onToggle: () => setState(() => _textExpanded = !_textExpanded),
          ),
          if (widget.otherPrintings.isNotEmpty)
            _OtherPrintings(
              printings: widget.otherPrintings,
              onSelect: widget.onSelectPrinting,
            ),
          // ★★ 長押しはここに書かない —— ★呼ぶ側が何をコピーするか決める ★★
          InkWell(
            key: const ValueKey('cardDetailCopyHint'),
            onLongPress: widget.onCopyInfo,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Text('（カード情報は長押しでコピーできます）'),
            ),
          ),
          // ★★ 渡されたときだけ出す（★§3-8 の帯 / ★デッキ編集から入ったときだけ）★★
          if (widget.countBand != null) widget.countBand!,
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('カード詳細'),
            Text(cardPositionLabel(index, total),
                key: const ValueKey('cardDetailPosition')),
          ],
        ),
      );
}

class _NameRow extends StatelessWidget {
  const _NameRow({required this.name, this.copies, this.maxCopies});

  final String name;
  final int? copies;
  final int? maxCopies;

  @override
  Widget build(BuildContext context) {
    final n = copies;
    final max = maxCopies;
    // ★★ 総合ルール 6.1.1.2: 同じカードナンバーはメインデッキに 4 枚まで ★★
    //   ★**達していたら赤字で出す**（★§3-14 の「4 / 4」）。
    final atLimit = n != null && max != null && n >= max;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 18))),
          if (n != null)
            Text('x$n',
                key: const ValueKey('cardDetailCopies'),
                style: TextStyle(
                    color: atLimit ? const Color(0xFFD32F2F) : null)),
        ],
      ),
    );
  }
}

class _ArtAndAttributes extends StatelessWidget {
  const _ArtAndAttributes({
    required this.card,
    required this.printing,
    this.onExpandImage,
  });

  final core.Card card;
  final Printing printing;
  final VoidCallback? onExpandImage;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ★★ 絵は拡大できる（§3-14 の ⤢）—— ★出す中身は呼ぶ側が決める ★★
          IconButton(
            key: const ValueKey('cardDetailExpandImage'),
            icon: const Icon(Icons.zoom_out_map),
            onPressed: onExpandImage,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final label in cardAttributeLabels(card))
                  Row(
                    key: ValueKey('cardDetailAttr:$label'),
                    children: [
                      SizedBox(width: 88, child: Text(label)),
                      Expanded(child: _attributeValue(label)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      );

  Widget _attributeValue(String label) => switch (label) {
        'レアリティ' => Text(printing.rarity),
        '種別' => Text(cardTypeLabel(card.cardType)),
        'コスト' => Text('${card.cost ?? 0}'),
        'ブレード' => Text('${card.bladeCount ?? 0}'),
        'ハート' => HeartChips(hearts: card.hearts),
        'スコア' => Text('${card.score ?? 0}'),
        '必要ハート' => HeartChips(hearts: card.requiredHearts),
        _ => const SizedBox.shrink(),
      };
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.card});

  final core.Card card;

  @override
  Widget build(BuildContext context) {
    // ★★ 「特徴」の位置に置くのは★グループ名とユニット ★★
    //   ★**総合ルール 2.12.2 が『』で参照すると定めている 2 つである**（★§3-14）。
    //   ★**キャラクター名は入れない**（★2.3.2.2 の「」は★別の参照である）。
    final parts = <String>[...card.groupNames, ...card.unitNames];
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(parts.join(' / '), key: const ValueKey('cardDetailFeature')),
    );
  }
}

class _TextSection extends StatelessWidget {
  const _TextSection({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const ValueKey('cardDetailTextToggle'),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Text('テキスト'),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(text, key: const ValueKey('cardDetailText')),
            ),
        ],
      );
}

class _OtherPrintings extends StatelessWidget {
  const _OtherPrintings({required this.printings, this.onSelect});

  final List<Printing> printings;
  final ValueChanged<Printing>? onSelect;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            const Text('ほかの刷り'),
            for (final p in printings)
              TextButton(
                key: ValueKey('cardDetailOtherPrinting:${p.printingId}'),
                onPressed: onSelect == null ? null : () => onSelect!(p),
                child: Text(p.rarity),
              ),
          ],
        ),
      );
}
