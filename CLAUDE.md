# ラブカ シミュレーター — 作業指示書

> このファイルは Cowork の「フォルダ指示（Folder instructions）」および Claude Code の
> プロジェクト指示として読まれる。セッションを跨いで前提を引き継ぐための唯一の入口。
> **`★` の項目は実データで前提が覆された経緯がある。安易に変更しないこと。**

---

## 0. このプロジェクトは何か

ラブライブ！シリーズ オフィシャルカードゲーム（通称「ラブカ」）の
**非公式シミュレーターアプリ**。個人利用・非商用の範囲で開発する。

```
カードを検索できる → デッキを作れる → 一人回しできる → オンライン対戦できる
```

| | Windows (PC) | iOS / Android |
|---|---|---|
| カードリスト・検索・デッキ構築・同期 | ○ | ○ |
| ゲーム盤面（一人回し・対戦） | ○ | **×** |

---

## 1. 絶対に変更しない設計方針

### ★ カード効果の自動処理は実装しない

ルールエンジンによる効果の自動解決・誘発効果の自動発動・効果テキストの構文解析は**一切行わない**。
紙のカードと同じように、プレイヤー自身が判断して手動操作する。
アプリは「盤面・カード・山札・手札をデジタル上で操作するサンドボックス」である。

**実装してよいのは物理操作の補助のみ**：引く / シャッフル / 移動 / 上から見る /
表裏の反転 / 横向き / 重ね置き / 選択。

### ★ ルールに触れるコードには必ず総合ルールの条番号をコメントで併記する

```dart
// 総合ルール 8.3.10: ブレード合計は「アクティブ状態のメンバー」のみ
```

根拠のない数値・条件をコードに書かない。参照元は `docs/LoveLiveTCG_cr_1.06_260428.pdf`（ver 1.06）。

★**`docs/` の公式 PDF は git 管理外**（ブシロードの著作物）。クローン直後は各自で配置する。本文の抽出は `python docs/tools/extract_rules.py`。

### ★ `loveca_core` に Flutter / 日時 / 乱数 / IO を持ち込まない

純粋 Dart パッケージとして維持する。理由は 2 つ。
1. デッキ検証が二重実装になると「スマホでは合法、PC では不正」という事故が起きる
2. Phase 6 の権威サーバが同じ `reduce` / `redact` をコピーゼロで再利用する

**禁止する依存**：

| 禁止 | 理由 |
|---|---|
| `package:flutter` / `dart:ui` | 上記のとおり。サーバとスマホで共有できなくなる |
| `dart:io` | 同上。サーバ・Web・テストで挙動が割れる |
| **`DateTime.now()`** | 同じ入力から同じ結果が出なくなる。時刻は呼び出し側から渡す |
| **`Random()`（seed なし）** | 同上。**乱数は `DeterministicRng` 抽象を注入する** |

★禁止するのは**非決定な呼び出し**であって型ではない。
`DateTime` を値として持つのは可（`Deck` の `createdAt` / `updatedAt` は同期に要る）。

★**乱数はシャッフル（10.2.3）に要るが、実装を埋め込まない。**
`DeterministicRng` を注入して seed 再現性を確保する。理由は 2 つ。
(1) 同じ seed で盤面を再現できないと不具合を追えない。
(2) Phase 6 の権威サーバがシャッフル結果の権威を持つ必要がある。

★**既知の違反が 1 箇所ある。**
`loveca-core/lib/src/entities/deck.dart` の `Deck.copyWith` が
`updatedAt` の既定値に `DateTime.now().toUtc()` を使っている。
Phase 2 で入れたもので、Phase 4（同期）の設計時に呼び出し側から渡す形へ直す。
**新しいコードでこれを真似しないこと。**

検証：

```bash
grep -rnE "package:flutter|dart:ui|dart:io|DateTime\.now|Random\(\)" loveca-core/lib
```

`loveca_db` は Flutter 非依存だけを課す（`dart:io` は `lib/native.dart` と
`lib/src/native/` に閉じる）。

```bash
grep -rnE "package:flutter|dart:ui" loveca-db/lib          # 0 件であること
grep -rln "^import 'dart:io'" loveca-db/lib            # native 配下のみ
```

---

## 2. ディレクトリ構成

