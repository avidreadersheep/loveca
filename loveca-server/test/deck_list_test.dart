/// ★★ 預けているデッキの一覧を返す口（★§55-3 が「★★口が無い★★」と書いた分）★★
///
/// ★★ これは §32-6 の 20 の続きであって、★21 ではない ★★
/// ★**21 は「★★相手の版を取りに行く★★」で、★★呼ぶ側★★の話である**（`loveca-ui`）。
/// ★**この群はサーバー側だけを見る。★呼ぶ側は 1 行も無い。**
///
/// ★★ 本物の待ち受けに当てる（**D-10**）★★
/// ★試験用の証明書は `test/fixtures/tls/`（決定 **D131-7**）。
///
/// ★★ 回数を下げて回す ★★
/// ★**本番は 600000 回。★1 回 1.5 秒かかる**（★§54-2 の実測）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:loveca_server/loveca_server.dart';
import 'package:test/test.dart';

const _fixtureDir = 'test/fixtures/tls';
const _certPath = '$_fixtureDir/localhost-TEST-ONLY.cert.pem';
const _keyPath = '$_fixtureDir/localhost-TEST-ONLY.key.pem';

Future<({int status, String body})> _post(
  HttpClient client,
  int port,
  String path,
  Object? body, {
  String method = 'POST',
}) async {
  final request =
      await client.openUrl(method, Uri.parse('https://localhost:$port$path'));
  request.headers.contentType = ContentType.json;
  request.write(body is String ? body : jsonEncode(body));
  final response = await request.close();
  return (
    status: response.statusCode,
    body: await utf8.decoder.bind(response).join(),
  );
}

