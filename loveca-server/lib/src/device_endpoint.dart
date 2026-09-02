/// ★★ 端末の名簿の口 —— §32-6 の **26**（決定 **D145-4** ＝ 名-1）★★
///
/// ## ★★ なぜ★専用の口なのか ★★
///
/// | 案 | ★なぜ採らないか |
/// |---|---|
/// | ★**名-2 既存の 3 つの口に載せる** | ★★**既に決めた署名が 3 つ変わる**★★（**D134-8** / **D141**）。★一覧の口が★★2 つの責務を持つ★★ |
/// | ★**名-3 `/auth` に載せる** | ★★**通らない**★★ —— ★**`deck_sync.dart` は★★`/auth` を 1 度も呼ばない★★**（★実読） |
///
/// ★★ 代償を隠さない —— ★★同期できるデッキが 1 つ減る★★ ★★
/// ★**1 回の同期 ＝ ★★2 ＋ デッキの数★★**（★名簿 1 ＋ 一覧 1 ＋ デッキごと 1）。
/// → ★**同期の枠 25 では★★デッキ 23 個まで★★**（★前は 24）。★**対で固定した**（`test/sync_burst_test.dart`）。
/// ★★**「小さい」とは書かない**★★（**D-28**）—— ★**書けるのは★★1 つ減ることまで★★である。**
///
/// ## ★★ 口の細目 ★★
///
/// | 何 | 決めたこと | ★なぜ |
/// |---|---|---|
/// | ★パス | ★`/devices` | ★**D130-7**（★パスで分ける） |
/// | ★メソッド | ★**POST** | ★**20 / 17-2 と同じ** —— ★★パスワードを URL に載せない★★ |
/// | ★返すもの | ★`known`（★1 ビット）＋ ★`deviceIds` | ★**D145-2**（★引き金）＋ ★**N-19** の「全端末の集合」 |
///
/// ### ★ 状態コード（★**20 と同じ分け方**。★対で固定した）
///
/// | 状態 | 何 |
/// |---|---|
/// | ★**200** | ★名簿に触れた |
/// | ★**400** | ★壊れた要求 / ★空 |
/// | ★**401** | ★名乗りが通らない（★★在る利用者名と無い利用者名を★状態で分けない★★ / **D130** の柵） |
/// | ★**405** | ★メソッド違い |
///
/// ★★**409 も 404 も持ち込まない**★★ —— ★**名簿に無い端末は★★答えであって不在ではない★★**
/// （★§55-3 が「空の一覧は 200」と書いたのと★同じ形）。
///
/// ## ★★ 柵: ★名乗りが先である（**D141** と同じ向き）★★
///
/// ★**名乗りが通らなければ★★名簿を 1 バイトも読み書きしない★★**（★対で固定した）——
/// ★**先に触ると、★★名乗れない相手が★名簿の状態を動かせる★★。**
library;

import 'dart:convert';
import 'dart:io';

import 'account_file_store.dart';
import 'auth.dart';
import 'deck_endpoint.dart' show writeDeckStatus;
import 'device_store.dart';
import 'json_field.dart';

/// 端末の名簿の口のパス。
const String devicesPath = '/devices';

/// 応答の鍵（★★アプリ側と★同じ字面を使う★★ / **D126-3** の代償）。
///
/// ★**やり取りの形が★2 か所に書かれる** —— ★**走査で見張る**
/// （`loveca-ui/test/data/device_client_test.dart`）。
const String deviceKnownKey = 'known';

/// 同（★名簿の全件）。
const String deviceIdsKey = 'deviceIds';

/// 要求の鍵（★端末の同定）。
const String deviceIdKey = 'deviceId';

/// 名簿に触れる口（★§32-6 の **26**）。
///
/// ★★ 期間と時刻は★呼び出し側から渡す ★★
/// ★**[maxIdle] の値は **D124-3**（10 日）。★★誰が決めるかは未決である★★**（**Q-02**）。
/// ★**[now] は★時計** —— ★★時間を測る検査を作らない★★（**D-28** / ★先例は `RateLimiter`）。
Future<void> handleDeviceRequest(
  HttpRequest request,
  AccountFileStore accounts,
  DeviceFileStore devices, {
  required DateTime now,
  required Duration maxIdle,
}) async {
  if (request.method != 'POST') {
    await writeDeckStatus(request.response, HttpStatus.methodNotAllowed);
    return;
  }

  final String userName;
  final String password;
  final String deviceId;
  try {
    final body = await utf8.decoder.bind(request).join();
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('★本文が表ではない');
    }
    userName = requireJsonString(decoded, 'userName');
    password = requireJsonString(decoded, 'password');
    deviceId = requireJsonString(decoded, deviceIdKey);
  } on FormatException {
    await writeDeckStatus(request.response, HttpStatus.badRequest);
    return;
  }

  // ★★ 空は断る（**D133-9** をそのまま持ち込む / 20 と同じ）★★
  if (userName.isEmpty || password.isEmpty || deviceId.isEmpty) {
    await writeDeckStatus(request.response, HttpStatus.badRequest);
    return;
  }

  // ★★ 柵: ★名乗りが先である（★名簿を 1 バイトも触る前）★★
  final auth = authenticate(
    AuthRequest(userName: userName, password: password),
    accounts,
  );
  if (auth is! AuthSuccess) {
    await writeDeckStatus(request.response, HttpStatus.unauthorized);
    return;
  }

  final result =
      devices.touch(userName, deviceId, now: now, maxIdle: maxIdle);

  request.response
    ..statusCode = HttpStatus.ok
    ..headers.contentType = ContentType.json
    ..write(jsonEncode({
      'ok': true,
      deviceKnownKey: result.wasKnown,
      deviceIdsKey: result.deviceIds,
    }));
  await request.response.close();
}
