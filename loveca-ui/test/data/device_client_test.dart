/// ★★ 端末の名簿の口（アプリ側）—— §32-6 の **26** の 3 番目（決定 **D145**）★★
///
/// ★★ 本物の待ち受けに当てる（**D-10**）★★
/// ★試験用の証明書は `loveca-server/test/fixtures/tls/`（決定 **D131-7**）を借りる。
///
/// ★★ サーバーの実装は★呼ばない（**D126-3**）★★
/// ★**自前の待ち受けを立てて★振る舞いを真似る**（★18 / 21 / 23 の口と同じ形）。
/// → ★★**「端から端まで 1 回で通した」とは書かない。**★★
///
/// ★★ やり取りの形は 2 か所に書かれる（**D126-3** が買った代償）★★
/// ★**パスと鍵の名前が★両側で同じであることを★★走査で見張る★★**（★下の最後の群）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_ui/src/data/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:loveca_ui/src/data/deck_sync_client.dart';
import 'package:loveca_ui/src/data/device_client.dart';

import '../support/strip_comments.dart';

/// ★サーバーの `lib`。★**パスと鍵の名前を突き合わせる相手**（★読むだけ。★呼ばない）。
const _serverDeviceEndpoint = '../loveca-server/lib/src/device_endpoint.dart';

const _fixtureDir = '../loveca-server/test/fixtures/tls';
const _certPath = '$_fixtureDir/localhost-TEST-ONLY.cert.pem';
const _keyPath = '$_fixtureDir/localhost-TEST-ONLY.key.pem';

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

/// ★器と同定の置き場のフェイク（★★本実装と食い違わせない★★ / **D70**）。
class _FakeIdentity implements DeviceIdentityStore {
  _FakeIdentity({this.identity});

  SyncIdentity? identity;
  int forgotten = 0;
  final List<SyncIdentity> recorded = [];

  @override
  Future<SyncIdentity?> currentIdentity() async => identity;

  @override
  Future<void> recordIdentity({
    required String userName,
    required String deviceId,
  }) async {
    identity = (userName: userName, deviceId: deviceId);
    recorded.add(identity!);
  }

  @override
  Future<void> forgetAllMarks() async => forgotten++;
}

/// ★★ 起きた順を記録するフェイク（★決定 **D148-1** の対）★★
///
/// ★**器を消したことを★★通信と同じ列に混ぜて記録する★★**ので、
/// ★★「記録より★先に消したか」が★1 つの列で読める★★。
class _OrderedIdentity extends _FakeIdentity {
  _OrderedIdentity(this._order, {super.identity});

  final List<String> _order;

  @override
  Future<void> forgetAllMarks() async {
    _order.add('forget');
    return super.forgetAllMarks();
  }
}

