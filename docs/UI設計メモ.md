# UI 設計メモ — Phase 2 後半（UI 本実装）の設計

位置づけ: `docs/UI技術検証メモ.md`（D42〜D51）が答えた「どう描くか」の**上位にある設計論点**への回答。
決定の実体は `docs/決定事項一覧.md` の **D52〜D58**。この文書はその根拠と細部を置く。
作成日: 2026-08-23

この文書が答えるのは 5 つ。

1. 画面構成と優先順位（§2）
2. 状態管理の方針（§3）
3. `loveca_db` との境界（§4）
4. 画像の供給方法（§5）
5. 試作（`spike/`）の知見の持ち込み方（§6）

★**この文書を書いた時点で `loveca-ui/lib/` は placeholder の `main.dart` だけ。**
記述はすべて設計であり、実測ではない。実測は `docs/UI技術検証メモ.md` にしかない。
**両者を混ぜて読まないこと。**

---

## 0. 確定事項サマリ

| 論点 | 結論 | 決定 | 根拠 |
|---|---|---|---|
| モバイル（Android / iOS） | **設計だけ通す。実装・検証は PC のみ** | D52 | §7 |
| 状態管理 | **パッケージを入れない。`ValueNotifier` ベースの自前 Store** | D53 | §3 |
| 非同期の 3 状態 | **sealed `Loadable<T>`。エラーを既定で画面に出す** | D53 | §3-3 |
| 画面 | **6 ルート + 3 ペイン/ダイアログ。器を幅で切り替える** | D54 | §2 |
| 実装順 | M1 土台+一覧 → M2 デッキ往復 → M3 検索 → **M4 で骨格が通る** → M5 → M6 | D54 | §2-4 |
| `loveca_db` との境界 | **リポジトリ層を挟む。UI から DAO を直接呼ばない** | D55 | §4 |
| `DeckValidator` の材料 | **起動時に 1 回だけ組み、セッション中は不変** | D55 | §4-3 |
| マスタ取り込み | **起動ゲートでのみ走らせる。実行中は走らせない** | D56 | §4-4 |
| 画像 | **`CardImageSource` の背後に閉じる。thumb + normal のみ（large は使わない）** | D57 | §5 |
| キャッシュ無効化 | **content-addressed なファイル名に委ね、無効化処理を書かない** | D57 | §5-3 |
| spike の知見 | **文書ではなく型で守る。ウィジェットテストで固定する** | D58 | §6 |
| DB ファイルの置き場 | **`path_provider` の `getApplicationSupportDirectory()`。`loveca-ui` にだけ入れる** | D59 | §4-6 |
| dist の場所 | **環境変数 → `settings.json` → 実行ファイルの隣の既定、の 3 段。不在時は段 3 で検出し段 4 で続行可否を決める** | D60 | §4-6 |
| 設定の永続先 | **自前の JSON。`shared_preferences` は採らない** | D60 | §4-6 |
| ペインの切替 | **840 論理px。★暫定値で、M4 と Phase 5 で見直す** | D61 | §2-1 |

★**最も重要なのは §4-4 と §6-1。**
前者は「無効化漏れが起きうる構造を作らない」ための制約、
後者は「知っている人しか守れない知見」を型に落とす方針で、
どちらも守らないと **A-3 型（痕跡を残さずデータを落とす）の不具合**が新設される。

---

## 1. 前提

### 1-1. Release 1 の範囲

**Release 1 = デッキ構築**（PC / Android / iOS）。盤面は Phase 3b で PC 専用（CLAUDE.md 冒頭の表）。

| | Windows (PC) | iOS / Android |
|---|---|---|
| カードリスト・検索・デッキ構築 | **Release 1** | **Release 1** |
| ゲーム盤面 | Phase 3b | **対象外** |

★**Phase 2 後半で実装・検証するのは PC だけ**（決定 D52 / §7）。
モバイルは**通路を設計で確保するに留め、実機検証は Phase 5 に残す。**

### 1-2. ★ 引き継ぎ資料は git 管理外で検証できない

**以降の設計はリポジトリ内の記述のみを根拠とする。**

`引き継ぎドキュメント.md` は git 管理外（未追跡）であり、リポジトリに存在しない。
本タスクの依頼にあった「画面 9 本を想定していた」という前提も**リポジトリ内で確認できない。**
したがって §2 の画面構成は **9 本という数に合わせにいかず**、
Release 1 の能力から導き直した結果を示す（結果として 9 になったが、それは帰結であって前提ではない）。

★**この検証不能性そのものが記録に値する。**
`ルール整合性チェック_v1.06.md` D-3 で「A-3 節が無いまま参照されていた」のと同じ構造であり、
`docs/決定事項一覧.md` §0 が `決定 D11` の参照先不在について書いたのと同じ問題である。

#### 同種の未解決参照の洗い出し（2026-08-23 時点）

リポジトリ全体を走査した結果、**解決先の無い外部参照が 4 系統・19 箇所**（手書き）あった。
`decision D1〜D35` の欠番（`決定事項一覧.md` §3 に記録済み）はこれとは別に既知。

| 系統 | 箇所数 | 実例 |
|---|---:|---|
| `設計書 STEP N §N.N` | **7** | `loveca-core/lib/src/entities/card.dart:3` /`deck.dart:3` / `product.dart:3` / `master/master_data.dart:3` / `rules/deck_validator.dart:3` / `loveca-data/loveca_data/build_dist.py:3` |
| `M44`（設計書の項目番号） | 1（上記に含む） | `loveca-core/lib/src/entities/deck.dart:140` |
| `P1`〜`P5`（同期設計の番号） | **10** ★別に生成物 `database.g.dart` に 4 | `deck.dart:52,63,66,70` / `loveca-db/.../tables.dart:246,255,258,262` / `dao/deck_dao.dart:118` / `docs/決定事項一覧.md:324` |
| `U1`（引き継ぎ資料の未解決課題番号） | **2** | `loveca-data/loveca_data/normalize.py:375` / `ルール整合性チェック_v1.06.md:74` |

★**いずれも参照先がリポジトリに無い。**

このうち **`P1`〜`P5` だけは判断が要る。**
参照先が `deckId` / `revision` / `deletedAt` / `masterDataVersion` ——
**Phase 4（同期）の中核**であり、`deck.dart` と `tables.dart` から
P1・P2・P3・P5 の内容は読み取れるものの **`P4` は手がかりが 1 つも無い。**
→ **`ルール整合性チェック_v1.06.md` D-5【Phase 4 の着手前に判断】** に記録した。

`設計書 STEP N` / `M44` / `U1` は「対応関係の記録」または内容が
A 節へ取り込み済みで、**判断は要らない。**

★いずれにせよ**推測で埋めない**
（`決定事項一覧.md` §0「★推測で埋めないこと」と同じ扱い）。

**この文書は新しい参照体系を増やさない。**
`docs/UI設計メモ.md` の節番号と `決定 DNN` だけを使う。

### 1-3. 調査で確定した事実

#### (1) `manifest.json` に画像は 1 件も載っていない

| | 実測 |
|---|---|
| `manifest.json` の `files` | **25 件**（`cards/*.json` 22 + `meta/*.json` 3） |
| うち画像 | **0 件** |

したがって `planUpdate`（差分更新の計画）は**画像を一切知らない**。
画像の版管理は `Printing.imageHash` だけが担っている。

#### (2) `imageHash` は原本 PNG のハッシュ

```python
image_hash = _sha256(src.read_bytes())[:32]   # loveca-data/loveca_data/build_dist.py:59
```

`src` は `raw/images/` の原本 PNG。**配信される WebP のハッシュではない。**
§5-4 でこの帰結を扱う。

#### (3) 別 isolate（D45）が移すのは SQL の実行だけ

`NativeDatabase.createInBackground` が別 isolate へ移すのは SQL の実行であり、
**行→エンティティの写像は呼び出し側（UI isolate）で走る。**
drift 自身が `computeWithDatabase` を「クエリ構築や結果処理が重いときの逃げ道」として説明している
（`drift-2.34.3/lib/src/runtime/api/db_base.dart:201-210`）。

これは `UI技術検証メモ.md` §2 の実測と整合する。

| 経路 | 実測 |
|---|---:|
| 表示列だけの JOIN（2,527 行） | 11〜15 ms |
| `CardDao` で `Card` / `Printing` を全件実体化 | **40〜60 ms** ← 写像コスト |

