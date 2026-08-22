# loveca_core

ラブカ シミュレーターのドメイン層。**Flutter に一切依存しない純粋 Dart パッケージ**。

## なぜ Flutter から独立させるのか

PC / スマホ / サーバの 3 者で共有される唯一の真実だから。

- **デッキ検証の二重実装を防ぐ** — スマホで組んだデッキを PC が別実装で検証すると
  「スマホでは合法、PC では不正」という事故が起きる (決定 D28 の前提条件)
- **サーバで再利用できる** — Phase 6 の権威サーバが同じ `reduce` / `redact` を使う
- **単体テストが書きやすい** — UI 非依存なのでロジックを直接検証できる

## 構成

```
lib/src/
  entities/   Card / Printing / Deck / DeckEntry / RuleConfig / Product / Faq
  master/     配信 JSON のパース、差分更新の計画
  rules/      DeckValidator
  game/       (Phase 3a) GameState / reduce / redact / 集計エンジン
```

## 実行

```bash
dart pub get
dart test
python tools/verify_contract.py   # 配信 JSON との契約検証 (Dart 不要)
```

`test/fixtures/` は **Python パイプラインが実際に生成した JSON** をそのままコピーしたもの。
手書きの想定 JSON でテストすると、生成側と読込側で形式がずれても気づけない。

## 契約検証について

Python (生成側) と Dart (読込側) は別言語なので、キー名がずれても実行するまで気づけない。
実際に `isDeleted` の出力漏れが起きた。

`tools/verify_contract.py` は Dart ソースから `json['xxx']` を抽出し、
実際の配信 JSON に存在するかを突き合わせる。**Dart SDK が無い環境でも動く。**

配信形式を変えたときは、必ずフィクスチャを更新してこれを実行すること。

```bash
cp ../loveca-data/data/dist/cards/BP01.json test/fixtures/cards_BP01.json
cp ../loveca-data/data/dist/version.json     test/fixtures/version.json
cp ../loveca-data/data/dist/manifest.json    test/fixtures/manifest.json
cp ../loveca-data/data/dist/meta/products.json   test/fixtures/products.json
cp ../loveca-data/data/dist/meta/ruleConfig.json test/fixtures/ruleConfig.json
python tools/verify_contract.py
```

## 実装済み

| 領域 | 状態 |
|---|---|
| エンティティ | 完了 |
| DeckValidator (総合ルール 6.1) | 完了 |
| 配信 JSON のパース | 完了 |
| 差分更新の計画 (純粋関数) | 完了 |
| GameState / reduce / redact | **Phase 3a で実装** |
| 集計エンジン | **Phase 3a で実装** |
