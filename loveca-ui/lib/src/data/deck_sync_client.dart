/// ★★ 相手の版を取りに行く口（アプリ側）—— §32-6 の **21** の★口★ ★★
///
/// ★★ 口だけである。★呼ぶ側は 1 行も無い ★★
/// ★**いつ取りに行くか / ★取ったものをどう見せるかは★★この口の外である★★**
/// （★§32-6 の **23**（送信）／ **25**（見せる）—— ★どちらも未着手）。
/// ★**18 の口（`auth_client.dart`）と★同じ形を採った**（**D132-4**）。
///
/// ---
///
/// ## ★★ なぜ「送る前に取る」のか（決定 **D121-4** ＝ 主-1 の (A)）★★
///
/// ★**衝突を解くのは★★送信側★★である**（**D121-4**）。
/// → ★**解くには★相手の版が要る。★★送る前に取りに行く★★。**
///
/// ★★ 何を取るのか —— ★★内容そのものである★★（決定 **D124-7** ＝ 門 イ の (c)）★★
/// ★**「相手側が変わったか」を★★内容ハッシュで見る★★**（**D115-1**）。
/// → ★**サーバーは★ハッシュも目印も持たない**（★あれはアプリ側の量である / **D114-1**）。
/// → ★★**内容を受け取って、★こちらで固める。★それしか道が無い。**★★
///
/// ## ★★ 2 つの口を呼ぶ ★★
///
/// | 何 | パス | ★なぜ要るか |
/// |---|---|---|
/// | ★一覧 | `/decks/list` | ★★**どのデッキが預けてあるかを★知る手段が★他に無い**★★ |
/// | ★1 つ取る | `/decks/fetch` | ★**内容を受け取る**（★上の (c)） |
///
/// ★★**一覧だけでは足りない**★★ —— ★**`deckId` からは★中身が 1 ビットも分からない**。
/// ★★**取るだけでも足りない**★★ —— ★**こちらに無いデッキの `deckId` を★知りようが無い**。
///
/// ---
///
/// ## ★★ 名乗りは★要求ごとに運ぶ。★★「決めた」とは書かない ★★
///
/// ★**送るものは★パスワードそのものである**（**D130-10**）。
/// ★★**持ち越す仕組みは★1 つも決まっておらず、★実装も 0 行である**★★（**N-21** の (4)）。
/// → ★★**今日は★この形しか書きようが無い。★選んだのではない。**★★
///
/// ## ★★ 答えを 3 つに分ける（**D105-6** / **D132-6** と同じ形）★★
///
/// | 何 | ★なぜ分けるか |
/// |---|---|
/// | ★取れた | ★—— |
/// | ★名乗れなかった | ★**利用者名かパスワードが違う**（★★どちらかは分からない★★ / **D130** の柵） |
/// | ★★**通信が失敗した**★★ | ★★**2 つに畳むと「つながらなかった」が「パスワードが違う」に化ける**★★ |
///
/// ★★ 「そのデッキが無い」は★4 つ目である ★★
/// ★**サーバーは★404 で言う**（★口の doc / **D134-8**）。
/// → ★**「通信が失敗した」に畳まない** —— ★★**「まだ預けていない」は★★正しい答えである★★**
/// （★★これが分からないと★★初回の同期が書けない★★）。
///
/// ---
///
/// ## ★★ 中身を 1 バイトも解釈しない ★★
///
/// ★**取れた内容は★★文字列のまま返す★★**（★サーバーが★字面のまま預かって★字面のまま返す /
/// **D105-2**）。★**`Deck` に組み立てない** —— ★**組み立て方は★★決まっていない★★**
/// （★**D116-2** の理由 3 —— ★明示コンストラクタ / `fromJson` / `copyWith` のどれかは未決）。
///
/// ## ★★ やり取りの形は★2 か所に書かれる（**D126-3** が買った代償）★★
///
/// ★**`loveca_ui` → `loveca_server` は★★永久に 0 本★★である。**
/// → ★**パスと鍵の名前は★★サーバー側にも同じものが書かれている★★。★走査で見張る**
/// （`test/data/deck_sync_client_test.dart`）。
///
/// ## ★★ D43 を踏まない ★★
///
/// ★**D43**（UI にネットワーク取得の口を作らない）の理由は★★画像である★★。
/// ★★**この口は★画像を 1 バイトも運ばない**★★（★18 の口と同じ判定 / §50-8）。
library;

import 'dart:convert';
import 'dart:io';

/// 一覧のパス（★サーバー側の `decksListPath` と同じ字面である）。
///
/// ★★ サーバーの定数を★import しない（**D126-3**）★★
const String decksListPath = '/decks/list';

/// 1 つ取るパス（★サーバー側の `decksFetchPath` と同じ字面である / **D134-8**）。
const String decksFetchPath = '/decks/fetch';

/// 要求の鍵（★サーバー側と同じ字面）。
const String syncUserNameKey = 'userName';

/// 同上。
const String syncPasswordKey = 'password';

/// 同上。
const String syncDeckIdKey = 'deckId';

/// 応答の鍵（★サーバー側と同じ字面）。
const String syncOkKey = 'ok';

/// 同上。★一覧が返す `deckId` の列。
const String syncDeckIdsKey = 'deckIds';

