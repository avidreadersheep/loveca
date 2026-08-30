/// ★★ 旧・同期設計番号がコードに live で残っていないこと（`ルール整合性チェック_v1.06.md` D-5 / A-0）★★
///
/// 2026-08-27 に旧番号は `決定 D100` / `D101` / `D102` / `決定 D11` / `決定 D35` へ
/// 置き換えた。★**そのとき走査を丸括弧つきに限ったため、括弧なしが両方の層に残った**
/// （新所見 **D-31**）。2026-08-30 に書き換えを終えたので、次はこの検査が受けになる。
///
/// ★★ 「0 件であること」は検査にできない ★★
/// 旧番号を**説明している文**は、旧番号と同じ字面を必ず含む（新所見 **D-30**）。
/// 置き換えの注記（`deck.dart` / `tables.dart`）と、`deck_edit_page.dart` の
/// 「この段落の番号は UI のペイン番号である」という注意書きがそれである。
/// → ★**除外を足すと、その除外自身が穴になる**（D-30 が「名乗れば黙らせられる」と書いている）。
/// → ★★**だから件数で見張る。**★★ 許可リストとの**完全一致**であり、
///   1 件でも増えれば落ちる（先例は **決定 D97** のカード番号ハードコードの走査）。
///
/// ★★ もう 1 つの体系がある。混ぜてはならない ★★
/// `docs/UI設計メモ.md` §2-3 の**ペイン番号**が同じ字面を使う（検証パネル / 取り込み失敗の
/// 詳細 / デッキのメタ編集）。★**素の置換で壊れるのはこちらである**（D-5 が自分でそう書いている）。
/// → 許可リストの各行に**どちらの理由で許すか**を書く。理由の無い許可を作らない。
///
/// ★★ 字面をこのファイルに書かない ★★
/// 書くとこのファイル自身がヒットし、許可リストに自分を載せることになる
/// （`test/board/abolished_term_test.dart` が同じ理由で語を文書から取り出している）。
/// → ★**正規表現の文字クラスとして書く。**`P` の次が数字ではないので走査に当たらない。
/// → ★**陽性対照の文字列は連結で組む。**
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 旧番号の字面。★丸括弧の有無を問わない（**D-31** が「括弧つきに限ったのが穴だった」）。
final _legacy = RegExp(r'(^|[^A-Za-z0-9_])P[1-5]([^0-9A-Za-z_]|$)');

/// 走査する木。★`loveca-ui` を作業ディレクトリとした相対パス。
const _roots = <String>[
  'lib',
  'test',
  '../loveca-core/lib',
  '../loveca-core/test',
  '../loveca-db/lib',
  '../loveca-db/test',
];

/// ★許されるヒット。**リポジトリ相対パス → 件数**。
///
/// ★★ 理由の無い許可を作らない ★★
/// 「置き換えの注記」= 旧番号そのものを主題にした文（**D-30**）。
/// 「ペイン番号」= `docs/UI設計メモ.md` §2-3 の別体系。
const _allowed = <String, int>{
  // ★置き換えの注記（D-30）
  'loveca-core/lib/src/entities/deck.dart': 4,
  'loveca-db/lib/src/schema/tables.dart': 2,
  // ★ペイン番号 ＋ 「この段落は別体系である」という注意書き（D-30）。★内訳は書かない
  'loveca-ui/lib/src/ui/deck/deck_edit_page.dart': 8,
  // ★以下はすべてペイン番号（§2-3）
  'loveca-ui/lib/src/data/deck_repository.dart': 3,
  'loveca-ui/lib/src/data/deck_share.dart': 1,
  'loveca-ui/lib/src/data/master_repository.dart': 1,
  'loveca-ui/lib/src/state/deck_edit_store.dart': 1,
  'loveca-ui/lib/src/state/deck_list_store.dart': 1,
  'loveca-ui/lib/src/ui/deck/deck_list_page.dart': 2,
  'loveca-ui/lib/src/ui/deck/deck_meta_dialog.dart': 1,
  'loveca-ui/lib/src/ui/deck/deck_pane.dart': 4,
  'loveca-ui/lib/src/ui/deck/deck_validation_panel.dart': 1,
  'loveca-ui/lib/src/ui/settings/import_issues_section.dart': 1,
  'loveca-ui/test/data/deck_share_test.dart': 1,
  'loveca-ui/test/ui/card_art_test.dart': 1,
  'loveca-ui/test/ui/deck_edit_page_test.dart': 1,
  'loveca-ui/test/ui/deck_meta_dialog_test.dart': 1,
  'loveca-ui/test/ui/deck_pane_width_test.dart': 1,
  'loveca-ui/test/ui/settings_page_test.dart': 1,
};