★**`DeckDao.validate()` / `canAdd()` は呼ぶたびに `cardsByNumber()` + `printingsById()` を引き直す**
（`loveca-db/lib/src/dao/deck_dao.dart:232-251`）。
UI からセルごとに `canAdd` を呼ぶと **40〜60 ms × 呼び出し回数**が UI isolate で走る。
§4-3 でこれを塞ぐ。

#### (4) D48 が要求する投影は `loveca_db` の公開 API に無い

「表示に要る列だけを引く」経路は `spike/common/card_grid_data.dart` にしか無い。
D51 により流用しないため、本実装側に書き直す先が要る（§4-2 / §4-5）。

---

## 2. 画面構成と実装順（決定 D54）

### 2-1. ★ 画面ではなく「ペイン」で設計する

Release 1 が PC とモバイルを同時に要求するため、**同じ機能が違う器に入る。**

| | PC | モバイル |
|---|---|---|
| デッキ編集 | 一覧・デッキ・検証を**同時に 3 ペイン** | タブ／ボトムシートで**1 ペインずつ** |
| カード詳細 | 一覧の隣のペイン | **別ルート** |

★**同じ Widget を器だけ替えて置く。ルートを増やして分岐させない。**
切替の判断点は `PaneScaffold` **1 箇所**に閉じる。
判断点が散ると「PC では直したがモバイルでは直っていない」が起きる。

#### ★ ブレークポイントは **840 論理px**（決定 D61 / ★暫定値）

`PaneScaffold` は**しきい値を 1 つだけ**持つ。`maxWidth >= 840` で 2 ペイン、下回れば 1 ペイン。

**根拠（2 つ。片方は見積りである）**

| # | 根拠 | 格 |
|---|---|---|
| (a) | Material 3 の window size class の **expanded 境界が 840dp**。Flutter の `MediaQuery` の論理px は dp と一致する | **外部の標準。確か** |
| (b) | R3 が 2 ペインで成立する最小幅の見積り: 一覧 3 列（3 × 140 + 間隔 ≈ **450**）+ デッキペイン（**≈ 320**）+ 余白 ≈ **800**。これを上回る最小の標準値が 840 | ★**見積り。実測ではない** |

★★**(b) のデッキペイン 320 は実測値ではない。**★★
本実装のデッキ行の寸法はまだ決まっていない（P3 のメタ編集や検証パネルの同居も未確定）。
したがって **840 は暫定値である。**

**見直す時点は 2 つ。**

1. **M4（R3 の実装時）** — デッキペインの最小幅が実際に決まった時点で 840 を検算する
2. **Phase 5（実機）** — タブレットの実寸で 1 ペイン / 2 ペインの切り替わりが妥当か確かめる

★**3 つ目のペイン（P1 検証パネル）にしきい値を増やさない。**
検証パネルは**デッキペインの内側に縦に積む**。しきい値が 2 つになると、
「どの幅でどうなるか」の組み合わせが 4 通りになり、テストも判断点も倍になる。

### 2-2. ルート（6 本）

| # | ルート | 役割 |
|---|---|---|
| **R1** | 起動ゲート | DB を開く → 移行 → 取り込み → カタログ読み込み。**段ごとに**失敗を出す（§3-4） |
| **R2** | デッキ一覧（ホーム） | 作る / 開く / 複製 / 論理削除 / 共有形式の入出力 |
| **R3** | デッキ編集 | 一覧ペイン + デッキペイン + 検証パネル |
| **R4** | カード閲覧 | デッキを開かずに探す。**R3 と同じ一覧ペイン**を単独で置く |
| **R5** | カード詳細 | ★モバイルのみルート。PC ではペイン |
| **R6** | 設定・診断 | dist の場所 / `dataVersion` / 取り込み失敗（D39） / パラレル表示の既定 |

★**ホームはデッキ一覧にする。** アプリの目的がデッキ構築だから。カード一覧をホームにしない。

### 2-3. ペイン・ダイアログ（3 つ）— 画面にしない

| # | 部品 | 置き場 | 画面にしない理由 |
|---|---|---|---|
| **P1** | 検証パネル | R3 に**常設** | 別画面だと「見に行く」操作が要り、**構築の最中に効かない** |
| **P2** | 取り込み失敗の詳細 | R6 のダイアログ + シェルのバッジ | 常時見るものではないが、**無言にはできない**（D39） |
| **P3** | デッキのメタ編集 | R2 / R3 のダイアログ | 名前 / メモ / タグ / カバー |

計 9（6 + 3）。★**数を合わせたのではなく、能力から導いた結果である**（§1-2）。

### 2-4. 実装順

基準は「**何を最初に動かせば全体の妥当性を早く確認できるか**」。

| # | 内容 | ここで確認できること |
|---|---|---|
| **M1** | 土台（`AppScope` / リポジトリ / Store / `PaneScaffold`）+ R1 + R4 の一覧（絞り込みのみ） | **本実装の層が spike ではなく実物として通る。** D45 / D48 / D42 が本経路で成立する。**レイアウト切替を PC 上のテストで固定する** |
| **M2** | R2 最小版（作る / 開く / 一覧）+ `DeckRepository` の書き込み | **読み書きの両方が層を通る。** 保存 → 再起動 → 残っている |
| **M3** | 検索（D44 デバウンス 150ms / D50 `truncated` / D40 `likeFallback` の表示） | 非同期 3 状態と「**静かな縮退の可視化**」が成立する |
| **M4** | R3 デッキ編集 + P1 検証パネル | ★**Release 1 の骨格が端から端まで通る。妥当性の確認点はここ** |
| **M5** | R5 カード詳細（PC ペイン / モバイルルート） | ペイン抽象が **2 通りの器**で成立する |
| **M6** | R6 設定・診断 + P3 メタ編集 + 共有形式の入出力 | D39 / D35 の**出口が塞がる** |

★**M1 と M2 を分ける理由。** M1 は読みだけで層を通す。M2 で初めて書きが通る。
読み書きを同じマイルストーンにすると、失敗したときに層の問題か画面の問題か切り分けられない。

### 2-5. 共有形式の入出力 — 範囲を限定する

**出力**は `Deck.toShareFormat`（`Map<cardNumber, 枚数>`）をそのまま使う。実装済みなので安い。

**入力**は論点が 2 つある。

#### ★ (a) cardNumber → printingId の逆写像が一意でない

1 つの cardNumber に複数の刷りがあり、CLAUDE.md §5-(4) により
**非パラレル刷りが複数ありうる**（実データで 19 の cardNumber が該当。`card_dao.dart:174-176`）。

「代表 1 枚」という概念は `isBasePrinting` として**誤りとして廃止済み**なので、
**「代表を選ぶ」のではなく「取り込み時の既定の刷りを選ぶ」**と位置づける。
既定は `isParallel == false` かつ `printingId` 昇順で最初のもの。**UI で差し替えられるようにする。**

#### ★ (b) 未知 cardNumber を無言で捨てない

`DeckEntry` は `printingId` しか持てないため、マスタに無い cardNumber は**そもそも DB に入れられない**。
黙って落とすと **A-3 と同じ失敗の型**になる。

```dart
class DeckShareImportResult {
  final List<DeckEntry> resolved;
  final List<(String cardNumber, int count)> unknown;    // マスタに無い
  final List<(String cardNumber, List<String> candidates)> ambiguous;  // 刷りが複数
}
```

**「N 件のカード番号がマスタに見つからない。取り込むか中止するか」を選ばせる。**

★D35（マスタに無い printingId を黙って削除しない）はデッキが**既に持っている**未知カードの話で、
これはその**一歩手前**。入れられないので入れないが、**入れなかったことを必ず見せる。**

### 2-6. `truncated` / `mode` の表示先 = **検索画面**

| 出すもの | 出す場所 | 理由 |
|---|---|---|
| `CardSearchResult.truncated`（D50） | **検索結果ヘッダ** | 「その検索語のその瞬間の状態」であり、設定に置いても結びつかない |
| `CardSearchMode.likeFallback`（D40） | **検索結果ヘッダ** | 同上。「2 文字以下なので全文一致で引いた」を出す |
| `import_issues`（D39） | **設定・診断（R6）+ シェルのバッジ** | **永続する状態**なので設定側 |

### 2-7. Release 1 から外した項目

外すにあたり、**なぜ外したか**と**着手時に注意すべきこと**を併記する。
一覧に積むだけだと、再開時に判断の根拠が失われる。

#### (1) FAQ 表示

**外す理由**: カード詳細の付加情報であり、無くてもデッキ構築は完結する。

