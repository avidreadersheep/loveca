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
/// ★★**形で守る**★★ —— ★[serveApi] は `SecurityContext` を★★必須で受け取る★★（★省略できない）。
/// ★★**2026-09-01 訂正: ここには `serveAuth` と書いてあった**★★（★型は **D-15 (l)** —— ★§53 で改名した）。
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
/// ★★**2026-09-01 追記: ★★429 が増えた**★★（★上限 / **N-26** の★★既定値★★ / `src/rate_limit.dart`）。
/// ★★**上の表は 1 文字も書き換えない**★★（**D-35** —— ★書いた時点では正しい）。
/// ★★**429 は★★決定ではない★★**★★ —— ★**N-26** の (1) は★★利用者判断のまま★★である。
/// ★**429 は★誰の何も漏らさない**（★★名乗りを見る★前★に返る★★ので、★利用者名の存在に触れない）。
///
/// ★★**失敗の 2 つは★状態コードでも区別しない**★★ —— ★**「利用者名が無い」も「パスワードが違う」も 401 である**
/// （**D130** の柵 —— ★★区別すると利用者名の存在が漏れる★★）。
///
/// ### ★★ ただし★時間では区別する（★★塞いでいない★★ / 決定 **D134-2**）★★
///
/// ★★**実測**★★（2026-09-01 / ★本番の回数 600000）—— ★**在る利用者名 ＋ 違うパスワード = 1526 ms /
/// ★無い利用者名 ＋ 違うパスワード = 1 ms。★★どちらも 401 である★★。**
/// ★**原因は [authenticate] の早い戻りである**（★★利用者名が無ければ★固める処理を 1 度も回さない★★）。
/// → ★★**「認証の口は漏らさない」と書かないこと。★漏れる。**★★
/// ★**塞ぐかは **N-26**（★門 セ）の (3) である** —— ★★塞ぐと★無い利用者名にも 1.5 秒かかる★★ので、
/// ★**上限の話と★逆を向く**（`docs/同期設計メモ.md` §54-2 / §10 の **N-26**）。
library;

import 'dart:convert';
import 'dart:io';

import 'account_endpoint.dart';
import 'account_file_store.dart';
import 'auth.dart';
import 'deck_endpoint.dart';
import 'device_endpoint.dart';
import 'device_store.dart';
import 'dist_endpoint.dart';
import 'deck_store.dart';
import 'password_hash.dart';
import 'rate_limit.dart';

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

/// パスがどの枠に入るか（★**N-27** の 論点 (2) の★★既定値★★ / 2026-09-02）。
///
/// ★★ 振り分けと★同じ定数を引く（★★字面を 2 か所に持たない★★ / **D-15** の規約 3）★★
/// ★**だからここに置いてある**（`src/rate_limit.dart` ではない）—— ★★あちらは口の名前を知らない★★。
///
/// ★★ 配る口はここに来ない ★★
/// ★**`/dist/...` は★★上限より前に振り分けられる★★**（★下の [handleApiRequest] / `docs/同期設計メモ.md` §62）。
///
/// ★★ 知らないパスは★人が押す枠に入れる ★★
/// ★**同期の枠は「★1 回の同期が通ること」で寸法が決まっており、★★知らないパスはその勘定に入らない★★。**
RateLimitFrame rateLimitFrameFor(String path) => switch (path) {
      decksPath ||
      decksFetchPath ||
      decksListPath ||
      // ★★ 2026-09-02: ★名簿の口も★同期の枠である（決定 **D145-4**）★★
      //   ★**1 回の同期が★必ず 1 回呼ぶ**（★§77-6 の (丙) —— ★2 ＋ デッキの数）。
      //   ★★**人が押す枠に入れると、★★同期が★人の枠を食う★★。**
      devicesPath =>
        RateLimitFrame.deckSync,
      _ => RateLimitFrame.human,
    };

