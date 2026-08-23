/// `deckId` の形式（決定 D62）.
///
/// ★★ 30 行の自前実装で最も静かに壊れるのが version / variant のビットである ★★
/// 立て忘れても 32 桁の 16 進数が並ぶので**見た目は UUID のまま**で、
/// 目視でも `flutter analyze` でも気づけない。形式を機械的に検査する。
///
/// ★衝突可能性は測らない。v4 の衝突確率を実測しようとすると意味のないテストになる。
/// 固定するのは**形式**と、**同じジェネレータを 2 回呼ぶと違う値が返ること**まで。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_ui/src/data/deck_id.dart';

/// RFC 4122 §4.4 の v4。★13 桁目が `4`、17 桁目が `8/9/a/b`。
final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  test('★RFC 4122 の v4 形式である（version / variant のビットが立っている）', () {
    final id = randomDeckIdV4();

    expect(id, matches(_uuidV4), reason: 'v4 の形式を満たしていない: $id');
    expect(id.length, 36);
    // ★桁位置で名指しして確認する。正規表現だけだと、あとで式を緩めたときに
    //   ビットの検査が落ちても気づけない。
    expect(id[14], '4', reason: 'version が 4 でない: $id');
    expect('89ab'.contains(id[19]), isTrue, reason: 'variant が 10xx でない: $id');
  });

  test('★100 回引いてもすべて形式を満たす', () {
    // ★ビットは毎回同じ位置に立つので確率的な検査ではない。
    //   マスクを間違えて「ときどき通る」形になった場合に捕まえるための回数。
    for (var i = 0; i < 100; i++) {
      expect(randomDeckIdV4(), matches(_uuidV4));
    }
  });

  test('2 回呼ぶと違う値が返る', () {
    expect(randomDeckIdV4(), isNot(randomDeckIdV4()));
  });

  test('★DeckIdGenerator として注入できる（テストで固定するため）', () {
    // Clock（設計メモ §9-1）と同じ形。固定値を入れられないと
    // 保存の往復テストが deckId を予測できず、検証が緩む。
    const fixed = '00000000-0000-4000-8000-000000000001';
    const DeckIdGenerator generator = _fixedId;

    expect(generator(), fixed);
    expect(generator(), matches(_uuidV4));
  });
}

String _fixedId() => '00000000-0000-4000-8000-000000000001';
