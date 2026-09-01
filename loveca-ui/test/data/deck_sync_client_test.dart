/// ★★ 相手の版を取りに行く口（アプリ側）—— §32-6 の **21** の★口★ ★★
///
/// ★★ 本物の待ち受けに当てる（**D-10**）★★
/// ★**合成の応答だけだと「★TLS 越しに本当に往復できるか」を★★1 つも見ていない★★。**
/// ★試験用の証明書は `loveca-server/test/fixtures/tls/`（決定 **D131-7**）を借りる。
///
/// ★★ サーバーの実装は★呼ばない（**D126-3**）★★
/// ★**`loveca_ui` → `loveca_server` は★★永久に 0 本★★である。**
/// → ★**この試験は★★自前の待ち受けを立てて★サーバーの振る舞いを真似る★★**（★18 の口と同じ形）。
/// → ★★**「端から端まで 1 回で通した」とは書かない。**★★ ★**両側とも★自分の側の試験を持つ。**
///
/// ★★ やり取りの形は 2 か所に書かれる（**D126-3** が買った代償）★★
/// ★**パスと鍵の名前が★両側で同じであることを★★走査で見張る★★**（★下の最後の群）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_ui/src/data/deck_sync_client.dart';

/// ★サーバーの `lib`。★**パスと鍵の名前を突き合わせる相手**（★読むだけ。★呼ばない）。
const _serverDeckEndpoint = '../loveca-server/lib/src/deck_endpoint.dart';

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
  group('★★ 一覧 —— ★★本物の待ち受けに当てる（**D-10**）★★', () {
    test('★ 取れたら SyncOk で、★deckId の列が返る', () async {
      final server = await _serve((request) async {
        await _reply(request, 200,
            jsonEncode({'ok': true, 'deckIds': ['a', 'b', 'c']}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await fetchRemoteDeckIds(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
      );

      expect(result, isA<SyncOk<List<String>>>());
      expect((result as SyncOk<List<String>>).value, ['a', 'b', 'c']);
    });

    test('★★ 空の一覧は★SyncOk である（★SyncAbsent ではない）★★', () async {
      // ★★ 「1 つも預けていない」は★答えであって不在ではない ★★
      final server = await _serve((request) async {
        await _reply(request, 200, jsonEncode({'ok': true, 'deckIds': []}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await fetchRemoteDeckIds(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
      );

      expect(result, isA<SyncOk<List<String>>>());
      expect((result as SyncOk<List<String>>).value, isEmpty);
    });

    test('★★ 一覧の 404 は★SyncUnreachable である（★SyncAbsent に畳まない）★★',
        () async {
      // ★★ 一覧の口に 404 は無い —— ★空の一覧は 200 で返ると決まっている ★★
      //   ★404 が返るのは「知らないパス」のときで、★★期待どおりでない★★。
      final server = await _serve((request) async {
        await _reply(request, 404, jsonEncode({'ok': false}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await fetchRemoteDeckIds(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
      );

      expect(result, isA<SyncUnreachable<List<String>>>());
    });

    test('★★ 列に文字列でないものが混ざっていたら SyncUnreachable。★理由も持つ ★★',
        () async {
      final server = await _serve((request) async {
        await _reply(
            request, 200, jsonEncode({'ok': true, 'deckIds': ['a', 7]}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await fetchRemoteDeckIds(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
      );

      expect(result, isA<SyncUnreachable<List<String>>>());
      // ★★ 理由を★診断に使える字面にする（**D105-6** —— ★見せるためには値が要る）★★
      //   ★**取り出しの失敗を★型の変換の例外に落とすと、★★理由が実装の内部語になる★★**
      //   （★仕込んで **0 件**だった —— ★型だけ見る対では★区別がつかない / **D-27**）。
      expect((result as SyncUnreachable<List<String>>).reason,
          '応答の中身が期待どおりでない');
    });

    test('★ 一覧は★deckId を送らない（★要らない）', () async {
      Map<String, Object?>? sent;
      final server = await _serve((request) async {
        sent = jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, Object?>;
        await _reply(request, 200, jsonEncode({'ok': true, 'deckIds': []}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      await fetchRemoteDeckIds(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
      );

      expect(sent!.containsKey('deckId'), isFalse);
      expect(sent!['userName'], 'みつき');
      expect(sent!['password'], 'ひみつ');
    });
  });

  group('★★ 1 つ取る ★★', () {
    test('★★ 取れたら SyncOk で、★★中身が★字面のまま★★返る ★★', () async {
      // ★★ 送る deckId と★返る content を★違えておく（★§47 の (J) と同じ形）★★
      //   ★同じにすると、★**送った字面をそのまま返す実装でも通る**。
      const content = '{"これは":"デッキの字面である"}';
      final server = await _serve((request) async {
        await _reply(request, 200,
            jsonEncode({'ok': true, 'deckId': 'd1', 'content': content}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await fetchRemoteDeck(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
        deckId: 'd1',
      );

      expect(result, isA<SyncOk<String>>());
      expect((result as SyncOk<String>).value, content);
    });

    test('★★ 中身を 1 バイトも解釈しない（★デッキとして成り立たない字面でも返る）★★',
        () async {
      const content = 'これは JSON ですらない';
      final server = await _serve((request) async {
        await _reply(
            request, 200, jsonEncode({'ok': true, 'content': content}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await fetchRemoteDeck(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
        deckId: 'd1',
      );

      expect((result as SyncOk<String>).value, content);
    });

    test('★★ 404 は★SyncAbsent である（★通信の失敗に畳まない）★★', () async {
      // ★★ 「まだ預けていない」は★正しい答えである ★★
      final server = await _serve((request) async {
        await _reply(request, 404, jsonEncode({'ok': false}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await fetchRemoteDeck(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
        deckId: 'いない',
      );

      expect(result, isA<SyncAbsent<String>>());
    });

    test('★ 1 つ取る口は★deckId を送る', () async {
      Map<String, Object?>? sent;
      final server = await _serve((request) async {
        sent = jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, Object?>;
        await _reply(request, 200, jsonEncode({'ok': true, 'content': 'x'}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      await fetchRemoteDeck(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
        deckId: 'd7',
      );

      expect(sent!['deckId'], 'd7');
    });
  });

  group('★★ 3 つに分ける（**D105-6** / **D132-6** と同じ形）★★', () {
    test('★★ 401 は SyncRejected（★通信の失敗に畳まない）★★', () async {
      final server = await _serve((request) async {
        await _reply(request, 401, jsonEncode({'ok': false}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final list = await fetchRemoteDeckIds(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ちがう',
      );
      final one = await fetchRemoteDeck(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ちがう',
        deckId: 'd1',
      );

      expect(list, isA<SyncRejected<List<String>>>());
      expect(one, isA<SyncRejected<String>>());
    });

    test('★★ 400 は SyncUnreachable（★「名乗れなかった」に畳まない）★★', () async {
      final server = await _serve((request) async {
        await _reply(request, 400, jsonEncode({'ok': false}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await fetchRemoteDeckIds(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: '',
        password: 'ひみつ',
      );

      expect(result, isA<SyncUnreachable<List<String>>>());
    });

    test('★★ 429 も SyncUnreachable（★上限に当たった）★★', () async {
      // ★★ 上限は★サーバー側の★★既定値★★である（**N-26** の Q-01）★★
      //   ★**「名乗れなかった」に畳まない** —— ★★資格情報は正しい★★。
      final server = await _serve((request) async {
        await _reply(request, 429, jsonEncode({'ok': false}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await fetchRemoteDeckIds(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
      );

      expect(result, isA<SyncUnreachable<List<String>>>());
    });

    test('★ 200 だが ok が真でなければ SyncUnreachable', () async {
      final server = await _serve((request) async {
        await _reply(request, 200, jsonEncode({'ok': false, 'deckIds': []}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await fetchRemoteDeckIds(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
      );

      expect(result, isA<SyncUnreachable<List<String>>>());
    });

    test('★ 応答が JSON でなければ SyncUnreachable', () async {
      final server = await _serve((request) async {
        await _reply(request, 200, 'これは JSON ではない');
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await fetchRemoteDeckIds(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
      );

      expect(result, isA<SyncUnreachable<List<String>>>());
    });

    test('★★ つながらなければ SyncUnreachable（★投げない）★★', () async {
      final client = _client();
      addTearDown(() => client.close(force: true));

      // ★★ 誰も待ち受けていない港へ投げる ★★
      final result = await fetchRemoteDeckIds(
        client: client,
        server: Uri.parse('https://localhost:1'),
        userName: 'みつき',
        password: 'ひみつ',
      );

      expect(result, isA<SyncUnreachable<List<String>>>());
    });

    test('★★ 渡した住所を★そのまま使う（★scheme を書き換えない）★★', () async {
      // ★★ 住所は★呼び出し側が決める（**D131-3** と同じ形）★★
      //   ★★**誰も待ち受けていない港へ投げる形では★この対は働かない**★★ ——
      //   ★**書き換えても書き換えなくても★つながらないので★同じ答えになる**
      //   （★仕込んで **0 件**だった / **D-27**）。
      //   → ★★**TLS で本当に待ち受けている港へ、★素の HTTP で投げる。**★★
      //     ★書き換える実装なら★★つながってしまう★★。
      final server = await _serve((request) async {
        await _reply(request, 200, jsonEncode({'ok': true, 'deckIds': []}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final plain = await fetchRemoteDeckIds(
        client: client,
        server: Uri.parse('http://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
      );
      expect(plain, isA<SyncUnreachable<List<String>>>());

      // ★★ 対: 同じ港へ TLS で投げれば通る（★上が「何でも失敗する」で通らないこと）★★
      final secure = await fetchRemoteDeckIds(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
      );
      expect(secure, isA<SyncOk<List<String>>>());
    });
  });

  group('★★ パスと鍵の名前が★サーバー側と揃っている（**D126-3** の代償を見張る）★★', () {
    late String serverSource;

    setUpAll(() {
      serverSource = File(_serverDeckEndpoint).readAsStringSync();
    });

    test('★ 突き合わせる相手が読める（★陽性対照）', () {
      expect(File(_serverDeckEndpoint).existsSync(), isTrue);
      expect(serverSource, isNotEmpty);
    });

    test('★★ パスが 2 つとも★サーバー側に★引用符ごと在る ★★', () {
      // ★★ 引用符ごと見る（**D-37 の裏**）★★
      //   ★引用符を外すと★doc の中の説明にも当たる。
      expect(serverSource.contains("'$decksListPath'"), isTrue);
      expect(serverSource.contains("'$decksFetchPath'"), isTrue);
    });

    test('★★ 要求の鍵が 3 つとも★サーバー側に★引用符ごと在る ★★', () {
      for (final key in const [
        syncUserNameKey,
        syncPasswordKey,
        syncDeckIdKey,
      ]) {
        expect(serverSource.contains("'$key'"), isTrue, reason: '★$key');
      }
    });

    test('★★ 応答の鍵が 3 つとも★サーバー側に★引用符ごと在る ★★', () {
      for (final key in const [syncOkKey, syncDeckIdsKey, syncContentKey]) {
        expect(serverSource.contains("'$key'"), isTrue, reason: '★$key');
      }
    });

    test('★★ 対: でたらめな鍵は★当たらない（★走査が働いていること）★★', () {
      expect(serverSource.contains("'この鍵はサーバー側に無い'"), isFalse);
    });
  });
}
