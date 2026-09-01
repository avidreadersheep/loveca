/// ★★ デッキを預かる / 返す口 —— §32-6 の **20**（決定 **D134-6** / **D134-7** / **D134-8**）★★
///
/// ★★ 本物の待ち受けに当てる（**D-10**）★★
/// ★試験用の証明書は `test/fixtures/tls/`（決定 **D131-7**）。
///
/// ★★ 回数を下げて回す ★★
/// ★**アカウントは★試験の中で作る**（★`accountIterations` を下げる）。
/// ★**名乗りの検証は★保管した値の回数に従う**ので、★下げた回数がそのまま効く。
///
/// ★★ 17-2 と食い違わないことを★実測で確かめる（★指示）★★
/// ★**空の扱い**（★400）／ ★**409**（★★こちらは使わない★★）／ ★**パス**（★重ならない）を
/// ★**この群が★1 つずつ固定する。**
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

  Map<String, Object?> put(String deckId, String content,
          {String userName = user, String password = pass}) =>
      {
        'userName': userName,
        'password': password,
        'deckId': deckId,
        'content': content,
      };

  Map<String, Object?> fetch(String deckId,
          {String userName = user, String password = pass}) =>
      {'userName': userName, 'password': password, 'deckId': deckId};

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('loveca_deck_endpoint_test');
    accounts = AccountFileStore.open(
        '${dir.path}${Platform.pathSeparator}accounts.json');
    decks = DeckFileStore(
        Directory('${dir.path}${Platform.pathSeparator}decks'));

    final context = SecurityContext()
      ..useCertificateChain(_certPath)
      ..usePrivateKey(_keyPath);
    server = await serveApi(
      context: context,
      store: accounts,
      decks: decks,
      // ★★ 本番は 600000 回。★試験は下げる（★1 回 1.5 秒かかる / §54-2）★★
      accountIterations: 10,
      // ★★ 上限を外す —— ★この群は★★上限そのものを見ていない★★
      //   ★`accountIterations` を下げるのと同じ格である（★本番の既定は `defaultRateLimit`）。
      //   ★★上限を見る群は `test/rate_limit_test.dart` に在る★★。
      rateLimit: const RateLimitPolicy.unlimited(),
    );

    final clientContext = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificates(_certPath);
    client = HttpClient(context: clientContext);

    // ★★ この口は★名乗りを要求するので、★先にアカウントを作る（★17-2 の口を通す）★★
    await _post(client, server.port, accountsPath,
        {'userName': user, 'password': pass});
  });

  tearDown(() async {
    client.close(force: true);
    await server.close(force: true);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('★★ 預かる（決定 D134-8）★★', () {
    test('★ 新しく預かったら 201', () async {
      final res = await _post(client, server.port, decksPath, put('d1', 'AAA'));

      expect(res.status, 201);
      expect(jsonDecode(res.body), {'ok': true, 'deckId': 'd1', 'created': true});
    });

    test('★★ 2 度目は 200（★★409 ではない★★ / 上書きが正しい）★★', () async {
      // ★★ 17-2 の 409 と★意味が違う（§7-7）★★
      //   ★**同じデッキを何度でも預ける。★それが同期である。**
      await _post(client, server.port, decksPath, put('d1', 'AAA'));

      final res = await _post(client, server.port, decksPath, put('d1', 'BBB'));

      expect(res.status, 200);
      expect(res.status, isNot(409));
    });

    test('★★ 対: 17-2 は同じ入力で 409 を返す（★★口ごとに意味が違う★★）★★', () async {
      // ★★ これが無いと「409 を使わない」は★★何も見ていない★★ ★★
      //   ★同じ「2 度目」でも、★作る口は断り、★預ける口は上書きする。
      final again = await _post(client, server.port, accountsPath,
          {'userName': user, 'password': pass});

      expect(again.status, 409);
    });

    test('★★ 預けたら★保管に残る（★開き直しても在る）★★', () async {
      await _post(client, server.port, decksPath, put('d1', 'AAA'));

      final reopened = DeckFileStore(
          Directory('${dir.path}${Platform.pathSeparator}decks'));
      expect(reopened.fetchDeck(user, 'd1'), 'AAA');
    });
  });

  group('★★ 返す（決定 D134-8）★★', () {
    test('★ 預けたものが★字面のまま返る（★D105-2: 中身を見ない）', () async {
      // ★★ JSON でない字面でも★そのまま返る（★保管庫は判断しない）★★
      const content = 'これは JSON ではない  でも預かる';
      await _post(client, server.port, decksPath, put('d1', content));

      final res =
          await _post(client, server.port, decksFetchPath, fetch('d1'));

      expect(res.status, 200);
      expect(jsonDecode(res.body)['content'], content);
    });

    test('★★ 上書きしたら★新しいほうが返る ★★', () async {
      await _post(client, server.port, decksPath, put('d1', 'AAA'));
      await _post(client, server.port, decksPath, put('d1', 'BBB'));

      final res =
          await _post(client, server.port, decksFetchPath, fetch('d1'));

      expect(jsonDecode(res.body)['content'], 'BBB');
    });

    test('★ 預けていないデッキは 404', () async {
      final res =
          await _post(client, server.port, decksFetchPath, fetch('いない'));

      expect(res.status, 404);
    });

    test('★★ 対: 預ける前は 404 で、★預けたあとは 200 ★★', () async {
      // ★★ 上が「いつでも 404」で通らないこと（**D-10**）★★
      final before =
          await _post(client, server.port, decksFetchPath, fetch('d1'));
      await _post(client, server.port, decksPath, put('d1', 'AAA'));
      final after =
          await _post(client, server.port, decksFetchPath, fetch('d1'));

      expect(before.status, 404);
      expect(after.status, 200);
    });
  });

  group('★★ 誰のデッキかを分ける（決定 D105-3）★★', () {
    test('★★ 別の利用者のデッキは★見えない（404）★★', () async {
      await _post(client, server.port, accountsPath,
          {'userName': 'ほのか', 'password': 'べつ'});
      await _post(client, server.port, decksPath, put('d1', 'AAA'));

      final res = await _post(client, server.port, decksFetchPath,
          fetch('d1', userName: 'ほのか', password: 'べつ'));

      expect(res.status, 404);
    });

    test('★★ 同じ `deckId` を★別々の利用者が持てる（★混ざらない）★★', () async {
      await _post(client, server.port, accountsPath,
          {'userName': 'ほのか', 'password': 'べつ'});
      await _post(client, server.port, decksPath, put('d1', 'みつきの'));
      await _post(client, server.port, decksPath,
          put('d1', 'ほのかの', userName: 'ほのか', password: 'べつ'));

      final mine = await _post(client, server.port, decksFetchPath, fetch('d1'));
      final theirs = await _post(client, server.port, decksFetchPath,
          fetch('d1', userName: 'ほのか', password: 'べつ'));

      expect(jsonDecode(mine.body)['content'], 'みつきの');
      expect(jsonDecode(theirs.body)['content'], 'ほのかの');
    });

    test('★★ パスワードが違えば 401（★預ける側）★★', () async {
      final res = await _post(
          client, server.port, decksPath, put('d1', 'AAA', password: 'ちがう'));

      expect(res.status, 401);
      expect(decks.countFor(user), 0);
    });

    test('★★ 無い利用者名も 401（★★状態で分けない★★）★★', () async {
      final taken = await _post(
          client, server.port, decksPath, put('d1', 'AAA', password: 'ちがう'));
      final absent = await _post(client, server.port, decksPath,
          put('d1', 'AAA', userName: 'いない', password: 'x'));

      // ★★ 状態コードは同じ ＝ 存在が漏れない ★★
      //   ★★**ただし★時間では漏れる**★★（★**D134-2** / §54-2）——
      //   ★**この群は時間を測っていない**（★**D-28**: 測っていないものを固定しない）。
      expect(taken.status, 401);
      expect(absent.status, 401);
    });

    test('★★ 名乗れなければ★返す口も 401（★404 に化けない）★★', () async {
      // ★★ 401 と 404 を取り違えると「無い」と「見えない」が混ざる ★★
      await _post(client, server.port, decksPath, put('d1', 'AAA'));

      final res = await _post(client, server.port, decksFetchPath,
          fetch('d1', password: 'ちがう'));

      expect(res.status, 401);
    });
  });

  group('★★ 空は断る。★長さの下限は決めない（D133-9 をそのまま持ち込む）★★', () {
    test('★ 空のパスワードは 400（★401 ではない）', () async {
      final res = await _post(
          client, server.port, decksPath, put('d1', 'AAA', password: ''));

      expect(res.status, 400);
    });

    test('★ 空の利用者名は 400', () async {
      final res = await _post(
          client, server.port, decksPath, put('d1', 'AAA', userName: ''));

      expect(res.status, 400);
    });

    test('★ 空の deckId は 400', () async {
      final res = await _post(client, server.port, decksPath, put('', 'AAA'));

      expect(res.status, 400);
    });

    test('★★ 空の content は 400（★預けるものが無い）★★', () async {
      final res = await _post(client, server.port, decksPath, put('d1', ''));

      expect(res.status, 400);
      expect(decks.countFor(user), 0);
    });

    test('★★ 対: 1 文字なら通る（★長さの下限を決めていない）★★', () async {
      final res = await _post(client, server.port, decksPath, put('a', 'b'));

      expect(res.status, 201);
    });
  });

  group('★★ 壊れた要求（決定 D131-6 と同じ分け方）★★', () {
    test('★ JSON でなければ 400', () async {
      final res =
          await _post(client, server.port, decksPath, 'これは JSON ではない');

      expect(res.status, 400);
    });

    test('★ 鍵が無ければ 400（★預ける側は content も要る）', () async {
      final res = await _post(client, server.port, decksPath, fetch('d1'));

      expect(res.status, 400);
    });

    test('★★ 返す側は content を要らない ★★', () async {
      // ★★ 上の 400 が「いつでも 400」で通らないこと ★★
      await _post(client, server.port, decksPath, put('d1', 'AAA'));

      final res =
          await _post(client, server.port, decksFetchPath, fetch('d1'));

      expect(res.status, 200);
    });

    test('★ メソッドが違えば 405（★2 つとも）', () async {
      final a = await _post(client, server.port, decksPath, '', method: 'GET');
      final b =
          await _post(client, server.port, decksFetchPath, '', method: 'GET');

      expect(a.status, 405);
      expect(b.status, 405);
    });

    test('★★ 400 のときは★1 件も預からない ★★', () async {
      await _post(client, server.port, decksPath, 'これは JSON ではない');

      expect(decks.countFor(user), 0);
    });
  });

  group('★★ 同じ口。★パスで分ける（決定 D130-7）★★', () {
    test('★★ 1 つの待ち受けが★4 つのパスを持つ ★★', () async {
      final made = await _post(client, server.port, accountsPath,
          {'userName': 'あたらしい', 'password': 'x'});
      final named = await _post(
          client, server.port, authPath, {'userName': user, 'password': pass});
      final stored =
          await _post(client, server.port, decksPath, put('d1', 'AAA'));
      final got =
          await _post(client, server.port, decksFetchPath, fetch('d1'));

      expect(made.status, 201);
      expect(named.status, 200);
      expect(stored.status, 201);
      expect(got.status, 200);
    });

    test('★★ 知らないパスは 404（★静かに 200 を返さない）★★', () async {
      final res =
          await _post(client, server.port, '/decks/しらない', put('d1', 'AAA'));

      expect(res.status, 404);
    });

    test('★★ 預ける口と返す口は★別である（★対）★★', () async {
      // ★★ 振り分けが壊れていたら★同じ状態になる ★★
      final stored =
          await _post(client, server.port, decksPath, put('d1', 'AAA'));
      final got = await _post(client, server.port, decksFetchPath, fetch('d2'));

      expect(stored.status, 201);
      expect(got.status, 404);
    });
  });

  group('★★ 保管の柵（決定 D134-7）★★', () {
    test('★★ 利用者名は★ファイル名にならない ★★', () async {
      // ★★ 名前に区切りを入れても★別の場所を指さない ★★
      //   ★**利用者名は★呼ぶ側が決める**（**D133-4** ＝ 誰でも作れる）。
      const evil = '../../そとへ';
      await _post(client, server.port, accountsPath,
          {'userName': evil, 'password': 'x'});
      await _post(client, server.port, decksPath,
          put('d1', 'AAA', userName: evil, password: 'x'));

      final deckDir = Directory('${dir.path}${Platform.pathSeparator}decks');
      final names = deckDir
          .listSync()
          .map((e) => e.uri.pathSegments.last)
          .toList();

      expect(names, hasLength(1));
      expect(names.single, matches(RegExp(r'^[0-9a-f]{64}\.json$')));
    });

    test('★★ 利用者名は★ファイルの中に残る（★戻せる）★★', () async {
      await _post(client, server.port, decksPath, put('d1', 'AAA'));

      final deckDir = Directory('${dir.path}${Platform.pathSeparator}decks');
      final saved =
          (deckDir.listSync().single as File).readAsStringSync();

      expect(jsonDecode(saved)['userName'], user);
    });

    test('★★ 利用者ごとに★別のファイルになる ★★', () async {
      await _post(client, server.port, accountsPath,
          {'userName': 'ほのか', 'password': 'べつ'});
      await _post(client, server.port, decksPath, put('d1', 'AAA'));
      await _post(client, server.port, decksPath,
          put('d1', 'BBB', userName: 'ほのか', password: 'べつ'));

      final deckDir = Directory('${dir.path}${Platform.pathSeparator}decks');
      expect(deckDir.listSync(), hasLength(2));
    });

    test('★★ 一時ファイルが残らない（★書き終えたら消えている）★★', () async {
      // ★★ この 1 件だけでは★★一時ファイルを使っていることを見ていない★★ ★★
      //   ★**直に書く実装でも★`.tmp` は残らない**（★実測で 0 件だった / **D-27**）。
      //   → ★**下の群が★★付け替えそのもの★★を見る。**
      await _post(client, server.port, decksPath, put('d1', 'AAA'));

      final deckDir = Directory('${dir.path}${Platform.pathSeparator}decks');
      final leftover = deckDir
          .listSync()
          .where((e) => e.path.endsWith('.tmp'))
          .toList();

      expect(leftover, isEmpty);
    });
  });

  group('★★ 保管は★一時ファイルへ書いてから付け替える（決定 D134-6）★★', () {
    // ★★ 待ち受けを通さない（★保管だけを見る）★★
    //   ★**HTTP 越しでは★書き込みの失敗を作れない**（★応答の形が先に決まってしまう）。

    late Directory deckDir;
    late DeckFileStore store;

    setUp(() {
      deckDir = Directory('${dir.path}${Platform.pathSeparator}decks2');
      store = DeckFileStore(deckDir);
    });

    test('★★ 書き込みが失敗したら★元の 1 件が残る ★★', () {
      store.putDeck(user, 'd1', 'AAA');
      final file = deckDir.listSync().single as File;

      // ★★ 一時ファイルの場所を★ディレクトリで塞ぐ ★★
      //   ★**直に書く実装では★この場所を使わないので★★成功してしまう★★。**
      Directory('${file.path}.tmp').createSync();

      expect(() => store.putDeck(user, 'd1', 'BBB'),
          throwsA(isA<FileSystemException>()));
      expect(store.fetchDeck(user, 'd1'), 'AAA');
    });

    test('★★ 対: 塞がなければ★上書きできる ★★', () {
      // ★★ 上が「いつでも投げる」で通らないこと（**D-10**）★★
      store.putDeck(user, 'd1', 'AAA');

      expect(store.putDeck(user, 'd1', 'BBB'), isFalse);
      expect(store.fetchDeck(user, 'd1'), 'BBB');
    });
  });

  group('★★ 線 α は空のまま（決定 D115-6 / D126-3）★★', () {
    test('★★ 預かった中身を 1 バイトも解釈しない ★★', () async {
      // ★★ デッキとして成り立たない字面でも★そのまま往復する ★★
      //   ★**サーバーは保管庫である**（**D105-2**）。★`loveca_core` を 1 つも呼ばない。
      const nonsense = '{"これは": "デッキではない"';
      await _post(client, server.port, decksPath, put('d1', nonsense));

      final res =
          await _post(client, server.port, decksFetchPath, fetch('d1'));

      expect(jsonDecode(res.body)['content'], nonsense);
    });
  });
}
