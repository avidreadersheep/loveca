/// デッキの衝突判定 —— 候補 L（決定 **D111-2** / `lib/src/sync/deck_conflict.dart`）.
///
/// ★★ この版で固定するのは「判定」だけである ★★
/// 解決（**(f-2)** / 決着層）も送信も器も無い。
/// → ★**それらを固定するテストを書かない。**書くと決めたことになる。
///
/// ★★ 「決めていないこと」を型で決めないための対も置く ★★
/// (1) ★**器の行が無い**とき、この関数は「何をするか」を答えない（**D114-3** / 門 カ）/
/// (2) ★**論理削除だけが起きた側**は落とされ、★その事実が 1 ビットとして外へ出る
///     （**D116-12** —— ★★削除の扱いはここで決めない★★）/
/// (3) ★**両側が同じ内容へ変わった**場合は衝突のままである（★L の定義どおり）。
library;

import 'package:loveca_core/loveca_core.dart';
import 'package:test/test.dart';

const _base = 'sha256:0000000000000000000000000000000000000000000000000000000000000000';
const _localMoved = 'sha256:1111111111111111111111111111111111111111111111111111111111111111';
const _remoteMoved = 'sha256:2222222222222222222222222222222222222222222222222222222222222222';

DeckConflictJudgement _judge({
  required bool hasOps,
  required String local,
  required String remote,
}) =>
    judgeDeckConflict(
      baseline: (hasOpsSinceMark: hasOps, contentHash: _base),
      localContentHash: local,
      remoteContentHash: remote,
    );

