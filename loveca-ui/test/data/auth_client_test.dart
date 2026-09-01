/// ★★ 認証の口（アプリ側）—— §32-6 の **18** の★口★（決定 **D132-4** / **D132-6**）★★
///
/// ★★ 本物の待ち受けに当てる（**D-10**）★★
/// ★**合成の応答だけだと「★TLS 越しに本当に往復できるか」を★★1 つも見ていない★★。**
/// ★試験用の証明書は `loveca-server/test/fixtures/tls/`（決定 **D131-7**）を借りる。
///
/// ★★ サーバーの実装は★呼ばない（**D126-3**）★★
/// ★**`loveca_ui` → `loveca_server` は★★永久に 0 本★★である。**
/// → ★**この試験は★★自前の待ち受けを立てて★サーバーの振る舞いを真似る★★**（★§50-10 の 4）。
/// → ★★**「端から端まで 1 回で通した」とは書かない。**★★ ★**両側とも★自分の側の試験を持つ。**
///
/// ★★ やり取りの形は 2 か所に書かれる（**D126-3** が買った代償）★★
/// ★**鍵の名前が★両側で同じであることを★★走査で見張る★★**（★下の最後の群）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_ui/src/data/auth_client.dart';

/// ★サーバーの `lib`。★**鍵の名前を突き合わせる相手**（★読むだけ。★呼ばない）。
const _serverAuthSource = '../loveca-server/lib/src/auth.dart';
const _serverEndpointSource = '../loveca-server/lib/src/auth_endpoint.dart';

const _fixtureDir = '../loveca-server/test/fixtures/tls';
const _certPath = '$_fixtureDir/localhost-TEST-ONLY.cert.pem';
const _keyPath = '$_fixtureDir/localhost-TEST-ONLY.key.pem';

/// ★合成の待ち受け。★**サーバーの振る舞いを真似る**（★実装は呼ばない）。
Future<HttpServer> _serve(
  Future<void> Function(HttpRequest request) handler,
) async {
  final context = SecurityContext()
    ..useCertificateChain(_certPath)
    ..usePrivateKey(_keyPath);
  final server =
      await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context);
  server.listen(handler);
  return server;
}

HttpClient _client() {
  final context = SecurityContext(withTrustedRoots: false)
    ..setTrustedCertificates(_certPath);
  return HttpClient(context: context);
}

Future<void> _reply(HttpRequest request, int status, String body) async {
  request.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(body);
  await request.response.close();
}

