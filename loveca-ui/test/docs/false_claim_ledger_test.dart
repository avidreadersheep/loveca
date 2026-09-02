/// ★★ 偽と測った主張の★★写しが★何か所に在るか★★を★台帳と突き合わせる ★★
///
/// ★★ 引き金 —— ★相談役の指示（運転指示【0】(1) / 2026-09-02）★★
/// ★**「★§93 で★★同じ偽が 3 か所に在った★★。★欄を単位にすると★片方だけ直る。**
/// ★**　★同じ主張が何か所に写っているかを★★機械で数える手段が作れるか★★。**
/// ★**　★§93 では手で 3 か所見つけた。★★4 か所目が無い保証が無い★★」。**
///
/// ★★ 実際に 4 か所目が在った（★2026-09-02 / `docs/tools/claim_copies.py` が数えた）★★
/// ★**`docs/同期設計メモ.md` の §10 の **N-28** の「今日は決めない」節**。
/// → ★**手で数える限り★★また抜ける★★**（★型は **D-2** —— ★手動の見張りは忘れられる）。
///
/// ★★ 何を見張るか ★★
/// ★**偽と測った主張ごとに★★ファイルごとの件数を持ち、★完全一致で見張る★★。**
/// ★**写しが 1 つ増えても、★★1 つ減っても落ちる★★**（★先例は `measurement_date_test.dart` の `_baseline`）。
///
/// ★★ 落ちたときの直し方 ★★
/// ★**その場所を★★分類する（★主張 / ★注記）★★。**
///   ★**主張なら**: ★注記の覆う範囲に足す（★注記は★★欄ではなく主張に付く★★ / `docs/同期設計メモ.md` §95-2）。
///   ★**注記なら**: ★台帳を 1 動かす。★★理由を書く★★。
/// ★★**「数を合わせる」ことではない**★★。
///
/// ★★ 代償（★★隠さない★★）★★
/// ★**この主張を★doc で 1 行語るたびに落ちる** —— ★★注記は★主張と同じ字面を必ず含む★★（**D-30**）。
/// ★**型は **D-25** の別の形**（★非 0 が常態になると★本物が埋もれる）。
/// → ★**だから★★偽と測ったものだけを載せる★★**（★一斉監査はしない / **D-28**）。
///
/// ★★ 走査する木 —— ★絞った。★範囲外を書く（**D-31**）★★
/// ★**見るのは `CLAUDE.md` / `ルール整合性チェック_v1.06.md` / `docs/*.md`（★★直下だけ★★）である。**
///
/// | 範囲外 | ★理由 |
/// |---|---|
/// | `docs/相談役への報告/` | ★★**増え続けるので★非 0 が常態になる**★★（**D-25**）。★**報告は★★記録であって live な写しではない★★** |
/// | `docs/セッション報告/` | ★同上 |
/// | ★`.dart` / ★`.py` | ★★**2 件在る。★2 件とも注記である**★★（★2026-09-02 実測）。★**live な写しが入ったら★★その日に木を広げること★★** |
///
/// ★★ 台帳を空で始めない ★★
/// ★**空の台帳は★★何も守らない★★**（★型は **D114-7** の理由 2 の列）。
/// ★**2 件目を足す手順は [_claims] の doc に書いてある。**
///
/// ★★ 総合ルールの条番号は 1 つも引かない ★★
/// ★これはゲームの規則ではなく★★文書の保守★★である。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

final _repoRoot = Directory('..');

/// ★★ 偽と測った主張 1 件 ★★
class FalseClaim {
  const FalseClaim({
    required this.id,
    required this.summary,
    required this.needles,
    required this.perFile,
  });

  /// ★この台帳の中の名前（★★新しい採番体系ではない★★）。
  final String id;

  /// ★1 行の説明（★★機械は読まない★★）。
  final String summary;

  /// ★★1 つ残らず★★同じ単位に在るときだけ 1 件と数える字面。
  final List<String> needles;

  /// ★ファイルごとの件数（★★完全一致★★ / ★0 の行も書く）。
  final Map<String, int> perFile;
}