void main() {
  late Directory dir;
  late AccountFileStore accounts;
  late DeckFileStore decks;
  late HttpServer server;
  late HttpClient client;

  const user = 'みつき';
  const pass = 'ひみつ';
  const other = 'かおり';
  const otherPass = 'べつのひみつ';

  // ★★ 取ったときの印を★必ず名乗る（**D141-1**）★★
  //   ★**この群は★一覧を見る群であり、★上書きは 1 か所だけである**（★そこは `mark:` を渡す）。
  Map<String, Object?> put(String deckId, String content,
          {String userName = user,
          String password = pass,
          String? mark}) =>
      {
        'userName': userName,
        'password': password,
        'deckId': deckId,
        'content': content,
        deckExpectMarkKey: mark,
      };

  Map<String, Object?> list({String userName = user, String password = pass}) =>
      {'userName': userName, 'password': password};

  Future<List<String>> listIds(
      {String userName = user, String password = pass}) async {
    final res = await _post(client, server.port, decksListPath,
        list(userName: userName, password: password));
    expect(res.status, HttpStatus.ok);
    final decoded = jsonDecode(res.body) as Map<String, Object?>;
    return (decoded['deckIds']! as List<Object?>).cast<String>();
  }

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('loveca_deck_list_test');
    accounts = AccountFileStore.open(
        '${dir.path}${Platform.pathSeparator}accounts.json');
    decks =
        DeckFileStore(Directory('${dir.path}${Platform.pathSeparator}decks'));

    final context = SecurityContext()
      ..useCertificateChain(_certPath)
      ..usePrivateKey(_keyPath);
    server = await serveApi(
      context: context,
      store: accounts,
      decks: decks,
      accountIterations: 10,
      // ★★ 上限を外す —— ★この群は★★上限そのものを見ていない★★
      //   ★`accountIterations` を下げるのと同じ格である（★本番の既定は `defaultRateLimit`）。
      //   ★★上限を見る群は `test/rate_limit_test.dart` に在る★★。
      rateLimits: const RateLimitPolicySet.unlimited(),
    );

    final clientContext = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificates(_certPath);
    client = HttpClient(context: clientContext);

    // ★★ 名乗りを要求する口なので、★先に利用者を 2 人作る（★17-2 の口を通す）★★
    await _post(client, server.port, accountsPath,
        {'userName': user, 'password': pass});
    await _post(client, server.port, accountsPath,
        {'userName': other, 'password': otherPass});
  });

  tearDown(() async {
    client.close(force: true);
    await server.close(force: true);
    dir.deleteSync(recursive: true);
  });

  group('★★ 一覧を返す（★§55-3 の穴を塞ぐ）★★', () {
    test('★★ 前提: 1 つも預けていないときは★空の一覧が 200 で返る（★404 ではない）★★',
        () async {
      final res = await _post(client, server.port, decksListPath, list());
      expect(res.status, HttpStatus.ok);
      final decoded = jsonDecode(res.body) as Map<String, Object?>;
      expect(decoded['ok'], isTrue);
      expect(decoded['deckIds'], isEmpty);
    });

    test('1 つ預けると 1 件返る', () async {
      await _post(client, server.port, decksPath, put('d1', '{"n":1}'));
      expect(await listIds(), <String>['d1']);
    });

    test('3 つ預けると 3 件返る', () async {
      await _post(client, server.port, decksPath, put('d1', 'a'));
      await _post(client, server.port, decksPath, put('d2', 'b'));
      await _post(client, server.port, decksPath, put('d3', 'c'));
      expect(await listIds(), <String>['d1', 'd2', 'd3']);
    });

    test('★★ 上書きしても件数が増えない（★409 を使わない口である）★★', () async {
      await _post(client, server.port, decksPath, put('d1', 'a'));
      final again = await _post(client, server.port, decksPath,
          put('d1', 'b', mark: deckContentMark('a')));
      expect(again.status, HttpStatus.ok, reason: '★2 度目は 200（★201 ではない）');
      expect(await listIds(), <String>['d1']);
    });
  });

  group('★★ 並びは★字面の昇順である。★預けた順ではない ★★', () {
    test('預けた順が逆でも★同じ並びが返る', () async {
      await _post(client, server.port, decksPath, put('zzz', 'a'));
      await _post(client, server.port, decksPath, put('aaa', 'b'));
      await _post(client, server.port, decksPath, put('mmm', 'c'));
      expect(await listIds(), <String>['aaa', 'mmm', 'zzz']);
    });

    test(
        '★★ 対: 預ける順を変えても★並びは 1 つも変わらない（★保管した順を返していない）★★',
        () async {
      await _post(client, server.port, decksPath, put('aaa', 'a'));
      await _post(client, server.port, decksPath, put('zzz', 'b'));
      await _post(client, server.port, decksPath, put('mmm', 'c'));
      expect(await listIds(), <String>['aaa', 'mmm', 'zzz']);
    });

    test('★★ 対: 保管を直に読むと★足した順のままである（★並べているのは口ではなく保管である）★★',
        () async {
      // ★★ 口を通さず保管を直に叩く（★待ち受けを通さない）★★
      decks.putDeck(user, 'zzz', 'a', expect: const ExpectAbsent());
      decks.putDeck(user, 'aaa', 'b', expect: const ExpectAbsent());
      expect(decks.listDeckIds(user), <String>['aaa', 'zzz'],
          reason: '★並べているのは `listDeckIds` である');
    });
  });

  group('★★ 別の利用者のものは 1 件も返らない（決定 D105-3）★★', () {
    test('自分のだけが返る', () async {
      await _post(client, server.port, decksPath, put('mine', 'a'));
      await _post(client, server.port, decksPath,
          put('theirs', 'b', userName: other, password: otherPass));

      expect(await listIds(), <String>['mine']);
      expect(await listIds(userName: other, password: otherPass),
          <String>['theirs']);
    });

    test('★★ 対: 塞がなければ★相手の deckId が見える（★保管は 1 人 1 ファイルである）★★',
        () async {
      await _post(client, server.port, decksPath, put('mine', 'a'));
      await _post(client, server.port, decksPath,
          put('theirs', 'b', userName: other, password: otherPass));
      // ★★ 保管そのものが★利用者で分かれていることを直に見る ★★
      expect(decks.listDeckIds(user), <String>['mine']);
      expect(decks.listDeckIds(other), <String>['theirs']);
    });
  });

  group('★★ 中身を 1 バイトも返さない（決定 D105-2）★★', () {
    test('一覧の応答に★預けた字面が 1 文字も出ない', () async {
      const content = 'ØØ-この字面は一覧に出てはならない-ØØ';
      await _post(client, server.port, decksPath, put('d1', content));
      final res = await _post(client, server.port, decksListPath, list());
      expect(res.body, isNot(contains('この字面は一覧に出てはならない')));
      expect(res.body, contains('d1'), reason: '★deckId は出る（★陽性対照）');
    });
  });

  group('★★ 名乗り（決定 D105-3 / D130 の柵）★★', () {
    test('無い利用者名は 401', () async {
      final res = await _post(client, server.port, decksListPath,
          list(userName: 'いない', password: pass));
      expect(res.status, HttpStatus.unauthorized);
    });

    test('★★ 対: 在る利用者名 ＋ 違うパスワードも★同じ 401（★状態で分けない）★★', () async {
      final res = await _post(
          client, server.port, decksListPath, list(password: 'ちがう'));
      expect(res.status, HttpStatus.unauthorized);
    });

    test('空の利用者名は 400（★401 ではない）', () async {
      final res = await _post(
          client, server.port, decksListPath, list(userName: ''));
      expect(res.status, HttpStatus.badRequest);
    });

    test('空のパスワードは 400', () async {
      final res =
          await _post(client, server.port, decksListPath, list(password: ''));
      expect(res.status, HttpStatus.badRequest);
    });
  });

  group('★★ 要求の形 ★★', () {
    test('★★ deckId を送らなくてよい（★この口は要らない）★★', () async {
      final res = await _post(client, server.port, decksListPath,
          {'userName': user, 'password': pass});
      expect(res.status, HttpStatus.ok);
    });

    test('★★ 対: 返す口は★deckId を送らないと 400 である（★要求が違う）★★', () async {
      final res = await _post(client, server.port, decksFetchPath,
          {'userName': user, 'password': pass});
      expect(res.status, HttpStatus.badRequest);
    });

    test('余分な deckId を送っても 200（★見ていない）', () async {
      await _post(client, server.port, decksPath, put('d1', 'a'));
      final res = await _post(client, server.port, decksListPath,
          {'userName': user, 'password': pass, 'deckId': 'いない'});
      expect(res.status, HttpStatus.ok);
      final decoded = jsonDecode(res.body) as Map<String, Object?>;
      expect(decoded['deckIds'], <String>['d1']);
    });

    test('GET は 405', () async {
      // ★★ 本文を書かない —— ★GET に本文を載せると★接続がヘッダの前に閉じる（★実測）★★
      final res =
          await _post(client, server.port, decksListPath, '', method: 'GET');
      expect(res.status, HttpStatus.methodNotAllowed);
    });

    test('壊れた本文は 400', () async {
      final res =
          await _post(client, server.port, decksListPath, 'これは JSON ではない');
      expect(res.status, HttpStatus.badRequest);
    });
  });

  group('★★ 振り分け —— ★4 つのパスが 1 つずつ別の口へ行く（★接頭辞で吸わない）★★', () {
    test('★★ /decks/list が /decks に吸われない ★★', () async {
      // ★`/decks`（預ける口）は★`content` を要求する。★吸われていればここが 400 になる。
      final res = await _post(client, server.port, decksListPath, list());
      expect(res.status, HttpStatus.ok);
    });

    test('★★ 対: /decks は★content が無いと 400（★吸われた場合に出る答え）★★', () async {
      final res = await _post(client, server.port, decksPath, list());
      expect(res.status, HttpStatus.badRequest);
    });

    test('★★ 対: 知らないパスは 404（★一覧の口へ落ちない）★★', () async {
      final res = await _post(client, server.port, '/decks/listing', list());
      expect(res.status, HttpStatus.notFound);
    });

    test('★★ 対: /decks/fetch は★別の口である（★一覧を返さない）★★', () async {
      await _post(client, server.port, decksPath, put('d1', 'a'));
      final res = await _post(client, server.port, decksFetchPath,
          {'userName': user, 'password': pass, 'deckId': 'd1'});
      expect(res.status, HttpStatus.ok);
      final decoded = jsonDecode(res.body) as Map<String, Object?>;
      expect(decoded.containsKey('deckIds'), isFalse);
      expect(decoded['content'], 'a');
    });
  });
}