/// パスで振り分ける（決定 **D130-7** —— ★同じ口。★パスで分ける）。
///
/// ★★ 知らないパスは 404（★静かに 200 を返さない）★★
/// ★**同じ口に★配信のパスも載る**（**D130-7**）。★**まだ無い。**
///
/// ★★ 2026-09-01: `/decks/list` を足した（★§55-3 が「一覧を返す口が無い」と書いた分）★★
/// ★**`/decks` と `/decks/fetch` の★前にも後にも置ける**（★`switch` は★★完全一致である★★）——
/// ★**接頭辞で振り分けていないので、★★`/decks/list` が `/decks` に吸われない★★。**
/// ★**対で固定する**（★4 つのパスが★1 つずつ★別の口へ行くこと）。
Future<void> handleApiRequest(
  HttpRequest request,
  AccountFileStore store,
  DeckFileStore decks, {
  int accountIterations = passwordHashIterations,
  ApiRateLimiter? rateLimiter,
  DistFileStore? dist,
  DeviceFileStore? devices,
  DateTime Function()? clock,
  Duration deviceMaxIdle = defaultDeviceMaxIdle,
}) async {
  // ★★ 配る口は★上限より★前に振り分ける（★対象から外している）★★
  //   ★**理由は 1 つ** —— ★この口は★★名乗りを 1 度も見ない★★ので、
  //   ★★固める処理（1.5 秒）を 1 度も通らない★★。→ ★上限を立てた理由が当たらない。
  //   ★★**「安全である」とは書かない**★★（★押し続けられればファイルを読む費用は掛かる / **D-28**）。
  //   ★**これは **N-27**（門 ソ）の★★入力である★★**（★論点 (2)「口ごとに枠を分けるか」）。
  //   ★★**置き場が渡されていなければ★既定の枝で 404 に落ちる**★★（★静かに 200 を返さない）。
  if (dist != null && request.uri.path.startsWith(distPathPrefix)) {
    await handleDistRequest(request, dist);
    return;
  }

  // ★★ 上限は★固める処理より★前に見る（★見なければ守っていない）★★
  //   ★**N-26**（門 セ）の★★既定値★★である。★決定ではない（`src/rate_limit.dart`）。
  //   ★**住所が取れない要求は★1 つの枠にまとめる**（★合成の要求 / 実際には起こらない）。
  //   ★★**2026-09-02: ★枠で分けるようにした**★★（★**N-27** の 論点 (2) の★★既定値★★ /
  //   ★運転指示【0】(3)）—— ★**人が押す枠と★同期の枠を★別に数える。**
  if (rateLimiter != null) {
    final key = request.connectionInfo?.remoteAddress.address ?? '★不明';
    if (!rateLimiter.allow(rateLimitFrameFor(request.uri.path), key)) {
      await _writeStatus(request.response, HttpStatus.tooManyRequests);
      return;
    }
  }

  switch (request.uri.path) {
    case authPath:
      await handleAuthRequest(request, store);
    case accountsPath:
      await handleAccountRequest(request, store,
          iterations: accountIterations);
    case decksPath:
      await handleDeckPutRequest(request, store, decks);
    case decksFetchPath:
      await handleDeckFetchRequest(request, store, decks);
    case decksListPath:
      await handleDeckListRequest(request, store, decks);
    case devicesPath:
      // ★★ 置き場が渡されていなければ★404 に落ちる（★配る口と同じ形）★★
      //   ★**静かに 200 を返さない。**
      if (devices == null) {
        await _writeStatus(request.response, HttpStatus.notFound);
      } else {
        await handleDeviceRequest(request, store, devices,
            now: (clock ?? DateTime.now)(), maxIdle: deviceMaxIdle);
      }
    default:
      await _writeStatus(request.response, HttpStatus.notFound);
  }
}

/// 待ち受けを立てる（決定 **D131-2** / **D131-3**）。
///
/// ★★ [context] は★必須である。★省略できない ★★
/// ★**これが「素の HTTP へ落ちない」柵そのものである**（**D131-2**）——
/// ★**`HttpServer.bind`（★TLS 無し）を呼ぶ道が★このパッケージに 1 つも無い。**
///
/// ★★ 証明書の出所を知らない ★★
/// ★**[context] は★呼び出し側が組み立てる**（**D131-3**）。★**N-24** の (1) は★ここに現れない。
///
/// ★★ 2026-09-01: `serveAuth` から改名した（決定 **D133-10**）★★
/// ★**アカウントを作る口（**17-2**）が入り、★★1 つの待ち受けが 2 つのパスを持つ★★ようになった。
/// ★**「認証だけを待ち受ける」という名前が★★実物と食い違った★★**（★型は **D-15 (l)**）。
///
/// ★★ この名前は★★動きうる。★前提を書いておく（**D134** / **D-15 (l)** の先回り）★★ ★★
///
/// ★**`Api` が指す範囲は★**D130-7**（★配信と同じ口。★パスで分ける）に従って★広がる。**
///
/// | いつ | ★何が起きるか |
/// |---|---|
/// | ★**カードマスタの配信が乗るとき**（**D120-1**） | ★★**配信は★静的なファイルであって「API」ではない**★★。★同じ待ち受けに乗るので、★★名前が指す範囲が広がる★★ |
/// | ★**Phase 6 が乗るとき** | ★★**別の待ち受けか★別の口が要るかもしれない**★★ —— ★**D130-5** は WebSocket を★★落としていない★★（★「サーバーから押し込む必要が★今日 1 つも無い」＋ ★開き直す条件つき） |
///
/// → ★★**今日は改名しない。★前提だと書いておく**★★（★正はここ 1 か所 / `docs/同期設計メモ.md` §54-5）。
Future<HttpServer> serveApi({
  required SecurityContext context,
  required AccountFileStore store,
  required DeckFileStore decks,
  DeviceFileStore? devices,
  Duration deviceMaxIdle = defaultDeviceMaxIdle,
  Object? address,
  int port = 0,
  int accountIterations = passwordHashIterations,
  RateLimitPolicySet rateLimits = defaultRateLimits,
  DateTime Function()? clock,
  DistFileStore? dist,
}) async {
  final server = await HttpServer.bindSecure(
    address ?? InternetAddress.loopbackIPv4,
    port,
    context,
  );
  // ★★ 待ち受け 1 つにつき 1 つ数える（★立て直せば忘れる）★★
  final limiter = ApiRateLimiter(rateLimits, clock: clock);
  server.listen((request) => handleApiRequest(request, store, decks,
      accountIterations: accountIterations,
      rateLimiter: limiter,
      dist: dist,
      devices: devices,
      clock: clock,
      deviceMaxIdle: deviceMaxIdle));
  return server;
}