/// ★★ 台帳 —— ★偽と測った主張だけを載せる ★★
///
/// ★★ 足す手順 ★★
/// ★**1. ★偽だと★★測る★★**（★見込みで足さない / **D-28**）。
/// ★**2. ★`docs/tools/claim_copies.py` で★★写しを全件並べる★★**（★★述語の側の字面で探す★★ / §95-3）。
/// ★**3. ★1 件ずつ★★主張 / 注記に分類する★★**（★★道具は分けられない★★ / **D-30**）。
/// ★**4. ★注記を★★主張に 1 つ★★置き、★覆う場所を全部並べる**（§95-2）。
/// ★**5. ★ここに 1 行足す。★★0 のファイルも書く★★**（★★書かないことだけができない★★ / **D-31**）。
const _claims = <FalseClaim>[
  FalseClaim(
    id: 'C-01',
    summary: '★`loveca_core` を割ると★import が動く（★**N-28** の α-3 の理由 / §90-4 が偽と測った）',
    // ★★ 主語ではなく★述語で探す ★★
    // ★**(戊) の欄には `loveca_core` の字面が★★1 つも無い★★**（★2026-09-02 実測）ので、
    //   ★主語で探すと★★4 か所のうち 1 つを落とす★★（§95-3）。
    needles: <String>['import が動く'],
    // ★★ 2026-09-02 に★この検査自身が数えた ★★
    perFile: <String, int>{
      'CLAUDE.md': 1,
      'ルール整合性チェック_v1.06.md': 0,
      'docs/PhaseEngine設計メモ.md': 0,
      'docs/UI技術検証メモ.md': 0,
      'docs/UI設計メモ.md': 0,
      'docs/プラットフォームを足す手順.md': 0,
      'docs/作業待ち行列.md': 0,
      'docs/利用者への問い.md': 0,
      'docs/同期設計メモ.md': 15,
      'docs/引き継ぎドキュメント.md': 0,
      'docs/引き継ぎドキュメント_注意.md': 0,
      'docs/決定事項一覧.md': 2,
      'docs/盤面設計メモ.md': 0,
      'docs/相談役への引き継ぎ.md': 0,
    },
  ),
];

/// ★★ 数える単位 —— ★表の行は★★セルごとに割る★★ ★★
///
/// ★**§10 の **N-28** の表は★★1 行の中に (戊) と (己) の 2 か所を持つ★★**（★2026-09-02 実測）。
/// → ★**行で数えると★★2 か所が 1 に潰れる★★。**
List<String> claimUnits(String line) {
  if (!line.trimLeft().startsWith('|')) {
    final one = line.trim();
    return one.isEmpty ? const <String>[] : <String>[one];
  }
  final out = <String>[];
  for (final cell in line.split('|')) {
    final text = cell.trim();
    if (text.isNotEmpty) out.add(text);
  }
  return out;
}

/// ★`needles` を★★1 つ残らず★★含む単位を★★1 件ずつ返す★★（★位置と字面の対）。
///
/// ★★ 本番も対も★この関数を通す（**D-27** の (甲)）★★
/// ★**下の [claimHits] / [claimHitDetails] は★★どちらもこれを通す★★**
///   （★数え方を 2 か所に持たない / **D-15** の規約 3）。
List<({String at, String unit})> claimScan(String text, List<String> needles) {
  final lines = const LineSplitter().convert(text);
  final out = <({String at, String unit})>[];
  for (var i = 0; i < lines.length; i++) {
    final units = claimUnits(lines[i]);
    for (var c = 0; c < units.length; c++) {
      if (needles.every(units[c].contains)) {
        out.add((at: '${i + 1}:$c', unit: units[c]));
      }
    }
  }
  return out;
}

/// ★`needles` を★★1 つ残らず★★含む単位を `行:セル` で返す。
List<String> claimHits(String text, List<String> needles) =>
    claimScan(text, needles).map((h) => h.at).toList();

