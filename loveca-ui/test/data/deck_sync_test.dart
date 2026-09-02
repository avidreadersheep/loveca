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

import '../support/fake_deck_repository.dart';
import '../support/strip_comments.dart';

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

/// ★書く側のフェイク（★★DB を開かない★★）。
class FakeWriter implements DeckSyncWriter {
  final List<({Deck deck, List<DeckEditOpRecord> ops})> saves = [];

  /// ★書いたときに起こすこと（★目印を進める / ★投げる）。
  void Function()? onSave;

  @override
  Future<void> saveReceived(
    Deck received, {
    required List<DeckEditOpRecord> ops,
  }) async {
    onSave?.call();
    saves.add((deck: received, ops: ops));
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
      //   ★★ 2026-09-02 訂正: ★「実物では起きにくい」と書いてあった ★★
      //   ★**D-28 が★その言い方そのものを禁じている**（★確率を測っていない）。
      //   ★★ 起きる条件（★★これだけが書ける★★）★★
      //   ★**(1) 両側の `updatedAt` が★★同じ秒★★**（★★保存精度は秒★★ / **D115-8** —— ★ミリ秒ではない）／
      //   ★**(2) 内容ハッシュの 5 フィールドが★一致する**（★`deletedAt` だけが違う形）。
      //   ★★ 立つ道筋 ★★ —— ★A が保存 → ★B へ同期 → ★★同じ秒のうちに A が削除★★ →
      //     ★B が同期すると★★B の生きている版が勝つ★★。
      //   ★★**この対が固定しているのは★いまの挙動である**★★（★手元が勝ち `DeckSyncSent` が返る）。
      //   → ★**直すと★★この 1 件が落ちる。★それが合図である★★**（★先例は **D-24** / ★待ち行列の **W-43**）。
      final alive = _deck();
      serveHolding(_deck(deletedAt: DateTime.utc(2026, 2, 2)));
      final marks = FakeMarks(baseline: baselineOf(alive));

      final out = await run(alive, marks);

      expect(out, isA<DeckSyncSent>(),
          reason: '★★同値なので★手元が勝つ ＝ ★相手の削除が上書きされる★★');
    });

    test('★★ 道筋: ★保存 → 同期 → ★★同じ秒のうちに削除★★ → ★もう 1 台が同期する ★★',
        () async {
      // ★★ 書いた道筋を★実際に通す（**D-15 (j)** —— ★★断定を書いたら走らせる★★）★★
      //   ★**段 1** 端末 A が保存する（`updatedAt` ＝ t）。
      //   ★**段 2** その版が端末 B へ同期される（★B の `updatedAt` も t）。
      //   ★**段 3** ★★同じ秒のうちに★★ 端末 A が `softDelete` する。
      //     → ★**`updatedAt` は★★秒に丸められて保管される★★**（**D115-8** の測定 1）ので、
      //       ★★A と B の `updatedAt` は★同じ値になる★★。
      //   ★**段 4** 端末 B が同期する。
      //
      // ★★ 秒に丸めたうえで★同じ値になることを★この test 自身が作る ★★
      //   ★**「同じ秒」を★ミリ秒違いの 2 つの時刻から作る**（★★保存精度が秒であることの意味★★）。
      final edited = DateTime.utc(2026, 2, 1, 3, 4, 5, 120);
      final deleted = DateTime.utc(2026, 2, 1, 3, 4, 5, 890);
      DateTime toStored(DateTime t) =>
          DateTime.fromMillisecondsSinceEpoch(
              (t.millisecondsSinceEpoch ~/ 1000) * 1000,
              isUtc: true);
      expect(toStored(edited), toStored(deleted),
          reason: '★★秒に丸めると★同じ値になる（★これが前提である）★★');

      final bAlive = _deck(updatedAt: toStored(edited));
      serveHolding(_deck(updatedAt: toStored(deleted), deletedAt: deleted));
      final marks = FakeMarks(baseline: baselineOf(bAlive));

      final out = await run(bAlive, marks);

      expect(out, isA<DeckSyncSent>(),
          reason: '★★B の生きている版が勝ち、★A の削除が上書きされる★★');
    });

    test('★★ 対: ★秒が 1 つ違えば★削除が勝つ（★★丸めの前なら差が残る★★）★★', () async {
      // ★★ 上の道筋が「同じ秒」に依っていることの対 ★★
      //   ★**1 秒ずらすだけで★★段 1 で決まり、★相手の削除が勝つ★★。**
      final bAlive = _deck(updatedAt: DateTime.utc(2026, 2, 1, 3, 4, 5));
      serveHolding(_deck(
          updatedAt: DateTime.utc(2026, 2, 1, 3, 4, 6),
          deletedAt: DateTime.utc(2026, 2, 1, 3, 4, 6)));
      final marks = FakeMarks(baseline: baselineOf(bAlive));

      final out = await run(bAlive, marks);

      expect(out, isA<DeckSyncRemoteWins>(),
          reason: '★★秒が違えば★段 1 で決まる★★');
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

    test('★★ 手元のデッキを書く口を★1 つも組み立てない（★走査）★★', () {
      // ★★ 書くのは [DeckSyncWriter] 越しだけである（★§32-6 の 24 / **D144**）★★
      //   ★**`DeckRepository` も `DeckDao` も★★この口が組み立てない★★。**
      //   ★**`DeckSyncMarkDao` は★★器だけを書く★★ので、★別である。**
      //
      // ★★ D-30 —— ★doc は★禁止対象と同じ字面を必ず含む ★★
      //   ★**実測: ★素の走査では★★この口の doc 自身が当たる★★。**
      final code = stripComments(
          File('lib/src/data/deck_sync.dart').readAsStringSync());

      expect(code.contains('DeckRepository'), isFalse);
      expect(code.contains('DeckDao('), isFalse,
          reason: '★★手元のデッキを書く DAO を★組み立てない★★');
      expect(code.contains('DeckSyncWriter'), isTrue, reason: '★陽性対照');
    });

    test('★★ 対: ★コメントを外さないと★doc 自身が当たる（★陽性対照 / D-30）★★', () {
      final raw = File('lib/src/data/deck_sync.dart').readAsStringSync();

      expect(raw.contains('DeckRepository'), isTrue,
          reason: '★★doc は★禁止対象と同じ字面を必ず含む★★');
    });

    // ★★ 純粋関数にする —— ★★合成の入力で対を作れるようにするため★★ ★★
    //   ★**実測: ★本番のファイルだけを見る形だと、★★コメント外しに対が届かない★★**
    //     （★★`deck_sync.dart` の doc は★`Deck.fromJson` を 1 度も引いていない★★ / ★仕込んで 0 件）。
    //   ★**先例は §63-7 の (J)** —— ★★同じ処置である★★。
    bool callsFromJsonIn(String source) =>
        stripComments(source).contains('Deck.fromJson');

    test('★★ 同期の経路は `Deck.fromJson` を 1 度も呼ばない（★走査）★★', () {
      // ★★ 取り違えたときの害は [Deck.fromJson] の doc に書いた（★★1 か所である★★）★★
      //   ★**組むのは `decodeDeckForSync` だけである**（★決定 **D142** ＝ 組-1）。
      //   ★**`Deck.fromJson` は★★欠けた鍵を既定値で埋める★★**ので、
      //     ★★壊れた字面が「空のデッキ」として成立し、★解決で勝って★手元のデッキが消えうる★★。
      for (final path in const [
        'lib/src/data/deck_sync.dart',
        'lib/src/data/deck_sync_client.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(callsFromJsonIn(source), isFalse, reason: '★$path');
        expect(
            stripComments(source).contains('decodeDeckForSync') ||
                path.contains('client'),
            isTrue,
            reason: '★陽性対照 —— ★組む口は★こちらである');
      }
    });

    test('★★ 対: ★呼べば★この走査が捕まえる（★陽性対照）★★', () {
      expect(
        callsFromJsonIn('Deck f(Map<String, dynamic> j) => Deck.fromJson(j);'),
        isTrue,
      );
    });

    test('★★ 対: ★doc の中の字面は★コメント外しが落とす（★★D-30★★）★★', () {
      // ★★ 合成の入力で対を作る —— ★★本番の doc に★この字面が 1 つも無いからである★★
      //   ★**実測: ★本番だけを見る形では★★仕込んでも 0 件だった★★**（**D-27**）。
      final lines = <String>[
        '/// ★doc の写し: ★この口は `Deck.fromJson` を呼ばない。',
        'Deck f(String s) => decodeDeckForSync(s);',
      ];
      final source = lines.join(String.fromCharCode(10));

      expect(source.contains('Deck.fromJson'), isTrue, reason: '★陽性対照');
      expect(callsFromJsonIn(source), isFalse);
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

  group('★★ 受信（★§32-6 の **24** / 決定 **D144**）★★', () {
    late FakeWriter writer;
    late FakeMarks marks;

    setUp(() {
      writer = FakeWriter();
      marks = FakeMarks(mark: 3);
    });

    DeckSyncRemoteWins wins(Deck remote, DeckSyncRemoteReason reason) =>
        DeckSyncRemoteWins(remote: remote, mark: 'M-REMOTE', reason: reason);

    test('★★ 受け取った `Deck` を★1 フィールドも変えずに書く（**N-15**）★★', () async {
      final remote = _deck(name: 'あいて', updatedAt: DateTime.utc(2026, 3, 1));

      await applyRemoteDeck(
        wins(remote, DeckSyncRemoteReason.remoteOnly),
        writer: writer,
        marks: marks,
        at: DateTime.utc(2026, 9, 2),
      );

      final saved = writer.saves.single.deck;
      expect(saved.updatedAt, DateTime.utc(2026, 3, 1),
          reason: '★★送信側の `updatedAt` を★そのまま採る★★');
      expect(saved.revision, remote.revision, reason: '★+1 しない');
      expect(saved.name, 'あいて');
      expect(saved.lastDeviceId, remote.lastDeviceId);
    });

    test('★★ 解決が起きたときだけ★ログを 1 件残す（**D119-1**）★★', () async {
      await applyRemoteDeck(
        wins(_deck(), DeckSyncRemoteReason.resolved),
        writer: writer,
        marks: marks,
        at: DateTime.utc(2026, 9, 2),
      );

      expect(writer.saves.single.ops, hasLength(1));
      expect(writer.saves.single.ops.single.kind,
          DeckEditOpKind.resolveConflict);
      expect(writer.saves.single.ops.single.at, DateTime.utc(2026, 9, 2));
    });

    test('★★ 対: ★相手側だけが変わっていたら★ログを 1 件も残さない ★★', () async {
      // ★★ 残すと★次の同期が「まだ送っていない編集が在る」と読む ★★
      await applyRemoteDeck(
        wins(_deck(), DeckSyncRemoteReason.remoteOnly),
        writer: writer,
        marks: marks,
        at: DateTime.utc(2026, 9, 2),
      );

      expect(writer.saves.single.ops, isEmpty);
    });

    test('★★ 器は★書いたあとに記録する（★目印が★ログの行を含む）★★', () async {
      // ★★ 書くと目印が進む（★`resolveConflict` の行が入る）★★
      writer.onSave = () => marks.mark = 8;

      await applyRemoteDeck(
        wins(_deck(), DeckSyncRemoteReason.resolved),
        writer: writer,
        marks: marks,
        at: DateTime.utc(2026, 9, 2),
      );

      expect(marks.recorded.single.logMark, 8,
          reason: '★★3 を書くと★その 1 件を★次の同期が送る★★');
    });

    test('★★ 基準は★受け取った版の内容ハッシュである ★★', () async {
      final remote = _deck(name: 'あいて');

      await applyRemoteDeck(
        wins(remote, DeckSyncRemoteReason.remoteOnly),
        writer: writer,
        marks: marks,
        at: DateTime.utc(2026, 9, 2),
      );

      expect(marks.recorded.single.baselineHash, deckContentHash(remote));
    });

    test('★★ 書く前に器を触らない（★書けなければ★器は古いまま）★★', () async {
      writer.onSave = () => throw StateError('★書けなかった');

      await expectLater(
        applyRemoteDeck(
          wins(_deck(), DeckSyncRemoteReason.resolved),
          writer: writer,
          marks: marks,
          at: DateTime.utc(2026, 9, 2),
        ),
        throwsA(isA<StateError>()),
      );
      expect(marks.recorded, isEmpty);
    });

    test('★★ 送信と受信を★通してみる（★相手が勝つ場面）★★', () async {
      serveHolding(_deck(name: 'あいて', updatedAt: DateTime.utc(2026, 3, 1)));
      final out = await run(_deck(name: 'てもと'), marks);

      expect(out, isA<DeckSyncRemoteWins>());
      await applyRemoteDeck(out as DeckSyncRemoteWins,
          writer: writer, marks: marks, at: DateTime.utc(2026, 9, 2));

      expect(writer.saves.single.deck.name, 'あいて');
      expect(marks.recorded, hasLength(1));
    });
  });

  group('★★ フェイクも★3 つ組を触らない（★★本実装と食い違わせない★★ / D70）★★', () {
    test('★★ `saveReceived` は★1 フィールドも変えない ★★', () async {
      // ★★ フェイクだけカバーを外すと★本実装と黙って食い違う（★上の `save` の doc）★★
      final fake = FakeDeckRepository();
      final received = Deck(
        deckId: 'D-1',
        name: 'うけとった',
        entries: const [],
        memo: '',
        tags: const [],
        coverPrintingId: null,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 3, 1),
        deletedAt: null,
        revision: 42,
        lastDeviceId: 'あいて',
        masterDataVersion: 7,
      );

      await fake.saveReceived(received, ops: const []);

      final saved = fake.receivedSaves.single.deck;
      expect(saved.updatedAt, DateTime.utc(2026, 3, 1));
      expect(saved.revision, 42);
      expect(saved.lastDeviceId, 'あいて');
    });

    test('★★ 書いたら★一覧から読める ★★', () async {
      final fake = FakeDeckRepository();
      final received = Deck(
        deckId: 'D-2',
        name: 'あたらしい',
        entries: const [],
        memo: '',
        tags: const [],
        coverPrintingId: null,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 3, 1),
        deletedAt: null,
        revision: 1,
        lastDeviceId: '',
        masterDataVersion: 0,
      );

      await fake.saveReceived(received, ops: const []);

      expect((await fake.byId('D-2'))!.name, 'あたらしい');
    });

    test('★★ 渡した操作を★そのまま覚える（★器だけを通す）★★', () async {
      final fake = FakeDeckRepository();
      final received = await fake.create(name: 'もと');

      await fake.saveReceived(received,
          ops: [(kind: DeckEditOpKind.resolveConflict, at: DateTime.utc(2026, 9, 2))]);

      expect(fake.receivedSaves.single.ops.single.kind,
          DeckEditOpKind.resolveConflict);
    });
  });

}
