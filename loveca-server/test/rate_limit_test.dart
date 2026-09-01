/// ★★ 呼ばれる回数の上限 —— **N-26**（★★門 セ★★）の★★既定値★★ ★★
///
/// ★★ これは★決定を固定する群ではない。★★既定値を固定する群である ★★
/// ★**N-26** の (1) は★★利用者判断のまま★★である（`docs/同期設計メモ.md` §10 の **N-26**）。
/// ★**既定値の根拠と差し替え点の正は `docs/利用者への問い.md` の **Q-01**。**
///
/// ★★ 時間を測らない（**D-28**）★★
/// ★**待って測る検査は★機械の状態で揺れる。**→ ★**時刻を★★渡して★★動かす。**
/// ★**`serveApi` / `RateLimiter` が★どちらも `clock` を受け取る**のはこのためである。
library;

import 'dart:convert';
import 'dart:io';

import 'package:loveca_server/loveca_server.dart';
import 'package:test/test.dart';

const _fixtureDir = 'test/fixtures/tls';
const _certPath = '$_fixtureDir/localhost-TEST-ONLY.cert.pem';
const _keyPath = '$_fixtureDir/localhost-TEST-ONLY.key.pem';

Future<int> _post(
  HttpClient client,
  int port,
  String path,
  Object? body,
) async {
  final request =
      await client.openUrl('POST', Uri.parse('https://localhost:$port$path'));
  request.headers.contentType = ContentType.json;
  request.write(jsonEncode(body));
  final response = await request.close();
  await utf8.decoder.bind(response).join();
  return response.statusCode;
}

