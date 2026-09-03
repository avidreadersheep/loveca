/// ★★ 追跡されているファイルに★制御文字が 1 バイトも無いことを見る（**D-38** の受け）★★
///
/// ★★ 引き金 —— ★相談役の指示（運転指示【0】(6) / 2026-09-04）★★
/// ★**「**D-38** が★★5 度目である★★。★機械の受けが在るか確かめること。**
/// ★**　★捕まえられるなら立てること（**D-2**）。★★**D-30** に当たらない形にすること★★。**
/// ★**　★捕まえられないなら、★捕まえられないと書くこと」。**
///
/// ★★ 答え —— ★★捕まえられる。★しかも★立てた初日に 3 件当たった★★ ★★
///
/// | # | ★どこ | ★★何が入っていたか★★ |
/// |---|---|---|
/// | ★**1** | ★`CLAUDE.md`（★**D-38** の 2 度目の記録の行） | ★★**後退（0x08）が 1 バイト**★★ |
/// | ★**2** | ★`docs/同期設計メモ.md`（★同じ記録の写し） | ★★**同じ 1 バイト**★★ |
/// | ★**3** | ★`loveca-server/test/deck_endpoint_test.dart` | ★★**0x01 が 1 バイト**★★（★JSON でない字面を作る意図） |
///
/// ★★**1 と 2 は★★D-38 を説明した行そのものである★★**★★ —— ★**「★エスケープが★本物の後退に化けた」と
/// ★書いた行に、★★本物の後退が 1 バイト入っていた★★**（★2026-09-04 に★この検査が見つけた）。
/// → ★★**3 件とも直した。★許可リストは★空で始める**★★（**D115-6** の形）。
///
/// ★★ **D-30** に当たらない理由（★★言い切る★★）★★
/// ★**この検査が探すのは★★バイトであって★字面ではない★★。**
/// ★**規約を説明した文書は★★「後退」「0x08」と★語で書く★★**（**D-38** の規約 (b) がそう定めている）ので、
/// ★★**説明が★自分自身に当たることが★原理的に起きない**★★。
/// ★**この doc も★制御文字を 1 バイトも含まない**（★★対で固定した★★）。
///
/// ★★ 何を制御文字と見るか ★★
/// ★**0x00〜0x1F のうち★★タブ (0x09) / 改行 (0x0A) / 復帰 (0x0D) を除いたもの★★と、★0x7F。**
/// ★**除く 3 つの理由**: ★★どれもテキストの構造そのものであり、★経路で化けたものではない★★。
///
/// ★★ 走査する木と、★除いたもの（★★除外がそのまま穴になる★★ / **D-31**）★★
///
/// | ★何 | ★★理由と仮定★★ |
/// |---|---|
/// | ★**追跡されているファイル全部**（`git ls-files`） | ★★**配られるのはこれだけである**★★ |
/// | ★**除く 1: ★[binaryExtensions] の拡張子** | ★★**設計として非テキストである**★★（★画像 / ビルドの成果物） |
/// | ★**除く 2: ★[generatedPrefixes] のパス** | ★★**仮定: そこに★人が書いたファイルは 1 つも無い**★★（★`flutter test` が生成する。★★追跡されていること自体は★別の問題であり、★この検査の論点ではない★★） |
///
/// ★★**拡張子の分け方は★リポジトリから導いて突き合わせる**★★（**D-31** の受け）——
/// ★**非テキストとして挙げた拡張子が★★1 つも実在しなくなったら落ちる★★**ので、★★分け方が古くなったことに気づける★★。
///
/// ★★ 実測した対（★★21 通り / 2026-09-04★★ / ★`docs/tools/measure_pairs.py`）★★
///
/// ★**「0 件」を★★5 回踏み、★5 回とも 3 通りに当てた★★**（**D-27**）——
///
/// | ★仕込み | ★★原因★★ | ★処置 |
/// |---|---|---|
/// | ★**(K) 自己検査が別のファイルを見る** | ★★**(a) 対の形**★★ —— ★★指し先の別ファイルも綺麗なので通る★★ | ★**中身に印を要求した** |
/// | ★**(L) 走査が `controlByteOffsets` を呼ばない** | ★★**(a) 対の形**★★ —— ★★実物が 0 件なので「走査していない」と区別がつかない★★ | ★**[hitsIn] に切り出し、★★合成の入力で当てた★★**（★★同じ処置が 8 回目★★） |
/// | ★**(S) 本命が [hitsIn] を呼ばず★自分で回す** | ★★**守る対象が★振る舞いではなく★構造**★★（★出る値が 1 つも変わらない） | ★**ソースに呼び出しが在ることを見る走査を足した** |
/// | ★★**(S-2) 同（★走査を足したあと）**★★ | ★★**(c) 仕込みの弱さではない —— ★★走査が★自分自身に当たっていた★★**★★（★型は **D-30**） | ★**字面を★★2 つに割って組み立てた★★** |
/// | ★**(T) / (U) 走査そのものを弱める** | ★★**(乙) 守りが 1 つも無い**★★ | ★★**受けを置かない**★★（★下） |
///
/// ★★ (T) / (U) の 0 件は★手当てしない。★★受けを置かない★★ ★★
/// ★**走査を見張る走査は★★置かない★★**（★★入れ子は 1 段で止まる★★ / **D-10** の注記と同じ判断）。
/// ★★**測定を残したことは★受けではない**★★（**D-28** の 5 つ目の軸 —— ★★落ちる試験が 1 つも無い★★）。
///
/// ★★ この検査が覆わないもの（★★言い切る★★）★★
///
/// | # | ★何 | ★なぜ |
/// |---|---|---|
/// | ★**1** | ★★**逆斜線が★1 つに畳まれた形**★★ | ★**制御文字にならない**（★`dart analyze` とコンパイルが受ける —— ★2026-09-04 の 5 度目は★★12 件の指摘で出た★★） |
/// | ★**2** | ★**追跡されていないファイル** | ★**配られない**（★測定の仕込みは★戻される） |
/// | ★★**3**★★ | ★★**化ける★前★に止めること**★★ | ★**この検査は★★入ったあとに見つける★★**（★受けであって★予防ではない） |
///
/// ★★ 総合ルールの条番号は 1 つも引かない ★★
/// ★これはゲームの規則ではなく★★文書とソースの保守★★である。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

