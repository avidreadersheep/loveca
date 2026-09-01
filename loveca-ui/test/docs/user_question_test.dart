/// ★★ `docs/利用者への問い.md` の★★写しが★正と食い違わないこと ★★
///
/// ★★ なぜ機械で見るか ★★
/// ★**あの文書は★問いの文言を★★写しとして持つ★★**（★正は `docs/同期設計メモ.md` の各節）。
/// ★**移さない理由は **D-35**** —— ★**あれらの節は「★その回に何を聞いたか」の記録でもあり、
/// ★★書いた時点では正しい★★。→ ★書き換えない。**
/// ★★**しかし写しは 2 か所目である。★食い違いうる**★★（**D-15** の規約 3）。
///
/// ★**受けは 2 つあり、★★これが本命である★★** ——
/// ★もう 1 つ（★「正はここ」と節番号を書く）は★★人の規律であり、★忘れられる★★
/// （`CLAUDE.md` §3 が **D-2** を前例として書いている）。
///
/// ★★ 見るのは★候補の行だけである。★背景は見ない ★★
/// ★**背景は★問いごとに言い換えられる**（★§7-8 の追記が「★背景をどの候補にも同じだけ書く」と
/// ★言っているのは★★中身の量であって字面ではない★★）。
/// ★**候補の行は★★選ばれたものを指す字面★★なので、★1 文字も動いてはならない。**
///
/// ★★ 「この文書自身が正である」節は★突き合わせない ★★
/// ★**「★問いの文言（★★この節が正である★★）」という見出しを持つ節は★突き合わせない。**
/// → ★★**除外を★別に書かない**★★ —— ★[_copiedHeading] が「★写し。★正は」を★★要求している★★ので、
/// ★あの見出しは★★そもそも当たらない★★。
/// ★★**「除外の判定」を別に置くと★★消費者の居ない判定になる**★★（★型は **D-20**）——
/// ★**最初はそう書いた。★★どの入力でも 1 度も効かないことが分かって外した★★。**
/// → ★**代わりに★「あの節が取り出されないこと」を★対で固定する**（★下の群）。
///
/// ★★ 2026-09-01（★第 3 セッション）: ★その形の節が★実物から 0 件になった ★★
/// ★**唯一の持ち主だった Q-05 は★★問い箱から外れた★★**
/// （★★決定であって問いではない★★ / **D133-9** / `docs/利用者への問い.md` の 1-0）。
/// → ★**対を★実物依存から★★合成の入力★★へ移した**（★型は **D-27** の (J)。★先例は「引用の外の表」）。
///
/// ★★ このファイルには★エスケープを 1 つも書かない（**D-38**）★★
/// ★**書こうとして★★実際に化けた★★**（★改行のエスケープが★道具の経路で★本物の改行になった）。
/// → ★**繋ぎの字は★エスケープを要らないものにしてある。**
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

final _questions = File(p.join('..', 'docs', '利用者への問い.md'));
final _source = File(p.join('..', 'docs', '同期設計メモ.md'));

/// ★「写し」の見出し。★★`正は` を含むものだけを拾う★★。
final _copiedHeading = RegExp(r'^#### ★ 問いの文言（★★写し。★正は .+★★）$');

/// ★引用の中の表の行（★`> | … | … |`）。
final _quotedRow = RegExp(r'^> (\|.*\|)$');

/// ★表の区切り行（★`|---|---|`）と見出し行は★候補ではない。
bool _isCandidateRow(String row) {
  if (RegExp(r'^\|[\s\-|]*\|$').hasMatch(row)) return false;
  if (row.startsWith('| # |')) return false;
  return true;
}

/// 「写し」の節ごとに、★候補の行を取り出す。
Map<String, List<String>> _copiedRows(List<String> lines) {
  final out = <String, List<String>>{};
  String? current;
  for (final line in lines) {
    if (_copiedHeading.hasMatch(line)) {
      current = line;
      out[current] = <String>[];
      continue;
    }
    if (line.startsWith('#')) {
      current = null;
      continue;
    }
    if (current == null) continue;
    final m = _quotedRow.firstMatch(line);
    if (m == null) continue;
    final row = m.group(1)!;
    if (_isCandidateRow(row)) out[current]!.add(row);
  }
  return out;
}

/// ★正の側に無い候補を返す（★★本番も対も★この関数を通す★★ / **D-27**）。
///
/// ★★ 直に `contains` を呼ぶ対を書かないこと ★★
/// ★**本番の突き合わせが★空振りしていても、★★対の側で直に呼べば★対は通る★★**
/// （★測って分かった —— ★**「突き合わせを常に真にする」の仕込みが★★0 件だった★★**）。
List<String> _missingRows(Map<String, List<String>> copied, String source) {
  final missing = <String>[];
  copied.forEach((heading, rows) {
    for (final row in rows) {
      if (!source.contains(row)) missing.add('$heading ＞ $row');
    }
  });
  return missing;
}

