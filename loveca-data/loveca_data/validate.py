"""段階 5: 検証.

実装仕様書 v1.0 §8 に対応。

V2 と V3 が最重要。この 2 つが通れば、本プロジェクトの 2 大リスクである
「色マッピングの誤り」と「カード番号の切り出し規則の誤り」が機械的に保証される。

BP01 だけで一度これを通してから全商品に拡大すること。
3,000 件取ってから誤りに気づくのは時間と相手サーバ負荷の両方の無駄になる。
"""

from __future__ import annotations

import json
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

from .constants import (
    ALL, GRAY, KIND_ENERGY, KIND_LIVE, KIND_MEMBER, KNOWN_KINDS,
    OFFICIAL_GROUPS, OFFICIAL_UNITS, SIX_COLORS,
)
from .normalize import (
    BLADE_HEART_EFFECT_KEYS, NormalizeResult, heart_icons_to_map, nfkc,
    parse_heart_string, split_card_number,
)


@dataclass
class Issue:
    code: str
    level: str   # "ERROR" | "WARN"
    message: str


@dataclass
class ValidationReport:
    issues: list[Issue] = field(default_factory=list)

    def add(self, code: str, level: str, message: str) -> None:
        self.issues.append(Issue(code, level, message))

    @property
    def errors(self) -> list[Issue]:
        return [i for i in self.issues if i.level == "ERROR"]

    @property
    def warnings(self) -> list[Issue]:
        return [i for i in self.issues if i.level == "WARN"]

    @property
    def ok(self) -> bool:
        return not self.errors

    def summary(self) -> str:
        lines = [f"検証結果: エラー {len(self.errors)} 件 / 警告 {len(self.warnings)} 件"]
        for issue in self.issues[:200]:
            lines.append(f"  [{issue.level}] {issue.code}: {issue.message}")
        if len(self.issues) > 200:
            lines.append(f"  ... 他 {len(self.issues) - 200} 件")
        return "\n".join(lines)


