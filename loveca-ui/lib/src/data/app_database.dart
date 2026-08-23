/// DB の組み立て（決定 D45 / D55）.
///
/// ★★ `drift` に触れてよいのはこのファイルだけ ★★
/// `Variable` / `QueryRow` / `LovecaDatabase` が UI に漏れると、
/// Phase 5 の Web / WASM 経路で UI ごと巻き込む。
/// `loveca_db` が `QueryExecutor` を外から受け取る形にしてある努力
/// （`native.dart` の doc）を UI 側で台無しにしない。
///
/// ★★ executor は別 isolate で開く（決定 D45）★★
/// 検索 1 回だけなら UI isolate のほうが速いが、**決め手はコールド起動の取り込み**。
/// 1.8 秒の取り込みが UI スレッドで走ると画面はほぼ止まる（実測 約 20fps）。
///
/// ★`package:loveca_db/native.dart` の `openFileExecutor` は UI isolate 実行なので
/// **アプリ本体では使わない**（テストと使い捨ての検証向け / `native.dart:22-27`）。
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:loveca_db/loveca_db.dart';

/// DB を開き、スキーマの作成／移行をここで確実に走らせる。
///
/// ★★ `MigrationStrategy` は「最初のクエリ」で初めて走る ★★
/// `beforeOpen` の `PRAGMA foreign_keys = ON` と `onUpgrade`
/// （決定 D49 の索引建て直し）は遅延実行される。
/// `SELECT 1` を明示的に打っておかないと、移行の失敗が
/// **あとの無関係なクエリの例外として出てくる**。
/// 起動ゲートが「どの段で失敗したか」を言えるのは、ここで打っているからである。
Future<LovecaDatabase> openAppDatabase(File file) async {
  await file.parent.create(recursive: true);

  final db = LovecaDatabase(NativeDatabase.createInBackground(file));

  // ★ここで onCreate / onUpgrade / beforeOpen を走らせきる。
  await db.customSelect('SELECT 1').get();

  return db;
}
