"""配信 JSON と Dart パーサの契約検証.

★この検査の存在理由★
Python (生成側) と Dart (読込側) は別言語なので、キー名がずれても
実行するまで気づけない。実際に `isDeleted` の出力漏れが起きた。
Dart SDK が無い環境でも形式の食い違いを潰せるよう、
Dart ソースから読んでいるキーを抽出して実 JSON と突き合わせる。

    python tools/verify_contract.py
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "test" / "fixtures"
SRC = ROOT / "lib" / "src"


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
    for card in cards_json["cards"]:
        if card["cardType"] not in known_types:
            problems.append(f"Dart の CardType が未対応: {card['cardType']}")
        for group in ("hearts", "requiredHearts", "bladeHearts"):
            for color in card.get(group, {}):
                if color not in known_colors:
                    problems.append(f"Dart の HeartColor が未対応: {color}")

    print("=" * 60)
    if problems:
        for problem in sorted(set(problems)):
            print(f"  NG {problem}")
        print("=" * 60)
        return 1

    print("  OK Dart のパーサが読むキーは全て配信 JSON に存在する")
    print(f"     card {len(card_keys)} キー / printing {len(printing_keys)} キー")
    print(f"     cardType {sorted(known_types)}")
    print(f"     heartColor {len(known_colors)} 色")
    print("=" * 60)
    return 0


if __name__ == "__main__":
    sys.exit(main())
