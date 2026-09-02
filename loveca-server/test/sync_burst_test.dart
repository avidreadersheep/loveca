/// ★★ 既定の上限と★1 回の同期が★正面から当たるか（★★測る★★）★★
///
/// ★★ これは「上限の仕組み」の群ではない ★★
/// ★**仕組みは `test/rate_limit_test.dart` が見ている。**
/// ★★**この群が見るのは★★既定の値（**Q-01** の 60 秒 5 回）と、★1 回の同期が投げる回数の関係である★★。**
///
/// ## ★★ なぜ測るか（★運転指示【0】(3)）★★
///
/// ★**相談役が「★『同じ相手 ＝ つないできた住所』が、★★既に返っている利用者の答えと当たっていないか★★を
/// ★確かめること。★当たると断じていない。★★在るかを見る★★」と述べた分である。**
///
/// | # | ★既に返っている答え |
/// |---|---|
/// | ★**1** | ★★**同じデッキを 2 台で編集することはある**★★（**D107-2**） |
/// | ★**2** | ★**1 アカウントが★複数の端末を持つ**（**D123-1** / **D120-3**） |
/// | ★**3** | ★**サーバーは★友人が 1 つ用意する**（**D124-2**） |
///
/// → ★**同じ家の 2 台は、★★外から見れば 1 つの住所である★★**（★`rate_limit.dart` の代償 1 が既に書いている）。
///
/// ## ★★ 1 回の同期が投げる回数（★★実装から数えた★★）★★
///
/// | 何 | ★回数 | ★出どころ |
/// |---|---|---|
/// | ★一覧 | ★**1** | `DeckSyncClient` の `/decks/list` |
/// | ★1 つ取る | ★★**デッキの数だけ**★★ | ★**サーバーは内容ハッシュを持たない**（**D114-1** / **D124-7**）→ ★★**中身を取らないと比べられない**★★ |
/// | ★預ける | ★**送るデッキの数だけ** | ★§32-6 の **23**（★★未着手★★ / ★この群は数えない） |
/// | ★再試行 | ★★**0**★★ | ★**呼ぶ側に再試行が 1 つも無い**（★走査した） |
///
/// → ★★**1 台の 1 回の同期 ＝ 1 ＋ デッキの数**★★（★★23 が入ると さらに増える★★）。
///
/// ## ★★ 直していない。★いまの挙動を固定する ★★
/// ★**値を動かすと★この群が落ちる。★★それが合図である★★**（★先例は **D-24** / **W-24**）。
/// ★★**「値が正しい」とは書かない**★★ —— ★**書けるのは「★置いた」までである**（★運転指示【0】(6) の 2）。
///
/// ---
///
/// # ★★ 2026-09-02: ★★合図が鳴った。★群を書き直した★★（運転指示【0】(3)）★★
///
/// ★★**上の doc は 1 文字も書き換えない**★★（**D-35** —— ★書いた時点では正しい）。
///
/// ★**相談役が「★★『デッキ 5 つで断られる』は★値が間違っていることの証拠であって、
/// ★利用者判断を待つ理由ではない。★★現に断られる状態を残さないこと★★」と判定した。**
/// → ★**既定値を★測った結果に合わせた**（★導き方の正は `src/rate_limit.dart` の doc）——
/// ★**人が押す枠 5 / 60 秒（★据え置き）＋ ★★同期の枠 33 / 60 秒★★**。
///
/// ★★**この群が★★何を見るかは変わっていない★★**★★ ——
/// ★**「★既定の値と、★1 回の同期が投げる回数の関係」である**（★上の doc の 1 行目）。
/// ★**変わったのは★★どちらに転ぶか★★だけである。**
///
/// | ★前（5 / 60 秒・枠 1 つ） | ★★今（5 ＋ 33 / 60 秒・枠 2 つ）★★ |
/// |---|---|
/// | ★デッキ 4 つ ＝ ちょうど上限 | ★★デッキ 32 個まで通る★★ |
/// | ★★デッキ 5 つで★断られる★★ | ★★**デッキ 33 個で★断られる**★★ |
/// | ★★2 台 × デッキ 2 つで★断られる★★ | ★★**2 台 × デッキ 16 個で★断られる**★★ |
///
/// ★★**「もう断られない」とは書かない**★★ —— ★**D を大きくすれば★★必ず破れる★★。**
/// ★**回数で数える形の帰結であって、★★値の問題ではない★★**（★`src/rate_limit.dart` の doc）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:loveca_server/loveca_server.dart';
import 'package:test/test.dart';

