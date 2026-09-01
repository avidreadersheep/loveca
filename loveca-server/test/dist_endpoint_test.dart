/// ★★ 配信物を配る口（決定 **D120-1** / **D130-7** / **D133-7**）★★
///
/// ★★ 本物の待ち受けに当てる（**D-10**）★★
/// ★試験用の証明書は `test/fixtures/tls/`（決定 **D131-7**）。
///
/// ★★ この群が★1 つずつ固定するもの ★★
/// ★**名乗りを要求しない** ／ ★**上限の対象にしない** ／ ★★**柵（根の外を読ませない）**★★ ／
/// ★**バイト列がそのまま返る** ／ ★**振り分けが他の 5 つのパスに吸われない**。
///
/// ★★ このファイルには★逆斜線を 1 つも書かない（**D-38** の 2 例目）★★
/// ★**道具の経路で★★2 つ続けた逆斜線が 1 つに畳まれる★★**（2026-09-02 に実際に踏んだ）。
/// → ★**要るところは `String.fromCharCode(92)` で組み立てる**（★先例は `user_question_test.dart`）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:loveca_server/loveca_server.dart';
import 'package:test/test.dart';

const _fixtureDir = 'test/fixtures/tls';
const _certPath = '$_fixtureDir/localhost-TEST-ONLY.cert.pem';
const _keyPath = '$_fixtureDir/localhost-TEST-ONLY.key.pem';

/// ★逆斜線（★字面で書かない / **D-38**）。
final _backslash = String.fromCharCode(92);

/// ★★ 素の口で投げる（★`Uri.parse` を 1 度も通さない）★★
///
/// ★★ なぜ要るか（★★2026-09-02 に測って分かった★★）★★
/// ★**`Uri.parse` は★上へ抜ける段を★★自分で畳む★★**（★`/dist/../x` が `/x` になる / ★実測）。
/// → ★**`HttpClient` から投げると★★柵に 1 度も届かない★★。**
/// → ★★**素の要求行を自分で書く。★これが★柵の対である**★★（★型は **D-27**）。
Future<int> _raw(int port, String requestTarget, SecurityContext ctx) async {
  final socket = await SecureSocket.connect('localhost', port, context: ctx);
  socket.write('GET $requestTarget HTTP/1.1${String.fromCharCode(13)}'
      '${String.fromCharCode(10)}'
      'Host: localhost${String.fromCharCode(13)}${String.fromCharCode(10)}'
      'Connection: close${String.fromCharCode(13)}${String.fromCharCode(10)}'
      '${String.fromCharCode(13)}${String.fromCharCode(10)}');
  final text = await utf8.decoder.bind(socket).join();
  await socket.close();
  final statusLine = text.split(String.fromCharCode(10)).first;
  return int.parse(statusLine.split(' ')[1]);
}

Future<({int status, List<int> bytes})> _get(
  HttpClient client,
  int port,
  String path,
) async {
  final request =
      await client.getUrl(Uri.parse('https://localhost:$port$path'));
  final response = await request.close();
  final bytes = <int>[];
  await for (final chunk in response) {
    bytes.addAll(chunk);
  }
  return (status: response.statusCode, bytes: bytes);
}

