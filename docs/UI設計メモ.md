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
| ペインの切替 | **840 論理px。★M4 で実測して確定（Phase 5 の実機は残る）** | D61 | §2-1 / §9-7 |
| デッキの並び順 | ★**保存されない。並べ替えは実装し「開き直すとカード番号順に戻る」と予告する** | D65 | §9-8 |
| カード詳細の置き場 | **2 ペインは secondary を差し替え / 1 ペインはルート。判断点は 1 箇所** | D66 | §9-9 |
| 共有形式の書式 | **行指向のテキスト。JSON を採らない。読めない行は必ず見せる** | D67 | §2-5 / §9-11 |
| 取り込み時の既定の刷り | ★**非パラレルのうち `printingId` 昇順の先頭。開示は「非パラレルが複数」の 19 種だけ** | D68 | §2-5 / §9-11 |
| 4 枚超過の共有文字列 | **弾かず丸めず、入れて `DeckValidator` に警告させる** | D69 | §9-11 |
| デッキの保存 | ★**`copyWith` ではなく明示コンストラクタ。カバーを外せるようにするため** | D70 | §9-11 |
| デッキの複製 | ★**刷りを保ったまま写せる唯一の手段。`masterDataVersion` は元の値を引き継ぐ** | D71 | §9-11 |
| カードの絵の枠 | ★**箱の寸法は種別で変えず、中に `cardAspectRatioOf` の枠を作って中央に置く。帯は透明** | D72 | §5-1 / §6-6 / §9-12 |

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

★★**(b) のデッキペイン 320 は、当初は実測値ではなかった。**★★
本実装のデッキ行の寸法が決まっていなかったため、**840 は暫定値だった。**

**見直す時点は 2 つあった。**

1. ~~**M4（R3 の実装時）** — デッキペインの最小幅が実際に決まった時点で 840 を検算する~~
   → ★**2026-08-24 実施。§9-7 に手順と値。実機の自然な最小幅は 288 付近で、
   採用 320・算数は 444 + 1 + 320 = 765 ≤ 840。840 は動かさない。**
2. **Phase 5（実機）** — タブレットの実寸で 1 ペイン / 2 ペインの切り替わりが妥当か確かめる
   （★**こちらは残っている**）

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
| **M2** | R2 最小版（作る / 開く / 一覧 / 論理削除）+ R3 最小版 + `DeckRepository` の書き込み | **読み書きの両方が層を通る。** 保存 → 再起動 → 残っている ★**2026-08-24 完了**（§9-4） |
| **M3** | 検索（D44 デバウンス 150ms / D50 `truncated` / D40 `likeFallback` の表示） | 非同期 3 状態と「**静かな縮退の可視化**」が成立する ★**2026-08-24 完了**（§9-5） |
| **M4** | R3 デッキ編集 + P1 検証パネル | ★**Release 1 の骨格が端から端まで通る。妥当性の確認点はここ** ★**2026-08-24 完了**（§9-6 / §9-7 / §9-8） |
| **M5** | R5 カード詳細（PC ペイン / モバイルルート） | ペイン抽象が **2 通りの器**で成立する ★**2026-08-24 完了**（決定 D66 / §9-9） |
| **M6** | R6 設定・診断 + P3 メタ編集 + 共有形式の入出力（+ 複製） | D39 / D35 の**出口が塞がる** ★**2026-08-24 完了**（決定 D67〜D71 / §9-10 / §9-11） |

★**M1 と M2 を分ける理由。** M1 は読みだけで層を通す。M2 で初めて書きが通る。
読み書きを同じマイルストーンにすると、失敗したときに層の問題か画面の問題か切り分けられない。

### 2-5. 共有形式の入出力 — 範囲を限定する

**出力**は `Deck.toShareFormat`（`Map<cardNumber, 枚数>`）をそのまま使う。実装済みなので安い。

**入力**は論点が 2 つある。

#### ★ (a) cardNumber → printingId の逆写像が一意でない ★**M6 で確定（決定 D68 / U7 解消）**

1 つの cardNumber に複数の刷りがあり、CLAUDE.md §5-(4) により
**非パラレル刷りが複数ありうる**（実データで 19 の cardNumber が該当。`card_dao.dart:174-176`）。

「代表 1 枚」という概念は `isBasePrinting` として**誤りとして廃止済み**なので、
**「代表を選ぶ」のではなく「取り込み時の既定の刷りを選ぶ」**と位置づける。
既定は `isParallel == false` かつ `printingId` 昇順で最初のもの。**UI で差し替えられる。**
★非パラレルが 1 件も無ければ全刷りの先頭（実データでは起きないが落とさない）。

★★**開示するのは「非パラレルが複数」の側だけ**★★

| 分類 | 実データの件数 | 扱い |
|---|---:|---|
| 非パラレルが複数（既定がコイントス） | **19** | ★件数を明示して開示する |
| 刷りが複数（差し替えられる） | **600** | 開示しない。プルダウンを出すだけ |

**毎回 600 件の警告を出すと 19 件の意味が消える。**
★また**曖昧さは「断り」ではない**——既定を選んであり差し替えもできるので、
取り込めなかったものは無い。確認ボタンの文言も変えない。

#### ★ (b) 未知 cardNumber を無言で捨てない

`DeckEntry` は `printingId` しか持てないため、マスタに無い cardNumber は**そもそも DB に入れられない**。
黙って落とすと **A-3 と同じ失敗の型**になる。

★**M6 の実装**（`loveca-ui/lib/src/data/deck_share.dart`）:

```dart
class DeckShareImportResult {
  final List<ResolvedShareCard> resolved;                 // 既定の刷りつき
  final List<(String cardNumber, int count)> unknown;     // マスタに無い
  final List<String> unparsedLines;                       // ★書式として読めない
  final List<(String cardNumber, int count)> overLimit;   // ★6.1.1.2 超過（D69）
  List<ResolvedShareCard> get ambiguous;                  // 非パラレルが複数
}
```

**「N 件のカード番号が見つかりません。取り込むか中止するか」を選ばせる。**

★★**`unparsedLines` を `unknown` と分けた（決定 D67）**★★
どちらも「取り込めなかった行」だが**利用者の対処が違う**——
前者は書き直す、後者はカードデータを更新する。
M3 で縮退 3 種を分けたのと同じ理由（§3-4(3)）。

★★**書き出しにも同じ穴がある（決定 D35）**★★
`Deck.toShareFormat` は `if (printing == null) continue;`
（`loveca-core/lib/src/entities/deck.dart:145`）で
**マスタに無い刷りを無言で落とす。** cardNumber が引けないので落とすこと自体は
正しいが、**落としたことを言わないのは A-3 と同じ型**。
呼び出し側で数えて返し、画面に出す。

★★**往復すると刷りの違いが潰れる**★★
共有形式は cardNumber ごとに合算するので、`-SD` 3 枚 + `-SD2` 1 枚は `x4` の 1 行になる。
**書式の性質であって不具合ではない**が、書き出しの画面で必ず言う。
刷りを保ったまま写したいなら**複製**（決定 D71）。

★D35（マスタに無い printingId を黙って削除しない）はデッキが**既に持っている**未知カードの話で、
これはその**一歩手前**。入れられないので入れないが、**入れなかったことを必ず見せる。**

### 2-6. `truncated` / `mode` の表示先 = **検索画面**

| 出すもの | 出す場所 | 理由 |
|---|---|---|
| `CardSearchResult.truncated`（D50） | **検索結果ヘッダ** | 「その検索語のその瞬間の状態」であり、設定に置いても結びつかない |
| `CardSearchMode.likeFallback`（D40） | **検索結果ヘッダ** | 同上。「2 文字以下なので全文一致で引いた」を出す |
| `import_issues`（D39） | **設定・診断（R6）+ シェルのバッジ** | **永続する状態**なので設定側 |
| ★**刷りが 1 件も無いカードの件数**（D-8 / 決定 D63・M3 で追加） | **検索結果ヘッダ** | 同上。検索だけに出て一覧には出ないので、ここで言わないと誰も気づけない |
| ★**検索上限の上書き**（D64・M3 で追加） | **起動 Notice**（+ 打ち切りの文面） | **セッション中ずっと続く状態**なので Notice 側。ただし誤認が起きるのは打ち切りの瞬間なので、文面にも実値を書く |

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

#### ★★ 縮退の型は文脈ごとに分ける。描画だけ共有する（M4 で追加）★★

M4 でデッキ編集にも縮退が出た（`DeckOrderNotPersisted` / `DeckUnknownPrintings`）。
検索側（`SearchDegradation`）と **1 つの `sealed` にまとめない。**

理由: `sealed` の値は**網羅性検査**にある。まとめると、検索側に 4 つ目を足したときに
デッキ側の `switch` にも「ここでは起きない」枝が生え、**検査の意味が薄れる。**

→ **描画だけ `ui/common/degradation_line.dart` に括り出して共有する。**
見た目が 2 系統に分かれるのを防ぎつつ、網羅性は各文脈に閉じる。

★★**3 つ目が出たときの振り分け規則**（書かないと次に足す人が迷う）★★

| その縮退の寿命 | 系統 | 出る場所 |
|---|---|---|
| 検索語ごと（`CardBrowseStore`） | `SearchDegradation` | 検索結果ヘッダ |
| 編集セッションごと（`DeckEditStore`） | `DeckEditDegradation` | デッキペイン |
| どの Store にも属さない（起動時に決まり以降不変） | `BootNotice` | ★**全ルートの `NoticeBar`**（`BootGate` に一本化 / **決定 D89** / §11）★**2026-08-25 訂正: それまでは「R2 の `NoticeBar`」だったが、R4 / R3 / R7 では読めなかった** |
| ★**盤面セッションごと** | `BoardNotice` | 盤面の帯（`docs/盤面設計メモ.md` §10-3） |

★★**この表の正はここである。写しが少なくとも 3 か所ある。**★★
`docs/盤面設計メモ.md` §10-3 / `loveca-ui/lib/src/state/board_notice.dart` /
`loveca-ui/lib/src/ui/common/degradation_line.dart`。
★★**直すときは必ず写しも掃くこと。**★★ D89 の実装では**ここだけを訂正し、
3 写しが「R2 の `NoticeBar`」のまま残った**（2026-08-25 に掃いた）。
★これは `ルール整合性チェック_v1.06.md` の **D-16**（「同じ列挙の写しを探す」）が
**その日のうちに守られなかった**という意味で、D-15 / D-16 とまったく同じ型である。
★**「唯一」「N 箇所」という語を 1 つも含まない写し**なので、
D-15 の走査（数え上げ語の正規表現）では**原理的に見つからない。**

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
| `cardType` | **`CardType`** | 絞り込み ＋ ★**絵の枠**（`cardAspectRatioOf` / 決定 D72）。★**`String` にしない**（下記） |
| `expansion` | `String` | 絞り込みと既定の並び順 |
| `rarity` | `String` | 表示（★**絞り込みには使っていない**。下記） |
| `isParallel` | `bool` | パラレル表示 OFF の判定（CLAUDE.md §5-(4)） |
| `imageHash` | `String` | 画像の解決。★**空文字がありうる**（§5-2(4)） |
| `cost` | `int?` | 絞り込み。★**メンバーにしか値が無い**（下記） |

並びは `expansion`, `printingId`（`ORDER BY p.expansion, p.printing_id`）。

★★**`rarity` は投影に来ているが、絞り込みには使っていない（2026-08-25 訂正）**★★
ここは長く「表示・**絞り込み**」と書かれていたが、**`CardListFilter` に `rarity` の条件は無い。**
`git log -S` で確かめたところ **`filter_panel.dart` に `rarity` が現れたことは一度も無い。**
この列表（`2d78228` / 2026-08-23）は実装（`0dd36f4` / 2026-08-24）より**先に書かれた設計意図**で、
実装は表示だけを作った。★経緯と型は `ルール整合性チェック_v1.06.md` **D-15 (h)**。

