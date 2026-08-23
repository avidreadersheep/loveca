"""テスト用のミニ配信物を実データから生成する。

`loveca-core/test/fixtures` と同じ方針。**手書きの想定 JSON は使わない。**
生成側 (Python) と読込側 (Dart) で形式がずれても、手書きだと気づけないため。

★ミニ配信物は相互にハッシュ参照する★
`version.json` が `manifest.json` のハッシュを、`manifest.json` が各ファイルの
ハッシュを持つ。1 ファイルだけ手で直すと壊れるので、必ずこのスクリプトで一括生成する。

実データは git 管理外なので、リフレッシュするときだけ実行する。

    cd loveca-db
    ../loveca-data/.venv/Scripts/python.exe tool/build_fixtures.py

選ぶカードの条件（テストが要求するもの）:

* 同一 cardNumber に**非パラレル刷りが 2 つ**（別商品への再録）
* ブレードハートに **DRAW を持つライブ**と **SCORE を持つライブ**
* 4 枚制限のテストに足りるメンバー / ライブ / エネルギー
* 差分更新のテストのために**商品ファイルが 3 つ以上**
"""

from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
DIST = REPO / "loveca-data" / "data" / "dist"
OUT = HERE.parent / "test" / "fixtures" / "dist"

MEMBER_QUOTA = 15
LIVE_QUOTA = 6
ENERGY_QUOTA = 4


def sha256_of(data: bytes) -> str:
    return "sha256:" + hashlib.sha256(data).hexdigest()


def dump(path: Path, payload: object) -> bytes:
    """配信物と同じ書き方（区切りを詰めた UTF-8）で書き出す。"""
    text = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    data = text.encode("utf-8")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return data


def main() -> int:
    if not DIST.is_dir():
        print(f"★実データが無い: {DIST}")
        print("  data/ は git 管理外。各自で配置してから実行する。")
        return 1

    cards: dict[str, dict] = {}
    printings: list[dict] = []
    for f in sorted((DIST / "cards").glob("*.json")):
        doc = json.loads(f.read_text(encoding="utf-8"))
        for c in doc["cards"]:
            cards[c["cardNumber"]] = c
        printings.extend(doc["printings"])

    by_card: dict[str, list[dict]] = {}
    for p in printings:
        by_card.setdefault(p["cardNumber"], []).append(p)

    picked: list[str] = []

    def pick(number: str) -> None:
        if number in cards and number not in picked:
            picked.append(number)

    # 1. 非パラレル刷りが 2 つ以上ある cardNumber（実データに 19 件）。
    #    ★これが「isParallel は刷り単位」の証拠になる（CLAUDE.md §5-(4)）。
    #    種別が偏らないよう、カード種別ごとに 1 件ずつ拾う。
    multi = sorted(
        n
        for n, ps in by_card.items()
        if sum(1 for p in ps if not p["isParallel"]) > 1
    )
    for kind in ("メンバー", "ライブ", "エネルギー"):
        for n in multi:
            if cards[n]["cardType"] == kind:
                pick(n)
                break

    # 2. DRAW / SCORE を持つライブ。実データではライブにしか存在しない。
    for icon in ("DRAW", "SCORE"):
        for n in sorted(cards):
            if icon in cards[n].get("bladeHeartEffects", {}):
                pick(n)
                break

    # 3. 種別ごとの員数。デッキ検証のテストに足りるだけ入れる。
    #    ★商品ファイルが薄く広がらないよう BP01 を優先する★
    #    差分更新のテストは「変えたファイルだけ再取得される」ことを見るので、
    #    1 ファイルに複数カードが入っていた方が検証として強い。
    def fill_order(number: str) -> tuple[int, str]:
        expansions = {p["expansion"] for p in by_card.get(number, [])}
        return (0 if "BP01" in expansions else 1, number)

    quota = {"メンバー": MEMBER_QUOTA, "ライブ": LIVE_QUOTA, "エネルギー": ENERGY_QUOTA}
    for n in picked:
        kind = cards[n]["cardType"]
        quota[kind] = max(0, quota[kind] - 1)
    for kind, need in quota.items():
        if need <= 0:
            continue
        for n in sorted(cards, key=fill_order):
            if need <= 0:
                break
            if n in picked or cards[n]["cardType"] != kind:
                continue
            pick(n)
            need -= 1

    # 選んだカードの刷りを商品ごとに束ね直す。
    grouped: dict[str, dict[str, list]] = {}
    for n in picked:
        for p in by_card.get(n, []):
            g = grouped.setdefault(p["expansion"], {"cards": {}, "printings": []})
            g["printings"].append(p)
            g["cards"][n] = cards[n]

    if OUT.exists():
        shutil.rmtree(OUT)

    files: list[dict] = []
    for expansion in sorted(grouped):
        g = grouped[expansion]
        payload = {
            "expansion": expansion,
            "cards": [g["cards"][n] for n in sorted(g["cards"])],
            "printings": sorted(g["printings"], key=lambda p: p["printingId"]),
        }
        rel = f"cards/{expansion}.json"
        data = dump(OUT / rel, payload)
        files.append(
            {
                "path": rel,
                "hash": sha256_of(data),
                "bytes": len(data),
                "cardCount": len(payload["cards"]),
            }
        )

    # meta はカードを絞った分だけ削る。
    products = json.loads((DIST / "meta" / "products.json").read_text("utf-8"))
    products["products"] = [
        p for p in products["products"] if p["expansionId"] in grouped
    ]
    picked_printings = {p["printingId"] for g in grouped.values() for p in g["printings"]}
    faqs = json.loads((DIST / "meta" / "faqs.json").read_text("utf-8"))
    faqs["faqs"] = [
        {**q, "cardNumbers": [c for c in q["cardNumbers"] if c in picked_printings]}
        for q in faqs["faqs"]
        if any(c in picked_printings for c in q["cardNumbers"])
    ][:5]
    rule_config = json.loads((DIST / "meta" / "ruleConfig.json").read_text("utf-8"))

    for rel, payload in (
        ("meta/products.json", products),
        ("meta/faqs.json", faqs),
        ("meta/ruleConfig.json", rule_config),
    ):
        data = dump(OUT / rel, payload)
        files.append({"path": rel, "hash": sha256_of(data), "bytes": len(data)})

    version_doc = json.loads((DIST / "version.json").read_text("utf-8"))
    manifest = {"dataVersion": version_doc["dataVersion"], "files": files}
    manifest_data = dump(OUT / "manifest.json", manifest)

    dump(
        OUT / "version.json",
        {
            "dataVersion": version_doc["dataVersion"],
            "minAppVersion": version_doc["minAppVersion"],
            "manifestPath": version_doc["manifestPath"],
            "manifestHash": sha256_of(manifest_data),
        },
    )

    total = sum(f["bytes"] for f in files) + len(manifest_data)
    print(f"生成: {OUT}")
    print(f"  商品ファイル {len(grouped)} 件 / カード {len(picked)} 種 / 計 {total:,} バイト")
    for expansion in sorted(grouped):
        g = grouped[expansion]
        print(f"    {expansion}: cards {len(g['cards'])} / printings {len(g['printings'])}")
    print(f"  非パラレル刷りが複数ある cardNumber: {multi[:2]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
