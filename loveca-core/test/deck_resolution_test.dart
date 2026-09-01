/// デッキの衝突解決 —— §32-6 の **14**（決定 **D108-2** / **D112-1** / **D138-1**）.
///
/// ★★ この版で固定するのは「解決」だけである ★★
/// ★**判定**（`deck_conflict.dart`）も★**送信**（コミット 23）も★
/// **起きたことを残す値**（コミット 15 / 後-1）も無い。
/// → ★**それらを固定するテストを書かない。**★書くと決めたことになる。
///
/// ★★ 「決めていないこと」を型で決めないための対も置く ★★
/// (1) ★**削除（`deletedAt`）を特別扱いしない**（**D112-1** の 粒-1 を開き直さない）/
/// (2) ★**判定を呼ばない**（★器も目印も引数に無い）/
/// (3) ★**マージしない**（★出力は★★入力の片方そのもの★★）。
library;

import 'package:loveca_core/loveca_core.dart';
import 'package:test/test.dart';

Deck _deck({
  required String name,
  required DateTime updatedAt,
  int revision = 1,
  String lastDeviceId = 'device-1',
  DateTime? deletedAt,
  List<DeckEntry> entries = const [
    DeckEntry(printingId: 'PL!N-bp1-034-PE', count: 4),
  ],
}) =>
    Deck(
      deckId: 'deck-resolution',
      name: name,
      entries: entries,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      revision: revision,
      lastDeviceId: lastDeviceId,
    );

/// ★2 つの名前のうち、★★内容ハッシュの字面が大きいほう★★を返す（★期待値を★計算で作る）。
///
/// ★★ 期待値を手で書かない ★★
/// ★**16 進の並びは★中身と無関係である**（**D138-2**）。★手で書くと★★実装の写しになる★★。
String _largerHashName(Deck a, Deck b) =>
    deckContentHash(a).compareTo(deckContentHash(b)) > 0 ? a.name : b.name;