★★**着手時の罠: `Faq.cardNumbers` の中身は cardNumber ではなく printingId。**★★

```dart
/// 関連するカード (cardNumber ではなく printingId で入る点に注意)。
final List<String> cardNumbers;      // loveca-core/lib/src/entities/product.dart:71-72
```

取り込み層も `faq_printings.printing_id` として入れている
（`loveca-db/lib/src/import/master_importer.dart:260-266`）。

**フィールド名を信じて `cards.card_number` と結合すると、例外も出ずに 0 件になる。**
CLAUDE.md §5-(1)「API のフィールド名を信用しない」と同じ型の罠であり、
**忘れた状態で着手すると必ず踏む。**

#### (2) `large`（1000px）画像を使う拡大表示

**外す理由**: 380 MB あり、配布物の 2/3 を占める（§5-1）。
効果テキストは DB にあるので画像で読ませる必要がない。

**着手時の注意**: 「原寸で見たい」という要求が出た時点で再判断する。
そのときは §5-5 のモバイル供給経路と**同時に**決めること（分けて決めると容量の見積りが二度手間になる）。

#### (3) 盤面（Phase 3b）

**外す理由**: Release 1 の対象外（§1-1）。

**着手時の注意**: `ルール整合性チェック_v1.06.md` の **B-2**（エネルギーデッキの順序）と
**B-4**（ポジションチェンジ / フォーメーションチェンジ）が**未決のまま**。
CLAUDE.md §8 が「B-4 は Phase 3b の論点である」と明記している。

---

## 3. 状態管理（決定 D53）

### 3-1. 判断 — パッケージを入れない

`ValueNotifier` ベースの自前 Store + `InheritedWidget`。riverpod / bloc を採らない。

★**判断根拠に Phase 3b（盤面が `GameState` と `reduce` を扱う）を含めている。**
デッキ構築だけを見て決めると Phase 3b で覆るため。

#### 根拠 1: `loveca_core` 側に既に store の実体がある

| 状態管理パッケージが提供するもの | `loveca_core` の対応物 |
|---|---|
| 単一の不変状態 | `GameState`（`final` + `copyWith`。構造共有が効く / D36） |
| アクション | `GameAction` |
| 遷移関数 | `reduce(GameState, GameAction) -> GameState` |
| 履歴・undo | `GameSession{state, history}` の `record` / `undo` / `undoStep` |

**パッケージはその上に器を被せるだけになる。**

★**bloc を採らない決め手はここ。** bloc の `Event` は `GameAction` と二重定義になり、
**D-D「Phase 6 の権威サーバが同じ `reduce` をコピーゼロで再利用する」の唯一性を濁す。**
「どちらが正のアクション定義か」が曖昧になるのは、D49 が案A を却下したのと同じ型の悪さである。

#### 根拠 2: 再描画粒度の懸念は実測で否定されている

パッケージを入れる最大の動機は「selector で再描画を絞れる」ことだが、**絞る必要が無い。**

| 対象 | build p50 | 出典 |
|---|---:|---|
| 最小盤面（メンバーエリア 3 + 手札 + 控え室） | **0.1 ms** | UI技術検証メモ §7-1 |
| 一覧 2,527 セル | **0.3〜0.4 ms** | 同 §3-1 |
| 観測フレーム予算（144Hz） | 6.9 ms | 同 §1-3 |

**盤面全体を作り直しても予算の 1.5% 程度。**
`ValueListenableBuilder` を根に 1 つ置いて全部作り直す方式で足りる。

★ただし**この数値は「フレーム落ちが無い」ことしか言っていない**（同 §3-4 の戒め）。
規模が変わったら測り直す。引き金は §3-5。

#### 根拠 3: Phase 6 の差し替え点は Store の `dispatch` 1 箇所

Phase 6 で「ローカルで `reduce` する」を「サーバへ action を送って state を受け取る」に差し替える。
その差し替え点は **`dispatch` 1 箇所**であり、**パッケージの有無に依らず自前で切る境界**である。
パッケージを入れてもこの境界は要るし、入れなくても引ける。

#### 根拠 4: 可逆性

**後から入れるほうが、入れたものを剥がすより安い。**
迷ったときは元に戻せるほうを選ぶ。

### 3-2. 自前 Store の形

```dart
/// 単一不変状態 + 遷移。ValueListenable なので
/// ValueListenableBuilder / AnimatedBuilder がそのまま効く。
abstract class Store<S> extends ValueNotifier<S> {
  Store(super.initial);
}
```

| 層 | Store | 遷移 |
|---|---|---|
| Phase 3b | `GameStore extends Store<GameSession>` | ★**`reduce` を呼ぶ唯一の場所が `dispatch`。** undo は `value = value.undo() ?? value` |
| Phase 2 | `CardBrowseStore` / `DeckListStore` / `DeckEditStore` | 各 Store のメソッド |

- 供給は `AppScope`（`InheritedWidget`）。リポジトリと寿命の長い Store を配る
- 画面固有の Store は `State.initState` で作り `dispose` で捨てる
- ★**`GameState` を直接 `InheritedWidget` に載せない。** 載せると
  「更新のたびに全 `dependOnInheritedWidgetOfExactType` が走る」形になり、絞る手段が消える

### 3-3. 非同期の 3 状態

パッケージを入れない選択は、**非同期の状態遷移を自前で書く**ことを意味する。
カード一覧の初回ロード・検索・マスタ取り込み（コールド 1.8 秒）はいずれも非同期で、失敗しうる。

```dart
sealed class Loadable<T> { const Loadable(); }
final class Loading<T> extends Loadable<T> { const Loading(); }
final class Failed<T>  extends Loadable<T> {
  const Failed(this.error, this.stackTrace);
  final Object error;
  final StackTrace stackTrace;
}
final class Ready<T>   extends Loadable<T> { const Ready(this.value); final T value; }
```

★★**`sealed` にする理由は網羅性検査である。**★★
`switch` の枝を足したときに**拾い漏らした `switch` がコンパイルエラーになる。**
nullable を 3 本並べる形（`T? data` / `Object? error` / `bool loading`）にすると網羅性が緩み、
**それは A-3 と同じ「無言」を招く。**

### 3-4. ★ エラーを握り潰さない仕組み

3 つで守る。**どれか 1 つでは漏れる。**

#### (1) `LoadableView` を唯一の描画口にし、`Failed` を既定でエラー表示する

```dart
// onError を渡さなければエラーが出る。握り潰すには明示的に書く必要がある。
LoadableView<List<CardListRow>>(
  loadable: store.value.rows,
  ready: (rows) => CardGrid(rows: rows),
  // onError: (e, s) => const SizedBox.shrink(),   ← これを書かないと握り潰せない
)
```

**握り潰すには明示的に 1 行書かねばならない**＝**レビューで見える。**

#### (2) リポジトリは例外を握らない

`catch` して空リストを返す経路を作らない。Store が `Failed` へ写す。

★**「空」と「失敗」を同じ型で表さない。**
`CardSearchDao` が `CardSearchMode.likeFallback` のコメントで
「黙って 0 件を返すのは A-3 と同じ失敗の型」と書いているのと同じ理由。

#### (3) ★ エラーではない縮退を別枠で見せる

次はいずれも**例外ではないが結果が完全でない**。`Loadable` では表せない。

| 縮退 | 出典 |
|---|---|
| `CardSearchResult.truncated` | D50 |
| `CardSearchMode.likeFallback` | D40 |
| `DeckSections.unknown` / `DeckValidationResult.unknownPrintingIds` | D35 |
| `MasterImportResult.failedPaths` / `unhandledPaths` / `dataVersionAdvanced == false` | D39 |

→ Store の状態に **`notice`** として持ち、`Loadable` とは**別に画面へ出す。**
★これを `Ready` に畳み込むと、「成功したが不完全」が「成功」と区別できなくなる。

### 3-5. ★ 別 isolate 越しのエラー

#### (1) スタックトレースは isolate 境界で切れる

背景 isolate の例外は `Future` のエラーとして返るが、**どこで起きたかは失われる**
（呼び出し側のトレースが付く）。

→ リポジトリの各メソッドが `RepositoryException(op: 'cardList.load', cause: e)` に包み直し、
**失われた情報を呼び出し側で補う。**

#### (2) executor が開けない経路がある

ネイティブ sqlite3 の解決に失敗した場合、**最初のクエリで初めて例外になる。**

→ 起動ゲート（R1）が唯一の受け口。**先に `probeSqliteCapabilities()`（`loveca_db` の既存 API）を走らせる。**
★**FTS5 が無いビルドを掴んでいると `card_search` の作成時まで気づけない。**