void main() {
  group('★★ 方針の値（★限-1 は★同じ型の 1 つの値である）★★', () {
    test('★★ 断らない方針でも★型は同じである（決定 D114-7 の理由 2 を踏まない）★★', () {
      const unlimited = RateLimitPolicy.unlimited();
      const limited =
          RateLimitPolicy.perWindow(maxRequests: 3, window: Duration(minutes: 1));

      expect(unlimited, isA<RateLimitPolicy>());
      expect(limited, isA<RateLimitPolicy>());
      expect(unlimited.isUnlimited, isTrue);
      expect(limited.isUnlimited, isFalse);
    });

    test('★★ 0 は「断らない」ではない（★意味が正反対である）★★', () {
      // ★★ `refuses` が別に持つので、★0 が「断らない」に化けない ★★
      expect(const RateLimitPolicy.unlimited().refuses, isFalse);
      expect(
        const RateLimitPolicy.perWindow(
                maxRequests: 1, window: Duration(seconds: 1))
            .refuses,
        isTrue,
      );
    });

    test('★ 既定は 60 秒に 5 回である（★値そのものの固定）', () {
      expect(defaultRateLimit.isUnlimited, isFalse);
      expect(defaultRateLimit.maxRequests, 5);
      expect(defaultRateLimit.window, const Duration(seconds: 60));
    });
  });

  group('★★ 枠（**N-27** の 論点 (2) の★★既定値★★ / 2026-09-02）★★', () {
    test('★★ 既定は★人が押す枠 5 / ★同期の枠 33 である（★値そのものの固定）★★', () {
      // ★★ 導き方の正は `src/rate_limit.dart` の doc ★★
      //   ★**60000 ms ÷ 1573 ms ＝ 38**（★★2026-09-02 実測 / この機械★★）。★**38 − 5 ＝ 33。**
      expect(defaultRateLimits.human.maxRequests, 5);
      expect(defaultRateLimits.deckSync.maxRequests, 33);
      expect(defaultRateLimits.human.window, const Duration(seconds: 60));
      expect(defaultRateLimits.deckSync.window, const Duration(seconds: 60));
    });

    test('★★ 合計は★測った上限を超えない（★★導き方そのものを固定する★★）★★', () {
      // ★★ これが「値が導かれている」ことの対である ★★
      //   ★**片方を上げたら★もう片方を下げないと落ちる。**
      const measuredCostMs = 1573;
      const windowMs = 60 * 1000;
      final ceiling = windowMs ~/ measuredCostMs;

      expect(ceiling, 38, reason: '★★2026-09-02 実測 / ★この機械★★');
      expect(
        defaultRateLimits.human.maxRequests +
            defaultRateLimits.deckSync.maxRequests,
        lessThanOrEqualTo(ceiling),
      );
    });

    test('★★ 既定は★1 回の同期を通す（★★相談役が名指しした場合★★）★★', () {
      // ★★ 1 回の同期 ＝ 1 ＋ デッキの数（★§10 の **N-27** の事実 2）★★
      expect(defaultRateLimits.deckSync.maxRequests,
          greaterThanOrEqualTo(1 + 5));
      // ★★ 同じ住所の 2 台 × デッキ 2 つ（★同 事実 5）★★
      expect(defaultRateLimits.deckSync.maxRequests,
          greaterThanOrEqualTo(2 * (1 + 2)));
    });

    test('★★ 枠-1 に戻す形が★型として在る（★決まっていない分岐を先に置かない）★★', () {
      const back = RateLimitPolicySet.uniform(defaultRateLimit);

      expect(back.human.maxRequests, 5);
      expect(back.deckSync.maxRequests, 5);
    });

    test('★★ デッキの 3 つの口は★同期の枠である ★★', () {
      expect(rateLimitFrameFor(decksPath), RateLimitFrame.deckSync);
      expect(rateLimitFrameFor(decksFetchPath), RateLimitFrame.deckSync);
      expect(rateLimitFrameFor(decksListPath), RateLimitFrame.deckSync);
    });

    test('★★ 対: 人が押す口と★知らないパスは★人が押す枠である ★★', () {
      expect(rateLimitFrameFor(authPath), RateLimitFrame.human);
      expect(rateLimitFrameFor(accountsPath), RateLimitFrame.human);
      expect(rateLimitFrameFor('/★知らないパス'), RateLimitFrame.human);
    });

    test('★★ 枠ごとに★別の勘定である（★鍵を混ぜていない）★★', () {
      var now = DateTime.utc(2026, 9, 2, 12);
      final limiter = ApiRateLimiter(
        const RateLimitPolicySet(
          human: RateLimitPolicy.perWindow(
              maxRequests: 1, window: Duration(seconds: 60)),
          deckSync: RateLimitPolicy.perWindow(
              maxRequests: 1, window: Duration(seconds: 60)),
        ),
        clock: () => now,
      );

      expect(limiter.allow(RateLimitFrame.human, 'a'), isTrue);
      // ★★ 同じ鍵でも★枠が違えば★まだ通る ★★
      expect(limiter.allow(RateLimitFrame.deckSync, 'a'), isTrue);
      // ★★ 対: 同じ枠なら★断られる ★★
      expect(limiter.allow(RateLimitFrame.human, 'a'), isFalse);
      expect(limiter.allow(RateLimitFrame.deckSync, 'a'), isFalse);
      expect(limiter.trackedKeys(RateLimitFrame.human), 1);
      expect(limiter.trackedKeys(RateLimitFrame.deckSync), 1);
    });
  });

  group('★★ 数え方（★時刻を渡す。★待たない）★★', () {
    late DateTime now;
    DateTime clock() => now;

    setUp(() => now = DateTime.utc(2026, 9, 1, 12));

    test('窓のあいだは★上限まで通り、★超えたら断る', () {
      final limiter = RateLimiter(
        const RateLimitPolicy.perWindow(
            maxRequests: 3, window: Duration(seconds: 60)),
        clock: clock,
      );

      expect(limiter.allow('a'), isTrue);
      expect(limiter.allow('a'), isTrue);
      expect(limiter.allow('a'), isTrue);
      expect(limiter.allow('a'), isFalse);
    });

    test('★★ 断った要求は★数えない（★窓が埋まったままにならない）★★', () {
      final limiter = RateLimiter(
        const RateLimitPolicy.perWindow(
            maxRequests: 2, window: Duration(seconds: 60)),
        clock: clock,
      );

      expect(limiter.allow('a'), isTrue);
      expect(limiter.allow('a'), isTrue);
      // ★★ 窓のあいだに 10 回押しても、★数えられているのは 2 件のままである ★★
      for (var i = 0; i < 10; i++) {
        expect(limiter.allow('a'), isFalse);
      }

      // ★★ 最初の 2 件が窓から出れば★また通る（★数えていたら通らない）★★
      now = now.add(const Duration(seconds: 61));
      expect(limiter.allow('a'), isTrue);
    });

    test('★ 窓を過ぎた分は忘れる', () {
      final limiter = RateLimiter(
        const RateLimitPolicy.perWindow(
            maxRequests: 2, window: Duration(seconds: 60)),
        clock: clock,
      );

      expect(limiter.allow('a'), isTrue);
      now = now.add(const Duration(seconds: 31));
      expect(limiter.allow('a'), isTrue);
      expect(limiter.allow('a'), isFalse);

      // ★1 件目だけが窓から出る
      now = now.add(const Duration(seconds: 30));
      expect(limiter.allow('a'), isTrue);
      expect(limiter.allow('a'), isFalse, reason: '★2 件目はまだ窓の中である');
    });

    test('★★ 相手ごとに別に数える ★★', () {
      final limiter = RateLimiter(
        const RateLimitPolicy.perWindow(
            maxRequests: 1, window: Duration(seconds: 60)),
        clock: clock,
      );

      expect(limiter.allow('a'), isTrue);
      expect(limiter.allow('a'), isFalse);
      expect(limiter.allow('b'), isTrue, reason: '★別の相手は別の枠である');
    });

    test('★★ 空になった相手は忘れる（★覚えている量が窓で頭打ちになる）★★', () {
      final limiter = RateLimiter(
        const RateLimitPolicy.perWindow(
            maxRequests: 5, window: Duration(seconds: 60)),
        clock: clock,
      );

      limiter.allow('a');
      limiter.allow('b');
      expect(limiter.trackedKeys, 2);

      now = now.add(const Duration(seconds: 61));
      limiter.allow('a');
      expect(limiter.trackedKeys, 1,
          reason: '★b は窓から出て忘れられ、★a だけが残る');
    });

    test('★★ 断らない方針では★何回でも通り、★1 人も覚えない ★★', () {
      final limiter =
          RateLimiter(const RateLimitPolicy.unlimited(), clock: clock);

      for (var i = 0; i < 100; i++) {
        expect(limiter.allow('a'), isTrue);
      }
      expect(limiter.trackedKeys, 0);
    });
  });

  group('★★ 待ち受けに当てる（★本物の TLS 越し / **D-10**）★★', () {
    late Directory dir;
    late HttpServer server;
    late HttpClient client;
    late DateTime now;

    Future<HttpServer> start(RateLimitPolicy policy) async {
      final context = SecurityContext()
        ..useCertificateChain(_certPath)
        ..usePrivateKey(_keyPath);
      return serveApi(
        context: context,
        store: AccountFileStore.open(
            '${dir.path}${Platform.pathSeparator}accounts.json'),
        decks: DeckFileStore(
            Directory('${dir.path}${Platform.pathSeparator}decks')),
        accountIterations: 10,
        rateLimits: RateLimitPolicySet.uniform(policy),
        clock: () => now,
      );
    }

    setUp(() {
      now = DateTime.utc(2026, 9, 1, 12);
      dir = Directory.systemTemp.createTempSync('loveca_rate_limit_test');
      final clientContext = SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificates(_certPath);
      client = HttpClient(context: clientContext);
    });

    tearDown(() async {
      client.close(force: true);
      await server.close(force: true);
      dir.deleteSync(recursive: true);
    });

    test('★★ 既定の方針では★6 回目が 429 になる（★`serveApi` の既定が効いている）★★',
        () async {
      // ★★ 方針を渡さない —— ★既定が `defaultRateLimit` であることを見る ★★
      final context = SecurityContext()
        ..useCertificateChain(_certPath)
        ..usePrivateKey(_keyPath);
      server = await serveApi(
        context: context,
        store: AccountFileStore.open(
            '${dir.path}${Platform.pathSeparator}accounts.json'),
        decks: DeckFileStore(
            Directory('${dir.path}${Platform.pathSeparator}decks')),
        accountIterations: 10,
        clock: () => now,
      );

      final statuses = <int>[];
      for (var i = 0; i < 6; i++) {
        statuses.add(await _post(client, server.port, accountsPath,
            {'userName': 'ひと$i', 'password': 'ひみつ'}));
      }

      expect(statuses.take(5), everyElement(HttpStatus.created));
      expect(statuses.last, HttpStatus.tooManyRequests);
    });

    test('★★ 対: 断らない方針なら★6 回目も通る（★上が「常に断る」で通らないこと）★★',
        () async {
      server = await start(const RateLimitPolicy.unlimited());

      final statuses = <int>[];
      for (var i = 0; i < 6; i++) {
        statuses.add(await _post(client, server.port, accountsPath,
            {'userName': 'ひと$i', 'password': 'ひみつ'}));
      }

      expect(statuses, everyElement(HttpStatus.created));
    });

    test('★★ 上限は★名乗りを見る★前★に効く（★見なければ守っていない）★★', () async {
      server = await start(const RateLimitPolicy.perWindow(
          maxRequests: 1, window: Duration(seconds: 60)));

      // ★1 回目で枠を使い切る
      expect(
        await _post(client, server.port, accountsPath,
            {'userName': 'みつき', 'password': 'ひみつ'}),
        HttpStatus.created,
      );

      // ★★ 2 回目は★★壊れた要求でも 429 である★★（★400 ではない）★★
      //   ★上限を★振り分けのあとに置いていたら、★ここが 400 になる。
      expect(
        await _post(client, server.port, accountsPath, 'これは JSON ではない'),
        HttpStatus.tooManyRequests,
      );
    });

    test('★★ 429 は★どのパスでも返る（★上限は口ごとではない）★★', () async {
      server = await start(const RateLimitPolicy.perWindow(
          maxRequests: 1, window: Duration(seconds: 60)));

      expect(
        await _post(client, server.port, accountsPath,
            {'userName': 'みつき', 'password': 'ひみつ'}),
        HttpStatus.created,
      );
      expect(
        await _post(client, server.port, authPath,
            {'userName': 'みつき', 'password': 'ひみつ'}),
        HttpStatus.tooManyRequests,
        reason: '★別のパスでも★同じ枠を使う',
      );
    });

    test('★★ 429 は★知らないパスでも返る（★404 より先である）★★', () async {
      server = await start(const RateLimitPolicy.perWindow(
          maxRequests: 1, window: Duration(seconds: 60)));

      expect(await _post(client, server.port, '/しらない', <String, Object?>{}),
          HttpStatus.notFound);
      expect(await _post(client, server.port, '/しらない', <String, Object?>{}),
          HttpStatus.tooManyRequests);
    });

    test('★★ 断られた本文に★理由が 1 つも入らない（★D130 の柵と同じ形）★★', () async {
      server = await start(const RateLimitPolicy.perWindow(
          maxRequests: 1, window: Duration(seconds: 60)));

      await _post(client, server.port, authPath,
          {'userName': 'みつき', 'password': 'ひみつ'});

      final request = await client
          .postUrl(Uri.parse('https://localhost:${server.port}$authPath'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'userName': 'みつき', 'password': 'ひみつ'}));
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();

      expect(response.statusCode, HttpStatus.tooManyRequests);
      expect(jsonDecode(body), {'ok': false});
      expect(body.contains('ひみつ'), isFalse);
      expect(body.contains('みつき'), isFalse);
    });

    test('★★ 窓が過ぎればまた通る（★永久に閉じない）★★', () async {
      server = await start(const RateLimitPolicy.perWindow(
          maxRequests: 1, window: Duration(seconds: 60)));

      expect(
        await _post(client, server.port, accountsPath,
            {'userName': 'ひとり', 'password': 'ひみつ'}),
        HttpStatus.created,
      );
      expect(
        await _post(client, server.port, accountsPath,
            {'userName': 'ふたり', 'password': 'ひみつ'}),
        HttpStatus.tooManyRequests,
      );

      now = now.add(const Duration(seconds: 61));
      expect(
        await _post(client, server.port, accountsPath,
            {'userName': 'ふたり', 'password': 'ひみつ'}),
        HttpStatus.created,
      );
    });
  });
}
