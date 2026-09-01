/// ★★ `CLAUDE.md` §1 / §2 のパッケージ境界を★機械で見張る ★★
/// （**D-D** / 決定 **D128-3** / `docs/同期設計メモ.md` §42-8 / §43）
///
/// ★★ なぜ機械に移すか ★★
/// `CLAUDE.md` §3 は境界の検証を**手動の `grep`** で置いている。
/// ★★**そのうち `loveca_core` の側は★常に非 0 を返す**★★ —— 当たるのは
/// **禁止そのものを説明した doc の行**であり（**D-30**）、§3 自身が
/// 「★**非 0 だから違反が残っていると読まないこと。★当たった行を 1 件ずつ開くこと**」と書いている。
/// → ★★**D-25 が「★常に非 0 なら誰も読まない」と定めた形そのものである。**★★
/// → ★**さらに §3 は「★手動の見張りは忘れられる」と★自ら書いている**（**D-2** が前例）。
/// → ★★**許可リストとの★完全一致に移す。★件数ではなく集合で見る**★★（**D-15** ——
///   ★数を書くなら機械が数えられる形にする。★★件数も内訳もこのファイルが正である★★）。
///
/// ★★ いま引かれた引き金（決定 **D128**）★★
/// ★**候補 3（端末が鍵を作って名乗る）が選ばれた**ので、★★鍵を作るコードがいずれ書かれる★★。
/// ★**鍵は推測できてはならない**ので `Random.secure()` を引く。
/// → ★★**`loveca_core` に入れてはならない**★★（§1 の「seed なし `Random()`」の禁止 / **D128-3**）。
/// ★**その禁止を今日見張っているのは★手動の grep 1 本だけだった**（★走査した）。
///
/// ★★ 何を見張るか（★2 つ。★★見ているものが違う★★ / **D-27**）★★
///
/// | 走査 | 見るもの | ★なぜ分けるか |
/// |---|---|---|
/// | ★**指示行** | `package:flutter` / `dart:ui` / `dart:io` | ★**doc の中の同じ字面を拾わない**（**D-30**）。★★素の字面で走ると★禁止を説明した行が当たる★★ |
/// | ★**本文** | `DateTime.now` / `Random()` | ★★**指示行では★1 件も見えない**★★（★呼び出しであって import ではない）。★許可リストで doc の行を通す |
///
/// ★**片方だけでは足りない** —— ★`dart:io` を足す事故と `DateTime.now()` を書く事故は**別である**。
/// ★**2 つとも対で測った**（★正は `docs/同期設計メモ.md` §43）。
///
/// ★★ 走査する木を絞った理由と、絞ったことで範囲外になるもの（**D-31**）★★
/// ★**見るのは `loveca-core/lib` と `loveca-db/lib` の 2 つだけである。**
/// ★**`CLAUDE.md` §1 / §2 が境界を課しているのが★その 2 つだからである**（★実読）。
/// → ★**範囲外**: ★`loveca-server/lib`（★自分の走査テストを持つ / **D115-7** の (c)）/
///   ★`loveca-ui/lib`（★Flutter そのものなので §1 の制約を持たない）。
/// → ★★**受けを置く**★★: ★下の [libPackageWatchers] が★**リポジトリを実際に見て**
///   `lib/` を持つパッケージを数え、★★見張りの割り当てとずれたら落ちる★★。
///   ★**パッケージを足した人は、★その境界を誰が見るかを★宣言することになる。**
///
/// ★★ このファイル自身は走査対象ではない ★★
/// 上の表にも下の定数にも禁止対象の字面が実在するが（**D-30**）、
/// ★**走るのは `loveca-core/lib` と `loveca-db/lib` だけである。**★`test/` は入っていない。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/source_scan.dart';

/// ★`loveca_core` が `import` / `export` してはならない URI（`CLAUDE.md` §1）。
const _forbiddenUrisInCore = <String>['package:flutter', 'dart:ui', 'dart:io'];