void main() {
  group('★★ 往復 —— ★★本物の待ち受けに当てる（**D-10**）★★', () {
    test('★★ 名乗れたら AuthOk で、★★保管の側の字面★★が返る ★★', () async {
      // ★★ 送る字面と★返る字面を★★違えておく★★（★§47 の (J) と同じ形）★★
      //   ★同じにすると、★**送った字面をそのまま返す実装でも通る**
      //   （★仕込んで **0 件**だった。★★対の形が悪かった★★ / **D-27**）。
      //   ★サーバーは★保管の側の字面を返すと決まっている（`AuthSuccess` の doc）。
      final server = await _serve((request) async {
        await _reply(request, 200, jsonEncode({'ok': true, 'userName': 'mitsuki'}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await authenticateWithServer(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'Mitsuki',
        password: 'ひみつ',
      );

      expect(result, isA<AuthOk>());
      expect((result as AuthOk).userName, 'mitsuki');
    });

    test('★★ 送る本文の鍵と★パスを固定する（★往復だけでは足りない）★★', () async {
      late String seenPath;
      late String seenBody;
      late String seenMethod;
      final server = await _serve((request) async {
        seenPath = request.uri.path;
        seenMethod = request.method;
        seenBody = await utf8.decoder.bind(request).join();
        await _reply(request, 200, jsonEncode({'ok': true, 'userName': 'a'}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      await authenticateWithServer(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'a',
        password: 'b',
      );

      expect(seenPath, '/auth');
      expect(seenMethod, 'POST');
      expect(seenBody, jsonEncode({'userName': 'a', 'password': 'b'}));
    });

    test('★★ 住所にパスが付いていても★/auth に置き換える ★★', () async {
      late String seenPath;
      final server = await _serve((request) async {
        seenPath = request.uri.path;
        await _reply(request, 200, jsonEncode({'ok': true, 'userName': 'a'}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      await authenticateWithServer(
        client: client,
        server: Uri.parse('https://localhost:${server.port}/なにか'),
        userName: 'a',
        password: 'b',
      );

      expect(seenPath, '/auth');
    });
  });

  group('★★ 答えを 3 つに分ける（決定 D132-6 / D105-6）★★', () {
    test('★★ 401 は AuthRejected（★通信は成功している）★★', () async {
      final server = await _serve((request) async {
        await _reply(request, 401, jsonEncode({'ok': false}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await authenticateWithServer(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'a',
        password: 'b',
      );

      expect(result, isA<AuthRejected>());
    });

    test('★★ つながらなければ AuthUnreachable（★AuthRejected ではない）★★', () async {
      // ★★ これが「2 つに畳まない」ことの対である ★★
      //   ★畳むと★★「つながらなかった」が「パスワードが違う」に化ける★★。
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await authenticateWithServer(
        client: client,
        // ★誰も待っていない口（★0 番で開いてすぐ閉じた番号ではなく、★使わない番号）。
        server: Uri.parse('https://localhost:1'),
        userName: 'a',
        password: 'b',
      );

      expect(result, isA<AuthUnreachable>());
    });

    test('★★ 証明書を信頼しなければ AuthUnreachable ★★', () async {
      final server = await _serve((request) async {
        await _reply(request, 200, jsonEncode({'ok': true, 'userName': 'a'}));
      });
      addTearDown(() => server.close(force: true));
      // ★★ 信頼しない client を渡す —— ★★門 シ の (2) は★呼び出し側に在る★★ ★★
      final stranger = HttpClient(context: SecurityContext(withTrustedRoots: false));
      addTearDown(() => stranger.close(force: true));

      final result = await authenticateWithServer(
        client: stranger,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'a',
        password: 'b',
      );

      expect(result, isA<AuthUnreachable>());
    });

    test('★★ 400 は AuthUnreachable（★AuthRejected に畳まない）★★', () async {
      // ★★ 400 は「送り手の作りが違う」、★401 は「資格情報が違う」（D131-6）★★
      final server = await _serve((request) async {
        await _reply(request, 400, jsonEncode({'ok': false}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await authenticateWithServer(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'a',
        password: 'b',
      );

      expect(result, isA<AuthUnreachable>());
    });

    test('★★ 壊れた応答は AuthUnreachable（★4 つ目に分けない）★★', () async {
      final cases = <String, String>{
        'JSON ではない': 'これは JSON ではない',
        '表ではない': jsonEncode([1, 2, 3]),
        'ok が真でない': jsonEncode({'ok': false}),
        '利用者名が無い': jsonEncode({'ok': true}),
        '利用者名が文字列でない': jsonEncode({'ok': true, 'userName': 1}),
      };

      for (final entry in cases.entries) {
        final server = await _serve((request) async {
          await _reply(request, 200, entry.value);
        });
        final client = _client();

        final result = await authenticateWithServer(
          client: client,
          server: Uri.parse('https://localhost:${server.port}'),
          userName: 'a',
          password: 'b',
        );

        expect(result, isA<AuthUnreachable>(), reason: '★${entry.key}');
        client.close(force: true);
        await server.close(force: true);
      }
    });

    test('★★ 対: 3 つは★互いに区別が付く ★★', () {
      // ★★ これが無いと、★★全部 AuthUnreachable を返す実装★★でも上が通る ★★
      expect(const AuthOk('a'), isNot(isA<AuthRejected>()));
      expect(const AuthRejected(), isNot(isA<AuthUnreachable>()));
      expect(const AuthUnreachable('x'), isNot(isA<AuthOk>()));
    });
  });

  group('★★ やり取りの形が★両側で同じ（**D126-3** が買った代償の見張り）★★', () {
    // ★★ サーバーを import できない（★依存は永久に 0 本）ので、★★字面で突き合わせる★★ ★★
    //   ★**引用符ごと見る**（**D-37 の裏** —— ★`userName` だけだと★★変数名にも当たる★★）。
    String read(String path) => File(path).readAsStringSync();

    test('★★ 陽性対照: 相手のファイルが読めて、★空でない ★★', () {
      expect(read(_serverAuthSource), isNotEmpty);
      expect(read(_serverEndpointSource), isNotEmpty);
    });

    test('★★ 要求と応答の鍵が★サーバー側にも在る ★★', () {
      final source = read(_serverAuthSource);

      for (final key in [authUserNameKey, authPasswordKey, authOkKey]) {
        expect(source.contains("'$key'"), isTrue,
            reason: '★$key —— ★★やり取りの形が★片側だけ動いた★★');
      }
    });

    test('★★ パスがサーバー側にも在る ★★', () {
      expect(read(_serverEndpointSource).contains("'$authPath'"), isTrue);
    });

    test('★★ 対: 引用符ごと見ている（**D-37 の裏**）★★', () {
      // ★★ 引用符を外すと★変数名にも当たる —— ★★見張りが緩む★★ ★★
      const synthetic = 'final userName = x;';

      expect(synthetic.contains('userName'), isTrue);
      expect(synthetic.contains("'userName'"), isFalse);
    });
  });
}
