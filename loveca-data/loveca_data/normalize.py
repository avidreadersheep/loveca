"""段階 4: 正規化.

実装仕様書 v1.0 §2 / §4 / §7 に対応。ネットワークアクセスは一切行わない。

★ このモジュールの最重要事項 ★
公式 API は CMS の汎用カラムを流用しているため、フィールド名と中身が乖離している。
card_kind による分岐なしに値を読んではいけない。

  フィールド     | メンバー           | ライブ
  --------------|--------------------|--------------------
  cost          | コスト             | ブレードハート(第2枠と推定)
  heart/heartNN | 基本ハート         | 必要ハート
  attack        | ブレード(数値)     | ブレードハート
  blade_heart   | ブレードハート     | スコア
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field
from typing import Any

from .constants import (
    ALL, BLADE_HEART_SPECIAL, GRAY, HEART_FIELD, HEART_NAME,
    KEYWORD_TOKENS, KIND_ENERGY, KIND_LIVE, KIND_MEMBER, NO_VALUE,
    OFFICIAL_GROUPS, OFFICIAL_UNITS,
)

# 「緑1青3」「桃3緑3紫3」「緑1青1無3」「ALL1」「ドロー1」を分解する。
#
# ★数字を必須にしてはいけない★
#   公式は同じ意味を複数の書き方で入れてくる (実測):
#     'ドロー1' 24 刷り / 'ドロー' 48 刷り / '[ドロー]' 3 刷り
#     'スコア1' 19 刷り / 'スコア' 27 刷り / '[スコア]' 1 刷り
#   数字必須にしていたため 59 種でブレードハートが無言で欠落していた。
#   数字が無い場合は 1 個として扱う。
#   角括弧は半角 [] のみ実在するが、全角 ［］ も防御的に受ける。
_TOKEN_RE = re.compile(
    r"[\[［]?(ALL|ドロー|スコア|全ブレード|桃|赤|黄|緑|青|紫|無)[\]］]?\s*(\d*)")
# Q&A の card_names: 「[LL-bp1-001-R＋ ： 上原歩夢&…]」
_FAQ_CARD_RE = re.compile(r"\[([^\s：\]]+)\s*：")


def nfkc(value: str | None) -> str:
    """全角プラス (U+FF0B) 等を半角へ。card_number に必須."""
    if not value:
        return ""
    return unicodedata.normalize("NFKC", value).strip()


def clean_text(value: str | None) -> str:
    """「-」を空に、改行と連続空白を正規化する."""
    if value is None:
        return ""
    text = value.strip()
    if text == NO_VALUE:
        return ""
    # text_html 側で <br> が二重エスケープされている箇所がある
    text = text.replace("&lt;br&gt;", "\n").replace("<br>", "\n")
    return text


def clean_name(value: str | None) -> str:
    """カード名の改行 (例: "UEHARA\\nAYUMU") を空白に正規化する.

    同一 cardNumber 内で表記ゆれがあるため、名前での突合は禁止。
    突合は必ず cardNumber で行うこと。
    """
    if not value:
        return ""
    return re.sub(r"\s+", " ", value.replace("\n", " ")).strip()


def split_card_number(printing_id: str) -> str:
    """printingId からレアリティ接尾を除いて cardNumber を得る.

    総合ルール 6.1.1.2 の「カードナンバー」= デッキ構築の 4 枚制限の判定単位。

    実測で確認した全パターンで成立する:
        LL-bp1-001-R+              -> LL-bp1-001
        PL!N-bp1-034-PE+           -> PL!N-bp1-034
        PL!N-bp1-014-PRproteinbar  -> PL!N-bp1-014
        PL!SP-bp1-023-SRL          -> PL!SP-bp1-023
        PL!HS-bp1-002-RM           -> PL!HS-bp1-002

    ★接尾のホワイトリスト化はしない。新商品・新レアリティで必ず増える。
    """
    pid = nfkc(printing_id)
    return pid.rsplit("-", 1)[0] if "-" in pid else pid


# 総合ルール付録 A の表記を正典とする正規化テーブル (NFKC 形 -> 正典表記)
_CANONICAL_NAMES = {
    unicodedata.normalize("NFKC", name): name
    for name in list(OFFICIAL_GROUPS) + list(OFFICIAL_UNITS)
}


def canonical_name(value: str) -> str:
    """グループ名・ユニット名の表記ゆれを総合ルール付録 A の表記に寄せる.

    ★実データに表記ゆれが存在する★
        'みらくらぱーく！' (全角) と 'みらくらぱーく!' (半角) が混在し、
        そのままでは同じユニットが 2 つに分裂して検索が片方しかヒットしない。

    NFKC 形が付録 A と一致すれば付録 A の表記を採用し、
    一致しなければ生値を保つ (新作品・新ユニットを勝手に変えない)。
    """
    text = value.strip()
    return _CANONICAL_NAMES.get(unicodedata.normalize("NFKC", text), text)


def split_slash(value: str | None) -> list[str]:
    """work_title / unit_name の「/」区切り。無しは「-」.

    表記ゆれを正典表記に寄せ、重複を除く (順序は保つ)。
    """
    if not value or value.strip() == NO_VALUE:
        return []
    out: list[str] = []
    for part in value.split("/"):
        name = canonical_name(part)
        if name and name not in out:
            out.append(name)
    return out


def split_ampersand(card_name: str) -> list[str]:
    """総合ルール 2.3.2.1: カード名の ＆ で区切られたそれぞれがメンバー名称."""
    if not card_name:
        return []
    normalized = card_name.replace("＆", "&")
    return [p.strip() for p in normalized.split("&") if p.strip()]


def parse_int(value: Any) -> int | None:
    if value is None:
        return None
    text = str(value).strip()
    if text in ("", NO_VALUE):
        return None
    try:
        return int(text)
    except ValueError:
        return None


# ---------------------------------------------------------------------------
# ハート系のパース
# ---------------------------------------------------------------------------
@dataclass
class HeartIcon:
    kind: str    # 色 (PINK..PURPLE / GRAY / ALL) または DRAW / SCORE
    count: int


def parse_heart_string(value: str | None) -> list[HeartIcon]:
    """系統 C: 「緑1青3」形式を分解する.

    ブレードハート欄では ALL / ドロー / スコア / [全ブレード] も出現する。
    数字が省略された表記 (「ドロー」「[スコア]」) は 1 個として扱う。
    """
    if not value or value.strip() in ("", NO_VALUE):
        return []
    out: list[HeartIcon] = []
    for token, num in _TOKEN_RE.findall(value):
        count = int(num) if num else 1
        if token in BLADE_HEART_SPECIAL:
            out.append(HeartIcon(BLADE_HEART_SPECIAL[token], count))
        else:
            out.append(HeartIcon(HEART_NAME[token], count))
    return out


def parse_heart_fields(raw: dict) -> dict[str, int]:
    """系統 A: heart0..heart06 を色 -> 枚数の辞書にする."""
    out: dict[str, int] = {}
    for field_name, color in HEART_FIELD.items():
        count = parse_int(raw.get(field_name)) or 0
        if count:
            out[color] = out.get(color, 0) + count
    return out


def heart_icons_to_map(icons: list[HeartIcon]) -> dict[str, int]:
    out: dict[str, int] = {}
    for icon in icons:
        out[icon.kind] = out.get(icon.kind, 0) + icon.count
    return out


# ブレードハートの非色アイコン。BLADE_HEART_SPECIAL を唯一の出処にする。
BLADE_HEART_EFFECT_KEYS = frozenset(BLADE_HEART_SPECIAL.values())


def split_blade_icons(icons: list[HeartIcon]) -> tuple[dict[str, int], dict[str, int]]:
    """ブレードハートを「色」と「効果アイコン」に分ける.

    ★同じ辞書に同居させてはいけない★
    総合ルール 8.3.14: 色のブレードハートはライブ所有ハートに合算する。
    総合ルール 8.3.12.1: ドローアイコンはカードを 1 枚引く (8.3.14 より前)。
    総合ルール 8.4.2.1:  スコアアイコンはスコア合計に +1 する。
    参照する領域も処理する時点も違うため、型で分けておかないと
    Phase 3a の集計で取り違える。
    """
    colors: dict[str, int] = {}
    effects: dict[str, int] = {}
    for icon in icons:
        target = effects if icon.kind in BLADE_HEART_EFFECT_KEYS else colors
        target[icon.kind] = target.get(icon.kind, 0) + icon.count
    return colors, effects


# ---------------------------------------------------------------------------
# 正規化済みモデル
# ---------------------------------------------------------------------------
@dataclass
class Printing:
    printing_id: str
    card_number: str
    site_id: int
    expansion: str
    rarity: str
    picture: str
    rarity: str
    is_parallel: bool
    parallel_source: str  # "official" | "rarity_guess" | "unknown"
    parallel_param_raw: str
    illustrator: str
    color_raw: str  # ゲーム挙動に無関係。保持のみ
    # 基本刷りの判定根拠。"official" = 公式の parallel=normal に含まれた
    #                    "fallback" = 公式が返さなかったため代表を自動選出した
    #                    ""         = 未判定


@dataclass
class Card:
    card_number: str
    name: str
    card_type: str
    character_names: list[str] = field(default_factory=list)
    group_names: list[str] = field(default_factory=list)
    unit_names: list[str] = field(default_factory=list)
    effect_text: str = ""
    effect_text_html: str = ""
    keywords: list[str] = field(default_factory=list)
    cost: int | None = None
    blade_count: int | None = None
    score: int | None = None
    hearts: dict[str, int] = field(default_factory=dict)          # メンバー: 基本ハート
    required_hearts: dict[str, int] = field(default_factory=dict) # ライブ: 必要ハート
    blade_hearts: dict[str, int] = field(default_factory=dict)    # 両方: ブレードハートの色 (8.3.14)
    # ★色とは別フィールドにする★ ドロー (8.3.12.1) / スコア (8.4.2.1) は
    #  ハート合計に合算せず、別の時点で別の処理を行う
    blade_heart_effects: dict[str, int] = field(default_factory=dict)
    heart_total: int = 0
    required_heart_total: int = 0
    stats: int | None = None   # 決定 D14: ブレード数 + ハート数
    # ★公式リストから消えても既存デッキを壊さないため、削除せずフラグで残す
    #  (検証 V12 が消滅を検出する)
    is_deleted: bool = False
    # 検証用に原文を保持
    raw_heart_string: str = ""
    raw_blade_heart: str = ""
    raw_attack: str = ""
    raw_cost: str = ""


@dataclass
class Faq:
    faq_id: int
    qa_id: str
    question: str
    answer: str
    regist_time: str
    update_time: str
    card_numbers: list[str] = field(default_factory=list)


@dataclass
class Product:
    expansion_id: str
    name: str
    release_date: str
    slug: str
    url: str


@dataclass
class NormalizeResult:
    cards: dict[str, Card] = field(default_factory=dict)
    printings: dict[str, Printing] = field(default_factory=dict)
    faqs: dict[str, Faq] = field(default_factory=dict)
    products: dict[str, Product] = field(default_factory=dict)
    # 検証で使う。printingId -> relationCards のカード番号集合
    relations: dict[str, set[str]] = field(default_factory=dict)
    # ★V15 専用。dist には出力しない★
    #  cards は cardNumber 単位の先勝ちなので、刷りごとの差異がここにしか残らない。
    #  printingId -> (色のブレードハート, 効果アイコン)
    blade_hearts_by_printing: dict[str, tuple[dict[str, int], dict[str, int]]] = \
        field(default_factory=dict)
    warnings: list[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# 本体
# ---------------------------------------------------------------------------
def extract_keywords(text: str) -> list[str]:
    found: list[str] = []
    for token, key in KEYWORD_TOKENS.items():
        if token in text and key not in found:
            found.append(key)
    return found


def normalize_card(raw: dict) -> tuple[Card, Printing]:
    """detail レスポンスの card ノード 1 件を正規化する."""
    printing_id = nfkc(raw.get("card_number"))
    card_number = split_card_number(printing_id)
    kind = (raw.get("card_kind") or "").strip()

    text = clean_text(raw.get("text"))

    card = Card(
        card_number=card_number,
        name=clean_name(raw.get("card_name")),
        card_type=kind,
        effect_text=text,
        effect_text_html=clean_text(raw.get("text_html")),
        keywords=extract_keywords(text),
        raw_heart_string=(raw.get("heart") or ""),
        raw_blade_heart=(raw.get("blade_heart") or ""),
        raw_attack=(raw.get("attack") or ""),
        raw_cost=(raw.get("cost") or ""),
    )
    card.character_names = split_ampersand(card.name)
    card.group_names = split_slash(raw.get("work_title"))
    card.unit_names = split_slash(raw.get("unit_name"))

    heart_map = parse_heart_fields(raw)

    # ---- ★ card_kind による分岐 (仕様書 §2) ----------------------------
    if kind == KIND_MEMBER:
        card.cost = parse_int(raw.get("cost"))
        card.blade_count = parse_int(raw.get("attack"))
        card.hearts = heart_map
        card.blade_hearts, card.blade_heart_effects = split_blade_icons(
            parse_heart_string(raw.get("blade_heart")))
        card.heart_total = sum(heart_map.values())
        card.stats = (card.blade_count or 0) + card.heart_total

    elif kind == KIND_LIVE:
        card.score = parse_int(raw.get("blade_heart"))
        card.required_hearts = heart_map
        card.required_heart_total = sum(heart_map.values())
        # ライブのブレードハートは attack。cost にも入りうる (U1) ため両方を結合。
        # cost が "-" なら parse 結果が空になるだけなので、正体が何であっても壊れない。
        icons = parse_heart_string(raw.get("attack")) + parse_heart_string(raw.get("cost"))
        card.blade_hearts, card.blade_heart_effects = split_blade_icons(icons)

    elif kind == KIND_ENERGY:
        pass  # エネルギーカードは数値情報を持たない

    printing = Printing(
        printing_id=printing_id,
        card_number=card_number,
        site_id=int(raw.get("id") or 0),
        expansion=(raw.get("expansion") or "").strip(),
        picture=(raw.get("picture") or "").strip(),
        # ★レアリティにも全角/半角の混在がある (P+ と P＋、PR+ と PR＋)。
        #  コードなので NFKC で半角に統一して良い。
        rarity=nfkc(raw.get("rare")),
        # ★パラレル判定は normalize_all でまとめて行う (公式 parallel=normal の集合)。
        #  parallel_param は基本刷りフラグではないことが実測で否定された。生値のみ保持。
        is_parallel=False,
        parallel_source="unknown",
        parallel_param_raw=(raw.get("parallel_param") or ""),
        illustrator=re.sub(r"^illust\s*/\s*", "", (raw.get("comment") or "").strip()),
        color_raw=(raw.get("color") or "").strip(),
    )
    return card, printing


def normalize_faqs(detail: dict) -> list[Faq]:
    out: list[Faq] = []
    for raw in detail.get("faqs") or []:
        numbers = [nfkc(m) for m in _FAQ_CARD_RE.findall(raw.get("card_names") or "")]
        out.append(Faq(
            faq_id=int(raw.get("id") or 0),
            qa_id=str(raw.get("qa_id") or ""),
            question=(raw.get("question") or "").strip(),
            answer=(raw.get("answer") or "").strip(),
            # date は取得日なので使わない。regist_time が公開日 (仕様書 §7.5)
            regist_time=(raw.get("regist_time") or "").strip(),
            update_time=(raw.get("update_time") or "").strip(),
            card_numbers=numbers,
        ))
    return out


def _guess_parallel_by_rarity(printings: list[Printing]) -> None:
    """公式 parallel=normal に 1 件も含まれない cardNumber のパラレル推定.

    エネルギーカードは公式の parallel フィルタで返らないため、
    そのままでは全刷りがパラレル扱いになり、パラレル表示 OFF で一覧から消える。
    エネルギーデッキは 12 枚必須 (総合ルール 6.1.1.3) なので実害がある。

    ★これは推定であり公式の定義ではない★
      レアリティ表記から次の順で「通常」を選ぶ:
        1. '+' を含まず、SEC で始まらないもの (PE, LLE)
        2. '+' を含まないもの (SECE)
        3. どれも該当しなければ全部 (単独刷り)
      決定論的に動くよう、同着は site_id / printingId で安定ソートする。
    """
    def is_plus(p: Printing) -> bool:
        return "+" in p.rarity or "\uff0b" in p.rarity

    ordered = sorted(printings, key=lambda p: (p.site_id, p.printing_id))
    normals = [p for p in ordered if not is_plus(p) and not p.rarity.startswith("SEC")]
    if not normals:
        normals = [p for p in ordered if not is_plus(p)]
    if not normals:
        normals = ordered

    normal_ids = {p.printing_id for p in normals}
    for printing in ordered:
        printing.is_parallel = printing.printing_id not in normal_ids
        printing.parallel_source = "rarity_guess"


def normalize_all(details: list[dict],
                  base_printing_ids: set[str] | None = None) -> NormalizeResult:
    """detail レスポンス群を正規化する.

    base_printing_ids: 公式検索の parallel=normal で返る printingId の集合。
        パラレル表示 OFF 時に代表として表示する刷りを決めるのに使う。
        未指定なら isBasePrinting は全て False のままになる。
    """
    result = NormalizeResult()

    for detail in details:
        raw = detail.get("card")
        if not raw:
            continue

        card, printing = normalize_card(raw)

        if printing.printing_id in result.printings:
            result.warnings.append(f"printingId 重複: {printing.printing_id}")
        result.printings[printing.printing_id] = printing

        # ★先勝ちで捨てられる前に刷り単位のブレードハートを控える★
        #  公式 CMS は同じカードでも刷りごとに書き方が揺れる
        #  (PL!-bp4-022 は -L が 'スコア'、-SECL が 'スコア1')。
        #  勝った刷りが壊れていても気づけるよう V15 の材料を残す。
        result.blade_hearts_by_printing[printing.printing_id] = (
            card.blade_hearts, card.blade_heart_effects)

        # 同一 cardNumber の刷りが複数ある場合、ルール上の性質は同一なので
        # 先勝ちで保持する (差異があれば検証で検出する)
        result.cards.setdefault(card.card_number, card)

        # relationCards: 同一 cardNumber の別刷り (自分自身を除く)
        rel = {nfkc(r.get("card_number")) for r in (detail.get("relationCards") or [])}
        if rel:
            result.relations[printing.printing_id] = rel

        for faq in normalize_faqs(detail):
            # 同一 Q&A が複数カードに紐づくため qa_id で重複排除
            existing = result.faqs.get(faq.qa_id)
            if existing:
                merged = sorted(set(existing.card_numbers) | set(faq.card_numbers))
                existing.card_numbers = merged
            else:
                result.faqs[faq.qa_id] = faq

        exp = detail.get("expansion") or {}
        if exp.get("id") and exp["id"] not in result.products:
            result.products[exp["id"]] = Product(
                expansion_id=exp["id"],
                name=exp.get("name", ""),
                release_date=exp.get("release_date", ""),
                slug=exp.get("slug", ""),
                url=exp.get("url", ""),
            )

    # ---- パラレル判定 -----------------------------------------------------
    # ★概念★ 「cardNumber ごとの代表 1 枚」ではなく「その刷りがパラレルか」。
    #   同じカードが複数商品に再録されると通常刷りが複数になる (N と PR、SD と SD2)。
    #   公式サイトの parallel=normal 検索もその全てを返す。
    #   パラレル表示 OFF = is_parallel が False の刷りを全て表示する、が正しい挙動。
    if base_printing_ids is not None:
        grouped: dict[str, list[Printing]] = {}
        for printing in result.printings.values():
            grouped.setdefault(printing.card_number, []).append(printing)

        for card_number, printings in grouped.items():
            official = [p for p in printings if p.printing_id in base_printing_ids]
            if official:
                for printing in printings:
                    printing.is_parallel = printing.printing_id not in base_printing_ids
                    printing.parallel_source = "official"
            else:
                # 公式が 1 件も通常刷りを返さない (エネルギーカード等)
                _guess_parallel_by_rarity(printings)
                result.warnings.append(
                    f"{card_number}: 公式 parallel=normal に含まれないため "
                    f"レアリティからパラレルを推定"
                )

    return result