const _fixtureDir = 'test/fixtures/tls';
const _certPath = '$_fixtureDir/localhost-TEST-ONLY.cert.pem';
const _keyPath = '$_fixtureDir/localhost-TEST-ONLY.key.pem';

Future<int> _status(
  HttpClient client,
  int port,
  String path,
  Object? body, {
  String method = 'POST',
}) async {
  final request =
      await client.openUrl(method, Uri.parse('https://localhost:$port$path'));
  request.headers.contentType = ContentType.json;
  request.write(jsonEncode(body));
  final response = await request.close();
  await response.drain<void>();
  return response.statusCode;
}

void main() {
  late Directory dir;
  late AccountFileStore accounts;
  late DeckFileStore decks;
  late HttpServer server;
  late HttpClient client;
  late Future<void> Function(RateLimitPolicySet limits) startServer;

  const user = 'みつき';
  const pass = 'ひみつ';

  // ★★ 時刻は★こちらが動かす（★待って測る検査を書かない / **D-28**）★★
  var now = DateTime.utc(2026, 9, 1, 12);

  Map<String, Object?> creds(Map<String, Object?> extra) => {
        'userName': user,
        'password': pass,
        ...extra,
      };

  /// ★1 台の 1 回の同期（★★一覧 1 ＋ 取る [deckCount] 回★★）を投げ、★状態コードを返す。
  /// ★★ 1 回の同期が投げる回数（★★2 ＋ デッキの数★★ / 決定 **D145-4**）★★
  ///
  /// ★**名簿 1 ＋ 一覧 1 ＋ デッキごと 1。★★字面を各所に埋め込まない★★**
  ///   （★口が増えたらここだけ直す / ★先例は §63-7 の「導出形」）。
  ///
  /// ★★ 2026-09-02: ★形を `lib` へ移した（★運転指示【0】(2)）★★
  /// ★**上の 3 行は 1 文字も書き換えない**（**D-35**）—— ★★その時点で誤りではない★★。
  /// ★**移した理由: ★★上限の★下端がこの形から導かれる★★**ので、
  ///   ★★試験の中に閉じていると `lib` から見えない★★（★`minimumSyncRateLimitBudget`）。
  int syncCost(int deckCount) =>
      syncRequestCount(deckCount: deckCount, joining: false);

  /// ★★ 2026-09-02: ★名簿に居ないときは★1 回多い（決定 **D148-1**）★★
  ///
  /// ★**順序が「★問う → ★器を消す → ★記録する」になった**（★§80-4 の手当て）。
  /// ★**定常（★名簿に居る）は [syncCost] のまま。★★居ないときだけ 1 増える★★。**
  /// ★★**上の [syncCost] は 1 文字も書き換えない**★★（**D-35** —— ★★定常では真である★★）。
  int joiningSyncCost(int deckCount) =>
      syncRequestCount(deckCount: deckCount, joining: true);

  Future<List<int>> syncOnce(int deckCount, {bool joining = false}) async {
    final out = <int>[];
    // ★★ 2026-09-02: ★名簿の口が★1 回増えた（決定 **D145-4** ＝ 名-1）★★
    //   ★**1 回の同期 ＝ ★★2 ＋ デッキの数★★**（★名簿 1 ＋ 一覧 1 ＋ デッキごと 1）。
    //   ★★**代償である。★隠さない**★★ —— ★§77-6 の (丙)。
    // ★★ 2026-09-02: ★[joining] のときは★名簿へ 2 回投げる（決定 **D148-1**）★★
    //   ★**段 1 は「問う」（`join: false`）、★段 3 は「記録する」（`join: true`）。**
    out.add(await _status(client, server.port, devicesPath,
        creds({deviceIdKey: 'DEV-1', deviceJoinKey: !joining})));
    if (joining) {
      out.add(await _status(client, server.port, devicesPath,
          creds({deviceIdKey: 'DEV-1', deviceJoinKey: true})));
    }
    out.add(await _status(client, server.port, decksListPath, creds({})));
    for (var i = 0; i < deckCount; i++) {
      out.add(await _status(
          client, server.port, decksFetchPath, creds({'deckId': 'd$i'})));
    }
    return out;
  }

  setUp(() async {
    now = DateTime.utc(2026, 9, 1, 12);
    dir = Directory.systemTemp.createTempSync('loveca_sync_burst_test');
    accounts = AccountFileStore.open(
        '${dir.path}${Platform.pathSeparator}accounts.json');
    decks = DeckFileStore(
        Directory('${dir.path}${Platform.pathSeparator}decks'));
    final devices = DeviceFileStore(
        Directory('${dir.path}${Platform.pathSeparator}devices'));

    // ★★ 上限だけを差し替えて立て直せるようにする（★運転指示【0】(2) の受け）★★
    //   ★**保管は同じものを使い回す**（★★アカウントは立て直しても残る★★）。
    startServer = (RateLimitPolicySet limits) async {
      final context = SecurityContext()
        ..useCertificateChain(_certPath)
        ..usePrivateKey(_keyPath);
      server = await serveApi(
        context: context,
        store: accounts,
        decks: decks,
        devices: devices,
        accountIterations: 10,
        rateLimits: limits,
        clock: () => now,
      );
    };
    // ★★ ここが要点 —— ★★本番の既定値をそのまま使う★★
    await startServer(defaultRateLimits);

    final clientContext = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificates(_certPath);
    client = HttpClient(context: clientContext);

    // ★アカウントを作る（★★これも 1 回として数えられる★★）
    await _status(client, server.port, accountsPath, creds({}));
    // ★窓を跨がせる（★作るのは★同期のずっと前の出来事である）
    now = now.add(const Duration(seconds: 61));
  });

  tearDown(() async {
    client.close(force: true);
    await server.close(force: true);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('★★ 陽性対照 —— ★上限が★デッキの口にも効いていること（**D-10**）★★', () {
    test('★★ 上限を外せば★何回でも通る（★★対★★）★★', () async {
      await server.close(force: true);
      final context = SecurityContext()
        ..useCertificateChain(_certPath)
        ..usePrivateKey(_keyPath);
      server = await serveApi(
        context: context,
        store: accounts,
        decks: decks,
        accountIterations: 10,
        rateLimits: const RateLimitPolicySet.unlimited(),
        clock: () => now,
      );

      final got = await syncOnce(20);

      expect(got.where((s) => s == 429), isEmpty);
    });
  });

  group('★★ 実測 —— ★★1 台の 1 回の同期★★ ★★', () {
    test('★★ 相談役が名指しした場合（★デッキ 5 つ）が★★通るようになった★★ ★★', () async {
      // ★★ これが「現に断られる状態を残さない」の実物である ★★
      //   ★**前は 1 ＋ 5 = 6 > 5 で断られた**（★上の doc の表）。
      final got = await syncOnce(5);

      expect(got, hasLength(7), reason: '★★2 ＋ 5（★名簿の口が 1 増えた / D145-4）★★');
      expect(got.where((s) => s == 429), isEmpty);
    });

    test('★★ 枠より 2 つ少ないデッキなら★1 回も断られない（★★ちょうど上限★★）★★', () async {
      // ★★ 2026-09-02: ★名簿の口が 1 増えた（**D145-4**）★★
      //   ★**2 ＋ (枠 − 2) = 枠 ＝ 同期の枠そのもの。**
      //   ★**上の 2 行（1 ＋ 32 = 33）は★★書き換えない★★**（**D-35** —— ★その口の数では真である）。
      final got = await syncOnce(syncRateLimitBudget - 2);

      expect(got, hasLength(syncRateLimitBudget));
      expect(got.where((s) => s == 429), isEmpty);
    });

    test('★★ デッキが★枠より 1 つ少ない数でも★★断られる★★（★★値で先送りしただけである★★）★★',
        () async {
      // ★★ 「もう断られない」ではない ★★
      //   ★**2 ＋ (枠 − 1) = 枠 ＋ 1 > 枠**。→ ★★D を大きくすれば必ず破れる★★（★形の帰結）。
      final got = await syncOnce(syncRateLimitBudget - 1);

      expect(got.last, 429);
      expect(got.where((s) => s == 429), hasLength(1));
    });

    test('★★ 1 台が同期できるデッキは★★枠 − 2 個まで★★（★名簿の口の代償）★★', () {
      // ★★ 代償を★数で固定する（**D145-4** の (丙)）★★
      //   ★**前は 枠 − 1 だった。★★1 つ減った★★。**
      expect(syncRateLimitBudget - 2, 32, reason: '★★今日の分母（1529）での値★★');
    });

    // ★★ 名簿に居ないとき —— ★★1 回多い（決定 D148-1）★★
    //
    // ★★ 悪いほうで見る ★★
    // ★**上限は「窓に入りきること」なので、★★起きうる最も多い回数で見る★★。**
    // ★**定常（★名簿に居る）は 1 つ上の群が見ている。★★どちらも残す★★。**
    test('★★ 名簿に居ないときは★★1 回多く投げる★★（★問う ＋ 記録する）★★', () async {
      final got = await syncOnce(1, joining: true);

      expect(got, hasLength(joiningSyncCost(1)));
      expect(got.where((s) => s == 429), isEmpty);
    });

    test('★★ 名簿に居ないときに同期できるデッキは★★枠 − 3 個まで★★', () async {
      final got = await syncOnce(syncRateLimitBudget - 3, joining: true);

      expect(got, hasLength(syncRateLimitBudget));
      expect(got.where((s) => s == 429), isEmpty);
    });

    test('★★ 対: ★枠 − 2 個だと★断られる（★★定常なら通る数である★★）★★', () async {
      final got = await syncOnce(syncRateLimitBudget - 2, joining: true);

      expect(got.last, 429);
      expect(got.where((s) => s == 429), hasLength(1));
    });

    test('★★ 代償を★数で固定する（★★1 つ減った★★ / 決定 D148-1）★★', () {
      expect(syncRateLimitBudget - 3, 31, reason: '★★今日の分母（1529）での値★★');
      expect(joiningSyncCost(0) - syncCost(0), 1,
          reason: '★★増えるのは★1 回だけである★★');
    });
  });

  group('★★ 実測 —— ★★同じ住所の 2 台が★同時に同期する★★（**D107-2**）★★', () {
    test('★★ 2 台 × デッキ 2 つは★★通るようになった★★（★前は断られた）★★', () async {
      final first = await syncOnce(2);
      final second = await syncOnce(2);

      expect(first.where((s) => s == 429), isEmpty);
      expect(second.where((s) => s == 429), isEmpty);
    });

    test('★★ 2 台 × デッキ★枠の半分で★★断られる★★（★どちらも 1 台なら通るのに）★★', () async {
      // ★**1 台なら 2 ＋ 12 = 14 ≤ 25 で通る**（★下の対）。
      // ★★**2 台だと 28 > 25**★★ —— ★**枠は 1 人ぶんではない**（`rate_limit.dart` の代償 1）。
      // ★**上の 2 行は★★書き換えない★★**（**D-35** —— ★その分母と口の数では真である）。
      final half = syncRateLimitBudget ~/ 2;
      final first = await syncOnce(half);
      final second = await syncOnce(half);

      expect(first.where((s) => s == 429), isEmpty);
      expect(second.where((s) => s == 429),
          hasLength(2 * syncCost(half) - syncRateLimitBudget),
          reason: '★★超えた分だけ断られる（★★字面を書かない★★）★★');
    });

    test('★★ 対: 1 台だけなら★同じ回数でも通る ★★', () async {
      final got = await syncOnce(syncRateLimitBudget ~/ 2);

      expect(got.where((s) => s == 429), isEmpty);
    });
  });

  group('★★ 枠が 2 つに分かれている（★**N-27** の 論点 (2) の★★既定値★★）★★', () {
    test('★★ 同期を上限まで使っても★名乗る口は★まだ通る ★★', () async {
      // ★★ これが「分けた」ことの実物である ★★
      //   ★**枠が 1 つなら、★同期で使い切ったあと★名乗れない。**
      final got = await syncOnce(syncRateLimitBudget - 2);
      expect(got.where((s) => s == 429), isEmpty);

      final auth = await _status(client, server.port, authPath, creds({}));

      expect(auth, 200, reason: '★★人が押す枠は★同期の枠と別に数える★★');
    });

    test('★★ 対: 人が押す枠は★据え置き（★5 回で打ち止め）★★', () async {
      // ★★ 分けたことで★人が押す枠が緩んでいないことを見る ★★
      final got = <int>[];
      for (var i = 0; i < humanRateLimitBudget + 1; i++) {
        got.add(await _status(client, server.port, authPath, creds({})));
      }

      expect(got.take(humanRateLimitBudget).where((s) => s == 429), isEmpty);
      expect(got.last, 429);
    });

    test('★★ 対: 知らないパスは★人が押す枠に入る ★★', () async {
      // ★★ 同期の枠に入れていないことを見る ★★
      //   ★**入れていれば、★同期を上限まで使ったあと★知らないパスも 429 になる。**
      final got = <int>[];
      for (var i = 0; i < humanRateLimitBudget + 1; i++) {
        got.add(await _status(client, server.port, '/★知らないパス', creds({})));
      }

      expect(got.take(humanRateLimitBudget).every((s) => s == 404), isTrue);
      expect(got.last, 429);
    });
  });

  // ★★ 分母が上がると、★★既に成立していた同期が断られる★★（★運転指示【0】(2)）
  //
  // ★★ 何を測るか ★★
  // ★**分-2（**D146**）は★★測り直すたびに★上にも下にも動く★★。**
  // ★**1949 → 1529 では★上限が★上がった**（★デッキ 24 → 33）。
  // → ★**★★次に重い処理の直後で測れば★下がる★★。★そのとき何が起きるかを測る。**
  //
  // ★★ 時刻は動かさない ★★
  // ★**待って測る検査を書かない**（**D-28**）—— ★上限だけを差し替えて★立て直す。
  group('★★ 分母が上がると★★既に成立していた同期が断られる★★（★運転指示【0】(2)）★★', () {
    /// ★★ 分母を [times] 倍にした機械で測り直したときの★同期の枠 ★★
    /// ★**導き方は 1 文字も変えない** —— ★★60000 ÷ 分母 − 人が押す枠★★。
    int budgetWhenDenominatorTimes(int times) =>
        rateLimitWindowMs ~/ (measuredPasswordHashCostMs * times) -
        humanRateLimitBudget;

    RateLimitPolicySet limitsFor(int syncBudget) => RateLimitPolicySet(
          human: const RateLimitPolicy.perWindow(
            maxRequests: humanRateLimitBudget,
            window: Duration(milliseconds: rateLimitWindowMs),
          ),
          deckSync: RateLimitPolicy.perWindow(
            maxRequests: syncBudget,
            window: const Duration(milliseconds: rateLimitWindowMs),
          ),
        );

    test('★★ 前提: ★今日の分母では★その同期は★通る ★★', () async {
      final got = await syncOnce(syncRateLimitBudget - 3, joining: true);

      expect(got.where((s) => s == 429), isEmpty);
    });

    test('★★ 分母が 2 倍の機械で測り直すと★★★同じ同期が断られる★★ ★★', () async {
      // ★★ これが「範囲が要る」ことの実物である ★★
      final smaller = budgetWhenDenominatorTimes(2);
      expect(smaller, lessThan(syncRateLimitBudget), reason: '★前提: ★枠が小さくなる');
      await server.close(force: true);
      await startServer(limitsFor(smaller));

      final got = await syncOnce(syncRateLimitBudget - 3, joining: true);

      expect(got.where((s) => s == 429), isNotEmpty,
          reason: '★★昨日まで通っていた同期が★今日は断られる★★');
    });

    test('★★ 対: ★分母が半分の機械なら★★★もっと多くのデッキが通る★★（★片道ではない）★★', () async {
      // ★**規則は★下がる向きにも上がる向きにも動く**（**D146** ＝ 分-2）。
      final bigger = rateLimitWindowMs ~/ (measuredPasswordHashCostMs ~/ 2) -
          humanRateLimitBudget;
      expect(bigger, greaterThan(syncRateLimitBudget), reason: '★前提: ★枠が大きくなる');
      await server.close(force: true);
      await startServer(limitsFor(bigger));

      final got = await syncOnce(syncRateLimitBudget - 2, joining: true);

      expect(got.where((s) => s == 429), isEmpty,
          reason: '★★今日の枠では断られる数が★通るようになる★★');
    });

    test('★★ 下端を下回ると★★デッキ 1 個の初回同期すら通らない★★（★禁止になる）★★', () async {
      // ★★ ここが「上限」ではなくなる点である（`rate_limit.dart` の下端の doc）★★
      await server.close(force: true);
      await startServer(limitsFor(minimumSyncRateLimitBudget - 1));

      final got = await syncOnce(1, joining: true);

      expect(got.last, 429);
    });

    test('★★ 対: ★下端ちょうどなら★デッキ 1 個は通る ★★', () async {
      await server.close(force: true);
      await startServer(limitsFor(minimumSyncRateLimitBudget));

      final got = await syncOnce(1, joining: true);

      expect(got.where((s) => s == 429), isEmpty);
    });
  });

  group('★★ 断られた同期は★窓が過ぎれば通る（★恒久に締め出さない）★★', () {
    test('★★ 61 秒あとに投げ直すと通る ★★', () async {
      final over = syncRateLimitBudget - 1;
      final blocked = await syncOnce(over);
      expect(blocked.last, 429);

      now = now.add(const Duration(seconds: 61));
      final again = await syncOnce(over);

      expect(again.where((s) => s == 429),
          hasLength(syncCost(over) - syncRateLimitBudget),
          reason: '★★窓が空いても★1 回の同期そのものが上限を超えている★★');
    });
  });
}
