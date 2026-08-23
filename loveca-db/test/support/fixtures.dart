/// テスト用ミニ配信物の読み出し.
///
/// `test/fixtures/dist/` は `tool/build_fixtures.py` が実データから生成したもの。
/// ★手書きの想定 JSON は置かない★
/// 生成側 (Python) と読込側 (Dart) で形式がずれても、手書きだと気づけないため。
library;

import 'dart:io';

import 'package:loveca_core/loveca_core.dart';

/// ミニ配信物の場所。`dart test` は パッケージルートを CWD にする。
Directory get fixtureDist =>
    Directory('${Directory.current.path}/test/fixtures/dist');

String readFixture(String relativePath) =>
    File('${fixtureDist.path}/$relativePath').readAsStringSync();

VersionInfo get fixtureVersion => VersionInfo.parse(readFixture('version.json'));

Manifest get fixtureManifest => Manifest.parse(readFixture('manifest.json'));

CardSet loadCardSet(String expansion) =>
    CardSet.parse(readFixture('cards/$expansion.json'));

/// ミニ配信物に入っている商品。
const fixtureExpansions = [
  'BP01',
  'BP03',
  'BP05',
  'HSSD01',
  'NSD01',
  'NSD02',
  'PR',
];

// ---------------------------------------------------------------------------
// テストが参照する実データ上の実例
// ---------------------------------------------------------------------------

/// ★非パラレル刷りが 2 つある cardNumber（BP01 の -N とプロモの -PR）。
const multiPrintingMember = 'PL!HS-bp1-012';

/// ★刷りが 3 つあり、うち 2 つが非パラレル。
/// BP03 の -N（通常）/ BP05 の -RM（パラレル）/ PR の -PR（通常）。
const multiPrintingWithParallel = 'PL!-bp3-012';

/// ブレードハートに DRAW を持つライブ（8.3.12.1）。
const drawLive = 'PL!-bp3-021';

/// ブレードハートに SCORE を持つライブ（8.4.2.1）。
const scoreLive = 'PL!HS-bp1-019';
