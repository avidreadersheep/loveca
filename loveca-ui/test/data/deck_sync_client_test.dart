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

import '../support/strip_comments.dart';

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
            jsonEncode({
              'ok': true,
              'deckId': 'd1',
              'content': content,
              // ★★ 印を一緒に返す（**D141-7**）—— ★呼ぶ側に計算させない ★★
              syncMarkKey: 'M1',
            }));
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

      expect(result, isA<SyncOk<RemoteDeck>>());
      expect((result as SyncOk<RemoteDeck>).value.content, content);
      expect(result.value.mark, 'M1');
    });

    test('★★ 中身を 1 バイトも解釈しない（★デッキとして成り立たない字面でも返る）★★',
        () async {
      const content = 'これは JSON ですらない';
      final server = await _serve((request) async {
        await _reply(
            request,
            200,
            jsonEncode({'ok': true, 'content': content, syncMarkKey: 'M1'}));
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

      expect((result as SyncOk<RemoteDeck>).value.content, content);
    });

    test('★★ 印が返らなければ★受け取らない（★★取る側★★）★★', () async {
      // ★★ 受け取ると、★預けるときに名乗れないまま先へ進む（★必ず 412 になる）★★
      final server = await _serve((request) async {
        await _reply(request, 200, jsonEncode({'ok': true, 'content': 'x'}));
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

      expect(result, isA<SyncUnreachable<RemoteDeck>>());
    });

    test('★★ 印が空文字でも★受け取らない（★★取る側★★）★★', () async {
      final server = await _serve((request) async {
        await _reply(request, 200,
            jsonEncode({'ok': true, 'content': 'x', syncMarkKey: ''}));
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

      expect(result, isA<SyncUnreachable<RemoteDeck>>());
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

      expect(result, isA<SyncAbsent<RemoteDeck>>());
    });

    test('★ 1 つ取る口は★deckId を送る', () async {
      Map<String, Object?>? sent;
      final server = await _serve((request) async {
        sent = jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, Object?>;
        await _reply(request, 200,
            jsonEncode({'ok': true, 'content': 'x', syncMarkKey: 'M1'}));
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
      expect(one, isA<SyncRejected<RemoteDeck>>());
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
      expect(serverSource.contains("'$decksPutPath'"), isTrue);
    });

    test('★★ 要求の鍵が 3 つとも★サーバー側に★引用符ごと在る ★★', () {
      for (final key in const [
        syncUserNameKey,
        syncPasswordKey,
        syncDeckIdKey,
        // ★★ 預ける口が要求する鍵（**D141-4**）★★
        //   ★**字面が食い違うと★サーバーは 400 を返す**（★★両側の定数を比べても分からない★★）。
        syncExpectMarkKey,
      ]) {
        expect(serverSource.contains("'$key'"), isTrue, reason: '★$key');
      }
    });

    test('★★ 応答の鍵が 3 つとも★サーバー側に★引用符ごと在る ★★', () {
      for (final key in const [
        syncOkKey,
        syncDeckIdsKey,
        syncContentKey,
        // ★★ 返す口 / 預ける口が返す鍵（**D141-7**）★★
        syncCreatedKey,
        syncMarkKey,
      ]) {
        expect(serverSource.contains("'$key'"), isTrue, reason: '★$key');
      }
    });

    test('★★ 対: でたらめな鍵は★当たらない（★走査が働いていること）★★', () {
      expect(serverSource.contains("'この鍵はサーバー側に無い'"), isFalse);
    });
  });
  // ★★ 送る口（★§32-6 の 23 の 2 番目 / 決定 **D141**）★★
  //
  // ★★ 口だけである。★呼ぶ側は 1 行も無い ★★
  // ★**いつ送るか / ★どう見せるかは★★23 の配線と 25 であり、★どちらも未着手★★**
  //   （★配線には★門が在る —— ★resolveDeckConflict が Deck を要求するのに、
  //    ★取りに行く口が返すのは★★文字列である★★ / **D116-2** の理由 3）。
  group('★★ 預ける（★§32-6 の 23 の★送る口）★★', () {
    test('★★ 新しく預かったら SyncOk で、★★印が返る★★ ★★', () async {
      Map<String, Object?>? sent;
      final server = await _serve((request) async {
        sent = jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, Object?>;
        await _reply(
            request,
            201,
            jsonEncode({
              'ok': true,
              'deckId': 'd1',
              syncCreatedKey: true,
              syncMarkKey: 'M2',
            }));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await pushRemoteDeck(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
        deckId: 'd1',
        content: 'ナカミ',
        expectMark: null,
      );

      expect(result, isA<SyncOk<RemoteDeck>>());
      expect((result as SyncOk<RemoteDeck>).value.mark, 'M2');
      expect(result.value.content, 'ナカミ');
      expect(sent!['content'], 'ナカミ');
    });

    test('★★ 201 も 200 も★成功である（★★新しく預かったか / 上書きか★★）★★', () async {
      for (final status in <int>[200, 201]) {
        final server = await _serve((request) async {
          await _reply(
              request, status, jsonEncode({'ok': true, syncMarkKey: 'M2'}));
        });
        addTearDown(() => server.close(force: true));
        final client = _client();
        addTearDown(() => client.close(force: true));

        final result = await pushRemoteDeck(
          client: client,
          server: Uri.parse('https://localhost:${server.port}'),
          userName: 'みつき',
          password: 'ひみつ',
          deckId: 'd1',
          content: 'x',
          expectMark: 'M1',
        );

        expect(result, isA<SyncOk<RemoteDeck>>(), reason: '★状態 $status');
      }
    });

    test('★★ 印の鍵は★必ず送る（★null も 1 つの値である / **D141-4**）★★', () async {
      // ★★ 鍵そのものを落とすと★サーバーは 400 を返す ★★
      //   ★**落とさないことを★ここで固定する**（★★サーバー側の 400 に頼らない★★）。
      Map<String, Object?>? sent;
      final server = await _serve((request) async {
        sent = jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, Object?>;
        await _reply(request, 201, jsonEncode({'ok': true, syncMarkKey: 'M2'}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      await pushRemoteDeck(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
        deckId: 'd1',
        content: 'x',
        expectMark: null,
      );

      expect(sent!.containsKey(syncExpectMarkKey), isTrue);
      expect(sent![syncExpectMarkKey], isNull);
    });

    test('★★ 印を渡せば★そのまま送る（★★書き換えない★★）★★', () async {
      Map<String, Object?>? sent;
      final server = await _serve((request) async {
        sent = jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, Object?>;
        await _reply(request, 200, jsonEncode({'ok': true, syncMarkKey: 'M2'}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      await pushRemoteDeck(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
        deckId: 'd1',
        content: 'x',
        expectMark: 'トッテキタシルシ',
      );

      expect(sent![syncExpectMarkKey], 'トッテキタシルシ');
    });

    test('★★ 412 は SyncStale である（★★401 にも通信の失敗にも畳まない★★）★★', () async {
      // ★★ これが「線 β」を呼ぶ側から見た形である（**D139-1**）★★
      //   ★**名乗りは通っている。★サーバーも正しく動いている。**
      //   ★**畳むと★★「取り直して解き直せばよい」が★「パスワードを直せ」に化ける★★。**
      final server = await _serve((request) async {
        await _reply(request, 412, jsonEncode({'ok': false}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await pushRemoteDeck(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
        deckId: 'd1',
        content: 'x',
        expectMark: 'フルイ',
      );

      expect(result, isA<SyncStale<RemoteDeck>>());
      expect(result, isNot(isA<SyncRejected<RemoteDeck>>()));
      expect(result, isNot(isA<SyncUnreachable<RemoteDeck>>()));
    });

    test('★★ 401 は★依然 SyncRejected である（★★412 と分ける★★）★★', () async {
      final server = await _serve((request) async {
        await _reply(request, 401, jsonEncode({'ok': false}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await pushRemoteDeck(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
        deckId: 'd1',
        content: 'x',
        expectMark: null,
      );

      expect(result, isA<SyncRejected<RemoteDeck>>());
      expect(result, isNot(isA<SyncStale<RemoteDeck>>()));
    });

    test('★★ 404 は★通信の失敗である（★★預ける口に 404 は無い★★）★★', () async {
      // ★★ 1 つ取る口とは違う（★あちらは「そのデッキが無い」＝ 答えである）★★
      final server = await _serve((request) async {
        await _reply(request, 404, jsonEncode({'ok': false}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await pushRemoteDeck(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
        deckId: 'd1',
        content: 'x',
        expectMark: null,
      );

      expect(result, isA<SyncUnreachable<RemoteDeck>>());
      expect(result, isNot(isA<SyncAbsent<RemoteDeck>>()));
    });

    test('★★ 印が返らなければ★受け取らない ★★', () async {
      // ★★ 受け取ると、★次に預けるときに名乗れないまま先へ進む（★必ず 412 になる）★★
      final server = await _serve((request) async {
        await _reply(request, 200, jsonEncode({'ok': true, 'created': false}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await pushRemoteDeck(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
        deckId: 'd1',
        content: 'x',
        expectMark: null,
      );

      expect(result, isA<SyncUnreachable<RemoteDeck>>());
    });

    test('★★ パスは decksPutPath である（★★取る口と別である★★）★★', () async {
      String? path;
      final server = await _serve((request) async {
        path = request.uri.path;
        await _reply(request, 201, jsonEncode({'ok': true, syncMarkKey: 'M2'}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      await pushRemoteDeck(
        client: client,
        server: Uri.parse('https://localhost:${server.port}/むし/される'),
        userName: 'みつき',
        password: 'ひみつ',
        deckId: 'd1',
        content: 'x',
        expectMark: null,
      );

      expect(path, decksPutPath);
      expect(path, isNot(decksFetchPath));
    });

    test('★★ つながらなければ SyncUnreachable（★投げない）★★', () async {
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await pushRemoteDeck(
        client: client,
        server: Uri.parse('https://localhost:1'),
        userName: 'みつき',
        password: 'ひみつ',
        deckId: 'd1',
        content: 'x',
        expectMark: null,
      );

      expect(result, isA<SyncUnreachable<RemoteDeck>>());
    });

    test('★★ アプリ側は★ハッシュを 1 度も計算しない（★★走査★★ / **D141-7**）★★', () {
      // ★★ 計算すると★取り違えうる（**§7-7** ＝ 別物である）★★
      //   ★**印は★サーバーが返した字面を★そのまま持ち回る。**
      //
      // ★★ D-30 —— ★★禁じた字面を説明した doc が★同じ字面を必ず含む★★
      //   ★**素の走査では★★この口の doc 自身が当たる★★**（★実測: ★2 行）。
      //   → ★**コメントを外してから見る**（★★除外の一覧を持たない★★ —— ★除外は穴になる）。
      final code = stripComments(
          File('lib/src/data/deck_sync_client.dart').readAsStringSync());

      expect(code.contains('sha256'), isFalse,
          reason: '★★この口はハッシュを計算しない★★');
      expect(code.contains('deckContentHash'), isFalse,
          reason: '★★loveca_core の量を持ち込まない★★');
      expect(code.contains(syncMarkKey), isTrue, reason: '★陽性対照');
    });

    test('★★ 対: ★コメントを外さないと★doc 自身が当たる（★陽性対照 / D-30）★★', () {
      final raw = File('lib/src/data/deck_sync_client.dart').readAsStringSync();

      expect(raw.contains('deckContentHash'), isTrue,
          reason: '★★doc は★禁じた字面を必ず含む★★');
    });

    test('★★ 対: ★コメント外しは★コードを落とさない（★陽性対照）★★', () {
      final line = 'const String syncMarkKey = ' "'mark';";
      // ★★ D-38 —— ★道具の経路で★改行の印が★本物の改行に化ける ★★
      //   → ★**`String.fromCharCode(10)` で組み立てる**（★★逆斜線を 1 つも書かない★★）。
      final nl = String.fromCharCode(10);
      final withDoc = '/// sha256 と deckContentHash の話$nl$line';

      expect(stripComments(withDoc).contains('sha256'), isFalse);
      expect(stripComments(withDoc).contains(line), isTrue);
    });
  });

}
