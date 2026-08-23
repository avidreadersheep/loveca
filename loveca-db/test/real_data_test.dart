/// 実配信データとの一致の検証.
///
/// ★`loveca-data/data/` は git 管理外★
/// クローン直後は存在しないので、未配置なら [markTestSkipped] で
/// **理由を明示して**飛ばす。落とすのは誤りだが、黙って通すのも誤り。
///
/// ```bash
/// dart test                                  # 既定は ../loveca-data/data/dist
/// LOVECA_DIST_DIR=/path/to/dist dart test    # 場所を変える
/// ```
///
/// ★テスト結果を報告するときは skip 件数も併記すること★
/// 「全通過」に skip が埋もれると、検証しているつもりで検証していない状態になる。
library;

import 'dart:io';

import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_db/native.dart';
import 'package:test/test.dart';

final _t0 = DateTime.utc(2026, 8, 23, 12);

Directory get _dist => Directory(
      Platform.environment['LOVECA_DIST_DIR'] ??
          '${Directory.current.parent.path}/loveca-data/data/dist',
    );

/// 実データが無ければ理由を出して飛ばす。
bool _skipIfMissing() {
  if (_dist.existsSync()) return false;
  markTestSkipped(
    '★実データ未配置のため検証していません★ ${_dist.path} がありません。'
    'loveca-data/data/ は git 管理外です。'
    'LOVECA_DIST_DIR で場所を指定できます。',
  );
  return true;
}

void main() {
  late LovecaDatabase db;
  late CardDao cards;

  setUp(() => db = LovecaDatabase(openInMemoryExecutor()));
  tearDown(() => db.close());

  Future<MasterImportResult> importRealDist() async {
    cards = CardDao(db);
    return MasterImporter(db).import(
      remoteVersion:
          VersionInfo.parse(File('${_dist.path}/version.json').readAsStringSync()),
      remoteManifest:
          Manifest.parse(File('${_dist.path}/manifest.json').readAsStringSync()),
      source: LocalDirectoryMasterFileSource(_dist),
      appVersion: '1.0.0',
      now: _t0,
    );
  }

  group('実配信データ (dataVersion 2)', () {
    test('全 22 商品を取り込める', () async {
      if (_skipIfMissing()) return;
      final result = await importRealDist();

      expect(result.hasFailures, isFalse,
          reason: '失敗: ${result.failedPaths}');
      expect(result.unhandledPaths, isEmpty);
      expect(result.dataVersionAdvanced, isTrue);

      // CLAUDE.md §8 の実測値。
      expect(await cards.cardCount(), 1708, reason: 'cardNumber の種類数');
      expect((await cards.printingsById()).length, 2527, reason: '刷りの数');
    }, timeout: const Timeout(Duration(minutes: 3)));

    // ★CLAUDE.md §6 の実測値。色ハートと同じ入れ物に戻していないことの証拠。
    test('bladeHeartEffects の DRAW が 59 種 / SCORE が 37 種', () async {
      if (_skipIfMissing()) return;
      await importRealDist();

      final rows = await db
          .customSelect('SELECT effect, COUNT(DISTINCT card_number) AS c '
              'FROM card_blade_heart_effects GROUP BY effect')
          .get();
      final counts = {
        for (final r in rows) r.read<String>('effect'): r.read<int>('c'),
      };
      expect(counts, {'draw': 59, 'score': 37});
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('DRAW / SCORE はライブカードにしか無い', () async {
      if (_skipIfMissing()) return;
      await importRealDist();

      final rows = await db
          .customSelect('SELECT DISTINCT c.card_type AS t '
              'FROM card_blade_heart_effects e '
              'JOIN cards c ON c.card_number = e.card_number')
          .get();
      expect(rows.map((r) => r.read<String>('t')).toSet(), {'live'});
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('card_hearts に DRAW / SCORE が 1 件も混入していない', () async {
      if (_skipIfMissing()) return;
      await importRealDist();

      final rows =
          await db.customSelect('SELECT DISTINCT color FROM card_hearts').get();
      final colors = rows.map((r) => r.read<String>('color')).toSet();
      // 実データで使われている 8 色。gray / all を含む。
      expect(colors, {
        'pink', 'red', 'yellow', 'green', 'blue', 'purple', 'gray', 'all',
      });
      expect(colors.intersection({'draw', 'score'}), isEmpty);
    }, timeout: const Timeout(Duration(minutes: 3)));

    // ★CLAUDE.md §5-(4): isParallel は刷り単位。
    test('非パラレル刷りが複数ある cardNumber が 19 件ある', () async {
      if (_skipIfMissing()) return;
      await importRealDist();

      final rows = await db
          .customSelect('SELECT COUNT(*) AS c FROM ('
              'SELECT card_number FROM printings WHERE is_parallel = 0 '
              'GROUP BY card_number HAVING COUNT(*) > 1)')
          .getSingle();
      expect(rows.read<int>('c'), 19);
    }, timeout: const Timeout(Duration(minutes: 3)));

    // ★決定 D50 の回帰テスト★
    // 既定が 500 だった頃、この語は 1,034 種に当たるのに 500 種しか返らず、
    // 落ちた 534 種は戻り値に何の痕跡も残していなかった。
    test('既定の上限で実データが切り捨てられない', () async {
      if (_skipIfMissing()) return;
      await importRealDist();

      // 長音記号。実データで最も広く当たる語。
      final result = await CardSearchDao(db).search('ー');
      expect(result.mode, CardSearchMode.likeFallback);
      expect(result.length, 1034);
      expect(result.truncated, isFalse);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('★上限で切ったときは黙らず truncated を立てる', () async {
      if (_skipIfMissing()) return;
      await importRealDist();

      final capped = await CardSearchDao(db).search('ー', limit: 500);
      expect(capped.length, 500);
      expect(capped.truncated, isTrue);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('検索索引がカード件数と一致する', () async {
      if (_skipIfMissing()) return;
      await importRealDist();
      expect(await CardSearchDao(db).indexedCount(), 1708);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('★fold の冪等性を実データ全件で確かめる', () {
    test('全検索対象テキストで fold(fold(x)) == fold(x)', () async {
      if (_skipIfMissing()) return;
      await importRealDist();

      var checked = 0;
      for (final card in (await cards.cardsByNumber()).values) {
        for (final text in [
          card.cardNumber,
          card.name,
          card.effectText,
          ...card.groupNames,
          ...card.unitNames,
          ...card.characterNames,
        ]) {
          final once = fold(text);
          expect(fold(once), once, reason: '${card.cardNumber}: $text');
          checked++;
        }
      }
      expect(checked, greaterThan(5000));
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
