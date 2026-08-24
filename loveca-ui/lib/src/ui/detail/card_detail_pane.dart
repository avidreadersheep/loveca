/// R5 カード詳細の**中身**（`docs/UI設計メモ.md` §2-1 / §2-2 / 決定 D66）.
///
/// ★★ 器が 2 通りある。中身はこの 1 つだけ ★★
///
/// | 器 | どこに出るか | 閉じ方 |
/// |---|---|---|
/// | **2 ペイン（PC）** | `PaneScaffold` の secondary を差し替える（決定 D66） | [onClose] |
/// | **1 ペイン（モバイル相当）** | R5 ルート（`card_detail_page.dart`） | AppBar の戻る |
///
/// **どちらに出すかを決めるのは `open_card_detail.dart` の 1 箇所だけ**（§2-1）。
/// このウィジェットは器を知らない。[onClose] が null かどうかしか見ない。
///
/// ★★ `Image` を作るのは `CardThumb`、`ImageProvider` を組むのは
/// `CardImageSource`（§5-2(2)）★★
/// M5 で `normal`（500px / 決定 D57）を初めて使うが、**役割分担は変えない。**
/// `cacheWidth = min(表示物理px, 原寸)` は `CardImageSource` が担う（§7）。
///
/// ★★ FAQ は出さない（Release 1 から外した / §2-7(1)）★★
/// `Faq.cardNumbers` の中身は **cardNumber ではなく printingId** という罠があり、
/// 名前を信じて結合すると**例外も出ずに 0 件**になる。M5 では触らない。
library;

import 'package:flutter/material.dart' hide Card;
// ★Material の Card ではなく loveca_core の Card（ルール上のカード）を使う。
//   衝突するのは Material 側なので、そちらを隠す。
import 'package:loveca_core/loveca_core.dart';

import '../../data/card_detail.dart';
import '../../data/card_image_source.dart';
import '../../state/app_scope.dart';
import '../common/card_thumb.dart';
import '../common/heart_chips.dart';

/// 詳細の絵の最大の論理幅。
///
/// ★1 ペインだと画面いっぱい（800 論理px 以上）になり、札が巨大になる。
/// ★この値のおかげで **DPR が 1.4 を超えると `normal` の原寸 500px で頭打ちになる**
/// （360 × 1.4 = 504）。§7 の規則が実際に効く幅である。
const double kCardDetailImageMaxWidth = 360;

class CardDetailPane extends StatefulWidget {
  const CardDetailPane({
    super.key,
    required this.printingId,
    this.onClose,
  });

  final String printingId;

  /// ★2 ペインのときだけ渡る。ルートでは AppBar の戻るが担うので null。
  final VoidCallback? onClose;

  @override
  State<CardDetailPane> createState() => _CardDetailPaneState();
}

class _CardDetailPaneState extends State<CardDetailPane> {
  /// いま見ている刷り。★同じ cardNumber の別の刷りへ切り替えられる（決定 D11）。
  late String _printingId = widget.printingId;

