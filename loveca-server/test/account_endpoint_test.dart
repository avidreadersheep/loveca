/// ★★ アカウントを作る口 —— §32-6 の **17-2**（決定 **D133-4** / **D133-9** / **D133-10**）★★
///
/// ★★ 本物の待ち受けに当てる（**D-10**）★★
/// ★試験用の証明書は `test/fixtures/tls/`（決定 **D131-7**）。
///
/// ★★ 回数を下げて回す ★★
/// ★**既定は本番の回数で、★1 回 1.5 秒かかる**（★§45 の実測）。
/// ★**`accountIterations` は★★試験のためだけに開けてある★★**。
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

String _make(String userName, String password) =>
    jsonEncode({'userName': userName, 'password': password});

void main() {
  late Directory dir;
  late AccountFileStore store;
  late HttpServer server;
  late HttpClient client;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('loveca_account_endpoint_test');
    store = AccountFileStore.open(
        '${dir.path}${Platform.pathSeparator}accounts.json');

    final context = SecurityContext()
      ..useCertificateChain(_certPath)
      ..usePrivateKey(_keyPath);
    server = await serveApi(
      context: context,
      store: store,
      // ★★ 20 で必須になった（★§32-6 の 20 / **D134-9**）★★
      decks: DeckFileStore(dir),
      // ★★ 本番は 600000 回。★試験は下げる（★1 回 1.5 秒かかる / §45）★★
      accountIterations: 10,
      // ★★ 上限を外す —— ★この群は★★上限そのものを見ていない★★
      //   ★`accountIterations` を下げるのと同じ格である（★本番の既定は `defaultRateLimit`）。
      //   ★★上限を見る群は `test/rate_limit_test.dart` に在る★★。
      rateLimit: const RateLimitPolicy.unlimited(),
    );

    final clientContext = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificates(_certPath);
    client = HttpClient(context: clientContext);
  });

  tearDown(() async {
    client.close(force: true);
    await server.close(force: true);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('★★ 作れる（決定 D133-4 ＝ 誰でも作れる）★★', () {
    test('★ 201 で、利用者名が返る', () async {
      final res = await _post(
          client, server.port, accountsPath, _make('みつき', 'ひみつ'));

      expect(res.status, 201);
      expect(res.body, jsonEncode({'ok': true, 'userName': 'みつき'}));
    });

    test('★★ 作ったら★保管に残る（★開き直しても在る）★★', () async {
      await _post(client, server.port, accountsPath, _make('みつき', 'ひみつ'));

      final reopened = AccountFileStore.open(
          '${dir.path}${Platform.pathSeparator}accounts.json');
      expect(reopened.findByUserName('みつき'), isNotNull);
    });

    test('★★ 作った直後に★名乗れる（★16 と繋がる）★★', () async {
      await _post(client, server.port, accountsPath, _make('みつき', 'ひみつ'));

      final res =
          await _post(client, server.port, authPath, _make('みつき', 'ひみつ'));

      expect(res.status, 200);
      expect(res.body, jsonEncode({'ok': true, 'userName': 'みつき'}));
    });

    test('★★ 対: 作る前は★名乗れない ★★', () async {
      // ★★ 上が「いつでも 200」で通らないこと ★★
      final res =
          await _post(client, server.port, authPath, _make('みつき', 'ひみつ'));

      expect(res.status, 401);
    });

    test('★★ 保管したのは★平文ではない（決定 D129-3）★★', () async {
      await _post(client, server.port, accountsPath, _make('みつき', 'ひみつ'));

      final saved = File('${dir.path}${Platform.pathSeparator}accounts.json')
          .readAsStringSync();
      expect(saved.contains('ひみつ'), isFalse);
      expect(saved.contains(passwordHashAlgorithm), isTrue);
    });

    test('★★ 同じパスワードでも★保管した値が違う（★塩が効いている / 柵 2）★★', () async {
      await _post(client, server.port, accountsPath, _make('a', 'おなじ'));
      await _post(client, server.port, accountsPath, _make('b', 'おなじ'));

      final reopened = AccountFileStore.open(
          '${dir.path}${Platform.pathSeparator}accounts.json');
      expect(reopened.findByUserName('a')!.passwordHash,
          isNot(reopened.findByUserName('b')!.passwordHash));
    });
  });

  group('★★ 重複は断る（決定 D130-9）★★', () {
    test('★★ 2 度目は 409 ★★', () async {
      await _post(client, server.port, accountsPath, _make('みつき', 'ひみつ'));

      final res = await _post(
          client, server.port, accountsPath, _make('みつき', 'ちがう'));

      expect(res.status, 409);
    });

    test('★★ 断ったあとも★元の 1 件は壊れていない ★★', () async {
      await _post(client, server.port, accountsPath, _make('みつき', 'ひみつ'));
      await _post(client, server.port, accountsPath, _make('みつき', 'ちがう'));

      // ★★ 上書きされていたら★「ちがう」で名乗れてしまう ★★
      final ok =
          await _post(client, server.port, authPath, _make('みつき', 'ひみつ'));
      final ng =
          await _post(client, server.port, authPath, _make('みつき', 'ちがう'));

      expect(ok.status, 200);
      expect(ng.status, 401);
    });

    test('★★ 409 は★存在を漏らす。★隠さない（★§52-10）★★', () async {
      // ★★ これは欠陥ではなく★避けられない代償である ★★
      //   ★**認証の口は漏らさない**（401 が 2 つを区別しない）が、
      //   ★★**2026-09-01 訂正: 上は★偽である**★★（**D134-2** —— ★★時間で漏れる★★ / §54-2）。
      //   ★**状態コードについては★いまも真である。★字面は書き換えない**（**D-35**）。
      //   ★★作る口は「その名前は使えない」と言わざるを得ない★★。
      await _post(client, server.port, accountsPath, _make('みつき', 'ひみつ'));

      final taken = await _post(
          client, server.port, accountsPath, _make('みつき', 'x'));
      final free =
          await _post(client, server.port, accountsPath, _make('いない', 'x'));

      // ★★ 状態が違う ＝ 存在が分かる（★これを固定する）★★
      expect(taken.status, isNot(free.status));
    });
  });

  group('★★ 空は断る。★長さの下限は決めない（決定 D133-9）★★', () {
    test('★★ 空のパスワードは 400 ★★', () async {
      // ★★ 空を許すと「パスワード無し」と同じで、★D105-3 が成り立たない ★★
      final res =
          await _post(client, server.port, accountsPath, _make('みつき', ''));

      expect(res.status, 400);
      expect(store.count, 0);
    });

    test('★★ 空の利用者名も 400 ★★', () async {
      final res =
          await _post(client, server.port, accountsPath, _make('', 'ひみつ'));

      expect(res.status, 400);
      expect(store.count, 0);
    });

    test('★★ 対: 1 文字なら通る（★長さの下限を決めていない）★★', () async {
      // ★★ 「4 文字以上」などを入れると★これが落ちる ★★
      //   ★下限は★好みで決まる（★測っていない / **D-28**）。★決めない。
      final res = await _post(client, server.port, accountsPath, _make('a', 'b'));

      expect(res.status, 201);
    });
  });

  group('★★ 壊れた要求（決定 D131-6 と同じ分け方）★★', () {
    test('★ JSON でなければ 400', () async {
      final res =
          await _post(client, server.port, accountsPath, 'これは JSON ではない');

      expect(res.status, 400);
    });

    test('★ 鍵が無ければ 400', () async {
      final res = await _post(
          client, server.port, accountsPath, jsonEncode({'userName': 'a'}));

      expect(res.status, 400);
    });

    test('★ メソッドが違えば 405', () async {
      final res =
          await _post(client, server.port, accountsPath, '', method: 'GET');

      expect(res.status, 405);
    });

    test('★★ 400 のときは★1 件も作られない ★★', () async {
      await _post(client, server.port, accountsPath, 'これは JSON ではない');

      expect(store.count, 0);
      expect(
          File('${dir.path}${Platform.pathSeparator}accounts.json')
              .existsSync(),
          isFalse);
    });
  });

  group('★★ 同じ口。★パスで分ける（決定 D130-7）★★', () {
    test('★★ 待ち受けは 1 つで、★2 つのパスが在る ★★', () async {
      final made = await _post(
          client, server.port, accountsPath, _make('みつき', 'ひみつ'));
      final named =
          await _post(client, server.port, authPath, _make('みつき', 'ひみつ'));

      expect(made.status, 201);
      expect(named.status, 200);
    });

    test('★★ 知らないパスは 404（★静かに 200 を返さない）★★', () async {
      final res = await _post(
          client, server.port, '/しらない', _make('みつき', 'ひみつ'));

      expect(res.status, 404);
    });

    test('★★ パスが違えば★振り分けも違う（★対）★★', () async {
      // ★★ 同じ本文を 2 つのパスへ送ると★状態が違う ★★
      //   ★振り分けが壊れていたら★同じになる。
      final toAccounts = await _post(
          client, server.port, accountsPath, _make('みつき', 'ひみつ'));
      final toAuth =
          await _post(client, server.port, authPath, _make('いない', 'x'));

      expect(toAccounts.status, 201);
      expect(toAuth.status, 401);
    });
  });
}