```
loveca-data/     Python: カードデータ取得・正規化パイプライン（開発者ツール）
  loveca_data/   config / constants / http_client / fetch / normalize / validate / build_dist / stats / cli
  tests/         run_all.py / test_imports.py / test_normalize.py
  data/          ★ローカル資産。zip に含まれない。絶対に消さない
    raw/         生レスポンス（取得は 1 回きり）
    normalized/  normalized.json
    dist/        配信物（version / manifest / cards/*.json / meta / images）

loveca-core/     Dart: ドメイン層（Flutter 非依存）
  lib/src/entities/   card.dart / deck.dart / product.dart
  lib/src/master/     master_data.dart（配信 JSON パース・差分更新の計画）
  lib/src/rules/      deck_validator.dart
  lib/src/game/       GameState / 集計 / フェイズ進行 / 巻き戻し / reduce / redact
  test/fixtures/      Python が実際に生成した JSON のコピー
  tools/verify_contract.py   Python↔Dart のキー整合検証（Dart SDK 不要）

loveca-db/       Dart: ローカル DB 層（drift / SQLite。★Flutter 非依存）
  lib/loveca_db.dart      スキーマ・DAO・取り込み層。dart:io を含まない
  lib/native.dart         ★dart:io に触れるのはこのエントリの下だけ
  lib/src/schema/         drift のテーブル定義とコード生成物
  lib/src/dao/            Card / Deck / 取り込み状態の読み書き
  lib/src/search/         fold（表記ゆれ折りたたみ）/ FTS5(trigram) 検索
  lib/src/import/         MasterFileSource / MasterImporter（planUpdate を使う）
  test/fixtures/dist/     ミニ配信物。tool/build_fixtures.py が実データから生成
  tool/build_fixtures.py  ★相互にハッシュ参照するので一括生成する
  tool/probe_sqlite.dart  解決された sqlite3 の診断（FTS5 / trigram の可否）

loveca-ui/       Flutter: UI 層（Windows デスクトップ）
  lib/           ★Phase 2 後半の本実装用。まだ空（placeholder の main.dart のみ）
  spike/         ★技術検証の試作。本実装と混ざらないよう lib/ の外に置く
    common/      DB 起動 / 計測 / 合成ポインタ / パス解決
    main_probe.dart   sqlite3 の Flutter 経路の疎通
    main_grid.dart    試作1 仮想リスト
    main_search.dart  試作2 検索
    main_drag.dart    試作3-A デッキ編集
    main_board.dart   試作3-B 最小盤面
  spike/.cache/  ★DB ファイルと測定結果。git 管理外
  windows/       flutter create が生成したランナー
```

★`loveca_db` は Flutter に依存させない。`drift_flutter` / `sqlite3_flutter_libs` /
`path_provider` は採らず、`QueryExecutor` を呼び出し側から受け取る。
`dart test` だけで検証できる状態を保つことが目的で、Phase 6 のサーバでも使える。
`dart:io` 禁止は **`loveca_core` に対する制約**であり `loveca_db` には及ばないが、
汚染範囲は `lib/native.dart` と `lib/src/native/` に閉じてある。

---

## 3. コマンド

```bash
# Python 側（取得・正規化・検証は標準ライブラリのみで動く）
cd loveca-data
python tests/run_all.py                       # テスト（ネットワーク不要）
python -m loveca_data stats                   # 統計（ネットワーク不要）
python -m loveca_data normalize               # 段階4（ネットワーク不要）
python -m loveca_data validate --complete     # 段階5（ネットワーク不要）
python -m loveca_data build --data-version 1 --skip-images   # 段階6（JSON のみ・数秒）
python -m loveca_data fetch --all             # ★段階0-3: 公式サイトへ実アクセス

# Dart 側（ドメイン層）
cd loveca-core
dart test
dart analyze                                  # ★テストでは検知できない指摘が出る
python tools/verify_contract.py               # Dart SDK 不要

# Dart 側（DB 層）
cd loveca-db
dart pub get
dart run build_runner build                   # drift のコード生成（*.g.dart はコミットする）
dart test
dart analyze                                  # ★同上
dart run tool/probe_sqlite.dart               # sqlite3 の FTS5 / trigram の可否
LOVECA_DIST_DIR=/path/to/dist dart test       # 実データの場所を変える
../loveca-data/.venv/Scripts/python.exe tool/build_fixtures.py   # ミニ配信物の再生成

# Flutter 側（UI）。★計測は profile ビルドで行う
cd loveca-ui
flutter pub get
flutter analyze
flutter run -d windows -t spike/main_probe.dart      # sqlite3 経路の疎通確認
flutter build windows --profile -t spike/main_grid.dart
SPIKE_AUTOEXIT=1 ./build/windows/x64/runner/Profile/loveca_ui.exe  # 計測して自己終了
```