#### (3) ★ 移行も「最初のクエリの例外」として出る

`beforeOpen` の `PRAGMA foreign_keys = ON` と `onUpgrade`（D49 の索引建て直し）は
**最初のクエリで初めて走る**（`loveca-db/lib/src/schema/database.dart` の `MigrationStrategy`）。

→ 起動ゲートは次の **4 段を明示的に順に実行し、どの段で失敗したかを表示する。**

| 段 | 内容 | 失敗したら |
|---|---|---|
| 1 | ネイティブ sqlite3 の確認（`probeSqliteCapabilities`） | FTS5 / trigram が無い旨を出す。以降へ進まない |
| 2 | DB を開く + 移行（`SELECT 1` を明示的に打って `onUpgrade` を走らせる） | 移行の失敗として出す。**デッキを消さない** |
| 3 | マスタ取り込み（§4-4） | `failedPaths` / `import_issues` を出す。**前回の内容で続行できる**（D39） |
| 4 | カタログ読み込み（§4-3） | 出して停止 |

★段 2 と段 3 を分けるのは、**「デッキが読めない」と「カードが古い」を区別する**ため。
前者は続行不能、後者は続行可能。混ぜると利用者が「壊れた」と誤解する。

### 3-6. ★ 見直す条件

「後から入れるほうが安い」が成立するのは、**自前 Store が薄いうちだけ。**
引き金を具体値で決めておかないと惰性で肥大化する。

| 引き金 | 具体値 |
|---|---|
| Store の肥大 | 1 つの Store の状態フィールドが **12 を超える**、または `dispatch` の分岐が **20 を超える** |
| 再描画が予算を超えた | Phase 3b の盤面で build p50 が**観測フレーム予算の 20%**（144Hz なら **1.4 ms**）を超える |
| 非同期の定型が重複 | `Loadable` の取り回しが **5 画面を超えて重複**し、`LoadableView` に寄せても消えない |
| Phase 6 | サーバ往復で state が非同期に届き、**楽観更新とロールバック**が要るようになった |

★**引き金を踏んだら「riverpod を入れる」ではなく、まず何が重いかを実測する。**
D42〜D50 と同じ手順（profile ビルド・実データ・観測フレーム予算）を踏む。

---

## 4. `loveca_db` との境界（決定 D55 / D56）

### 4-1. 判断 — リポジトリ層を挟む

**UI から DAO を直接呼ばない。** 理由は 3 つ。

1. **`DeckDao.validate` / `canAdd` は呼ぶたび全件実体化する。**
   UI からセルごとに呼ぶと **40〜60 ms × 呼び出し回数**が UI isolate で走る（§1-3(3)）
2. **D48 が要求する投影クエリが `loveca_db` に無い**（§1-3(4)）。
   ウィジェットに `customSelect` を書くと二度と剥がせない
3. **`drift` の型（`Variable` / `QueryRow` / `LovecaDatabase`）が UI に漏れると、
   Phase 5 の Web / WASM 経路で UI ごと巻き込む。**
   `loveca_db` が `QueryExecutor` を外から受け取る形にしてある努力（`native.dart` の doc）を
   UI 側で台無しにしない

### 4-2. 構成

```
loveca-ui/lib/src/data/
  app_database.dart              ★drift / dart:io / パス解決に触れるのはここだけ
  master_catalog.dart            不変のカタログ（§4-3）
  card_list_row.dart             一覧の投影型
  card_catalog_repository.dart   一覧の投影 / 検索 / カード 1 件 / 刷り
  deck_repository.dart           デッキ CRUD / 検証
  master_repository.dart         版 / 取り込み / import_issues
  card_image_source.dart         ★画像パスを組み立てる唯一の場所（§5）
```

★**リポジトリが返すのは `loveca_core` の型と UI 用の投影型だけ。**
`drift` の型を返さない。
ただし `Stream<int> watchOutstandingImportIssueCount()` はそのまま通してよい
（`Stream<int>` は drift の型ではない）。

★**`NativeDatabase.createInBackground` を組み立てるので `pubspec.yaml` の `drift` 依存は残る。**
それを `app_database.dart` の外へ出さない。
`package:loveca_db/native.dart` の `openFileExecutor` は **UI isolate 実行なのでアプリ本体では使わない**
（D45 / `native.dart:22-27`）。

#### `CardListRow` の列

★**`spike` の `CardGridRow` を写さない（D51）。** 一覧が何を要るかから起こす。

| 列 | 型 | なぜ要るか |
|---|---|---|
| `printingId` | `String` | 一覧の一意キー。**デッキが保持する単位**（D11） |
| `cardNumber` | `String` | **4 枚制限の単位**（D11 / 6.1.1.2）。カード詳細への鍵 |
| `name` | `String` | 表示 |
| `cardType` | **`CardType`** | 絞り込み。★**`String` にしない**（下記） |
| `expansion` | `String` | 絞り込みと既定の並び順 |
| `rarity` | `String` | 表示・絞り込み |
| `isParallel` | `bool` | パラレル表示 OFF の判定（CLAUDE.md §5-(4)） |
| `imageHash` | `String` | 画像の解決。★**空文字がありうる**（§5-2(4)） |
| `cost` | `int?` | 絞り込み。★**メンバーにしか値が無い**（下記） |

並びは `expansion`, `printingId`（`ORDER BY p.expansion, p.printing_id`）。

★**`cardType` は `loveca_core` の `CardType` enum で持つ。**
`spike` は `String` で持っており、`entry.row.cardType == 'energy'` という
**文字列比較**が `main_drag.dart:718` にあった。
綴りを間違えても**コンパイルは通り、静かに false になる。**
投影クエリは `TEXT` を読むので、**リポジトリの境界で 1 回だけ enum へ直す。**

★★**`cost` はメンバーにしか値が無い。**★★
`normalize.py:362-363` は `card.cost` を **`KIND_MEMBER` の分岐でしか設定していない。**
ライブは `cost` フィールドを**ブレードハートの供給元として使う**（同 375-377 / CLAUDE.md §5-(1)）。
したがって配信 JSON でも `cost` はライブ・エネルギーで `null` である。

**帰結: 「コスト N 以下」で素朴に絞ると、ライブとエネルギーが全部消える。**
`spike` の `CardGridFilter.matches` は `r.cost == null` を除外していたので、
実測の「コスト 2 以下 = 208 件」は**メンバーだけの件数**である。

→ **コスト絞り込みは種別フィルタと連動させる。**
実装は 2 案あり、**M1 では (a) を採る**（M3 の検索と同時に見直す）。

| 案 | 挙動 |
|---|---|
| **(a) 採用** | コスト絞り込みを出すのは**種別が「メンバー」のときだけ**。ほかの種別では UI ごと出さない |
| (b) | 「コスト無しを含む」チェックを添える。★**既定でどちらにするかを決めねばならず、既定が「含まない」なら結局静かに消える** |

### 4-3. ★ `MasterCatalog` を起動時に 1 回だけ組む

```dart
class MasterCatalog {
  final Map<String, Card> cards;          // 1,708
  final Map<String, Printing> printings;  // 2,527
  final RuleConfig config;
  final List<CardListRow> rows;           // 2,527（表示に要る列だけ / D48）
  final int dataVersion;
}
```

`DeckRepository` は**ここから `DeckValidator` を 1 個作って持つ。**
`validate` / `canAdd` は DB へ行かない。

★★**無効化処理を書かなくて済む形にする。**★★

カタログが変わるのは**取り込みが起きたときだけ**で、取り込みは**起動ゲートでしか走らない**（§4-4）。
したがって **セッション中ずっと不変**であり、**無効化そのものが要らない。**

これは **D49 が案A（`{fold(cardNumber): cardNumber}` の写像をメモリに保持）を却下したのと同じ考え方**である。

> 無効化を 1 箇所でも漏らすと「取り込んだ新しいカードが検索で引けない」という無言の欠落になり、
> これは A-3 と同じ失敗の型である。（`card_search_dao.dart:19-28`）

**漏れうる構造を作らない。**

### 4-4. ★ マスタ取り込みは起動ゲートでのみ走らせる（決定 D56）

実行中に取り込むと、メモリ上の

- `MasterCatalog.cards` / `printings`（→ `DeckValidator` の判定）
- `MasterCatalog.rows`（→ 一覧の表示とメモリ上フィルタ / D48）

が**静かに古くなる。** どれも**間違った答えを返すが例外は出ない**＝ A-3 型。

