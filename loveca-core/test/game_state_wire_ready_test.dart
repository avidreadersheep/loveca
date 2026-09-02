/// ★★ 盤面の状態は★★1 つ残らずデータである★★（**W-32** の前提 / `docs/同期設計メモ.md` §91）★★
///
/// ★★ これは「配る形」ではない。★★配る形が書ける前提★★である ★★
/// ★**`loveca-core/lib/src/game/` に `toJson` は★★今日 0 件である★★**（★§56-8 の 1 / ★走査）。
/// ★**足していない。★★何を運ぶかが決まっていない★★**（★§91 —— ★状態そのもの / ★操作の列 ＋ 種 / ★両方）。
///
/// ★★ では何を守るのか ★★
/// ★**どの候補で運ぶにせよ、★★データでなければ運べない★★。**
/// ★**いま `GameState` の下に在る欄は★★1 つ残らずデータである★★**（★2026-09-02 実測）——
///   ★関数の型も、★注入される抽象（`DeterministicRng`）も、★IO も★1 つも無い。
/// ★**この事実は★§56-8 の 1 が★★記録しただけで★守りを 1 つも持っていなかった★★。**
/// → ★**破れても★★何も落ちない★★**（★型は **D-20** / **D-32** の列 —— ★★痕跡を残さず難しくなる★★）。
///
/// ★★ 好みが 0 である ★★
/// ★**鍵の字面も、★入れ子の形も、★版の印も★1 つも決めていない**（★それらは **W-32** 本体である）。
/// ★**見るのは★★欄の型だけ★★である。**
///
/// ★★ 増えたら落ちる。★それが合図である ★★
/// ★**新しい型の欄を足した人は、★★それがデータかどうかを宣言することになる★★**
///   （★先例は `loveca-ui/test/docs/package_boundary_test.dart` の許可リスト / **D-15** ——
///    ★★数を書くなら機械が数えられる形にする★★）。
///
/// ★★ 運-2 が選ばれても★この制約は無駄にならない（2026-09-02 に確かめた）★★
///
/// ★**問い**（★相談役）—— 「★★運-2（★操作の列 ＋ 種で再生する）が選ばれた場合、
///   ★この制約は★★何のために残るか★★」。
///
/// ★★**答え: ★`redact` の口が★★配るものを★既に決めている★★**★★ ——
/// ★`lib/src/game/redact.dart` の doc（★実読）:
///   > ★**権威サーバは完全な `GameState` を保持し、各クライアントへは
///   >   `redact(state, viewerId)` の結果★★だけ★★を配る。**
/// ★**`CLAUDE.md` §8 のモードの表も同じことを書く**（★「サーバが `redact` を掛けて配る」）。
/// → ★★**下りに載るのは★★`GameState` である★★。★運-N が決めるのは★★上りの形だけである★★。**
///
/// ★★ したがって運-2 でも★`GameState` は線に載る ★★
/// ★**上りを操作の列にしても、★★下りを操作の列にはできない★★** ——
///   ★**種を配れば★★相手の手札と山札の順が全部割れる★★**（★4.8.2 / 4.11.2 / ★`redact` の表）。
/// ★★**「配らずに再生させる」形は★★秘匿の語彙を新しく作ることになる★★**
///   （★「誰かが 1 枚引いた」を★★中身抜きで運ぶ操作★★）。★**そんな語彙は今日 1 つも無い**（★走査した）。
///
/// ★★ 開き直す条件（★★隠さない★★）★★
/// ★**上の秘匿の語彙を作るなら、★★`redact.dart` の doc が述べた設計を開き直すことになる★★**
///   （★★訂正であって★この試験の問題ではない★★ / **D-15 (l)** の型）。
/// → ★**そのときは★この試験を★★消してよい条件★★に当てること**（**D-27** の 3 つ目の追記）。
///
/// ★★ 覆っているのは `game/` 全部ではない ★★
/// ★**見るのは★★`GameState` の欄から辿れる 5 ファイルだけ★★である**（★下の `_stateFiles`）。
/// ★`game/` の 19 ファイルのうち★★15 は★1 つも見ていない★★（★`reduce` も `redact` も `step_engine` も / ★2026-09-02 実測）。
///
/// ★★ 総合ルールの条番号は 1 つも引かない ★★
/// ★これはゲームの規則ではなく**運べるかどうか**である。
library;

import 'dart:io';

import 'package:test/test.dart';

/// ★★ 状態の閉包 —— `GameState` の欄から辿れるファイル ★★
///
/// ★**`RuleConfig` が `entities/deck.dart` に同居している**（★§90-3 の実測）ので、
///   ★★そのファイルも入る★★。★**`Deck` / `DeckEntry` の欄も一緒に見ることになるが、
///   ★★どちらもデータである★★**ので★この群の答えは変わらない。
const _stateFiles = <String>[
  'lib/src/game/game_state.dart',
  'lib/src/game/card_instance.dart',
  'lib/src/game/member_area.dart',
  'lib/src/game/step.dart',
  'lib/src/entities/deck.dart',
];

