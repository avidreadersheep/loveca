/// ★★ 認証の判定（決定 **D130-14** / `docs/同期設計メモ.md` §46-11 / §46-12）★★
///
/// ★★ golden の形が★対の判別力を決める（★§45 の (R)）★★
/// ★§45 で、★**32 バイトの golden では★通し番号の組み立てが★★誰にも見られていなかった★★**。
/// → ★**この群では★★要求と応答の JSON を★字面で固定する★★**（★鍵の名前も、★入れ子の形も）。
/// ★**「往復して同じ」だけでは足りない** —— ★★鍵の名前を両側で入れ替えても通る★★。
///
/// ★★ ここで固定していないもの ★★
/// - ★**利用者名の正規化**（★どの決定にも書かれていない / §46-14 の 2）。
///   → ★**受け取った字面をそのまま鍵にすることだけ**を固定する。
/// - ★**待ち受け**（★門 シ）と ★**保管の実装**（★§35-9）。★**1 行も無い。**
library;

import 'dart:convert';

import 'package:loveca_server/loveca_server.dart';
import 'package:test/test.dart';

/// ★試験用の保管。★**`lib` には置かない**（★§35-9 が未決 / **D126-4** の 3 段目）。
class _MapStore implements AccountStore {
  _MapStore(this._rows);

  final Map<String, AccountRecord> _rows;

  /// ★引いた回数。★**「引いたか」を見る対に使う。**
  final List<String> lookups = [];

  @override
  AccountRecord? findByUserName(String userName) {
    lookups.add(userName);
    return _rows[userName];
  }
}

/// ★★ 正規化する保管（★要求の字面と★保管の字面が違う場合）★★
/// ★**どの決定にも規則が無い**ので、★**`lib` は正規化しない**。
/// ★**この実装は「保管の側が持てる」ことを見るためだけに在る。**
class _LowerCaseStore implements AccountStore {
  _LowerCaseStore(this._rows);

  final Map<String, AccountRecord> _rows;

  @override
  AccountRecord? findByUserName(String userName) =>
      _rows[userName.toLowerCase()];
}

const _salt = <int>[
  1, 2, 3, 4, 5, 6, 7, 8, //
  9, 10, 11, 12, 13, 14, 15, 16,
];

/// ★繰り返し回数は小さくする（★**既定の 600000 は 1 回 1.5 秒かかる** / §45）。
/// ★**保存の形そのものは `password_hash_test.dart` が見る。**
String _hash(String password) =>
    encodePasswordHash(password, salt: _salt, iterations: 10);

AccountRecord _account(String userName, String password) =>
    AccountRecord(userName: userName, passwordHash: _hash(password));