  @override
  void didUpdateWidget(CardDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ★器が別のカードを差してきたら従う（2 ペインで一覧の別セルを叩いたとき）。
    if (oldWidget.printingId != widget.printingId) {
      _printingId = widget.printingId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final detail = scope.environment.cardDetail.of(_printingId);

    if (detail == null) {
      // ★★ 黙って空白にしない ★★
      //   いまこの経路は一覧セルからは到達しないが、Phase 4 の同期や
      //   M6 の共有形式で未知の printingId が入りうる（`card_detail.dart` の doc）。
      return _NotFound(printingId: _printingId, onClose: widget.onClose);
    }

    final theme = Theme.of(context);
    final card = detail.card;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _Header(detail: detail, onClose: widget.onClose),
        const SizedBox(height: 12),
        _DetailImage(
          imageHash: detail.printing.imageHash,
          source: scope.environment.imageSource,
        ),
        const SizedBox(height: 16),

        // 総合ルール 2.3.2.1: カード名の ＆ で区切られたそれぞれの名称。
        // ★1 枚に複数のキャラクターが載る（実データで 6 種）。
        if (card.characterNames.isNotEmpty)
          _Section(title: 'キャラクター', child: _Names(card.characterNames)),

        // 総合ルール 2.4.2.1: 1 枚が複数グループに属しうる。
        if (card.groupNames.isNotEmpty)
          _Section(title: 'グループ', child: _Names(card.groupNames)),
        if (card.unitNames.isNotEmpty)
          _Section(title: 'ユニット', child: _Names(card.unitNames)),

        // ★種別ごとに埋まる欄が違う。無い欄は出さない
        //   （エネルギーは 567 種すべてが空 / 実データ）。
        if (_hasNumbers(card))
          _Section(title: 'ステータス', child: _Numbers(card: card)),

        // 総合ルール 2.9: メンバーの所持ハート。
        if (card.hearts.isNotEmpty)
          _Section(
            title: 'ハート',
            trailing: '合計 ${card.heartTotal}',
            child: HeartChips(hearts: card.hearts),
          ),

        // 総合ルール 2.11: ライブの必要ハート。★「無」(GRAY) が入る。
        if (card.requiredHearts.isNotEmpty)
          _Section(
            title: '必要ハート',
            trailing: '合計 ${card.requiredHeartTotal}',
            child: HeartChips(hearts: card.requiredHearts),
          ),

        // 総合ルール 2.7: ブレードハートの色。★8.3.14 でハート合計に合算される側。
        if (card.bladeHearts.isNotEmpty)
          _Section(
            title: 'ブレードハート',
            child: HeartChips(hearts: card.bladeHearts),
          ),

        // ★★ 色とは別の見出しにする（CLAUDE.md §6）★★
        //   同じ並びに混ぜると、画面の上で 8.3.14 の合算対象を取り違える。
        if (card.bladeHeartEffects.isNotEmpty)
          _Section(
            title: 'ブレードハートのアイコン',
            note: 'エールで出たときに働きます。ハートの合計には数えません。',
            child: BladeHeartEffectChips(effects: card.bladeHeartEffects),
          ),

        if (card.effectText.isNotEmpty)
          _Section(
            title: '効果',
            child: SelectableText(
              card.effectText,
              style: theme.textTheme.bodyMedium,
            ),
          ),

        // ★`keywords`（`ENTER` / `LIVE_SUCCESS` …）は出さない。
        //   正規化の産物であって利用者の言葉ではなく、同じことが効果テキストに
        //   日本語で書いてある（【登場】【ライブ成功時】）。内部語彙を画面に出さない。

        _Section(title: 'この刷り', child: _PrintingFacts(printing: detail.printing)),

        if (detail.hasOtherPrintings)
          _Section(
            title: 'ほかの刷り',
            // ★「代表 1 枚」は誤りとして廃止済み（CLAUDE.md §5-(4)）。
            //   通常刷りが複数ありうるので、パラレルかどうかは各行に出す。
            note: '同じカードナンバーの別の絵柄です。デッキの 4 枚制限では合算されます。',
            child: _SiblingPrintings(
              detail: detail,
              source: scope.environment.imageSource,
              current: _printingId,
              onSelect: (id) => setState(() => _printingId = id),
            ),
          ),
      ],
    );
  }

  static bool _hasNumbers(Card card) =>
      card.cost != null || card.bladeCount != null || card.score != null;
}

/// 見出し。★2 ペインのときだけ閉じるボタンが出る。
class _Header extends StatelessWidget {
  const _Header({required this.detail, required this.onClose});

  final CardDetail detail;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(detail.card.name, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                // ★4 枚制限の単位は cardNumber（6.1.1.2 / 決定 D11）。
                '${detail.card.cardNumber} ・ ${_typeLabel(detail.card.cardType)}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.hintColor),
              ),
            ],
          ),
        ),
        if (onClose != null)
          IconButton(
            tooltip: '詳細を閉じる',
            icon: const Icon(Icons.close),
            onPressed: onClose,
          ),
      ],
    );
  }
}

String _typeLabel(CardType type) => switch (type) {
      CardType.member => 'メンバー',
      CardType.live => 'ライブ',
      CardType.energy => 'エネルギー',
    };

/// 大きい絵。★`normal`（500px / 決定 D57）を使う唯一の場所。
class _DetailImage extends StatelessWidget {
  const _DetailImage({required this.imageHash, required this.source});

