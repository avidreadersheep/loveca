import 'dart:io';

import 'package:loveca_core/loveca_core.dart';
import 'package:test/test.dart';

/// ★フィクスチャは Python パイプラインが実際に生成した JSON をそのままコピーしたもの★
/// 手書きの想定 JSON でテストすると、生成側と読み込み側で形式がずれていても気づけない。
String _fixture(String name) =>
    File('test/fixtures/$name').readAsStringSync();

void main() {
  group('version.json', () {
    test('パースできる', () {
      final v = VersionInfo.parse(_fixture('version.json'));
      expect(v.dataVersion, 2, reason: 'bladeHeartEffects 追加で形式が変わった');
      expect(v.minAppVersion, '1.0.0');
      expect(v.manifestHash, startsWith('sha256:'));
    });

    test('アプリのバージョン比較', () {
      const v = VersionInfo(
        dataVersion: 1,
        minAppVersion: '1.2.0',
        manifestPath: '/data/manifest.json',
        manifestHash: '',
      );
      expect(v.isAppSupported('1.2.0'), isTrue);
      expect(v.isAppSupported('1.2.1'), isTrue);
      expect(v.isAppSupported('1.10.0'), isTrue, reason: '10 > 2 の桁比較');
      expect(v.isAppSupported('1.1.9'), isFalse);
    });

    test('compareVersions が桁数の違う版を扱える', () {
      expect(compareVersions('1.0', '1.0.0'), 0);
      expect(compareVersions('1.0.1', '1.0'), greaterThan(0));
      expect(compareVersions('2.0', '10.0'), lessThan(0));
    });
  });

  group('cards/{EXPANSION}.json', () {
    late CardSet set;
    setUpAll(() => set = CardSet.parse(_fixture('cards_BP01.json')));

    test('カードと刷りを読める', () {
      expect(set.expansion, 'BP01');
      expect(set.cards, isNotEmpty);
      expect(set.printings, isNotEmpty);
    });

    test('★複数キャラ・複数グループが配列で入る (総合ルール 2.3.2.1 / 2.4.2.1)', () {
      final card =
          set.cards.firstWhere((c) => c.cardNumber == 'LL-bp1-001');
      expect(card.characterNames,
          ['上原歩夢', '澁谷かのん', '日野下花帆']);
      expect(card.groupNames, ['虹ヶ咲', 'Liella!', '蓮ノ空']);
    });

    test('★メンバーのフィールド (cost / bladeCount / hearts)', () {
      final card =
          set.cards.firstWhere((c) => c.cardNumber == 'LL-bp1-001');
      expect(card.cardType, CardType.member);
      expect(card.cost, 20);
      expect(card.bladeCount, 5);
      expect(card.score, isNull);
      expect(card.hearts, {
        HeartColor.pink: 3,
        HeartColor.green: 3,
        HeartColor.purple: 3,
      });
      expect(card.heartTotal, 9);
      expect(card.stats, 14, reason: '決定 D14: ブレード + ハート');
    });

    test('★ライブのフィールド (score / requiredHearts / bladeHearts)', () {
      final live = set.cards.firstWhere((c) => c.cardType == CardType.live);
      expect(live.score, isNotNull);
      expect(live.requiredHearts, isNotEmpty);
      expect(live.cost, isNull);
      // 必要ハートには「色指定なし」(GRAY) が入りうる (総合ルール 2.1.1.2)
      expect(
        live.requiredHearts.keys,
        everyElement(isIn(HeartColor.values)),
      );
    });

    test('★ブレードハートの色と効果アイコンが型で分かれている', () {
      // ★A-1 の回帰防止★
      // DRAW / SCORE を bladeHearts に入れて配信すると
      // HeartColor.fromKey が throw し、カードマスタのロードが丸ごと落ちる。
      for (final card in set.cards) {
        expect(card.bladeHearts.keys, everyElement(isIn(HeartColor.values)),
            reason: '${card.cardNumber}: bladeHearts は色のみ (総合ルール 8.3.14)');
      }

      // 総合ルール 8.3.12.1: ドローアイコン。色と同居する
      final draw =
          set.cards.firstWhere((c) => c.cardNumber == 'PL!HS-bp1-022');
      expect(draw.bladeHearts, {HeartColor.blue: 1});
      expect(draw.bladeHeartEffects, {BladeHeartEffect.draw: 1});

      // 総合ルール 8.4.2.1: スコアアイコン。色を伴わず単独で入る
      final score =
          set.cards.firstWhere((c) => c.cardNumber == 'PL!HS-bp1-019');
      expect(score.bladeHearts, isEmpty);
      expect(score.bladeHeartEffects, {BladeHeartEffect.score: 1});
    });

    test('効果アイコンを持たないカードは bladeHeartEffects が空', () {
      final live =
          set.cards.firstWhere((c) => c.cardNumber == 'PL!N-bp1-025');
      expect(live.bladeHearts, {HeartColor.all: 1});
      expect(live.bladeHeartEffects, isEmpty);
    });

    test('★printingId と cardNumber が 2 階層になっている', () {
      final printing = set.printings.first;
      expect(printing.printingId, startsWith(printing.cardNumber));
      expect(printing.printingId.length,
          greaterThan(printing.cardNumber.length),
          reason: 'printingId はレアリティ接尾を含む');
    });

    test('imageHash が入っている (画像は不変・CDN キャッシュ可)', () {
      expect(set.printings.every((p) => p.imageHash.isNotEmpty), isTrue);
    });

    test('全角プラスが NFKC で半角に統一されている', () {
      for (final p in set.printings) {
        expect(p.printingId.contains('\uFF0B'), isFalse,
            reason: '${p.printingId} に全角プラスが残っている');
        expect(p.rarity.contains('\uFF0B'), isFalse);
      }
    });
  });

  group('meta', () {
    test('products.json が camelCase で読める', () {
      final products = MasterMeta.parseProducts(_fixture('products.json'));
      expect(products, isNotEmpty);
      expect(products.first.expansionId, 'BP01');
      expect(products.first.name, contains('ブースターパック'));
      expect(products.first.releaseDateTime, DateTime(2025, 2, 8));
    });

    test('ruleConfig.json が総合ルール 6.1 の値を持つ', () {
      final config = MasterMeta.parseRuleConfig(_fixture('ruleConfig.json'));
      expect(config.mainDeckSize, 60);
      expect(config.memberCount, 48);
      expect(config.liveCount, 12);
      expect(config.energyDeckSize, 12);
      expect(config.maxCopiesPerCardNumber, 4);
      expect(config.winCondition, 3);
    });
  });

  group('差分更新の計画', () {
    late VersionInfo remote;
    late Manifest manifest;

    setUpAll(() {
      remote = VersionInfo.parse(_fixture('version.json'));
      manifest = Manifest.parse(_fixture('manifest.json'));
    });

    // =====================================================================
    // ★★ 版ゲートは「より小さい」で切る（決定 D118-3 = 版-3 / 所見 D-32）★★
    // =====================================================================
    //
    // ★ここは 2026-08-31 に向きが変わった。
    //   以前は「同じ dataVersion なら更新不要」を**仕様として**固定していた。
    //   ★★その仕様が D-32 そのものだった★★ —— 同じ版のまま cards/*.json を
    //   作り直しても、manifest のファイルを 1 件も見ずに落ちる。
    //
    // ★★ 3 つとも要る。1 つでも欠くと「常に通す実装」か
    //    「常に止める実装」が通ってしまう ★★

    test('★同じ dataVersion でも中身が違えば取り込む（所見 D-32 の根治）', () {
      // ★1 件だけローカルのハッシュを食い違わせる。
      final local = <String, String>{
        for (final f in manifest.files) f.path: f.hash,
      };
      final changed = manifest.files.first.path;
      local[changed] = 'sha256:0000';

      final plan = planUpdate(
        remoteVersion: remote,
        remoteManifest: manifest,
        appVersion: '1.0.0',
        localDataVersion: remote.dataVersion,
        localFileHashes: local,
      );
      expect(plan.decision, UpdateDecision.update);
      expect(plan.filesToDownload.map((f) => f.path), [changed]);
    });

    test('★対: 同じ dataVersion で中身も同じなら取るものが無い', () {
      // ★「常に通す実装」と区別するための対ではない（それは上で見ている）。
      //   ★★版ゲートを通したあと、**取るものが無いこと**を見る対である。★★
      final plan = planUpdate(
        remoteVersion: remote,
        remoteManifest: manifest,
        appVersion: '1.0.0',
        localDataVersion: remote.dataVersion,
        localFileHashes: {for (final f in manifest.files) f.path: f.hash},
      );
      expect(plan.needsDownload, isFalse);
      expect(plan.filesToDelete, isEmpty);
      // ★決定は `update` である。★`upToDate` には戻さない
      //   —— 「版で切った」と「中身が同じだった」は別の事実だからである。
      expect(plan.decision, UpdateDecision.update);
    });

    test('★対: 降格（配信物のほうが古い）は止まる。★これは意図である', () {
      // ★根拠は `docs/同期設計メモ.md` §23-3 の事実 (2) ——
      //   通すと古い dist が取り込まれ、削除計画が
      //   **新しい商品ファイルを消す**。
      final plan = planUpdate(
        remoteVersion: remote,
        remoteManifest: manifest,
        appVersion: '1.0.0',
        localDataVersion: remote.dataVersion + 1,
        localFileHashes: const {'cards/NEW01.json': 'sha256:beef'},
      );
      expect(plan.decision, UpdateDecision.upToDate);
      expect(plan.needsDownload, isFalse);
      expect(plan.filesToDelete, isEmpty,
          reason: '止めた以上、削除計画も立ててはならない');
    });

    test('アプリが古すぎれば強制アップデート', () {
      final plan = planUpdate(
        remoteVersion: const VersionInfo(
          dataVersion: 2,
          minAppVersion: '2.0.0',
          manifestPath: '',
          manifestHash: '',
        ),
        remoteManifest: manifest,
        appVersion: '1.0.0',
        localDataVersion: 1,
      );
      expect(plan.decision, UpdateDecision.appTooOld);
    });

    test('初回は全ファイルを取得する', () {
      final plan = planUpdate(
        remoteVersion: remote,
        remoteManifest: manifest,
        appVersion: '1.0.0',
        localDataVersion: 0,
      );
      expect(plan.decision, UpdateDecision.update);
      expect(plan.filesToDownload.length, manifest.files.length);
      expect(plan.totalBytes, manifest.totalBytes);
    });

    test('★ハッシュが同じファイルは取得しない (新弾追加時の差分更新)', () {
      // 1 件だけハッシュが変わった状況を作る
      final local = <String, String>{
        for (final f in manifest.files) f.path: f.hash,
      };
      final changed = manifest.files.first.path;
      local[changed] = 'sha256:0000';

      final plan = planUpdate(
        remoteVersion: remote,
        remoteManifest: manifest,
        appVersion: '1.0.0',
        localDataVersion: 0,
      // ignore: avoid_redundant_argument_values
        localFileHashes: local,
      );
      expect(plan.filesToDownload.map((f) => f.path), [changed],
          reason: '商品単位に分割してあるので変わったファイルだけ取れば済む');
    });

    test('配信から消えたファイルは削除対象になる', () {
      final local = <String, String>{
        for (final f in manifest.files) f.path: f.hash,
        'cards/OLD99.json': 'sha256:dead',
      };
      final plan = planUpdate(
        remoteVersion: remote,
        remoteManifest: manifest,
        appVersion: '1.0.0',
        localDataVersion: 0,
        localFileHashes: local,
      );
      expect(plan.filesToDelete, ['cards/OLD99.json']);
    });
  });

  // =========================================================================
  // ★★ 画像だけのマニフェスト（決定 D121-1 ＝ 画-5 / N-2 の画像側）★★
  // =========================================================================
  //
  // ★ここは受け取り側の 1／4 である（`docs/同期設計メモ.md` §32-6 の 5）。
  //   ★読むだけで、取りにも行かず取り込みもしない。
  //
  // ★★ 「まだ無い」と「0 枚である」を書き分けてある ★★
  //   生成側は `--skip-images` のとき書かず、列も出さない。
  //   空のマニフェストを書くと「画像が 0 枚である」という宣言になり、
  //   削除の計画を足したときに **全部消せ** と読める。
  group('★★ 版の情報の画像マニフェストの列（決定 D121-1）★★', () {
    const withColumns = '''
{"dataVersion":7,"minAppVersion":"0.3.0",
 "manifestPath":"/data/manifest.json","manifestHash":"sha256:aa",
 "imageManifestPath":"/data/image_manifest.json",
 "imageManifestHash":"sha256:bb"}''';

    test('★列が在れば読む', () {
      final v = VersionInfo.parse(withColumns);
      expect(v.imageManifestPath, '/data/image_manifest.json');
      expect(v.imageManifestHash, 'sha256:bb');
      expect(v.hasImageManifest, isTrue);
      // ★対: カード側の列は 1 つも動いていない。
      expect(v.manifestHash, 'sha256:aa');
    });

    test('★対: 列が無ければ null（★今日の現物がこの形である）', () {
      const old = '{"dataVersion":2,"minAppVersion":"1.0.0",'
          '"manifestPath":"/data/manifest.json","manifestHash":"sha256:aa"}';
      final v = VersionInfo.parse(old);
      expect(v.imageManifestPath, isNull);
      expect(v.imageManifestHash, isNull);
      expect(v.hasImageManifest, isFalse);
      // ★対: ほかは今までどおり読める（読み方を壊していない）。
      expect(v.dataVersion, 2);
      expect(v.manifestPath, '/data/manifest.json');
    });

    test('★対: 片方だけなら「無い」として扱う', () {
      // ★場所だけあってハッシュが無いと、取り直す判断ができない。
      //   ★推測で埋めない。
      const half = '{"dataVersion":2,"minAppVersion":"1.0.0",'
          '"manifestPath":"/data/manifest.json","manifestHash":"sha256:aa",'
          '"imageManifestPath":"/data/image_manifest.json"}';
      final v = VersionInfo.parse(half);
      expect(v.imageManifestPath, isNotNull, reason: '読めてはいる');
      expect(v.hasImageManifest, isFalse, reason: 'それでも「無い」扱いである');
    });

    test('★対: 空文字も「無い」として扱う', () {
      const empty = '{"dataVersion":2,"minAppVersion":"1.0.0",'
          '"manifestPath":"/data/manifest.json","manifestHash":"sha256:aa",'
          '"imageManifestPath":"","imageManifestHash":""}';
      expect(VersionInfo.parse(empty).hasImageManifest, isFalse);
    });

    test('★知らない名前は黙って捨てる（★古いアプリが新しい dist を読める）', () {
      // ★これが無いと、列を 1 つ足すたびに古いアプリが落ちる。
      const future = '{"dataVersion":2,"minAppVersion":"1.0.0",'
          '"manifestPath":"/data/manifest.json","manifestHash":"sha256:aa",'
          '"somethingWeHaveNotInventedYet":{"a":1}}';
      expect(VersionInfo.parse(future).dataVersion, 2);
    });
  });

  group('★★ 画像だけのマニフェストを読む（決定 D121-1）★★', () {
    const imageManifest = '''
{"files":[
  {"path":"images/thumb/aaaa.webp","hash":"sha256:11","bytes":10},
  {"path":"images/normal/aaaa.webp","hash":"sha256:22","bytes":20}
]}''';

    test('★dataVersion が無くても読める', () {
      final m = Manifest.parseImages(imageManifest);
      expect(m.files, hasLength(2));
      expect(m.byPath['images/thumb/aaaa.webp']!.hash, 'sha256:11');
      expect(m.totalBytes, 30);
    });

    test('★★ 対: カード側の parse は dataVersion が無いと落ちる ★★', () {
      // ★これが無いと、`parseImages` が「ただ緩めただけ」でも通ってしまう。
      //   ★カード側を緩めると **壊れたマニフェストが 0 として通る**。
      expect(() => Manifest.parse(imageManifest), throwsA(anything));
    });

    test('★対: カード側の parse は今までどおり読める', () {
      const cardManifest = '{"dataVersion":7,"files":['
          '{"path":"cards/BP01.json","hash":"sha256:33","bytes":5,'
          '"cardCount":2}]}';
      final m = Manifest.parse(cardManifest);
      expect(m.dataVersion, 7);
      expect(m.files.single.cardCount, 2);
    });

    test('★files が無くても落ちない（★空として読む）', () {
      expect(Manifest.parseImages('{}').files, isEmpty);
    });
  });

  group('画像 URL', () {
    test('サイズごとに組み立てられる', () {
      expect(
        imageUrl('https://cdn.example.com', 'abc123', ImageSize.thumb),
        'https://cdn.example.com/images/thumb/abc123.webp',
      );
      expect(
        imageUrl('https://cdn.example.com', 'abc123', ImageSize.large),
        'https://cdn.example.com/images/large/abc123.webp',
      );
    });
  });
}