final _repoRoot = Directory('..');

/// ★★ 設計として非テキストの拡張子（★走査しない）★★
///
/// ★★**`dill` / `bin` / `Z` / `frag` は★挙げていない**★★ —— ★**実在するのは
/// ★★[generatedPrefixes] の木の中だけで、★そこは前置で除いてある★★**（★2026-09-04 実測）。
/// ★**挙げると★★実在しない拡張子を除外し続けることになる★★**（**D-31** —— ★★下の受けが落ちる★★）。
const binaryExtensions = <String>{'png', 'ico'};

/// ★★ 生成物の木（★走査しない / ★上の「除く 2」）★★
const generatedPrefixes = <String>['loveca-core/build/'];

/// ★★ 許可リスト —— ★★空で始める★★（**D115-6** の形）★★
///
/// ★**足すときは★★1 行 1 件で理由を書くこと★★。**
const allowedFiles = <String>{};

/// ★★ 制御文字と見ないバイト（★テキストの構造そのもの）★★
const _structural = <int>{9, 10, 13};

/// ★★ 制御文字の位置を返す（★本番も対も★この関数を通す / **D-27** の (甲)）★★
///
/// ★**返すのは★★全部である★★**（★最初の 1 件で止めない —— ★直す人が 1 度で直せる）。
List<int> controlByteOffsets(List<int> bytes) {
  final out = <int>[];
  for (var i = 0; i < bytes.length; i++) {
    final b = bytes[i];
    if (b == 0x7f || (b < 0x20 && !_structural.contains(b))) out.add(i);
  }
  return out;
}

/// ★区切りを POSIX に揃える（★**D-38** —— ★★逆斜線を 1 つも書かない★★）。
String _posix(String path) => path.replaceAll(String.fromCharCode(92), '/');

