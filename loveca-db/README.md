# loveca_db

ラブカ シミュレーターのローカル DB 層（drift / SQLite）。**Flutter に依存しない。**

`loveca_core`（ドメイン層）と Flutter アプリ（Phase 2 後半 / Phase 3b）の間に入り、
配信 JSON をローカル SQLite に落とし、カード検索とデッキ保存を提供する。

## なぜ Flutter から独立させるのか

`loveca_core` を Flutter 非依存に保つ理由（決定 D-D / D28）と同じ理由がここにも及ぶ。

- **`dart test` だけで検証できる。** Flutter 実機もエミュレータも要らない
- Phase 6 の権威サーバがカードマスタを引く必要が出たとき、そのまま使える

そのため次は**採らない**。

| 採らない依存 | 代替 |
|---|---|
| `drift_flutter` | `QueryExecutor` を呼び出し側から受け取る |
| `sqlite3_flutter_libs` | `sqlite3` パッケージのビルドフック（下記） |
| `path_provider` | DB ファイルのパスは呼び出し側が決めて渡す |

`dart:io` に触れるのは **`lib/native.dart` と `lib/src/native/` だけ**。
スキーマ層・DAO 層・取り込み層は `QueryExecutor` を受け取るだけなので、
Phase 5 で Web / WASM 経路を足すときはそちらを差し替えれば済む。

★`dart:io` 禁止は CLAUDE.md §1 が **`loveca_core` に対して**課している制約であり、
このパッケージには及ばない。それでも汚染範囲は最小に閉じてある。

## ネイティブ sqlite3 の調達

`sqlite3` 3.x は**ビルドフック（native assets）で SQLite 本体を自前調達する**。
`dart test` / `dart run` が自動で走らせるので、実験フラグも手動配置も要らない。

```
SQLite 3.53.4 (fts5: true, trigram: true)
```

**これが重要なのは、FTS5 の有無が実行環境ごとに変わる問題が構造的に消えるため。**
Windows 11 には素の `sqlite3.dll` が無く `C:\Windows\System32\winsqlite3.dll`
（SQLite 3.51.1）しか無い。あちらも実測では FTS5・trigram を持っていたが、
OS 更新で変わりうるものに検索機能の可否を預ける形になっていた。

診断:

```bash
cd loveca-db && dart run tool/probe_sqlite.dart
```

`assertSqliteCapabilities()` を起動時に呼ぶと、FTS5 が無い環境で
**スキーマ移行の中に埋もれる前に**原因の分かる形で落ちる。

## 実行

```bash
dart pub get
dart run build_runner build   # drift のコード生成（*.g.dart はコミットする）
dart test
```

★`dart test` の結果を報告するときは **skip 件数も併記すること。**
実データ（`loveca-data/data/dist/`）に依存するテストは、
`data/` が git 管理外のため未配置時に `markTestSkipped` で理由を明示して skip する。
「全通過」の報告に skip が埋もれると、検証しているつもりで検証していない状態になる。

実データのパスは環境変数で上書きできる。

```bash
LOVECA_DIST_DIR=/path/to/dist dart test
```

## リント

`analysis_options.yaml` で `package:lints/recommended.yaml` を接続してある。
★これは **決定 D-2 を前倒ししない。** D-2 は `loveca-core` の `StepId.s8_4_13` 形式の
enum 値名と `constant_identifier_names` の衝突が論点で、判断時期は Phase 3b と定められている。
`loveca-db` には条番号 ID を持つ enum が無いため、その論点は発生しない。
