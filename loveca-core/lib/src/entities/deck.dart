/// デッキエンティティ.
///
/// 設計書 STEP 7 §7.4 / §0.1 に対応。
///
/// ★ Phase 2 の時点で必ず入れておく先行対応 (案B: PC先行) ★
///   決定 D100 deckId は UUID                      … 端末間で衝突しないため
///   決定 D101 revision / updatedAt / deletedAt    … 同期の差分検出
///   決定 D102 物理削除をしない (論理削除)          … 削除の伝播
///   決定 D11  printingId 単位で保持                … 保持は刷り・検証は cardNumber
///   決定 D35  masterDataVersion を記録             … 未知カード検出
///
/// ★★ 旧番号 P1〜P5 はこの 5 つに置き換えた (2026-08-27) ★★
///   参照先の無い体系だったため。P4 / P5 は最初から D11 / D35 として
///   採番済みで、新規採番は P1〜P3 の 3 つだけ
///   (`ルール整合性チェック_v1.06.md` D-5 の訂正 / D-29)。
///
/// 同期エンジン本体は Phase 4 でよいが、これらの構造だけは後付けが極めて高コスト。

library;

import 'card.dart';

/// デッキ内の 1 エントリ。★保持は printingId 単位 (決定 D11)。
class DeckEntry {
  const DeckEntry({required this.printingId, required this.count});

  final String printingId;
  final int count;

  DeckEntry copyWith({int? count}) =>
      DeckEntry(printingId: printingId, count: count ?? this.count);

  Map<String, dynamic> toJson() => {'printingId': printingId, 'count': count};

  factory DeckEntry.fromJson(Map<String, dynamic> json) => DeckEntry(
        printingId: json['printingId'] as String,
        count: json['count'] as int,
      );
}

class Deck {
  const Deck({
    required this.deckId,
    required this.name,
    this.entries = const [],
    this.memo = '',
    this.tags = const [],
    this.coverPrintingId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.revision = 0,
    this.lastDeviceId = '',
    this.masterDataVersion = 0,
  });

  /// ★UUID v4。連番にすると端末間で衝突する (決定 D100)。
  final String deckId;
  final String name;
  final List<DeckEntry> entries;
  final String memo;
  final List<String> tags;
  final String? coverPrintingId;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// ★論理削除 (決定 D102)。物理削除すると削除が同期で伝播しない。
  final DateTime? deletedAt;

  /// ★更新のたびに +1 (決定 D101)。同期の差分検出に使う。
  ///
  /// ★+1 するのは呼び出し側である (決定 D116-1)。[copyWith] は据え置く。
  final int revision;
  final String lastDeviceId;

  /// ★作成時のカードマスタ版 (決定 D35)。未知カード検出に使う。
  final int masterDataVersion;

  bool get isDeleted => deletedAt != null;

  int get totalCount => entries.fold(0, (sum, e) => sum + e.count);

  /// 指定した分だけを差し替える。
  ///
  /// ★★ 既定値は「据え置き」である。指定しなかった値を勝手に動かさない ★★
  ///   決定 D116-1 3 つ組 (決定 D101) を決めるのは呼び出し側である
  ///   決定 D116-2 2 つの既定値を「据え置き」に変えた (A-3 / D-14 の根治)
  ///
  /// ★以前は [updatedAt] の既定値が現在時刻、[revision] の既定値が +1 だった。
  ///   前者は CLAUDE.md §1 が禁じる非決定な呼び出しそのもので、
  ///   後者は「決めるのは呼び出し側」(決定 D116-1) と食い違っていた。
  ///   `copyWith` の意味は「指定した分だけ変える」であり、
  ///   指定しなかった分を動かすほうが語と食い違っていた。
  ///
  /// ★★ 3 つ組を動かすのは呼び出し側の責務である ★★
  ///   更新のたびに +1 する (決定 D101) のは `DeckRepository.save` の側で、
  ///   ここでは行わない。時刻も呼び出し側から渡す。
  ///
  /// ★[deckId] / [createdAt] / [masterDataVersion] は引数を持たない (不変)。
  Deck copyWith({
    String? name,
    List<DeckEntry>? entries,
    String? memo,
    List<String>? tags,
    String? coverPrintingId,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? revision,
    String? lastDeviceId,
  }) =>
      Deck(
        deckId: deckId,
        name: name ?? this.name,
        entries: entries ?? this.entries,
        memo: memo ?? this.memo,
        tags: tags ?? this.tags,
        coverPrintingId: coverPrintingId ?? this.coverPrintingId,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
        revision: revision ?? this.revision,
        lastDeviceId: lastDeviceId ?? this.lastDeviceId,
        masterDataVersion: masterDataVersion,
      );

  Map<String, dynamic> toJson() => {
        'deckId': deckId,
        'name': name,
        'entries': entries.map((e) => e.toJson()).toList(),
        'memo': memo,
        'tags': tags,
        'coverPrintingId': coverPrintingId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
        'revision': revision,
        'lastDeviceId': lastDeviceId,
        'masterDataVersion': masterDataVersion,
      };