→ 「データを更新」は**再起動を伴う操作**にする（設定画面から「更新して再起動」）。

★**これは性能の話ではなく、無効化漏れを構造的に不可能にするための制約である。**

★副次的に、D45 の実測（コールド取り込み 1.8 秒の間 UI isolate なら約 20fps）も
「取り込み中は起動ゲートを出しているだけ」という前提を得て素直になる。

### 4-5. 未決 — 投影クエリを `loveca_db` へ移すか

| | 今回 | 将来 |
|---|---|---|
| 置き場 | `loveca-ui/lib/src/data/card_catalog_repository.dart` | `loveca_db` に `CardListDao` |
| 理由 | 今回は `loveca_db` を変更しない | Phase 5 のスマホでも**同じ投影**が要る |

★**Phase 6 のサーバでは要らない**（サーバは一覧を描かない）ので、
`loveca_db` に置くのが自明に正しいとは言えない。
**移す条件**: Phase 5 で「スマホ側が同じ投影を必要とする」ことが確定したとき。
それまでは UI 側に置き、`CardListRow` の形を `loveca_db` へ移しやすい素直な形に保つ。

### 4-6. アプリのファイル置き場（決定 D59 / D60）

`loveca_db` は **DB ファイルの置き場所を決めない**（`native.dart:24-25`
「置き場所は呼び出し側が決める。`path_provider` は Flutter 依存なのでこのパッケージからは参照しない」）。
**決めるのは `loveca-ui` の責務。**

#### (1) `path_provider` を採る（D59）

★**`loveca-ui` にだけ入れる。`loveca_core` / `loveca_db` には持ち込まない。**
`path_provider` は Flutter プラグインなので `package:flutter` を引き込む。
CLAUDE.md §1 / §2 の検証コマンドが**既にこれを検知する**（両パッケージで `package:flutter` が 0 件であること）。
新しい見張りは要らない。

★**`sqlite3_flutter_libs` を却下した理由（D45 / SQLite の二重調達）は当てはまらない。**
`path_provider` は**何も二重調達しない。**OS のディレクトリを問い合わせるだけである。

#### (2) 置き場を解決する唯一の場所 — `AppPaths`

```dart
/// アプリのファイル置き場。★path_provider に触れてよいのはここだけ。
class AppPaths {
  static Future<AppPaths> resolve() async { /* getApplicationSupportDirectory() */ }

  final Directory supportDir;
  File get databaseFile => File(p.join(supportDir.path, 'loveca.db'));
  File get settingsFile => File(p.join(supportDir.path, 'settings.json'));
}
```

★★**キャッシュディレクトリに置かない。**★★
DB は `decks`（**作り直せないユーザデータ** / D11・D35）と
`cards` / `printings` / `card_search`（dist からの派生物で作り直せる）を**同じ 1 ファイル**に持つ。
`getApplicationCacheDirectory()` は **OS がいつでも消してよい場所**なので、
置くと**デッキが黙って消えうる。**これは A-3 と同じ型の失敗である。
→ **`getApplicationSupportDirectory()` を使う。**

★**Phase 5 で `app_database.dart` を書き換えずに済む形になっている。**
`getApplicationSupportDirectory()` は Windows / Android / iOS のすべてで
「アプリが支援ファイルを置いてよい場所」を返す契約なので、**DB の置き場は差し替え不要。**
プラットフォームで変わるのは次の (3) の dist だけである。

#### (3) dist の場所と解決順（D60）

★**M1 の時点で設定画面（R6）はまだ無い。既定値だけで動く必要がある。**

解決順は 3 段。**上から順に見て、最初に見つかったものを採る。**

| 順 | 出所 | 用途 |
|---:|---|---|
| 1 | 環境変数 `LOVECA_DIST_DIR` | ★**開発と検証。M1 はこれで動かす** |
| 2 | `settings.json` の `distDir` | R6（M6）が書く。M1 でも手で置ける |
| 3 | **既定: 実行ファイルの隣の `data/dist/`** | 配布形態（zip を展開して exe を実行） |

★段 3 は**デスクトップでしか成立しない。**モバイルは実行ファイルの隣に置けない。
→ **`DistLocator` 抽象**にし、モバイル実装は Phase 5 で足す（§5-5 の未決と同じ場所で決まる）。

#### (4) ★ カタログが空なら止める — 理由を添えて

★★**無言で空のカタログを返さない。**★★ それは A-3 と同じ型である。

★★**2026-08-24 訂正。当初この節は「dist 不在 かつ `cards` 0 件」だけを停止条件にしていた。
これは特殊形にすぎず、M1 の実機起動で穴が出た。**★★

実際に起きたこと: dist は**あった**が、配信物の `minAppVersion` が `1.0.0`、
アプリが `0.1.0` だったため `planUpdate` が **`UpdateDecision.appTooOld`** を返し、
`MasterImporter` は**1 ファイルも取り込まずに戻った**。
その結果 `cards` は 0 件だが `distMissing` は false なので、
**起動ゲートはこれを成功として通し、空の一覧を出した。**
警告は 1 つも出なかった。**設計が防ぐはずだった失敗そのものである。**

★原因は「dist の有無」という**入口の条件だけを見ていた**こと。
見るべきは**出口**——**カタログが空かどうか**である。

**段 3（取り込み）の結末は 3 通りある**

| 結末 | 起きること |
|---|---|
| dist 不在 | ★`MasterImporter` を**呼ばない**（呼ぶと原因が「読めない」に化ける） |
| dist あり・`decision != update` | `appTooOld` / `upToDate`。★**取り込みは 1 件も行われない** |
| dist あり・`decision == update` | 取り込みが行われる（全成功 / 一部失敗 / 全失敗） |

**段 4（カタログ）の判断**

```
cards が 0 件なら → 停止し、段 3 の結末から理由を決めて出す
cards があるなら → 続行し、取り込めなかった事実は Notice に出す
```

| `cards` | 段 3 の結末 | 挙動 |
|---|---|---|
| **0 件** | dist 不在 | ★停止。「カードデータが見つかりません」＋**探した場所を全部**（決定 D60） |
| **0 件** | `appTooOld` | ★停止。「アプリが古いため取り込めません」＋**アプリ版と要求される最小版の実値** |
| **0 件** | `upToDate` | ★停止。「取り込み済みのはずですがデータがありません」（`master_state` と実データの不整合） |
| **0 件** | 取り込み失敗 | ★停止。`failedPaths` を出す |
| あり | dist 不在 | 続行 + Notice「更新できませんでした（前回の内容で動いています）」（決定 D39 と同じ考え方） |
| あり | `appTooOld` | ★**続行 + Notice**。データは古いままだが動く |
| あり | 一部失敗 | 続行 + Notice（`import_issues` / 決定 D39） |

★★**理由には必ず「実際の値」を入れる。**★★
「アプリが古い」だけでは利用者は直せない。**アプリ版と `minAppVersion` の両方**を出す。
決定 D60 が「探した場所を並べる」と定めたのと同じ理屈である。

★**`appTooOld` はカタログが空でなくても必ず Notice に出す。**
取り込みが行われなかった事実を黙って落とすと、
「新しい商品が出ているのに増えない」が原因不明のまま残る。

★**`spike` はこの経路を一度も通っていない。**
`spike/common/spike_db.dart:118` が `appVersion: '1.0.0'` を**ハードコード**していたため、
`appTooOld` に落ちなかった。本実装が自分の版を渡してはじめて表面化した。
決定 D51 が言う「spike は本実装と食い違っても誰も気づかない」の実例である。

#### (5) 設定の永続先 — **自前の JSON ファイル**（D60）

`shared_preferences` を**採らない。**

| | 自前 JSON（採用） | `shared_preferences` |
|---|---|---|
| 依存 | **増やさない** | 増える |
| 器 | 全プラットフォームで**同じ 1 ファイル** | Windows は JSON / Android は SharedPreferences / iOS は NSUserDefaults と**器が違う** |
| 置き場 | `AppPaths.settingsFile`。**DB と同じ寿命・同じバックアップ対象** | プラットフォーム任せ |
| 項目数 | 現時点で 2 つ（`distDir` / パラレル表示の既定） | 同じ |

★**器が 3 通りに分かれる代償を、2 項目のために払う理由が無い。**
書き込みは**一時ファイルへ書いてから rename** する（途中で落ちても壊れた設定が残らない）。

★**設定ファイルが壊れていたら、既定に戻したうえで警告を出す。**
黙って既定に戻すと「設定したのに効かない」が原因不明のまま残る。