/// ★★ 拡張子（★★basename の最後の点より後ろ★★）★★
///
/// ★**点を持たない名前は★★空を返す★★**（★このリポジトリには今日 0 件 —— ★対で固定した）。
String extensionOf(String path) {
  final name = p.posix.basename(_posix(path));
  final dot = name.lastIndexOf('.');
  if (dot < 0) return '';
  return name.substring(dot + 1);
}

/// ★★ 走査した結果（★★純粋関数 —— ★本番も対も★ここを通る★★ / **D-27** の (甲)）★★
///
/// ★**戻すのは★★1 ファイル 1 行の文言★★**（★直す人が★どこを見ればよいか分かる形）。
List<String> hitsIn(Map<String, List<int>> files) {
  final out = <String>[];
  files.forEach((String path, List<int> bytes) {
    final offsets = controlByteOffsets(bytes);
    if (offsets.isEmpty) return;
    out.add('$path: ${offsets.length} 件（★最初は ${offsets.first} バイト目）');
  });
  return out;
}

/// ★★ 走査するか ★★
bool scans(String path) {
  final rel = _posix(path);
  if (allowedFiles.contains(rel)) return false;
  for (final prefix in generatedPrefixes) {
    if (rel.startsWith(prefix)) return false;
  }
  return !binaryExtensions.contains(extensionOf(rel));
}

/// ★★ 追跡されているファイルを読む ★★
List<String> _trackedFiles() {
  final nul = String.fromCharCode(0);
  final result = Process.runSync(
    'git',
    <String>['ls-files', '-z'],
    workingDirectory: _repoRoot.path,
    stdoutEncoding: const Utf8Codec(),
  );
  if (result.exitCode != 0) {
    throw StateError('git ls-files が失敗した: ${result.stderr}');
  }
  return (result.stdout as String)
      .split(nul)
      .where((String s) => s.isNotEmpty)
      .toList();
}

