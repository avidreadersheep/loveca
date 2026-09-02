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

/// 預けるパス（★サーバー側の `decksPath` と同じ字面である）。
const String decksPutPath = '/decks';

/// ★★ 預けるときに名乗る「取ったときの印」の鍵（決定 **D141-1** / **D141-4**）★★
///
/// ★★ 省けない。★鍵そのものが無ければ★サーバーは 400 を返す ★★
/// ★**「無い」を「前提なし」に読ませない**（★★鍵を落とすだけで★黙って上書きできてしまう★★）。
const String syncExpectMarkKey = 'expectMark';

/// ★★ 応答が返す「いまの印」の鍵（決定 **D141-7**）★★
///
/// ★★ この値の中身を★1 バイトも解釈しない ★★
/// ★**サーバーが計算して返す**ので、★★アプリ側は★ハッシュを 1 度も計算しない★★。
/// → ★**`loveca_core` の `deckContentHash` と★★取り違えようが無い★★**（**§7-7** ＝ ★別物である）。
const String syncMarkKey = 'mark';

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

/// 同上。★1 つ取ったときの中身。★★預けるときにも同じ鍵で送る★★。
const String syncContentKey = 'content';

/// 同上。★★預ける口が返す「新しく預かったか」★★（★201 と 200 の違い）。
const String syncCreatedKey = 'created';

/// ★★ 取ってきたデッキ 1 つ —— ★中身と、★★そのときの印★★ ★★
///
/// ★★ 2 つを★1 つの値にする理由 ★★
/// ★**別々に返すと、★★片方だけを持ち回れる★★** —— ★★別のデッキの印を渡す事故が書ける★★。
/// ★**預ける口は★この [mark] を★そのまま名乗る**（★★中身を持たない字面である★★）。
typedef RemoteDeck = ({String content, String mark});

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

