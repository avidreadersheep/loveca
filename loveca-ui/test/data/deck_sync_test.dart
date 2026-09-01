/// ★★ 送信の配線 —— ★判定 → 解決 → 送る ＋ 器への記録点（★§32-6 の **23** / 決定 **D143**）★★
///
/// ★★ この群が固定するもの ★★
/// ★**手元の `Deck` を★★1 バイトも書き換えないこと★★**（★受信は §32-6 の 24 / ★未着手）。
/// ★**送れなかったら★★器を 1 バイトも触らないこと★★**。
/// ★**門 カ（初回同期）が★★衝突と同じ層を通ること★★**（★初-1）。
/// ★**論理削除が★★内容ハッシュに現れなくても送られること★★**（**D111-4** / **D116-12**）。
///
/// ★★ 待ち受けは★本物を立てる（**D-10**）★★
/// ★**`loveca_server` を 1 度も呼ばない**（**D126-3**）—— ★★振る舞いを真似た待ち受けを自分で立てる★★。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/data/deck_sync.dart';
import 'package:loveca_ui/src/data/deck_sync_client.dart';

const _fixtureDir = '../loveca-server/test/fixtures/tls';
const _certPath = '$_fixtureDir/localhost-TEST-ONLY.cert.pem';
const _keyPath = '$_fixtureDir/localhost-TEST-ONLY.key.pem';

/// ★器のフェイク（★★DB を開かない★★ / `MasterFileSource` と同じ形）。
class FakeMarks implements DeckSyncMarks {
  FakeMarks({this.baseline, this.mark = 0});

  DeckSyncBaseline? baseline;
  int mark;

  /// ★書かれた記録（★★1 件も無いことを見る対が在る★★）。
  final List<({String deckId, int logMark, String baselineHash})> recorded = [];

  @override
  Future<DeckSyncBaseline?> baselineFor(String deckId) async => baseline;

  @override
  Future<int> latestLogMark(String deckId) async => mark;

  @override
  Future<void> record({
    required String deckId,
    required int logMark,
    required String baselineHash,
  }) async {
    recorded.add((deckId: deckId, logMark: logMark, baselineHash: baselineHash));
  }
}

Deck _deck({
  String name = 'かのん',
  DateTime? updatedAt,
  DateTime? deletedAt,
  int count = 4,
}) =>
    Deck(
      deckId: 'D-1',
      name: name,
      entries: [DeckEntry(printingId: 'PL!-bp1-001-P', count: count)],
      memo: '',
      tags: const [],
      coverPrintingId: null,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: updatedAt ?? DateTime.utc(2026, 2, 1),
      deletedAt: deletedAt,
      revision: 1,
      lastDeviceId: '',
      masterDataVersion: 0,
    );