void main() {
  group('★★ 制御文字が 1 バイトも無い（**D-38** の受け）★★', () {
    late List<String> tracked;

    setUpAll(() {
      tracked = _trackedFiles();
    });

    test('★★ 前提: ★追跡されているファイルが★十分に在る（★空振り防止）★★', () {
      expect(tracked.length, greaterThan(100));
    });

    test('★★ 前提: ★どのファイルも拡張子を持つ（★点を持たない名前が 0 件）★★', () {
      final noExtension = tracked.where((f) => extensionOf(f).isEmpty).toList();
      expect(noExtension, isEmpty,
          reason: '★点を持たない名前が入った。★分け方を決め直すこと');
    });

    test('★★ **D-31** の受け: ★非テキストの分け方が★古くなっていない ★★', () {
      final found = <String>{};
      for (final f in tracked) {
        final rel = _posix(f);
        if (generatedPrefixes.any(rel.startsWith)) continue;
        found.add(extensionOf(rel));
      }
      // ★★ 挙げた拡張子が★1 つも実在しなくなったら★分け方が古い ★★
      final missing = binaryExtensions.difference(found);
      expect(missing, isEmpty,
          reason: '★実在しない拡張子を挙げている。★★除外がそのまま穴になる★★（**D-31**）');
    });

    test('★★ 走査した木に★制御文字が 1 バイトも無い ★★', () {
      final bytes = <String, List<int>>{};
      for (final f in tracked) {
        if (!scans(f)) continue;
        bytes[f] = File(p.join(_repoRoot.path, f)).readAsBytesSync();
      }
      expect(bytes.length, greaterThan(100),
          reason: '★走査したファイルが少なすぎる。★除外が広すぎる');
      expect(hitsIn(bytes), isEmpty,
          reason: '★制御文字が入った。★★字面を写さず、★語で書くこと★★（**D-38** の規約 (b)）');
    });

    test('★★ 対: ★合成の入力で★走査そのものが働く（**D-27** の (a) の受け）★★', () {
      // ★★ 実物の木は★今日 0 件なので、★★「走査していない」と区別がつかない★★ ★★
      //   ★**2026-09-04 に測った** —— ★`controlByteOffsets` の呼び出しを落としても★★0 件だった★★。
      final hits = hitsIn(<String, List<int>>{
        'a.md': <int>[65, 66],
        'b.md': <int>[65, 8, 66],
      });
      expect(hits, hasLength(1));
      expect(hits.single, startsWith('b.md: 1 件'));
    });

    test('★★ 陽性対照: ★制御文字を入れると当たる（**D-10**）★★', () {
      expect(controlByteOffsets(<int>[65, 8, 66]), <int>[1]);
    });

    test('★★ 対: ★タブ / 改行 / 復帰は当たらない ★★', () {
      expect(controlByteOffsets(<int>[9, 10, 13, 65]), isEmpty);
    });

    test('★★ 対: ★0x7F も当たる ★★', () {
      expect(controlByteOffsets(<int>[65, 0x7f]), <int>[1]);
    });

    test('★★ 対: ★1 件で止めず★全部返す ★★', () {
      expect(controlByteOffsets(<int>[0, 65, 1]), <int>[0, 2]);
    });

    test('★★ 対: ★除外は★パスの前置で効く（★名前では見ない）★★', () {
      expect(scans('loveca-core/build/x.frag'), isFalse);
      expect(scans('loveca-core/lib/build/x.dart'), isTrue,
          reason: '★名前で除くと★★見張りたい木まで一緒に見逃す★★（`CLAUDE.md` §3 と同じ型）');
    });

    test('★★ 対: ★非テキストの拡張子は走査しない ★★', () {
      expect(scans('loveca-ui/windows/runner/resources/app_icon.ico'), isFalse);
      expect(scans('CLAUDE.md'), isTrue);
    });

    test('★★ 許可リストは★空である（**D115-6** の形）★★', () {
      expect(allowedFiles, isEmpty,
          reason: '★足したなら★1 行 1 件で理由を書くこと');
    });

    test('★★ 対: ★この検査そのものが★制御文字を 1 バイトも持たない ★★', () {
      final self = File(p.join(
          _repoRoot.path, 'loveca-ui', 'test', 'docs', 'control_byte_test.dart'));
      expect(self.existsSync(), isTrue);
      final text = self.readAsStringSync();
      // ★★ 自分自身を読んでいることを★中身で確かめる ★★
      //   ★**パスだけ見ると★★別の綺麗なファイルを指しても通る★★**（★2026-09-04 に測った / **D-27**）。
      expect(text.contains('List<int> controlByteOffsets('), isTrue,
          reason: '★自分自身ではないファイルを読んでいる');
      // ★★ 本命が★合成の対と★同じ道を通ることを★構造で見る ★★
      //   ★**自分で回しても★出る値は 1 つも変わらない**（★2026-09-04 に測った ＝ ★★0 件★★ / ★仕込み (S)）。
      //   ★**守る対象が★★振る舞いではなく★構造である★★**（**D-27** —— ★対は走査でしか置けない）。
      //   ★★**この走査を見張る走査は★置かない。★受けを置かない**★★（★★入れ子は 1 段で止まる★★ /
      //   ★**D-10** の注記と同じ判断 —— ★★弱めれば (S) がまた 0 件になるが、★落ちる試験が 1 つも無い★★）。
      //   ★★**字面を 2 つに割って組み立てる**★★ —— ★**そのまま書くと
      //   ★★この行自身が当たって★何を壊しても通る★★**（★2026-09-04 に測った ＝ ★★0 件★★ /
      //   ★型は **D-30** —— ★★禁止対象を説明する行は★禁止対象と同じ字面を含む★★）。
      final callMarker = 'expect(hitsIn' '(bytes), isEmpty,';
      expect(text.contains(callMarker), isTrue,
          reason: '★本命が [hitsIn] を通っていない。★★合成の対が★本番を 1 度も通らなくなる★★');
      expect(controlByteOffsets(self.readAsBytesSync()), isEmpty);
    });
  });
}