void main() {
  final early = DateTime.utc(2026, 5, 1, 12, 0, 0);
  final late_ = DateTime.utc(2026, 5, 1, 12, 0, 1);

  group('★★ 段 1 —— `updatedAt` の新しいほうが勝つ（決定 D108-2）★★', () {
    test('★ 手元が新しければ手元が勝つ', () {
      final local = _deck(name: 'てもと', updatedAt: late_);
      final remote = _deck(name: 'あいて', updatedAt: early);

      final got = resolveDeckConflict(local: local, remote: remote);

      expect(got.side, DeckResolutionWinner.local);
      expect(got.reason, DeckResolutionReason.updatedAt);
      expect(got.winner.name, 'てもと');
    });

    test('★ 対: 受け取った版が新しければそちらが勝つ', () {
      final local = _deck(name: 'てもと', updatedAt: early);
      final remote = _deck(name: 'あいて', updatedAt: late_);

      final got = resolveDeckConflict(local: local, remote: remote);

      expect(got.side, DeckResolutionWinner.remote);
      expect(got.reason, DeckResolutionReason.updatedAt);
      expect(got.winner.name, 'あいて');
    });

    test('★★ 段 1 で決まったら★内容ハッシュを見ない ★★', () {
      // ★★ これが「段が 2 つである」ことの対である ★★
      //   ★**内容ハッシュの字面で負ける側を★時刻で勝たせる。**
      //   ★段 2 が先に効いていれば、この 1 件が落ちる。
      final a = _deck(name: 'あ', updatedAt: late_);
      final b = _deck(name: 'い', updatedAt: early);
      final loserByHash = _largerHashName(a, b) == a.name ? b : a;

      // ★時刻の新しいほうを★ハッシュで負ける側にする。
      final local = _deck(name: loserByHash.name, updatedAt: late_);
      final remote =
          _deck(name: loserByHash.name == 'あ' ? 'い' : 'あ', updatedAt: early);
      expect(deckContentHash(local).compareTo(deckContentHash(remote)),
          lessThan(0),
          reason: '★前提: 手元は★ハッシュでは負ける側である');

      final got = resolveDeckConflict(local: local, remote: remote);

      expect(got.side, DeckResolutionWinner.local);
      expect(got.reason, DeckResolutionReason.updatedAt);
    });
  });

  group('★★ 段 2 —— 同値なら内容ハッシュの字面で決める（決定 D138-1）★★', () {
    test('★★ 字面の大きいほうが勝つ（★向きは好み / D138-2）★★', () {
      final local = _deck(name: 'あ', updatedAt: early);
      final remote = _deck(name: 'い', updatedAt: early);

      final got = resolveDeckConflict(local: local, remote: remote);

      expect(got.reason, DeckResolutionReason.contentHashTieBreak);
      expect(got.winner.name, _largerHashName(local, remote));
    });

    test('★★★ 対称である —— ★入れ替えても★同じ側が勝つ ★★★', () {
      // ★★ これがこの群の要石である（★**収束の根拠そのもの**）★★
      //   ★**「自分を勝たせる」と★2 台が交互に同期して永久に入れ替わり続ける**
      //   （`docs/同期設計メモ.md` §65-5 に 1 手ずつ書いた）。
      //   ★**この 1 件が落ちたら、★★収束しなくなっている★★。**
      final a = _deck(name: 'あ', updatedAt: early);
      final b = _deck(name: 'い', updatedAt: early);

      final forward = resolveDeckConflict(local: a, remote: b);
      final backward = resolveDeckConflict(local: b, remote: a);

      expect(forward.winner.name, backward.winner.name,
          reason: '★★向きを入れ替えると勝つ側が変わる ＝ 収束しない★★');
      expect(forward.reason, DeckResolutionReason.contentHashTieBreak);
      expect(backward.reason, DeckResolutionReason.contentHashTieBreak);
      // ★対: 呼ぶ側から見た「どちら側か」は★入れ替わる（★勝った内容は同じ）。
      expect(forward.side, isNot(backward.side));
    });

    test('★★ 3 つ以上でも★同じ 1 つに落ちる（★★全順序である★★）★★', () {
      // ★★ 2 つで対称でも、★3 つで巡回する規則は作れる ★★
      //   ★**字面の比較は全順序なので巡回しない。**★それを見る。
      final decks = [
        _deck(name: 'あ', updatedAt: early),
        _deck(name: 'い', updatedAt: early),
        _deck(name: 'う', updatedAt: early),
      ];

      final winners = <String>{};
      for (final x in decks) {
        for (final y in decks) {
          if (x.name == y.name) continue;
          winners.add(resolveDeckConflict(local: x, remote: y).winner.name);
        }
      }

      // ★★ 全順序なら、★最大の 1 つは★どの相手にも勝ち、★他は★最大に負ける ★★
      final top = decks
          .reduce((a, b) => deckContentHash(a).compareTo(deckContentHash(b)) > 0
              ? a
              : b)
          .name;
      for (final x in decks) {
        if (x.name == top) continue;
        expect(resolveDeckConflict(local: x, remote: decks.firstWhere((d) => d.name == top)).winner.name,
            top);
      }
      expect(winners, contains(top));
    });
  });

  group('★★ 内容が同じ —— ★★どちらを採っても同じである★★ ★★', () {
    test('★★ 空振りを★呼ぶ側から見えるようにする（★畳まない）★★', () {
      // ★★ 候補 L は「両側が同じ内容へ変わった場合」も衝突のままにする ★★
      //   （**D111-2** / `deck_conflict.dart` の doc）。
      //   ★**解決は空振りになるが害は無い**とあちらが書いている。
      //   → ★**その空振りを★★段 2 と区別できる形で出す★★。**
      final local = _deck(name: 'おなじ', updatedAt: early, lastDeviceId: 'A');
      final remote = _deck(name: 'おなじ', updatedAt: early, lastDeviceId: 'B');

      final got = resolveDeckConflict(local: local, remote: remote);

      expect(got.reason, DeckResolutionReason.identical);
      expect(got.side, DeckResolutionWinner.local);
    });

    test('★★ 対: `lastDeviceId` は内容ハッシュに入らない（決定 D111-4）★★', () {
      // ★★ 上の 1 件が「内容が同じ」と言える根拠そのものである ★★
      final local = _deck(name: 'おなじ', updatedAt: early, lastDeviceId: 'A');
      final remote = _deck(name: 'おなじ', updatedAt: early, lastDeviceId: 'B');

      expect(deckContentHash(local), deckContentHash(remote));
    });
  });

  group('★★ 決めていないことを型で決めない ★★', () {
    test('★★ 削除（`deletedAt`）を特別扱いしない（決定 D112-1 を開き直さない）★★', () {
      // ★★ `deletedAt` は内容ハッシュの 5 フィールドに入らない（**D111-4**）★★
      //   → ★**削除だけが起きた側は★内容ハッシュが 1 ビットも変わらない**（**D116-12**）。
      //   ★**ここで削除を勝たせる / 負けさせるのは★★(f-2) の 粒-1 を開き直すことである★★。**
      final deleted =
          _deck(name: 'おなじ', updatedAt: early, deletedAt: DateTime.utc(2026, 6));
      final alive = _deck(name: 'おなじ', updatedAt: early);

      final got = resolveDeckConflict(local: deleted, remote: alive);

      expect(got.reason, DeckResolutionReason.identical,
          reason: '★削除は内容ハッシュに現れない');
      expect(got.winner.deletedAt, isNotNull, reason: '★手元をそのまま返している');
    });

    test('★★ `revision` を見ない（決定 D116-8 —— ★消費者を作らない）★★', () {
      // ★★ 同-4 を採っていないことの対である（`docs/同期設計メモ.md` §65-5）★★
      final local = _deck(name: 'あ', updatedAt: early, revision: 1);
      final remote = _deck(name: 'あ', updatedAt: early, revision: 99);

      final got = resolveDeckConflict(local: local, remote: remote);

      expect(got.reason, DeckResolutionReason.identical,
          reason: '★`revision` は内容ハッシュにも決着にも入らない');
    });

    test('★★ 出力は★入力の片方そのものである（★マージしない / 粒-1）★★', () {
      final local = _deck(name: 'てもと', updatedAt: late_, revision: 3);
      final remote = _deck(
        name: 'あいて',
        updatedAt: early,
        revision: 9,
        entries: const [DeckEntry(printingId: 'LL-E-002-SD', count: 12)],
      );

      final got = resolveDeckConflict(local: local, remote: remote);

      expect(identical(got.winner, local), isTrue,
          reason: '★★新しく作られたものが 1 つも無い★★');
    });
  });

  group('★★ 柵 —— ★渡す `updatedAt` は★DB から読んだ値であること（決定 D138-4）★★', () {
    test('★★ 秒より細かい差は★段 1 で決まってしまう（★★柵が要る理由★★）★★', () {
      // ★★ 保存精度は秒である（**D115-8** の測定 1）★★
      //   ★**メモリ上の丸められていない値を渡すと、★★同じ秒でも同値にならない★★。**
      //   ★**この 1 件は★柵を破ったときに何が起きるかを固定している**（★直していない）。
      final local = _deck(name: 'あ', updatedAt: DateTime.utc(2026, 5, 1, 12, 0, 0, 1));
      final remote = _deck(name: 'い', updatedAt: DateTime.utc(2026, 5, 1, 12, 0, 0, 0));

      final got = resolveDeckConflict(local: local, remote: remote);

      expect(got.reason, DeckResolutionReason.updatedAt,
          reason: '★★段 2 へ進まない ＝ 決着が「どこから読んだ値か」に依存する★★');
    });

    test('★★ 対: 秒に丸めれば★段 2 へ進む ★★', () {
      final local = _deck(name: 'あ', updatedAt: DateTime.utc(2026, 5, 1, 12, 0, 0));
      final remote = _deck(name: 'い', updatedAt: DateTime.utc(2026, 5, 1, 12, 0, 0));

      final got = resolveDeckConflict(local: local, remote: remote);

      expect(got.reason, DeckResolutionReason.contentHashTieBreak);
    });
  });
}
