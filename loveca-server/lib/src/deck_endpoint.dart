/// ★★ デッキを預かる / 返す口 —— §32-6 の **20**（決定 **D134-8** / **D134-9**）★★
///
/// ★★ これが★§32-6 の 20 である ★★
/// ★**§52-12 は「★**D104** の札 ＋ ★デッキの保管」の 2 つ待ちと書いていた**（★実読）。
/// → ★**当て直した**（**D-15 (l)** / `docs/同期設計メモ.md` §54-9）——
/// ★**札は「★★動かす前★★」であって「★書く前」ではない**（**D133-5** と同じ形）／
/// ★**保管は★この回で決めた**（**D134-6**）。
///
/// ---
///
/// ## ★★ 【要確認/法務】D104 の札が★発火している（**D133-5** / **§35-6**）★★
///
/// ★★**ここが「★デッキが★他人の機械へ渡る★最初の瞬間」である**★★（★§35-6 が名指しした箇所）。
/// → ★★**この口を★★動かす★★前に、★利用者が★**D104** を引き直すかを判断すること。**★★
/// ★**書く前ではない** —— ★**証明書が無ければ待ち受けが立たず、★★デッキは 1 バイトも渡らない★★**
/// （**D133-3** の柵）。
///
/// ## ★★ **N-26**（門 セ）—— ★★1 回 1.5 秒かかる。★塞いでいない ★★
///
/// ★★**預ける / 返すの★毎回★★固める処理が回る★★**★★（★名乗りを★要求ごとに運ぶため）。
/// ★**実測は 1.5 秒である**（`docs/同期設計メモ.md` §54-2 —— ★本番の回数 600000）。
/// ★★**そのあいだ★この待ち受けは★他の要求に 1 つも答えない**★★（★実測）。
/// → ★**呼ばれる回数に上限を置くかは★★未決である★★**（**N-26** ＝ ★門 セ。★★中心は利用者判断★★）。
/// ★★**塞がない**★★ —— ★**決まっていない分岐を先に置かない**（**D114-7** の理由 2）。
///
/// ---
///
/// ## ★★ 名乗りは★要求ごとに運ぶ。★★「決めた」とは書かない ★★
///
/// ★**送るものは★パスワードそのものである**（**D130-10**）。
/// ★★**持ち越す仕組みは★1 つも決まっておらず、★実装も 0 行である**★★（**N-21** の (4)）。
/// → ★★**今日は★この形しか書きようが無い。★選んだのではない。**★★
///
/// ## ★★ 口の細目（決定 **D134-8**）★★
///
/// | 何 | 決めたこと | ★なぜ |
/// |---|---|---|
/// | ★パス（預ける） | ★`/decks` | ★**D130-7**（★パスで分ける） |
/// | ★パス（返す） | ★`/decks/fetch` | ★**本文に名乗りが入るので★POST を 2 つに分ける**（★GET は本文を運ばない） |
/// | ★メソッド | ★**POST**（★2 つとも） | ★**17-2 と同じ** —— ★★パスワードを URL に載せない★★ |
///
/// ★★**2026-09-01 追記: ★口が 3 つになった**★★ —— ★**`/decks/list`**（★上の [decksListPath]）。
/// ★★**上の表は 1 文字も書き換えない**★★（**D-35** —— ★書いた時点では正しい）。
/// ★**メソッドも状態コードの分け方も★3 つとも同じである**（★対で固定した）。
///
/// ### ★ 状態コード
///
/// | 状態 | 何 | ★なぜ |
/// |---|---|---|
/// | ★**201** | ★新しく預かった | ★**17-2 の 201 と★語を揃える** |
/// | ★**200** | ★上書きした / ★返せた | ★—— |
/// | ★**400** | ★壊れた要求 / ★空 | ★**D131-6** と同じ分け方（★400 は「送り手の作りが違う」） |
/// | ★**401** | ★名乗りが通らない | ★**16 と同じ**（**D105-3**）。★★**在る利用者名と無い利用者名を★状態で分けない**★★ |
/// | ★**404** | ★そのデッキが無い | ★**返す口だけ**。★知らないパスの 404 と★本文で分けない（★呼んだ側が知っている） |
/// | ★**405** | ★メソッド違い | ★**17-2 と同じ** |
///
/// ### ★★ 409 を使わない —— ★★17-2 とは意味が違う ★★ ★★
///
/// ★**17-2 の 409 は「★その利用者名は既に在る」である**（**D130-9** —— ★★一意性を保つ★★）。
/// ★★**こちらは★上書きが正しい**★★ —— ★**同じデッキを★何度でも預ける**（★それが同期である）。
/// → ★★**同型としてまとめない**★★（`docs/同期設計メモ.md` §7-7）。★**対で固定する**。
///
/// ### ★★ 空は断る。★長さの下限は決めない（**D133-9** をそのまま持ち込む）★★
///
/// ★**空の利用者名 / パスワード / `deckId` / `content` は 400 である。**
/// ★★**`content` の空を断る理由は★他の 3 つと違う**★★ ——
/// ★**あちらは「★名乗りが無い」（**D105-3** が成り立たない）、
/// ★★こちらは「★預けるものが無い」★★**（★★中身を見ないので★空かどうかしか判定できない★★）。
library;

