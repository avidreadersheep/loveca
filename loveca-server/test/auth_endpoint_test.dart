/// ★★ 認証の口（サーバー側）—— §32-6 の **16**（決定 **D131-2** / **D131-3** / **D131-6** / **D131-8**）★★
///
/// ★★ 待ち受けを★本当に張って確かめる（**D-10**）★★
/// ★**張らずに書くと「★待ち受けの配線が正しいか」を★★1 つも見ていない★★。**
/// ★試験用の証明書は `test/fixtures/tls/`（★決定 **D131-7** / ★そこの README を読むこと）。
///
/// ★★ 飛ばす検査（skip）を作らない ★★
/// ★**証明書を★作るたびに生成すると、★`openssl` が無い機械で飛ばすことになる**
/// （`CLAUDE.md` §3 —— ★★飛ばした検査は「検証しているつもりで検証していない」★★）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:loveca_server/loveca_server.dart';
import 'package:test/test.dart';

const _fixtureDir = 'test/fixtures/tls';
const _certPath = '$_fixtureDir/localhost-TEST-ONLY.cert.pem';
const _keyPath = '$_fixtureDir/localhost-TEST-ONLY.key.pem';

AccountRecord _account(String userName, String password) => AccountRecord(
      userName: userName,
      passwordHash: encodePasswordHash(password,
          salt: List<int>.filled(16, 5), iterations: 10),
    );

/// ★1 回の往復。★**状態と本文をそのまま返す。**
Future<({int status, String body})> _post(
  HttpClient client,
  int port,
  String path,
  String body, {
  String method = 'POST',
}) async {
  final request =
      await client.openUrl(method, Uri.parse('https://localhost:$port$path'));
  request.headers.contentType = ContentType.json;
  request.write(body);
  final response = await request.close();
  return (
    status: response.statusCode,
    body: await utf8.decoder.bind(response).join(),
  );
}

