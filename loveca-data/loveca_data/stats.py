"""正規化結果の統計.

配信物を作る前のサニティチェックと、Phase 2 の規模見積もりに使う。
ネットワークアクセスは一切しない。
"""

from __future__ import annotations

from collections import Counter, defaultdict

from .constants import KIND_ENERGY, KIND_LIVE, KIND_MEMBER
from .normalize import NormalizeResult


def _bar(count: int, total: int, width: int = 30) -> str:
    if total <= 0:
        return ""
    filled = round(width * count / total)
    return "#" * filled + "." * (width - filled)


def summarize(result: NormalizeResult) -> str:
    lines: list[str] = []
    cards = result.cards
    printings = result.printings

    lines.append("=" * 64)
    lines.append(f"カード (cardNumber 単位) : {len(cards):,} 種")
    lines.append(f"刷り (printingId 単位)   : {len(printings):,} 件")
    lines.append(f"収録商品                 : {len(result.products):,} 件")
    lines.append(f"公式 Q&A                 : {len(result.faqs):,} 件")

    # ---- カード種別 ------------------------------------------------------
    lines.append("")
    lines.append("--- カード種別 ---")
    by_type = Counter(c.card_type for c in cards.values())
    for kind in (KIND_MEMBER, KIND_LIVE, KIND_ENERGY):
        count = by_type.get(kind, 0)
        lines.append(f"  {kind:<8} {count:>5} 種  {_bar(count, len(cards))}")

    # ---- パラレル判定の内訳 ★537 件の検証 --------------------------------
    lines.append("")
    lines.append("--- パラレル判定 ---")
    normal = sum(1 for p in printings.values() if not p.is_parallel)
    parallel = len(printings) - normal
    lines.append(f"  通常刷り   {normal:>5} 件")
    lines.append(f"  パラレル   {parallel:>5} 件")

    lines.append("")
    lines.append("--- 判定の根拠 ---")
    by_source = Counter(p.parallel_source for p in printings.values())
    for source, count in by_source.most_common():
        label = {
            "official": "公式 parallel=normal による確定",
            "rarity_guess": "レアリティからの推定 (要注意)",
            "unknown": "未判定",
        }.get(source, source)
        lines.append(f"  {source:<13} {count:>5} 件  {label}")

    # ★推定になった刷りの種別内訳。エネルギー以外が混ざっていないかの確認
    guessed = [p for p in printings.values() if p.parallel_source == "rarity_guess"]
    if guessed:
        lines.append("")
        lines.append("--- 推定になった刷りのカード種別 ---")
        kinds = Counter(
            (cards[p.card_number].card_type if p.card_number in cards else "不明")
            for p in guessed
        )
        for kind, count in kinds.most_common():
            mark = "" if kind == KIND_ENERGY else "  ★エネルギー以外。要確認"
            lines.append(f"  {kind:<8} {count:>5} 件{mark}")

        non_energy = [
            p for p in guessed
            if p.card_number in cards and cards[p.card_number].card_type != KIND_ENERGY
        ]
        if non_energy:
            lines.append("")
            lines.append("  エネルギー以外の例 (先頭 20 件):")
            for p in sorted(non_energy, key=lambda x: x.printing_id)[:20]:
                lines.append(f"    {p.printing_id}  rare={p.rarity}")

    # ---- 商品ごと --------------------------------------------------------
    lines.append("")
    lines.append("--- 収録商品ごとの刷り数 ---")
    by_expansion = Counter(p.expansion for p in printings.values())
    for expansion, count in sorted(by_expansion.items()):
        name = result.products[expansion].name if expansion in result.products else ""
        lines.append(f"  {expansion:<8} {count:>5} 件  {name}")

    # ---- レアリティ ------------------------------------------------------
    lines.append("")
    lines.append("--- レアリティ ---")
    by_rarity = Counter(p.rarity for p in printings.values())
    for rarity, count in by_rarity.most_common():
        lines.append(f"  {rarity or '(空)':<8} {count:>5} 件")

    # ---- 画像 (Phase 2 の容量見積もり) -----------------------------------
    lines.append("")
    lines.append("--- 画像 ---")
    pictures = {p.picture for p in printings.values() if p.picture}
    lines.append(f"  ユニークな画像 {len(pictures):,} 枚")
    lines.append(f"  概算容量  thumb {len(pictures) * 15 / 1024:.0f}MB / "
                 f"normal {len(pictures) * 60 / 1024:.0f}MB / "
                 f"large {len(pictures) * 200 / 1024:.0f}MB")

    # ---- ゲーム的な分布 (Phase 2 のデッキ分析 UI の参考) -------------------
    members = [c for c in cards.values() if c.card_type == KIND_MEMBER]
    lives = [c for c in cards.values() if c.card_type == KIND_LIVE]

    if members:
        lines.append("")
        lines.append("--- メンバーのコスト分布 ---")
        costs = Counter(c.cost for c in members if c.cost is not None)
        for cost in sorted(costs):
            lines.append(f"  コスト {cost:>2}  {costs[cost]:>4} 種  "
                         f"{_bar(costs[cost], max(costs.values()))}")

        lines.append("")
        lines.append("--- メンバーの所持ハート色 ---")
        colors: Counter = Counter()
        for c in members:
            for color, count in c.hearts.items():
                colors[color] += count
        total_hearts = sum(colors.values()) or 1
        for color, count in colors.most_common():
            lines.append(f"  {color:<8} {count:>5}  {_bar(count, total_hearts)}")

    if lives:
        lines.append("")
        lines.append("--- ライブの必要ハート色 ---")
        req: Counter = Counter()
        for c in lives:
            for color, count in c.required_hearts.items():
                req[color] += count
        total_req = sum(req.values()) or 1
        for color, count in req.most_common():
            lines.append(f"  {color:<8} {count:>5}  {_bar(count, total_req)}")

        lines.append("")
        lines.append("--- ライブのスコア分布 ---")
        scores = Counter(c.score for c in lives if c.score is not None)
        for score in sorted(scores):
            lines.append(f"  スコア {score:>2}  {scores[score]:>4} 種")

    # ---- キーワード ------------------------------------------------------
    lines.append("")
    lines.append("--- キーワード能力 ---")
    keywords: Counter = Counter()
    for c in cards.values():
        keywords.update(c.keywords)
    for keyword, count in keywords.most_common():
        lines.append(f"  {keyword:<14} {count:>5} 種")

    # ---- グループ / ユニット ---------------------------------------------
    lines.append("")
    lines.append("--- グループ ---")
    groups: Counter = Counter()
    for c in cards.values():
        groups.update(c.group_names)
    for group, count in groups.most_common():
        lines.append(f"  {group:<40} {count:>5} 種")

    lines.append("")
    lines.append("--- ユニット ---")
    units: Counter = Counter()
    for c in cards.values():
        units.update(c.unit_names)
    for unit, count in units.most_common(30):
        lines.append(f"  {unit:<40} {count:>5} 種")

    # ---- 表記ゆれの確認 ---------------------------------------------------
    import unicodedata
    variants: dict[str, set[str]] = {}
    for c in cards.values():
        for value in c.unit_names + c.group_names:
            variants.setdefault(unicodedata.normalize("NFKC", value), set()).add(value)
    dupes = {k: v for k, v in variants.items() if len(v) > 1}
    lines.append("")
    lines.append("--- 表記ゆれ ---")
    if dupes:
        for _, raws in sorted(dupes.items()):
            lines.append(f"  ★ {sorted(raws)}  検索が分裂します")
    else:
        lines.append("  なし")

    lines.append("=" * 64)
    return "\n".join(lines)