★**見直す条件**: 設定項目が**10 を超える**、または型付きの構造（入れ子・配列）が要るようになったとき。

---

## 5. 画像の供給（決定 D57）

### 5-1. 実測

| | 枚数 | 容量 | 幅 / 品質 |
|---|---:|---:|---|
| `dist/images/thumb` | 2,527 | **42 MB** | 200px / WebP q80 |
| `dist/images/normal` | 2,527 | **149 MB** | 500px / WebP q85 |
| `dist/images/large` | 2,527 | **380 MB** | 1000px / WebP q90 |
| **合計** | | **571 MB** | |

（`loveca-data/loveca_data/config.py:37-42` の `image_sizes` と実ファイルの実測）

### 5-2. 決められること

#### (1) Release 1 は `thumb` と `normal` だけ使う。`large` は使わない

**571 MB → 191 MB。配布物の 2/3 を捨てられる。**

| 段 | 用途 |
|---|---|
| `thumb`（200px） | 一覧のセル |
| `normal`（500px） | カード詳細 |
| `large`（1000px） | **使わない**（§2-7(2)） |

★効果テキストは DB にあるので**画像で読ませない。** 画像は同定と雰囲気の確認用。

#### (2) `CardImageSource` 抽象 1 つに閉じる

```dart
abstract class CardImageSource {
  /// imageHash が空なら null を返す（＝プレースホルダのまま）。
  ImageProvider? provider(
    String imageHash,
    CardImageSize size, {
    required int cacheWidthPx,   // ★物理ピクセル（D42）
  });
}
```

実装は Release 1 では **`LocalDirectoryImageSource` の 1 本だけ。**

★★**`ImageProvider` を組むのは `CardImageSource` 側であって `CardThumb` ではない。**★★
D57 が抽象を置いた理由は「実装をもう 1 本足すだけで UI が変わらない」ことなので、
**ネットワーク実装は別の `ImageProvider` を返せなければならない。**
組む場所を UI に置くと、その差し替えが成立しない。

責務は次のように分かれる。**どちらも「唯一の場所」である。**

| ファイル | 唯一である責務 |
|---|---|
| `data/card_image_source.dart` | **`FileImage` / `ResizeImage` を構築する唯一の場所。**パスと段（thumb / normal）を知っている |
| `ui/common/card_thumb.dart` | **`Image` ウィジェットを作る唯一の場所**、かつ**セルの物理px を計算する唯一の場所。**プレースホルダを必ず描く |

「UI コードで `Image` / `FileImage` を直接使わない」（D58）は**この分割で満たされる。**

★**D43「UI にネットワーク取得の口を作らない」は、実装が 1 本しかないことで守る。**
抽象を置くこと自体は口を増やさないので D43 に反しない。
経路が 2 つあると「どちらから来た画像か」で不具合の切り分けができなくなる、というのが D43 の理由であり、
**実装が 1 本なら経路は 1 つのままである。**

#### (3) PC は「dist ディレクトリを置く」形。場所は設定で指せる

`spike/common/paths.dart` の `LOVECA_DIST_DIR` と同じ発想。
zip に同梱するかは配布時の判断で、**アプリの設計としては場所を指せれば足りる。**

#### (4) ★ `imageHash` が空文字の刷りがありうる

`build --skip-images` で作った dist は **`imageHash` も空になる**（CLAUDE.md §7-3）。

→ このとき**プレースホルダのままにする。**
ファイル名 `.webp` を組み立てて存在しないパスを読むと、例外か無言の空白になる。
`CardImageSource.provider` が `null` を返し、`CardThumb` が下地だけを描く。

### 5-3. キャッシュ無効化は content-addressed なファイル名が担う

ファイル名が `{imageHash}.webp` なので、**原本が変われば別ファイルになる。**

したがって

- **「同じ名前で中身が変わる」ことが無く、無効化処理を書く必要がない**
- `imageCache` のキーは `ImageProvider` の等価性。`FileImage(path)` + `ResizeImage(width)` は
  パスが変われば別のキーになる。**明示的な `evict` を書かない**
- **ディスクの永続キャッシュを別に作らない。`dist/images/` そのものがキャッシュである**

★`imageCache` の上限は**既定のまま触らない**（D42 / §3-3）。
`ResizeImage` を入れると枚数上限（1000 枚）側が先に効くため、バイト上限を上げても載る枚数は変わらない。

### 5-4. ★★ 穴 — `imageHash` は原本のハッシュであって配信 WebP のハッシュではない ★★

```python
image_hash = _sha256(src.read_bytes())[:32]           # 原本 PNG
dest = cfg.dist_dir / "images" / name / f"{image_hash}.webp"   # 3 サイズが同じ名前
```
（`loveca-data/loveca_data/build_dist.py:59,70`）

**`Config.image_sizes`（`thumb: (200, 80)` など）を変えると、
同じ `imageHash` のまま WebP の中身が変わる。**

| いつ | 影響 |
|---|---|
| 現在（dist を丸ごと差し替える運用） | **影響なし** |
| Phase 4 で「差分で画像を配る」経路を作った瞬間 | ★**古い画質の画像が更新されずに残る** |

手当ての候補は 3 つあるが、いずれも `loveca-data` の変更を伴うので**ここでは決めない。**

| 案 | 内容 |
|---|---|
| (a) | `image_sizes` を凍結する（変えたければ全再配信） |
| (b) | `imageHash` を派生物（WebP）のハッシュにする |
| (c) | 配信側に画像リビジョンを持たせる |

★**UI 側で先に打てる手は 1 つだけ**:
**ファイル名を組み立てる場所を `CardImageSource` の 1 箇所に閉じておく**（§5-2(2)）。
規約が変わったときの変更点が 1 箇所で済む。

★**この穴は `ルール整合性チェック_v1.06.md` の D-4 にも記録した。**
UI の論点ではなく `loveca-data` のパイプラインの論点であり、
この文書だけに置くと **Phase 4 で `loveca-data` を触る人が辿れない。**

### 5-5. 未決 — モバイルの供給経路（Phase 4 依存）

191 MB の同梱は現実的でない。

- **Android**: Play の base 配信にはサイズ上限があり、この規模は Play Asset Delivery か初回ダウンロードが要る
- **iOS**: セルラー回線でのダウンロードに上限があり、同梱は利用者に不利益

★**正確な上限値はいずれも着手時に確認すること。** ここで数値を断定しない。

したがってモバイルは**初回取得が事実上必須**。しかしそれは

- **D43**（UI にネットワーク取得の口を作らない）に触れる
- **Phase 4 の配信経路が未確定**

ため、**現時点では決められない。**

★★**この未決は Phase 2 後半の実装を止めない。**★★
`CardImageSource` の実装をもう 1 本足すだけで、**UI は 1 行も変わらない。**
これが §5-2(2) で抽象を置く実利である。

---

## 6. 試作の知見の持ち込み（決定 D58）

### 6-1. ★★ 「守らないと静かに壊れる」知見は、文書ではなく型で守る ★★

D51 は `spike/` のコードを流用しないと定めた。したがって知見は**書き写す**ことになるが、
**書き写した知見は、次に書く人が知らなければ守られない。**

D46 の発見（掴める領域は描画物の上にしか無い）は、**知らないと必ず踏み、踏んでも例外が出ない。**
「たまに掴めない」という再現条件の分かりにくい不具合になる。

→ **素の `Draggable` / `DragTarget` / `Image` / `FileImage` を UI コードで直接使わせない。**
ラッパの中に知見を **1 回だけ**実装し、決定番号のコメントを付ける。

### 6-2. 対応表（知見 → 本実装での置き場）

