/// ★★ 認証の口（アプリ側）—— §32-6 の **18** の★口★（決定 **D132-4** / **D132-6**）★★
///
/// ★★ 口だけである。★画面は無い ★★
/// ★**何を残すか**（★毎回入力させるのか、★何かを覚えておくのか）は
/// ★**N-21** の (4)(ii) —— ★★未決である★★。★**この口の外である**
/// （`docs/同期設計メモ.md` §50-6）。
///
/// ---
///
/// ## ★★ 16 と同じ形を採った（決定 **D132-4**）★★
///
/// | 待っているもの | ★この口はこれを要るか |
/// |---|---|
/// | ★**門 シ の (2)**（★アプリが何を信頼するか） | ★★**要らない**★★ —— ★[HttpClient] を★★呼び出し側から渡す★★（**D131-3** と同じ形）。★**証明書の形が何であれ★このファイルは 1 文字も変わらない** |
/// | ★**N-21 の (4)(ii)**（★端末に何を残すか） | ★★**要らない**★★ —— ★**名乗りに行って★答えを返すだけである** |
///
/// ★**住所（[Uri]）も★呼び出し側から渡す**（★**D59** / **D131-5** の柵 3 と同じ形）。
/// ★★**`AppSettings` に足さない**★★ —— ★**それは 18 の★★画面★★の仕事である**（★§40-13 の 3）。
///
/// ---
///
/// ## ★★ 答えを 3 つに分ける（決定 **D132-6** / **D105-6**）★★
///
/// | 何 | 型 | ★なぜ分けるか |
/// |---|---|---|
/// | ★名乗れた | [AuthOk] | ★—— |
/// | ★名乗れなかった | [AuthRejected] | ★**利用者名かパスワードが違う**（★★どちらかは分からない★★ —— ★サーバーが区別しない / **D130** の柵） |
/// | ★★**通信が失敗した**★★ | [AuthUnreachable] | ★★**D105-6**（★通信の失敗は見せる。★編集は止めない）★★ —— ★**2 つに畳むと★★「つながらなかった」が「パスワードが違う」に化ける★★** |
///
/// ★**壊れた応答は★[AuthUnreachable] に畳む**（**D132-6**）——
/// ★**アプリから見れば★どちらも「サーバーが期待どおりでない」である。★分ける材料が無い**（**D-28**）。
///
/// ---
///
/// ## ★★ やり取りの形は★2 か所に書かれる（**D126-3** が買った代償）★★
///
/// ★**`loveca_ui` → `loveca_server` は★★永久に 0 本★★である**
/// （**D126-3** —— ★「★通信は HTTP 越しであってコード依存ではない」）。
/// → ★**鍵の名前（`userName` / `password` / `ok`）は★★サーバー側にも同じものが書かれている★★。**
/// → ★★**消えない。★走査で見張るだけである**★★（`test/data/auth_client_test.dart`）。
///
/// ## ★★ D43 を踏まない ★★
///
/// ★**D43**（UI にネットワーク取得の口を作らない）の理由は★★画像である★★ ——
/// 「★経路が 2 つあると『★どちらから来た画像か』で不具合の切り分けができなくなる」。
/// ★★**この口は★画像を 1 バイトも運ばない。★害が及ばない**★★（★§50-8）。
/// ★★**「期限が切れた」に寄りかからない**★★ —— ★**画像の経路は★門 キ のまま固まっていない**（**N-1**）。
library;

import 'dart:convert';
import 'dart:io';

/// 認証のパス（★サーバー側の `authPath` と同じ字面である / **D131-6**）。
///
/// ★★ サーバーの定数を★import しない（**D126-3**）★★
/// ★**依存は★永久に 0 本である。**★**同じ字面を 2 か所に書く**のが★その決定の代償である。
const String authPath = '/auth';

/// 要求の鍵（★サーバー側の `AuthRequest` と同じ字面である / **D130-12**）。
const String authUserNameKey = 'userName';

/// 同上。
const String authPasswordKey = 'password';

/// 応答の鍵（★サーバー側の `AuthResponse` と同じ字面である）。
const String authOkKey = 'ok';

/// 名乗った結果。
sealed class AuthOutcome {
  const AuthOutcome();
}

/// 名乗れた。★**返るのは★利用者の同定 1 つだけである**（**D123-1**）。
final class AuthOk extends AuthOutcome {
  const AuthOk(this.userName);

  /// ★**サーバーの保管に在る字面である**（★送った字面とは違いうる）。
  final String userName;
}

/// 名乗れなかった。
///
/// ★★ 理由を持たない ★★
/// ★**サーバーが「利用者名が無い」と「パスワードが違う」を区別しない**（**D130** の柵）。
/// ★**こちらで作り分けると★★サーバーが言っていないことを言うことになる★★。**
final class AuthRejected extends AuthOutcome {
  const AuthRejected();
}

/// つながらなかった / 応答が期待どおりでない。
///
/// ★★ 名乗れなかったのと★混ぜない（**D105-6**）★★
/// ★**混ぜると「★つながらなかった」が「★パスワードが違う」に化ける。**
final class AuthUnreachable extends AuthOutcome {
  const AuthUnreachable(this.reason);

  /// ★**利用者に出すためではなく、★診断のために持つ**（★画面は未決 / **N-21** の (4)(ii)）。
  final String reason;
}

/// サーバーに名乗る（★§32-6 の **18** の★口）。
///
/// ★★ [client] と [server] は★呼び出し側から渡す（**D132-6**）★★
/// ★**[client] は★信頼の設定（`SecurityContext`）を★その中に持つ**（★門 シ の (2) はここに現れない）。
/// ★**[server] は★★住所だけ★★である**（★パスはこのファイルが持つ）。
///
/// ★★ 投げない ★★
/// ★**通信の失敗も★壊れた応答も★[AuthUnreachable] にして返す**
/// （★**D105-6** —— ★★見せるためには★値として返る必要がある★★）。
Future<AuthOutcome> authenticateWithServer({
  required HttpClient client,
  required Uri server,
  required String userName,
  required String password,
}) async {
  try {
    final request = await client.postUrl(server.replace(path: authPath));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({
      authUserNameKey: userName,
      authPasswordKey: password,
    }));
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();

    // ★★ 401 は「名乗れなかった」である。★通信は成功している ★★
    if (response.statusCode == HttpStatus.unauthorized) {
      return const AuthRejected();
    }
    if (response.statusCode != HttpStatus.ok) {
      // ★400 / 404 / 405 / 5xx —— ★★どれも「サーバーが期待どおりでない」である★★。
      //   ★400 を「パスワードが違う」に畳まない（★送り手の作りが違う / **D131-6**）。
      return AuthUnreachable('状態 ${response.statusCode}');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return const AuthUnreachable('応答が JSON ではない');
    }
    if (decoded is! Map<String, Object?>) {
      return const AuthUnreachable('応答が表ではない');
    }
    if (decoded[authOkKey] != true) {
      // ★★ 200 なのに `ok` が真でない —— ★★期待どおりでない★★ ★★
      //   ★「名乗れなかった」に畳まない（★サーバーは 401 で言うと決まっている）。
      return const AuthUnreachable('200 だが ok が真でない');
    }
    final name = decoded[authUserNameKey];
    if (name is! String) {
      return const AuthUnreachable('応答に利用者名が無い');
    }
    return AuthOk(name);
  } on Object catch (e) {
    // ★★ つながらない / 証明書が信頼できない / 途中で切れた ★★
    //   ★**投げずに返す**（**D105-6** —— ★見せるためには値として返る必要がある）。
    return AuthUnreachable('$e');
  }
}