★`loveca_ui` は `sqlite3_flutter_libs` を採らない（決定 D45 の詳細・
`docs/UI技術検証メモ.md` §1-2）。`sqlite3` のビルドフックがそのまま Flutter でも働き、
FTS5 / trigram つきの SQLite 3.53.4 がバンドルされることを実測で確認済み。
採ると SQLite が二重調達になり、どちらを掴んだか分からなくなる。

★**`dart test` はリントもアナライザも走らせない。** `dart analyze` を別に流すこと。
テストが全通過していても指摘は検知されない（`ルール整合性チェック_v1.06.md` D-2）。

### ★ テスト件数の正はここ

**他の文書に書かれた件数は執筆時点のスナップショットであり、参照に留める。**
食い違ったらこの表を優先し、この表が古ければここを直す。

| パッケージ | 件数 | 確認コマンド |
|---|---|---|
| `loveca-data`（Python） | 33 | `python tests/run_all.py` |
| `loveca-core`（Dart） | 255 | `dart test` |
| `loveca-db`（Dart） | 117（★skip 0） | `dart test` |

（2026-08-23 時点。`loveca-ui` は試作のみでテストを持たない）

★`loveca-db` のテスト結果を報告するときは **skip 件数も併記すること。**
実データ（`loveca-data/data/dist/`）を使うテストは `data/` が git 管理外のため、
未配置なら `markTestSkipped` で理由を明示して飛ばす。
「全通過」の報告に skip が埋もれると、検証しているつもりで検証していない状態になる。

**`fetch` は明示的な指示がない限り実行しない。** 公式サイトへの実アクセスを伴う。

---

## 4. 公式サイトへのアクセス制約（絶対に緩めない）

| 項目 | 設定 |
|---|---|
| 並列度 | 1（直列のみ） |
| 間隔 | 1.5 秒 |
| リトライ | 指数バックオフ 最大 3 回 / 連続 5 回失敗で自動停止 |
| `per_page` | 100（増やさない） |
| User-Agent | 素性と連絡先を明記 |
| 実行頻度 | 新商品発売時のみ。定期巡回しない |

取得と正規化は完全に分離してある。**正規化ロジックを何度直しても公式サイトを再度叩かない。**

---

## 5. ★ 実データで判明した落とし穴

### (1) API のフィールド名を信用しない

公式 API は CMS の汎用カラムを流用しており、名前と中身が乖離している。
**`card_kind` による分岐が必須。**

| JSON フィールド | メンバー | ライブ |
|---|---|---|
| `cost` | コスト | ブレードハート（の一部） |
| `heart` / `heartNN` | 基本ハート | **必要ハート** |
| `attack` | ブレード（数値） | **ブレードハート** |
| `blade_heart` | ブレードハート | **スコア** |

### (2) 色マッピングが 3 系統あり、共用してはいけない

```
系統A（heartNN フィールド）: 01桃 02赤 03黄 04緑 05青 06紫
系統B（heart_NN.png 画像）  : 01桃 02緑 03青 04赤 05黄 06紫   ★A と 02/03/04/05 が食い違う
系統C（日本語文字列）        : 桃/赤/黄/緑/青/紫/無/ALL
```

効果テキストのアイコン置換に系統 A を使うと**カードテキストの色表示が全件誤る**。
公式の `meta.text_icons` 自体にバグがある（黄と緑が同じファイルを指す）。
`meta` は実行時に信用せず、新アイコン検知にのみ使う。

### (3) 画像 URL を組み立ててはいけない

```
PL!N-bp1-034-PE＋  → PL!N-bp1_034-PE2.png        ハイフンがアンダースコア
PL!N-bp1-999-SEC＋ → SEC2-PL!N-bp1-999-SEC2.png  接頭辞つき
```

`picture` フィールドの実値をそのまま使う。

### (4) パラレル判定は「刷り単位」

同じカードが複数商品に再録されると**通常刷りが複数になる**。
`isParallel`（刷り単位）が正。`isBasePrinting`（cardNumber ごとに代表 1 枚）という概念は**誤りとして廃止済み**。
`parallel_param` は基本刷りフラグではない（実測で否定済み）。判定は公式検索 `parallel=normal` の集合で行う。

**パラレル表示 OFF = `isParallel == false` の刷りを「すべて」表示する。**