| 知見 | 出典 | 置き場 |
|---|---|---|
| `ResizeImage` + **物理px** `cacheWidth` | D42 / §3-2 | ★**2 つに分かれる。**`ImageProvider` を組むのは `data/card_image_source.dart`、`Image` を作り物理px を計算するのは `ui/common/card_thumb.dart`（§5-2(2)） |
| プレースホルダ必須（fling では 1〜2% しかデコードが間に合わない） | D42 / §3-4 | 同上（**常に下地を描く**） |
| `precacheImage` の常時先読みはしない | D42 / §3-5 | **実装しない**（要求が出たら条件つきで） |
| `imageCache` の上限を触らない | D42 / §3-3 | **どこにも書かない。**理由をコメントで残す |
| デバウンス **150 ms** | D44 / §4-3 | `ui/common/debouncer.dart` |
| `truncated` / `mode` を出す | D50 / D40 | 検索結果ヘッダ（§2-6） |
| メモリ上フィルタ（SQL 再クエリしない） | D48 / §3-6 | `CardCatalogRepository` が持つ投影行への**純関数** |
| 表示列だけの投影 | D48 / §2 | `CardCatalogRepository`（§4-5） |
| 別 isolate executor | D45 / §5 | `data/app_database.dart` **1 箇所** |
| **`ColoredBox` でヒットテスト** | D46 / §6-1 | 掴む / 落とす部品の基底が**必ず `color` を持つ** |
| **`pointerDragAnchorStrategy`** | D47 / §6-3 | ラッパが**必ず**指定する |
| `onDragEnd` を当てにしない | D46 / §6-6 | ★**ラッパの API に `onDragEnd` を出さない**（誤用を構造的に不能にする） |
| `ReorderableListView` を採らない | D46 / §6-2 | lint では検知できない → **この表とレビュー観点で守る** |
| タッチは `LongPressDraggable` | D46 / §7-2 | `DragStartMode` で切り替え（§6-3） |
| フレーム予算は `display.refreshRate` から求めない | §1-3 | ★**本実装では計測しない**（下記） |

★**フレーム統計（予算超え 0 など）は本実装ではテストしない。**
profile ビルドでしか出ず、それは `spike/` の資産（D51）。
本実装が守るのは「**必ず `CardThumb` を通ること**」であり、それは型で守れる。

### 6-3. ★ タッチ用の差し替え口を腐らせない

**問題**: `LongPressDraggable` 経路は PC では使われない。
**使われない経路は D51 の `spike/` と同じ性質で静かに腐る**（`flutter analyze` は通るので気づけない）。

手当ては 3 つ。**全部やる。**

| # | 手当て | 効果 |
|---|---|---|
| 1 | ★**ウィジェットテストで両経路を通す。** `DragStartMode` の両値についてドラッグが成立することを `flutter_test` で固定する | **本命。** spike にテストが無くて腐ったのだから、本実装はテストで固定する |
| 2 | ★**ヒットテストの回帰テストを置く。** `tester.startGesture(行の中央)` → `onDragStarted` が呼ばれること | D46 の発見を固定する。**spike では合成ポインタと実行ファイルが要ったが、ウィジェットテストなら要らない** |
| 3 | 開発用スイッチで PC 上でも長押し経路に切り替えられるようにする | 手で触れる状態を残す |

★**手当て 2 は spike より安く同じ欠陥を捉えられる。**
D46 は profile ビルド + 合成ポインタで見つけたが、
「掴めるか」だけならウィジェットテストで十分であり、**CI に乗る。**

### 6-4. レイアウト切替を PC 上のテストで固定

`tester.view.physicalSize` を変えて `PaneScaffold` が **1 ペイン ⇄ 2 ペイン**を
切り替えることを固定する。

★**「設計だけ通した」を「切替は動く」まで引き上げる。**
ただしこれは**モバイルで動く保証ではない**（§7）。

### 6-5. ★ `loveca-ui` に初めてテストを置く

現在 `loveca-ui` のテストは **0 件**。§6-3 / §6-4 で初めて置く。

★CLAUDE.md §3 の**テスト件数表に `loveca-ui` の行を足すのは、実際にテストを書いたとき。**
設計の段階で表に載せない（載せると「あるはず」の件数が独り歩きする）。

### 6-6. グリッドの寸法 — 出典と再現条件

★**出典の格が 2 つある。混ぜないこと。**

| 値 | 出典 | 格 |
|---|---|---|
| セル幅 **120 物理px** | `docs/UI技術検証メモ.md` §3（測定条件） | ★**正。**D42 の数値はこの条件で得られた |
| thumb の原寸 **200 × 279** | 同 §3 / §1-2 | ★**正。**実データの寸法 |
| 実測 **144Hz** / 予算 **6.9 ms** | 同 §1-3 | ★**正** |
| `maxExtent` **140 論理px** | `spike/main_grid.dart:491` | **再現手段。**メモには無い |
| `spacing` **6** | 同 `:492` | 同上 |
| `childAspectRatio` **200 / 279** | 同 `:522` | 同上（原寸の比） |

本実装は **`maxExtent 140` / `spacing 6` / `childAspectRatio 200/279` を採る。**
列数は `ceil(利用可能幅 / 140)`、セル幅はそこから割り戻す。

★★**この 3 つを変えると、セル幅 120 物理px という D42 の前提が動く。**★★
`ResizeImage` の効果（予算超え 25 フレーム → 0）も、キャッシュの見積り
（1 枚 74 KB / 1000 枚）も、**すべてこのセル幅で測ったものである。**
**変えるなら測り直すこと。**

★`cacheWidth` は §7 の規則に従う: **`min(セル物理px, その段の原寸幅)`。**

---

## 7. ★ Phase 5 着手時に最初に潰す項目（決定 D52）

★★**「設計だけ通した」は「モバイルで動く保証がある」ことを意味しない。**★★

この区別が曖昧なまま Phase 5 に入ると、**設計上は対応済みという記述だけが残って実機で破綻する。**

| # | 項目 | 現状 |
|---|---|---|
| **1** | **`thumb` 200px がモバイルの物理セル幅を下回る** | PC の実測セル幅は **120 物理px**（＝縮小方向）。モバイルは DPR 2.5〜3 で 3 列なら **300〜400 物理px** になり、**原寸 200px を超える**。`ResizeImage` の前提（縮小）が逆になり、拡大でぼやける。`normal`(500px) が要る可能性があり、要れば §3-3 のキャッシュ見積り（1 枚 74 KB / 1000 枚）は**やり直し** |
| **2** | **タッチのジェスチャ競合** | スクロール領域内で `Draggable` 既定（`ImmediateMultiDragGestureRecognizer`）はスクロールに負けやすい。`LongPressDraggable` へ切り替える設計にしてあるが**実機未検証**（UI技術検証メモ §7-2） |
| **3** | **sqlite3 のネイティブ調達の Android / iOS 経路** | 配布物に `libsqlite3.arm64.android.so` / `libsqlite3.arm64.ios.dylib` は**実在する**（`sqlite3-3.5.2/lib/src/hook/asset_hashes.dart`）。ただし ★**FTS5 / trigram の有無を確かめたのは Windows だけ**（UI技術検証メモ §1-2）。`dart run tool/probe_sqlite.dart` / `spike/main_probe.dart` 相当を**各プラットフォームで走らせること。FTS5 が無いと `card_search` の作成時点で落ちる** |
| **4** | **iOS は macOS が無いと検証すらできない** | ビルドも実機確認もできない |
| **5** | **モバイルの画像供給経路** | §5-5 の未決 |

★★**上記が未了である限り、Release 1 を「完了」と呼べない。**★★

今のうちに決められる規則を 1 つだけ先に置く。

> **`cacheWidth = min(セル物理px, その段の原寸幅)`**

原寸を超える値を渡してもデコード結果は大きくならないが、
上限を明示しておくと「**なぜぼやけるのか**」を追える。

---

## 8. `loveca-ui/lib/` の構成

```
lib/
  main.dart                       runApp のみ
  src/
    app.dart                      MaterialApp / ルート / AppScope の設置
    app_info.dart                 AppInfo.version（§9-2）
    boot/
      boot_gate.dart              R1。§3-5 の 4 段
      catalog_loader.dart         MasterCatalog を 1 回だけ組む
    data/
      app_paths.dart              ★path_provider に触れる唯一の場所（§4-6 / D59）
      dist_locator.dart           dist の 3 段解決と不在の検出（§4-6 / D60）
      app_settings.dart           settings.json の読み書き（§4-6(5)）
      clock.dart                  ★UI 層で DateTime.now() を書く唯一の場所（§9-1）
      app_database.dart           ★drift / dart:io に触れるのはここだけ
      master_catalog.dart
      card_list_row.dart
      card_catalog_repository.dart
      deck_repository.dart
      master_repository.dart
      card_image_source.dart      ★画像パスを組み立てる唯一の場所
    state/
      store.dart                  Store<S> / Loadable<T>
      card_browse_store.dart
      deck_list_store.dart
      deck_edit_store.dart
    ui/
      layout/pane_scaffold.dart   ★1ペイン/2ペイン切替の唯一の判断点
      common/
        loadable_view.dart        ★Failed を既定で出す
        card_thumb.dart           ★ResizeImage / プレースホルダ / 物理px の唯一の場所
        card_drag.dart            ★Draggable / DragTarget のラッパ
        debouncer.dart            ★150 ms（D44）
      browse/ deck/ settings/
test/
  app_info_test.dart              ★pubspec.yaml の version と突き合わせる（§9-2）
  layout/pane_scaffold_test.dart  ★840 論理px の前後で 1/2 ペインが切り替わる（D61）
  data/dist_locator_test.dart     ★3 段の解決順と「不在」の検出（D60）
  common/card_drag_test.dart      ★D46 のヒットテスト回帰 / DragStartMode 両経路
  common/debouncer_test.dart
```

