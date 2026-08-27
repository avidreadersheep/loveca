# loveca-data — ラブカ カードデータ取得・正規化パイプライン

実装仕様書 v1.0 に基づく Phase 1-A の実装。

## 依存

取得・正規化・検証は **Python 3.10+ の標準ライブラリのみ**で動作します。
画像リサイズ（`build` の一部）にのみ Pillow が必要です。

```bash
python -m pip install Pillow   # 画像リサイズを行う場合のみ
```

## 実行前に必ず

1. **権利・利用規約は確認済みです（決定 D104 / 2026-08-27 時点）。**
   根拠は「**利用規約を確認し、専門家の確認を得た判断**」です。
   ★**「もう考えなくてよい」ではありません** ——
   **利用規約は改定されうるので、改定時は引き直しが要ります。**
   robots.txt で `/cardlist/` `/manage/` は Disallow されていませんが、
   **それは許可を意味しません**（この判断の前提であって、判断で消える話ではありません）。
   ★**下の「リクエスト規約」はこの判断で緩みません。**
2. `loveca_data/config.py` の `user_agent` を、**実在する連絡先**に書き換えてください。

## 使い方

```bash
# ★まず BP01 だけで一巡させ、V2/V3/V7 が通ることを確認する
python -m loveca_data fetch --expansion BP01
python -m loveca_data normalize
python -m loveca_data validate

# 検証が通ってから全商品に拡大
python -m loveca_data fetch --all
python -m loveca_data normalize && python -m loveca_data validate
python -m loveca_data build --data-version 1
```

### 画像リサイズについて

`build` の実行時に Pillow が無いと、**原本 PNG がそのままコピー**されます (数 GB になります)。
インストール後は `dist/images` を削除してから再実行してください。

```powershell
python -m pip install Pillow
Remove-Item -Recurse -Force data\dist\images
python -m loveca_data build --data-version 1
```

リサイズ後の目安 (2,527 枚): thumb 37MB / normal 148MB / large 494MB

**3,000件取ってから色マッピングの誤りに気づくのは、時間と相手サーバへの負荷の両方の無駄になります。**
必ず BP01 で止めて確認してください。

## ★取得データ (`data/`) の扱い

`data/` は**あなたのローカル資産**であり、配布 zip には含まれません。

新しいバージョンの zip を別の場所へ展開した場合、`data/` は前のフォルダに残っています。
**再ダウンロードせずに再利用してください。**

```bash
# 旧フォルダから data/ をコピーする、または
python -m loveca_data --data-dir "C:\旧フォルダ\data" validate
```

`data/` の場所が分からないとき (PowerShell):

```powershell
Get-ChildItem -Path C:\ -Filter "search_form.json" -Recurse -ErrorAction SilentlyContinue |
  Select-Object -First 5 FullName
```

**更新時は zip を上書き展開するのが最も安全です。** `data/` は zip に無いので消えません。

## 診断コマンド

```bash
python -m loveca_data stats        # データの統計 (種別/パラレル/商品/色分布…)
python -m loveca_data expansions   # 商品コードと検索フォームの構造
```

どちらもネットワークを使いません。
`stats` の「推定になった刷りのカード種別」に**エネルギー以外が出たら要確認**です。

## ディレクトリ

```
data/
  raw/          ← ここだけが公式サイト由来。取得は1回きり
    search_form.json
    list/{EXP}_{page}.json
    detail/{id}.json
    images/{picture}
  normalized/   ← 正規化結果（raw のみを入力とする。何度でも再実行可）
  dist/         ← 配信物（version.json / manifest.json / cards/ / meta/ / images/）
```

**取得と正規化を分離してあります。** 正規化ロジックを何度直しても公式サイトを再度叩きません。

## リクエスト規約

| 項目 | 値 |
|---|---|
| 並列度 | 1（直列のみ） |
| 間隔 | 1.5 秒 |
| リトライ | 指数バックオフ 最大3回 |
| 連続失敗 | 5回で自動停止 |
| per_page | 100（これ以上増やさない） |
| 再実行 | 取得済みファイルはスキップ（中断しても再開可） |

## テスト

```bash
python tests/test_normalize.py
```

実際の BP01 レスポンスを使って、フィールド分岐と色マッピングを検証します。

## ★実装上の最重要事項

### 1. フィールド名を信用しない

CMS の汎用カラム流用により、名前と中身が乖離しています。

| フィールド | メンバー | ライブ |
|---|---|---|
| `cost` | コスト | ブレードハート（推定） |
| `heart`/`heartNN` | 基本ハート | 必要ハート |
| `attack` | ブレード（数値） | ブレードハート |
| `blade_heart` | ブレードハート | **スコア** |

### 2. 色マッピングは3系統あり、共用してはいけない

系統A（`heartNN`）と系統B（`heart_NN.png`）は **02/03/04/05 が食い違います**。
効果テキストのアイコン置換に系統Aを使うと、カードテキストの色表示が全件誤ります。

### 3. エネルギーカードは detail を取得しない

性能差が無いため `detail` はスキップし、`list` の情報だけで正規化します。
必要な情報（cardNumber / 名前 / 画像 / レアリティ / 収録商品）は list で揃います。
画像は取得します（デッキ構築の絵柄選択・盤面表示に必要）。

全商品でおよそ 500 リクエストの削減になります。

### 4. パラレル判定は「刷り単位」であって「cardNumber ごとの代表 1 枚」ではない

同じカードが複数商品に再録されると、**通常刷りが複数になります**。

```
PL!N-bp1-019-N  (ブースター) と PL!N-bp1-019-PR  (プロモ再録)
PL!N-sd1-001-SD と PL!N-sd1-001-SD2 (スタートデッキ 2 種)
LL-E-002-PR     と LL-E-002-SD
```

公式サイトの `parallel=normal` 検索もこの全てを返します。
**パラレル表示 OFF = `isParallel == false` の刷りを「すべて」表示する**、が正しい挙動です。

`parallel_param` はこの判定に使えません
(レアリティ P/P+/SEC/PE/PE+ で非空、R/R+/N/L/LLE/SECE で空となる別物)。生値のみ保持しています。

エネルギーカードは公式の `parallel` フィルタで返らないため、
レアリティ表記から推定します (`+` を含むもの・`SEC` 系をパラレル扱い)。
これは推定なので `parallelSource: "rarity_guess"` として記録し、検証で件数を報告します。

### 5. 表記ゆれを正典表記に統一する

実データに全角/半角の混在がある。

```
みらくらぱーく！ (30種) と みらくらぱーく! (20種)   ← 同じユニットが分裂
P+ (146件) と P＋ (11件)                          ← レアリティ
```

グループ名・ユニット名は**総合ルール付録 A の表記**に寄せ、レアリティは NFKC で半角に統一する。
未知の名前は勝手に変えない (新作品・新ユニットを壊さないため)。

検証 V13 が残存する表記ゆれを検出する。

### 6. 画像URLを組み立てない

```
PL!N-bp1-034-PE＋ → PL!N-bp1_034-PE2.png    ハイフンがアンダースコア
PL!N-bp1-999-SEC＋ → SEC2-PL!N-bp1-999-SEC2.png  接頭辞つき
```

`picture` フィールドの実値をそのまま使ってください。
