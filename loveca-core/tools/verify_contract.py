"""配信 JSON と Dart パーサの契約検証.

★この検査の存在理由★
Python (生成側) と Dart (読込側) は別言語なので、キー名がずれても
実行するまで気づけない。実際に `isDeleted` の出力漏れが起きた。
Dart SDK が無い環境でも形式の食い違いを潰せるよう、
Dart ソースから読んでいるキーを抽出して実 JSON と突き合わせる。

★フィクスチャ 5 枚では足りない★
bladeHearts に DRAW / SCORE が入る問題 (A-1) は、この検査を持っていながら
参照先が test/fixtures/cards_BP01.json の 5 枚だけだったため生き延びた。
色検査は dist の全商品を対象にする。dist が無い環境では
「限定検査しかしていない」ことを終了コード 2 で必ず明示する。

    python tools/verify_contract.py

終了コード:
    0  dist 全商品を検査して問題なし
    1  不整合を検出した
    2  dist が無く、フィクスチャだけの限定検査に留まった
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "test" / "fixtures"
SRC = ROOT / "lib" / "src"
# data/ は .gitignore 済みなので、新規クローンでは存在しない
DIST_CARDS = ROOT.parent / "loveca-data" / "data" / "dist" / "cards"

EXIT_OK = 0
EXIT_NG = 1
EXIT_LIMITED = 2


def dart_keys(relative: str) -> set[str]:
    """Dart ソース中の json['xxx'] を抽出する."""
    text = (SRC / relative).read_text(encoding="utf-8")
    return set(re.findall(r"json\['([A-Za-z]+)'\]", text))


def main() -> int:
    problems: list[str] = []

    def load(name: str):
        return json.loads((FIXTURES / name).read_text(encoding="utf-8"))

    cards_json = load("cards_BP01.json")
    card_keys = set(cards_json["cards"][0])
    printing_keys = set(cards_json["printings"][0])
    for key in dart_keys("entities/card.dart"):
        if key not in card_keys and key not in printing_keys:
            problems.append(f"card.dart が読む '{key}' が cards JSON に無い")

    product_keys = set(load("products.json")["products"][0])
    faq_only = {"qaId", "question", "answer", "faqId",
                "registTime", "updateTime", "cardNumbers"}
    for key in dart_keys("entities/product.dart") - faq_only:
        if key not in product_keys:
            problems.append(f"product.dart が読む '{key}' が products.json に無い")

    version_keys = set(load("version.json"))
    for key in ("dataVersion", "minAppVersion", "manifestPath", "manifestHash"):
        if key not in version_keys:
            problems.append(f"version.json に '{key}' が無い")

    manifest = load("manifest.json")
    for key in ("dataVersion", "files"):
        if key not in manifest:
            problems.append(f"manifest.json に '{key}' が無い")
    for key in ("path", "hash", "bytes"):
        if key not in manifest["files"][0]:
            problems.append(f"manifest files に '{key}' が無い")

    rule_json = load("ruleConfig.json")
    master_src = (SRC / "master" / "master_data.dart").read_text(encoding="utf-8")
    for key in set(re.findall(r"v\('([A-Za-z]+)'", master_src)):
        if key not in rule_json:
            problems.append(f"ruleConfig.json に '{key}' が無い")

    card_src = (SRC / "entities" / "card.dart").read_text(encoding="utf-8")
    known_types = set(re.findall(r"'(メンバー|ライブ|エネルギー)'", card_src))
    known_colors = set(re.findall(
        r"'(PINK|RED|YELLOW|GREEN|BLUE|PURPLE|GRAY|ALL)'", card_src))
    known_effects = set(re.findall(r"'(DRAW|SCORE)'", card_src))

    # ---- 種別と色の検査。対象は dist の全商品 -----------------------------
    dist_files = sorted(DIST_CARDS.glob("*.json")) if DIST_CARDS.is_dir() else []
    limited = not dist_files
    if limited:
        sources = [("test/fixtures/cards_BP01.json", cards_json)]
    else:
        sources = [
            (f"cards/{path.name}", json.loads(path.read_text(encoding="utf-8")))
            for path in dist_files
        ]

    checked_numbers: set[str] = set()
    for label, payload in sources:
        for card in payload["cards"]:
            checked_numbers.add(card["cardNumber"])
            if card["cardType"] not in known_types:
                problems.append(
                    f"{label} {card['cardNumber']}: "
                    f"Dart の CardType が未対応: {card['cardType']}")
            # 総合ルール 8.3.14 の合算対象は色のみ。
            # ドロー (8.3.12.1) / スコア (8.4.2.1) は bladeHeartEffects 側。
            for group in ("hearts", "requiredHearts", "bladeHearts"):
                for color in card.get(group, {}):
                    if color not in known_colors:
                        problems.append(
                            f"{label} {card['cardNumber']}: "
                            f"{group} に Dart の HeartColor が未対応の '{color}'")
            for effect in card.get("bladeHeartEffects", {}):
                if effect not in known_effects:
                    problems.append(
                        f"{label} {card['cardNumber']}: "
                        f"bladeHeartEffects に Dart の BladeHeartEffect が未対応の '{effect}'")

    print("=" * 60)
    if problems:
        for problem in sorted(set(problems))[:40]:
            print(f"  NG {problem}")
        if len(set(problems)) > 40:
            print(f"  … 他 {len(set(problems)) - 40} 件")
        print("=" * 60)
        return EXIT_NG

    print("  OK Dart のパーサが読むキーは全て配信 JSON に存在する")
    print(f"     card {len(card_keys)} キー / printing {len(printing_keys)} キー")
    print(f"     cardType {sorted(known_types)}")
    print(f"     heartColor {len(known_colors)} 色 / bladeHeartEffect {sorted(known_effects)}")

    if limited:
        print("")
        print("  " + "!" * 56)
        print("  !! 限定検査です。契約は保証されていません")
        print("  !!")
        print(f"  !! dist が見つかりません: {DIST_CARDS}")
        print(f"  !! フィクスチャ {len(checked_numbers)} 枚しか見ていないため、")
        print("  !! 全商品にしか出現しないキーの取りこぼしは検出できません。")
        print("  !! (A-1 はこの状態で生き延びました)")
        print("  !!")
        print("  !! python -m loveca_data build --data-version <N> を実行してから")
        print("  !! もう一度このスクリプトを通してください。")
        print("  " + "!" * 56)
        print("=" * 60)
        return EXIT_LIMITED

    print(f"  OK 全 {len(sources)} 商品 / カード {len(checked_numbers)} 種の"
          f"種別・色・効果アイコンを検査した")
    print("=" * 60)
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
