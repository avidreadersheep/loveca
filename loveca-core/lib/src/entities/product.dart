/// 収録商品と公式 Q&A.
///
/// 設計書 STEP 7 §7.3 に対応。
library;

/// 収録商品。
class Product {
  const Product({
    required this.expansionId,
    required this.name,
    this.releaseDate = '',
    this.slug = '',
    this.url = '',
  });

  final String expansionId;
  final String name;

  /// 公式表記は "2025.02.08" 形式。並べ替え用に [releaseDateTime] を使う。
  final String releaseDate;
  final String slug;
  final String url;

  /// 発売日。パースできない場合は null。
  DateTime? get releaseDateTime {
    final parts = releaseDate.split('.');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        expansionId: json['expansionId'] as String,
        name: json['name'] as String? ?? '',
        releaseDate: json['releaseDate'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );
}

/// 公式 Q&A。
///
/// カード効果を自動処理しない設計 (方針①) では、
/// プレイヤーが自分で判断するための材料として価値が高い。
/// 盤面からカードの裁定をすぐ引けることは実用上の強みになる。
class Faq {
  const Faq({
    required this.qaId,
    required this.question,
    required this.answer,
    this.faqId = 0,
    this.registTime = '',
    this.updateTime = '',
    this.cardNumbers = const [],
  });

  /// 公式の Q 番号。同一 Q&A が複数カードに紐づくため、これが重複排除のキー。
  final String qaId;
  final String question;
  final String answer;

  final int faqId;

  /// 公開日。取得日ではないことに注意 (公式 JSON の date は取得日)。
  final String registTime;
  final String updateTime;

  /// 関連するカード (cardNumber ではなく printingId で入る点に注意)。
  final List<String> cardNumbers;

  factory Faq.fromJson(Map<String, dynamic> json) => Faq(
        qaId: json['qaId'] as String? ?? '',
        question: json['question'] as String? ?? '',
        answer: json['answer'] as String? ?? '',
        faqId: json['faqId'] as int? ?? 0,
        registTime: json['registTime'] as String? ?? '',
        updateTime: json['updateTime'] as String? ?? '',
        cardNumbers: (json['cardNumbers'] as List?)?.cast<String>() ?? const [],
      );
}