/// ★`loveca_db` が `import` / `export` してはならない URI（`CLAUDE.md` §2）。
///
/// ★★ `dart:io` を入れない ★★
/// §2 は `loveca_db` に **Flutter 非依存だけを課す**（★実読）。
/// `dart:io` は**禁止ではなく、置き場所が決まっている** —— 下の [_dbNativeOnly]。
const _forbiddenUrisInDb = <String>['package:flutter', 'dart:ui'];

/// ★`loveca_db` で `dart:io` を引いてよいファイル（`CLAUDE.md` §2 / リポジトリ相対）。
const _dbNativeOnly = <String>{
  // ★★ 汚染範囲はこの 2 つに閉じる（`CLAUDE.md` §2）★★
  //   `lib/native.dart` と `lib/src/native/` の下だけ、と §2 が定めている。
  'loveca-db/lib/native.dart',
  'loveca-db/lib/src/native/local_dir_source.dart',
};

/// ★`loveca_core` の**本文**に許される当たり。★**リポジトリ相対パス → 件数**。
///
/// ★★ 理由の無い許可を作らない（**D-30**）★★
/// 禁止対象を説明する文書は、禁止対象と**同じ字面を必ず含む**。
/// ★**2 件とも★禁止そのものを説明した doc の行である**（★1 件ずつ開いて確かめた）。
const _allowedTextHitsInCore = <String, int>{
  // ★`reduce` が純粋関数である条件を並べた行（★2 件 —— 時刻と乱数）。
  'loveca-core/lib/src/game/reduce.dart': 2,
  // ★`DeterministicRng` を注入する理由を書いた行（★1 件 —— 乱数）。
  'loveca-core/lib/src/game/rng.dart': 1,
};

/// ★`lib/` を持つパッケージと、★その境界を**誰が見るか**。
///
/// ★★ ここが **D-31** の受けである ★★
/// ★**パッケージが増えたら、★境界を誰が見るかを★ここに書くことになる。**
/// ★**「見ない」と書いてもよい。★書かないことだけができない。**
const _libPackageWatchers = <String, String>{
  'loveca-core/lib': '★このファイル（指示行 ＋ 本文）',
  'loveca-db/lib': '★このファイル（指示行のみ）',
  'loveca-server/lib': '★`loveca-server/test/core_boundary_test.dart`（決定 D115-7 の (c)）',
  'loveca-ui/lib': '★見ない（★Flutter そのもの。★CLAUDE.md §1 の制約を持たない）',
};

/// ★`import` / `export` の指示行。★**両方を見る** ——
/// `export` は再公開であり、`import` と同じだけ線を跨ぐ
/// （`loveca-server/test/support/directive_scan.dart` と同じ判断 / ★あちらの (B) の対）。
///
/// ★引用符は `\x22` で書く（★字面の二重引用符をこの raw 文字列に入れないため / **D-38**）。
final _directive = RegExp(
  r"^[ \t]*(?:import|export)[ \t]+r?(['\x22])([^'\x22]*)\1",
  multiLine: true,
);

/// ★**本文**に当てる字面（`CLAUDE.md` §1 の禁止のうち、★指示行では見えない 2 つ）。
///
/// ★★ 字面を広げない（**D-37 の裏**）★★
/// ★`Random(` ではなく `Random()` を見る。★広げると `Random.secure()` と
/// `Random(seed)` を拾い、★★禁止されていないものが当たる★★
/// （`test/support/source_scan.dart` の doc が★その前例を記録している）。
final _forbiddenText = RegExp(r'DateTime\.now|Random\(\)');

/// [source] の `import` / `export` の URI。★分類器そのもの。★陽性対照はここへ当てる。
List<String> directiveUris(String source) =>
    _directive.allMatches(source).map((m) => m.group(2)!).toList();