/// ★★ 落ちたときに★位置へ★★単位の字面を添える★★（★★直す手間の側の手当て★★）★★
///
/// ★★ なぜ足したか —— ★★測った（2026-09-02 / §96-3）★★ ★★
/// ★**落ちたときの文言は★★写しを 1 つ残らず並べるが、★どれが新しいかを言わない★★。**
/// ★**直す人は★★全部の位置を自分で突き合わせることになる★★**（★★実測: ★1 件増えたときに 16 か所が並んだ★★）。
/// → ★**字面を添えれば★★「いま自分が書いた行」を目で拾える★★。**
///
/// ★★ どれが新しいかは★依然★言えない。★隠さない ★★
/// ★**台帳は★★件数しか持たない★★。★位置を持たせると★★上の行が 1 行増えるたびに落ちる★★**
///   （★型は **D-25** の別の形 —— ★★非 0 が常態になる★★）。
/// ★**だから「探しやすくする」までである**（★§96-4）。
String claimHitDetails(String text, List<String> needles, {int maxChars = 48}) {
  final hits = claimScan(text, needles);
  final rows = hits.map((h) {
    final u = h.unit;
    final head = u.length <= maxChars ? u : '${u.substring(0, maxChars)}…';
    return '  ${h.at} $head';
  });
  return rows.join(String.fromCharCode(10));
}

/// ★走査する `.md` を★リポジトリから導く（**D-31** の受け）。
List<String> _corpus() {
  final out = <String>['CLAUDE.md', 'ルール整合性チェック_v1.06.md'];
  for (final e in Directory(p.join(_repoRoot.path, 'docs')).listSync()) {
    if (e is File && e.path.endsWith('.md')) {
      out.add('docs/${p.basename(e.path)}');
    }
  }
  out.sort();
  return out;
}

String _read(String rel) =>
    File(p.join(_repoRoot.path, rel.replaceAll('/', p.separator)))
        .readAsStringSync();