void main() {
  late String questionText;
  late String sourceText;
  late Map<String, List<String>> copied;

  setUpAll(() {
    questionText = _questions.readAsStringSync();
    sourceText = _source.readAsStringSync();
    copied = _copiedRows(const LineSplitter().convert(questionText));
  });

  group('★★ 陽性対照 —— ★取り出しが働くこと（**D-10**）★★', () {
    test('★ 台帳が 2 つとも読める', () {
      expect(_questions.existsSync(), isTrue);
      expect(_source.existsSync(), isTrue);
    });

    test('★★ 「写し」の節が 1 つ以上見つかる（★0 件なら見出しの字面が動いている）★★', () {
      expect(copied, isNotEmpty,
          reason: '★見出しの字面（`#### ★ 問いの文言（★★写し。★正は …★★）`）が動いた');
    });

    test('★★ どの節も★候補の行を 1 つ以上持つ ★★', () {
      for (final entry in copied.entries) {
        expect(entry.value, isNotEmpty, reason: '★候補が 0 件: ${entry.key}');
      }
    });

    test('★★ 1 文字変えると★当たらない（★突き合わせが働いていること）★★', () {
      // ★★ 本番と★同じ関数を通す（★[_missingRows] の doc）★★
      final row = copied.values.first.first;
      expect(
        _missingRows(<String, List<String>>{
          '仮': <String>[row],
        }, sourceText),
        isEmpty,
        reason: '★素のままなら当たる',
      );
      expect(
        _missingRows(<String, List<String>>{
          '仮': <String>['$row★★★これは在ってはならない'],
        }, sourceText),
        isNotEmpty,
      );
    });

    test('★★ 「この節が正である」の節は★取り出さない（★合成の入力で見る / D-27）★★', () {
      // ★★ 実物にこの形が★もう 1 つも無い（2026-09-01 / ★第 3 セッション）★★
      //   ★**旧 Q-05 が★唯一の持ち主だった。★★問い箱から外した★★**
      //   （★★決定である。★問いではない★★ / **D133-9** / `docs/利用者への問い.md` の 1-0）。
      //   ★**実物だけで測ると、★★この判定に対が 1 つも付かない★★**（★型は **D-27** の (J)）。
      //   → ★**合成の入力で固定する**（★先例は★下の「引用の外の表」）。
      final rows = _copiedRows(const <String>[
        '#### ★ 問いの文言（★★この節が正である★★）',
        '> | ★これは取り出してはならない |',
        '#### ★ 問いの文言（★★写し。★正は §9 の **X**★★）',
        '> | ★これは取り出す |',
      ]);

      // ★★ 取り出したのは★「写し」の節★だけである ★★
      expect(rows, hasLength(1));
      expect(rows.keys.single.contains('この節が正である'), isFalse);
      expect(rows.values.single, <String>['| ★これは取り出す |']);
    });
  });

  group('★★ 写しは★正と 1 文字も違わない ★★', () {
    test('★★ 候補の行がすべて `docs/同期設計メモ.md` に★字面のまま在る ★★', () {
      expect(_missingRows(copied, sourceText), isEmpty,
          reason: '★写しが正と食い違っている（★正を採ること / **D-15**）');
    });
  });

  group('★★ 取り出しの形（★合成の入力で見る）★★', () {
    test('★★ 引用の外の表は★拾わない ★★', () {
      // ★★ 実物にはこの形が今日 1 つも無い ★★
      //   ★**実物だけで測ると、★★引用を要求する判定に★対が 1 つも付かない★★**
      //   （★測って分かった / **D-27**）。→ ★**合成の入力で固定する。**
      final rows = _copiedRows(const <String>[
        '#### ★ 問いの文言（★★写し。★正は §9 の **X**★★）',
        '',
        '| ★これは引用の外の行である |',
        '> | ★これは引用の中の行である |',
      ]);

      expect(rows.values.single, <String>['| ★これは引用の中の行である |']);
    });

    test('★★ 見出しが変われば★そこで区切れる ★★', () {
      final rows = _copiedRows(const <String>[
        '#### ★ 問いの文言（★★写し。★正は §9 の **X**★★）',
        '> | ★中に在る |',
        '### ★★ Q-99. 別の問い ★★',
        '> | ★外に在る |',
      ]);

      expect(rows.values.single, <String>['| ★中に在る |']);
    });
  });

  group('★★ この文書が★正であるもの（★3 つ）を★どの問いも持つ ★★', () {
    /// ★`### ★★ Q-NN. …` の節を取り出す。
    List<String> sectionsOf(String text) {
      final out = <String>[];
      for (final part in text.split(RegExp(r'^### ', multiLine: true)).skip(1)) {
        if (part.startsWith('★★ Q-')) out.add(part);
      }
      return out;
    }

    test('★★ 問いの節が 1 つ以上見つかる（★陽性対照）★★', () {
      expect(sectionsOf(questionText), isNotEmpty);
    });

    test('★★ どの問いも「止まるもの」「止まらないもの」「既定値」「差し替え点」を持つ ★★', () {
      for (final section in sectionsOf(questionText)) {
        final name = const LineSplitter().convert(section).first;
        for (final required in const <String>[
          '止まるもの',
          '止まらないもの',
          '既定値',
          '差し替え点',
          '違っていたら何が崩れるか',
        ]) {
          expect(section.contains(required), isTrue,
              reason: '★$name に「$required」が無い');
        }
      }
    });
  });
}