★**ただし「投影に既に来ている」ことは捨てない。**
詳細検索（**U21** / §12-1）を入れるとき、`rarity` は
**行を増やさず `CardListFilter` に条件を 1 つ足すだけで済む＝追加費用が最も小さい軸**である。

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

#### ★★ 縦横比は種別で違う（M5 で全数計測 / 2026-08-24）★★

| 種別 | thumb の寸法 | 比 |
|---|---|---|
| メンバー | 200×279（1,036 枚）/ 200×280（483 枚） | 縦長 **0.717** |
| エネルギー | 200×279（484）/ 200×280（228）/ 200×273（5） | 縦長 **0.717** |
| ★**ライブ** | **200×143（290 枚）/ 200×144（1 枚）** | **横長 1.399** |

★`docs/UI技術検証メモ.md` §3 の「thumb の原寸 200×279」は**メンバーの値**であって全種ではない。

★★**枠は種別で選ぶ。箱は種別で変えない（決定 D72 / 未決 U11 の解消）★★**
カード詳細（R5）も一覧（`CardGrid`）もデッキ行も P3 カバー選択も、
`cardAspectRatioOf(cardType)` の枠を箱の中に作って中央に置く（`CardArt`）。
**一覧のタイルは D42 の測定条件のまま 200:279** なので、
ライブのセルには上下に帯（片側 0.340 × セル幅）ができる。
★以前は全部を 200:279 の箱に `cover` で入れており、
**ライブは左右 48.7% が切り落とされ 1.951 倍に拡大されていた。**

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

#### ★★ 「タイルの比」と「絵の枠の比」は別物である（決定 D72）★★

| | 何で決まるか | 種別で変わるか |
|---|---|---|
| **タイル**の比 | `childAspectRatio` = `kCardAspectRatio`（200:279） | ★**変わらない。**D42 の測定条件そのもの |
| **枠**の比 | `cardAspectRatioOf(cardType)`（`CardArt`） | ★**変わる**（ライブは 200:143） |

★★**枠を種別で選んでも D42 は動かない。**★★ 理由は 3 つとも成り立つから——
(1) セル幅は `maxExtent` / `spacing` / タイル比から決まり、どれも触らない。
(2) 箱が枠の比より縦長なので `AspectRatio` は幅いっぱいを取り、**枠の幅 == タイルの幅**。
(3) `ResizeImage(width:)` は幅だけを指定するので**デコード結果が 1 バイトも変わらない**。
★これは `test/ui/card_art_test.dart` が機械で固定している（文章に頼らない）。

★★**逆に、タイルの比を種別で変えると D42 の前提が 2 つに割れる。**★★
未決 **U12** はその案（単一種別のときだけタイルを横長にする）を、
退避先として**退けたうえで**残してある。

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
| ★**6** | ★**タッチでは `Tooltip` が出ず、無効なボタンの理由が読めない**（M-B5 / 決定 D90-3 で追加） | 盤面の巻き戻しは `canUndo == false` のときボタンを消さず**無効にして理由を Tooltip に出す**（`_DrawEnergyButton` と同じ形で、盤面の他のボタンも同じ）。★**着地先の条番号はラベル自身に出してある**ので「押す前にどこへ着くか」は読めるが、**理由はタッチでは読めない。**★盤面は PC 専用（CLAUDE.md 冒頭）なので **Phase 5 の範囲外だが、同じ形が R2〜R6 にもある** —— そちらは Phase 5 の対象である。★**判断は Phase 5。いま決めない** |

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


### ★ 9-4. M2 の実機確認（2026-08-24）

実データ（1,708 種 / 2,527 刷り / `dataVersion` 2）/ Windows / `LOVECA_DIST_DIR` 指定 / debug ビルド。

★**M2 の目的は「読み書きの両方が層を通る」ことの確認であり、性能ではない。**
起動の内訳は §9-3 と同傾向（ウォーム合計 494.7 ms）だったので測り直していない。

| # | 確かめたこと | 結果 |
|---|---|---|
| 1 | ホームが R2（デッキ一覧）であること | ○ 空表示「デッキがまだありません」 |
| 2 | 作る → `decks` に行が入る | ○ `deckId` = `810f5480-5834-4578-af22-0585f8a0b8e7`（v4 の形式を満たす / 決定 D62） |
| 3 | ★`masterDataVersion` が配信の版になる（P5） | ○ **2**（dist の `dataVersion` と一致） |
| 4 | ★**編集しても `revision` が動かない**（§9-1） | ○ 名前を数回変えた時点で **`revision: 0`** のまま。画面にも出している |
| 5 | ★**保存 1 回で `revision` が +1** | ○ **0 → 1**。`updatedAt` だけ動き `createdAt` は不変 |
| 6 | ★★**保存 → 再起動 → 残っている**（M2 の目的）★★ | ○ プロセスを落として起動し直しても一覧に出る |
| 7 | ★★**削除 → 再起動 → 復活しない**★★ | ○ 一覧に出ない。★**DB には行が残り `deletedAt` が入っている**（P3） |
| 8 | `DeckValidator` が本経路で動く（決定 D55） | ○ メンバー 0/48・ライブ 0/12・エネルギー 0/12・未達 3 件 |
| 9 | R4（カード閲覧）へ R2 から到達できる | ○ 2,527 件が出る。2 ペインと絞り込みのモーダルも動く |

★**#7 で `revision` は 1 のままだった。**`DeckDao.softDelete` が `revision` に
触れないためで、P2「更新のたびに +1」と食い違う。
**M2 では直さず**、`ルール整合性チェック_v1.06.md` **D-9** に記録した（判断は Phase 4）。

### ★ M2 で表面化した設計の穴 — `AppScope` が Navigator の下にあった

M1 は画面が 1 枚で遷移が無かったため、`AppScope` を
`MaterialApp.home`（= Navigator の**下**）に置いていても成立していた。
M2 で R2 から R3 / R4 を `push` した瞬間、**押した先で `AppScope.of` が届かない。**

→ `MaterialApp.builder` は Navigator を `child` として受け取るので、そこで包む。
`BootGate` の API を `builder: WidgetBuilder` から `child: Widget` に変えた。
起動が通るまで `child` を返さなければ Navigator は組み立てられない（Widget は遅延評価）。

★**テストの器も本番と同じ形に揃えてある**（`test/support/pump_app.dart`）。
`MaterialApp(home: AppScope(...))` のままにすると、
**テストだけ通って実機で落ちる**（逆もある）状態になる。


### ★ 9-5. M3 の実機確認（2026-08-24）

実データ（1,708 種 / 2,527 刷り / `dataVersion` 2）/ Windows / `LOVECA_DIST_DIR` 指定 / debug ビルド。

★**M3 の目的は「静かな縮退が実際に見えること」の確認であり、性能ではない。**
起動の内訳は §9-3 と同傾向（ウォーム合計 414.9 / 428.5 ms）だったので測り直していない。

★★**確認は「出る側」と「出ない側」を対で行った。**★★
出る側だけ見ると、**常に出している実装**でも合格してしまう（D-10 の教訓）。

| # | 手順 | 結果 |
|---|---|---|
| 1 | `LOVECA_DIST_DIR` 指定で起動 → R2 → カード | ○ **2,527 件**。2 ペイン（1280 論理px） |
| 2 | `ライブ`（3 文字） | ○ **1,015 件**。★経路表示も打ち切りも**出ない** |
| 3 | ★`花帆`（2 文字） | ○ **51 件** + 「2 文字以下のため、部分一致で検索しました。3 文字以上にすると別の方法で検索し、並び順も変わります。」 |
| 4 | ★`日野下花帆`（5 文字） | ○ **51 件**（同じ当たり）で、★経路表示が**消える**。#3 と対になる |
| 5 | ★`ー` を既定上限（2000）で | ○ **1,668 件**（＝ **1,034 種**。D50 / `UI技術検証メモ.md` §4-4 の実測と一致）。★打ち切りは**出ない** |
| 6 | ★`LOVECA_SEARCH_LIMIT=50` で起動し `ー` | ○ **69 件**（50 種）+「該当が多いため上限 50 件で打ち切りました（50 件を表示）。検索語を足すと絞り込めます。※上限は検証用の `LOVECA_SEARCH_LIMIT` により既定から変更されています。」★#5 と対になる |
| 7 | 同上の起動でホーム（R2） | ○ 「検索結果の上限が 50 件に変更されています（検証用）」の Notice |
| 8 | ★`LOVECA_SEARCH_LIMIT=abc` で起動 | ○ **起動は通る**。既定 2000 に戻り、詳細に **「指定された値: abc」「使う上限: 2000 件（既定）」「1 以上の整数を指定してください。」** |
| 9 | `[boot]` ログ | ○ `searchLimit=2000` / `searchLimit=50 (★LOVECA_SEARCH_LIMIT で上書き)` |

★**#6 では打ち切りと経路の 2 つが同時に出た。**別々の行・別々のアイコンで読めることを確認した。
3 つ目（刷りが 1 件も無いカード / D-8）は**実データでは起こらない**
（配信から商品が消えたことがまだ無い）ため、実 DB のテストで
`deleteExpansion` を呼んで**実際に孤児を作って**確かめている
（`test/data/card_search_degradation_test.dart`）。

### ★ M3 で決めたこと

| 論点 | 結論 |
|---|---|
| 縮退の型 | ★**`sealed SearchDegradation`**。4 つ目を足したとき、描画側の `switch` の拾い漏れが**コンパイルエラーになる**（D53 と同じ理由）。「見せ忘れ」を静かに起こさない |
| 縮退の文面 | ★**内部語彙（孤児 / cardNumber / trigram / 索引）を出さない。1 縮退 = 1 行で、対処まで書く。** 3 つが同じ見た目だと「なんか出てる」で無視される |
| デバウンスの持ち主 | **Store**（`ui/common/debouncer.dart` を使う）。入力欄は自前の `TextEditingController` を持つ ——Store の `query` で駆動すると**打鍵中にカーソルが飛ぶ** |
| 検索と絞り込みの合成 | `filter.apply(all)` ∩ ヒットした cardNumber。★**絞り込みを変えても検索は走らない**（D48） |
| 空の検索語 | ★**「0 件」ではなく「絞り込みなし」。** `CardSearchMode.empty` を 0 件に畳むと全件が消える |
| 結果の追い越し | ★**通し番号で捨てる。** 遅い検索が後から返って新しい結果を上書きすると、「打った語と違う結果が出ている」が無言で起きる |


### ★ 9-6. M4 の実機確認（2026-08-24）

実データ（1,708 種 / 2,527 刷り / `dataVersion` 2）/ Windows / `LOVECA_DIST_DIR` 指定 / debug ビルド。

★**M4 の目的は「Release 1 の骨格が端から端まで通ること」の確認であり、性能ではない。**
起動の内訳は §9-3 と同傾向（ウォーム合計 414.6 / 439.6 ms）だったので測り直していない。

★★**確認は「起きる側」と「起きない側」を対で行った。**★★
出る側だけ見ると、**常に出している実装**でも合格してしまう（D-10 の教訓）。

