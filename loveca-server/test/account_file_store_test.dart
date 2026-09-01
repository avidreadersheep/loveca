/// ★★ アカウントの保管（決定 **D131-4** / **D131-5** / `docs/同期設計メモ.md` §48-4 〜 §48-6）★★
///
/// ★★ golden の形が★対の判別力を決める（★§45 の (R) / §47 の (J)）★★
/// ★**ファイルの中身を★★字面で固定する★★**（★鍵の名前も、★版の欄も）。
/// ★**「書いて読み戻せる」だけでは足りない** —— ★★鍵の名前を両側で入れ替えても通る★★。
library;

import 'dart:convert';
import 'dart:io';

import 'package:loveca_server/loveca_server.dart';
import 'package:test/test.dart';

late Directory _dir;

String get _path => '${_dir.path}${Platform.pathSeparator}accounts.json';

AccountRecord _account(String userName) => AccountRecord(
      userName: userName,
      passwordHash: encodePasswordHash(
        'ひみつ',
        salt: List<int>.filled(16, 3),
        iterations: 10,
      ),
    );

void main() {
  setUp(() {
    _dir = Directory.systemTemp.createTempSync('loveca_accounts_test');
  });

  tearDown(() {
    if (_dir.existsSync()) _dir.deleteSync(recursive: true);
  });

  group('★★ 開く ★★', () {
    test('★★ 無ければ空として開く（★作らない）★★', () {
      final store = AccountFileStore.open(_path);

      expect(store.count, 0);
      // ★★ 開いただけでファイルを作らない ★★
      //   ★作ると「まだ 1 件も無い」と「空だと書いてある」が区別できなくなる。
      expect(File(_path).existsSync(), isFalse);
    });

    test('★ 書いたものを読み戻せる', () {
      AccountFileStore.open(_path).add(_account('みつき'));

      final reopened = AccountFileStore.open(_path);
      expect(reopened.count, 1);
      expect(reopened.findByUserName('みつき'), isNotNull);
    });

    test('★★ 壊れていれば投げる（★空として開かない）★★', () {
      // ★★ 空として開くと★★全アカウントが静かに消える★★ ★★
      File(_path).writeAsStringSync('これは JSON ではない');

      expect(() => AccountFileStore.open(_path), throwsFormatException);
    });

    test('★★ 知らない版は投げる（★推測で読まない）★★', () {
      File(_path).writeAsStringSync(jsonEncode({
        'version': accountFileVersion + 1,
        'accounts': <Object?>[],
      }));

      expect(() => AccountFileStore.open(_path), throwsFormatException);
    });

    test('★★ 読み込みでも重複を断る（★柵 2 の裏側）★★', () {
      // ★★ 手で書き足したファイルが★★静かに片方を捨てる★★のを防ぐ ★★
      File(_path).writeAsStringSync(jsonEncode({
        'version': accountFileVersion,
        'accounts': [
          {'userName': 'a', 'passwordHash': 'x'},
          {'userName': 'a', 'passwordHash': 'y'},
        ],
      }));

      expect(() => AccountFileStore.open(_path), throwsFormatException);
    });

    test('★ 鍵が無い行は投げる', () {
      File(_path).writeAsStringSync(jsonEncode({
        'version': accountFileVersion,
        'accounts': [
          {'userName': 'a'},
        ],
      }));

      expect(() => AccountFileStore.open(_path), throwsFormatException);
    });
  });

  group('★★ 柵 2 —— ★重複は断る（決定 D130-9）★★', () {
    test('★★ 同じ利用者名は 2 度足せない ★★', () {
      final store = AccountFileStore.open(_path)..add(_account('みつき'));

      expect(() => store.add(_account('みつき')), throwsStateError);
    });

    test('★★ 対: 断ったあとも★元の 1 件は壊れていない ★★', () {
      // ★★ これが無いと、★★半分書いてから投げる実装★★でも上が通る ★★
      final store = AccountFileStore.open(_path)..add(_account('みつき'));
      try {
        store.add(AccountRecord(userName: 'みつき', passwordHash: 'ちがう'));
      } on StateError {
        // ★握り潰す（★上の検査が投げることを見ている）。
      }

      final reopened = AccountFileStore.open(_path);
      expect(reopened.count, 1);
      expect(reopened.findByUserName('みつき')!.passwordHash, isNot('ちがう'));
    });

    test('★ 違う利用者名なら足せる', () {
      final store = AccountFileStore.open(_path)
        ..add(_account('みつき'))
        ..add(_account('かのん'));

      expect(store.count, 2);
    });
  });

  group('★★ ファイルの形 —— ★★字面で固定する ★★', () {
    test('★★ 鍵の名前と版を固定する（★往復だけでは足りない）★★', () {
      AccountFileStore.open(_path)
          .add(const AccountRecord(userName: 'a', passwordHash: 'H'));

      expect(
        File(_path).readAsStringSync(),
        jsonEncode({
          'version': 1,
          'accounts': [
            {'userName': 'a', 'passwordHash': 'H'},
          ],
        }),
      );
    });

    test('★★ 並びは利用者名の順である（★足した順ではない）★★', () {
      // ★★ 並びが揺れると、★差分が★★中身と無関係に動く★★ ★★
      AccountFileStore.open(_path)
        ..add(const AccountRecord(userName: 'b', passwordHash: '1'))
        ..add(const AccountRecord(userName: 'a', passwordHash: '2'));

      final decoded = jsonDecode(File(_path).readAsStringSync())
          as Map<String, Object?>;
      final names = (decoded['accounts']! as List<Object?>)
          .map((e) => (e! as Map<String, Object?>)['userName'])
          .toList();

      expect(names, ['a', 'b']);
    });

    test('★★ 版は `loveca_db` の schemaVersion とは別物である ★★', () {
      // ★★ 共有しないために分けた（§48-5）★★
      //   ★この定数がここに在ること自体が★その決定である。
      expect(accountFileVersion, 1);
    });
  });

  group('★★ 柵 1 —— ★一時ファイルへ書いてから置き換える ★★', () {
    test('★★ 書いたあと★一時ファイルが残らない ★★', () {
      AccountFileStore.open(_path).add(_account('みつき'));

      expect(File('$_path.tmp').existsSync(), isFalse);
      expect(File(_path).existsSync(), isTrue);
    });

    test('★★ 対: 一時ファイルが先に在っても★置き換わる ★★', () {
      // ★★ 前回落ちた残骸が在っても★次の書き込みが通ること ★★
      File('$_path.tmp').writeAsStringSync('ごみ');

      AccountFileStore.open(_path).add(_account('みつき'));

      expect(AccountFileStore.open(_path).count, 1);
      expect(File('$_path.tmp').existsSync(), isFalse);
    });

    test('★★ 柵 3: 置き場は★呼び出し側が渡す ★★', () {
      // ★★ このパッケージは★置き場を 1 つも決めない（D59 の先例）★★
      //   ★別のディレクトリを渡せば★そこに書かれる。
      final other = Directory('${_dir.path}${Platform.pathSeparator}別')
        ..createSync();
      final otherPath = '${other.path}${Platform.pathSeparator}a.json';

      AccountFileStore.open(otherPath).add(_account('みつき'));

      expect(File(otherPath).existsSync(), isTrue);
      expect(File(_path).existsSync(), isFalse);
    });
  });

  group('★★ 判定と繋がる（決定 D130-14）★★', () {
    test('★★ 保管から引いた値で★名乗れる ★★', () {
      final store = AccountFileStore.open(_path)..add(_account('みつき'));

      expect(
        authenticate(
            const AuthRequest(userName: 'みつき', password: 'ひみつ'), store),
        isA<AuthSuccess>(),
      );
    });

    test('★ 対: 違うパスワードなら名乗れない', () {
      final store = AccountFileStore.open(_path)..add(_account('みつき'));

      expect(
        authenticate(
            const AuthRequest(userName: 'みつき', password: 'ちがう'), store),
        isA<AuthFailure>(),
      );
    });

    test('★★ 受け取った字面をそのまま鍵にする（★正規化しない）★★', () {
      // ★★ 字の向きに気を付ける（★§47 の (J) —— ★保管が小文字、★要求が大文字混じり）★★
      final store = AccountFileStore.open(_path)..add(_account('mitsuki'));

      expect(store.findByUserName('Mitsuki'), isNull);
      expect(store.findByUserName('mitsuki'), isNotNull);
    });
  });
}
