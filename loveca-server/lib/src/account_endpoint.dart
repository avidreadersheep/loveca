/// ★★ アカウントを作る口 —— §32-6 の **17-2**（決定 **D133-4** / **D133-9** / **D133-10**）★★
///
/// ★★ §32-6 の漏れだった（**D132-1**）★★
/// ★§46-14 の 1 / §48-12 の 1 / §49-3 が「★アカウントを作る口が★どのコミットにも無い」と
/// ★★3 回書いた分★★である。★**D132-1** が **17-2** として立て、★**D133-4** が★門 ス を閉じた。
///
/// ---
///
/// ## ★★ 誰が呼んでよいか —— ★★誰でも（決定 **D133-4** ＝ 作-1）★★
///
/// ★**利用者が 2026-09-01 に決めた**（★経緯に★★撤回が 1 件在る★★ / `docs/同期設計メモ.md` §9-18）。
/// ★★**方針の切り替えを持たない**★★（**D114-7** の理由 2 —— ★★決まっていない分岐を先に置かない★★）。
/// ★**開き直す条件**（**D133-6**）: ★**見ず知らずの人が実際に作り始め、★利用者が止めたいと判断したとき。**
///
/// ## ★★ 【要確認/法務】D104 の札が発火している（**D133-5**）★★
///
/// ★**D104 の確認の範囲は「★利用者以外がサーバー経由で★利用する形」であり、
/// ★★人数の上限も★★公開の可否★★も述べられていない★★**（`docs/同期設計メモ.md` §9-2 の依存 2）。
/// → ★★**この口を★★動かす★★前に、★利用者が引き直すかを判断すること。**★★
/// ★**書く前ではない** —— ★**証明書が無ければ待ち受けが立たず、★★誰も作れない★★**（**D133-3** の柵）。
///
/// ---
///
/// ## ★★ 口の細目（決定 **D133-9**）★★
///
/// | 何 | 決めたこと | ★なぜ |
/// |---|---|---|
/// | ★パス | ★`/accounts` | ★**D130-7**（★パスで分ける）。★`/auth` と重ならない |
/// | ★メソッド | ★**POST** | ★本文を送る（★パスワードが入る）。★**URL に載せない** |
/// | ★**201** | ★作れた | ★**409 と分ける**（★作れたかどうかが状態で分かる） |
/// | ★★**409**★★ | ★その利用者名は既に在る | ★**D130-9**（★サーバーが一意性を保つ）。★★**下の「漏れる」を読むこと**★★ |
/// | ★**400** | ★壊れた要求 / ★空 | ★**D131-6** と同じ分け方（★400 は「送り手の作りが違う」） |
///
/// ### ★★ 空は断る。★長さの下限は決めない ★★
///
/// ★★**空のパスワードを許すと「パスワード無し」と同じになる**★★ ——
/// ★**利用者名を知っていれば誰でも名乗れる**。★**D105-3**（★アクセス制御はサーバー）が★★成り立たない★★。
/// ★**これは `docs/同期設計メモ.md` §9-16 の (a) が倒した形そのものである**（★秘密が無い）。
/// ★★**長さの下限は★格が違う**★★ —— ★「4 文字か 8 文字か」は★★好みで決まる★★（★測っていない / **D-28**）。★**決めない。**
///
/// ### ★★ 存在が漏れる。★隠さない ★★
///
/// ★**409 は「★その利用者名は既に在る」を返す。**→ ★★**利用者名の存在が★外から分かる。**★★
/// ★**§46-14 の 3 / §48-12 の 3 が★★2 度書いた★★とおりである** ——
/// ★**認証の口は漏らさないが、★★作る口は避けられない★★。**
/// ★★**2026-09-01 訂正: 上の「認証の口は漏らさない」は★偽である**★★（**D134-2**）——
/// ★**状態コードでは漏らさないが、★★時間で漏れる★★**（★実測: ★在る 1526 ms / ★無い 1 ms。★どちらも 401）。
/// ★★**上の 1 行は 1 文字も書き換えない**★★（**D-35**）。★**正は `docs/同期設計メモ.md` §54-2 である。**
/// ★★**避ける形は在る**★★（★作れたかどうかを返さない）—— ★**採らない。★理由**:
/// ★**利用者が★自分の利用者名が使えたかを★★次に名乗るまで知れない★★。**
/// ★★**「漏れない」とは書かない。★対で固定する**★★（`test/account_endpoint_test.dart`）。
library;

import 'dart:convert';
import 'dart:io';

import 'account_file_store.dart';
import 'auth.dart';
import 'json_field.dart';
import 'password_hash.dart';

/// アカウントを作るパス（決定 **D133-9**）。
const String accountsPath = '/accounts';

/// 1 つの要求に答える（★待ち受けを知らない）。
///
/// ★★ [iterations] は★試験のためだけに開けてある ★★
/// ★**既定は本番の回数である**（**D129-5** の柵 1）。★**1 回 1.5 秒かかる**（★§45 の実測）ので、
/// ★**試験は下げて回す**（★`encodePasswordHash` の `iterations` と同じ作法）。
Future<void> handleAccountRequest(
  HttpRequest request,
  AccountFileStore store, {
  int iterations = passwordHashIterations,
}) async {
  if (request.method != 'POST') {
    await _write(request.response, HttpStatus.methodNotAllowed);
    return;
  }

  final String userName;
  final String password;
  try {
    final body = await utf8.decoder.bind(request).join();
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('★本文が表ではない');
    }
    userName = requireJsonString(decoded, 'userName');
    password = requireJsonString(decoded, 'password');
  } on FormatException {
    await _write(request.response, HttpStatus.badRequest);
    return;
  }

  // ★★ 空は断る（★長さの下限は決めない / 上の doc）★★
  if (userName.isEmpty || password.isEmpty) {
    await _write(request.response, HttpStatus.badRequest);
    return;
  }

  final record = AccountRecord(
    userName: userName,
    passwordHash: encodePasswordHash(
      password,
      salt: newSalt(),
      iterations: iterations,
    ),
  );

  try {
    store.add(record);
  } on StateError {
    // ★★ その利用者名は既に在る（**D130-9**）★★
    //   ★**存在が漏れる。★隠さない**（上の doc）。
    await _write(request.response, HttpStatus.conflict);
    return;
  }

  request.response
    ..statusCode = HttpStatus.created
    ..headers.contentType = ContentType.json
    ..write(jsonEncode({'ok': true, 'userName': record.userName}));
  await request.response.close();
}

Future<void> _write(HttpResponse response, int status) async {
  response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(jsonEncode({'ok': false}));
  await response.close();
}