void main() {
  late HttpClient client;
  late HttpServer server;
  late List<Map<String, Object?>> received;
  late Uri base;
  late Future<void> Function(HttpRequest request) handler;

  Future<void> reply(
      HttpRequest request, int status, Map<String, Object?> body) async {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  }

  setUp(() async {
    received = [];
    final context = SecurityContext()
      ..useCertificateChain(_certPath)
      ..usePrivateKey(_keyPath);
    server =
        await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context);
    server.listen((request) async {
      received.add({
        'path': request.uri.path,
        'body': jsonDecode(await utf8.decoder.bind(request).join()),
      });
      await handler(request);
    });
    client = HttpClient(context: SecurityContext(withTrustedRoots: false))
      ..badCertificateCallback = (_, _, _) => true;
    base = Uri.parse('https://localhost:${server.port}');
  });

  tearDown(() async {
    client.close(force: true);
    await server.close(force: true);
  });

  Future<DeckSyncOutcome> run(Deck local, FakeMarks marks) => syncOneDeck(
        client: client,
        server: base,
        userName: 'みつき',
        password: 'ひみつ',
        local: local,
        marks: marks,
      );

  Map<String, Object?> lastPushBody() =>
      received.lastWhere((r) => r['path'] == decksPutPath)['body']
          as Map<String, Object?>;

  /// ★相手が [remote] を持っている待ち受け（★預ければ通す）。
  void serveHolding(Deck remote, {String mark = 'M-REMOTE'}) {
    handler = (request) async {
      if (request.uri.path == decksFetchPath) {
        await reply(request, 200, {
          'ok': true,
          'content': encodeDeckForSync(remote),
          syncMarkKey: mark,
        });
        return;
      }
      await reply(request, 200, {'ok': true, syncMarkKey: 'M-NEW'});
    };
  }

  /// ★相手が持っていない待ち受け。
  void serveEmpty() {
    handler = (request) async {
      if (request.uri.path == decksFetchPath) {
        await reply(request, 404, {'ok': false});
        return;
      }
      await reply(request, 201, {'ok': true, syncMarkKey: 'M-NEW'});
    };
  }

  group('★★ 相手が持っていない —— ★踏み潰す相手が 1 つも無い ★★', () {
    test('★★ 「まだ預けていないはず」と名乗って送る ★★', () async {
      serveEmpty();
      final marks = FakeMarks(mark: 7);

      final out = await run(_deck(), marks);

      expect(out, isA<DeckSyncSent>());
      expect((out as DeckSyncSent).created, isTrue);
      expect(lastPushBody()[syncExpectMarkKey], isNull);
    });

    test('★★ 送れたら★器に記録する（★★目印は先に取った値★★）★★', () async {
      serveEmpty();
      final marks = FakeMarks(mark: 7);
      final local = _deck();

      await run(local, marks);

      expect(marks.recorded, hasLength(1));
      expect(marks.recorded.single.deckId, 'D-1');
      expect(marks.recorded.single.logMark, 7);
      expect(marks.recorded.single.baselineHash, deckContentHash(local));
    });
  });
  group('★★ 門 カ（初回同期）—— ★★衝突と同じ層を通す（★初-1）★★', () {
    test('★★ 器の行が無く、★手元が新しければ★送る ★★', () async {
      final remote = _deck(name: 'あいて', updatedAt: DateTime.utc(2026, 1, 15));
      serveHolding(remote);
      final marks = FakeMarks(baseline: null);
      final local = _deck(name: 'てもと', updatedAt: DateTime.utc(2026, 2, 1));

      final out = await run(local, marks);

      expect(out, isA<DeckSyncSent>());
      expect(lastPushBody()[syncExpectMarkKey], 'M-REMOTE',
          reason: '★★取ったときの印を★そのまま名乗る★★');
    });

    test('★★ 器の行が無く、★相手が新しければ★★送らない★★ ★★', () async {
      final remote = _deck(name: 'あいて', updatedAt: DateTime.utc(2026, 3, 1));
      serveHolding(remote);
      final marks = FakeMarks(baseline: null);

      final out = await run(_deck(name: 'てもと'), marks);

      expect(out, isA<DeckSyncRemoteWins>());
      expect((out as DeckSyncRemoteWins).remote.name, 'あいて');
      expect(out.mark, 'M-REMOTE');
      expect(received.where((r) => r['path'] == decksPutPath), isEmpty);
    });

    test('★★ 相手が勝ったら★器を 1 バイトも触らない（★書くのは 24 である）★★', () async {
      serveHolding(_deck(name: 'あいて', updatedAt: DateTime.utc(2026, 3, 1)));
      final marks = FakeMarks(baseline: null);

      await run(_deck(name: 'てもと'), marks);

      expect(marks.recorded, isEmpty);
    });

    test('★★ 初-2 / 初-3 ではない —— ★★向きは★時刻で決まる★★ ★★', () async {
      // ★★ 「常に相手」でも「常に自分」でもないことを★2 つ並べて見る ★★
      serveHolding(_deck(name: 'あいて', updatedAt: DateTime.utc(2026, 1, 1)));
      final first =
          await run(_deck(name: 'てもと', updatedAt: DateTime.utc(2026, 2, 1)),
              FakeMarks(baseline: null));

      serveHolding(_deck(name: 'あいて', updatedAt: DateTime.utc(2026, 3, 1)));
      final second =
          await run(_deck(name: 'てもと', updatedAt: DateTime.utc(2026, 2, 1)),
              FakeMarks(baseline: null));

      expect(first, isA<DeckSyncSent>());
      expect(second, isA<DeckSyncRemoteWins>());
    });
  });

  group('★★ 判定の 4 つの答えに 1 つずつ当てる ★★', () {
    DeckSyncBaseline baselineOf(Deck deck, {bool hasOps = false}) =>
        (hasOpsSinceMark: hasOps, contentHash: deckContentHash(deck));

    test('★ どちらも動いていなければ★送らない（unchanged）', () async {
      final same = _deck();
      serveHolding(same);
      final marks = FakeMarks(baseline: baselineOf(same));

      final out = await run(same, marks);

      expect(out, isA<DeckSyncSkipped>());
      expect((out as DeckSyncSkipped).advancedMark, isFalse);
      expect(received.where((r) => r['path'] == decksPutPath), isEmpty);
      expect(marks.recorded, isEmpty);
    });

    test('★ 自分側だけ動いていれば★送る（localOnly）', () async {
      final base = _deck(count: 4);
      serveHolding(base);
      final marks = FakeMarks(baseline: baselineOf(base, hasOps: true));

      final out = await run(_deck(count: 3), marks);

      expect(out, isA<DeckSyncSent>());
      expect((out as DeckSyncSent).created, isFalse);
      expect(lastPushBody()[syncExpectMarkKey], 'M-REMOTE');
    });

    test('★★ 相手側だけ動いていれば★送らない（remoteOnly）★★', () async {
      final base = _deck(count: 4);
      serveHolding(_deck(count: 2));
      final marks = FakeMarks(baseline: baselineOf(base));

      final out = await run(base, marks);

      expect(out, isA<DeckSyncRemoteWins>());
      expect((out as DeckSyncRemoteWins).reason,
          DeckSyncRemoteReason.remoteOnly);
      expect(received.where((r) => r['path'] == decksPutPath), isEmpty);
      expect(marks.recorded, isEmpty);
    });

    test('★★ 両側が動いていれば★解決してから送る（conflict）★★', () async {
      final base = _deck(count: 4);
      serveHolding(_deck(count: 2, updatedAt: DateTime.utc(2026, 1, 15)));
      final marks = FakeMarks(baseline: baselineOf(base, hasOps: true));

      final out = await run(
          _deck(count: 3, updatedAt: DateTime.utc(2026, 2, 1)), marks);

      expect(out, isA<DeckSyncSent>());
      expect((out as DeckSyncSent).mark, 'M-NEW');
    });

    test('★★ 衝突で相手が勝てば★送らない ★★', () async {
      final base = _deck(count: 4);
      serveHolding(_deck(count: 2, updatedAt: DateTime.utc(2026, 3, 1)));
      final marks = FakeMarks(baseline: baselineOf(base, hasOps: true));

      final out = await run(
          _deck(count: 3, updatedAt: DateTime.utc(2026, 2, 1)), marks);

      expect(out, isA<DeckSyncRemoteWins>());
      expect(
          (out as DeckSyncRemoteWins).reason, DeckSyncRemoteReason.resolved);
    });
  });

  group('★★ 落ちたログの扱い（**D111-2** が「23 が決める」と書いた分）★★', () {
    DeckSyncBaseline baselineOf(Deck deck) =>
        (hasOpsSinceMark: true, contentHash: deckContentHash(deck));

    test('★★ 差し引きゼロの編集は★目印だけ進める（★送らない）★★', () async {
      final same = _deck();
      serveHolding(same);
      final marks = FakeMarks(baseline: baselineOf(same), mark: 9);

      final out = await run(same, marks);

      expect(out, isA<DeckSyncSkipped>());
      expect((out as DeckSyncSkipped).advancedMark, isTrue);
      expect(marks.recorded, hasLength(1));
      expect(marks.recorded.single.logMark, 9);
      expect(received.where((r) => r['path'] == decksPutPath), isEmpty);
    });

    test('★★ 論理削除だけが起きたら★★送る★★（★内容ハッシュは 1 ビットも動かない）★★', () async {
      // ★★ これが **D116-12** の言う「削除を見る手段はログ 1 つだけ」の受けである ★★
      //   ★**`DeckDao.softDelete` は `updatedAt` も動かす**（★実読）ので、
      //   ★★削除した側の時刻が新しい★★。→ ★決着層の段 1 で決まる。
      final alive = _deck();
      final deleted = _deck(
          deletedAt: DateTime.utc(2026, 2, 2),
          updatedAt: DateTime.utc(2026, 2, 2));
      expect(deckContentHash(alive), deckContentHash(deleted),
          reason: '★★前提: ★削除は内容ハッシュに現れない★★');

      serveHolding(alive);
      final marks = FakeMarks(baseline: baselineOf(alive), mark: 9);

      final out = await run(deleted, marks);

      expect(out, isA<DeckSyncSent>());
      final sent = lastPushBody()[syncContentKey]! as String;
      expect(decodeDeckForSync(sent).deletedAt, isNotNull);
    });

    test('★★ 相手だけが削除されていても★見る（★向きを問わない）★★', () async {
      final alive = _deck();
      serveHolding(_deck(
          deletedAt: DateTime.utc(2026, 3, 3),
          updatedAt: DateTime.utc(2026, 3, 3)));
      final marks = FakeMarks(baseline: baselineOf(alive));

      final out = await run(alive, marks);

      expect(out, isA<DeckSyncRemoteWins>(),
          reason: '★★相手の削除のほうが新しい★★');
    });

    test('★★ 時刻まで同じなら★決着層は★削除を見分けられない（★★記録する★★）★★', () async {
      // ★★ 隠さない —— ★★これは限界であって★手当てではない★★ ★★
      //   ★**`deletedAt` は★★内容ハッシュの 5 フィールドに無く**（**D111-4**）、
      //   ★★決着層の段 2 も内容ハッシュしか見ない★★（**D138-1**）。
      //   → ★**時刻が同値なら★★2 段とも削除を見ない★★。**
      //   ★**実物では起きにくい**（`softDelete` が `updatedAt` を動かす）が、
      //   ★★起きないとは書かない★★（**D-28**）。★**いまの挙動を固定する。**
      final alive = _deck();
      serveHolding(_deck(deletedAt: DateTime.utc(2026, 2, 2)));
      final marks = FakeMarks(baseline: baselineOf(alive));

      final out = await run(alive, marks);

      expect(out, isA<DeckSyncSent>(),
          reason: '★★同値なので★手元が勝つ ＝ ★相手の削除が上書きされる★★');
    });

    test('★★ 対: ★削除の状態が同じなら★送らない ★★', () async {
      final deleted = _deck(deletedAt: DateTime.utc(2026, 2, 2));
      serveHolding(deleted);
      final marks = FakeMarks(baseline: baselineOf(deleted));

      final out = await run(deleted, marks);

      expect(out, isA<DeckSyncSkipped>());
    });
  });

  group('★★ 送れなかったら★器を 1 バイトも触らない ★★', () {
    DeckSyncBaseline baselineOf(Deck deck) =>
        (hasOpsSinceMark: true, contentHash: deckContentHash(deck));

    test('★★ 412 は DeckSyncStale。★再試行は 0 回である（**D141-3**）★★', () async {
      final base = _deck(count: 4);
      handler = (request) async {
        if (request.uri.path == decksFetchPath) {
          await reply(request, 200, {
            'ok': true,
            'content': encodeDeckForSync(base),
            syncMarkKey: 'M-REMOTE',
          });
          return;
        }
        await reply(request, 412, {'ok': false});
      };
      final marks = FakeMarks(baseline: baselineOf(base));

      final out = await run(_deck(count: 3), marks);

      expect(out, isA<DeckSyncStale>());
      expect(marks.recorded, isEmpty);
      expect(received.where((r) => r['path'] == decksPutPath), hasLength(1),
          reason: '★★1 回だけ投げる（★取り直さない）★★');
    });

    test('★ 401 は DeckSyncNotAuthorized', () async {
      handler = (request) async => reply(request, 401, {'ok': false});
      final marks = FakeMarks();

      final out = await run(_deck(), marks);

      expect(out, isA<DeckSyncNotAuthorized>());
      expect(marks.recorded, isEmpty);
    });

    test('★ 送る側で 500 なら DeckSyncFailed', () async {
      final base = _deck(count: 4);
      handler = (request) async {
        if (request.uri.path == decksFetchPath) {
          await reply(request, 200, {
            'ok': true,
            'content': encodeDeckForSync(base),
            syncMarkKey: 'M-REMOTE',
          });
          return;
        }
        await reply(request, 500, {'ok': false});
      };
      final marks = FakeMarks(baseline: baselineOf(base));

      final out = await run(_deck(count: 3), marks);

      expect(out, isA<DeckSyncFailed>());
      expect(marks.recorded, isEmpty);
    });

    test('★★ 受け取った字面が読めなければ★DeckSyncFailed（★★埋めない★★）★★', () async {
      handler = (request) async => reply(request, 200, {
            'ok': true,
            'content': '{"deckId":"D-1"}',
            syncMarkKey: 'M-REMOTE',
          });
      final marks = FakeMarks();

      final out = await run(_deck(), marks);

      expect(out, isA<DeckSyncFailed>());
      expect(received.where((r) => r['path'] == decksPutPath), isEmpty,
          reason: '★★読めない相手に★上書きを投げない★★');
      expect(marks.recorded, isEmpty);
    });

    test('★ つながらなければ DeckSyncFailed（★投げない）', () async {
      final marks = FakeMarks();

      final out = await syncOneDeck(
        client: client,
        server: Uri.parse('https://localhost:1'),
        userName: 'みつき',
        password: 'ひみつ',
        local: _deck(),
        marks: marks,
      );

      expect(out, isA<DeckSyncFailed>());
      expect(marks.recorded, isEmpty);
    });
  });

  group('★★ 手元を 1 バイトも書き換えない（★受信は §32-6 の 24 である）★★', () {
    test('★★ 相手が勝っても★手元の `Deck` は★そのままである ★★', () async {
      serveHolding(_deck(name: 'あいて', updatedAt: DateTime.utc(2026, 3, 1)));
      final local = _deck(name: 'てもと');
      final before = encodeDeckForSync(local);

      await run(local, FakeMarks(baseline: null));

      expect(encodeDeckForSync(local), before);
    });

    test('★★ 書き込む口を★1 つも持たない（★走査）★★', () {
      // ★★ 手元のデッキを書く口（`DeckRepository` / `DeckDao`）を★呼ばない ★★
      //   ★**`DeckSyncMarkDao` は★★器だけを書く★★ので、★別である。**
      final src = File('lib/src/data/deck_sync.dart').readAsStringSync();

      expect(src.contains('DeckRepository'), isFalse);
      expect(src.contains('DeckDao('), isFalse,
          reason: '★★手元のデッキを書く DAO を★組み立てない★★');
      expect(src.contains('DeckSyncMarks'), isTrue, reason: '★陽性対照');
    });
  });

  group('★★ 目印は★先に取る（★同期のあいだの編集を★送ったことにしない）★★', () {
    test('★★ 記録する目印は★取りに行く★前★の値である ★★', () async {
      serveEmpty();
      final marks = FakeMarks(mark: 5);
      // ★★ 取りに行っているあいだに★編集が入った（★★目印が進んだ★★）★★
      handler = (request) async {
        marks.mark = 99;
        if (request.uri.path == decksFetchPath) {
          await reply(request, 404, {'ok': false});
          return;
        }
        await reply(request, 201, {'ok': true, syncMarkKey: 'M-NEW'});
      };

      await run(_deck(), marks);

      expect(marks.recorded.single.logMark, 5,
          reason: '★★99 を書くと★送っていない編集を★送ったことにする★★');
    });
  });

}