★**`lib/` から `spike/` を参照しない**（D51）。
`spike/` は `lib/` の外にあるので `package:loveca_ui/...` では届かない。**この配置を崩さない。**

---

## 9. Phase 4 の同期を見据えた更新経路

`Deck.copyWith` の既定値に注意が要る（`loveca-core/lib/src/entities/deck.dart:77-100`）。

```dart
updatedAt: updatedAt ?? DateTime.now().toUtc(),   // ★CLAUDE.md §1 の既知違反
revision: revision ?? this.revision + 1,          // ★呼ぶたびに +1
```

| 守ること | 理由 |
|---|---|
| **編集中はドラフトを Store に持ち、保存時に 1 回だけ `copyWith` する** | キー入力ごとに呼ぶと **`revision` が跳ね、Phase 4 の同期で「大量に更新された」ように見える** |
| ★**`updatedAt` を必ず明示的に渡す** | 既定値の `DateTime.now()` を踏まない。CLAUDE.md が「新しいコードでこれを真似しない」と定めており、**呼び出し側から渡せば既知違反の影響を受けない** |
| **`now` の供給元をアプリ内で 1 箇所に決める** | `DeckDao.softDelete(deckId, at)` は既に `at` を要求する形。**層の内側で `DateTime.now()` を呼ばない方針の、UI 側の受け** |

★`DeckDao.save` は `revision` をそのまま書く（`deck_dao.dart:75-89`）ので、
**`revision` を管理するのは UI 側の責務**である。

### 9-1. `now` の供給元 — `Clock`

`loveca_core` / `loveca_db` はどちらも**層の内側で `DateTime.now()` を呼ばない**設計で、
`DeckDao.softDelete(deckId, at)` / `MasterImporter.import(now:)` /
`MasterStateDao.recordIssue(at:)` はいずれも**呼び出し側から受け取る。**
その「呼び出し側」を UI のどこにするかを決める。

```dart
typedef Clock = DateTime Function();

/// ★UI 層で DateTime.now() を書いてよいのはこの 1 行だけ。
DateTime systemClockUtc() => DateTime.now().toUtc();
```

`AppScope` が `Clock` を 1 つ持ち、`DeckRepository` / `MasterRepository` へ渡す。

★**利得は 2 つ。**
(1) テストで固定時刻を入れられる（`revision` と `updatedAt` の検証が決定的になる）。
(2) ★**`DateTime.now()` の grep が 1 箇所に収まる**ので、
CLAUDE.md §1 の既知違反（`Deck.copyWith` の既定値）を UI 側から踏んでいないことを確認できる。

### 9-2. `appVersion` の供給元 — `AppInfo.version`

`MasterImporter.import(appVersion:)` が要る。`planUpdate` がこれを
配信側の `minAppVersion` と比べ、**古ければ取り込みを拒否する**（`master_data.dart`）。

`package_info_plus` を**入れない。**依存を 1 つ増やす価値が無い。

```dart
/// ★pubspec.yaml の version と手で揃える。ズレると minAppVersion の判定が誤る。
abstract final class AppInfo {
  static const String version = '0.1.0';
}
```

★★**手で揃えるものは必ずズレる。テストで固定する。**★★

```
test/app_info_test.dart:
  pubspec.yaml の version: 行を読み、AppInfo.version と一致することを検証する
```

これは D58 の「知見は文書ではなく型（とテスト）で守る」と同じ手当てである。
定数のコメントに「揃えること」と書くだけでは守られない。

---

### 9-3. ★ M1 の実測（2026-08-24）

★**すべて debug ビルドの値である。**
`docs/UI技術検証メモ.md` の数値は profile ビルドなので、**直接は比べられない**
（同メモが「計測は profile ビルドで行う。debug では数値が実態と離れる」と定めている）。

実データ（1,708 種 / 2,527 刷り）/ Windows / `LOVECA_DIST_DIR` 指定。

| 段 | コールド（取り込みあり） | ウォーム（`upToDate`） |
|---|---:|---:|
| 1 sqlite の確認 | 65.5 ms | 60.8 ms |
| 2 DB を開く + 移行 | 182.6 ms | 248.6 ms |
| 3 取り込み | **3,590.1 ms** | 56.5 ms |
| 4 **カタログ構築** | **125.6 ms** | **155.9 ms** |
| 合計 | 3,963.8 ms | 521.8 ms |

カタログの中身: `rows` 2,527 / `cards` 1,708 / `printings` 2,527 / `dataVersion` 2 /
★**`imageHash` が空の刷り 0 件**。

### ★ カタログ構築 125〜156 ms — 見積り 40〜60 ms との差について

閾値 200 ms は下回った。ただし**見積りより 2〜3 倍大きい**。理由は 2 つあり、
**どちらも「想定が外れた」ではない。**

1. ★**見積りの 40〜60 ms は `daoFull`（`cardsByNumber` + `printingsById`）だけの値**
   （UI技術検証メモ §2）。段 4 はそれに加えて**投影 `loadListRows`（11〜15 ms）/
   `ruleConfig` / `localDataVersion`** も行う。**同じものを測っていない。**
2. ★**debug ビルドである。**上記の見積りは profile。

→ **決定 D55（起動時に 1 回だけ組む）の判断は覆らない。**
起動 1 回で 156 ms は、`DeckDao.validate` を UI から呼ぶたびに払う代償
（呼び出し回数 × 40〜60 ms）と比べる対象ですらない。

★**profile ビルドでの再測定はしていない。** M1 の目的は
「層が実物として通ること」の確認であり、性能の確定ではない。
数値が判断に効く場面が来たら profile で測り直すこと。

### ★ 取り込み 3,590 ms — spike の 1,828 ms との差

同じく **debug ビルドの差**が大きいと見られるが、**確かめていない**。
決定 D45（別 isolate）はこの取り込みを UI スレッドから外すためのもので、
**遅いほど D45 の判断は強まる**方向なので、M1 では追わない。

---

## 10. 未決一覧

★**推測で埋めない。** 判断の時期を併記する。

| # | 論点 | いつ判断するか |
|---|---|---|
| **U1** | **モバイルの画像供給経路**（同梱 / 初回取得）。D43 に触れる | **Phase 4**（配信経路の確定時） |
| **U2** | **`image_sizes` を変えたときの `imageHash` 据え置き**（§5-4）。`loveca-data` の変更を伴う | **Phase 4**。`ルール整合性チェック_v1.06.md` D-4 に記録済み |
| **U3** | **モバイルのグリッドに `thumb` で足りるか**（§7-1） | **Phase 5 着手時** |
| **U4** | **投影クエリを `loveca_db` へ移すか**（§4-5） | **Phase 5**（スマホが同じ投影を要すると確定したとき） |
| **U5** | **盤面のカード表示に `thumb` で足りるか**（`normal` が要るか） | **Phase 3b**（UI技術検証メモ §10-5 の再掲） |
| **U6** | **先読みを採る条件**（「スクロールが止まったら 1 画面分」などの具体値） | 要求が出たとき（同 §10-4 の再掲） |
| **U7** | **共有形式インポートの既定の刷りの選び方**（§2-5(a)） | **M6 実装時** |
| **U8** | ★**ペインの切替しきい値 840 論理px は暫定値**（§2-1）。デッキペインの最小幅 320 が見積りのため | **M4**（実装で検算）と **Phase 5**（実機） |

★このほか `docs/UI技術検証メモ.md` §10 の
「タッチ環境は実機未検証」「測定は 1 台・1 解像度・144Hz のみ」は**そのまま有効**。
本文書 §7 がその具体化にあたる。

★**上の未決と §7 は `CLAUDE.md` §8 の「未決項目（着手フェイズから辿るための索引）」に載せてある。**
着手フェイズから辿れないと見落とすため。
**あちらは索引で、内容はこちらにしか置かない**（両方に書くと片方だけ直されて食い違う）。
未決を足したら**索引にも 1 行足すこと。**