  /// JSON から `Deck` を組む（★★寛容な口である★★）。
  ///
  /// ## ★★ どの用途で★どちらが正しいか（★★ここが 1 か所である★★ / 2026-09-02）★★
  ///
  /// ★**同じ「JSON から `Deck` を組む」に★★2 つの判断が在る★★。★用途が違うだけで矛盾していない。**
  /// ★**片方だけ読むと★★取り違える★★**ので、★★両方をここに書く★★（★運転指示【0】(4)）。
  ///
  /// | 用途 | ★どちらを使うか | ★なぜ |
  /// |---|---|---|
  /// | ★★**同期の受信**★★（★§32-6 の **23** / **24**） | ★★**この口を使わない**★★。
  ///   ★`decodeDeckForSync`（`src/sync/deck_wire.dart` / 決定 **D142** ＝ 組-1） | ★★**欠けた鍵を★既定値で埋めるから**★★ ——
  ///   ★★壊れた字面が「空のデッキ」として成立し、★解決で勝って★手元のデッキが消えうる★★ |
  /// | ★★**手元のファイルを読む**★★ | ★★**この口が正しい**★★ | ★★**寛容であることが★そこでは正しい**★★
  ///   （**§7-7** —— ★同じ形でも★★見ている相手が違う★★） |
  ///
  /// ★★ 何を埋めるか（★★これが「寛容」の中身である★★）★★
  /// ★`memo` が無ければ空文字 ／ ★`entries` が無ければ空の列 ／ ★`tags` が無ければ空の列 ／
  /// ★`revision` / `masterDataVersion` が無ければ 0 ／ ★`lastDeviceId` が無ければ空文字。
  ///
  /// ## ★★ 2026-09-02: ★★今日この口を呼ぶ側は★1 人も居ない★★（★走査した）★★
  ///
  /// ★**`lib` にも `test` にも★★呼び出しが 0 件である★★**（★★例外は `deck_wire_test.dart` の★対 2 件★★
  ///   —— ★あれは「★この口なら通ってしまう」ことを★示すために呼んでいる）。
  /// → ★★**「手元のファイルを読む口である」は★★想定された用途についての判断であって、
  ///   ★実在する呼び出し側についてではない★★**★★（**§7-11** —— ★★走査した層についてだけ書く★★）。
  /// ★**型は **D-20** である**（★宣言は在るのに `lib` の消費者が 1 人も居ない）。
  /// ★★**消していない**★★ —— ★**[toJson] は同期が使っており、★対で在るほうが読みやすい。**
  ///   ★**消すかどうかは★★この commit の論点ではない★★。**
  factory Deck.fromJson(Map<String, dynamic> json) => Deck(
        deckId: json['deckId'] as String,
        name: json['name'] as String,
        entries: (json['entries'] as List? ?? [])
            .map((e) => DeckEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        memo: json['memo'] as String? ?? '',
        tags: (json['tags'] as List?)?.cast<String>() ?? const [],
        coverPrintingId: json['coverPrintingId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        deletedAt: json['deletedAt'] == null
            ? null
            : DateTime.parse(json['deletedAt'] as String),
        revision: json['revision'] as int? ?? 0,
        lastDeviceId: json['lastDeviceId'] as String? ?? '',
        masterDataVersion: json['masterDataVersion'] as int? ?? 0,
      );

  /// 外部共有用の単純形式 (cardNumber + 枚数)。
  ///
  /// 内部表現は printingId 単位だが、そのままでは他ツールと互換しない。
  /// 共有・デッキログ連携時は必ずこの形式に落とす (設計書 STEP 4 M44)。
  Map<String, int> toShareFormat(Map<String, Printing> printings) {
    final out = <String, int>{};
    for (final entry in entries) {
      final printing = printings[entry.printingId];
      if (printing == null) continue;
      out[printing.cardNumber] = (out[printing.cardNumber] ?? 0) + entry.count;
    }
    return out;
  }
}

/// デッキ構築ルール。総合ルール 6.1。
///
/// ★定数にしないこと★
/// 総合ルール 6.1.2 に「デッキの構築条件に関する常時能力は、
/// 上記のデッキ構築条件を置換する置換効果として適用される」とあり、
/// 構築条件を変えるカードが存在しうる。
class RuleConfig {
  const RuleConfig({
    this.mainDeckSize = 60,
    this.memberCount = 48,
    this.liveCount = 12,
    this.energyDeckSize = 12,
    this.maxCopiesPerCardNumber = 4,
    this.initialHandSize = 6,
    this.initialEnergyOnField = 3,
    this.liveSlotMax = 3,
    this.winCondition = 3,
    this.stageAreaCount = 3,
  });

  final int mainDeckSize;
  final int memberCount;
  final int liveCount;
  final int energyDeckSize;
  final int maxCopiesPerCardNumber;
  final int initialHandSize;
  final int initialEnergyOnField;
  final int liveSlotMax;
  final int winCondition;
  final int stageAreaCount;

  static const standard = RuleConfig();
}