  final String imageHash;
  final CardImageSource source;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth < kCardDetailImageMaxWidth
              ? constraints.maxWidth
              : kCardDetailImageMaxWidth;
          return Center(
            child: SizedBox(
              width: width,
              child: AspectRatio(
                // ★比は `card_thumb.dart` に 1 つだけ置いてある。
                aspectRatio: kCardAspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CardThumb(
                    key: const Key('cardDetailImage'),
                    source: source,
                    imageHash: imageHash,
                    logicalWidth: width,
                    size: CardImageSize.normal,
                    // ★札の端まで見せる。切り落とすと同定の役に立たない。
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          );
        },
      );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.trailing,
    this.note,
  });

  final String title;
  final Widget child;
  final String? trailing;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
              if (trailing != null)
                Text(trailing!, style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 6),
          child,
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(
              note!,
              style:
                  theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
            ),
          ],
        ],
      ),
    );
  }
}

class _Names extends StatelessWidget {
  const _Names(this.names);

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final name in names)
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Text(name, style: theme.textTheme.labelMedium),
            ),
          ),
      ],
    );
  }
}

/// コスト / ブレード / スコア。★null の欄は出さない。
class _Numbers extends StatelessWidget {
  const _Numbers({required this.card});

  final Card card;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          // 総合ルール 2.6: メンバーのみ。
          if (card.cost case final cost?) _Fact(label: 'コスト', value: '$cost'),
          // 総合ルール 2.8: メンバーのみ。★8.3.10 の集計はアクティブなメンバーだけ。
          if (card.bladeCount case final blades?)
            _Fact(label: 'ブレード', value: '$blades'),
          // 総合ルール 2.10: ライブのみ。
          if (card.score case final score?) _Fact(label: 'スコア', value: '$score'),
        ],
      );
}

class _PrintingFacts extends StatelessWidget {
  const _PrintingFacts({required this.printing});

  final Printing printing;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Fact(label: '刷り', value: printing.printingId),
          _Fact(label: '商品', value: printing.expansion),
          _Fact(
            label: 'レアリティ',
            // ★パラレルは刷りの属性（CLAUDE.md §5-(4)）。
            value: printing.isParallel
                ? '${printing.rarity}（パラレル）'
                : printing.rarity,
          ),
          // ★実データで illustrator が入るのは 2,527 中 185 だけ。空なら出さない。
          if (printing.illustrator.isNotEmpty)
            _Fact(label: 'イラスト', value: printing.illustrator),
        ],
      );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 68,
            child: Text(
              label,
              style:
                  theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
            ),
          ),
          Flexible(child: Text(value, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// 同じ cardNumber のほかの刷り。★タップで切り替える。
class _SiblingPrintings extends StatelessWidget {
  const _SiblingPrintings({
    required this.detail,
    required this.source,
    required this.current,
    required this.onSelect,
  });

  final CardDetail detail;
  final CardImageSource source;
  final String current;
  final ValueChanged<String> onSelect;

  static const double _width = 52;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final printing in detail.siblings)
          InkWell(
            key: ValueKey('siblingPrinting:${printing.printingId}'),
            onTap: printing.printingId == current
                ? null
                : () => onSelect(printing.printingId),
            child: SizedBox(
              width: _width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: printing.printingId == current
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: SizedBox(
                      width: _width,
                      height: _width / kCardAspectRatio,
                      // ★一覧と同じ段（thumb）。詳細の大きい絵だけが normal。
                      child: CardThumb(
                        source: source,
                        imageHash: printing.imageHash,
                        logicalWidth: _width,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    printing.isParallel
                        ? '${printing.rarity}☆'
                        : printing.rarity,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// ★★ 見つからなかったことを黙って空白にしない（決定 D35 と同じ考え方）★★
class _NotFound extends StatelessWidget {
  const _NotFound({required this.printingId, required this.onClose});

  final String printingId;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(Icons.report_problem_outlined,
                size: 18, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'このカードのデータがありません',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ),
            if (onClose != null)
              IconButton(
                tooltip: '詳細を閉じる',
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
          ],
        ),
        const SizedBox(height: 8),
        // ★どの刷りが引けなかったのかを出す。出さないと利用者も開発者も追えない。
        SelectableText(printingId, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        Text(
          'カードデータが古い可能性があります。データを更新してください。',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
