/// ★★ 同期で運ぶ字面 —— ★組み立てと★読み取り（決定 **D142**）★★
///
/// ★★ この群が固定するもの ★★
/// ★**往復して★12 フィールドとも一致すること**（★★鍵の字面が 2 か所に在る代償の受け★★）。
/// ★**欠けた鍵を★★埋めないこと★★**（★組-2 ＝ `Deck.fromJson` との違いそのもの）。
///
/// ★★ `Deck.fromJson` は 1 文字も触っていない ★★
/// ★**あちらは★★手元のファイルを読む口である★★**（★寛容であることが★そこでは正しい / **§7-7**）。
library;

import 'dart:convert';

import 'package:loveca_core/loveca_core.dart';
import 'package:test/test.dart';

Deck _deck() => Deck(
      deckId: 'D-1',
      name: 'かのん',
      entries: const [
        DeckEntry(printingId: 'PL!-bp1-001-P', count: 4),
        DeckEntry(printingId: 'PL!-bp1-002-C', count: 2),
      ],
      memo: 'めも',
      tags: const ['たぐ1', 'たぐ2'],
      coverPrintingId: 'PL!-bp1-001-P',
      createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
      updatedAt: DateTime.utc(2026, 2, 3, 4, 5, 6),
      deletedAt: DateTime.utc(2026, 3, 4, 5, 6, 7),
      revision: 7,
      lastDeviceId: 'たんまつ',
      masterDataVersion: 3,
    );