/// ★★ データとして認める型 —— ★★増やすときは理由を書くこと★★ ★★
///
/// | 種類 | ★中身 |
/// |---|---|
/// | ★**素の値** | `String` / `int` / `bool` / `double` |
/// | ★**日時** | `DateTime`（★**値として持つのは可** / `CLAUDE.md` §1 —— ★禁じているのは `DateTime.now()`） |
/// | ★**列挙** | `CardOrientation` / `FaceState` / `MemberAreaSlot` / `PhaseId` / `StepId` / `StepDecision` |
/// | ★**値の組** | `CardInstance` / `MemberStack` / `MemberArea` / `PlayerState` / `StepCursor` / `LiveJudgementRecord` / `RuleConfig` / `DeckEntry` |
const _dataTypes = <String>{
  'String',
  'int',
  'bool',
  'double',
  'DateTime',
  'CardOrientation',
  'FaceState',
  'MemberAreaSlot',
  'PhaseId',
  'StepId',
  'StepDecision',
  'CardInstance',
  'MemberStack',
  'MemberArea',
  'PlayerState',
  'StepCursor',
  'LiveJudgementRecord',
  'RuleConfig',
  'DeckEntry',
};

/// ★入れ物として認める形。★中身は [_dataTypes] でなければならない。
const _containers = <String>{'List', 'Set', 'Map'};

final _fieldPattern =
    RegExp(r'^[ \t]*final[ \t]+([^;=]+?)[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]*;',
        multiLine: true);

/// ★doc コメントを落とす（★**D-30** —— ★doc の中の字面を拾わない）。
String stripDocComments(String source) =>
    source.replaceAll(RegExp(r'^[ \t]*///.*$', multiLine: true), '');

/// ★[source] の `final` の欄を「型 → 名前」で返す。★★分類器そのもの★★。
List<({String type, String name})> fieldsOf(String source) => _fieldPattern
    .allMatches(stripDocComments(source))
    .map((m) => (type: m.group(1)!.trim(), name: m.group(2)!))
    .toList();

/// ★[type] がデータか。★★入れ物は 1 段だけ剥がす★★（★実物に 2 段が 1 つも無い / ★対で固定した）。
bool isDataType(String type) {
  var t = type.trim();
  if (t.endsWith('?')) t = t.substring(0, t.length - 1).trim();
  final generic = RegExp(r'^([A-Za-z_][A-Za-z0-9_]*)<(.+)>$').firstMatch(t);
  if (generic != null) {
    if (!_containers.contains(generic.group(1))) return false;
    return generic
        .group(2)!
        .split(',')
        .every((inner) => _dataTypes.contains(inner.trim()));
  }
  return _dataTypes.contains(t);
}