import 'dart:convert';
import 'dart:io';

import 'account_file_store.dart';
import 'auth.dart';
import 'deck_store.dart';
import 'json_field.dart';

/// デッキを預けるパス（決定 **D134-8**）。
const String decksPath = '/decks';

/// デッキを返すパス（決定 **D134-8**）。
const String decksFetchPath = '/decks/fetch';

/// 預けているデッキの一覧を返すパス。
///
/// ★★ §55-3 が「★★一覧を返す口が無い★★」と書いた分である ★★
/// ★**呼ぶ側は「★どのデッキが預けてあるか」を★★知りようが無かった★★。**
/// → ★**§32-6 の **21**（★相手の版を取りに行く）が★これを要る**（**D124-7** ＝ 門 イ の (c)
/// ★★—— ★相手の★内容★を受け取って比べる。★★受け取る前に★何が在るかを知る要がある★★）。
///
/// ★★ 返すのは `deckId` だけである（★中身も★件数以外の量も返さない）★★
/// ★**サーバーは★内容ハッシュも★目印も持たない**（**D114-1** / **D124-7** —— ★あれはアプリ側の量）。
/// → ★★**返せるものが★`deckId` しか無い。★選んだのではない。**★★
const String decksListPath = '/decks/list';

/// ★★ 預ける口が要求する鍵 —— ★★取ったときの印★★（**D141-1**）★★
///
/// ★**鍵そのものが無ければ★400 である**（★下の `_readPrecondition`）。
/// ★**アプリ側にも★同じ字面が在る**（`loveca-ui/.../deck_sync_client.dart` / **D126-3** の代償）。
const String deckExpectMarkKey = 'expectMark';

/// 預ける口に 1 つ答える（★待ち受けを知らない）。
Future<void> handleDeckPutRequest(
  HttpRequest request,
  AccountFileStore accounts,
  DeckFileStore decks,
) async {
  final parsed = await _parse(request, needsContent: true);
  if (parsed == null) return;

  if (!_authorized(parsed, accounts)) {
    await writeDeckStatus(request.response, HttpStatus.unauthorized);
    return;
  }

  final result = decks.putDeck(
    parsed.userName,
    parsed.deckId,
    parsed.content!,
    expect: parsed.expect!,
  );

  // ★★ 印が合わなければ★断る（**D139-1** ＝ 線 β / ★状態は 412 / **D141-2**）★★
  //   ★**サーバーは★★衝突を 1 つも解かない★★。★解くのは依然アプリ側である**（**D121-4** ＝ 主-1）。
  if (result == DeckPutResult.preconditionFailed) {
    await writeDeckStatus(request.response, HttpStatus.preconditionFailed);
    return;
  }

  final isNew = result == DeckPutResult.created;
  request.response
    ..statusCode = isNew ? HttpStatus.created : HttpStatus.ok
    ..headers.contentType = ContentType.json
    ..write(jsonEncode({'ok': true, 'deckId': parsed.deckId, 'created': isNew}));
  await request.response.close();
}

/// 返す口に 1 つ答える（★待ち受けを知らない）。
Future<void> handleDeckFetchRequest(
  HttpRequest request,
  AccountFileStore accounts,
  DeckFileStore decks,
) async {
  final parsed = await _parse(request, needsContent: false);
  if (parsed == null) return;

  if (!_authorized(parsed, accounts)) {
    await writeDeckStatus(request.response, HttpStatus.unauthorized);
    return;
  }

  final content = decks.fetchDeck(parsed.userName, parsed.deckId);
  if (content == null) {
    await writeDeckStatus(request.response, HttpStatus.notFound);
    return;
  }

  request.response
    ..statusCode = HttpStatus.ok
    ..headers.contentType = ContentType.json
    ..write(jsonEncode({'ok': true, 'deckId': parsed.deckId, 'content': content}));
  await request.response.close();
}

