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
  Future<List<int>> syncOnce(int deckCount) async {
    final out = <int>[];
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

    final context = SecurityContext()
      ..useCertificateChain(_certPath)
      ..usePrivateKey(_keyPath);
    server = await serveApi(
      context: context,
      store: accounts,
      decks: decks,
      accountIterations: 10,
      // ★★ ここが要点 —— ★★本番の既定値をそのまま使う★★
      rateLimit: defaultRateLimit,
      clock: () => now,
    );

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
        rateLimit: const RateLimitPolicy.unlimited(),
        clock: () => now,
      );

      final got = await syncOnce(20);

      expect(got.where((s) => s == 429), isEmpty);
    });
  });

  group('★★ 実測 —— ★★1 台の 1 回の同期★★ ★★', () {
    test('★★ デッキが 4 つなら★1 回も断られない（★★ちょうど上限★★）★★', () async {
      // ★1 ＋ 4 = 5 ＝ 既定の上限そのもの。
      final got = await syncOnce(4);

      expect(got, hasLength(5));
      expect(got.where((s) => s == 429), isEmpty);
    });

    test('★★ デッキが 5 つなら★★断られる★★（★★1 台。★1 回の同期★★）★★', () async {
      // ★★ これが「当たっている」の実物である ★★
      //   ★**1 ＋ 5 = 6 > 5**。→ ★★同期が★★途中で切れる★★。
      final got = await syncOnce(5);

      expect(got.last, 429);
      expect(got.where((s) => s == 429), hasLength(1));
    });
  });

  group('★★ 実測 —— ★★同じ住所の 2 台が★同時に同期する★★（**D107-2**）★★', () {
    test('★★ 2 台 × デッキ 2 つで★★断られる★★（★どちらも上限内なのに）★★', () async {
      // ★**1 台なら 1 ＋ 2 = 3 で通る**（★下の対）。
      // ★★**2 台だと 6 > 5**★★ —— ★**枠は 1 人ぶんではない**（`rate_limit.dart` の代償 1）。
      final first = await syncOnce(2);
      final second = await syncOnce(2);

      expect(first.where((s) => s == 429), isEmpty);
      expect(second.where((s) => s == 429), hasLength(1));
    });

    test('★★ 対: 1 台だけなら★同じ回数でも通る ★★', () async {
      final got = await syncOnce(2);

      expect(got.where((s) => s == 429), isEmpty);
    });
  });

  group('★★ 断られた同期は★窓が過ぎれば通る（★恒久に締め出さない）★★', () {
    test('★★ 61 秒あとに投げ直すと通る ★★', () async {
      final blocked = await syncOnce(5);
      expect(blocked.last, 429);

      now = now.add(const Duration(seconds: 61));
      final again = await syncOnce(5);

      expect(again.where((s) => s == 429), hasLength(1),
          reason: '★★窓が空いても★1 回の同期そのものが上限を超えている★★');
    });
  });
}
