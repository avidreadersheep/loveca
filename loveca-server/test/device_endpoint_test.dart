/// ★★ 端末の名簿の口（★§32-6 の **26** / 決定 **D145**）★★
///
/// ★★ この群はサーバー側だけを見る。★呼ぶ側は 1 行も無い ★★
/// ★**アプリ側の口は `loveca-ui` に在る**（★別の試験）。
///
/// ★★ 時間を測る検査は 1 つも無い（**D-28**）★★
/// ★**時刻を★★渡して★★動かす**（`serveApi` が `clock` を受け取る）。
/// ★**先例は `rate_limit_test.dart`。**
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
  late DeviceFileStore devices;
  late HttpServer server;
  late HttpClient client;
  late DateTime clockNow;

  const user = 'みつき';
  const pass = 'ひみつ';
  const other = 'かおり';
  const otherPass = 'べつのひみつ';

  // ★★ 2026-09-02: ★`join` が増えた（**D148-1**）★★
  //   ★**既定を `true` にしてある** —— ★★旧の「判定 ＋ 記録」と★同じ振る舞いになる★★ので、
  //     ★**この下の群は★1 件も書き換わっていない**（★`join: false` の群は★別に置いた）。
  Map<String, Object?> body(String deviceId,
          {String userName = user, String password = pass, bool join = true}) =>
      {
        'userName': userName,
        'password': password,
        deviceIdKey: deviceId,
        deviceJoinKey: join,
      };

  Future<({bool known, List<String> ids})> touch(String deviceId,
      {String userName = user,
      String password = pass,
      bool join = true}) async {
    final res = await _post(client, server.port, devicesPath,
        body(deviceId, userName: userName, password: password, join: join));
    expect(res.status, HttpStatus.ok);
    final decoded = jsonDecode(res.body) as Map<String, Object?>;
    return (
      known: decoded[deviceKnownKey]! as bool,
      ids: (decoded[deviceIdsKey]! as List<Object?>).cast<String>(),
    );
  }

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('loveca_device_test');
    accounts = AccountFileStore.open(
        '${dir.path}${Platform.pathSeparator}accounts.json');
    decks =
        DeckFileStore(Directory('${dir.path}${Platform.pathSeparator}decks'));
    devices = DeviceFileStore(
        Directory('${dir.path}${Platform.pathSeparator}devices'));
    clockNow = DateTime.utc(2026, 9, 2, 12);

    final context = SecurityContext()
      ..useCertificateChain(_certPath)
      ..usePrivateKey(_keyPath);
    server = await serveApi(
      context: context,
      store: accounts,
      decks: decks,
      devices: devices,
      accountIterations: 10,
      clock: () => clockNow,
      rateLimits: const RateLimitPolicySet.unlimited(),
    );

    final clientContext = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificates(_certPath);
    client = HttpClient(context: clientContext);

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

  group('★★ 名簿に触れる（★§32-6 の 26）★★', () {
    test('★★ 初めての端末は★`known` が false（★★居なかった★★）★★', () async {
      final got = await touch('DEV-1');

      expect(got.known, isFalse);
      expect(got.ids, ['DEV-1'], reason: '★★自分も全端末の 1 つである★★');
    });

    test('★★ 2 度目は★`known` が true（★★引き金が立たない★★）★★', () async {
      await touch('DEV-1');

      final got = await touch('DEV-1');

      expect(got.known, isTrue);
      expect(got.ids, ['DEV-1']);
    });

    test('★★ 別の端末が足される（★★全端末の集合★★ / N-19 の 事実 1）★★', () async {
      await touch('DEV-1');

      final got = await touch('DEV-2');

      expect(got.known, isFalse, reason: '★DEV-2 は初めてである');
      expect(got.ids, ['DEV-1', 'DEV-2']);
    });

    test('★★ 並びは★字面の昇順である（★★保管した順を返さない★★）★★', () async {
      // ★**§55-3 の一覧の口と★同じ理由** —— ★2 台が★同じ集合を持っても
      //   ★★並びが違うと★呼ぶ側が比べられない★★。
      await touch('DEV-9');
      await touch('DEV-1');

      final got = await touch('DEV-5');

      expect(got.ids, ['DEV-1', 'DEV-5', 'DEV-9']);
    });

    test('★★ 利用者ごとに★別の名簿である（★★混ざらない★★）★★', () async {
      await touch('DEV-1');

      final got = await touch('DEV-1', userName: other, password: otherPass);

      expect(got.known, isFalse, reason: '★★同じ字面でも★別の利用者の端末である★★');
      expect(got.ids, ['DEV-1']);
      expect(devices.listDeviceIds(user), ['DEV-1']);
      expect(devices.listDeviceIds(other), ['DEV-1']);
    });
  });

  group('★★ 外す（**D145-1** ＝ 判-1。★★サーバーが判断する★★）★★', () {
    test('★★ 期間より長くつながらないと★外れる（★`known` が false に戻る）★★',
        () async {
      await touch('DEV-1');
      clockNow = clockNow.add(const Duration(days: 11));

      final got = await touch('DEV-1');

      expect(got.known, isFalse, reason: '★★10 日を超えた★★');
    });

    test('★★ 対: ★期間の内なら★外れない（★★境界を見る★★）★★', () async {
      await touch('DEV-1');
      clockNow = clockNow.add(const Duration(days: 9, hours: 23));

      final got = await touch('DEV-1');

      expect(got.known, isTrue);
    });

    test('★★ 他の端末も★外れる（★★自分だけを見ていない★★）★★', () async {
      await touch('DEV-1');
      await touch('DEV-2');
      clockNow = clockNow.add(const Duration(days: 11));

      final got = await touch('DEV-1');

      expect(got.ids, ['DEV-1'], reason: '★★DEV-2 は外れている★★');
    });

    test('★★ 触った端末だけ★時刻が進む（★他は据え置き）★★', () async {
      await touch('DEV-1');
      await touch('DEV-2');
      clockNow = clockNow.add(const Duration(days: 6));
      await touch('DEV-1');
      clockNow = clockNow.add(const Duration(days: 6));

      // ★DEV-1 は 6 日前 / ★DEV-2 は 12 日前。
      final got = await touch('DEV-1');

      expect(got.known, isTrue, reason: '★DEV-1 は 6 日前に触れている');
      expect(got.ids, ['DEV-1'], reason: '★★DEV-2 だけが外れる★★');
    });

    test('★★ 外してから★見る（★★自分自身も外れうる★★ / 順序の対）★★', () async {
      // ★★ 段の順序が意味を持つ ★★
      //   ★**先に記録すると、★★自分が「居た」と数えられてしまう★★。**
      //   ★→ ★10 日以上ぶりに繋いだ端末が★★外れたことに気づけない★★。
      await touch('DEV-1');
      clockNow = clockNow.add(const Duration(days: 30));

      final got = await touch('DEV-1');

      expect(got.known, isFalse);
      // ★対: そのあとは★居る（★記録は済んでいる）。
      expect((await touch('DEV-1')).known, isTrue);
    });
  });

  group('★★ 柵: ★名乗りが先である（★★名簿を 1 バイトも触らない★★）★★', () {
    test('★★ パスワードが違えば 401（★★名簿に行が増えない★★）★★', () async {
      final res = await _post(client, server.port, devicesPath,
          body('DEV-1', password: 'ちがう'));

      expect(res.status, HttpStatus.unauthorized);
      expect(devices.listDeviceIds(user), isEmpty);
    });

    test('★★ 無い利用者名も 401（★★在る / 無いを状態で分けない★★ / D130 の柵）★★',
        () async {
      final res = await _post(client, server.port, devicesPath,
          body('DEV-1', userName: 'だれか', password: 'なにか'));

      expect(res.status, HttpStatus.unauthorized);
    });

    test('★★ 対: ★通れば★名簿に行が増える（★陽性対照）★★', () async {
      await touch('DEV-1');

      expect(devices.listDeviceIds(user), ['DEV-1']);
    });
  });

  group('★★ 壊れた要求 / 空（★20 と同じ分け方）★★', () {
    test('★ 表でない本文は 400', () async {
      final res = await _post(client, server.port, devicesPath, '[]');
      expect(res.status, HttpStatus.badRequest);
    });

    test('★ 端末の同定が無ければ 400', () async {
      final res = await _post(client, server.port, devicesPath,
          {'userName': user, 'password': pass});
      expect(res.status, HttpStatus.badRequest);
    });

    test('★★ 空の端末の同定は 400（★★空は断る★★ / D133-9）★★', () async {
      final res = await _post(client, server.port, devicesPath, body(''));
      expect(res.status, HttpStatus.badRequest);
      expect(devices.listDeviceIds(user), isEmpty);
    });

    test('★ GET は 405', () async {
      final res =
          await _post(client, server.port, devicesPath, '', method: 'GET');
      expect(res.status, HttpStatus.methodNotAllowed);
    });

    test('★★ 壊れた要求は★名乗りより★先に断る（★★401 ではない★★）★★', () async {
      // ★**D131-6** と同じ分け方（★400 は「送り手の作りが違う」、★401 は「資格情報が違う」）。
      final res = await _post(client, server.port, devicesPath, '[]');
      expect(res.status, HttpStatus.badRequest);
    });
  });

  group('★★ 置き場が渡されていなければ 404（★★静かに 200 を返さない★★）★★', () {
    test('★ 名簿を渡さずに立てた待ち受けでは 404', () async {
      final context = SecurityContext()
        ..useCertificateChain(_certPath)
        ..usePrivateKey(_keyPath);
      final bare = await serveApi(
        context: context,
        store: accounts,
        decks: decks,
        accountIterations: 10,
        rateLimits: const RateLimitPolicySet.unlimited(),
      );
      addTearDown(() => bare.close(force: true));

      final res = await _post(client, bare.port, devicesPath, body('DEV-1'));

      expect(res.status, HttpStatus.notFound);
    });
  });

  group('★★ 振り分け（★完全一致 / D130-7）★★', () {
    test('★★ `/devices` は★デッキの口に吸われない ★★', () async {
      // ★**`switch` は完全一致である**（★接頭辞で振り分けていない）。
      final res = await _post(client, server.port, devicesPath, body('DEV-1'));
      expect(res.status, HttpStatus.ok);
      expect(jsonDecode(res.body), containsPair(deviceKnownKey, false));
    });

    test('★ 知らないパスは 404', () async {
      final res =
          await _post(client, server.port, '/devices/list', body('DEV-1'));
      expect(res.status, HttpStatus.notFound);
    });
  });

  group('★★ 既定値（**N-19** の (2-b) は★利用者判断のまま）★★', () {
    test('★★ 既定の期間は 10 日である（**D124-3**）★★', () {
      // ★★ 差し替え点は★この定数 1 つである ★★
      //   ★**口も保管も★値を持たない**（★どちらも引数で受け取る）。
      expect(defaultDeviceMaxIdle, const Duration(days: 10));
    });

    test('★★ 期間は★呼び出し側から渡せる（★★差し替え点が効く★★）★★', () async {
      final context = SecurityContext()
        ..useCertificateChain(_certPath)
        ..usePrivateKey(_keyPath);
      var now = DateTime.utc(2026, 9, 2, 12);
      final short = await serveApi(
        context: context,
        store: accounts,
        decks: decks,
        devices: devices,
        deviceMaxIdle: const Duration(days: 1),
        accountIterations: 10,
        clock: () => now,
        rateLimits: const RateLimitPolicySet.unlimited(),
      );
      addTearDown(() => short.close(force: true));

      await _post(client, short.port, devicesPath, body('DEV-1'));
      now = now.add(const Duration(days: 2));
      final res = await _post(client, short.port, devicesPath, body('DEV-1'));

      final decoded = jsonDecode(res.body) as Map<String, Object?>;
      expect(decoded[deviceKnownKey], isFalse, reason: '★★1 日で外れた★★');
    });
  });

  group('★★ 保管の形（★DeckFileStore と同じ / D134-7）★★', () {
    test('★★ 受け取った利用者名を★ファイル名にしない ★★', () async {
      await touch('DEV-1', userName: other, password: otherPass);

      final dirEntries = Directory('${dir.path}${Platform.pathSeparator}devices')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toList();
      expect(dirEntries, hasLength(1));
      expect(dirEntries.single, isNot(contains(other)));
      expect(dirEntries.single, endsWith('.json'));
    });

    test('★★ 利用者名は★ファイルの中に持つ（★戻せなくならないため）★★', () async {
      await touch('DEV-1');

      final file = Directory('${dir.path}${Platform.pathSeparator}devices')
          .listSync()
          .whereType<File>()
          .single;
      final decoded =
          jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      expect(decoded['userName'], user);
      expect(decoded['version'], deviceFileVersion);
    });

    test('★★ 一時ファイルが残らない（★置き換えで書く）★★', () async {
      await touch('DEV-1');

      final names = Directory('${dir.path}${Platform.pathSeparator}devices')
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .toList();
      expect(names.where((n) => n.endsWith('.tmp')), isEmpty);
    });

    test('★★ 対: ★一時ファイルへ書けなければ★元が残る（★★直に書いていない★★）★★',
        () async {
      // ★★ D-27: ★上の対は★★直に書く実装でも通る★★（★実測 0 件）★★
      //   ★**「`.tmp` が残らない」は★★置き換えでも★直書きでも真である★★。**
      //   → ★**一時ファイルの場所を塞いで、★★元の 1 件が残ることを見る★★**
      //     （★先例は **D134** の (L) —— ★★同じ処置である★★）。
      await touch('DEV-1');
      final dirPath = '${dir.path}${Platform.pathSeparator}devices';
      final file = Directory(dirPath).listSync().whereType<File>().single;
      final before = file.readAsStringSync();

      // ★一時ファイルの場所に★ディレクトリを置く（★書き込みが必ず失敗する）。
      Directory('${file.path}.tmp').createSync();

      // ★★ 待ち受けを通さない —— ★保管だけを見る ★★
      expect(
        () => devices.touch('みつき', 'DEV-2',
            now: clockNow, maxIdle: defaultDeviceMaxIdle, join: true),
        throwsA(anything),
      );
      expect(file.readAsStringSync(), before,
          reason: '★★元の 1 件が★1 バイトも変わっていない★★');
    });
  });

  // ★★ `join` —— ★★問う → 器を消す → 記録する、の★「問う」を作る（決定 D148-1）★★
  //
  // ★★ なぜ要るか ★★
  // ★**旧は「★判定 ＋ 記録」が★★1 つの要求で不可分だった★★**ので、
  //   ★★記録のあとに呼ぶ側が器を消し損ねると★次の要求が `known: true` を返し、★器が古いまま残った★★
  //   （★`docs/同期設計メモ.md` §80-4）。
  // → ★**記録を★★後ろへ移せる形にする★★**（★順序で解く / ★新しい量は 1 つも要らない）。
  group('★★ `join` —— ★記録を★呼ぶ側が後ろへ移せる（決定 D148-1）★★', () {
    test('★★ `join: false` は★名簿に居ない端末を★書き加えない ★★', () async {
      final got = await touch('DEV-1', join: false);

      expect(got.known, isFalse);
      expect(got.ids, isEmpty, reason: '★★自分も入っていない★★');
      expect(devices.listDeviceIds(user), isEmpty);
    });

    test('★★ 対: ★`join: true` なら★書き加える ★★', () async {
      await touch('DEV-1', join: false);
      final got = await touch('DEV-1', join: true);

      expect(got.known, isFalse, reason: '★★書く★前★の値を返す★★');
      expect(devices.listDeviceIds(user), ['DEV-1']);
    });

    test('★★ `join: false` を★何度投げても★名簿は 0 件のままである（★冪等）★★', () async {
      await touch('DEV-1', join: false);
      await touch('DEV-1', join: false);
      await touch('DEV-1', join: false);

      expect(devices.listDeviceIds(user), isEmpty);
    });

    test('★★ `join: false` でも★★居る端末の時刻は書き直す★★（★★10 日で外れない★★）★★', () {
      // ★★ 待ち受けを通さない —— ★時刻をこちらが動かす（**D-28**）★★
      const user2 = 'ときめき';
      final t0 = DateTime.utc(2026, 9, 1, 12);
      devices.touch(user2, 'DEV-1',
          now: t0, maxIdle: defaultDeviceMaxIdle, join: true);

      // ★9 日後に★問うだけ（★`join: false`）
      final t1 = t0.add(const Duration(days: 9));
      final r1 = devices.touch(user2, 'DEV-1',
          now: t1, maxIdle: defaultDeviceMaxIdle, join: false);
      expect(r1.wasKnown, isTrue);

      // ★さらに 9 日後 —— ★★時刻が書き直されていれば★まだ居る★★
      final t2 = t1.add(const Duration(days: 9));
      final r2 = devices.touch(user2, 'DEV-1',
          now: t2, maxIdle: defaultDeviceMaxIdle, join: false);
      expect(r2.wasKnown, isTrue,
          reason: '★★書き直していなければ★18 日ぶんで外れている★★');
    });

    test('★★ `join` の鍵が無ければ 400（★★省けない★★ / 先例は D141-4）★★', () async {
      final res = await _post(client, server.port, devicesPath, {
        'userName': user,
        'password': pass,
        deviceIdKey: 'DEV-1',
      });

      expect(res.status, HttpStatus.badRequest);
      expect(devices.listDeviceIds(user), isEmpty,
          reason: '★★1 バイトも書いていない★★');
    });

    test('★ `join` が真偽値でなければ 400', () async {
      final res = await _post(client, server.port, devicesPath, {
        'userName': user,
        'password': pass,
        deviceIdKey: 'DEV-1',
        deviceJoinKey: 'true',
      });

      expect(res.status, HttpStatus.badRequest);
    });

    test('★★ 柵: ★名乗りが通らなければ★`join` を見る前に 401 ★★', () async {
      final res = await _post(client, server.port, devicesPath, {
        'userName': user,
        'password': 'ちがう',
        deviceIdKey: 'DEV-1',
        deviceJoinKey: true,
      });

      expect(res.status, HttpStatus.unauthorized);
      expect(devices.listDeviceIds(user), isEmpty);
    });

    test('★★ `join: false` でも★★古いものは外す★★（★段 1 は条件つきでない）★★', () {
      const user2 = 'あやむ';
      final t0 = DateTime.utc(2026, 9, 1, 12);
      devices.touch(user2, 'OLD',
          now: t0, maxIdle: defaultDeviceMaxIdle, join: true);
      expect(devices.listDeviceIds(user2), ['OLD']);

      final t1 = t0.add(const Duration(days: 11));
      final got = devices.touch(user2, 'NEW',
          now: t1, maxIdle: defaultDeviceMaxIdle, join: false);

      expect(got.wasKnown, isFalse);
      expect(devices.listDeviceIds(user2), isEmpty,
          reason: '★★外した結果は★join に関わらず保存する★★');
    });
  });
}