def validate(result: NormalizeResult, *,
             raw_images_dir: Path | None = None,
             expected_totals: dict[str, int] | None = None,
             previous_card_numbers: set[str] | None = None,
             complete_dataset: bool = False) -> ValidationReport:
    """正規化結果を検証する.

    complete_dataset: 全商品を取得済みなら True。
        relationCards は全商品を横断した一覧を返すため、一部商品しか取得していない
        状態では「公式にあってこちらに無い刷り」が大量に出る。それは欠損であって
        規則の誤りではないので、False のときは報告しない。
    """
    rep = ValidationReport()

    for warn in result.warnings:
        # パラレル推定は V4 でまとめて件数報告するので個別には出さない
        if "レアリティからパラレルを推定" in warn:
            continue
        rep.add("V0", "WARN", warn)

    # -- V1: printingId の一意性 -----------------------------------------
    # dict なので構造上一意。normalize 側の warnings で重複を検出済み。

    # -- V2 ★: heart 文字列と heartNN の一致 ------------------------------
    # 色マッピング系統 A が正しいことの機械的保証
    for printing_id, printing in result.printings.items():
        card = result.cards.get(printing.card_number)
        if card is None:
            continue
        expected = heart_icons_to_map(parse_heart_string(card.raw_heart_string))
        actual = card.hearts if card.card_type == KIND_MEMBER else card.required_hearts
        if card.card_type in (KIND_MEMBER, KIND_LIVE) and expected != actual:
            rep.add("V2", "ERROR",
                    f"{printing_id}: heart文字列 '{card.raw_heart_string}' -> {expected} が "
                    f"heartNN {actual} と不一致。色マッピングを疑うこと")

    # -- V3 ★: relationCards と自前グルーピングの一致 ---------------------
    # cardNumber の切り出し規則が正しいことの機械的保証
    by_number: dict[str, set[str]] = defaultdict(set)
    for printing in result.printings.values():
        by_number[printing.card_number].add(printing.printing_id)

    for printing_id, official_rel in result.relations.items():
        printing = result.printings[printing_id]

        # (a) ★本質的な検証★
        # 公式が「同一カードの別刷り」とみなす printingId は、
        # 自前の切り出し規則でも必ず同じ cardNumber にならなければならない。
        # 取得済みかどうかに依存しないので、1 商品だけでも成立する。
        for rel_id in official_rel:
            derived = split_card_number(rel_id)
            if derived != printing.card_number:
                rep.add("V3", "ERROR",
                        f"{printing_id}: 公式が同一カードとみなす {rel_id} を "
                        f"自前規則で切ると '{derived}' となり "
                        f"'{printing.card_number}' と一致しない。切り出し規則の誤り")

        # (b) 取得済みの同 cardNumber の刷りが、公式 relationCards に含まれること。
        # 含まれない = 別カードを誤って同一視している (過剰グルーピング)。
        mine = by_number[printing.card_number] - {printing_id}
        extra = mine - official_rel
        if extra:
            rep.add("V3", "ERROR",
                    f"{printing_id}: {sorted(extra)} を同一カードとして扱っているが "
                    f"公式 relationCards に含まれない。過剰グルーピングの疑い")

        # (c) 公式にあってこちらに無いものは「未取得」。
        # 全商品を取得済みのときだけ欠損として報告する。
        if complete_dataset:
            missing = {r for r in official_rel if r not in result.printings}
            if missing:
                rep.add("V3", "WARN",
                        f"{printing_id}: 公式 relationCards の {sorted(missing)} が未取得")

    # -- V4: 各 cardNumber に基本刷りがちょうど 1 つ ----------------------
    # ★「cardNumber ごとに基本刷り 1 枚」ではない。
    #   同じカードが複数商品に再録されると通常刷りが複数になる (N と PR、SD と SD2)。
    #   検証すべきは「パラレル表示 OFF で消えるカードが無いこと」。
    if any(p.parallel_source != "unknown" for p in result.printings.values()):
        for card_number, printing_ids in by_number.items():
            normals = [p for p in printing_ids
                       if not result.printings[p].is_parallel]
            if not normals:
                rep.add("V4", "ERROR",
                        f"{card_number}: 全ての刷りがパラレル判定。"
                        f"パラレル表示 OFF で一覧から消える")

        guessed = [w for w in result.warnings if "レアリティからパラレルを推定" in w]
        if guessed:
            rep.add("V4", "WARN",
                    f"公式 parallel=normal に含まれずレアリティから推定: "
                    f"{len(guessed)} 件 (主にエネルギーカード)")
    else:
        rep.add("V4", "WARN",
                "パラレル情報が未取得です。fetch が parallel=normal の集合を "
                "取得しているか確認してください (パラレル表示 ON/OFF に必要)")

    # -- V5: 商品ごとの件数 -----------------------------------------------
    if expected_totals:
        counts: dict[str, int] = defaultdict(int)
        for printing in result.printings.values():
            counts[printing.expansion] += 1
        for expansion, expected in expected_totals.items():
            actual = counts.get(expansion, 0)
            if actual != expected:
                rep.add("V5", "ERROR",
                        f"{expansion}: 件数不一致 取得={actual} total={expected}")

    # -- V6: 画像の実在 ----------------------------------------------------
    if raw_images_dir is not None:
        for printing in result.printings.values():
            if not printing.picture:
                rep.add("V6", "ERROR", f"{printing.printing_id}: picture が空")
            elif not (raw_images_dir / printing.picture).exists():
                rep.add("V6", "ERROR",
                        f"{printing.printing_id}: 画像未取得 {printing.picture}")

    # -- V7 ★: 同色のハート音符が重複しないこと ---------------------------
    # 集約形式 (heartNN) で表現できる前提が崩れていないかの確認
    for card in result.cards.values():
        icons = parse_heart_string(card.raw_heart_string)
        seen: set[str] = set()
        for icon in icons:
            if icon.kind in seen:
                rep.add("V7", "ERROR",
                        f"{card.card_number}: heart文字列 '{card.raw_heart_string}' に "
                        f"同じ色 {icon.kind} が複数回出現。"
                        f"ハート音符を slotIndex 付きで保持する設計に戻す必要がある")
            seen.add(icon.kind)

    # -- V14 ★: ブレードハートの色と効果アイコンが混ざっていないこと --------
    # ★この網が無かったために A-1 が生き延びた★
    #   DRAW / SCORE を色と同じ辞書に入れて配信すると、Dart 側の
    #   HeartColor.fromKey が未知キーで throw し、カードマスタのロードが
    #   丸ごとクラッシュする。生成側で止めるのが唯一の防ぎ方。
    known_colors = set(SIX_COLORS) | {GRAY, ALL}
    for card in result.cards.values():
        for key in card.blade_hearts:
            if key not in known_colors:
                rep.add("V14", "ERROR",
                        f"{card.card_number}: bladeHearts に色でない '{key}' が入っている。"
                        f"総合ルール 8.3.14 の合算対象は色のみ。"
                        f"ドロー(8.3.12.1)/スコア(8.4.2.1) は bladeHeartEffects へ")
        for key in card.blade_heart_effects:
            if key not in BLADE_HEART_EFFECT_KEYS:
                rep.add("V14", "ERROR",
                        f"{card.card_number}: bladeHeartEffects に未知の '{key}' が入っている。"
                        f"許可されるのは {sorted(BLADE_HEART_EFFECT_KEYS)} のみ")

    # -- V8: card_kind が既知の 3 値のみ ----------------------------------
    for card in result.cards.values():
        if card.card_type not in KNOWN_KINDS:
            rep.add("V8", "ERROR", f"{card.card_number}: 未知の card_kind '{card.card_type}'")

    # -- V10: 種別ごとの必須値 ---------------------------------------------
    for card in result.cards.values():
        if card.card_type == KIND_ENERGY:
            continue
        if card.card_type == KIND_MEMBER and card.cost is None:
            rep.add("V10", "WARN", f"{card.card_number}: メンバーだが cost が無い")
        if card.card_type == KIND_LIVE and card.score is None:
            rep.add("V10", "WARN", f"{card.card_number}: ライブだが score が無い")

    # -- V11: グループ名 / ユニット名が総合ルール付録 A と一致 --------------
    known_groups = {nfkc(g) for g in OFFICIAL_GROUPS}
    # 実データでは A-RISE / Saint Snow / Sunny Passion / Aqours が unit_name にも入る。
    # 総合ルール付録 A では「グループ名」だが、ユニットとしても機能するため許容する。
    known_units = {nfkc(u) for u in OFFICIAL_UNITS} | known_groups
    for card in result.cards.values():
        # 公式サイトと総合ルール付録 A で半角/全角が揺れる
        # (例: 'みらくらぱーく!' と 'みらくらぱーく！') ため NFKC で比較する
        for group in card.group_names:
            if nfkc(group) not in known_groups:
                rep.add("V11", "WARN",
                        f"{card.card_number}: 未知のグループ名 '{group}' (新規追加の可能性)")
        for unit in card.unit_names:
            if nfkc(unit) not in known_units:
                rep.add("V11", "WARN",
                        f"{card.card_number}: 未知のユニット名 '{unit}' (新規追加の可能性)")

    # -- V13 ★: 表記ゆれの検出 --------------------------------------------
    # NFKC 形が同じなのに生表記が異なる値は、検索・集計で分裂する。
    # 実データで 'みらくらぱーく！' と 'みらくらぱーく!' の分裂が発生した。
    for label, extract in (
        ("グループ名", lambda c: c.group_names),
        ("ユニット名", lambda c: c.unit_names),
        ("キャラクター名", lambda c: c.character_names),
    ):
        variants: dict[str, set[str]] = {}
        for card in result.cards.values():
            for value in extract(card):
                variants.setdefault(nfkc(value), set()).add(value)
        for normalized, raws in variants.items():
            if len(raws) > 1:
                rep.add("V13", "ERROR",
                        f"{label}に表記ゆれ: {sorted(raws)} が同一視されるべきだが "
                        f"別々に保持されている。検索・集計が分裂する")

    rarities: dict[str, set[str]] = {}
    for printing in result.printings.values():
        if printing.rarity:
            rarities.setdefault(nfkc(printing.rarity), set()).add(printing.rarity)
    for normalized, raws in rarities.items():
        if len(raws) > 1:
            rep.add("V13", "ERROR",
                    f"レアリティに表記ゆれ: {sorted(raws)}")

    # -- V12 ★: 既存 cardNumber が消えていないこと -------------------------
    # 消えると既存デッキが壊れる
    if previous_card_numbers:
        missing = previous_card_numbers - set(result.cards.keys())
        for card_number in sorted(missing):
            rep.add("V12", "ERROR",
                    f"{card_number}: 前回存在したが今回消滅。"
                    f"既存デッキが壊れるため isDeleted=true で残すこと "
                    f"(normalized/previous.json から復元できる)")

    return rep


def load_previous_card_numbers(path: Path) -> set[str]:
    if not path.exists():
        return set()
    data = json.loads(path.read_text(encoding="utf-8"))
    return {c["cardNumber"] for c in data.get("cards", [])}