/// [root] 以下の `.dart` のうち、★[uris] のどれかを引いているファイル。
///
/// ★**リポジトリ相対の POSIX パス**を返す。★生成物 `*.g.dart` も見る
/// （★生成されたコードが線を跨いでも★線は跨いでいる）。
Set<String> filesImporting(String root, List<String> uris) {
  final out = <String>{};
  final dir = Directory(root);
  if (!dir.existsSync()) return out;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final found = directiveUris(entity.readAsStringSync());
    if (found.any((u) => uris.any((bad) => u == bad || u.startsWith('$bad/')))) {
      out.add(repoRelative(entity.path));
    }
  }
  return out;
}

/// `loveca-ui` を作業ディレクトリとしたパスを、★リポジトリのルートから見た形に直す。
String repoRelative(String path) {
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

/// ★リポジトリに実在する「`lib/` を持つパッケージ」。★リポジトリ相対の POSIX パス。
///
/// ★`loveca-data` は Python なので `lib/` を持たず、★自動的に外れる。
Set<String> libPackages() {
  final out = <String>{};
  for (final entity in Directory('..').listSync()) {
    if (entity is! Directory) continue;
    final name = p.split(entity.path).last;
    if (!name.startsWith('loveca-')) continue;
    if (Directory(p.join(entity.path, 'lib')).existsSync()) {
      out.add('$name/lib');
    }
  }
  return out;
}

/// 見張りが割り当てられているパッケージ。
Set<String> libPackageWatchers() => _libPackageWatchers.keys.toSet();

/// `loveca-core/lib` の**本文**の当たり。★**リポジトリ相対パス → 件数**。
Map<String, int> coreTextHits() => scanDart(_coreLib, _forbiddenText)
    .map((name, count) => MapEntry(_coreFileByName[name]!, count));

const _coreLib = '../loveca-core/lib';
const _dbLib = '../loveca-db/lib';

/// [scanDart] は**ファイル名**を鍵にするので、★リポジトリ相対パスへ引き直す表を作る。
///
/// ★★ 名前が衝突したら落ちる ★★
/// ★同じ名前の `.dart` が 2 つ在ると、★[scanDart] の側で件数が畳まれて
/// ★★どちらの当たりか分からなくなる★★。★下の群がそれを見る。
final Map<String, String> _coreFileByName = _buildCoreFileIndex();

Map<String, String> _buildCoreFileIndex() {
  final out = <String, String>{};
  for (final entity in Directory(_coreLib).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final name = p.split(entity.path).last;
    if (out.containsKey(name)) {
      throw StateError('★同じ名前の .dart が 2 つある: $name');
    }
    out[name] = repoRelative(entity.path);
  }
  return out;
}

void main() {
  group('★★ 分類器が当たること（★これが無いと下の 0 件は何も証明しない / D-10）★★', () {
    test('★ 指示行を拾う（import も export も）', () {
      expect(directiveUris("import 'dart:io';"), <String>['dart:io']);
      expect(directiveUris("export 'package:flutter/material.dart';"),
          <String>['package:flutter/material.dart']);
      // ★字下げされていても拾う（★条件つき import の書き方）。
      expect(directiveUris("  import 'dart:ui';"), <String>['dart:ui']);
      // ★raw 文字列の接頭辞つきも拾う。
      expect(directiveUris("import r'dart:io';"), <String>['dart:io']);
    });

    test('★★ doc の中の同じ字面は拾わない（D-30 —— これが分ける理由である）★★', () {
      expect(directiveUris("/// ★ここでは import 'dart:io'; を禁じる"), isEmpty);
      expect(directiveUris("// import 'package:flutter/material.dart';"), isEmpty);
    });

    test('★ 本文の字面を拾う', () {
      expect(_forbiddenText.allMatches('final t = DateTime.now();').length, 1);
      expect(_forbiddenText.allMatches('final r = Random();').length, 1);
    });

    test('★★ 禁止されていない形は拾わない（D-37 の裏 —— 字面を広げない）★★', () {
      // ★`Random.secure()` は §1 の禁止ではない（★`deck_id.dart` / `board_seed.dart` の doc）。
      expect(_forbiddenText.allMatches('Random.secure()').length, 0);
      // ★seed つきは再現できるので禁止ではない。
      expect(_forbiddenText.allMatches('Random(42)').length, 0);
      // ★`DateTime` を値として持つことは可（`CLAUDE.md` §1 の但し書き）。
      expect(_forbiddenText.allMatches('DateTime.utc(2026, 9, 1)').length, 0);
    });
  });

  group('★★ 走査の根と、パッケージの名簿（D-10 / D-31）★★', () {
    test('★★ 根が 2 つとも実在する（★綴りの受け）★★', () {
      // ★綴りを間違えると、★その木の当たりが黙って落ちる。
      expect(Directory(_coreLib).existsSync(), isTrue, reason: '★$_coreLib');
      expect(Directory(_dbLib).existsSync(), isTrue, reason: '★$_dbLib');
    });

    test('★★ `lib` を持つパッケージは 1 つ残らず★見張りが割り当てられている ★★', () {
      // ★★ これが無いと、★パッケージを足した人が★境界を宣言し忘れても
      //   ★★誰も気づかない★★（**D-31** —— ★走査の穴はそのまま完了条件の穴になる）。
      // ★先に「実在する側」が空でないことを見る（0 件は何も証明しない / **D-10**）。
      expect(libPackages(), isNotEmpty);
      expect(libPackageWatchers(), libPackages(),
          reason: '★パッケージを足したなら、★その境界を★誰が見るかをここに書くこと'
              '（★「見ない」でもよい。★書かないことだけができない）');
    });

    test('★ `loveca-core/lib` に同じ名前の `.dart` が 2 つ無い', () {
      // ★[scanDart] はファイル名を鍵にする。★衝突すると件数が畳まれる。
      expect(_coreFileByName, isNotEmpty);
      expect(_coreFileByName.length,
          Directory(_coreLib)
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))
              .length);
    });
  });

  group('★★ `loveca_core` の境界（`CLAUDE.md` §1 / D-D）★★', () {
    test('★★ 禁止 URI を引くファイルが 1 つも無い ★★', () {
      expect(filesImporting(_coreLib, _forbiddenUrisInCore), isEmpty,
          reason: '★★`loveca_core` は純粋 Dart である★★ —— '
              '★サーバーとスマホで共有できなくなる（`CLAUDE.md` §1 の理由 1 / 2）');
    });

    test('★★ 本文の当たりは許可リストと★完全一致する ★★', () {
      // ★件数ではなく**集合**で見る（★件数だけだと入れ替わりが通る）。
      expect(coreTextHits(), _allowedTextHitsInCore,
          reason: '★★時刻と乱数を `loveca_core` に持ち込まないこと★★ —— '
              '★同じ入力から同じ結果が出なくなる（`CLAUDE.md` §1）。'
              '★★鍵を作るコードもここには置けない★★（決定 **D128-3**）');
    });
  });

  group('★★ `loveca_db` の境界（`CLAUDE.md` §2）★★', () {
    test('★★ Flutter を引くファイルが 1 つも無い ★★', () {
      expect(filesImporting(_dbLib, _forbiddenUrisInDb), isEmpty,
          reason: '★`dart test` だけで検証できる状態を保つ（`CLAUDE.md` §2）');
    });

    test('★★ `dart:io` を引くのは native の 2 ファイルだけである ★★', () {
      // ★★ 「0 件であること」ではない。★**置き場所が決まっている** ★★
      //   §2 は `loveca_db` に `dart:io` を禁じていない。★閉じ込めているだけである。
      expect(filesImporting(_dbLib, const <String>['dart:io']), _dbNativeOnly,
          reason: '★汚染範囲は `lib/native.dart` と `lib/src/native/` に閉じる');
    });
  });
}
