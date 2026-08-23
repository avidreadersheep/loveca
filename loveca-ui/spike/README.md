# `spike/` — 技術検証の試作（決定 D51）

**ここは本実装ではない。** Phase 2 後半（UI）に着手する前に、
後回しにすると計画が崩れる論点を実測で潰すために書いたもの。

測定結果と判断は `docs/UI技術検証メモ.md`、
そこから生まれた決定は `docs/決定事項一覧.md` の **D42〜D50**。

---

## ★ `loveca-ui/` の中で扱いが違う

| 場所 | 扱い | 寿命 |
|---|---|---|
| `lib/` | **本実装。** Phase 2 後半のコードはここに書く | 恒久 |
| `windows/` | **本実装。** `flutter create` が生成したランナーで、製品の一部 | 恒久 |
| `pubspec.yaml` | **本実装。** 依存の正本 | 恒久 |
| **`spike/`（ここ）** | **検証用。** D42〜D50 の数値の再現手段 | **Phase 3b 完了時に削除を再判断** |
| `spike/.cache/` | DB ファイルと測定結果の出力先 | git 管理外 |

★**`lib/` から `spike/` を参照しない。**
`spike/` は `lib/` の外にあるので `package:loveca_ui/...` では届かない。
この配置は意図的なもので、崩さないこと。

---

## ★ 触る前に知っておくこと

### ここにはテストが無い。だから静かに腐る

`flutter analyze` は通るので**コンパイルは壊れない**が、
**計測している対象が実態と食い違っても誰も気づかない。**

実際に起きた例（決定 D49）:

> `main_search.dart` は `CardSearchDao.search` の内訳として
> 「`cards` の全件読み」を測っていた。D49 でその処理が `search()` から
> 消えたあとも、コードはそのまま動き、**もう検索に含まれない処理の時間を
> あたかも内訳であるかのように出し続けた。**
> 気づいたのは D49 を実装した本人が見直したからで、
> テストが教えてくれたわけではない。

**したがって次の規則を置く（決定 D51）。**

> **本実装の変更で spike の計測が意味を失ったら、その場で注記を直すか消す。**
> 「あとでまとめて」は効かない。次に読む人は、その数字が古いことを知らない。

上の例では、当該の列を「参考: 旧復元処理（D49 で廃止）」と改名し、
`search()` の実測値には含まれない旨をコードのコメントに書いた。

### なぜ残してあるのか

消すと **D42〜D50 の数値が検証不能な主張になる。**
「144Hz で予算 6.9ms」「`ResizeImage` で 25 フレーム落ちが 0 になる」
「検索 10.13ms → 0.74ms」はいずれも再現手順があってはじめて意味を持つ。

Phase 3b（盤面 UI）はドラッグ・重ね置きの知見を直接使うので、
再測定が要る可能性もある。**削除の再判断は Phase 3b 完了時に行う。**

---

## 走らせ方

計測は **profile ビルド**で行う。debug では数値が実態と離れる。

```bash
cd loveca-ui && flutter pub get
```

```bash
flutter run -d windows -t spike/main_probe.dart
```

`SPIKE_AUTOEXIT=1` を渡すと計測後に自己終了し、
結果が `spike/.cache/measurements/*.md` に出る。

```bash
flutter build windows --profile -t spike/main_grid.dart
```

```bash
SPIKE_AUTOEXIT=1 ./build/windows/x64/runner/Profile/loveca_ui.exe
```

| エントリポイント | 内容 | 出力 |
|---|---|---|
| `main_probe.dart` | sqlite3 の Flutter 経路の疎通 | `01_probe.md` |
| `main_grid.dart` | 試作1 仮想リスト | `02_grid.md` |
| `main_search.dart` | 試作2 検索 | `03_search.md` |
| `main_drag.dart` | 試作3-A デッキ編集 | `04_drag.md` |
| `main_board.dart` | 試作3-B 最小盤面 | `05_board.md` |
| `main_search_variants.dart` | 検索改善案の比較（D49 の判断材料） | `06_search_variants.md` |

**`--dart-define`**

| 定義 | 効果 |
|---|---|
| `LOVECA_DB_BACKGROUND=false` | executor を UI isolate 実行に切り替える（D45 の比較用） |
| `LOVECA_DIST_DIR=...` | 実データの場所を変える |
| `LOVECA_DB_FRESH=true` | キャッシュ DB を捨てて取り込み直す |

DB は `spike/.cache/loveca_spike.db` に作られ、2 回目以降は再利用される。
消せば作り直す。

---

## 触ってはいけないもの

- **`loveca-data/data/` は読むだけ。** 書き込み・移動・削除をしない。`fetch` を実行しない
- **画像をリポジトリにコミットしない**（`spike/.cache/` は git 管理外）
- `loveca_core` / `loveca_db` を試作の都合で変えない。
  必要が生じたら理由を報告してから（CLAUDE.md §7-5）