void main() {
  group('★★ 名簿に触れる口（★本物の待ち受けに当てる / D-10）★★', () {
    test('★ 取れたら SyncOk で、★1 ビットと全端末が返る', () async {
      final server = await _serve((request) async {
        await _reply(
            request,
            200,
            jsonEncode({
              'ok': true,
              syncKnownKey: true,
              syncDeviceIdsKey: ['DEV-1', 'DEV-2'],
            }));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await touchDeviceRoster(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
        deviceId: 'DEV-1',
        join: true,
      );

      expect(result, isA<SyncOk<DeviceRoster>>());
      final value = (result as SyncOk<DeviceRoster>).value;
      expect(value.known, isTrue);
      expect(value.deviceIds, ['DEV-1', 'DEV-2']);
    });

    test('★★ 送るのは★利用者名 / パスワード / 端末の同定の 3 つである ★★', () async {
      Map<String, Object?>? sent;
      final server = await _serve((request) async {
        sent = jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, Object?>;
        await _reply(request, 200,
            jsonEncode({'ok': true, syncKnownKey: true, syncDeviceIdsKey: []}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      await touchDeviceRoster(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
        deviceId: 'DEV-1',
        join: true,
      );

      // ★★ 2026-09-02: ★`join` が増えた（決定 **D148-1**）★★
      //   ★**送るものは 4 つになった。★★字面をここで固定する★★。**
      expect(sent, {
        syncUserNameKey: 'みつき',
        syncPasswordKey: 'ひみつ',
        syncDeviceIdKey: 'DEV-1',
        syncJoinKey: true,
      });
    });

    test('★★ `join: false` を渡すと★★そのまま送る★★（★問うだけ / D148-1）★★', () async {
      Map<String, Object?>? sent;
      final server = await _serve((request) async {
        sent = jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, Object?>;
        await _reply(request, 200,
            jsonEncode({'ok': true, syncKnownKey: true, syncDeviceIdsKey: []}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      await touchDeviceRoster(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
        deviceId: 'DEV-1',
        join: false,
      );

      expect(sent![syncJoinKey], isFalse);
    });

    test('★★ 1 ビットが欠けていたら★受け取らない（★★SyncUnreachable★★）★★', () async {
      // ★★ 受け取ると、★★引き金が立たないまま先へ進む★★ ★★
      //   ★**外れた端末が★古い器のまま同期を続ける。**
      final server = await _serve((request) async {
        await _reply(
            request, 200, jsonEncode({'ok': true, syncDeviceIdsKey: []}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await touchDeviceRoster(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
        deviceId: 'DEV-1',
        join: true,
      );

      expect(result, isA<SyncUnreachable<DeviceRoster>>());
    });

    test('★ 401 は SyncRejected（★通信の失敗に畳まない）', () async {
      final server = await _serve((request) async {
        await _reply(request, 401, jsonEncode({'ok': false}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await touchDeviceRoster(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ちがう',
        deviceId: 'DEV-1',
        join: true,
      );

      expect(result, isA<SyncRejected<DeviceRoster>>());
    });

    test('★★ 429 は★通信の失敗である（★★名乗れなかったに畳まない★★）★★', () async {
      // ★**上限に当たったとき★資格情報は正しい**（★21 / 23 と同じ分け方）。
      final server = await _serve((request) async {
        await _reply(request, 429, jsonEncode({'ok': false}));
      });
      addTearDown(() => server.close(force: true));
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await touchDeviceRoster(
        client: client,
        server: Uri.parse('https://localhost:${server.port}'),
        userName: 'みつき',
        password: 'ひみつ',
        deviceId: 'DEV-1',
        join: true,
      );

      expect(result, isA<SyncUnreachable<DeviceRoster>>());
    });

    test('★ つながらなければ SyncUnreachable（★投げない）', () async {
      final client = _client();
      addTearDown(() => client.close(force: true));

      final result = await touchDeviceRoster(
        client: client,
        server: Uri.parse('https://localhost:1'),
        userName: 'みつき',
        password: 'ひみつ',
        deviceId: 'DEV-1',
        join: true,
      );

      expect(result, isA<SyncUnreachable<DeviceRoster>>());
    });
  });

  group('★★ 配線 —— ★★外れていたら器を戻す（§32-6 の 26 ＋ 27）★★', () {
    late HttpServer server;
    late HttpClient client;
    late bool known;
    late List<String> sentDeviceIds;
    late List<bool> sentJoins;

    setUp(() async {
      known = true;
      sentDeviceIds = [];
      sentJoins = [];
      server = await _serve((request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, Object?>;
        sentDeviceIds.add(body[syncDeviceIdKey]! as String);
        sentJoins.add(body[syncJoinKey]! as bool);
        await _reply(
            request,
            200,
            jsonEncode({
              'ok': true,
              syncKnownKey: known,
              syncDeviceIdsKey: [body[syncDeviceIdKey]],
            }));
      });
      client = _client();
    });

    tearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    Future<SyncOutcome<DeviceRoster>> run(_FakeIdentity identity) =>
        syncDeviceRoster(
          client: client,
          server: Uri.parse('https://localhost:${server.port}'),
          userName: 'みつき',
          password: 'ひみつ',
          identity: identity,
          newDeviceId: () => 'NEW-1',
        );

    test('★★ 名簿に居れば★器を 1 バイトも触らない ★★', () async {
      final identity =
          _FakeIdentity(identity: (userName: 'みつき', deviceId: 'DEV-1'));

      await run(identity);

      expect(identity.forgotten, 0);
      expect(sentDeviceIds, ['DEV-1'], reason: '★★覚えている同定を使う★★');
      // ★★ 2026-09-02: ★★居れば 1 回で済む（決定 D148-1）★★
      //   ★**代償は「★名簿に居ないときだけ 1 回増える」である。★★定常では増えない★★。**
      expect(sentJoins, [false], reason: '★★問うだけ ＝ 名簿を 1 行も増やさない★★');
    });

    test('★★ 居なければ★器を戻す（**D121-7** ＝ 落-1）★★', () async {
      known = false;
      final identity =
          _FakeIdentity(identity: (userName: 'みつき', deviceId: 'DEV-1'));

      await run(identity);

      expect(identity.forgotten, 1);
    });

    test('★★ 同定が無ければ★ここで作って記録する（**D145-3**）★★', () async {
      known = false; // ★★初めての端末なので★サーバーは必ず false を返す★★
      final identity = _FakeIdentity();

      await run(identity);

      expect(identity.recorded, [(userName: 'みつき', deviceId: 'NEW-1')]);
      // ★★ 2026-09-02: ★名簿に居ないので★2 回投げる（決定 **D148-1**）★★
      //   ★**段 1（問う）と 段 3（記録する）。★★同じ同定を名乗る★★。**
      expect(sentDeviceIds, ['NEW-1', 'NEW-1']);
      expect(sentJoins, [false, true]);
      expect(identity.forgotten, 1, reason: '★★行が 0 件なら★何も消えない★★');
    });

    test('★★ 別の利用者なら★作り直す（★★入り直しの痕跡を残さない★★ / D125-1）★★',
        () async {
      final identity =
          _FakeIdentity(identity: (userName: 'かおり', deviceId: 'OLD-1'));

      await run(identity);

      expect(identity.recorded, [(userName: 'みつき', deviceId: 'NEW-1')]);
      expect(sentDeviceIds, ['NEW-1'],
          reason: '★★前のアカウントの同定を★名乗らない★★');
    });

    test('★★ 通信が失敗したら★器を 1 バイトも触らない ★★', () async {
      // ★★ 触ると、★★つながらなかっただけで★基準を捨てる★★ ★★
      final identity =
          _FakeIdentity(identity: (userName: 'みつき', deviceId: 'DEV-1'));

      final result = await syncDeviceRoster(
        client: client,
        server: Uri.parse('https://localhost:1'),
        userName: 'みつき',
        password: 'ひみつ',
        identity: identity,
        newDeviceId: () => 'NEW-1',
      );

      expect(result, isA<SyncUnreachable<DeviceRoster>>());
      expect(identity.forgotten, 0);
    });

    test('★★ 名乗れなかったときも★触らない ★★', () async {
      final rejecting = await _serve((request) async {
        await _reply(request, 401, jsonEncode({'ok': false}));
      });
      addTearDown(() => rejecting.close(force: true));
      final identity =
          _FakeIdentity(identity: (userName: 'みつき', deviceId: 'DEV-1'));

      final result = await syncDeviceRoster(
        client: client,
        server: Uri.parse('https://localhost:${rejecting.port}'),
        userName: 'みつき',
        password: 'ちがう',
        identity: identity,
        newDeviceId: () => 'NEW-1',
      );

      expect(result, isA<SyncRejected<DeviceRoster>>());
      expect(identity.forgotten, 0);
    });
  });

  // ★★ 順序 —— ★★問う → 器を消す → 記録する（決定 D148-1 / 運転指示【0】(4)）★★
  //
  // ★★ 何を守っているか ★★
  // ★**§80-4 が「★途中で落ちたときは★★自分で直らない★★」と記録した分である。**
  // ★**記録が★器を消す★★前★★に起きると、★次の同期が `known: true` を返して★器が古いまま残る。**
  // → ★**この群は★★3 段の順序そのもの★★を見る。**
  group('★★ 順序 —— ★問う → 器を消す → 記録する（決定 D148-1）★★', () {
    late HttpServer server;
    late HttpClient client;
    late List<bool> sentJoins;
    late List<String> order;
    late bool failJoin;

    setUp(() async {
      sentJoins = [];
      order = [];
      failJoin = false;
      server = await _serve((request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, Object?>;
        final join = body[syncJoinKey]! as bool;
        sentJoins.add(join);
        order.add(join ? 'join' : 'ask');
        if (join && failJoin) {
          await _reply(request, 500, jsonEncode({'ok': false}));
          return;
        }
        await _reply(
            request,
            200,
            jsonEncode({
              'ok': true,
              syncKnownKey: false,
              syncDeviceIdsKey: [body[syncDeviceIdKey]],
            }));
      });
      client = _client();
    });

    tearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    Future<SyncOutcome<DeviceRoster>> run(_OrderedIdentity identity) =>
        syncDeviceRoster(
          client: client,
          server: Uri.parse('https://localhost:${server.port}'),
          userName: 'みつき',
          password: 'ひみつ',
          identity: identity,
          newDeviceId: () => 'NEW-1',
        );

    test('★★ 3 段が★この順で起きる（★★記録は★器を消したあとである★★）★★', () async {
      final identity = _OrderedIdentity(order,
          identity: (userName: 'みつき', deviceId: 'DEV-1'));

      await run(identity);

      expect(order, ['ask', 'forget', 'join']);
    });

    test('★★ 問う段は★名簿を 1 行も増やさない（`join: false`）★★', () async {
      final identity = _OrderedIdentity(order,
          identity: (userName: 'みつき', deviceId: 'DEV-1'));

      await run(identity);

      expect(sentJoins, [false, true]);
    });

    test('★★ 記録が落ちても★器は消えたままである（★★次の同期が同じ経路を通る★★）★★',
        () async {
      failJoin = true;
      final identity = _OrderedIdentity(order,
          identity: (userName: 'みつき', deviceId: 'DEV-1'));

      final result = await run(identity);

      expect(result, isA<SyncUnreachable<DeviceRoster>>(),
          reason: '★★落ちたことを★呼ぶ側に返す★★');
      expect(identity.forgotten, 1);
      expect(order, ['ask', 'forget', 'join']);
    });

    test('★★ もう一度通しても★同じ状態になる（★★冪等★★）★★', () async {
      final identity = _OrderedIdentity(order,
          identity: (userName: 'みつき', deviceId: 'DEV-1'));

      await run(identity);
      order.clear();
      await run(identity);

      expect(order, ['ask', 'forget', 'join'],
          reason: '★★2 度目も★同じ経路を通る★★');
      expect(identity.forgotten, 2, reason: '★★2 度消しても★結果は同じである★★');
    });
  });

  group('★★ 走査 —— ★★パスと鍵の名前が★両側で同じである（**D126-3** の代償）★★', () {
    // ★★ 純粋関数にする —— ★★合成の入力で対を作れるようにするため★★ ★★
    //   ★**実測: ★本番のファイルだけを見る形だと、★★コメント外しに対が届かない★★**
    //     （★★サーバーの doc は★パスを★引用符ではなく★★逆引用符★★で書いている★★ / ★仕込んで 0 件）。
    //   ★**先例は §63-7 の (J) / §76-4 の (T)** —— ★★同じ処置である★★。
    bool declaresIn(String source, String literal) =>
        stripComments(source).contains("'$literal'");

    late String serverSource;

    setUpAll(() {
      serverSource = File(_serverDeviceEndpoint).readAsStringSync();
    });

    test('★★ パスが同じ（★★引用符ごと見る★★ / D-37 の裏）★★', () {
      expect(declaresIn(serverSource, devicesPath), isTrue);
    });

    test('★ 送る鍵の名前が同じ', () {
      expect(declaresIn(serverSource, syncDeviceIdKey), isTrue);
      expect(declaresIn(serverSource, syncUserNameKey), isTrue);
      expect(declaresIn(serverSource, syncPasswordKey), isTrue);
      // ★★ 2026-09-02: ★`join` を足した（決定 **D148-1**）★★
      //   ★**引き金**: ★`syncJoinKey` の字面を変えても★★1 件も落ちなかった★★
      //     （★2026-09-02 実測 / ★0 件）—— ★**両側が★★同じ定数を読む★★ので★一緒に動く。**
      //   ★**原因は★★対の形★★である**（**D-27** / ★先例は §72 の (D)(J)）。
      //   → ★**サーバーのソースに★★引用符ごと在ること★★を見る。**
      expect(declaresIn(serverSource, syncJoinKey), isTrue);
    });

    test('★ 返る鍵の名前が同じ', () {
      expect(declaresIn(serverSource, syncKnownKey), isTrue);
      expect(declaresIn(serverSource, syncDeviceIdsKey), isTrue);
    });

    test('★★ 対: ★doc の中の写しは★コメント外しが落とす（★★D-30★★）★★', () {
      // ★★ 合成の入力で対を作る —— ★★本番の doc は★引用符で書いていないからである★★
      //   ★**外さないと、★★doc に写しが在るだけで★通ってしまう★★。**
      final lines = <String>[
        "/// ★doc の写し: ★パスは '/devices' である。",
        "const String devicesPath = '/★ちがうパス';",
      ];
      final source = lines.join(String.fromCharCode(10));

      expect(source.contains("'/devices'"), isTrue, reason: '★陽性対照');
      expect(declaresIn(source, '/devices'), isFalse);
    });

    test('★★ 対: ★字面が違えば★この走査が捕まえる（★陽性対照）★★', () {
      expect(declaresIn(serverSource, '/★実在しないパス'), isFalse);
    });
  });

  group('★★ 実 DB —— ★★橋渡しが★2 つの表を正しく触る（**D-10**）★★', () {
    late Directory tmp;
    late LovecaDatabase db;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('loveca_device_store_test');
      db = await openAppDatabase(File(p.join(tmp.path, 'loveca.db')));
    });

    tearDown(() async {
      await db.close();
      tmp.deleteSync(recursive: true);
    });

    DaoDeviceIdentityStore storeOn() =>
        DaoDeviceIdentityStore(SyncIdentityDao(db), DeckSyncMarkDao(db));

    test('★★ 記録すると★読み戻せる（★★橋渡しが通っている★★）★★', () async {
      final store = storeOn();
      expect(await store.currentIdentity(), isNull);

      await store.recordIdentity(userName: 'みつき', deviceId: 'DEV-1');

      expect(await store.currentIdentity(),
          (userName: 'みつき', deviceId: 'DEV-1'));
    });

    test('★★ 器を全部消す（★★ログには触れない★★）★★', () async {
      final marks = DeckSyncMarkDao(db);
      await marks.record(
          deckId: 'D-1', logMark: 1, baselineHash: 'sha256:aa');
      await marks.record(
          deckId: 'D-2', logMark: 2, baselineHash: 'sha256:bb');
      await db.into(db.deckEditOps).insert(DeckEditOpsCompanion.insert(
            deckId: 'D-1',
            kind: DeckEditOpKind.setName.key,
            at: DateTime.utc(2026, 9, 2),
          ));

      await storeOn().forgetAllMarks();

      expect(await marks.baselineFor('D-1'), isNull);
      expect(await marks.baselineFor('D-2'), isNull);
      expect(await db.select(db.deckEditOps).get(), hasLength(1),
          reason: '★★未送信の編集を★失わせない★★');
    });

    test('★★ 同定を消しても★器は残る（★★別の表である★★ / D125-9）★★', () async {
      final store = storeOn();
      final marks = DeckSyncMarkDao(db);
      await store.recordIdentity(userName: 'みつき', deviceId: 'DEV-1');
      await marks.record(
          deckId: 'D-1', logMark: 1, baselineHash: 'sha256:aa');

      await SyncIdentityDao(db).forget();

      expect(await store.currentIdentity(), isNull);
      expect(await marks.baselineFor('D-1'), isNotNull,
          reason: '★★器はデッキごと、★同定は DB 全体で 1 つ★★');
    });

    test('★★ 対: ★器を消しても★同定は残る（★逆向き）★★', () async {
      final store = storeOn();
      await store.recordIdentity(userName: 'みつき', deviceId: 'DEV-1');
      await DeckSyncMarkDao(db)
          .record(deckId: 'D-1', logMark: 1, baselineHash: 'sha256:aa');

      await store.forgetAllMarks();

      expect(await store.currentIdentity(),
          (userName: 'みつき', deviceId: 'DEV-1'));
    });
  });
}
