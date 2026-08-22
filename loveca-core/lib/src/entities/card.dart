/// ラブカのカードエンティティ.
///
/// 設計書 STEP 7 §7.2 に対応。
///
/// ★ 2 階層の識別子 ★
///   cardNumber  … 総合ルール 6.1.1.2 の「カードナンバー」。4 枚制限の判定単位
///   printingId  … 個別の刷り。画像・レアリティ・収録商品の単位
///
/// デッキは printingId 単位で保持し、検証は cardNumber 単位で行う (決定 D11)。
/// この非対称性が本モデルの核心。

library;

/// ハートの色。
///
/// 総合ルール 2.1.1。
/// - [gray] は色を指定しないハート (2.1.1.2)。ライブの必要ハート側で使う
/// - [all]  は任意の 1 色として扱えるハート (2.1.1.3)。所有ハート側で使う
enum HeartColor {
  pink,
  red,
  yellow,
  green,
  blue,
  purple,
  gray,
  all;

  static HeartColor fromKey(String key) => switch (key) {
        'PINK' => HeartColor.pink,
        'RED' => HeartColor.red,
        'YELLOW' => HeartColor.yellow,
        'GREEN' => HeartColor.green,
        'BLUE' => HeartColor.blue,
        'PURPLE' => HeartColor.purple,
        'GRAY' => HeartColor.gray,
        'ALL' => HeartColor.all,
        _ => throw ArgumentError('unknown heart color: $key'),
      };

  /// 総合ルール 2.1.1.1 の 6 色。gray / all を含まない。
  static const sixColors = [pink, red, yellow, green, blue, purple];
}

/// カード種別。総合ルール 2.2.2。
enum CardType {
  member,
  live,
  energy;

  static CardType fromJa(String value) => switch (value) {
        'メンバー' => CardType.member,
        'ライブ' => CardType.live,
        'エネルギー' => CardType.energy,
        _ => throw ArgumentError('unknown card type: $value'),
      };
}

/// ルール上のカード。cardNumber をキーとする。
class Card {
  const Card({
    required this.cardNumber,
    required this.name,
    required this.cardType,
    this.characterNames = const [],
    this.groupNames = const [],
    this.unitNames = const [],
    this.effectText = '',
    this.keywords = const [],
    this.cost,
    this.bladeCount,
    this.score,
    this.hearts = const {},
    this.requiredHearts = const {},
    this.bladeHearts = const {},
    this.heartTotal = 0,
    this.requiredHeartTotal = 0,
    this.stats,
    this.isDeleted = false,
  });

  final String cardNumber;
  final String name;
  final CardType cardType;

  /// 総合ルール 2.3.2.1: カード名の ＆ で区切られたそれぞれの名称。
  final List<String> characterNames;

  /// 総合ルール 2.4.2.1: 1 枚が複数グループに属しうる。
  final List<String> groupNames;
  final List<String> unitNames;

  final String effectText;
  final List<String> keywords;

  /// メンバーのみ (総合ルール 2.6)。
  final int? cost;

  /// メンバーのみ (総合ルール 2.8)。
  /// ★エール枚数の算出は「アクティブ状態のメンバー」のみが対象 (8.3.10)。
  final int? bladeCount;

  /// ライブのみ (総合ルール 2.10)。
  final int? score;

  /// メンバーの所持ハート (総合ルール 2.9)。
  /// ★ライブ所有ハートの集計はウェイト状態のメンバーも含む (8.3.14)。
  final Map<HeartColor, int> hearts;

  /// ライブの必要ハート (総合ルール 2.11)。
  final Map<HeartColor, int> requiredHearts;

  /// ブレードハート (総合ルール 2.7)。エール時に機能する。
  final Map<HeartColor, int> bladeHearts;

  final int heartTotal;
  final int requiredHeartTotal;

  /// 決定 D14: ブレード数 + ハート数の合計。検索用。
  final int? stats;

  /// 公式から消えても既存デッキを壊さないため保持する。
  final bool isDeleted;

  factory Card.fromJson(Map<String, dynamic> json) => Card(
        cardNumber: json['cardNumber'] as String,
        name: json['name'] as String,
        cardType: CardType.fromJa(json['cardType'] as String),
        characterNames: (json['characterNames'] as List?)?.cast<String>() ?? const [],
        groupNames: (json['groupNames'] as List?)?.cast<String>() ?? const [],
        unitNames: (json['unitNames'] as List?)?.cast<String>() ?? const [],
        effectText: json['effectText'] as String? ?? '',
        keywords: (json['keywords'] as List?)?.cast<String>() ?? const [],
        cost: json['cost'] as int?,
        bladeCount: json['bladeCount'] as int?,
        score: json['score'] as int?,
        hearts: _hearts(json['hearts']),
        requiredHearts: _hearts(json['requiredHearts']),
        bladeHearts: _hearts(json['bladeHearts']),
        heartTotal: json['heartTotal'] as int? ?? 0,
        requiredHeartTotal: json['requiredHeartTotal'] as int? ?? 0,
        stats: json['stats'] as int?,
        isDeleted: json['isDeleted'] as bool? ?? false,
      );

  static Map<HeartColor, int> _hearts(Object? node) {
    if (node is! Map) return const {};
    return {
      for (final entry in node.entries)
        HeartColor.fromKey(entry.key as String): entry.value as int,
    };
  }
}

/// 個別の刷り。printingId をキーとする。
class Printing {
  const Printing({
    required this.printingId,
    required this.cardNumber,
    required this.expansion,
    required this.rarity,
    required this.isParallel,
    this.illustrator = '',
    this.imageHash = '',
  });

  final String printingId;
  final String cardNumber;
  final String expansion;
  final String rarity;

  /// この刷りがパラレルかどうか。
  ///
  /// ★「cardNumber ごとの代表 1 枚」ではない★
  /// 同じカードが複数商品に再録されると通常刷りが複数になる
  /// (ブースターの N とプロモの PR、スタートデッキの SD と SD2 など)。
  /// 公式サイトの parallel=normal 検索もその全てを返す。
  ///
  /// パラレル表示 OFF = isParallel が false の刷りを「すべて」表示する。
  final bool isParallel;

  final String illustrator;
  final String imageHash;

  factory Printing.fromJson(Map<String, dynamic> json) => Printing(
        printingId: json['printingId'] as String,
        cardNumber: json['cardNumber'] as String,
        expansion: json['expansion'] as String? ?? '',
        rarity: json['rarity'] as String? ?? '',
        isParallel: json['isParallel'] as bool? ?? false,
        illustrator: json['illustrator'] as String? ?? '',
        imageHash: json['imageHash'] as String? ?? '',
      );
}
