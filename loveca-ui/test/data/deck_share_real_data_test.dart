/// ★★ 共有形式の書式が実データの全 cardNumber で成立することを見張る ★★
///
/// 決定 D67 は「1 行 1 カード / 区切りは空白 / NFKC + 前後空白除去だけ許容」と
/// 定めた。これが成立するのは、**実データの cardNumber が ASCII のみで
/// NFKC でも変化しない**からである（2026-08-24 に 1,708 件を走査して確認）。
///
/// ★★ ただしそれは「現時点の実データの性質」であって保証ではない ★★
/// CLAUDE.md §5-(6) は `PRproteinbar` のような**公式レアリティ一覧に無い接尾**が
/// 実在したと記録している。新商品で空白や `#` を含む番号が出れば、
/// 行指向の書式では表せなくなる——**そのとき黙って壊れないように**、
/// ここで全件を通す。
///
/// ★実データ（`loveca-data/data/`）は git 管理外なので、
/// 未配置なら理由を明示して飛ばす。
/// ★★ このテストの結果を報告するときは skip 件数も併記すること ★★
/// 「全通過」に skip が埋もれると、検証しているつもりで検証していない状態になる。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_ui/src/data/deck_share.dart';

Directory get _dist => Directory(
      Platform.environment['LOVECA_DIST_DIR'] ??
          '${Directory.current.parent.path}/loveca-data/data/dist',
    );

bool _skipIfMissing() {
  if (_dist.existsSync()) return false;
  markTestSkipped(
    '★実データ未配置のため検証していません★ ${_dist.path} がありません。'
    'loveca-data/data/ は git 管理外です。'
    'LOVECA_DIST_DIR で場所を指定できます。',
  );
  return true;
}

/// 配信物の全 cardNumber を読む。
List<String> _allCardNumbers() {
  final cards = Directory('${_dist.path}/cards');
  final out = <String>{};
  for (final file in cards.listSync().whereType<File>()) {
    if (!file.path.endsWith('.json')) continue;
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    for (final printing in (json['printings'] as List).cast<Map>()) {
      out.add(printing['cardNumber'] as String);
    }
  }
  return out.toList()..sort();
}

void main() {
  test('★★ 実データの全 cardNumber が共有形式で往復する ★★', () {
    if (_skipIfMissing()) return;

    final cardNumbers = _allCardNumbers();
    expect(cardNumbers.length, greaterThan(1000),
        reason: '仕込みが効いていること自体をまず確かめる');

    // ★1 件ずつ書いて読み戻す。1 件でも崩れたら書式を見直す合図。
    final unencodable = <String>[];
    final brokenRoundTrip = <String>[];

    for (final cardNumber in cardNumbers) {
      if (!isEncodableCardNumber(cardNumber)) {
        unencodable.add(cardNumber);
        continue;
      }
      final parsed = parseDeckShare('$cardNumber x3');
      if (parsed.unparsedLines.isNotEmpty || parsed.counts[cardNumber] != 3) {
        brokenRoundTrip.add(cardNumber);
      }
    }

    expect(unencodable, isEmpty,
        reason: '★この書式で表せない cardNumber が出た。'
            '決定 D67 の書式を見直すか、出力側の扱いを決めること。');
    expect(brokenRoundTrip, isEmpty,
        reason: '★書いて読み戻せない cardNumber が出た。'
            'parseDeckShare と encodeDeckShare が食い違っている。');
  });

  test('★ 正規化しても変わらない（実データは ASCII のみという前提の見張り）', () {
    if (_skipIfMissing()) return;

    final changed = [
      for (final cardNumber in _allCardNumbers())
        if (normalizeShareToken(cardNumber) != cardNumber) cardNumber,
    ];

    expect(changed, isEmpty,
        reason: '★正規化で変わる cardNumber が出た。'
            '入力の照合が「正規化後」なので、保存値と当たらなくなる。');
  });
}