/// 一覧の口に 1 つ答える（★待ち受けを知らない）。
///
/// ★★ `deckId` を要らない ★★
/// ★**名乗りだけで答えられる**ので、★[_parse] に★`deckId` を要求させない。
///
/// ★★ 空の一覧は 200 である。★404 にしない ★★
/// ★**「1 つも預けていない」は★★答えであって★不在ではない★★。**
/// ★**返す口の 404 は「★★そのデッキが無い★★」で、★★意味が違う★★**（`docs/同期設計メモ.md` §7-7）。
Future<void> handleDeckListRequest(
  HttpRequest request,
  AccountFileStore accounts,
  DeckFileStore decks,
) async {
  final parsed = await _parse(request, needsContent: false, needsDeckId: false);
  if (parsed == null) return;

  if (!_authorized(parsed, accounts)) {
    await writeDeckStatus(request.response, HttpStatus.unauthorized);
    return;
  }

  request.response
    ..statusCode = HttpStatus.ok
    ..headers.contentType = ContentType.json
    ..write(jsonEncode({
      'ok': true,
      'deckIds': decks.listDeckIds(parsed.userName),
    }));
  await request.response.close();
}

class _DeckRequest {
  const _DeckRequest(
    this.userName,
    this.password,
    this.deckId,
    this.content,
    this.expect,
  );

  final String userName;
  final String password;
  final String deckId;
  final String? content;

  /// ★★ 預ける口だけが持つ（★返す口 / 一覧の口では `null`）★★
  final DeckPrecondition? expect;
}

/// ★★ 名乗りは★要求ごとに運ぶ（★上の doc）★★
///
/// ★**在る利用者名と無い利用者名を★状態で分けない**（**D130** の柵）。
/// ★★**ただし★時間では分かれる**★★（★`authenticate` の早い戻り / `docs/同期設計メモ.md` §54-2）——
/// ★**塞ぐかは **N-26** の (3) である。★この口では塞いでいない。**
bool _authorized(_DeckRequest parsed, AccountFileStore accounts) =>
    authenticate(
      AuthRequest(userName: parsed.userName, password: parsed.password),
      accounts,
    ) is AuthSuccess;

/// 壊れた要求 / 空を断る（★断ったら `null` を返し、★応答は書き終えている）。
Future<_DeckRequest?> _parse(
  HttpRequest request, {
  required bool needsContent,
  bool needsDeckId = true,
}) async {
  if (request.method != 'POST') {
    await writeDeckStatus(request.response, HttpStatus.methodNotAllowed);
    return null;
  }

  final String userName;
  final String password;
  String deckId = '';
  String? content;
  DeckPrecondition? expect;
  try {
    final body = await utf8.decoder.bind(request).join();
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('★本文が表ではない');
    }
    userName = requireJsonString(decoded, 'userName');
    password = requireJsonString(decoded, 'password');
    if (needsDeckId) deckId = requireJsonString(decoded, 'deckId');
    if (needsContent) content = requireJsonString(decoded, 'content');
    if (needsContent) expect = _readPrecondition(decoded);
  } on FormatException {
    await writeDeckStatus(request.response, HttpStatus.badRequest);
    return null;
  }

  // ★★ 空は断る（★長さの下限は決めない / **D133-9** をそのまま持ち込む）★★
  final empty = userName.isEmpty ||
      password.isEmpty ||
      (needsDeckId && deckId.isEmpty) ||
      (needsContent && content!.isEmpty);
  if (empty) {
    await writeDeckStatus(request.response, HttpStatus.badRequest);
    return null;
  }

  return _DeckRequest(userName, password, deckId, content, expect);
}

/// ★★ 取ったときの印を読む（**D141-1** / **D141-4**）★★
///
/// ## ★★ 鍵が★無い★のと、★`null` である★のを★分ける ★★
///
/// | 送られたもの | ★意味 |
/// |---|---|
/// | ★★**鍵そのものが無い**★★ | ★★**壊れた要求である（400）**★★ —— ★**呼ぶ側が★前提を名乗っていない** |
/// | `null` | ★**まだ 1 つも預けていないはず**（★初回） |
/// | ★16 進の文字列 | ★**取ったときの印が★それだったはず** |
///
/// ★★**「無い」を「前提なし」に読まない**★★ ——
/// ★**読むと、★★鍵を落とすだけで★黙って上書きできる★★**（★★塞ぎたいものがそのまま残る★★）。
/// → ★**鍵が無ければ★400 である**（★対で固定した）。
DeckPrecondition _readPrecondition(Map<String, Object?> decoded) {
  if (!decoded.containsKey(deckExpectMarkKey)) {
    throw const FormatException('★取ったときの印が名乗られていない');
  }
  final raw = decoded[deckExpectMarkKey];
  if (raw == null) return const ExpectAbsent();
  if (raw is! String || raw.isEmpty) {
    throw const FormatException('★印が文字列でない / 空である');
  }
  return ExpectMark(raw);
}

/// 本文を持たない応答（★理由を 1 つも持たない / **D130** の柵）。
Future<void> writeDeckStatus(HttpResponse response, int status) async {
  response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(jsonEncode({'ok': false}));
  await response.close();
}