void main() {
  group('★★ 器の行が無い ＝ まだ一度も同期していない（決定 D114-3）★★', () {
    test('★ 内容が何であっても neverSynced である', () {
      // ★★ 基準が無いので変化を測れない ★★
      //   ★「何をするか」は初回同期の設計（★門 カ）が決める。
      //   ★この関数はそこへ進まない。
      for (final pair in [
        (_base, _base),
        (_localMoved, _base),
        (_base, _remoteMoved),
        (_localMoved, _remoteMoved),
      ]) {
        final r = judgeDeckConflict(
          baseline: null,
          localContentHash: pair.$1,
          remoteContentHash: pair.$2,
        );
        expect(r.verdict, DeckConflictVerdict.neverSynced);
        expect(r.droppedLocalOpsByContent, isFalse);
      }
    });

    test('★★ 対: 行が在れば neverSynced にならない（★これが無いと常に null 扱いでも通る）★★',
        () {
      // ★★ D-10 —— 0 件は「無い」と「見えていない」の区別がつかない ★★
      final r = _judge(hasOps: false, local: _base, remote: _base);
      expect(r.verdict, isNot(DeckConflictVerdict.neverSynced));
    });
  });

  group('★★ G の段 —— 目印より後ろの操作の有無 ★★', () {
    test('操作が 1 件も無ければ、内容が動いていても自分側は変わっていない扱い', () {
      // ★候補 G / L の定義そのものである（§18-2-4）。
      //   ★保存を通らずに内容だけが動く経路は今日 0 本だが、
      //   ★**定義を型で崩さない**ために固定する。
      final r = _judge(hasOps: false, local: _localMoved, remote: _base);
      expect(r.verdict, DeckConflictVerdict.unchanged);
      expect(r.droppedLocalOpsByContent, isFalse);
    });

    test('★ 対: 操作が在って内容も動けば localOnly になる', () {
      final r = _judge(hasOps: true, local: _localMoved, remote: _base);
      expect(r.verdict, DeckConflictVerdict.localOnly);
      expect(r.droppedLocalOpsByContent, isFalse);
    });
  });

  group('★★ L の段 —— 内容が基準と一致するものを落とす ★★', () {
    test('★★ 操作は在るが内容が基準と同じなら、自分側は変わっていない ★★', () {
      // ★★ G の空振りそのものである（§19-3）★★
      //   ★「保存を挟んで変えて戻す」と操作は 2 件残るが内容は基準に戻る。
      //   ★**候補 G はここで衝突と言う。★L は落とす。**
      final r = _judge(hasOps: true, local: _base, remote: _base);
      expect(r.verdict, DeckConflictVerdict.unchanged);
      expect(r.droppedLocalOpsByContent, isTrue);
    });

    test('★★ 落とした事実は 1 ビットとして外へ出る ★★', () {
      // ★★ ここを捨てると「操作が 1 件も無い」と「L が落とした」が区別できない ★★
      final dropped = _judge(hasOps: true, local: _base, remote: _base);
      final noOps = _judge(hasOps: false, local: _base, remote: _base);

      expect(dropped.verdict, noOps.verdict, reason: '★判定は同じである');
      expect(dropped.droppedLocalOpsByContent, isTrue);
      expect(noOps.droppedLocalOpsByContent, isFalse);
    });

    test('★★ 相手が動いていても落とす（★L は自分側の空振りを落とす）★★', () {
      final r = _judge(hasOps: true, local: _base, remote: _remoteMoved);
      expect(r.verdict, DeckConflictVerdict.remoteOnly,
          reason: '★落とさないと衝突になる = 候補 G のままである');
      expect(r.droppedLocalOpsByContent, isTrue);
    });
  });

  group('★★ 相手側は内容ハッシュだけで見る（決定 D124-7 ＝ (c)）★★', () {
    test('相手が動いていれば remoteOnly', () {
      final r = _judge(hasOps: false, local: _base, remote: _remoteMoved);
      expect(r.verdict, DeckConflictVerdict.remoteOnly);
    });

    test('★ 対: 相手が動いていなければ remoteOnly にならない', () {
      final r = _judge(hasOps: false, local: _base, remote: _base);
      expect(r.verdict, DeckConflictVerdict.unchanged);
    });

    test('★★ 相手側は「操作の有無」に一切影響されない ★★', () {
      // ★★ 器に相手側の列は 1 つも無い（**D124-7**）★★
      //   ★引数にも無いことを、★同じ相手ハッシュで両方の有無を当てて確かめる。
      final withOps = _judge(hasOps: true, local: _base, remote: _remoteMoved);
      final withoutOps =
          _judge(hasOps: false, local: _base, remote: _remoteMoved);
      expect(withOps.verdict, DeckConflictVerdict.remoteOnly);
      expect(withoutOps.verdict, DeckConflictVerdict.remoteOnly);
    });
  });

  group('★★ 衝突 —— 両側が基準から変わった ★★', () {
    test('★ 別の内容へ変わっていれば conflict', () {
      final r = _judge(hasOps: true, local: _localMoved, remote: _remoteMoved);
      expect(r.verdict, DeckConflictVerdict.conflict);
      expect(r.droppedLocalOpsByContent, isFalse);
    });

    test('★★ 両側が同じ内容へ変わっても conflict のままである ★★', () {
      // ★★ 候補 L の定義どおりである。★特別扱いを足していない ★★
      //   ★L が落とすのは「★基準と一致するもの」であって
      //   ★「両側が一致するもの」ではない（§18-2-4 / §19-3）。
      //   ★**足すと (f-1) を開き直すことになる。★していない。**
      //   ★解決は空振りになるが害は無い（粒-1 はどちらを採っても同じ内容 / **D112-1**）。
      final r = _judge(hasOps: true, local: _localMoved, remote: _localMoved);
      expect(r.verdict, DeckConflictVerdict.conflict);
    });
  });

  group('★★ 論理削除はここに現れない（決定 D116-12）★★', () {
    // ★★ これは欠陥ではなく **D111-4** の帰結である ★★
    //   `deletedAt` は内容ハッシュの 5 フィールドに入っていないので、
    //   ★**削除しても内容ハッシュは 1 ビットも変わらない。**
    //   ★削除を見る手段はログ 1 つだけである（**D116-12**）。

    /// ★実物で作る —— 「削除しても内容ハッシュが変わらない」ことを
    /// ★**この群自身が確かめてから**判定に流す（★仮定を借りてこない）。
    final deck = Deck(
      deckId: 'deck-conflict-delete',
      name: 'けす',
      entries: const [DeckEntry(printingId: 'AB', count: 1)],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final deleted = deck.copyWith(deletedAt: DateTime.utc(2026, 9, 1));

    test('★前提: 論理削除しても内容ハッシュは変わらない', () {
      expect(deckContentHash(deleted), deckContentHash(deck));
    });

    test('★★ 削除だけが起きた側は「変わっていない」と出て、★落とされた 1 ビットが立つ ★★',
        () {
      // ★★ この 1 件がこの群の要石である ★★
      //   ★**候補 L は削除を見ない。**★見る手段はログの `kind` であって、
      //   ★この関数に渡っているのは有無だけである。
      //   ★**扱いをここで決めない**（★足すと (f-1) を開き直す）。
      //   → ★送信の側（コミット 23）が決めてから扱う。
      final r = judgeDeckConflict(
        baseline: (
          hasOpsSinceMark: true, // ★`softDelete` がログに 1 件残す（**D110-3**）
          contentHash: deckContentHash(deck),
        ),
        localContentHash: deckContentHash(deleted),
        remoteContentHash: deckContentHash(deck),
      );

      expect(r.verdict, DeckConflictVerdict.unchanged);
      expect(r.droppedLocalOpsByContent, isTrue,
          reason: '★ここが false になると、削除が痕跡なく消える');
    });
  });

  group('★ 4 通りの組み合わせを 1 つ残らず当てる', () {
    test('★ 表として並べる（★抜けが無いことを見る）', () {
      final table = <(bool, String, String, DeckConflictVerdict)>[
        (false, _base, _base, DeckConflictVerdict.unchanged),
        (true, _base, _base, DeckConflictVerdict.unchanged),
        (false, _localMoved, _base, DeckConflictVerdict.unchanged),
        (true, _localMoved, _base, DeckConflictVerdict.localOnly),
        (false, _base, _remoteMoved, DeckConflictVerdict.remoteOnly),
        (true, _base, _remoteMoved, DeckConflictVerdict.remoteOnly),
        (false, _localMoved, _remoteMoved, DeckConflictVerdict.remoteOnly),
        (true, _localMoved, _remoteMoved, DeckConflictVerdict.conflict),
      ];
      for (final row in table) {
        expect(
          _judge(hasOps: row.$1, local: row.$2, remote: row.$3).verdict,
          row.$4,
          reason: '★ops=${row.$1} local=${row.$2 == _base ? "基準" : "動いた"} '
              'remote=${row.$3 == _base ? "基準" : "動いた"}',
        );
      }
      expect(table, hasLength(8), reason: '★2 x 2 x 2 を 1 つ残らず並べる');
    });
  });
}