/// 同上。★1 つ取ったときの中身。
const String syncContentKey = 'content';

/// 取りに行った結果（★取るもので中身が違うので★型引数を持つ）。
sealed class SyncOutcome<T> {
  const SyncOutcome();
}

/// 取れた。
final class SyncOk<T> extends SyncOutcome<T> {
  const SyncOk(this.value);

  final T value;
}

/// 名乗れなかった。
///
/// ★★ 理由を持たない ★★
/// ★**サーバーが「利用者名が無い」と「パスワードが違う」を区別しない**（**D130** の柵）。
final class SyncRejected<T> extends SyncOutcome<T> {
  const SyncRejected();
}

/// そのデッキがサーバーに無い（★★1 つ取る口だけが返す★★）。
///
/// ★★ 通信の失敗に畳まない ★★
/// ★**「まだ預けていない」は★★正しい答えである★★**（★上の doc）。
final class SyncAbsent<T> extends SyncOutcome<T> {
  const SyncAbsent();
}

/// つながらなかった / 応答が期待どおりでない。
final class SyncUnreachable<T> extends SyncOutcome<T> {
  const SyncUnreachable(this.reason);

  /// ★**利用者に出すためではなく、★診断のために持つ**（★見せ方は §32-6 の **25**）。
  final String reason;
}

/// 預けているデッキの `deckId` を取りに行く（★§32-6 の **21**）。
///
/// ★★ [client] と [server] は★呼び出し側から渡す（**D132-4** と同じ形）★★
/// ★**[server] は★★住所だけ★★である**（★パスはこのファイルが持つ）。
///
/// ★★ 投げない ★★
Future<SyncOutcome<List<String>>> fetchRemoteDeckIds({
  required HttpClient client,
  required Uri server,
  required String userName,
  required String password,
}) async {
  return _post<List<String>>(
    client: client,
    server: server,
    path: decksListPath,
    body: <String, Object?>{
      syncUserNameKey: userName,
      syncPasswordKey: password,
    },
    read: (decoded) {
      final ids = decoded[syncDeckIdsKey];
      if (ids is! List<Object?>) return null;
      final out = <String>[];
      for (final id in ids) {
        if (id is! String) return null;
        out.add(id);
      }
      return out;
    },
  );
}

/// 預けているデッキ 1 つの中身を取りに行く（★§32-6 の **21**）。
///
/// ★★ 返るのは★文字列である。★`Deck` に組み立てない ★★
/// ★**組み立て方は★★決まっていない★★**（**D116-2** の理由 3）。
Future<SyncOutcome<String>> fetchRemoteDeck({
  required HttpClient client,
  required Uri server,
  required String userName,
  required String password,
  required String deckId,
}) async {
  return _post<String>(
    client: client,
    server: server,
    path: decksFetchPath,
    body: <String, Object?>{
      syncUserNameKey: userName,
      syncPasswordKey: password,
      syncDeckIdKey: deckId,
    },
    read: (decoded) {
      final content = decoded[syncContentKey];
      return content is String ? content : null;
    },
    absentOnNotFound: true,
  );
}

/// 1 回の往復（★2 つの口が★同じ形を通る）。
///
/// ★★ [absentOnNotFound] —— ★404 の意味が★口ごとに違う ★★
/// ★**1 つ取る口の 404 は「★そのデッキが無い」**（★答えである）。
/// ★★**一覧の口に 404 は無い**★★ —— ★**空の一覧は 200 で返る**（★サーバー側の doc）。
/// → ★**一覧で 404 が返ったら★★それは「知らないパス」であり、★期待どおりでない★★。**
Future<SyncOutcome<T>> _post<T>({
  required HttpClient client,
  required Uri server,
  required String path,
  required Map<String, Object?> body,
  required T? Function(Map<String, Object?> decoded) read,
  bool absentOnNotFound = false,
}) async {
  try {
    final request = await client.postUrl(server.replace(path: path));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close();
    final raw = await utf8.decoder.bind(response).join();

    if (response.statusCode == HttpStatus.unauthorized) {
      return SyncRejected<T>();
    }
    if (absentOnNotFound && response.statusCode == HttpStatus.notFound) {
      return SyncAbsent<T>();
    }
    if (response.statusCode != HttpStatus.ok) {
      // ★400 / 404 / 405 / 429 / 5xx —— ★★どれも「サーバーが期待どおりでない」★★。
      //   ★**400 を「名乗れなかった」に畳まない**（★送り手の作りが違う / **D131-6**）。
      return SyncUnreachable<T>('状態 ${response.statusCode}');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return SyncUnreachable<T>('応答が JSON ではない');
    }
    if (decoded is! Map<String, Object?>) {
      return SyncUnreachable<T>('応答が表ではない');
    }
    if (decoded[syncOkKey] != true) {
      return SyncUnreachable<T>('200 だが ok が真でない');
    }
    final value = read(decoded);
    if (value == null) return SyncUnreachable<T>('応答の中身が期待どおりでない');
    return SyncOk<T>(value);
  } on Object catch (e) {
    // ★★ つながらない / 証明書が信頼できない / 途中で切れた ★★
    //   ★**投げずに返す**（**D105-6**）。
    return SyncUnreachable<T>('$e');
  }
}