void main() {
  group('★★ 往復する（★12 フィールドとも）★★', () {
    test('★★ 組み立てて読み戻すと★1 フィールドも変わらない ★★', () {
      final before = _deck();

      final after = decodeDeckForSync(encodeDeckForSync(before));

      expect(after.deckId, before.deckId);
      expect(after.name, before.name);
      expect(after.memo, before.memo);
      expect(after.tags, before.tags);
      expect(after.coverPrintingId, before.coverPrintingId);
      expect(after.createdAt, before.createdAt);
      expect(after.updatedAt, before.updatedAt);
      expect(after.deletedAt, before.deletedAt);
      expect(after.revision, before.revision);
      expect(after.lastDeviceId, before.lastDeviceId);
      expect(after.masterDataVersion, before.masterDataVersion);
      expect(after.entries.length, before.entries.length);
      for (var i = 0; i < before.entries.length; i++) {
        expect(after.entries[i].printingId, before.entries[i].printingId);
        expect(after.entries[i].count, before.entries[i].count);
      }
    });

    test('★★ 内容ハッシュも★往復して一致する（★★解決が立つ前提★★）★★', () {
      final before = _deck();

      final after = decodeDeckForSync(encodeDeckForSync(before));

      expect(deckContentHash(after), deckContentHash(before));
    });

    test('★★ 同じ `Deck` からは★同じ字面が出る（★決定性）★★', () {
      expect(encodeDeckForSync(_deck()), encodeDeckForSync(_deck()));
    });

    test('★ null を持つ側も往復する', () {
      final before = Deck(
        deckId: 'D-2',
        name: 'すみれ',
        entries: const [],
        memo: '',
        tags: const [],
        coverPrintingId: null,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        deletedAt: null,
        revision: 0,
        lastDeviceId: '',
        masterDataVersion: 0,
      );

      final after = decodeDeckForSync(encodeDeckForSync(before));

      expect(after.coverPrintingId, isNull);
      expect(after.deletedAt, isNull);
      expect(after.entries, isEmpty);
      expect(after.tags, isEmpty);
    });
  });
  group('★★ 欠けた鍵を★埋めない（★★組-2 との違いそのもの★★）★★', () {
    Map<String, Object?> base() =>
        jsonDecode(encodeDeckForSync(_deck())) as Map<String, Object?>;

    void expectRefused(Map<String, Object?> json, String why) {
      expect(() => decodeDeckForSync(jsonEncode(json)),
          throwsA(isA<FormatException>()), reason: why);
    }

    test('★★ 12 の鍵を★1 つずつ落として★12 通りとも断る ★★', () {
      // ★★ 1 つずつ落とす（★★まとめて落とすと★どれが効いたか分からない★★）★★
      for (final key in <String>[
        'deckId',
        'name',
        'entries',
        'memo',
        'tags',
        'coverPrintingId',
        'createdAt',
        'updatedAt',
        'deletedAt',
        'revision',
        'lastDeviceId',
        'masterDataVersion',
      ]) {
        final json = base()..remove(key);
        expectRefused(json, '★$key を落とした');
      }
    });

    test('★★ 対: `Deck.fromJson` は★同じ入力を★通してしまう ★★', () {
      // ★★ これが「組-2 を採らない」の実物である ★★
      //   ★**`Deck.fromJson` は★★手元のファイルを読む口である★★**（★寛容が正しい場面が在る）。
      //   ★**1 文字も書き換えていない**（**D-35**）。
      final json = base()
        ..remove('memo')
        ..remove('tags')
        ..remove('entries')
        ..remove('revision');

      final lenient = Deck.fromJson(json.cast<String, dynamic>());

      expect(lenient.memo, '');
      expect(lenient.tags, isEmpty);
      expect(lenient.entries, isEmpty);
      expect(lenient.revision, 0);
      expectRefused(json, '★同じ入力を★この口は断る');
    });

    test('★★ 空のデッキが★勝ちうることを★対で示す（★★断る理由★★）★★', () {
      // ★★ 埋めると何が起きるか ★★
      //   ★**壊れた字面が★「空のデッキ」として成立し、★★解決で勝って★手元のデッキが消えうる★★。**
      final mine = _deck();
      final broken = Deck.fromJson(
          (base()..remove('entries')).cast<String, dynamic>());

      expect(deckContentHash(broken), isNot(deckContentHash(mine)));
      expect(broken.entries, isEmpty,
          reason: '★★埋めると★中身が消えたデッキが★成立する★★');
    });
  });

  group('★★ 型が違えば★断る（★★埋めない★★）★★', () {
    Map<String, Object?> base() =>
        jsonDecode(encodeDeckForSync(_deck())) as Map<String, Object?>;

    void expectRefused(Map<String, Object?> json, String why) {
      expect(() => decodeDeckForSync(jsonEncode(json)),
          throwsA(isA<FormatException>()), reason: why);
    }

    test('★ 文字列の所に数を入れると断る', () {
      expectRefused(base()..['name'] = 7, '★name が数');
      expectRefused(base()..['deckId'] = 7, '★deckId が数');
      expectRefused(base()..['lastDeviceId'] = 7, '★lastDeviceId が数');
    });

    test('★ 整数の所に文字列を入れると断る', () {
      expectRefused(base()..['revision'] = '7', '★revision が文字列');
      expectRefused(base()..['masterDataVersion'] = '3', '★masterDataVersion が文字列');
    });

    test('★★ null を許す所と★許さない所を★分ける ★★', () {
      // ★★ 「無い」と「空」を分ける（★鍵そのものの不在は★上の群が見ている）★★
      expect(
          decodeDeckForSync(jsonEncode(base()..['coverPrintingId'] = null))
              .coverPrintingId,
          isNull);
      expect(
          decodeDeckForSync(jsonEncode(base()..['deletedAt'] = null)).deletedAt,
          isNull);
      expectRefused(base()..['name'] = null, '★name は null を許さない');
      expectRefused(base()..['createdAt'] = null, '★createdAt は null を許さない');
    });

    test('★ 日時として読めなければ断る', () {
      expectRefused(base()..['createdAt'] = 'きのう', '★createdAt');
      expectRefused(base()..['updatedAt'] = '', '★updatedAt が空');
      expectRefused(base()..['deletedAt'] = 'あした', '★deletedAt');
    });

    test('★ 列でなければ断る', () {
      expectRefused(base()..['tags'] = 'たぐ', '★tags が文字列');
      expectRefused(base()..['entries'] = <String, Object?>{}, '★entries が表');
    });

    test('★ 列の中身が違えば断る', () {
      expectRefused(base()..['tags'] = <Object?>['ok', 7], '★tags の値が数');
      expectRefused(base()..['entries'] = <Object?>['ok'], '★entries の要素が文字列');
      expectRefused(
          base()..['entries'] = <Object?>[
            <String, Object?>{'printingId': 'p'}
          ],
          '★entries の要素に count が無い');
      expectRefused(
          base()..['entries'] = <Object?>[
            <String, Object?>{'count': 1}
          ],
          '★entries の要素に printingId が無い');
    });

    test('★ JSON でなければ断る', () {
      expect(() => decodeDeckForSync('これは JSON ではない'),
          throwsA(isA<FormatException>()));
    });

    test('★ 表でなければ断る（★列や数を渡しても）', () {
      expect(() => decodeDeckForSync('[]'), throwsA(isA<FormatException>()));
      expect(() => decodeDeckForSync('7'), throwsA(isA<FormatException>()));
      expect(() => decodeDeckForSync('""'), throwsA(isA<FormatException>()));
    });

    test('★★ 投げるのは FormatException だけである ★★', () {
      // ★★ 呼ぶ側が★1 種類だけ受ければよいことを固定する ★★
      for (final bad in <String>['', 'x', '[]', '{}', 'null']) {
        expect(() => decodeDeckForSync(bad), throwsA(isA<FormatException>()),
            reason: '★入力 "$bad"');
      }
    });
  });

}