void main() {
  group('★★ 走査の根（★★綴りの受け / D-10★★）★★', () {
    test('★ 5 つとも実在する', () {
      for (final path in _stateFiles) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });

    test('★★ 根は★値の組を宣言するファイルを★1 つ残らず覆う（★**D-31** の受け）★★', () {
      // ★★ 根を手で足す規約に頼らない ★★
      //   ★**許可リストに在る「値の組」が★★根の外で宣言されていたら、
      //     ★その欄は 1 度も見られない★★**（★根から 1 つ外すだけで★静かに範囲外になる）。
      const valueClasses = <String>[
        'CardInstance',
        'MemberStack',
        'MemberArea',
        'PlayerState',
        'StepCursor',
        'LiveJudgementRecord',
        'RuleConfig',
        'DeckEntry',
      ];
      final declaredIn = <String, String>{};
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = stripDocComments(entity.readAsStringSync());
        for (final name in valueClasses) {
          if (RegExp('class $name[^A-Za-z0-9_]').hasMatch(source)) {
            declaredIn[name] = entity.path.replaceAll(String.fromCharCode(92), '/');
          }
        }
      }

      expect(declaredIn.keys.toSet(), valueClasses.toSet(),
          reason: '★★宣言が見つからない値の組が在る（★改名したか、★許可リストが古い）★★');
      for (final entry in declaredIn.entries) {
        expect(_stateFiles, contains(entry.value),
            reason: '★★${entry.key} を宣言する ${entry.value} が★根に入っていない★★');
      }
    });

    test('★★ 欄を★実際に見つけている（★★0 件が「無い」ではない★★）★★', () {
      var total = 0;
      for (final path in _stateFiles) {
        total += fieldsOf(File(path).readAsStringSync()).length;
      }

      expect(total, greaterThan(50),
          reason: '★★正規表現が空振りしていれば★下の 0 件は何も証明しない★★');
    });
  });

  group('★★ 状態の欄は★1 つ残らずデータである（**W-32** の前提）★★', () {
    test('★★ データでない欄が 1 つも無い ★★', () {
      final bad = <String>[];
      for (final path in _stateFiles) {
        for (final field in fieldsOf(File(path).readAsStringSync())) {
          if (!isDataType(field.type)) {
            bad.add('$path: ${field.type} ${field.name}');
          }
        }
      }

      expect(bad, isEmpty,
          reason: '★★足した型がデータかどうかを宣言すること'
              '（★データなら許可リストへ / ★でなければ★★配る形が書けなくなる★★）★★');
    });
  });

  group('★★ 分類器が当たること（★これが無いと上の 0 件は何も証明しない / D-10）★★', () {
    test('★★ 関数の型は★データではない ★★', () {
      expect(isDataType('void Function()'), isFalse);
      expect(isDataType('int Function(String)'), isFalse);
    });

    test('★★ 注入される抽象は★データではない（`DeterministicRng`）★★', () {
      // ★★ これが入ると★状態が★★再現できなくなる★★（`CLAUDE.md` §1 の乱数の断り）★★
      expect(isDataType('DeterministicRng'), isFalse);
      expect(isDataType('List<DeterministicRng>'), isFalse);
    });

    test('★ 素の値と列挙はデータである', () {
      expect(isDataType('String'), isTrue);
      expect(isDataType('int'), isTrue);
      expect(isDataType('StepId?'), isTrue);
      expect(isDataType('List<CardInstance>'), isTrue);
      expect(isDataType('Set<String>'), isTrue);
    });

    test('★★ 知らない入れ物は★データではない（★字面を広げない / D-37 の裏）★★', () {
      expect(isDataType('Future<String>'), isFalse);
      expect(isDataType('Stream<int>'), isFalse);
    });

    test('★★ 合成の入力で★実際に捕まえる（★陽性対照）★★', () {
      const source = 'class X {\n  final void Function() onTick;\n}';

      final found = fieldsOf(source);

      expect(found, hasLength(1));
      expect(isDataType(found.single.type), isFalse);
    });

    test('★★ doc の行は★型の走査に当たらない（★★2 段で守っている★★）★★', () {
      // ★★ 1 段目: ★正規表現が★行頭の空白しか許さない ★★
      //   ★**`///` は空白ではない**ので、★doc の行は★★そもそも当たらない★★。
      // ★★ 2 段目: ★[stripDocComments] が★先に落とす ★★
      //   ★**下の群が★★そちらに対を持つ★★**（★この群は 1 段目だけを見る）。
      final lines = <String>[
        '/// ★doc の写し: final void Function() onTick;',
        '  final int turnNumber;',
      ];

      final found = fieldsOf(lines.join(String.fromCharCode(10)));

      expect(found.map((f) => f.name), ['turnNumber']);
    });

    test('★★ doc の中の `toJson` は★落ちる（★★D-30★★ / ★合成の入力）★★', () {
      // ★★ 引き金: ★[stripDocComments] を恒等にしても★1 件も落ちなかった ★★
      //   （★2026-09-02 実測 / ★0 件）—— ★**原因は★★対の形★★である。**
      //   ★**今日の `game/` には★doc の中に `toJson` の字面が 1 つも無い**ので、
      //     ★★コメント外しに★見る相手が無かった★★。
      //   ★**先例は §63-7 の (J) / §76-4 の (T) / §80-6 の (L) / §90 の (E)**。
      final lines = <String>[
        '/// ★doc の写し: `toJson` を足すのは **W-32** である。',
        'class X {}',
      ];
      final src = lines.join(String.fromCharCode(10));

      // ★★ 外さなければ★doc の写しに当たる ＝ ★守りが働いている証拠 ★★
      expect(src.contains('toJson'), isTrue);
      // ★★ 外せば★当たらない ★★
      expect(stripDocComments(src).contains('toJson'), isFalse);
    });
  });

  group('★★ 配る形は★1 つも書いていない（★**W-32** は開いたままである）★★', () {
    test('★★ `lib/src/game/` に `toJson` が 1 件も無い ★★', () {
      final hits = <String>[];
      for (final entity
          in Directory('lib/src/game').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = stripDocComments(entity.readAsStringSync());
        if (source.contains('toJson') || source.contains('fromJson')) {
          hits.add(entity.path);
        }
      }

      expect(hits, isEmpty,
          reason: '★★足すのは **W-32** である。'
              '★何を運ぶかが決まってから書くこと（§91）★★');
    });

    test('★★ 対: ★同じ走査は★`entities/deck.dart` では当たる（★陽性対照）★★', () {
      final source =
          stripDocComments(File('lib/src/entities/deck.dart').readAsStringSync());

      expect(source.contains('toJson'), isTrue);
    });
  });
}