| # | 手順 | 結果 |
|---|---|---|
| 1 | R2 → デッキを開く（1600 論理px） | ○ 2 ペイン。一覧・デッキ・**P1 常設**が同時に見える |
| 2 | ★**一覧 → デッキ**（ドラッグ） | ○ 1 枚入る。セルに枚数バッジが出る |
| 3 | ★**デッキ内の並べ替え**（★**行の余白**を掴む / D46） | ○ 入れ替わる。落ちる位置の帯も出る（D47） |
| 4 | ★**デッキ → ゴミ箱**（同じく行の余白を掴む） | ○ 行ごと外れる。P1 の枚数も減る |
| 5 | ★並べ替えたら予告が出る（決定 D65） | ○ 「並び順はこの画面の中だけです。開き直すとカード番号順に戻ります。」 |
| 6 | ★**区分をまたいで足しただけでは出ない**（対） | ○ 出ない ——**最初は出た。**下の「実機で見つけた誤検知」 |
| 7 | ★4 枚制限（6.1.1.2） | ○ メンバー 4 枚で「+」が無効。★**パラレル違いも合算**（`-001-P` 3 枚 + `-001-R` 1 枚 で両方無効） |
| 8 | ★**保存 → プロセスを落として再起動 → 中身が残る** | ○ メンバー 4 / エネルギー 1 がそのまま |
| 9 | ★**並び順は戻る**（#5 の予告どおり） | ○ 保存前 `-001-R`, `-001-P` → 再起動後 `-001-P`, `-001-R`（カード番号順） |
| 10 | ★`revision` は編集で動かず、保存 1 回で +1 | ○ DB を直接見て `revision = 2`（作成 0 → 保存 2 回）。★間に増減・並べ替え・削除を何十回も挟んでいる |
| 11 | 1 ペイン（800 論理px） | ○ デッキペインは横に出ず、「デッキを見る」から**同じ Widget**がモーダルで出る |
| 12 | ★**2 ペインでは「デッキを見る」を出さない**（対） | ○ 出ない |
| 13 | ★R4 の絞り込みボタンが 2 ペインで出ない | ○ 出ない（M4 で直した不具合。下記） |

#### ★ 実機で見つけた誤検知 — 縮退の判定が平坦なリストを見ていた

エネルギーを 1 枚入れたあとにメンバーを入れただけで、
**並べ替えていないのに**「並び順はこの画面の中だけです」が出た。

原因は `isReordered` が**ドラフトの平坦なリスト**を正規化列と比べていたこと。
画面は区分ごとに分けて出す（メンバー → ライブ → エネルギー）ので、
**平坦には `[E, M]` でも見た目は `[M][E]` で正規化列と一致している。**

→ 判定を「**各区分の中が `printingId` 昇順か**」に直した。
`test/data/deck_repository_test.dart` に**出る側と出ない側**を対で足してある。

★★**ウィジェットテストでは捕まらなかった。**★★
テストは 1 区分だけのデッキで並べ替えを見ていたため、区分をまたぐ経路を通っていない。
**実機確認が拾った不具合であり、M4 に実機確認を課している理由そのもの。**

#### ★ M4 で直した不具合 — 器の外から `isTwoPaneOf` を呼んでいた

`_PaneScope` は `PaneScaffold` の内側にしか無いので、`Scaffold.appBar` から
`PaneScaffold.isTwoPaneOf` を呼ぶと**常に false** になる。
R4 の絞り込みボタンがそれで、**2 ペインで絞り込みパネルが見えているのに
同じものを開くボタンも出ていた**（M3 まで）。

→ `PaneScaffold` に `header` スロット（全幅・両ペインの上・`_PaneScope` の内側）を足し、
検索欄・結果ヘッダ・ボタンをそこへ移した。
★出ない側も対でテストしてある（出る側だけだと、常に出す実装でも通る）。

### ★ 9-7. U8 の検算（2026-08-24）— **840 は動かさない**

★**測る前に「削らないもの」を決めてある**（`lib/src/ui/deck/deck_pane.dart` の doc）。
名前+保存 / メモ / 中身の一覧 / **ゴミ箱の常設バー** / 縮退 / **P1 の常設** の 6 つ。
**320 に収まるよう表示を削ってから測ると検算にならない。**

★★**測定値の格が 2 段ある。混ぜないこと。**★★

| 段 | 手段 | 値 | 格 |
|---|---|---:|---|
| (1) | ウィジェットテスト（`test/ui/deck_pane_width_test.dart`） | 溢れない下限 **151** 論理px | ★**テスト用フォント**。「構造の下限」であって**読める幅ではない**（名前も刷り番号も ellipsis で潰れるだけ） |
| (1) | 同上 | 採用値 320 で行の名前に残る幅 **177** 論理px | ★固定幅の引き算なので**フォントに依らない**。回帰ガードとして固定 |
| (2) | 実機（Windows / debug / 実データ） | **240**: 刷り番号の行が切れる（`PL!-bp1-000-LLE・…`） | ★**正** |
| (2) | 同上 | **288**: 同じ行が最後まで読める → **自然な最小幅は 288 付近** | ★**正** |
| 採用 | | **320**（余裕を持たせた） | |

**しきい値の算数**: 一覧 3 列 `3 × 140 + 6 × 4 = 444` + 仕切り 1 + **320** = **765 ≤ 840**。
→ ★**840 を動かす理由が無い。** Material 3 の expanded 境界（840dp）から外れずに済む。

**根拠の格は D61 と同じ 2 段のまま更新する。**

