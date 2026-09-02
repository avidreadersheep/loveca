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

import 'support/directive_scan.dart';

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
    test('★★ 既定は★人が押す枠 5 / ★同期の枠 25 である（★値そのものの固定）★★', () {
      // ★★ 導き方の正は `src/rate_limit.dart` の doc ★★
      //   ★**60000 ms ÷ 1573 ms ＝ 38**（★★2026-09-02 実測 / この機械★★）。★**38 − 5 ＝ 33。**
      // ★★ 2026-09-02 追記: ★同じ機械で測り直し、★★規則どおり最大を採った★★ ★★
      //   ★**上の 2 行は 1 文字も書き換えない**（**D-35** —— ★その分母では真である）。
      //   ★**60000 ms ÷ ★★1949 ms★★ ＝ 30。★30 − 5 ＝ ★★25★★。**
      // ★★ 2026-09-02 追記: ★★規則そのものを変えた（★分-2 ＝ 最後の 1 回で置き換える）★★ ★★
      //   ★**上の 4 行は 1 文字も書き換えない**（**D-35** —— ★その規則と分母の下では真である）。
      //   ★**60000 ms ÷ ★★1529 ms★★ ＝ 39。★39 − 5 ＝ ★★34★★。**
      expect(defaultRateLimits.human.maxRequests, 5);
      expect(defaultRateLimits.deckSync.maxRequests, 34);
      expect(defaultRateLimits.human.window, const Duration(seconds: 60));
      expect(defaultRateLimits.deckSync.window, const Duration(seconds: 60));
    });

    test('★★ 合計は★測った上限を超えない（★★導き方そのものを固定する★★）★★', () {
      // ★★ これが「値が導かれている」ことの対である ★★
      //   ★**片方を上げたら★もう片方を下げないと落ちる。**
      const measuredCostMs = 1529;
      const windowMs = 60 * 1000;
      final ceiling = windowMs ~/ measuredCostMs;

      expect(ceiling, 39, reason: '★★2026-09-02 実測 / ★この機械 / ★8 回目★★');
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

  // ★★ 導出 —— ★上限を「測定値から導く形」で置いたこと（★★運転指示【0】(1)★★）★★
  //
  // ★★ ここは★値ではなく★★規則★★を見る ★★
  // ★**値だけを見ると、★★どの数がどこから来たかが分からない★★。**
  // ★**分母（`measuredPasswordHashCostMs`）が動いたとき、★何が動いて何が動かないかを固定する。**
  group('★★ 導出 —— ★上限は★分母から導く（★固定値ではない）★★', () {
    test('★★ 合計の枠は★窓に★入りきる（★切り上げていない）★★', () {
      // ★**上限の定義そのもの** —— ★通す回数 × 1 回の費用 ≤ 窓。
      expect(
        totalRateLimitBudget * measuredPasswordHashCostMs,
        lessThanOrEqualTo(rateLimitWindowMs),
      );
    });

    test('★★ 合計の枠は★これ以上増やせない（★★最大である★★）★★', () {
      // ★**「入りきる」だけなら 1 でも通る。★★最大であることは別に見る★★**（**D-27**）。
      expect(
        (totalRateLimitBudget + 1) * measuredPasswordHashCostMs,
        greaterThan(rateLimitWindowMs),
      );
    });

    test('★★ 2 つの枠は★合計を★超えない。★★余らせもしない★★', () {
      expect(humanRateLimitBudget + syncRateLimitBudget, totalRateLimitBudget);
    });

    test('★ 同期の枠は 1 以上（★★0 以下は「全部断る」になる★★）', () {
      expect(syncRateLimitBudget, greaterThan(0));
    });

    test('★★ 名簿の口は★同期の枠である（★★人が押す枠を食わない★★ / D145-4）★★', () {
      // ★★ D-27: ★これが無いと、★★枠の割り当てを変えても 1 件も落ちない★★（★実測 0 件）★★
      //   ★**1 回の同期が★必ず 1 回呼ぶ**（★§77-6 の (丙) —— ★2 ＋ デッキの数）。
      //   ★**人が押す枠に入れると、★★同期が★人の枠（5）を食い切る★★。**
      expect(rateLimitFrameFor(devicesPath), RateLimitFrame.deckSync);

      // ★対: 知らないパスは★人が押す枠のままである（★走査そのものが効いている）。
      expect(rateLimitFrameFor('/★知らないパス'), RateLimitFrame.human);
    });

    test('★★ 既定値は★導いた値を★そのまま使う（★字面を埋め込んでいない）★★', () {
      // ★**仕込み: ★どちらかに数字を直に書くと落ちる。**
      expect(defaultRateLimit.maxRequests, humanRateLimitBudget);
      expect(defaultSyncRateLimit.maxRequests, syncRateLimitBudget);
      expect(defaultRateLimits.human.maxRequests, humanRateLimitBudget);
      expect(defaultRateLimits.deckSync.maxRequests, syncRateLimitBudget);
    });

    test('★★ 窓は★2 つの枠で同じ（★★合計の勘定が成り立つ前提★★）★★', () {
      // ★**窓が違えば「合計 38」の算術そのものが成り立たない。**
      expect(defaultRateLimit.window.inMilliseconds, rateLimitWindowMs);
      expect(defaultSyncRateLimit.window.inMilliseconds, rateLimitWindowMs);
    });
  });

  // ★★ 今日の分母での値 —— ★★これは「合図」である ★★
  //
  // ★★ 分母を動かしたら★★この群が落ちる。★それが正しい ★★
  // ★**落ちたら★数を合わせるのではなく、★★`tool/measure_hash_cost.dart` の出力と突き合わせること★★。**
  // ★**先例は **D-24** / `docs/同期設計メモ.md` §57**（★いまの挙動を固定し、★動かしたら落ちる形）。
  group('★★ 今日の分母（1529 ms）での値 —— ★★動かしたら落ちる（合図）★★', () {
    test('★ 分母は 1529 ms', () {
      expect(measuredPasswordHashCostMs, 1529);
    });

    test('★ 合計 39 / ★人が押す枠 5 / ★同期の枠 34', () {
      expect(totalRateLimitBudget, 39);
      expect(humanRateLimitBudget, 5);
      expect(syncRateLimitBudget, 34);
    });

    test('★★ 1 台が同期できるデッキは 33 個まで（★★34 は 1529 に依る★★）★★', () {
      // ★**1 回の同期 ＝ 1 ＋ デッキの数**（★§10 の **N-27** の事実 2）。
      // ★★**この数は★分母が動けば動く。★入力ではなく★★帰結である★★。**
      expect(syncRateLimitBudget - 1, 33);
      // ★同じ住所の 2 台（**D107-2**）—— ★2 × (1 ＋ D) ≤ 34。
      expect((syncRateLimitBudget ~/ 2) - 1, 16);
    });
  });

  // ★★ 規則そのもの —— ★★分母は「最後の 1 回の測定の最大」である（★分-2）★★
  //
  // ★★ なぜ群を分けるか ★★
  // ★**上の群は★★値★★を見る。★ここは★★値の出どころ★★を見る。**
  // ★**前の規則（★分-1 ＝ 貯めた全標本の最大）は★★測り直すたびに単調に悪化した★★**
  //   （★運転指示【0】(2)）。→ ★**規則を変えたことを★★機械が見られる形に置く★★。**
  //
  // ★★ 何を守っているか ★★
  // ★**「標本の列を★差し替えずに★足す」形（＝ 分-1）に戻すと★★この群が落ちる★★。**
  group('★★ 分母の規則（★分-2 ＝ ★最後の 1 回の測定の最大）★★', () {
    // ★★ 本番の関数を通す（**D-27** の (甲) —— ★★対を 1 本書いた瞬間に当てる★★）★★
    //   ★**最初は★ここに `maxOf` を★書き写していた。**
    //   ★**すると★★道具が平均を採るように変えても★1 件も落ちなかった★★**（★2026-09-02 実測 / ★0 件）。
    //   → ★**規則を `lib` の [takenHashCostMs] にし、★★道具も試験もそれを呼ぶ★★。**

    test('★★ 分母は★記録された標本の最大である（★★字面ではなく機械で見る★★）★★', () {
      expect(
        measuredPasswordHashCostMs,
        takenHashCostMs(
          measuredPasswordHashSaveMs,
          measuredPasswordHashVerifyMs,
        ),
      );
    });

    test('★★ 採る値は★両側の最大のうち★大きいほうである ★★', () {
      expect(takenHashCostMs(<int>[10, 30], <int>[20, 25]), 30);
      expect(takenHashCostMs(<int>[10, 20], <int>[25, 40]), 40);
    });

    test('★★ 対: ★平均でも中央でもない（★★合成の入力で見る★★）★★', () {
      // ★★ 平均なら 20、★中央なら 20、★★最大は 100★★ ★★
      final xs = <int>[1, 1, 1, 1, 100];
      expect(takenHashCostMs(xs, const <int>[]), 100);
    });

    test('★★ 標本が 1 つも無ければ★投げる（★★測っていない値は採れない★★）★★', () {
      expect(() => takenHashCostMs(const <int>[], const <int>[]),
          throwsA(isA<ArgumentError>()));
    });

    test('★★ 記録されているのは★★1 回ぶんだけ★★である（★貯めていない）★★', () {
      // ★**道具の既定は 12 標本**（`tool/measure_hash_cost.dart`）。
      // ★★**この 2 行が★「集合は 1 回である」ことの対である**★★ ——
      //   ★**貯めれば★件数が 12 を超える。**
      expect(measuredPasswordHashSaveMs, hasLength(12));
      expect(measuredPasswordHashVerifyMs, hasLength(12));
    });

    test('★★ 対: ★前の回の標本を混ぜると★分母と食い違う（★分-1 に戻すと落ちる）★★', () {
      // ★★ これが「単調に悪化しない」ことの対である ★★
      //   ★**6 回目の照合する側の最大は 1949 だった**（`src/rate_limit.dart` の追記の表）。
      //   ★**貯める規則なら★分母は 1949 になる。★★分-2 では 1529 のままである★★。**
      const previousRun = <int>[1560, 1949];
      final pooled = takenHashCostMs(
        <int>[...measuredPasswordHashSaveMs, ...previousRun],
        measuredPasswordHashVerifyMs,
      );
      expect(pooled, 1949, reason: '★★貯めると★上がる（★これが 分-1 である）★★');
      expect(measuredPasswordHashCostMs, isNot(pooled),
          reason: '★★いまの分母は★貯めた集合の最大ではない★★');
    });

    test('★★ 対: ★測り直して★下がった場合も★そのまま採る（★★片道ではない★★）★★', () {
      // ★★ 分-1 では★これが成り立たなかった ★★
      //   ★**前の分母は 1949。★いまは 1529 で、★★下がっている★★。**
      //   ★**分-1（貯めた全標本の最大）なら★1949 のままだった。**
      expect(measuredPasswordHashCostMs, lessThan(1949));
      expect(totalRateLimitBudget, greaterThan(60000 ~/ 1949));
    });
  });

  // ★★ 測った機械 —— ★★分母と★対で持つ（★★運転指示【0】(1)★★）★★
  //
  // ★★ なぜ要るか ★★
  // ★**分母は★測った機械に依る**（★`rate_limit.dart` の doc）。
  // ★**機械が併記されていないと、★★次に測る人が「同じ機械か」を判定できない★★** ——
  //   ★**同じなら★最大を採り、★違うなら★置き換える。★★どちらをするかが決まらない★★。**
  //
  // ★★ この群が落ちるのは「合図」である ★★
  // ★**別の機械で走らせると★下の 2 件目が落ちる。★★それが正しい★★。**
  // ★**直し方は★★`dart run tool/measure_hash_cost.dart` を走らせて★値と機械を一緒に写す★★ことで、
  //   ★★字面を合わせることではない★★**（★先例は **D-24** / §57）。
  group('★★ 測った機械 —— ★分母と★対で持つ ★★', () {
    test('★ 機械の同定は★空でない', () {
      expect(measuredPasswordHashCostMachine, isNotEmpty);
    });

    test('★★ いま走っている機械と★一致する（★★違えば★測り直して置き換える★★）★★', () {
      expect(
        measuredPasswordHashCostMachine,
        currentMachineFingerprint(),
        reason: '★★別の機械である。★★`dart run tool/measure_hash_cost.dart` を走らせ、'
            '★★「採る値」と「測った機械」を★一緒に★★写すこと'
            '（★★またがって最大を採らない ＝ ★置き換える★★）。',
      );
    });

    test('★★ 同定は★OS と★コア数と★Dart の版を含む（★★どれか 1 つでは足りない★★）★★', () {
      final fp = currentMachineFingerprint();
      expect(fp, contains(Platform.operatingSystem));
      expect(fp, contains('${Platform.numberOfProcessors} コア'));
      expect(fp, contains('Dart '));
    });

    test('★★ ホスト名も利用者名も入っていない（★★リポジトリに残る字面である★★）★★', () {
      final fp = currentMachineFingerprint();
      final host = Platform.localHostname;
      if (host.isNotEmpty) {
        expect(fp.toLowerCase(), isNot(contains(host.toLowerCase())));
      }
      for (final key in const ['USERNAME', 'USER', 'LOGNAME']) {
        final v = Platform.environment[key];
        if (v != null && v.isNotEmpty) {
          expect(fp.toLowerCase(), isNot(contains(v.toLowerCase())));
        }
      }
    });

    test('★★ Dart の版は★ビルド日時を含まない（★★`Platform.version` の写しではない★★）★★', () {
      // ★**`Platform.version` は `3.11.1 (stable) (Tue Feb 24 ...) on "..."` の形**（★実測）。
      // ★**そのまま使うと★★同じ SDK でも★字面が長くなるだけで★判定は 1 つも良くならない★★。**
      final fp = currentMachineFingerprint();
      expect(fp, isNot(contains(Platform.version)));
      expect(fp.length, lessThan(Platform.version.length + 80));
      // ★曜日の 3 文字（★ビルド日時に必ず入る）が★1 つも無いこと。
      for (final d in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
        expect(fp, isNot(contains(d)));
      }
    });

    // ★★ 走査 —— ★★値では区別できないので★ソースの字面を見る（**D-27**）★★
    //
    // ★★ 引き金: ★仕込み (G) が★★0 件だった★★ ★★
    // ★**`currentMachineFingerprint()` が★★記録されている字面を直に返す★★実装は、
    //   ★★この機械では★上の 4 件のどれからも区別できない★★**（★実測 0 件）。
    // ★**原因は★★対の形★★である** —— ★**今日は「いま走っている機械」と「記録された機械」が
    //   ★★同じ字面である★★**ので、★★値を比べる限り★区別しようがない★★
    //   （★★本命の空振りでも★仕込みの弱さでもない★★）。
    // ★**先例は §63-7 の (D)** / ★**§32-7 の (B)(D)**（★「型でしか見えないものは、型でしか守れない」）。
    String fingerprintBodyIn(String source) {
      final src = stripDartComments(source);
      final at = src.indexOf('String currentMachineFingerprint()');
      expect(at, isNot(-1), reason: '★宣言そのものが見つからない');
      final end = src.indexOf(';', at);
      expect(end, isNot(-1), reason: '★宣言の終わりが読めない');
      return src.substring(at, end);
    }

    test('★★ 走査: ★同定は★`Platform` を★実際に読む（★★機械に依る★★）★★', () {
      final body = fingerprintBodyIn(
        File('lib/src/machine.dart').readAsStringSync(),
      );
      for (final needed in const [
        'Platform.operatingSystem',
        'Platform.numberOfProcessors',
        '_dartVersion()',
      ]) {
        expect(body, contains(needed),
            reason: '★★$needed を読んでいない ＝ ★機械に依らない字面である★★');
      }
    });

    test('★★ 対: ★字面を直に返す実装は★この走査が捕まえる（★陽性対照）★★', () {
      // ★★ 合成の入力で対を作る —— ★★本番に「悪い実装」が 1 つも無いからである★★
      final bad = "String currentMachineFingerprint() => "
          "'windows / 16 コア / Dart 3.11.1';";
      final body = fingerprintBodyIn(bad);
      expect(body, isNot(contains('Platform.operatingSystem')));
    });

    test('★★ 対: ★doc の中の写しを★コメント外しが落とす（★★D-30★★）★★', () {
      // ★**この repo は★doc に★宣言をそのまま写す**（★**D-30** が「必ず含む」と書いている）。
      // ★**外さないと★★doc の写し（★悪い実装）のほうが先に当たる★★。**
      final lines = <String>[
        "/// ★doc の写し: String currentMachineFingerprint() => 'windows / 16 コア';",
        "String currentMachineFingerprint() => '\${Platform.operatingSystem} / '",
        "    '\${Platform.numberOfProcessors} コア / '",
        "    'Dart \${_dartVersion()}';",
      ];
      final body = fingerprintBodyIn(lines.join(String.fromCharCode(10)));
      expect(body, contains('Platform.operatingSystem'));
    });
  });


  // ★★ 走査 —— ★★字面を埋め込んでいないこと（★★対を測って足した★★）★★
  //
  // ★★ 引き金: ★上の「導いた値をそのまま使う」の対が★★0 件だった★★（**D-27**）★★
  // ★**仕込み（★`maxRequests: 33` と直に書く）を当てても★★1 件も落ちなかった★★。**
  // ★**原因は★★対の形★★である** —— ★**今日の分母では★字面 33 と導いた値が★★等しい★★**ので、
  //   ★**値を比べる限り★★区別しようがない★★**（★★本命の空振りでも★仕込みの弱さでもない★★ ——
  //   ★★分母も一緒に動かす 2 段の仕込みでは★9 件落ちた★★）。
  // ★**先例は §32-7 の (B)(D)**（★「型でしか見えないものは、型でしか守れない」）。
  // → ★★**値では見えないので★★ソースの字面を見る★★。**
  group('★★ 走査 —— ★既定値の宣言に★数字を直に書いていない ★★', () {
    // ★★ 純粋関数にする —— ★★合成の入力で対を作れるようにするため★★ ★★
    // ★**先例は `support/directive_scan.dart` の doc**（★「0 件は『無い』と『見えていない』の
    //   区別がつかない」）。★**ファイルを直に読む形だと★★コメント外しに対が届かない★★**（★実測: 0 件）。
    String argOfIn(String source, String declaration) {
      final src = stripDartComments(source);
      final at = src.indexOf(declaration);
      expect(at, isNot(-1), reason: '★宣言そのものが見つからない');
      final close = src.indexOf(');', at);
      final chunk = src.substring(at, close);
      final m = RegExp(r'maxRequests:\s*([^,]+),').firstMatch(chunk);
      expect(m, isNotNull, reason: '★maxRequests の引数が読めない');
      return m!.group(1)!.trim();
    }

    String argOf(String declaration) => argOfIn(
          File('lib/src/rate_limit.dart').readAsStringSync(),
          declaration,
        );

    test('★★ 同期の枠は★識別子で書かれている（★数字ではない）★★', () {
      final arg = argOf('const RateLimitPolicy defaultSyncRateLimit');
      expect(int.tryParse(arg), isNull,
          reason: '★★数字を直に書くと★分母が動いても付いてこない★★');
      expect(arg, 'syncRateLimitBudget');
    });

    test('★ 人が押す枠も★識別子で書かれている', () {
      final arg = argOf('const RateLimitPolicy defaultRateLimit');
      expect(int.tryParse(arg), isNull);
      expect(arg, 'humanRateLimitBudget');
    });

    test('★★ 対: ★doc の中の宣言を★コメント外しが落とす（★★D-30★★）★★', () {
      // ★★ この repo は★doc の中に★宣言をそのまま写す（★D-30 が「必ず含む」と書いている）★★
      //   ★**外さないと★★doc の写しのほうが先に当たる★★**（★合成の入力で固定した）。
      final lines = <String>[
        '/// ★doc の写し: const RateLimitPolicy defaultSyncRateLimit ='
            ' RateLimitPolicy.perWindow(maxRequests: 33, window: w);',
        'const RateLimitPolicy defaultSyncRateLimit = RateLimitPolicy.perWindow(',
        '  maxRequests: syncRateLimitBudget,',
        '  window: Duration(milliseconds: rateLimitWindowMs),',
        ');',
      ];
      final src = lines.join(String.fromCharCode(10));

      expect(
        argOfIn(src, 'const RateLimitPolicy defaultSyncRateLimit'),
        'syncRateLimitBudget',
      );
    });

    test('★★ 対: ★コメント外しを通さないと★doc の写しに当たる（★陽性対照）★★', () {
      final lines = <String>[
        '/// ★doc の写し: const RateLimitPolicy defaultSyncRateLimit ='
            ' RateLimitPolicy.perWindow(maxRequests: 33, window: w);',
        'const RateLimitPolicy defaultSyncRateLimit = RateLimitPolicy.perWindow(',
        '  maxRequests: syncRateLimitBudget,',
        ');',
      ];
      final raw = lines.join(String.fromCharCode(10));
      final at = raw.indexOf('const RateLimitPolicy defaultSyncRateLimit');
      final chunk = raw.substring(at, raw.indexOf(');', at));
      final m = RegExp(r'maxRequests:\s*([^,]+),').firstMatch(chunk);

      expect(int.tryParse(m!.group(1)!.trim()), 33,
          reason: '★★外さなければ★doc の 33 に当たる ＝ ★守りが働いている証拠★★');
    });

    // ★★ 2026-09-02 追記: ★★導出そのものの宣言も見る（★対を測って足した / **D-27**）★★
    //   ★**引き金**: ★`syncRateLimitBudget` の定義を★★字面 34 に置き換えても★1 件も落ちなかった★★
    //     （★2026-09-02 実測 / ★0 件）。★**上の 2 件は★★引数★★を見ており、★★定義★★を見ていない。**
    //   ★**原因は★★対の形★★である** —— ★今日の分母では★導いた値と字面 34 が★★等しい★★。
    String bodyOfIn(String source, String declaration) {
      final s = stripDartComments(source);
      final at = s.indexOf(declaration);
      expect(at, isNot(-1), reason: '★宣言そのものが見つからない');
      final close = s.indexOf(';', at);
      return s.substring(at + declaration.length, close).replaceAll('=', '').trim();
    }

    String bodyOf(String declaration) => bodyOfIn(
          File('lib/src/rate_limit.dart').readAsStringSync(),
          declaration,
        );

    test('★★ 同期の枠の★定義★は★式である（★数字を直に書いていない）★★', () {
      final body = bodyOf('const int syncRateLimitBudget');
      expect(RegExp(r'[0-9]').hasMatch(body), isFalse,
          reason: '★★字面を書くと★分母が動いても付いてこない★★');
      expect(body, 'totalRateLimitBudget - humanRateLimitBudget');
    });

    test('★★ 合計の枠の★定義★も★式である ★★', () {
      final body = bodyOf('const int totalRateLimitBudget');
      expect(RegExp(r'[0-9]').hasMatch(body), isFalse);
      expect(body, 'rateLimitWindowMs ~/ measuredPasswordHashCostMs');
    });

    test('★★ 対: ★この走査は★数字を実際に見分ける（★陽性対照 / ★合成の入力）★★', () {
      final lines = <String>[
        'const int syncRateLimitBudget = 34;',
      ];
      final body =
          bodyOfIn(lines.join(String.fromCharCode(10)), 'const int syncRateLimitBudget');
      expect(RegExp(r'[0-9]').hasMatch(body), isTrue,
          reason: '★★字面なら★この走査が捕まえる★★');
    });

    test('★★ 対: ★doc の中の宣言を★コメント外しが落とす（★★D-30★★ / ★合成の入力）★★', () {
      // ★★ 引き金: ★★コメント外しを落としても★1 件も落ちなかった★★（★2026-09-02 実測 / ★0 件）★★
      //   ★**原因は★★対の形★★である** —— ★**今日の `rate_limit.dart` には
      //     ★★この 2 つの宣言の写しが★doc に 1 つも無い★★**（★走査した）ので、
      //     ★★コメント外しに★見る相手が無かった★★。
      //   ★**先例は §63-7 の (J) / §76-4 の (T) / §80-6 の (L)**（★★同じ処置が 4 回目である★★）。
      final lines = <String>[
        '/// ★doc の写し: const int syncRateLimitBudget = 34;',
        'const int syncRateLimitBudget = totalRateLimitBudget - humanRateLimitBudget;',
      ];
      final src = lines.join(String.fromCharCode(10));

      // ★★ 外せば★本物の宣言に当たる（★数字が 1 つも無い）★★
      expect(RegExp(r'[0-9]').hasMatch(bodyOfIn(src, 'const int syncRateLimitBudget')),
          isFalse);

      // ★★ 外さなければ★doc の写しに当たる ＝ ★守りが働いている証拠 ★★
      final at = src.indexOf('const int syncRateLimitBudget');
      final raw = src
          .substring(at + 'const int syncRateLimitBudget'.length, src.indexOf(';', at))
          .replaceAll('=', '')
          .trim();
      expect(raw, '34');
    });

    test('★★ 対: ★この走査は★数字を実際に見分ける（★陽性対照）★★', () {
      // ★★ 走査そのものが空振りしていないことを★合成で見る（**D-10**）★★
      // ★★ D-38 を踏んだ: ★道具の経路で★逆斜線が畳まれ、★改行の印が★本物の改行に化けた ★★
      //   → ★**このファイルには★★逆斜線の並びを 1 つも書かない★★形にした**（★1 行に畳んだ）。
      final chunk = 'const RateLimitPolicy x = RateLimitPolicy.perWindow(maxRequests: 33, window: Duration(milliseconds: 60000));';
      final m = RegExp(r'maxRequests:\s*([^,]+),').firstMatch(chunk);
      expect(int.tryParse(m!.group(1)!.trim()), 33);
    });
  });

}