void main() {
  group('★★ 要求の形 —— ★★字面で固定する（決定 D130-12）★★', () {
    test('★★ 鍵の名前を固定する（★往復だけでは足りない / §45 の (R)）★★', () {
      const request = AuthRequest(userName: 'みつき', password: 'ひみつ');

      // ★★ 字面で見る。★鍵を入れ替えても往復は通るが、★これは通らない ★★
      expect(jsonEncode(request.toJson()),
          jsonEncode({'userName': 'みつき', 'password': 'ひみつ'}));
    });

    test('★★ フィールドは 2 つだけである（決定 D130-13）★★', () {
      // ★★ 端末の同定を入れない。★入れると 26（端末の名簿）の形を先に決めてしまう ★★
      //   ★フィールドを足すと★この検査が落ちる。
      const request = AuthRequest(userName: 'a', password: 'b');

      expect(request.toJson().keys.toList(), ['userName', 'password']);
    });

    test('★ JSON から読める', () {
      final request = AuthRequest.fromJson(
          jsonDecode('{"userName":"みつき","password":"ひみつ"}')
              as Map<String, Object?>);

      expect(request.userName, 'みつき');
      expect(request.password, 'ひみつ');
    });

    test('★★ 鍵が無い / 型が違うときは投げる（★壊れた要求である）★★', () {
      expect(() => AuthRequest.fromJson({'userName': 'a'}),
          throwsFormatException);
      expect(() => AuthRequest.fromJson({'password': 'b'}),
          throwsFormatException);
      expect(() => AuthRequest.fromJson({'userName': 'a', 'password': 1}),
          throwsFormatException);
    });

    test('★★ 対: 空文字は投げない（★間違った資格情報であって壊れた要求ではない）★★', () {
      // ★★ これが無いと、★「投げる」側だけを見て★★空も投げる実装★★が通る ★★
      final request = AuthRequest.fromJson({'userName': '', 'password': ''});

      expect(request.userName, '');
      expect(request.password, '');
    });
  });

  group('★★ 応答の形 —— ★★失敗に理由を入れない（★柵）★★', () {
    test('★ 成功は利用者名を 1 つだけ返す（決定 D123-1）', () {
      expect(jsonEncode(const AuthSuccess('みつき').toJson()),
          jsonEncode({'ok': true, 'userName': 'みつき'}));
    });

    test('★★ 失敗は理由を 1 つも持たない ★★', () {
      // ★★ 鍵が増えたらこの検査が落ちる ★★
      //   ★「利用者名が無い」と「パスワードが違う」を区別すると、
      //   ★★利用者名の存在が外から分かる★★。
      expect(jsonEncode(const AuthFailure().toJson()),
          jsonEncode({'ok': false}));
      expect(const AuthFailure().toJson().keys.toList(), ['ok']);
    });
  });

  group('★★ 判定 ★★', () {
    final store = _MapStore({
      'みつき': _account('みつき', 'ひみつ'),
      'kanon': _account('kanon', 'password'),
    });

    test('★ 合っていれば成功で、利用者名が返る', () {
      final result = authenticate(
          const AuthRequest(userName: 'みつき', password: 'ひみつ'), store);

      expect(result, isA<AuthSuccess>());
      expect((result as AuthSuccess).userName, 'みつき');
    });

    test('★ パスワードが違えば失敗', () {
      expect(
          authenticate(
              const AuthRequest(userName: 'みつき', password: 'ちがう'), store),
          isA<AuthFailure>());
    });

    test('★ 利用者名が無ければ失敗', () {
      expect(
          authenticate(
              const AuthRequest(userName: 'いない', password: 'ひみつ'), store),
          isA<AuthFailure>());
    });

    test('★★ 2 つの失敗は★区別が付かない（★柵）★★', () {
      // ★★ これが柵そのものである ★★
      //   ★応答に理由を足すと、★この検査が落ちる。
      final noUser = authenticate(
          const AuthRequest(userName: 'いない', password: 'ひみつ'), store);
      final badPass = authenticate(
          const AuthRequest(userName: 'みつき', password: 'ちがう'), store);

      expect(jsonEncode(noUser.toJson()), jsonEncode(badPass.toJson()));
    });

    test('★★ 対: 成功と失敗は区別が付く（★上が「全部同じ」で通らないこと）★★', () {
      // ★★ これが無いと、★★常に AuthFailure を返す実装★★でも上の検査が通る ★★
      final ok = authenticate(
          const AuthRequest(userName: 'kanon', password: 'password'), store);
      final ng = authenticate(
          const AuthRequest(userName: 'kanon', password: 'Password'), store);

      expect(jsonEncode(ok.toJson()), isNot(jsonEncode(ng.toJson())));
    });

    test('★★ 空のパスワードは★失敗であって★例外ではない ★★', () {
      expect(
          authenticate(const AuthRequest(userName: 'みつき', password: ''), store),
          isA<AuthFailure>());
    });

    test('★★ 受け取った字面をそのまま鍵にする（★正規化しない）★★', () {
      // ★★ どの決定にも規則が無い（§46-14 の 2）ので、★lib は畳まない ★★
      //
      // ★★ 字の向きが★対の判別力を決める（★§45 の (R) / ★この回で踏んだ）★★
      //   ★**最初は保管を `Mitsuki`、★要求を `mitsuki` にしていた。**
      //   ★**そのままだと★lib が小文字へ畳んでも★★要求は既に小文字で、★保管は大文字混じり★★
      //     なので★★結果も引いた字面も 1 つも変わらない★★**（★仕込んで **0 件**だった）。
      //   → ★**向きを逆にする** —— ★**保管が小文字、★要求が大文字混じり**。
      //     ★これなら★畳んだ瞬間に★★見つかってしまう★★。
      final probe = _MapStore({'mitsuki': _account('mitsuki', 'ひみつ')});

      expect(
          authenticate(
              const AuthRequest(userName: 'Mitsuki', password: 'ひみつ'), probe),
          isA<AuthFailure>());
      // ★★ 引いた字面そのものも見る（★結果だけだと★保管が畳んだ場合と区別が付かない）★★
      expect(probe.lookups, ['Mitsuki']);
    });

    test('★★ 対: 「同じ」の定義は保管の実装が持てる ★★', () {
      // ★★ 上の検査だけだと「正規化できない」と読める。★できる ★★
      //   ★**置き場が違うだけである**（★lib ではなく [AccountStore] の実装）。
      final folding = _LowerCaseStore({'mitsuki': _account('mitsuki', 'ひみつ')});

      final result = authenticate(
          const AuthRequest(userName: 'Mitsuki', password: 'ひみつ'), folding);

      expect(result, isA<AuthSuccess>());
      // ★★ 返るのは★保管の側の字面である（★要求の字面ではない）★★
      expect((result as AuthSuccess).userName, 'mitsuki');
    });

    test('★★ 保管を 1 度だけ引く（★引かずに答える実装なら落ちる）★★', () {
      final probe = _MapStore({'a': _account('a', 'b')});
      authenticate(const AuthRequest(userName: 'a', password: 'b'), probe);

      expect(probe.lookups, ['a']);
    });
  });

  group('★★ 固める関数との繋がり（決定 D129-3）★★', () {
    test('★★ 判定は★保存した値を通して行う（★平文と比べていない）★★', () {
      // ★★ 保管の値が★平文なら★判定は失敗する ★★
      //   ★**平文で比べる実装ならこれが成功して落ちる。**
      const plain =
          AccountRecord(userName: 'なぎさ', passwordHash: 'ひみつ');
      final store = _MapStore({'なぎさ': plain});

      expect(
          () => authenticate(
              const AuthRequest(userName: 'なぎさ', password: 'ひみつ'), store),
          throwsFormatException);
    });

    test('★★ 対: 固めた値なら通る ★★', () {
      final store = _MapStore({'なぎさ': _account('なぎさ', 'ひみつ')});

      expect(
          authenticate(
              const AuthRequest(userName: 'なぎさ', password: 'ひみつ'), store),
          isA<AuthSuccess>());
    });
  });
}