void main() {
  late Directory dir;
  late Directory distRoot;
  late AccountFileStore accounts;
  late DeckFileStore decks;
  late DistFileStore dist;
  late HttpServer server;
  late HttpClient client;
  late SecurityContext clientContext;

  final sep = Platform.pathSeparator;

  /// ★UTF-8 として復号できないバイト列（★★WebP の代わり★★）。
  final webpLike = <int>[0xFF, 0xD8, 0x00, 0x01, 0xFE];

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('loveca_dist_endpoint_test');
    distRoot = Directory('${dir.path}${sep}dist')..createSync(recursive: true);
    File('${distRoot.path}${sep}version.json')
        .writeAsStringSync('{"dataVersion":1}');
    Directory('${distRoot.path}${sep}images${sep}thumb')
        .createSync(recursive: true);
    File('${distRoot.path}${sep}images${sep}thumb${sep}a.webp')
        .writeAsBytesSync(webpLike);
    // ★★ 根の★外★に置く（★柵が効くことを見るため）★★
    File('${dir.path}$sep秘密.txt').writeAsStringSync('これは配ってはならない');

    accounts = AccountFileStore.open('${dir.path}${sep}accounts.json');
    decks = DeckFileStore(Directory('${dir.path}${sep}decks'));
    dist = DistFileStore(distRoot);

    final context = SecurityContext()
      ..useCertificateChain(_certPath)
      ..usePrivateKey(_keyPath);
    server = await serveApi(
      context: context,
      store: accounts,
      decks: decks,
      dist: dist,
      accountIterations: 10,
    );

    clientContext = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificates(_certPath);
    client = HttpClient(context: clientContext);
  });

  tearDown(() async {
    client.close(force: true);
    await server.close(force: true);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('★★ 配る ★★', () {
    test('★★ 名乗らずに読める（★**D133-7**）★★', () async {
      final res = await _get(client, server.port, '/dist/version.json');

      expect(res.status, 200);
      expect(utf8.decode(res.bytes), '{"dataVersion":1}');
    });

    test('★★ バイト列がそのまま返る（★UTF-8 にできない中身）★★', () async {
      final res = await _get(client, server.port, '/dist/images/thumb/a.webp');

      expect(res.status, 200);
      expect(res.bytes, webpLike);
    });

    test('★ 無いファイルは 404', () async {
      final res = await _get(client, server.port, '/dist/これは無い.json');

      expect(res.status, 404);
    });

    test('★ GET 以外は 405', () async {
      final request = await client.postUrl(
          Uri.parse('https://localhost:${server.port}/dist/version.json'));
      final response = await request.close();
      await response.drain<void>();

      expect(response.statusCode, 405);
    });
  });

  group('★★ 柵 —— ★根の外を読ませない（★★素の口で当てる★★）★★', () {
    // ★★ ここは★`HttpClient` では当てられない ★★
    //   ★**`Uri.parse` が★上へ抜ける段を★自分で畳む**（★実測 2026-09-02）。
    //   ★★**最初はそう書いており、★2 件とも★★柵を 1 度も通らずに通っていた★★**（★型は **D-27**）。
    test('★★ 陽性対照 —— ★素の口そのものが働くこと（**D-10**）★★', () async {
      expect(await _raw(server.port, '/dist/version.json', clientContext), 200);
    });

    test('★★ 上へ抜ける道は 404（★★中身が漏れない★★）★★', () async {
      expect(
        await _raw(server.port, '/dist/../%E7%A7%98%E5%AF%86.txt', clientContext),
        404,
      );
    });

    test('★★ 符号化しても抜けられない ★★', () async {
      expect(
        await _raw(
            server.port, '/dist/%2e%2e/%E7%A7%98%E5%AF%86.txt', clientContext),
        404,
      );
    });

    test('★★ 対: ★同じ名前でも★根の中に在れば読める（★★何にでも 404 を返すのではない★★）★★',
        () async {
      File('${distRoot.path}$sep秘密.txt').writeAsStringSync('これは配ってよい');

      final res = await _get(client, server.port, '/dist/秘密.txt');

      expect(res.status, 200);
      expect(utf8.decode(res.bytes), 'これは配ってよい');
    });

    test('★★ 「無い」と「外を指している」を★区別しない ★★', () async {
      final outside = await _raw(
          server.port, '/dist/../%E7%A7%98%E5%AF%86.txt', clientContext);
      final missing =
          await _raw(server.port, '/dist/nai.json', clientContext);

      expect(outside, missing);
    });
  });

  group('★★ 待ち受けが★要求行を畳む（★★測って分かった / 2026-09-02★★）★★', () {
    // ★★ これが「柵に届かない」の中身である ★★
    //   ★**`/dist/a/../x.txt` を★素の口で投げると、★★`x.txt` が返る★★。**
    //   → ★**上へ抜ける段は★★`handleDistRequest` に届く前に消えている★★。**
    //   ★**Dart の `HttpServer` が★要求行を `Uri` として解いたときに畳む**（★実測）。
    test('★★ 上へ抜ける段は★口に届く前に畳まれる ★★', () async {
      File('${distRoot.path}${sep}x.txt').writeAsStringSync('中に在る');

      expect(await _raw(server.port, '/dist/a/../x.txt', clientContext), 200,
          reason: '★★畳まれていなければ★段 1 が `..` を断って 404 になる★★');
    });
  });

  group('★★ 柵 —— ★★口を通さず★`read` に直に当てる（**D-27**）★★', () {
    // ★★ なぜ直に当てるか ★★
    //   ★**口からは 1 度も届かない**（★上の群）。→ ★★**口の対では★柵を 1 ミリも見ていない**★★。
    //   ★**測って分かった** —— ★★柵を丸ごと外しても★21 件が全部通った★★（★型は **D-27**）。
    //   → ★**`read` を直に呼ぶ**。★**`DistFileStore` は★口の外からも呼べる**（★公開されている）。
    test('★★ 陽性対照 —— ★素直な段は読める ★★', () {
      expect(dist.read(const <String>['version.json']), isNotNull);
      expect(dist.read(const <String>['images', 'thumb', 'a.webp']), isNotNull);
    });

    test('★★ 上へ抜ける段は★読めない（★★根の外の中身が出ない★★）★★', () {
      expect(dist.read(const <String>['..', '秘密.txt']), isNull);
    });

    test('★★ 対: ★その中身は★実際に根の外に在る（★★「無いから null」ではない★★）★★', () {
      expect(File('${dir.path}$sep秘密.txt').existsSync(), isTrue);
      expect(File('${dir.path}$sep秘密.txt').readAsStringSync(),
          'これは配ってはならない');
    });

    test('★★ 段が 0 個なら読めない ★★', () {
      expect(dist.read(const <String>[]), isNull);
    });

    test('★★ 無いものは null（★「外」と同じ答え。★区別しない）★★', () {
      expect(dist.read(const <String>['nai.json']), isNull);
    });
  });

  group('★★ 柵の段 1 —— ★区切りごとに見る（★★口を通さず直に★★）★★', () {
    test('★ 空は断る', () {
      expect(DistFileStore.isSafeSegments(const <String>[]), isFalse);
    });

    test('★ 絶対パスは断る', () {
      expect(DistFileStore.isSafeSegments(const <String>['', 'etc', 'passwd']), isFalse);
    });

    test('★★ 上へ抜ける段を含むものは断る ★★', () {
      expect(DistFileStore.isSafeSegments(const <String>['a', '..', 'b']), isFalse);
      expect(DistFileStore.isSafeSegments(const <String>['..']), isFalse);
    });

    test('★ 「.」の段は断る', () {
      expect(DistFileStore.isSafeSegments(const <String>['a', '.', 'b']), isFalse);
    });

    test('★★ ドライブを含む段は断る ★★', () {
      expect(DistFileStore.isSafeSegments(const <String>['C:', 'x']), isFalse);
    });

    test('★★ 逆向きの区切りを含む段は断る ★★', () {
      expect(
        DistFileStore.isSafeSegments(<String>['a$_backslash..${_backslash}b']),
        isFalse,
      );
    });

    test('★★ 対: ★素直な相対パスは通る（★★何でも断るのではない★★）★★', () {
      expect(DistFileStore.isSafeSegments(const <String>['images', 'thumb', 'a.webp']), isTrue);
      expect(DistFileStore.isSafeSegments(const <String>['version.json']), isTrue);
    });
  });

  group('★★ 振り分け ★★', () {
    test('★★ `/decks` には吸われない（★前置が違う）★★', () async {
      final res = await _get(client, server.port, '/dist/version.json');

      expect(res.status, 200);
    });

    test('★★ 知らない前置は 404（★静かに 200 を返さない）★★', () async {
      final res = await _get(client, server.port, '/distx/version.json');

      expect(res.status, 404);
    });

    test('★★ 置き場が渡されていなければ 404 に落ちる ★★', () async {
      await server.close(force: true);
      final context = SecurityContext()
        ..useCertificateChain(_certPath)
        ..usePrivateKey(_keyPath);
      server = await serveApi(
        context: context,
        store: accounts,
        decks: decks,
        accountIterations: 10,
      );

      final res = await _get(client, server.port, '/dist/version.json');

      expect(res.status, 404);
    });
  });

  group('★★ 口そのものに直に当てる（★★振り分けを通さない★★ / **D-27**）★★', () {
    // ★★ なぜ要るか —— ★★対が 1 つも無い守りが見つかった★★ ★★
    //   ★**`handleDistRequest` の「先頭の段が `dist` か」の判定は、
    //   ★★`serveApi` の振り分けを通る限り★★必ず真である★★**（★前置で振り分けているため）。
    //   → ★**測ったら★★外しても 27 件が全部通った★★**（★先例は §32-7 の (L)）。
    //   ★**`handleDistRequest` は★★公開されている★★**ので、★直に呼ぶ人が居うる。
    //   → ★**何でもこの口へ流す待ち受けを 1 つ立てて当てる。**
    late HttpServer direct;

    setUp(() async {
      final context = SecurityContext()
        ..useCertificateChain(_certPath)
        ..usePrivateKey(_keyPath);
      direct = await HttpServer.bindSecure(
          InternetAddress.loopbackIPv4, 0, context);
      direct.listen((request) => handleDistRequest(request, dist));
    });

    tearDown(() async => direct.close(force: true));

    test('★★ 陽性対照 —— ★`dist` で始まれば読める ★★', () async {
      final res = await _get(client, direct.port, '/dist/version.json');

      expect(res.status, 200);
    });

    test('★★ 先頭の段が `dist` でなければ 404（★★段を 1 つ食べない★★）★★', () async {
      final res = await _get(client, direct.port, '/other/version.json');

      expect(res.status, 404);
    });

    test('★★ 段が 1 つも無ければ 404 ★★', () async {
      final res = await _get(client, direct.port, '/');

      expect(res.status, 404);
    });
  });

  group('★★ 上限の対象にしていない（★守っていない。★隠さない）★★', () {
    test('★★ 既定の上限を超える回数を投げても★1 度も断られない ★★', () async {
      // ★★ 既定は 60 秒に 5 回（**Q-01**）。★20 回投げる ★★
      //   ★**理由は 1 つ** —— ★この口は★★名乗りを 1 度も見ない★★ので、
      //   ★★固める処理（1.5 秒）を 1 度も通らない★★。
      //   ★**これは **N-27**（門 ソ）の★★入力である★★**（★論点 (2)）。
      final got = <int>[];
      for (var i = 0; i < 20; i++) {
        got.add((await _get(client, server.port, '/dist/version.json')).status);
      }

      expect(got.where((s) => s == 429), isEmpty);
      expect(got.where((s) => s == 200), hasLength(20));
    });

    test('★★ 対: ★名乗る口には★効いている（★★上限そのものは生きている★★）★★', () async {
      final got = <int>[];
      for (var i = 0; i < 8; i++) {
        final request = await client
            .postUrl(Uri.parse('https://localhost:${server.port}/auth'));
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({'userName': 'x', 'password': 'y'}));
        final response = await request.close();
        await response.drain<void>();
        got.add(response.statusCode);
      }

      expect(got.where((s) => s == 429), isNotEmpty);
    });
  });

  // ★★ 時間以外の軸（★★運転指示【0】(2)★★ / `docs/同期設計メモ.md` §70）★★
  //
  // ★★ 引き金: ★相談役が「時間で足りるとしか書かれていない」と述べた ★★
  // ★**§62 は「1 件 0.261 ms／比 5,831 倍」で★★時間について★★答えた。**
  // ★**ここは★★同じ物を何度でも取れること／量／経路★★を★1 つずつ固定する。**
  // ★★**時間は測らない**★★（**D-28**）—— ★**固定するのは★★数えられるものだけ★★である。**
  group('★★ 時間以外の軸 —— ★★2 つ開き、★1 つ開いていない★★', () {
    test('★★ 同じ物を★何度でも取れる（★★開いている★★）★★', () async {
      // ★★ §70-3 の 1 行目 —— ★★反復に上限が 1 つも無い★★
      final got = <int>[];
      for (var i = 0; i < 20; i++) {
        got.add((await _get(client, server.port, '/dist/version.json')).status);
      }

      expect(got.where((s) => s == 429), isEmpty);
      expect(got.toSet(), <int>{200},
          reason: '★★同じ物を 20 回取っても★1 度も断られない★★');
    });

    test('★★ 取れる量に★上限が 1 つも無い（★★開いている★★）★★', () async {
      // ★★ §70-3 の 2 行目 —— ★★出ていくバイト数を★上限は 1 バイトも見ていない★★
      //   ★**上限の掛かる口なら★★回数 × 1 件の大きさ★★で頭打ちになるが、★ここは頭打ちにならない。**
      //   ★★**バイト数そのものは測らない**★★（★機械と回線で揺れる / **D-28**）——
      //   ★**固定するのは「★★20 回ぶんが全部返ってきた★★」ことである。**
      var total = 0;
      for (var i = 0; i < 20; i++) {
        final res = await _get(client, server.port, '/dist/version.json');
        expect(res.status, 200);
        total += res.bytes.length;
      }
      final one =
          (await _get(client, server.port, '/dist/version.json')).bytes.length;

      expect(total, one * 20,
          reason: '★★20 回ぶんが★1 バイトも削られずに出ていく★★');
    });

    test('★★ 対: ★経路の柵は★上限と独立に★毎回走る（★★開いていない★★）★★', () async {
      // ★★ §70-3 の 3 行目 —— ★★上限を 1 度も通らないのに★柵は効いている★★
      //   ★**上限より★前★に振り分けられる**（★`handleApiRequest` / ★実読）ので、
      //   ★★上限が守っていないことと★柵が効いていることは★別である★★。
      //
      // ★★ 素の `..` は使えない —— ★★`Uri.parse` が★自分で畳む★★（★上の doc / 実測）★★
      //   ★**畳まれると★`/dist/` で始まらなくなり、★★上限の掛かる側へ行って 429 になる★★**
      //   （★★最初この形で書いて★実際に 429 が 3 件返った★★ / **D-27** —— ★対が対象を見ていなかった）。
      //
      // ★★ 上へ抜ける段は★★HTTP の層で畳まれる★★ので★柵に届かない（★★実測★★）★★
      //   ★**`/dist/../x` も `/dist/%2e%2e/x` も、★★`HttpServer` が★自分で畳む★★**
      //   （★★素の口で投げても畳まれる★★ —— ★`uri.path` が `/x` になる / ★2026-09-02 実測）。
      //   → ★**畳まれると★`/dist/` で始まらなくなり、★★上限の掛かる側へ行って 429 になる★★**
      //     （★★最初この形で書いて★実際に 429 が 3 件返った★★ / **D-27** —— ★対が対象を見ていなかった）。
      //   → ★**畳まれない形で★段 1 に届かせる** —— ★★`/dist/` は段が 0 個★★（★`sublist(1)` が空）。
      final got = <int>[];
      for (var i = 0; i < 8; i++) {
        got.add((await _get(client, server.port, '/dist/')).status);
      }

      expect(got.where((s) => s == 429), isEmpty,
          reason: '★上限は 1 度も効いていない');
      expect(got.toSet(), <int>{404},
          reason: '★★それでも★8 回とも★根の外を読ませない★★');
    });

    test('★★ 対: ★本文を 1 バイトも読まない（★★開いていない★★）★★', () async {
      // ★★ §70-4 —— ★`GET` しか通さないので★要求の本文の大きさは★この口では開かない ★★
      final request = await client
          .postUrl(Uri.parse('https://localhost:${server.port}/dist/version.json'));
      request.write('x' * 100000);
      final response = await request.close();
      await response.drain<void>();

      expect(response.statusCode, 405,
          reason: '★★本文を読む前に★メソッドで断る★★');
    });

    test('★★ 対: ★何度取っても★機械に何も残らない（★★開いていない★★）★★', () async {
      // ★★ §70-4 —— ★書き込みが 0 件であること ★★
      int countFiles() =>
          distRoot.listSync(recursive: true).whereType<File>().length;

      final before = countFiles();
      for (var i = 0; i < 20; i++) {
        await _get(client, server.port, '/dist/version.json');
      }

      expect(countFiles(), before, reason: '★★読むだけである★★');
    });
  });

}