### (5) 表記ゆれが実データ内に存在する

`みらくらぱーく！`（全角）と `みらくらぱーく!`（半角）が分裂していた。
グループ名・ユニット名は総合ルール付録 A の表記に寄せ、レアリティは NFKC で半角統一。
**未知の名前は勝手に変えない**（新作品・新ユニットを壊さないため）。

### (6) カード番号の切り出しはホワイトリスト化しない

```python
printing_id = unicodedata.normalize("NFKC", card_number).strip()
card_number = printing_id.rsplit("-", 1)[0]
```

`PRproteinbar` のような公式レアリティ一覧に無い接尾が実在する。機械的な `rsplit` に徹する。

### (7) 同じ意味を公式が複数の書き方で入れてくる

数値やトークンのパースで**数字や括弧を必須にしない**。実測の内訳：

| 意味 | 実在する書き方 |
|---|---|
| ブレードハートのドロー | `ドロー1` 24 刷り / `ドロー` 48 刷り / `[ドロー]` 3 刷り |
| ブレードハートのスコア | `スコア1` 19 刷り / `スコア` 27 刷り / `[スコア]` 1 刷り |
| ALL のブレードハート | `ALL1` / `[全ブレード]`（パラレル刷りのみ 5 刷り） |
| ターン 1 回 | `[ターン1回]` 271 刷り / `［ターン1回］` 全角 9 刷り |

数字必須の正規表現だったため 59 種でブレードハートが、
半角括弧のみの照合だったため 4 種で `TURN_1` が無言で欠落していた。
**色は例外で、5,367 刷り分すべてが数字を伴っていた。**

さらに**同一 cardNumber でも刷りごとに書き方が揺れる**。
`PL!-bp4-022` は `-L` が `スコア`、`-SECL` が `スコア1`。
`normalize_all` は先勝ちなので、壊れた刷りが勝つと丸ごと落ちる。V15 がこれを検出する。

---

## 6. ★ 集計で最も間違えやすい点（Phase 3a の核心）

```
ブレード合計 = メンバーエリアの「アクティブ状態のメンバー」のブレード     （8.3.10）
ハート合計   = メンバーエリアの「全メンバー（ウェイト含む）」のハート      （8.3.14）
エールハート = 共有解決領域の「ownerId == 自分」のカードのブレードハート （8.3.14）
```

**参照範囲が違う。** ウェイト状態のメンバーからはブレードを参照できない。

解決領域は**両プレイヤー共有で 1 つだけ**（4.14.1）。先攻パフォーマンス後も先攻のエールカードが
残ったまま後攻パフォーマンスに入るため、`ownerId` での絞り込みが必須。

ブレードハートには色以外のアイコンがあり、**配信 JSON では色と別フィールドに分かれている**。

```jsonc
"bladeHearts":       { "BLUE": 1 },   // 8.3.14 のハート合計に合算するのはこちらだけ
"bladeHeartEffects": { "DRAW": 1 }    // 合算しない
```

- ドローアイコン → カードを 1 枚引く（8.3.12.1）。**ハート集計 8.3.14 より前**
- スコアアイコン → スコア合計に +1（8.4.2.1）

★同じ `Map<HeartColor,int>` に同居させ直さないこと。
参照範囲も処理する時点も違うため、型で分けておかないと集計で取り違える。
実在数は DRAW 59 種 / SCORE 37 種で、**いずれもライブカードのみ**（メンバーには 1 件も無い）。

---

## 7. 作業ルール

1. **`data/` を消さない・移動しない。** コード更新は既存フォルダへの上書き展開で行う。
2. **コードを編集したら `python tests/run_all.py` を必ず実行する。**
   過去にパッチ適用で関数 7 つが消失した事故があり、`test_imports.py` はその再発検知が目的。
3. **`dist` を再生成したら必ず `verify_contract.py` を通す。**（形式を変えたときだけではない）
   `loveca-core` の `HeartColor.fromKey` / `BladeHeartEffect.fromKey` は未知キーで例外を投げる。
   この厳格さは「配信前に門番が毎回機能すること」が前提で成立している。
   終了コード **2 は「dist が無く限定検査しかしていない」** の意味であり、成功ではない。
   `test/fixtures/` は相互にハッシュ参照するミニ配信物なので、1 ファイルだけ直すと壊れる。一括で更新する。
   なお `build --skip-images` は **`imageHash` も空になる**（画像を読まないため）。
   配信物として使う dist を作るときは `--skip-images` を付けない（`requirements.txt` の Pillow が要る）。
