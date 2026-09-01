/// ★★ 配信物を取りに行く口（§32-6 の **8** の 4 番目 / **D137-6**）★★
///
/// ★★ 本物の待ち受けに当てる（**D-10**）★★
/// ★**`loveca-server` の試験用の証明書を借り、★★TLS 越しに往復する★★**（**D131-7**）。
///
/// ★★ サーバーの実装を 1 度も呼ばない（**D126-3**）★★
/// ★**依存は永久に 0 本である。**→ ★**自前の待ち受けを立てて★振る舞いを真似る。**
/// → ★★**「端から端まで 1 回で通した」とは書かない**★★（★両側とも★自分の側の試験を持つ）。
///
/// ★★ やり取りの形が 2 か所に書かれる ★★
/// ★**D126-3** が★★買った代償である★★。→ ★**前置が両側で同じことを★走査で見張る**
/// （★★引用符ごと見る★★ / **D-37 の裏** —— ★外すと doc の説明にも当たる）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_ui/src/data/http_master_file_source.dart';

const _fixtureDir = '../loveca-server/test/fixtures/tls';
const _certPath = '$_fixtureDir/localhost-TEST-ONLY.cert.pem';
const _keyPath = '$_fixtureDir/localhost-TEST-ONLY.key.pem';

void main() {
  late HttpServer server;
  late HttpClient client;
  late HttpMasterFileSource source;
  late List<String> seenPaths;
  late List<String> seenAuthHeaders;

  /// ★UTF-8 として復号できないバイト列（★★WebP の代わり★★）。
  final webpLike = <int>[0xFF, 0xD8, 0x00, 0x01, 0xFE];

  setUp(() async {
    seenPaths = <String>[];
    seenAuthHeaders = <String>[];

    final context = SecurityContext()
      ..useCertificateChain(_certPath)
      ..usePrivateKey(_keyPath);
    server =
        await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context);
    server.listen((request) async {
      seenPaths.add(request.uri.path);
      final auth = request.headers.value(HttpHeaders.authorizationHeader);
      if (auth != null) seenAuthHeaders.add(auth);

      switch (request.uri.path) {
        case '/dist/version.json':
          request.response
            ..statusCode = HttpStatus.ok
            ..write('{"dataVersion":1}');
        case '/dist/images/thumb/a.webp':
          request.response
            ..statusCode = HttpStatus.ok
            ..add(webpLike);
        case '/dist/500.json':
          request.response.statusCode = HttpStatus.internalServerError;
        default:
          request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });

    final clientContext = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificates(_certPath);
    client = HttpClient(context: clientContext);
    source = HttpMasterFileSource(
      client: client,
      server: Uri.parse('https://localhost:${server.port}'),
    );
  });

  tearDown(() async {
    client.close(force: true);
    await server.close(force: true);
  });

  group('★★ 取れる ★★', () {
    test('★ テキストが読める', () async {
      expect(await source.read('version.json'), '{"dataVersion":1}');
    });

    test('★★ バイト列がそのまま運べる（★UTF-8 にできない中身）★★', () async {
      expect(await source.readBytes('images/thumb/a.webp'), webpLike);
    });

    test('★★ 読んだ path を記録する（★差分更新の確認に要る）★★', () async {
      await source.read('version.json');
      await source.readBytes('images/thumb/a.webp');

      expect(source.readPaths, <String>['version.json', 'images/thumb/a.webp']);
    });
  });

  group('★★ 送るもの ★★', () {
    test('★★ 前置を付けて投げる（★サーバー側と同じ字面）★★', () async {
      await source.read('version.json');

      expect(seenPaths, <String>['/dist/version.json']);
    });

    test('★★ 段が深くてもそのまま繋ぐ ★★', () async {
      await source.readBytes('images/thumb/a.webp');

      expect(seenPaths, <String>['/dist/images/thumb/a.webp']);
    });

    test('★★ 名乗らない（**D133-7** —— ★配信は誰でも受け取れる）★★', () async {
      await source.read('version.json');

      expect(seenAuthHeaders, isEmpty);
    });

    test('★★ 住所のパスは使わない（★★差し替える★★）★★', () async {
      final withPath = HttpMasterFileSource(
        client: client,
        server: Uri.parse('https://localhost:${server.port}/これは使わない'),
      );

      await withPath.read('version.json');

      expect(seenPaths, <String>['/dist/version.json']);
    });
  });

  group('★★ 取れないときは★投げる（★契約に合わせる）★★', () {
    test('★★ 無いファイルは投げる（★★`null` を返さない★★）★★', () async {
      await expectLater(
        source.read('nai.json'),
        throwsA(isA<MasterFetchException>()),
      );
    });

    test('★★ 理由に状態コードが入る（★★畳まない★★）★★', () async {
      try {
        await source.read('500.json');
        fail('★投げるはずである');
      } on MasterFetchException catch (e) {
        expect(e.reason, contains('500'));
        expect(e.path, '500.json');
      }
    });

    test('★★ 404 と 500 の理由は★別である ★★', () async {
      final a = await _reasonOf(source, 'nai.json');
      final b = await _reasonOf(source, '500.json');

      expect(a, isNot(b));
    });

    test('★★ つながらないときも投げる（★状態コードが無い）★★', () async {
      final dead = HttpMasterFileSource(
        client: client,
        // ★★ 誰も待ち受けていない港（★同じ機械）★★
        server: Uri.parse('https://localhost:1'),
      );

      await expectLater(
        dead.read('version.json'),
        throwsA(isA<MasterFetchException>()),
      );
    });

    test('★★ 投げても★読んだ path は記録されている（★★次に何を取るか分かる★★）★★',
        () async {
      try {
        await source.read('nai.json');
      } on MasterFetchException {
        // ★握り潰す（★ここで見たいのは記録である）
      }

      expect(source.readPaths, <String>['nai.json']);
    });
  });

  group('★★ 走査 —— ★前置が両側で同じ字面である（**D126-3** の代償）★★', () {
    test('★★ サーバー側の `lib` に★同じ字面が在る ★★', () async {
      final serverSource =
          File('../loveca-server/lib/src/dist_endpoint.dart').readAsStringSync();

      // ★★ 引用符ごと見る（★外すと doc の説明にも当たる / **D-37 の裏**）★★
      expect(serverSource, contains("'$distPathPrefix'"));
    });

    test('★★ 陽性対照 —— ★違う字面は当たらない ★★', () async {
      final serverSource =
          File('../loveca-server/lib/src/dist_endpoint.dart').readAsStringSync();

      expect(serverSource, isNot(contains("'/dists/'")));
    });
  });
}

Future<String> _reasonOf(HttpMasterFileSource source, String path) async {
  try {
    await source.read(path);
  } on MasterFetchException catch (e) {
    return e.reason;
  }
  return '★投げなかった';
}