/// ★★ 取ったときの印が★合わなかった（★★預ける口だけが返す★★ / **D139-1** ＝ 線 β）★★
///
/// ★★ 「名乗れなかった」にも「通信の失敗」にも★畳まない ★★
/// ★**名乗りは通っている**（★合わなければ 401 が先に返る / **D141-6**）。
/// ★**サーバーも★正しく動いている**（★★断ったのは★正しい振る舞いである★★）。
/// → ★**畳むと★★「取り直して解き直せばよい」が★「パスワードを直せ」に化ける★★。**
///
/// ★★ この結果を受けて★何をするかは★ここに無い ★★
/// ★**再試行は★★0 回である★★**（**D141-3** ＝ 再-1）—— ★**この口は★★呼ぶ側へ返すだけ★★。**
/// ★**いつ取り直して★どう見せるかは★★§32-6 の 25 である★★**（★未着手）。
final class SyncStale<T> extends SyncOutcome<T> {
  const SyncStale();
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
  return postSyncRequest<List<String>>(
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
Future<SyncOutcome<RemoteDeck>> fetchRemoteDeck({
  required HttpClient client,
  required Uri server,
  required String userName,
  required String password,
  required String deckId,
}) async {
  return postSyncRequest<RemoteDeck>(
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
      final mark = decoded[syncMarkKey];
      // ★★ 印が欠けていたら★受け取らない ★★
      //   ★**受け取ると、★★預けるときに名乗れないまま先へ進む★★**（★★必ず 412 になる★★）。
      if (content is! String || mark is! String || mark.isEmpty) return null;
      return (content: content, mark: mark);
    },
    absentOnNotFound: true,
  );
}

/// ★★ デッキ 1 つを預ける（★§32-6 の **23** の★送る口）★★
///
/// ## ★★ [expectMark] は★必須である。★省けない（**D141-4**）★★
///
/// | 渡すもの | ★意味 |
/// |---|---|
/// | `null` | ★**まだ 1 つも預けていないはず**（★初回 / ★器の行が無い） |
/// | ★[RemoteDeck.mark] | ★**取ったときの印が★それだったはず** |
///
/// ★★**「省く」という選び方が★引数に無い**★★ —— ★**`required` にしてある。**
/// ★**渡し忘れると★★コンパイルが通らない★★**（★サーバー側の 400 に頼らない）。
///
/// ## ★★ 印は★取ってきた値を★そのまま渡す。★計算しない ★★
///
/// ★**サーバーが [fetchRemoteDeck] / この口の応答で★返した字面をそのまま渡す**（**D141-7**）。
/// ★★**`loveca_core` の `deckContentHash` を渡してはならない**★★（**§7-7** —— ★★別物である★★）。
/// → ★**アプリ側は★★ハッシュを 1 度も計算しない★★ので、★取り違えようが無い。**
///
/// ## ★★ 中身を 1 バイトも解釈しない（**D105-2**）★★
///
/// ★**文字列を★そのまま送る。★★`Deck` を組み立てない★★**（★組み立て方は未決 / **D116-2** の理由 3）。
///
/// ## ★★ 返るのは★預けたあとの [RemoteDeck] である ★★
///
/// ★**[RemoteDeck.content] は★送った字面そのもの**（★サーバーは 1 バイトも変えない）。
/// ★**[RemoteDeck.mark] は★★次に預けるときに名乗る印★★**（★★取り直さなくてよい★★）。
///
/// ★★ 投げない ★★
Future<SyncOutcome<RemoteDeck>> pushRemoteDeck({
  required HttpClient client,
  required Uri server,
  required String userName,
  required String password,
  required String deckId,
  required String content,
  required String? expectMark,
}) async {
  return postSyncRequest<RemoteDeck>(
    client: client,
    server: server,
    path: decksPutPath,
    body: <String, Object?>{
      syncUserNameKey: userName,
      syncPasswordKey: password,
      syncDeckIdKey: deckId,
      syncContentKey: content,
      // ★★ 鍵は★必ず送る（★`null` も★1 つの値である）★★
      syncExpectMarkKey: expectMark,
    },
    read: (decoded) {
      final mark = decoded[syncMarkKey];
      if (mark is! String || mark.isEmpty) return null;
      return (content: content, mark: mark);
    },
    staleOnPreconditionFailed: true,
    okOnCreated: true,
  );
}

/// 1 回の往復（★2 つの口が★同じ形を通る）。
///
/// ★★ [absentOnNotFound] —— ★404 の意味が★口ごとに違う ★★
/// ★**1 つ取る口の 404 は「★そのデッキが無い」**（★答えである）。
/// ★★**一覧の口に 404 は無い**★★ —— ★**空の一覧は 200 で返る**（★サーバー側の doc）。
/// → ★**一覧で 404 が返ったら★★それは「知らないパス」であり、★期待どおりでない★★。**
/// 同期の口を 1 つ投げる（★★答えの分け方は★ここ 1 本が持つ★★）。
///
/// ★★ ほかの同期の口も★この 1 本を通る ★★
/// ★**`device_client.dart` が★この関数を呼ぶ**（★§32-6 の **26** の 3 番目）。
/// ★★**別に書くと、★★401 / 429 / 壊れた応答の畳み方が★黙って食い違う★★**（**D-15** の規約 3）。
Future<SyncOutcome<T>> postSyncRequest<T>({
  required HttpClient client,
  required Uri server,
  required String path,
  required Map<String, Object?> body,
  required T? Function(Map<String, Object?> decoded) read,
  bool absentOnNotFound = false,
  bool staleOnPreconditionFailed = false,
  bool okOnCreated = false,
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
    // ★★ 412 —— ★取ったときの印が合わない（**D141-2**）★★
    //   ★**「名乗れなかった」にも「通信の失敗」にも畳まない**（★上の [SyncStale]）。
    if (staleOnPreconditionFailed &&
        response.statusCode == HttpStatus.preconditionFailed) {
      return SyncStale<T>();
    }
    // ★★ 201 —— ★新しく預かった（★預ける口だけが返す）★★
    //   ★**200 と同じ道を通す**（★下で本文を読む）。
    final created =
        okOnCreated && response.statusCode == HttpStatus.created;
    if (!created && response.statusCode != HttpStatus.ok) {
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