| # | 根拠 | 格 |
|---|---|---|
| (a) | Material 3 の window size class の expanded 境界が 840dp | 外部の標準。**確か**（変わらず） |
| (b') | 一覧 3 列 444 + 仕切り 1 + デッキペイン **320** = 765 | ★**実測に置き換わった**（デッキペインの 320 は 288 の実測に余裕を足した値） |

★**debug / profile でこの寸法は変わらないと断定してよい。**
レイアウトは同じ RenderObject・同じ制約・同じフォントで計算され、
`kDebugMode` は制約にもフォントにも影響しない。
★§9-3 の注記（**時間**は debug と profile で違う）とは**別の話**である——
**時間は違うが寸法は同じ。**
唯一違うのは `flutter test` の**テスト用フォント**であって、debug/profile の差ではない。
だから上の表で (1) と (2) を分けてある。

#### ★ しきい値そのものも実機で確かめた（2026-08-24）

`GetClientRect` でクライアント幅を読みながらウィンドウを縮めた。
★**ウィンドウ矩形は枠を含むので、論理px はクライアント幅のほう**（DPR 1.0 の環境）。

| クライアント幅 | 結果 |
|---:|---|
| **838** | 1 ペイン |
| **840** | **2 ペイン** |

→ しきい値ちょうどで切り替わる。**厳密な 840 / 839 の境目は
`test/layout/pane_scaffold_test.dart` が固定している**（実機は枠の分だけ粗い）。

★★**実測して分かったこと: 840 のとき一覧は 3 列ではなく 4 列になる。**★★
デッキペイン 320 と仕切り 1 を引いた残りは 519 論理px で、
`maxExtent 140` なので `ceil(519 / 140) = 4` 列・**セル幅は約 123 論理px** になる。
見積り (b) の「3 列 = 444」は**最低限必要な幅**の見積りであって、実際にはもっと詰まる。

★これは D42 の測定条件（セル幅 **120 物理px**）とほぼ一致しており、
**キャッシュと `ResizeImage` の見積り（1 枚 74 KB / 1000 枚）がそのまま通じる幅**である。
偶然だが、しきい値を上げる理由がもう 1 つ無いことを意味する。

→ **U8 のうち M4 分は解消。** ★**Phase 5（実機のタブレット）での見直しは残っている。**


### ★ 9-8. デッキの並び順は保存されない（決定 D65 / M4 で判明）

★★**着手して初めて分かった。本文書にも整合性チェックにも書かれていなかった。**★★

| 事実 | 出典 |
|---|---|
| `deck_entries` に順序列が無い。主キーは `{deckId, printingId}` | `loveca-db/lib/src/schema/tables.dart:289-297` |
| `DeckDao.byId` は entries を `ORDER BY printing_id` で読む | `loveca-db/lib/src/dao/deck_dao.dart:147` |
| ★**`DeckDao.all` は entries に `ORDER BY` を持たない** | 同 `:171-175` |
| R2 は `all()` の `Deck` をそのまま R3 へ渡す | `deck_list_page.dart:81` |

→ **並べ替えても保存されない**うえに、**取得経路で並びが違いうる**
（所見は `ルール整合性チェック_v1.06.md` **D-11**、方式は **決定 D65**）。

#### M4 の判断 — 実装したうえで、失うものを言う

| # | 採ったこと | 理由 |
|---|---|---|
| 1 | **並べ替えを実装する** | D46（並べ替えと持ち出しの両立）を**本経路で確かめる唯一の機会**。ここを飛ばすと spike の知見が本実装で成立するか永久に分からない |
| 2 | **開いた直後の並びを正規化**（区分順 → `printingId` 昇順） | 取得経路の差を画面に持ち込まない。★`byId` の並びを区分ごとに再現しているので、3 の予告が**実際と一致する** |
| 3 | ★★**「開き直すとカード番号順に戻ります」まで書く**★★ | 「保存されません」だけでは**次に開いたとき何が起きるか**が伝わらない。**戻る先**が分かれば驚きにならない |
| 4 | **並べ替えでは保存ボタンを光らせない** | 押せると「保存したのに戻る」という最悪の形になる。`isDirtyAgainst` は並びを見ない |
| 5 | ★**判定は「区分の中が昇順か」で行う** | 平坦なリストで比べると、区分をまたいで足しただけで出る。**実機で実際に出た誤検知**（§9-6） |

★**採らなかった案**: 「並べ替えを出さない（固定順で表示する）」。
D46 を本実装で確かめる機会を失うため。
★**採ってはいけない案**: 「実装するが何も言わない」。
CLAUDE.md が繰り返し戒めている「痕跡を残さず落とす」に該当する。

#### 根治

**決定 D65** に `ord` 列の移行方式（`schemaVersion` 2→3 / backfill SQL /
`all` にも `ORDER BY` を足すこと / 主キーは変えないこと）まで書いてある。
実施は **`loveca_db` を次に触るとき**（§10 の **U10**）。


### ★ 9-9. M5 の実機確認（2026-08-24）

実データ（1,708 種 / 2,527 刷り / `dataVersion` 2）/ Windows / `LOVECA_DIST_DIR` 指定 / debug ビルド。

★**M5 の目的は「ペイン抽象が 2 通りの器で成立すること」の確認であり、性能ではない。**
起動の内訳は §9-3 と同傾向（ウォーム合計 454.0 ms）だったので測り直していない。

| # | 手順 | 結果 |
|---|---|---|
| 1 | ★**2 ペイン × R4**: セルを叩く | ○ secondary が詳細に変わり、**一覧は残る**。`normal` の絵が実際に出る |
| 2 | 同上: 閉じる | ○ 絞り込みパネルに戻る |
| 3 | ★**2 ペイン × R3**: 未保存のまま叩く | ○ 帯に「デッキ編集中 / **未保存の変更があります（戻れば残っています）** / デッキに戻る」。デッキペインは隠れるが編集は残る |
| 4 | 同上: 「デッキに戻る」 | ○ デッキが戻り、**名前の編集も未保存表示も残っている** |
| 5 | ★**1 ペイン × R4 / R3**（820 論理px） | ○ どちらも R5 ルートが開く（AppBar の戻る）。中身は 2 ペインと同じ |
| 6 | ★**複数キャラ名 / 複数グループ名** | ○ `LL-bp1-001` で 上原歩夢 / 澁谷かのん / 日野下花帆、虹ヶ咲 / Liella! / 蓮ノ空 |
| 7 | ★★**色ハートと `bladeHeartEffects` が混ざらない** | ○ `AWOKE` で **ブレードハート「青 1」** と **ブレードハートのアイコン「ドロー 1」** が別見出し + 「ハートの合計には数えません」 |
| 8 | ★`GRAY` / `SCORE` | ○ `Dream Believers` で 必要ハート「**無 4**」/ アイコン「**スコア 1**」。★色の見出しは**出ない**（対） |
| 9 | ★★**エネルギーは空の欄が消える** | ○ `PL!-bp1-000` は キャラクター と この刷り だけ。**壊れて見えない** |
| 10 | ★**ほかの刷りの切替** | ○ `PL!HS-bp1-019` の L / **SECL☆** が並び、叩くと絵と「この刷り」（BP01 → **BP05** / SECL（パラレル））が入れ替わる |

#### ★★ 実機で分かったこと — ライブの札は横長である ★★

最初 `BoxFit.contain` を縦長（200:279）の枠に入れていたため、
**ライブの絵が上下に大きく余白を作った。**

→ 実データの thumb **2,527 枚を全数計測**した（2026-08-24）。

| 種別 | 寸法 | 比 |
|---|---|---|
| メンバー | 200×279（1,036 枚）/ 200×280（483 枚） | 縦長 **0.717** |
| エネルギー | 200×279（484）/ 200×280（228）/ 200×273（5） | 縦長 **0.717** |
| ★**ライブ** | **200×143（290 枚）/ 200×144（1 枚）** | **横長 1.399** |

★1px の揺れ（279 / 280）は 0.4% なので 1 つの値に丸めてよい。**ライブとの差は丸められない。**

→ 詳細の枠は**種別で選ぶ**（`cardAspectRatioOf`）。`ui/common/card_thumb.dart`。

★★**`docs/UI技術検証メモ.md` §3 の「thumb の原寸 200×279」は
メンバーの値であって全種ではない。**★★ 同メモにも注記を足した。

#### ★ 一覧（`CardGrid`）は 200:279 のままにしてある

セル幅 120 物理px という **D42 の測定条件がその比で得られている**ため、
比を変えると `ResizeImage` の効果もキャッシュの見積りも測り直しになる。
また `BoxFit.cover` なので**ライブのセルは左右が切れている。**
→ 一覧をどうするかは別の設計判断であり、§10 の **U11** に登録した。

#### ★ 「見つからない printingId」の扱い（テストが何を守っているか）

★★**この経路はいま UI から到達しない。**★★
R3 / R4 の一覧セルは `MasterCatalog.rows`（`printings JOIN cards`）から作られるので、
必ずカタログに在る printingId しか渡ってこない。

**それでも `CardDetailView.of` が null を返せる形にし、テストで固定してある。**
到達させる予定のある経路が 2 つあるからである。

| いつ | どこから未知の printingId が来るか |
|---|---|
| **Phase 4（同期）** | 他端末が新しいマスタで作ったデッキが降ってくる。`Deck.masterDataVersion`（P5）と決定 D35 は**まさにこれを検出するため**にあり、M4 のデッキペインは未知の刷りを「表示できないカード」として出している。★**そこから詳細を開けるようにした瞬間に到達する** |
| **M6（共有形式インポート / §2-5）** | cardNumber → printingId の逆写像が一意でなく、マスタに無い cardNumber もありうる |

★★**消してよいのは上の 2 つが「未知の printingId を持ち込まない」と確定したときだけ。**★★
「念のため」ではない。判断材料を `lib/src/data/card_detail.dart` と
`test/data/card_detail_view_test.dart` の doc に同じ内容で書いてある。

#### ★ テストの落とし穴 — `ListView` は下を作っていない

詳細は `ListView` なので、**下のほうのセクションは画面外だと要素が存在しない。**
`find` に出ないのは「無い」のではなく「**まだ作っていない**」。

★★**「出ないこと」を見るテストは、末尾までスクロールしてから見ないと常に通る。**★★
D-10 と同じ形なので、`test/ui/card_detail_test.dart` に
`_scrollDetailTo` を置き、出ない側の検査は必ず末尾まで送ってから行っている。


### ★ 9-10. M6 の実データ確認（2026-08-24）

実データ（1,708 種 / 2,527 刷り / `dataVersion` 2）/ Windows / debug ビルド。

★**M6 の目的は「D39 / D35 の出口が塞がること」の確認であり、性能ではない。**
起動の内訳は §9-3 と同傾向（ウォーム合計 453.7 / 439.7 / 496.6 ms）だったので測り直していない。

★★**確認は「出る側」と「出ない側」を対で行った。**★★

| # | 手順 | 結果 |
|---|---|---|
| 1 | `LOVECA_DIST_DIR` 指定で起動 | ○ `rows=2527 cards=1708 printings=2527 dataVersion=2` / `searchLimit=2000` / ★**Notice 無し（出ない側）** |
| 2 | ★`LOVECA_SEARCH_LIMIT=50` で起動 | ○ `searchLimit=50 (★LOVECA_SEARCH_LIMIT で上書き)` + Notice「検索結果の上限が 50 件に変更されています（検証用）」。#1 と対になる |
| 3 | ★★**壊れた dist で起動**（下記の手順）★★ | ○ Notice「1 件の商品ファイルを取り込めませんでした」+「データ版は据え置きです（失敗したファイルは次回再取得されます）」 |
| 4 | ★同上: `import_issues` の中身 | ○ `cards/BP01.json` / `unknownKey` / `Invalid argument(s): unknown heart color: CYAN` / 回数 1 |
| 5 | ★同上: **UI 層が読む形**（`MasterRepository.outstandingImportIssues()`） | ○ 件数 1 / 種別「このアプリが知らない値が入っていました」/ ★`supersededByNewerFile=true` |
| 6 | ★同上: **ユーザデータが無事か** | ○ `decks` **2 件**・`cards` 1,708・`printings` 2,527 が残る。`data_version` は **2 のまま**（D39 の据え置き） |
| 7 | ★DB を戻して再起動 | ○ 未解消 **0 件**・Notice 無し。#3 と対になる |
| 8 | ★**共有形式の書き出し**（実カタログ） | ○ `-SD` 3 + `-SD2` 1 → **`PL!N-sd1-001 x4` の 1 行**。★未知の刷り `UNKNOWN-1 x2` は落ち、**落ちたことが返る**（2 枚 / 決定 D35） |
| 9 | ★★**往復すると刷りが潰れる**★★ | ○ 読み戻すと **`-SD` に 4 枚**。`-SD2` の 1 枚は残らない——**開示どおり** |
| 10 | ★**既定の刷り**（決定 D68） | ○ `PL!N-sd1-001` の 3 刷り（`-P` パラレル / `-SD` NSD01 / `-SD2` NSD02）から **`-SD`** を採り、`非パラレル複数=true` が立つ |
| 11 | ★**3 種類の取り込めなかったもの**が別枠で返る | ○ `unknown=[(ZZ-none-001, 2)]` / `unparsed=[これは行ではない]` / `overLimit=[(LL-bp1-001, 5)]` |

★★**画面の操作（クリック）は `flutter test` のウィジェットテストで固定してある。**★★
Windows の GUI を機械的に叩く手段が無いため、**実データで確かめたのは
起動経路とデータの経路**である。どちらが何を担保しているかを混ぜない。

#### ★ 壊れた dist の作り方（再現手順）

★★**`loveca-data/data/` には一切触らない**（CLAUDE.md §7-1）。**scratch へ写して壊す。**★★

1. dist を作業用ディレクトリへ丸ごとコピーする
2. `cards/BP01.json` の `"BLUE"` を `"CYAN"` に置換する（`HeartColor.fromKey` が `ArgumentError`）
3. ★`manifest.json` の当該 path の `hash` を**実体に合わせて再計算**する
   （`planUpdate` はハッシュ差でしか再取得しないので、これを忘れると**壊したファイルが読まれない**）
4. `manifest.json` の `dataVersion` と `version.json` の `dataVersion` を上げ、
   `version.json` の `manifestHash` も再計算する
5. `LOVECA_DIST_DIR` をそこへ向けて起動する

★★**始める前に `loveca.db` を退避し、終わったら戻して sha256 で一致を確かめること。**★★
**D-13 により、壊れた記録は元の dist に戻しても消えない。**
「戻したつもり」で終わらせない——実際に一致を機械的に確かめる。

```
%APPDATA%\com.example\loveca_ui\loveca.db
```

#### ★ M6 で確かめられた D-13（`ルール整合性チェック_v1.06.md`）

`master_files` は path ごとに**現在のハッシュ 1 件**しか持たないのに、
`import_issues` の主キーは `{path, hash}`。
配信側が直すと**内容が変わるのでハッシュも変わり**、取り込めても記録は残る。

★実機でも `supersededByNewerFile=true` を確認した。
**根治の方式は D-13 に書いてある**（取り込み成功時に同じ path の行を消す）。


### ★ 9-11. M6 で決めたこと

| 論点 | 結論 |
|---|---|
| 共有形式の書式 | ★**行指向**（決定 D67）。JSON を採らない——手で貼る前提で、1 文字壊れて全体が読めなくなる形は用途に合わない |
| 未解釈の行 | ★**未知 cardNumber と別枠**。原因も対処も違う（書き直す / データを更新する）。M3 の縮退 3 種と同じ理由 |
| 既定の刷り（U7） | ★**非パラレルのうち `printingId` 昇順の先頭**（決定 D68）。開示するのは**非パラレルが複数**の 19 種だけ——600 種に警告すると 19 種の意味が消える |
| 曖昧さと確認 | ★**曖昧さは「断り」ではない。** 既定を選んであり差し替えもできるので、取り込めなかったものは無い。ボタンの文言も変えない |
| 4 枚超過 | ★**弾かず丸めず、入れて検証に出す**（決定 D69）。判定は `DeckValidator` が唯一（D28） |
| 取り込み先 | ★**R3 のドラフトを置き換える。** 保存しなければ戻せるので「置き換えます」と言い切れる。**合算しない**——合算すると 4 枚超過が起きやすく、しかも戻せない |
| 取り込みの入口 | ★**R3 の 1 本だけ**（§2-2）。R2 からは「新規デッキ → 開く → 取り込む」で届く |
| `save` の畳み方 | ★**明示コンストラクタ**（決定 D70）。`copyWith` ではカバーを外せない。受けは `Deck.toJson()` のキー凍結 |
| `LOVECA_SEARCH_LIMIT` を R6 に出すか | ★**上書きされているときだけ出す。** 常設すると検証用の口が本番の設定に見える |
| 「データを更新」 | ★**再起動を伴う操作**（決定 D56）。「いま取り込む」ボタンを置かない |

#### ★ M6 で表面化した設計の穴 — 帯は押した場所から見えない

R6 で設定を保存すると「反映されるのは次の起動からです」の帯を一覧の**先頭**に出していたが、
**下のほうの項目を触った利用者には見えない。**

→ 押した場所でも言うように SnackBar を足した。
★**ウィジェットテストが拾った。** `ListView` の下のほうを叩くには
`scrollUntilVisible` が要り、そのとき「帯が画面外にある」ことに気づいた。

#### ★ M6 で踏んだテストの罠（3 つとも M5 と同じ形）

| 罠 | 何が起きたか |
|---|---|
| 横スクロールの中の `CardThumb` | 幅が無限に来て `BoxConstraints forces an infinite width`。`SizedBox` で閉じる |
| `InputChip` の削除アイコン | 既定は Material の版で変わる。**明示しないとテストが版に縛られる** |
| ダイアログ / `ListView` の下のほう | 叩いても**外れるだけで例外にならない**（`warnIfMissed` の警告が出るだけ）。`ensureVisible` / `scrollUntilVisible` してから叩く |

★★**3 つ目は M5 §9-9 の「`ListView` は画面外を作らない」と同じ形である。**★★
あちらは「出ないこと」の検査が常に通る罠、こちらは「押したつもりが押していない」罠。
**どちらも「見えていない要素は無い要素ではない」に由来する。**


### ★ 9-12. U11 の解消と実データ確認（2026-08-24 / 決定 D72）

実データ（1,708 種 / 2,527 刷り / `dataVersion` 2）/ Windows / `LOVECA_DIST_DIR` 指定 / debug ビルド。

★**目的は「ライブが正しい比で描かれること」と「メンバー / エネルギーが変わっていないこと」の確認**であり、性能ではない。

| # | 手順 | 結果 |
|---|---|---|
| 1 | ★**混在した一覧**（2,527 件 / 絞り込みなし） | ○ ライブが**切れず・ぼやけず**横長で出る。★**メンバー / エネルギーは従来どおりタイル全面** |
| 2 | ★**種別「ライブ」だけ**（291 件） | ○ 291 件 / 全 2527 件。★**判定は下記** |
| 3 | ★**R3 でライブのセルの帯（タイル上端 +8px）を掴む** | ○ ドラッグが始まり、デッキへ入る（`ライブ 1 / 12`）。★**feedback も横長** |
| 4 | ★**デッキ行のライブ** | ○ 34 の枠に横長で出る。★**行の余白（上端 +5px）から掴めて**ゴミ箱へ持ち出せる |
| 5 | ★**P3 カバー選択にライブ** | ○ 横長で出る。★**帯（絵の上）を叩いても選べる**（枠が太くなり「カバーを外す」が活性化） |
| 6 | ★**読み込み中の下地** | ○ 速く送ると**メンバーはタイル全面の下地 / ライブは横長の下地だけ**。★**形が違うので取り違えない** |

#### ★★ 目視 #2 の判定 — 引き金 1 / 2 とも当たらなかった ★★

★★**「見てから決める」と「もう実装したから」で許容に傾く。だから見る前に線を引いた。**★★

**算術（目視前に確定していた）**: セル論理幅 W とすると
`maxCellExtent 140` と `crossAxisCount = ceil(幅 / 140)` のため **W は常に 140 未満**。

| | 式 |
|---|---|
| ライブの札の高さ | `W / 1.3986` = **0.715W** |
| 行間の空白 | `0.340W + spacing 6 + 0.340W` = **0.680W + 6** |

「空白 ≤ 札の高さ」の成立条件は `W ≥ 171`。★**`maxCellExtent 140` の限り起こりえない。**
つまり**ライブだけに絞ると札と札の隙間が札より広くなることは、見る前から確定していた。**
→ **疎であること自体は退避の理由にしない。**

**硬い引き金（当たれば見た目の好みに関係なく退避する、と決めてあった）**

| # | 引き金 | 実機の結果 |
|---|---|---|
| 1 | 帯が「絵が読み込めていない / 失敗した」に見える | ★**当たらない。**帯はページ背景（`surface`／ほぼ白）で、未読込の下地は `surfaceContainerHighest`（灰）。**色も形も違う**（#6 で実際に並べて確認） |
| 2 | 行の対応が取れない（グリッドとして成立していない） | ★**当たらない。**9 列が厳密に揃い、行は等間隔の帯として読める |

→ **退避しない。**代わりに**未決 U12 として登録**した（§10）。退避先（却下案）と
「それが D42 を動かさないこと」まで書いてあるので、**そのとき検討をやり直さないこと。**

#### ★ この作業で「絶対に採らない」と決めたもの

**`maxCellExtent 140` / `spacing 6` / 混在時のタイル比 200:279 / ライブを 2 列ぶんに広げる案。**
★いずれも**セル幅 = D42 の測定条件そのもの**を動かす。
2 列案は `cacheWidth` が 120 → 240、デコードが 41 KB → 165 KB（4 倍）になる。
**採るなら別の決定番号で、再測定を伴って行う。**

#### ★ 見た目の副作用（記録）

R3 の一覧セルの「+」と枚数バッジは**タイルの角**に置いてある。
ライブのセルではそれが**絵の外（帯の中）**に出る。実機で確認したが**押しにくくはない**ので変えていない。
★変えるなら、ラッパ（`_catalogCell`）が枠の矩形を知る必要があり、比の知識が広がる。

---

## 10. 未決一覧

★**推測で埋めない。** 判断の時期を併記する。

| # | 論点 | いつ判断するか |
|---|---|---|
| **U1** | **モバイルの画像供給経路**（同梱 / 初回取得）。D43 に触れる | **Phase 4**（配信経路の確定時） |
| **U2** | **`image_sizes` を変えたときの `imageHash` 据え置き**（§5-4）。`loveca-data` の変更を伴う | **Phase 4**。`ルール整合性チェック_v1.06.md` D-4 に記録済み |
| **U3** | **モバイルのグリッドに `thumb` で足りるか**（§7-1） | **Phase 5 着手時** |
| **U4** | **投影クエリを `loveca_db` へ移すか**（§4-5） | **Phase 5**（スマホが同じ投影を要すると確定したとき） |
| **U5** | **盤面のカード表示に `thumb` で足りるか**（`normal` が要るか）。★**種別ごとに見ること**——ライブの thumb は **200×143** なので、横に大きく出す盤面ではメンバーより先に解像度が足りなくなる（決定 D72） | **Phase 3b**（UI技術検証メモ §10-5 の再掲） |
| **U6** | **先読みを採る条件**（「スクロールが止まったら 1 画面分」などの具体値） | 要求が出たとき（同 §10-4 の再掲） |
| ~~**U7**~~ | ~~**共有形式インポートの既定の刷りの選び方**~~ → ★**M6 で解消（決定 D68）。**非パラレルのうち `printingId` 昇順の先頭。UI で差し替えられる。開示するのは**非パラレルが複数**の 19 種だけ | ~~M6~~ **解消** |
| **U8** | ~~★**ペインの切替しきい値 840 論理px は暫定値**~~ → ★**M4 で検算し 840 を確定**（§9-7。実機の自然な最小幅 288 / 採用 320 / 444+1+320=765 ≤ 840）。**残るのは実機のタブレットでの妥当性** | ~~M4~~ / **Phase 5**（実機） |
| ~~**U11**~~ | ~~★**一覧（`CardGrid`）はライブのセルを `cover` で切っている**~~ → ★**2026-08-24 に解消（決定 D72）。**★**箱の寸法は種別で変えず、中に `cardAspectRatioOf` の枠を作って中央に置く。**タイルは 200:279 のままなので **D42 の測定条件は 1 つも動いていない**（§9-12） | ~~一覧の見た目を次に触るとき~~ **解消** |
| **U12** | ★**ライブだけに絞った一覧は、行間の空白が札の高さより広くなる**（`0.680W + 6` > `0.715W` は `maxCellExtent 140` の限り常に真 / §9-12）。★★**退避先は決めてある**——`rows` が 1 種別だけのとき `childAspectRatio` をその種別の比にする。**`childAspectRatio` はセル高さしか変えないので D42 のセル幅 120 物理px は動かない。**★採らなかったのは「グリッドに寸法の前提が 2 つ生まれる」（§6-6）ためであって、性能ではない。★★**そのとき検討をやり直さないこと**★★ | **一覧の見た目を次に触るとき**（要求が出たら） |
| **U10** | ★**デッキの並び順が保存されない**（`deck_entries` に順序列が無い / §9-8）。方式は決定 **D65** に書いてある | **`loveca_db` を次に触るとき**（D-8 と同じ時点） |
| **U9** | ★**論理削除したデッキを戻す口が無い。**`deletedAt` を立てるだけなので DB には残る（P3）が、UI から復元できない。M2 は確認ダイアログ 1 枚で誤操作を防いでいるだけ。★★**M6 では入れなかった。忘れたのではない**——`DeckDao.softDelete` が `revision` を上げない（**D-9**）のが未解決で、復元時に `revision` をどう扱うかはその判断が先に要る。決めないまま復元を作ると、Phase 4 の同期で**削除と復元の差分検出が両方壊れる** | ★**D-9 を決めたとき（Phase 4）** |
| **U21**（新設 / 実機確認） | ★**詳細検索（R3 / R4）。**いま引けるのは 5 軸だけで、**スキーマにあるのに引けない軸が多数ある**（★索引が建っている 3 本を参照するクエリが 0 件）。★**数は §12-1 の表が正**（索引に数を書かない / **D-15 (f)**）。★論点は 4 つ ——**D48（メモリ上）か SQL か**（★`cards` / `printings` の列は D48 で済むが、**子テーブル由来は「1 行 = 1 刷り」の投影に収まらない**）/ 種別依存の軸は素朴に絞ると他種別が全消え /現コストフィルタは実データの **52% を区別できない** / キーワードは内部語彙。★**内容は §12-1。ここに書かない** | **Phase 3b 完了後**（★SQL を足すなら `loveca_db` を触る時点 = D-8 / D-11 / D-13 と同時） |
| **U22**（新設 / 実機確認） | ★**デッキの並び順をメンバー = コスト降順 / ライブ = スコア降順にする。**★**エネルギーには降順にできる軸が 1 つも無い**（実データ 567 種すべて数値が空）ので「指定なし」は要判断ではなく**事実**。★同値が多く副次キーが要る（`cost` 4 が 251 種）。★★**表示順だけなら `ord` は要らないが、D65 の backfill 基準が「移行の前後で見た目が変わらないこと」なので単独では決められない**★★。★**D65 の訂正ではなく新決定にする**（理由は §12-2）。★**内容は §12-2** | ★**`loveca_db` を次に触るとき**（**U10 / D-11 / D65 の `ord` 実装と同時**） |
| **U23**（新設 / 実機確認） | ★**エネルギーデッキ 0 枚での保存。**★★**要望 3 つのうち 2 つは既に成立している** ——「0 枚でも保存できる」も「0 枚でも盤面を開始できる」も**現状できる**（★2026-08-25 に 6.2.1 を実際に通して確認。例外は出ず、エネルギー 0 枚のまま正規の開始位置に着く）。★★**できないのは「0 枚を完成と表示する」ことだけで、これは 6.1.1.3 に反するので解けない**★★。→ **要望の実体は「12 枚を補完する」である。**補完場所 (a) 保存時 / (b) 盤面の開始時 / (c) 表示だけ を対比してあり、★**(c) は単独では解にならない**。★**内容は §12-3** | **Phase 3b 完了後**（★条文解釈が未決着のまま M-B6 に入れない。M-B6 は 11.10.2 の【要確認】を既に抱えている） |
| **U24**（新設 / 実機確認） | ★**既定のエネルギーカード。**★**`LL-E-002` は実在する**（2026-08-25 実測 / name「エネルギーカード」）。★★**ただし非パラレル刷りが 2 件あり、cardNumber を指定しただけでは刷りが決まらない**★★（**D68 が開示対象にした 19 種の 1 つ**。D68 の規則を流用すると `LL-E-002-PR`）。★選定の根拠が示されていない（5 種のうちなぜ 002 か）。★**本番コードにカード番号のハードコードは現在 0 件**で、書くとこの不変条件を最初に破る。★**内容は §12-4** | ★**U23 の後**（★**一方向に依存する。U23 で (c) を採ると U24 は消滅する**） |

★このほか `docs/UI技術検証メモ.md` §10 の
「タッチ環境は実機未検証」「測定は 1 台・1 解像度・144Hz のみ」は**そのまま有効**。
本文書 §7 がその具体化にあたる。

★**上の未決と §7 は `CLAUDE.md` §8 の「未決項目（着手フェイズから辿るための索引）」に載せてある。**
着手フェイズから辿れないと見落とすため。
**あちらは索引で、内容はこちらにしか置かない**（両方に書くと片方だけ直されて食い違う）。
未決を足したら**索引にも 1 行足すこと。**

---

## 11. ★ dist が解決できていないことの見せ方（決定 D89）

作成日: 2026-08-25。★**実機で 2 人が別々の誤診をしたことを受けて書いた。**

### 11-1. 何が起きていたか（★経路を最後まで辿った）

```
LOVECA_DIST_DIR 無しで起動
  → DesktopDistLocator.locate() が 3 段とも外す（決定 D60）
  → MasterImportOutcome.distMissing == true
  → BootNotice「カードデータを更新できませんでした（前回取り込んだ内容で動いています）」
  → ★NoticeBar は deck_list_page.dart（R2）の 1 箇所にしか無い
  → imageSourceFor() が LocalDirectoryCardImageSource(null) を渡す
  → provider() が常に null（`card_image_source.dart`）
  → ★CardThumb が全カードでプレースホルダのまま
```

★★**症状（絵が出ない）と原因（置き場が無い）が結びついていない。**★★
さらに**文面が症状に触れていない** —— 「データを更新できませんでした」としか言わないが、
実際に起きるのは「**カード画像が 1 枚も出ない**」である（画像は dist からしか読まない / **D43**）。

★**R2 に留まっていれば読める。しかし R4 / R3 / R7 へ移ると読めない。**
`notice_bar.dart` の doc が M1 について書いた「**R4 が暫定のホームだったので結果的に出ていただけ**」と
**同じ形の失敗**である。置き場が 1 ルートに固定されている限り繰り返す。

### 11-2. (1) 症状 —— プレースホルダを撃ち分ける

★★**いま「絵が出ない」理由が 2 つあり、同じ絵になっている。**★★

| 理由 | いまの表示 | 対処の向き |
|---|---|---|
| `imageHash` が空（`build --skip-images` 由来の dist / **D-4** で実際に踏んだ） | プレースホルダ | **データ**の問題 |
| `imagesRoot == null`（dist 未解決） | ★**同じプレースホルダ** | **設定**の問題 |
| ファイルが読めなかった | `_BrokenMark`（★既にある） | — |

→ `CardImageSource` に「**画像の置き場そのものが無い**」を問える口を足し、`CardThumb` が撃ち分ける。

★★**§3-4(2)「『空』と『失敗』を同じ型で表さない」がここでも効く。**★★
`CardSearchDao` が `likeFallback` のコメントで書いた「黙って 0 件を返すのは A-3 と同じ失敗の型」と同型で、
**原因も対処も違うものを 1 つの表示に畳んでいた。**

### 11-3. (2) 原因 —— 帯を `BootGate` 1 箇所に一本化する

`app.dart` の `MaterialApp.builder` は既に `BootGate` を通しており、
**`BootGate` は `BootReady.notices` を持っている。ここが唯一の 1 箇所である。**

- ready のとき、`child`（= Navigator）の**上**に `NoticeBar` を置く
- ★**`notices` が空なら `SizedBox.shrink()`**
- ★**R2 の `NoticeBar(notices: _scope.notices)` は重複するので外す**

★**新しいルートを足した人が忘れられない形にする**のが目的である。
各ルートの `AppBar` にバッジを配る案は、**忘れても何も壊れない**ので採らない
（D66 が「どちらに出すかを決めるのは 1 行だけ」と定めたのと同じ理由）。

★★**事実の確認: `MulliganNotImplemented` / `DeckNotValid` は `BoardNotice`（盤面の帯）であって
`BootNotice` ではない。**★★ R2 の `NoticeBar` には**出ていない**ので、一本化の影響を受けない。
一本化の対象は **`BootNotice` を出す 7 経路**（`boot_controller.dart`）——
検索上限の不正値 / 検索上限の上書き（**D64**）/ 設定ファイルの復旧 / `distMissing` /
`appTooOld` / `failedPaths` と `unhandledPaths` / データ版据え置き。

→ ★★**「R2 だけに出ていたものが全画面に出る」であって「R2 から消える」ではない。**★★
**消えるものが 1 つも無いことをテストで固定する。**

### 11-4. (3) 文面 —— 内部語彙を出さず、次にすべきことを書く

★`dist` は内部語彙である。**利用者には通じない。**

> **カードデータの置き場所が見つかりません。カード画像は 1 枚も表示されません。**
> カードの一覧とデッキは、前回取り込んだ内容で動いています。
> **設定画面で「カードデータの場所」を指定してください。**
> 詳細 → 探した場所（3 段 / `DistSource.label` つき）

★「詳細」ダイアログから **R6（設定・診断）へ飛べるボタン**を足す。3 段解決の結果はそこにある。
★**探した場所を省かない**（決定 D60）。

### 11-5. ★★ 測定条件への影響は M-B4 の実装時に測る ★★

★★**「notices が空なら増えないはず」で済ませない。**★★
M-B2 と M-B3 で「増やさないはず」が**2 回とも実際には動いた**（決定 D83 / D86）。

★**測るのは M-B4 の実装時である**（この文書を書いた時点では実装が無いので測れない）。
★**「測る」と書いたまま誰も測らない状態を作らないため、測る項目をここに固定しておく。**

| # | 測ること | 期待 | 出典 |
|---|---|---|---|
| 1 | `notices` が空のときの盤面の横の下限 (b-1) / (b-2) / (b-3) | **506 / 496 / 696 のまま** | D83 / D86 |
| 2 | `notices` が空のときの **U19（縦 496）** | **変わらない** | D86 |
| 3 | ★**帯が出ている状態の U19** | ★**別の値として記録する**（帯 1 本ぶん増える） | ★**U19 は M-B3 で新設したばかりで、1 本足せば動きうる** |

★**推測で値を埋めない。**下限は `board_min_width_test.dart` と同じ手順（毎回ツリーを捨てて組み直す /
「下限 +1 に収束していないこと」を検査に足す）で測る。

#### ★★ 測った（2026-08-25 / M-B4）★★

| # | 測ったもの | 結果 |
|---|---|---|
| 1 | `notices` 空のときの (b-1) / (b-2) / (b-3) | ★**506 / 496 / 696 のまま**（期待どおり） |
| 2 | `notices` 空のときの **U19** | ★**496 のまま**（期待どおり） |
| 3 | ★**帯が出ている状態の U19** | ★★**560**★★（帯 1 本 = **64**） |
| ★ | **U20**（ソロ / 決定 D88） | (b-1) **394** / (b-2) **496** / (b-3) **584** / 縦 **392** |

★**U20 は「分ける」と判断した** —— `kSoloBoardMinWidth = 988`。
判断基準は**測る前に**宣言してある（`board_min_width_test.dart` の doc /
`docs/決定事項一覧.md` の「D88 / D89 の実装」）。

#### ★★ 測り直した（2026-08-25 / M-B5 / 決定 D90-5）★★

巻き戻しのボタン 2 つが進行バーの `Wrap` に入ったので、**U19 の引き金を踏んだ。**

| # | 測ったもの | M-B4 | **M-B5** |
|---|---|---:|---:|
| 1 | (b-1) / (b-2) / (b-3) | 506 / 496 / 696 | ★**同じ** |
| 2 | **U19（帯なし）** | 496 | ★**同じ** |
| 3 | **U19（帯あり / D89）** | 560 | ★**同じ** |
| ★ | **U20**（ソロ） | 394 / 496 / 584 / 縦 392 | ★**同じ** |

★★**「変わらなかった」を信じる前に、入っていることを機械で確かめた。**★★
`board_min_width_test.dart` の内訳に **`undo-controls` が出ていること**と
**進行バーが 1 行のままであること**を検査として足した。
★**D-10（0 件は「無い」と「見えていない」の区別がつかない）を測定値そのものに適用した。**

理由も読める —— **巻き戻しのボタンは「次へ」と同じ高さ**なので、
`Wrap` が 1 行のままなら段は伸びない。内訳の `progress-bar = 48` は **M-B3 から不変**である。

★**M-B2 / M-B3 / M-B4 は 3 回とも動いた。今回が初めて動かなかった回である。**
「だから次も動かない」ではない —— **次に段を足すときも測る。**

★★**測定中に検知手段が黙る条件を見つけた。**★★
帯を出した状態では**高さ 120 で溢れが 1 件も報告されない**（130 以上では報告される）。
`_search` の「狭すぎれば溢れるはず」がこれを捕まえた。
★D83（溢れは `RenderObject` ごとに 1 回しか報告されない）と**同じ型**なので、
**この検査を外さないこと。**

### 11-6. ★ 固定すること（M-B4 の実装時）

| # | 固定すること | 外すと何が起きるか |
|---|---|---|
| 1 | dist が無い状態で **R2 / R3 / R4 / R7 のどこからでも帯が読める** | 症状の出る画面で原因に辿れない |
| 2 | ★**対照**: dist があるときは帯が出ない | 常に出す実装でも通ってしまう |
| 3 | `imagesRoot == null` のプレースホルダが `imageHash` 空のものと**区別できる** | `--skip-images` の dist と見分けがつかない（**D-4**） |
| 4 | ★**対照**: dist があり `imageHash` が空のときは**従来のプレースホルダのまま** | 撃ち分けが常に片側へ倒れていても通る |
| 5 | 一本化で **`BootNotice` の 7 経路が 1 つも消えない** | 「R2 から消えた」を「全画面に出た」と取り違える |
| 6 | ★§11-5 の 3 つの測定値 | 「増えないはず」が 2 回続けて外れている |

#### ★★ 固定した（2026-08-25 / M-B4）★★

| # | どこで | 備考 |
|---|---|---|
| 1 | `test/boot/boot_notice_bar_test.dart` の「どのルートからでも読める」群 | R2 / R3 / R4 / R7 を**実際に遷移して**見る |
| 2 | 同 「★対: 警告が無ければどのルートでも出ない」 | — |
| 3 | `test/ui/card_art_test.dart` の「置き場が無いことを、データが無いことと区別して出す」 | — |
| 4 | 同 「★★ 対: 置き場はあるが `imageHash` が空 → 従来のプレースホルダのまま ★★」 | ★2×2 の全部を見る |
| 5 | `test/boot/boot_notice_bar_test.dart` の「★★ `BootNotice` の 7 経路が 1 つも消えていない ★★」 | ★**実物の `BootGate`** を通す |
| 6 | `test/board/board_min_width_test.dart` | §11-5 の表に結果を記録 |

★★**5 を書いたその場で D-10 の罠を踏んだ。**★★
同じ型の `MaterialApp` を `pumpWidget` し直すと**要素が使い回され**、
`BootGate` の `initState`（= `BootController.run()`）が**再実行されない。**
7 経路の 2 件目以降が 1 件目の結果を見続けていた。
→ **毎回ツリーを捨ててから組み直す**（`board_min_width_test.dart` と同じ手当て）。

---

## 12. ★ 実機確認で出た機能要望（U21〜U24）

作成日: 2026-08-25。★**実装はしていない。論点・根拠・判断時期・依存だけを固定してある。**

★**ここが内容の正である。** §10 と `CLAUDE.md` §8 は索引であり、1 行ずつしか置かない
（両方に内容を書くと片方だけ直されて食い違う / **D-15**）。

★**実測値の再現手段**（引用値が古くなったときはこれで数え直す）:

```bash
./loveca-data/.venv/Scripts/python.exe -c "import json,glob,collections; c=collections.Counter(); [c.update([x['cardType']]) for f in glob.glob('loveca-data/data/dist/cards/*.json') for x in json.load(open(f,encoding='utf-8')).get('cards',[])]; print(c)"
```

### 12-1. U21 — 詳細検索（R3 / R4）

#### いま引ける軸は 5 つだけ

判定は `CardListFilter`（`loveca-ui/lib/src/data/card_list_row.dart:65-123`）**1 箇所**、
パネルは `loveca-ui/lib/src/ui/browse/filter_panel.dart` で **R3 と R4 が共有**する。

| 軸 | 実体 | 制約 |
|---|---|---|
| フリーワード | FTS5 trigram。2 文字以下は `cards.search_blob` への `LIKE`（**D40**）。上限 2000（**D50**） | 索引しているのは 5 列（`card_number` / `name` / `effect` / `group_names` / `unit_names`） |
| 商品 | `printings.expansion` の `DISTINCT` | ★**商品名ではなく展開 ID**。`products.name` を読む DAO が無い |
| 種別 | `cards.card_type` | 単一選択 |
| コスト | `cards.cost` | ★**「0〜5 の N 以下」だけ**・**種別がメンバーのときだけ**（§4-2 の案 (a)） |
| パラレル表示 | `printings.is_parallel` | ON/OFF |

#### ★ スキーマにあるのに UI からも DAO からも引けない軸

| 軸 | 所在 | 索引 | 現状 |
|---|---|---|---|
| メンバーの所持ハート（色×数） | `card_hearts` kind=`hearts` | ★`idx_card_hearts_kind_color` **あり** | 詳細で表示のみ |
| ライブの必要ハート | 同 kind=`requiredHearts` | 同 | 同 |
| ブレードハート（色） | 同 kind=`bladeHearts` | 同 | 同 |
| ブレードハートのアイコン（DRAW / SCORE） | `card_blade_heart_effects` | 無し | 表示のみ。実データ DRAW 59 / SCORE 37 種（いずれもライブのみ） |
| キーワード | `card_keywords` | ★`idx_card_keywords_keyword` **あり** | ★**UI は意図的に非表示**（`card_detail_pane.dart:155-157`「内部語彙を画面に出さない」） |
| キャラクター名 | `card_names` kind=`character` | ★`idx_card_names_lookup` **あり** | ★**FTS5 にも意図的に入れていない**（`card_search_schema.dart:18-21`。`name` の部分文字列だから） |
| グループ名 / ユニット名の**選択式** | 同 kind=`group` / `unit` | 同 | 全文では当たるが候補一覧を出す口が無い |
| ブレード数 | `cards.blade_count` | 無し | 表示のみ。`CardListRow` に無い |
| スコア | `cards.score` | 無し | 同上 |
| ハート合計 / 必要ハート合計 | `cards.heart_total` / `required_heart_total` | 無し | 詳細の「合計 N」のみ |
| `stats`（ブレード数＋ハート数） | `cards.stats` | 無し | ★**`lib/` の参照が 0 件。**`tables.dart:51` は「**検索・ソート用**の派生値」と書いている（**D-20 と同型**） |
| レアリティ | `printings.rarity` | 無し | ★**`CardListRow` に既に来ている**が `CardListFilter` に条件が無い（§4-2 / **D-15 (h)**） |
| イラストレーター | `printings.illustrator` | 無し | 表示のみ。実データで値があるのは 2,527 刷り中 185 件 |
| 商品名 / 発売日 | `products` | — | ★**読む DAO が存在しない** |
| 複数選択・OR | — | — | 商品も種別も単一選択の `Dropdown` |
| ソート軸 | — | — | `ORDER BY p.expansion, p.printing_id` 固定。変える口が無い |

★★**索引が既に建っている 3 本（`idx_card_names_lookup` / `idx_card_keywords_keyword` /
`idx_card_hearts_kind_color`）は、どれも参照するクエリが 1 本も無い。**★★

#### ★ 論点 1 — D48（メモリ上）か FTS5 か

**既にある方針が 2 つある。**

- `card_search_schema.dart:22-23`「`rarity` / `expansion` は入れない —— **完全一致の絞り込みなので
  `printings` の通常列＋索引で扱う**」→ **数値・完全一致の軸を FTS5 に入れない方針は既に確立している。**
- **D48**「絞り込みはメモリ上で行い SQL を再実行しない」（100〜200 倍速い。全 2,527 行が既にメモリにある）

→ 素直に読めば **D48 側**。★**ただしそれで済むのは `cards` / `printings` 由来の軸だけである。**

| 軸の出どころ | D48 で済むか |
|---|---|
| `cards` / `printings` の通常列（`blade_count` / `score` / `stats` / `heart_total` / `rarity` / `illustrator`） | ○ `CardListRow` に列を足すだけ。SQL は増えない |
| ★子テーブル（`card_hearts` / `card_keywords` / `card_names` / `card_blade_heart_effects`） | ✗ **「1 行 = 1 刷り」の投影に収まらない**（1 刷りに複数行つく） |

→ ★**未決はここ。** 子テーブル由来の軸を出すなら
**(i) 投影の形を変える**（`CardListRow` に `Map` / `List` を持たせる = D48 の「表示に要る列だけ」という前提を崩す）か、
**(ii) cardNumber の集合を返す SQL を足して検索結果と交差させる**（FTS5 の結果と同じ扱い。SQL が増える）か
のどちらかを選ぶ。**どちらを採るかは決めていない。**
★(ii) を採るなら `loveca_db` に手が入るので、**D-8 / D-11 / D-13 と同じ時点**になる。

#### ★ 論点 2 — 種別依存の軸は素朴に絞ると他の種別が全部消える

`loveca-data/loveca_data/normalize.py:362-380` は `card_kind` で分岐しており、
★**`KIND_ENERGY` は `pass`（エネルギーは数値情報を持たない）**。

| 軸 | 値を持つ種別 |
|---|---|
| `cost` / `blade_count` / `hearts` / `heart_total` / `stats` | メンバーのみ |
| `score` / `required_hearts` / `required_heart_total` | ライブのみ |
| `bladeHearts` / `bladeHeartEffects` | 実データではライブのみ |
| （どれも無い） | **エネルギー 567 種すべて** |

→ §4-2 が `cost` で踏んだ罠（「コスト N 以下」で絞るとライブとエネルギーが全部消える）が
**新しい軸のほぼ全てで再発する。**
軸ごとに「どの種別で出すか」を決める（案 (a) の踏襲）のか、
案 (b)（「値なしを含む」チェックを添える）へ方針を変えるのかは**未決**。
★**軸が増えるほど (a) は「出す / 出さない」の分岐が増えることに注意。**

#### ★ 論点 3 — 現在のコスト絞り込みは実データの半分を区別できない（実測）

`_costOptions` は 0〜5 の「N 以下」のみ（`filter_panel.dart:19`）。
実データのメンバー **916 種**の `cost` 分布は **2〜22 の 13 通り**（飛び飛び）で、

```
2:134  4:251  5:52  7:52  8:2  9:137  10:18  11:102  13:80  15:62  17:18  20:7  22:1
```

★**「5 以下」に入るのは 437 種（47.7%）だけ**で、**残る 479 種は互いに区別できない。**
詳細検索を入れるなら、まずここが直る。

#### ★ 論点 4 — キーワードを出すなら内部語彙をどうするか

`card_keywords` の値は `ENTER` / `LIVE_SUCCESS` のような正規化の産物で、
`card_detail_pane.dart:155-157` は **「利用者の言葉ではない」として意図的に表示していない。**
絞り込みに出すなら**日本語（【登場】【ライブ成功時】）への写像が要る**。
★その写像をどこに置くか（配信データか UI か）は決めていない。

#### いつ判断するか

**Phase 3b 完了後**（Release 1 の仕上げ。§7 の 5 項目と同じ時点）。
R3 / R4 は Release 1 の範囲（§1-1）だが、**Phase 3b の実装中に別フェーズを開くと
「1 コミット = 1 論点」が崩れる**。
★**論点 1 で (ii) を採るなら `loveca_db` に手が入るので、D-8 / D-11 / D-13 と同じ時点にまとめる。**

### 12-2. U22 — デッキの並び順

要望: **メンバーはコスト降順 / ライブはスコア降順 / エネルギーは指定なし。**

#### いまの規則がどこにあるか

| 何を | どこに |
|---|---|
| 正規化（開いた直後の並び） | `loveca-ui/lib/src/data/deck_repository.dart:338-349`（`normalizedEntries`） |
| 縮退の判定 | 同 `:368-379`（`isReordered`。「**各区分の中が `printingId` 昇順か**」） |
| 画面の並びの最終地点 | `loveca-ui/lib/src/ui/deck/deck_pane.dart:244-251` |

★★**「メンバー → ライブ → エネルギー」という区分順は決定 D65 の本文に無い。**★★
D65 が書いているのは「区分順 → `printingId` 昇順」までで、
具体的な区分の順は**コードの doc（`deck_repository.dart:328-329`）にしかない。**
→ **変えるときに直す場所が 2 つある**（コードの doc と、下記の D65 への追記）。

#### ★ 事実 1 — エネルギーには降順にできる軸が 1 つも無い

`normalize.py:379-380` の `KIND_ENERGY: pass` により、実データのエネルギー **567 種**は
`cost` / `blade_count` / `score` / `hearts` / `stats` が**全件 null または空**（実測で確認）。

→ ★**「エネルギーは指定なし」は要判断ではなく、数値では並べられないという事実である。**
残る候補は `printingId` / `name` / `expansion` / `rarity` のみで、
★**`printingId` 昇順の据え置きが最も安い**（現行と同じで、D65 の backfill 規則とも揃う）。

#### ★ 事実 2 — 副次キーは要る。ただし「値が無い」の心配は現データでは要らない

実測: メンバー **916 種で `cost == null` は 0 件**（値域 2〜22）。
ライブ **225 種で `score == null` は 0 件**（値域 0〜9）。

→ null の置き場を**いま**決める必要は無い。
★**ただし `Card.cost` / `Card.score` は `int?` なので、型の上では null がありうる。**
新商品で現れたときに黙って先頭へ来ないよう、**どちらの端に置くかは決めておく。**

同値は多い（`cost` 4 が **251 種** / `score` 5 が **39 種**）ので**副次キーは必須**。
★候補は **`printingId` 昇順**（現規則をそのまま副次キーへ降格する）。
カード名を挟むと表記ゆれ（CLAUDE.md §5-(5)）の影響を受ける。

#### ★ 事実 3 — 表示順を変えるだけなら `ord` は要らない。**ただし単独では決められない**

D65 の backfill 基準は ★**「移行の前後で見た目が変わらないこと」**で、
いま `byId` が返す `printing_id` 昇順を凍結すると決めてある（`決定事項一覧.md:1454-1455`）。

→ 表示順を先にコスト降順へ変え、**あとから旧規則で backfill すると
移行の瞬間に並びが `printingId` 昇順へ飛ぶ。**
★★**U22 と U10 / D-11 は同時に決める。**★★

#### ★ 事実 4 — U22 は経路差（D-11）を解消しない

`DeckDao.all` が entries に `ORDER BY` を持たない問題（**D-11**）は**表示順とは別**である。
U22 は「開いたときにどう並べるか」の話であって、永続化の話ではない。

#### ★ 判断 — D65 の訂正ではなく**新決定**にする

1. D65 の主題は「並び順は**保存されない**」という事実と `ord` の移行方式で、**そこは 1 文字も変わらない。**
2. 変わるのは付随的な正規化規則だけで、しかもその文言は **D65 本文になくコードの doc にある**（上記）。
3. 本プロジェクトが「訂正」を使ったのは D77 / D81 / D84（D88 による）のように
   **同じ論点の答えが変わった**場合。今回は D65 が誤っていたのではなく**新しい要求**である。

→ 解くときに**新しい D 番号**を採り、D65 側には「区分内の並びは D9x で置き換えた」と **1 行だけ**追記する。
★**いま採番しない**（番号を予約すると `docs/決定事項一覧.md` §3 と食い違う / **D-15**）。

#### いつ判断するか

★**`loveca_db` を次に触るとき**（**D-11 / D65 の `ord` 実装と同時**。D-8 / D-13 も同じ時点）。

### 12-3. U23 — エネルギーデッキ 0 枚での保存

#### ★ まず要望を事実で分解する —— 3 つのうち 2 つは既に成立している

| 要望の中身 | 現状 | 根拠 |
|---|---|---|
| 0 枚でも**保存できる** | ★**既にできる** | `canSave = isDirty && draft.isValid && !busy`（`deck_edit_store.dart:67`）。`draft.isValid` は**名前が空でないこと**だけ（`deck_repository.dart:136`）。★**`DeckValidationResult` は式に現れない** |
| 0 枚でも**盤面で使える** | ★**既にできる**（下記で実測） | 6.1 違反では止めない（`board_start_dialog.dart:339-341` / **D81**）。止めるのは未知の刷りだけ |
| 0 枚を「**完成**」と表示する | ★**できない** | **6.1.1.3** が 12 枚ちょうどを要求。`deck_validator.dart:208-215` が `energyCountMismatch` を立てる。**0 枚の特別扱いは無い** |

★★**したがって要望の実体は「保存できるようにする」ではなく「12 枚を補完する」である。**★★
0 枚のまま開始すると**エネルギーが永久に 1 枚も出ない** ——
6.2.1.7 で 0 枚、7.5.2 も毎ターン 0 枚。エネルギーは控え室を経由しない閉ループ
（4.9.1 →(6.2.1.7 / 7.5.2)→ 4.7 → 5.10.1 → 10.5.4）で**リフレッシュ（10.2）が無い。**

#### ★★ 実測（2026-08-25）—— 0 枚で 6.2.1 を通すと何が起きるか ★★

★**推測ではない。**`GameSetup.begin` → `dealInitialEnergy` を
**エネルギーの `DeckEntry` を 1 件も持たないデッキ**で実際に通した。

```
config.initialEnergyOnField = 3     ← 6.2.1.7 は 3 枚を要求する
A energyDeck  = 0
A energyField = 0                   ← ★1 枚も動かないまま完了。例外は出ない
A hand        = 6                   ← 6.2.1.5 は正常
A mainDeck    = 8
cursor        = PhaseId.firstActive / StepId.s7_4_1   ← 正規の開始位置
```

対照（同時に確認）: **エネルギー 1 枚なら 1 枚だけ出る**（3 枚要求しても落ちない）。

例外が出ない理由は 5 箇所とも枚数に依存しないため ——
`begin` の 3 つの throw（`game_setup.dart:118-127`）/ 未知の刷りの throw（同 `:141-146`）/
`_buildPiles` の非 null 断言（同 `:264-268`。上の検査に守られている）/
`PlayerState`（`game_state.dart` に **`assert` が 0 件**、`energyDeck` の既定値が `const []`）/
`drawEnergyRandomly` の `if (deck.isEmpty) break;`（`energy_deck.dart:63-65`）。

★★**この確認は使い捨てで行った。恒久のテストは無い。**★★
既存で最も近いのは
`loveca-core/test/energy_deck_test.dart:116-127`（`drawEnergyRandomly` を直接・`count` は 1）と
`loveca-ui/test/support/board_fixture.dart:48-53`（エネルギー **3 枚**を使い切る）で、
**どちらも「入口が 0 枚」ではない。**
→ ★**U23 を解くときに `loveca-core/test/game_setup_test.dart` へ恒久版を置くこと。**
決定 **D51** が戒めた「リポジトリの外で確かめたまま再現手段が無い」状態にしない
（**M-B5** が §8-3 で返済したのと同じ負債である）。

#### ★ 「保存できる」と「6.1 を満たす」を分ける形で解けるか → **半分は解ける。半分は解けない**

**解ける側**: ★**既に別の場所で判定されている。**

| 判定 | どこ | 中身 |
|---|---|---|
| 保存の可否 | `DeckDraft.isValid`（`deck_repository.dart:136`） | 名前が空白だけでないこと |
| 6.1 の合否 | `DeckValidationResult.isValid`（`deck_validator.dart:80`） | `issues.isEmpty` |

★**同名だが別物**であり、`canSave` は後者を見ない。**`DeckValidator` に「保存可能」の概念は無い。**

★**解けない側**: 「0 枚を**完成**と呼ぶ」は **6.1.1.3 に反する。**
分けられるのは**保存の可否**までであって、**「6.1 を満たしている」という表示は分けられない。**
★**ここを「解けます」と書かないこと。**

なお `DeckValidationResult` は結果を 1 つしか返さないが、
`DeckIssueCode`（6 種）で**事後に仕分けることは既にできている**（3 箇所が実際にやっている ——
`deck_edit_store.dart:138` / `deck_validation_panel.dart:41-45` / `board_start_dialog.dart:148`）。

#### ★ 補完する場所 —— 3 案の対比

| | **(a) 保存時** | **(b) 盤面の開始時** | **(c) 表示だけ** |
|---|---|---|---|
| DB | 12 枚入る。★**0 枚のデッキは存在しなくなる** | 0 枚のまま | 0 枚のまま |
| `DeckValidator` | ★**6.1 を満たす**（`energyCountMismatch` が消える） | ★**違反のまま。**一覧・検証パネル・盤面の帯に「エネルギーカード 0枚（12枚ちょうど必要）」が出続ける | 違反のまま |
| 共有形式の**書き出し** | `LL-E-00N x12` の行が出る | ★**エネルギー行が出ない。**受け取り側は「エネルギーが無いデッキ」と「行を消し忘れたデッキ」を区別できない（`deck_share.dart:145-156` に枚数不足を表現するフィールドが無い） | 同左 |
| 共有形式の**取り込み** | 12 枚として入る | 0 枚として入る（`resolveDeckShare` は枚数不足を検出しない） | 同左 |
| 盤面 | 12 枚で始まる | 12 枚で始まる。★**DB と盤面で中身が違う**ので `BoardNotice` で必ず出す（黙って足さない） | ★**0 枚のまま** |
| `revision` | 上がる（保存だから） | 上がらない | 上がらない |
| 主な難点 | ★**利用者が入れていないカードが DB とエクスポートに現れる。**あとで自分のエネルギーへ差し替える経路が要る | ★**補完を `loveca_core` の `GameSetup` に入れると Phase 6 のサーバが相手のデッキにも勝手に 12 枚足す**ことになる。UI 側（`start_board.dart`）で `Deck` を作り替えて渡す形なら core は無傷 | ★**単独では要望を満たさない** |

★★**(c) は解にならない。**★★ (a) か (b) を採ったうえで「表示をどう変えるか」の話に降格する。

#### いつ判断するか

**Phase 3b 完了後。**
★**6.1.1.3 に抵触する判断が未決着のまま M-B6 に取り込むと、実装の途中で条文解釈を迫られる。**
M-B6 は 11.10.2 の【要確認】（`docs/盤面設計メモ.md` §3-5）を既に抱えており、
**判断を 2 系統同時に走らせない。**
加えて M-B6 の範囲（11.10 / 11.11 / 整理 / `SetLiveJudgement` / マリガン 6.2.1.6）は
**すべて条文の実装**であり、これは**条文に無い補完**なので混ぜない（1 コミット = 1 論点）。
★上の実測により**盤面の実装を止める種類の阻害ではない**ことが確かめてある。

★(a) を採ってデッキごとに既定を持たせるなら `schemaVersion` を上げることになり、
**`loveca_db` を触る時点（D-11 / D-8 / D-13）と同時**が安い。

### 12-4. U24 — 既定のエネルギーカード

#### ★ `LL-E-002` は実在する（2026-08-25 実測）

| 項目 | 実測値 |
|---|---|
| cardNumber | `LL-E-002` / name「エネルギーカード」/ cardType エネルギー / **全数値フィールドが空** |
| 刷り | ★**2 件**。`LL-E-002-SD`（HSSD01 / SD）と `LL-E-002-PR`（PR / PR）。**どちらも `isParallel == false`**、`parallelSource` は両方 `official` |
| 同系列 | `LL-E-001`〜`LL-E-005` の **5 種 / 7 刷り**。名前は「エネルギーカード」「エネルギー」「エネルギー(無地)」と揺れる |
| エネルギー全体 | **567 種 / 717 刷り。**★**全フィールドが一様に空で、ゲーム上の差は 1 件も無い**（差は名前・絵・レアリティ・収録商品だけ） |

#### ★ 利用者に確認が要る論点 —— 実在はしたが、**選定の根拠が示されていない**

1. ★**なぜ 5 種のうち `LL-E-002` なのか。** 「無地」を意図するなら
   `LL-E-005`（名前が「エネルギー(無地)」）のほうが字面は近い。
   ★**`LL-E-002` は `loveca-db/test/fixtures/dist/` に唯一のエネルギー fixture として
   焼き込まれている**ので、そこから来ている可能性がある（★推測。確認が要る）。
2. ★★**cardNumber を指定しただけでは刷りが決まらない。**★★
   デッキは `printingId` で持つ（**D11** / `deck_entries.printing_id`）。
   `LL-E-002` は非パラレル刷りが 2 件あり、★**決定 D68 が「既定がコイントス」として
   開示対象にした 19 種のうちの 1 つ**である（実測で確認）。
   D68 の規則（非パラレルのうち `printingId` 昇順の先頭）を流用すると **`LL-E-002-PR`** になる。

★**書き方でも意味が変わる。** CLAUDE.md §5-(6) の切り出し規則に `LL-E-002` を掛けると
`rsplit("-", 1)` で **`LL-E`** になり、そんなカードは実在しない。
★**`LL-E-002` は規則の入力ではなく出力である。** cardNumber と printingId を書き分けること。

#### ★ 設定できる場所 —— 3 案

| 案 | 難点 |
|---|---|
| **アプリ全体の既定**（R6 設定） | 1 箇所で済む。R6 は既に dist / `dataVersion` / パラレル表示の既定を持つので置き場としては自然。★**「このデッキだけ別のエネルギー」ができない** |
| **デッキごと** | `decks` に列が要る → `schemaVersion` 3 → ★**D65 の `ord` 移行と同じ時点**になる。Phase 4 の同期にも乗る |
| **開始ダイアログ**（`board_start_dialog.dart`） | ★既に 6.2.1.1 の枠があり **(b) と自然に噛み合う**。**保存しないので毎回選ぶ。**★ソロでも相手側に同じデッキが入る（§14-5）ので両方に効く |

→ ★**U23 の答えで候補が変わる。**(a) 保存時なら「アプリ全体の既定」か「デッキごと」、
(b) 開始時なら「開始ダイアログ」か「アプリ全体の既定」。

#### ★ マスタが更新されて消えた場合（D35 / D-8 と同型）

- `LL-E-002` は **2 商品**（HSSD01 / PR）に刷りがあるので、片方が配信から落ちても他方が残る。
- ★**ただし printingId で固定していると、その刷りの商品が消えた時点で解決できなくなる。**
- 決めるべきは「**解決できないときどうするか**」。★**黙って 0 枚に戻さない**（**D35**「黙って削除しない」の精神）。
  候補は (i) 別の刷りへ落とす（D68 と同じ選び方）/ (ii) 開始を止めて理由を出す（未知の刷りと同じ扱い）/
  (iii) 設定を空にして R6 で警告する。

#### ★ カード番号のハードコードという不変条件

★★**本番コード（3 パッケージの `lib/`）にカード番号のハードコードは現在 0 件である**（走査で確認）。★★
`lib/` にあるエネルギーの識別は**種別からの導出だけ**（`CardType.energy`）で、
これは `決定事項一覧.md:410-419`（区分は列に持たず導出する）と揃っている。

→ ★**`LL-E-002` をコードに書くと、この不変条件を最初に破る。**
配信データ（`meta/`）か利用者設定に置けば破らない。**この選択も U24 の一部である。**

#### いつ判断するか

★**U23 の後。** ★★**U24 は U23 に一方向で依存する。**★★
U23 の補完場所が決まらないと、既定を「いつ・どこで・どの単位（cardNumber / printingId）で」
持つかが決まらない。★**U23 で (c) を採ると U24 は消滅する。**
**U24 を先に決めてはいけない。**