4. **1 コミット = 1 論点。** 複数の修正を混ぜない。
5. 判断に迷う点は勝手に決めず、選択肢と根拠（条番号つき）を提示して確認を取る。
6. 権利・利用規約に関わる論点は `【要確認/法務】` と明記し、技術的可否と法的可否を分けて書く。

---

## 8. 現在のフェーズ

| フェーズ | 状態 |
|---|---|
| Phase 1-A データパイプライン（Python） | **完了**（1,708 種 / 2,527 刷り / 検証エラー 0。Python テストで担保） |
| Phase 1-B `loveca_core` エンティティ・DeckValidator | **完了**（`loveca-core` の **Dart** テストで担保。件数は §3 の表） |
| Phase 2 PC ローカル DB・カードリスト・デッキ構築 | **着手中**（第一段階: drift スキーマ + マスタ取り込み層 = 完了。UI 着手前の技術検証 = 完了 / `docs/UI技術検証メモ.md`。検索の改善と移行機構 = 完了 / D49・D50） |
| Phase 3a GameState / 集計 / 進行 / 巻き戻し / reduce・redact | **完了**（`loveca-core` の Dart テストで担保。件数は §3 の表） |
| Phase 3b PC 盤面 UI | 未着手（★転用可否は検証済み。`docs/UI技術検証メモ.md` §7） |
| Phase 4 認証・同期 / Phase 5 スマホ / Phase 6 対戦サーバ | 未着手 |

Dart SDK は導入済み（3.11.1 stable / Flutter 3.41.4）。
Python は **`loveca-data/.venv/Scripts/python.exe`（3.13.12）を使う**。
Git Bash の `python` は MSYS2 の 3.14.3 を掴むため使わない。

**次の一手**: Phase 2 後半（UI 本実装）。`loveca-ui/lib/` に書く。
実装方針は決定 D42〜D48 で確定済みなので、そこから外れる場合は理由を示すこと。
`loveca-ui/spike/` は検証用であり、**本実装から参照しない。**

決定事項の参照先は `docs/決定事項一覧.md`（`決定 DNN` / `決定 D-X` の実体）。
**新しい決定は D49 以降を使う（D36〜D48 は使用済み）。** 未記録番号を再利用しないこと。

### ★ ルール整合性チェックの未決項目

`ルール整合性チェック_v1.06.md` には **B-1〜B-4** があり、**B-2 と B-4 は未決のまま**。
着手フェイズから辿れないと見落とすのでここに再掲する。

| # | 論点 | 状態 | いつ判断するか |
|---|---|---|---|
| B-1 | フェイズ構成 | **確定**（リーフフェイズ 12 個） | 済 |
| **B-2** | **エネルギーデッキは「順番が管理されない」**（4.9.2 と 6.2.1.7 / 7.5.2 の食い違い）。提案は `DeterministicRng` による無作為 1 枚抽出 | **未決** | Phase 3b でエネルギー操作を実装するとき |
| B-3 | 重ね置きの解消先 | **確定** | 済 |
| **B-4** | **ポジションチェンジ / フォーメーションチェンジ**（11.10 / 11.11）。キーワード能力ではなく効果テキスト中の動詞なので `KEYWORD_TOKENS` に無いのは正しい。ただし**盤面 UI に補助コマンドがあると実用性が大きく変わる**。効果の自動処理ではなく物理操作の補助なので D-A に抵触しない | **未決** | **Phase 3b（盤面 UI）着手時** |

★**B-4 は Phase 3b の論点である。** 盤面 UI に着手するときは必ず読むこと。

B-1（フェイズ構成）と B-3（重ね置きの解消先）は**確定済み**。根拠と設計は
`docs/PhaseEngine設計メモ.md` を参照する。要点だけ再掲する。

- **リーフフェイズは 12 個**（7.1.2 / 7.3.3 / 8.1.2）。★**過去に書いていた「13 フェイズ」は誤記**
- 8.4.13（先攻入れ替え）と 8.4.14（ターン終了）は**ライブ勝敗判定フェイズ 8.4 の内部手順**であり、
  フェイズではない。フェイズの下に**条番号をそのまま ID とするステップ層**を持つ
- フェイズはロール（先攻/後攻）で定義し、実プレイヤーは `firstPlayerId` から解決する。
  8.4.13 で入れ替わるため、**フェイズに実プレイヤー ID を埋めない**