/// 1 本の文字列に何件あるか。★分類器そのもの。陽性対照はここへ当てる。
int hitsIn(String source) => _legacy.allMatches(source).length;

/// リポジトリのルートから見た POSIX 形式のパスにする。★許可リストの鍵に使う。
String _repoRelative(String path) {
  final parts = p.split(p.normalize(p.join('loveca-ui', path)));
  final out = <String>[];
  for (final part in parts) {
    if (part == '..') {
      out.removeLast();
    } else {
      out.add(part);
    }
  }
  return out.join('/');
}

/// 実測。★**パス → 件数**。生成物 `*.g.dart` は数えない（手で書いた行ではない）。
Map<String, int> scan() {
  final found = <String, int>{};
  for (final root in _roots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      final count = hitsIn(entity.readAsStringSync());
      if (count > 0) found[_repoRelative(entity.path)] = count;
    }
  }
  return found;
}

void main() {
  group('★★ 陽性対照 —— 分類器が書き換え前の形を拾うこと ★★', () {
    // ★★ 字面を直に書かない。連結で組む（上の library doc）★★
    const legacy = 'P';

    test('★ 書き換え前の形は拾う（★これが無いと下の一致は何も証明しない）', () {
      expect(hitsIn('  // ★$legacy${5}: 作成時のカードマスタ版。'), 1);
      expect(hitsIn('  /// `deckId`（UUID v4 / $legacy${1}）'), 1);
      expect(hitsIn('  // ★$legacy${3}: 物理削除すると削除が同期で伝播しない。'), 1);
    });

    test('★★ 対: 書き換え後の形は拾わない ★★', () {
      expect(hitsIn('  // ★決定 D35: 作成時のカードマスタ版。'), 0);
      expect(hitsIn('  /// `deckId`（UUID v4 / 決定 D100）'), 0);
      expect(hitsIn('  // ★決定 D102: 物理削除すると削除が同期で伝播しない。'), 0);
    });

    test('★ 丸括弧の有無を問わない（**D-31** の穴そのもの）', () {
      expect(hitsIn('  /// ($legacy${4})'), 1);
      expect(hitsIn('  /// $legacy${4} は printingId 単位で保持する'), 1);
    });

    test('★ このファイル自身は 1 件も当たらない（★許可リストに自分を載せない）', () {
      final self = File(p.join('test', 'docs', 'legacy_design_number_test.dart'));
      expect(self.existsSync(), isTrue, reason: '★ファイル名を変えたらここも直す');
      expect(hitsIn(self.readAsStringSync()), 0);
    });
  });

  group('★★ 走査が対象を見ていること（前提）★★', () {
    test('★ 木が空でない —— 各 root に `.dart` が在る', () {
      for (final root in _roots) {
        final dir = Directory(root);
        expect(dir.existsSync(), isTrue, reason: '★走査の根が無い: $root');
        final darts = dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));
        expect(darts, isNotEmpty, reason: '★走査の根が空: $root');
      }
    });

    test('★ 実測が空でない（★0 件は「無い」と「見えていない」の区別がつかない / **D-10**）', () {
      expect(scan(), isNotEmpty);
    });
  });

  test('★★ 実測は許可リストと完全一致する ★★', () {
    // ★★ 落ちたときにすること ★★
    //   増えた側 —— その行が **ペイン番号**（`docs/UI設計メモ.md` §2-3）か、
    //     **旧番号を主題にした説明**（D-30）か、**同期の設計番号**かを人が分ける。
    //     最後のものだけが書き換えの対象である（`決定 D100` / `D101` / `D102` /
    //     `決定 D11` / `決定 D35` へ）。★機械には分けられない（D-5 がそう書いている）。
    //   減った側 —— 許可リストからその行を消す。★件数だけ直して理由を残さない、をしない。
    expect(scan(), _allowed);
  });
}
