/// ★★ 認証の口（サーバー側）—— §32-6 の **16**（決定 **D131-2** / **D131-3** / **D131-6**）★★
///
/// ★★ これが★§32-6 の 16 である ★★
/// ★**認証のレーンで★★番号を持つ最初のコミットである★★**（★§48-9 / **D131-8**）。
/// ★**待っていた 3 つが揃った** —— ★**判定**（**D130-14**）／ ★**保管**（**D131-4**）／ ★**待ち受け**（**D131-3**）。
///
/// ---
///
/// ## ★★ 柵 —— ★★素の HTTP へ落ちない（決定 **D131-2**）★★
///
/// ★**D129-6** —— ★**盗み見られる経路に載せると★★保存をどれだけ固くしても意味が無い★★。**
/// ★★**形で守る**★★ —— ★[serveAuth] は `SecurityContext` を★★必須で受け取る★★（★省略できない）。
/// ★**このファイルに `HttpServer.bind`（★素の待ち受け）は 1 つも無い**（★走査で見張る）。
///
/// ## ★★ 証明書は★渡される（決定 **D131-3**）★★
///
/// ★**`SecurityContext` は★証明書と鍵を★ファイルからしか読めない。**
/// ★★**どこから来るかは★このパッケージの外である**★★ —— ★**N-24** の (1) は★★利用者判断のまま★★で、
/// ★**その答えが何であれ★このファイルは 1 文字も変わらない。**
///
/// ## ★★ 用意できなかったとき（決定 **D131-1**）★★
///
/// ★**同期が始められないだけである。★★編集は止めない★★**（**D105-6** ＋ **D127-4**）。
/// ★**アプリ側の話であり、★このファイルには現れない**（★★待ち受けが立たなければ★つながらないだけ★★）。
///
/// ---
///
/// ## ★★ 口の細目（決定 **D131-6**）★★
///
/// | 何 | 決めたこと | ★なぜ |
/// |---|---|---|
/// | ★パス | ★`/auth` | ★**D130-7**（★パスで分ける） |
/// | ★メソッド | ★**POST** | ★**本文を送る**（★パスワードが入る）。★★**URL に載せない**★★ —— ★載せると★★記録に残りうる★★ |
/// | ★本文 | ★**JSON** | ★**D130-12** |
///
/// ### ★★ 状態コードを分ける理由（**D105-6** の下流）★★
///
/// | 状態 | 何 | ★なぜ分けるか |
/// |---|---|---|
/// | **200** | ★名乗れた | ★—— |
/// | ★**401** | ★名乗れなかった | ★**アプリが「★つながらなかった」と「★名乗れなかった」を★区別できる形にする** |
/// | ★**400** | ★壊れた要求 | ★**401 と取り違えない** —— ★**400 は「送り手の作りが違う」、★401 は「資格情報が違う」** |
/// | **404** | ★知らないパス | ★**同じ口に配信のパスが載る**（**D130-7**）ので、★★静かに 200 を返さない★★ |
/// | **405** | ★メソッド違い | ★**同上** |
///
/// ★★**失敗の 2 つは★状態コードでも区別しない**★★ —— ★**「利用者名が無い」も「パスワードが違う」も 401 である**
/// （**D130** の柵 —— ★★区別すると利用者名の存在が漏れる★★）。
library;

import 'dart:convert';
import 'dart:io';

import 'auth.dart';

/// 認証のパス（決定 **D131-6**）。
const String authPath = '/auth';

/// 1 つの要求に答える（★★純粋に近い —— ★待ち受けを知らない★★）。
///
/// ★**[request] を読み、★[store] で判定し、★[request.response] に書く。**
/// ★**待ち受けの形（★TLS / ポート / 住所）を 1 つも知らない**ので、
/// ★★**試験は★本物の `HttpServer` でも★合成の要求でも回せる。**★★
Future<void> handleAuthRequest(
  HttpRequest request,
  AccountStore store,
) async {
  if (request.uri.path != authPath) {
    // ★同じ口に配信のパスが載る（D130-7）。★静かに 200 を返さない。
    await _writeStatus(request.response, HttpStatus.notFound);
    return;
  }
  if (request.method != 'POST') {
    await _writeStatus(request.response, HttpStatus.methodNotAllowed);
    return;
  }

  final AuthRequest parsed;
  try {
    final body = await utf8.decoder.bind(request).join();
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('★本文が表ではない');
    }
    parsed = AuthRequest.fromJson(decoded);
  } on FormatException {
    // ★★ 壊れた要求である（★資格情報が違うのではない）★★
    //   ★401 にすると、★**送り手の作りの誤りが「パスワードが違う」に化ける**。
    await _writeStatus(request.response, HttpStatus.badRequest);
    return;
  }

  final result = authenticate(parsed, store);
  final status = result is AuthSuccess
      ? HttpStatus.ok
      // ★★ アカウントが無い場合も、★パスワードが違う場合も 401 である ★★
      //   ★区別すると★★利用者名の存在が外から分かる★★（D130 の柵）。
      : HttpStatus.unauthorized;

  request.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(result.toJson()));
  await request.response.close();
}

Future<void> _writeStatus(HttpResponse response, int status) async {
  response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(const AuthFailure().toJson()));
  await response.close();
}

/// 待ち受けを立てる（決定 **D131-2** / **D131-3**）。
///
/// ★★ [context] は★必須である。★省略できない ★★
/// ★**これが「素の HTTP へ落ちない」柵そのものである**（**D131-2**）——
/// ★**`HttpServer.bind`（★TLS 無し）を呼ぶ道が★このパッケージに 1 つも無い。**
///
/// ★★ 証明書の出所を知らない ★★
/// ★**[context] は★呼び出し側が組み立てる**（**D131-3**）。★**N-24** の (1) は★ここに現れない。
Future<HttpServer> serveAuth({
  required SecurityContext context,
  required AccountStore store,
  Object? address,
  int port = 0,
}) async {
  final server = await HttpServer.bindSecure(
    address ?? InternetAddress.loopbackIPv4,
    port,
    context,
  );
  server.listen((request) => handleAuthRequest(request, store));
  return server;
}