void main() {
  late HttpServer server;
  late HttpClient client;
  late Directory dir;

  setUp(() async {
    final context = SecurityContext()
      ..useCertificateChain(_certPath)
      ..usePrivateKey(_keyPath);

    // ★★ 2026-09-01: `serveAuth` から `serveApi` に改名した（決定 **D133-10**）★★
    //   ★1 つの待ち受けが★★2 つのパスを持つ★★ようになった（★アカウントを作る口が入った）。
    //   ★保管は★ファイルの実装を使う（★`serveApi` が★書き込みを要るため）。
    dir = Directory.systemTemp.createTempSync('loveca_auth_endpoint_test');
    final store = AccountFileStore.open(
        '${dir.path}${Platform.pathSeparator}accounts.json')
      ..add(_account('みつき', 'ひみつ'));

    // ★★ `decks` は 20 で必須になった（★§32-6 の 20 / **D134-9**）★★
    server = await serveApi(
      context: context,
      store: store,
      decks: DeckFileStore(dir),
      // ★★ 上限を外す —— ★この群は★★上限そのものを見ていない★★
      //   ★★上限を見る群は `test/rate_limit_test.dart` に在る★★。
      rateLimit: const RateLimitPolicy.unlimited(),
    );

    // ★★ 自己署名なので★この証明書だけを信頼する ★★
    //   ★`badCertificateCallback` で素通しにしない —— ★**素通しにすると
    //   ★★TLS が張れているかを 1 つも見ていない★★**（**D-10**）。
    final clientContext = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificates(_certPath);
    client = HttpClient(context: clientContext);
  });

  tearDown(() async {
    client.close(force: true);
    await server.close(force: true);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('★★ 柵 —— ★★TLS でなければつながらない（決定 D131-2）★★', () {
    test('★★ 素の HTTP で叩くとつながらない ★★', () async {
      // ★★ これが「素の HTTP へ落ちない」ことの対である ★★
      //   ★`serveAuth` が `bindSecure` ではなく `bind` を呼んでいたら、
      //   ★★これが 200 を返して落ちる★★。
      // ★★ `getUrl` だけでは足りない ★★
      //   ★要求の器を作るだけで、★★つなぎに行くのは `close()` のときである★★。
      //   ★最初はここで止めており、★**素の HTTP でも「投げない」ので落ちた**
      //   （★§45 の (R) / §47 の (J) と同じ形 —— ★★対が対象を見ていなかった★★）。
      final plain = HttpClient();
      await expectLater(
        plain
            .getUrl(Uri.parse('http://localhost:${server.port}$authPath'))
            .then((request) => request.close()),
        throwsA(anything),
      );
      plain.close(force: true);
    });

    test('★★ 対: TLS でならつながる（★上が「何でも落ちる」で通らないこと）★★', () async {
      final res = await _post(client, server.port, authPath,
          jsonEncode({'userName': 'みつき', 'password': 'ひみつ'}));

      expect(res.status, 200);
    });

    test('★★ 証明書を信頼しない相手はつながらない ★★', () async {
      // ★★ 「TLS が張れている」ことの対 —— ★素通しにしていないことを見る ★★
      final stranger = HttpClient(context: SecurityContext(withTrustedRoots: false));
      await expectLater(
        stranger
            .postUrl(Uri.parse('https://localhost:${server.port}$authPath'))
            .then((r) => r.close()),
        throwsA(anything),
      );
      stranger.close(force: true);
    });
  });

  group('★★ 状態コード（決定 D131-6）★★', () {
    test('★ 名乗れたら 200 で、利用者名が返る', () async {
      final res = await _post(client, server.port, authPath,
          jsonEncode({'userName': 'みつき', 'password': 'ひみつ'}));

      expect(res.status, 200);
      expect(res.body, jsonEncode({'ok': true, 'userName': 'みつき'}));
    });

    test('★★ パスワードが違えば 401 ★★', () async {
      final res = await _post(client, server.port, authPath,
          jsonEncode({'userName': 'みつき', 'password': 'ちがう'}));

      expect(res.status, 401);
      expect(res.body, jsonEncode({'ok': false}));
    });

    test('★★ 利用者名が無ければ★同じく 401（★状態コードでも区別しない）★★', () async {
      // ★★ これが柵そのものである —— ★区別すると★利用者名の存在が漏れる ★★
      final noUser = await _post(client, server.port, authPath,
          jsonEncode({'userName': 'いない', 'password': 'ひみつ'}));
      final badPass = await _post(client, server.port, authPath,
          jsonEncode({'userName': 'みつき', 'password': 'ちがう'}));

      expect(noUser.status, badPass.status);
      expect(noUser.body, badPass.body);
    });

    test('★★ 壊れた要求は 400（★401 と取り違えない）★★', () async {
      // ★★ 400 は「送り手の作りが違う」、★401 は「資格情報が違う」★★
      final notJson = await _post(client, server.port, authPath, 'これは JSON ではない');
      final missingKey = await _post(
          client, server.port, authPath, jsonEncode({'userName': 'みつき'}));
      final notMap =
          await _post(client, server.port, authPath, jsonEncode([1, 2, 3]));

      expect(notJson.status, 400);
      expect(missingKey.status, 400);
      expect(notMap.status, 400);
    });

    test('★★ 対: 空文字は 400 ではなく 401（★間違った資格情報である）★★', () async {
      // ★★ 「無い」と「空」を分けていることの対 ★★
      final res = await _post(client, server.port, authPath,
          jsonEncode({'userName': 'みつき', 'password': ''}));

      expect(res.status, 401);
    });

    test('★★ 知らないパスは 404（★静かに 200 を返さない）★★', () async {
      // ★★ 同じ口に配信のパスが載る（D130-7）★★
      final res = await _post(client, server.port, '/しらない',
          jsonEncode({'userName': 'みつき', 'password': 'ひみつ'}));

      expect(res.status, 404);
    });

    test('★★ メソッドが違えば 405 ★★', () async {
      final res = await _post(client, server.port, authPath, '',
          method: 'GET');

      expect(res.status, 405);
    });

    test('★★ パスの判定が★メソッドの判定より先である ★★', () async {
      // ★★ 順を入れ替えると、★知らないパスに GET したとき 405 が返る ★★
      //   ★**「そのパスは在るがメソッドが違う」と読める** —— ★★偽である★★。
      final res =
          await _post(client, server.port, '/しらない', '', method: 'GET');

      expect(res.status, 404);
    });
  });

  group('★★ 応答の中身 ★★', () {
    test('★★ 失敗の本文に★理由が 1 つも入らない ★★', () async {
      final res = await _post(client, server.port, authPath,
          jsonEncode({'userName': 'いない', 'password': 'x'}));

      expect(jsonDecode(res.body), {'ok': false});
    });

    test('★★ 本文にパスワードが 1 文字も現れない ★★', () async {
      // ★★ 送った値を★そのまま返す実装なら落ちる ★★
      final res = await _post(client, server.port, authPath,
          jsonEncode({'userName': 'みつき', 'password': 'ひみつ'}));

      expect(res.body.contains('ひみつ'), isFalse);
    });

    test('★ 型は JSON である（決定 D130-12）', () async {
      final request = await client
          .postUrl(Uri.parse('https://localhost:${server.port}$authPath'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'userName': 'みつき', 'password': 'ひみつ'}));
      final response = await request.close();

      expect(response.headers.contentType?.mimeType, 'application/json');
      await utf8.decoder.bind(response).join();
    });
  });
}