void main() {
  group('★★ 陽性対照 —— ★数え方が働くこと（**D-10**）★★', () {
    test('★★ 素の行は★1 件と数える ★★', () {
      expect(claimHits('★ここで import が動く。', const <String>['import が動く']),
          <String>['1:0']);
    });

    test('★★ 表の 1 行に 2 か所在れば★2 件と数える（★★§N-28 の形★★）★★', () {
      const row = '| ★α-3 | ★移設（import が動く） | ★当たる（★割ると import が動く） |';

      expect(claimHits(row, const <String>['import が動く']).length, 2);
    });

    test('★★ 対: ★表でなければ★同じ字面でも 1 件である（★セル割りを見ている）★★', () {
      const line = '★移設（import が動く） ／ ★当たる（★割ると import が動く）';

      expect(claimHits(line, const <String>['import が動く']).length, 1);
    });

    test('★★ 対: ★字面は★1 つ残らず要る ★★', () {
      expect(claimHits('★import が動く', const <String>['import が動く', '割ると']),
          isEmpty);
    });

    test('★★ 対: ★同じ単位に揃えば★数える ★★', () {
      expect(claimHits('★割ると import が動く', const <String>['import が動く', '割ると']),
          <String>['1:0']);
    });

    test('★★ 対: ★無い字面は★0 件である ★★', () {
      expect(claimHits('★ここには無い', const <String>['import が動く']), isEmpty);
    });
  });

  // ★★ 落ちたときの文言 —— ★★直す手間の側（§96-4）★★
  //
  // ★★ これは「守り」ではない。★★直す人が読むもの★★である ★★
  // ★**測って足した** —— ★★1 件増えたときの文言が★16 か所を並べ、★どれが新しいかを言わなかった★★
  //   （★2026-09-02 実測 / §96-3）。
  // ★**対を置く理由**: ★★字面を落としても★件数の検査は通ってしまう★★
  //   （→ ★**手当てが★★黙って空振りする★★** / ★型は **D-20** の列）。
  group('★★ 落ちたときの文言に★単位の字面が添う ★★', () {
    const needles = <String>['import が動く'];

    test('★★ 位置だけでなく★字面が出る ★★', () {
      final out = claimHitDetails('★割ると import が動く。', needles);

      expect(out, contains('1:0'));
      expect(out, contains('割ると import が動く'));
    });

    test('★★ 長い単位は★切り詰める（★★16 か所並んでも読める★★）★★', () {
      final long = '★${'あ' * 200} import が動く';

      final out = claimHitDetails(long, needles, maxChars: 10);

      expect(out.contains('…'), isTrue);
      expect(out.length, lessThan(60));
    });

    test('★★ 対: ★写しが 0 件なら★空である ★★', () {
      expect(claimHitDetails('★ここには無い', needles), isEmpty);
    });

    test('★★ 数え方は [claimHits] と★1 件も違わない（★★同じ走査を通る★★）★★', () {
      // ★★ 数え方を 2 か所に持たない（**D-15** の規約 3）★★
      const row = '| ★α-3 | ★移設（import が動く） | ★当たる（★割ると import が動く） |';
      final detail = claimHitDetails(row, needles);

      expect(claimHits(row, needles).length, 2);
      expect(String.fromCharCode(10).allMatches(detail).length, 1);
    });
  });

  group('★★ 走査する木（**D-31** の受け）★★', () {
    test('★★ 台帳の鍵は★リポジトリの `.md` と★完全一致する ★★', () {
      for (final claim in _claims) {
        expect(_corpus().toSet(), claim.perFile.keys.toSet(),
            reason: '★`.md` を足したら★${claim.id} にも 1 行足すこと'
                '（★写しが無いなら 0 と書く。★★書かないことだけができない★★）');
      }
    });

    test('★★ どのファイルも★読める（★陽性対照）★★', () {
      for (final rel in _claims.first.perFile.keys) {
        expect(_read(rel), isNotEmpty, reason: rel);
      }
    });

    test('★★ 範囲外に★実際に写しが在る（★★除外が空振りしていない★★）★★', () {
      // ★★ 除外の理由が実在することを対で固定する（**D-25** の作法）★★
      // ★**件数は書かない** —— ★★報告は増え続ける★★。★「1 件以上」だけを見る。
      final reports = Directory(p.join(_repoRoot.path, 'docs', '相談役への報告'));
      final hits = <String>[];
      for (final e in reports.listSync()) {
        if (e is! File || !e.path.endsWith('.md')) continue;
        if (claimHits(e.readAsStringSync(), _claims.first.needles).isNotEmpty) {
          hits.add(p.basename(e.path));
        }
      }

      expect(hits, isNotEmpty,
          reason: '★★範囲外に写しが 0 件なら★除外の理由が消えている★★');
    });
  });

  group('★★ 件数は★台帳と完全一致する ★★', () {
    test('★★ 増えていない。★減ってもいない ★★', () {
      final diffs = <String>[];
      for (final claim in _claims) {
        claim.perFile.forEach((rel, want) {
          final got = claimHits(_read(rel), claim.needles);
          if (got.length != want) {
            // ★★ 位置だけでなく★字面も出す（★★直す手間の側 / §96-4★★）★★
            diffs.add('${claim.id} $rel: 台帳 $want / 実測 ${got.length}'
                '${String.fromCharCode(10)}${claimHitDetails(_read(rel), claim.needles)}');
          }
        });
      }

      expect(diffs, isEmpty,
          reason: '★★直し方は「その場所を分類して、★注記の覆う範囲に足す」ことである。'
              '★「台帳の数を合わせる」ことではない★★');
    });
  });

  group('★★ 台帳を空で始めない（§95-5）★★', () {
    test('★★ 1 件以上載っている ★★', () {
      expect(_claims, isNotEmpty);
      for (final claim in _claims) {
        expect(claim.needles, isNotEmpty, reason: claim.id);
        expect(claim.perFile.values.reduce((a, b) => a + b), greaterThan(0),
            reason: '★★合計 0 の主張は★何も守らない★★: ${claim.id}');
      }
    });
  });
}
