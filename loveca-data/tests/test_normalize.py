"""実測データ (BP01) に基づくテスト.

ここで使っているサンプルは、公式 detail API から実際に取得した
レスポンスの card ノードをそのまま貼り付けたもの。
フィールド分岐と色マッピングが仕様書 §2/§3 の通りであることを保証する。
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from loveca_data.normalize import (  # noqa: E402
    Card, canonical_name, heart_icons_to_map, normalize_all, normalize_card,
    parse_heart_string, split_card_number,
)
from loveca_data.validate import validate  # noqa: E402

# --------------------------------------------------------------------------
# 実測サンプル
# --------------------------------------------------------------------------
MEMBER_WITH_BLADE_HEART = {  # id=79 桜坂しずく
    "id": 79, "picture": "BP01/PL!N-bp1-003-P.png",
    "card_number": "PL!N-bp1-003-P", "card_name": "桜坂しずく",
    "card_kind": "メンバー", "rare": "P", "expansion": "BP01",
    "color": "橙", "cost": "10", "heart": "緑1青3",
    "heart0": "0", "heart01": "0", "heart02": "0", "heart03": "0",
    "heart04": "1", "heart05": "3", "heart06": "0",
    "power": "緑1青3", "attack": "2",
    "text": "【登場】手札を1枚控え室に置いてもよい：自分の控え室から『虹ヶ咲』のライブカードを1枚手札に加える。\n【ライブ開始時】[E]支払ってもよい：好きなハートの色を1つ指定する。ライブ終了時まで、そのハートを1つ得る。",
    "text_html": "", "work_title": "虹ヶ咲", "unit_name": "A・ZU・NA",
    "blade_heart": "青1", "comment": "", "parallel_param": "\u3007",
}

MEMBER_NO_BLADE_HEART = {  # id=75 中須かすみ
    "id": 75, "picture": "BP01/PL!N-bp1-002-P.png",
    "card_number": "PL!N-bp1-002-P", "card_name": "中須かすみ",
    "card_kind": "メンバー", "rare": "P", "expansion": "BP01",
    "color": "橙", "cost": "2", "heart": "黄1",
    "heart0": "0", "heart01": "0", "heart02": "0", "heart03": "1",
    "heart04": "0", "heart05": "0", "heart06": "0",
    "power": "黄1", "attack": "2",
    "text": "【登場】自分のデッキの上からカードを3枚見る。",
    "text_html": "", "work_title": "虹ヶ咲", "unit_name": "QU4RTZ",
    "blade_heart": "-", "comment": "", "parallel_param": "\u3007",
}

LIVE = {  # id=117 虹色Passions！
    "id": 117, "picture": "BP01/PL!N-bp1-025-L.png",
    "card_number": "PL!N-bp1-025-L", "card_name": "虹色Passions！",
    "card_kind": "ライブ", "rare": "L", "expansion": "BP01",
    "color": "紫", "cost": "-", "heart": "緑1青1無3",
    "heart0": "3", "heart01": "0", "heart02": "0", "heart03": "0",
    "heart04": "1", "heart05": "1", "heart06": "0",
    "power": "緑1青1無3", "attack": "ALL1",
    "text": "(必要ハートを確認する時、エールで出た[ALLブレード]は任意の色のハートとして扱う。)",
    "text_html": "", "work_title": "虹ヶ咲", "unit_name": "-",
    "blade_heart": "2", "comment": "", "parallel_param": "",
}

LIVE_DRAW = {  # id=119 Solitude Rain — ★色とドローが同居する実データ
    "id": 119, "picture": "BP01/PL!N-bp1-027-L.png",
    "card_number": "PL!N-bp1-027-L", "card_name": "Solitude Rain",
    "card_kind": "ライブ", "rare": "L", "expansion": "BP01",
    "color": "橙", "cost": "ドロー1", "heart": "青5無7",
    "heart0": "7", "heart01": "0", "heart02": "0", "heart03": "0",
    "heart04": "0", "heart05": "5", "heart06": "0",
    "power": "青5無7", "attack": "青1",
    "text": "(エールをすべて行った後、エールで出た[ドロー]1つにつき、カードを1枚引く。)",
    "text_html": "", "work_title": "虹ヶ咲", "unit_name": "-",
    "blade_heart": "0", "comment": "", "parallel_param": "",
}

LIVE_SCORE = {  # id=41 Dream Believers — ★スコアが単独で入る実データ
    "id": 41, "picture": "BP01/PL!HS-bp1-019-L.png",
    "card_number": "PL!HS-bp1-019-L", "card_name": "Dream Believers",
    "card_kind": "ライブ", "rare": "L", "expansion": "BP01",
    "color": "水", "cost": "スコア1", "heart": "無4",
    "heart0": "4", "heart01": "0", "heart02": "0", "heart03": "0",
    "heart04": "0", "heart05": "0", "heart06": "0",
    "power": "無4", "attack": "-",
    "text": "(エールで出た[スコア]1つにつき、成功したライブのスコアの合計に1を加算する。)",
    "text_html": "", "work_title": "蓮ノ空", "unit_name": "-",
    "blade_heart": "1", "comment": "", "parallel_param": "",
}

MULTI_GROUP = {  # id=1 上原歩夢&澁谷かのん&日野下花帆
    "id": 1, "picture": "BP01/LL-bp1-001-R2.png",
    "card_number": "LL-bp1-001-R\uff0b", "card_name": "上原歩夢&澁谷かのん&日野下花帆",
    "card_kind": "メンバー", "rare": "R+", "expansion": "BP01",
    "color": "桃", "cost": "20", "heart": "桃3緑3紫3",
    "heart0": "0", "heart01": "3", "heart02": "0", "heart03": "0",
    "heart04": "3", "heart05": "0", "heart06": "3",
    "power": "桃3緑3紫3", "attack": "5",
    "text": "【登場】自分の控え室からメンバーカードを1枚手札に加える。\n【ライブ開始時】…",
    "text_html": "", "work_title": "虹ヶ咲/Liella!/蓮ノ空", "unit_name": "-",
    "blade_heart": "-", "comment": "illust/オペラハウス", "parallel_param": "",
}

ENERGY_ODD_NAME = {  # id=126 改行を含むカード名
    "id": 126, "picture": "BP01/PL!N-bp1-034-PE.png",
    "card_number": "PL!N-bp1-034-PE", "card_name": "UEHARA\nAYUMU",
    "card_kind": "エネルギー", "rare": "PE", "expansion": "BP01",
    "color": "橙", "cost": "", "heart": "",
    "heart0": "0", "heart01": "0", "heart02": "0", "heart03": "0",
    "heart04": "0", "heart05": "0", "heart06": "0",
    "power": "", "attack": "", "text": "", "text_html": "",
    "work_title": "虹ヶ咲", "unit_name": "-",
    "blade_heart": "-", "comment": "", "parallel_param": "\u3007",
}

IRREGULAR_IMAGE = {  # id=127 picture のハイフンがアンダースコアになる例
    "id": 127, "picture": "BP01/PL!N-bp1_034-PE2.png",
    "card_number": "PL!N-bp1-034-PE\uff0b", "card_name": "UEHARA AYUMU",
    "card_kind": "エネルギー", "rare": "PE+", "expansion": "BP01",
    "color": "橙", "cost": "", "heart": "",
    "heart0": "0", "heart01": "0", "heart02": "0", "heart03": "0",
    "heart04": "0", "heart05": "0", "heart06": "0",
    "power": "", "attack": "", "text": "", "text_html": "",
    "work_title": "虹ヶ咲", "unit_name": "-",
    "blade_heart": "-", "comment": "", "parallel_param": "",
}


def _detail(card, relations=None, faqs=None):
    return {
        "card": card,
        "relationCards": relations or [],
        "faqs": faqs or [],
        "expansion": {"id": "BP01", "name": "ブースターパック vol.1",
                      "release_date": "2025.02.08", "slug": "bp01",
                      "url": "https://llofficial-cardgame.com/products/bp01/"},
    }


# --------------------------------------------------------------------------
def test_card_number_split():
    """§4: レアリティ接尾を除いた部分が cardNumber."""
    cases = {
        "LL-bp1-001-R\uff0b": ("LL-bp1-001-R+", "LL-bp1-001"),
        "PL!N-bp1-034-PE\uff0b": ("PL!N-bp1-034-PE+", "PL!N-bp1-034"),
        "PL!-bp1-000-LLE": ("PL!-bp1-000-LLE", "PL!-bp1-000"),
        "PL!N-bp1-999-SEC\uff0b": ("PL!N-bp1-999-SEC+", "PL!N-bp1-999"),
    }
    for raw, (expected_printing, expected_number) in cases.items():
        card, printing = normalize_card({**MULTI_GROUP, "card_number": raw})
        assert printing.printing_id == expected_printing, raw
        assert card.card_number == expected_number, raw
    print("  OK cardNumber の切り出し (全角プラスの NFKC 含む)")


def test_member_fields():
    """§2: メンバーは attack=ブレード, blade_heart=ブレードハート."""
    card, printing = normalize_card(MEMBER_WITH_BLADE_HEART)
    assert card.cost == 10
    assert card.blade_count == 2, "attack はブレード数値"
    assert card.hearts == {"GREEN": 1, "BLUE": 3}, card.hearts
    assert card.blade_hearts == {"BLUE": 1}, "blade_heart はブレードハート"
    assert card.score is None
    assert card.heart_total == 4
    assert card.stats == 6, "決定 D14: ブレード + ハート"
    assert card.unit_names == ["A・ZU・NA"]
    assert printing.parallel_param_raw == "\u3007", "生値は保持する"
    assert printing.parallel_source == "unknown", \
        "parallel_param からは判定しない。判定は parallel=normal の集合で行う"
    print("  OK メンバーのフィールド分岐 (ブレードハートあり)")


def test_member_without_blade_heart():
    card, _ = normalize_card(MEMBER_NO_BLADE_HEART)
    assert card.blade_hearts == {}, '"-" は無しとして扱う'
    assert card.hearts == {"YELLOW": 1}, "heart03 = 黄 (系統A)"
    print("  OK メンバーのブレードハート無し")


def test_live_fields():
    """§2: ライブは blade_heart=スコア, attack=ブレードハート."""
    card, printing = normalize_card(LIVE)
    assert card.score == 2, "blade_heart がスコア"
    assert card.cost is None
    assert card.required_hearts == {"GREEN": 1, "BLUE": 1, "GRAY": 3}, card.required_hearts
    assert card.required_heart_total == 5
    assert card.blade_hearts == {"ALL": 1}, "attack がブレードハート"
    print("  OK ライブのフィールド分岐 (スコア/必要ハート/ブレードハート)")


def test_blade_heart_effects_split_live():
    """★A-1: ブレードハートの色と効果アイコンを別フィールドに分ける.

    総合ルール 8.3.14 が合算するのは色のみ。
    ドロー (8.3.12.1) とスコア (8.4.2.1) は処理する時点も対象も違うため、
    同じ辞書に載せると Phase 3a の集計で取り違える。
    Dart 側の HeartColor.fromKey も未知キーで throw する。
    """
    draw, _ = normalize_card(LIVE_DRAW)
    assert draw.blade_hearts == {"BLUE": 1}, f"色だけが残る: {draw.blade_hearts}"
    assert draw.blade_heart_effects == {"DRAW": 1}, draw.blade_heart_effects

    score, _ = normalize_card(LIVE_SCORE)
    assert score.blade_hearts == {}, f"色は無い: {score.blade_hearts}"
    assert score.blade_heart_effects == {"SCORE": 1}, score.blade_heart_effects

    # 色しか持たないライブは効果側が空になる
    plain, _ = normalize_card(LIVE)
    assert plain.blade_hearts == {"ALL": 1}
    assert plain.blade_heart_effects == {}
    print("  OK ★ライブのブレードハートを色と効果アイコンに分離")


def test_blade_heart_without_count():
    """★A-3: 数字を省いた表記を取りこぼさない.

    公式は同じ意味を複数の書き方で入れてくる (実測):
        'ドロー1' 24 刷り / 'ドロー' 48 刷り / '[ドロー]' 3 刷り
    数字必須の正規表現だったため 59 種でブレードハートが欠落していた。
    総合ルール 8.3.12.1 / 8.4.2.1 の入力そのものが落ちる。
    """
    cases = {
        "ドロー1": {"DRAW": 1},
        "ドロー": {"DRAW": 1},
        "[ドロー]": {"DRAW": 1},
        "［ドロー］": {"DRAW": 1},   # 全角角括弧は現データに無いが防御的に受ける
        "スコア1": {"SCORE": 1},
        "スコア": {"SCORE": 1},
        "[スコア]": {"SCORE": 1},
    }
    for value, expected in cases.items():
        card, _ = normalize_card({**LIVE, "cost": value, "attack": "-"})
        assert card.blade_heart_effects == expected, f"{value!r} -> {card.blade_heart_effects}"
        assert card.blade_hearts == {}, f"{value!r} で色側に混入している"
    print("  OK ★数字なし・角括弧つきのドロー/スコアを取りこぼさない")


def test_blade_heart_all_blade_alias():
    """★A-3: '[全ブレード]' はパラレル刷りにおける 'ALL1' の別表記.

    実データ 5 刷りすべてで、同一 cardNumber の通常刷りが 'ALL1' かつ
    スコアも同値。総合ルール上「同一カードナンバー = 同一のカード」なので
    ALL 1 個として扱う。V15 がこの推論の裏を取り続ける。
    """
    normal, _ = normalize_card({**LIVE, "attack": "ALL1"})
    parallel, _ = normalize_card({**LIVE, "attack": "[全ブレード]"})
    assert normal.blade_hearts == {"ALL": 1}
    assert parallel.blade_hearts == normal.blade_hearts, parallel.blade_hearts
    assert parallel.blade_heart_effects == {}
    print("  OK ★[全ブレード] を ALL1 と同じに解釈する")


def test_color_tokens_unaffected_by_optional_count():
    """数字を任意にしても色の解釈が変わらないこと (回帰防止).

    実測では色トークンの出現 5,367 刷り分すべてが数字を伴っており、
    A-3 の修正で色が変化してはならない。
    """
    card, _ = normalize_card({**LIVE, "attack": "緑1青3無2"})
    assert card.blade_hearts == {"GREEN": 1, "BLUE": 3, "GRAY": 2}, card.blade_hearts
    member, _ = normalize_card(MEMBER_WITH_BLADE_HEART)
    assert member.blade_hearts == {"BLUE": 1}
    print("  OK 数字ありの色トークンは従来どおり解釈される")


def test_validation_v15_detects_printing_mismatch():
    """V15: 刷りごとにブレードハートが違えば検出すること."""
    details = [
        _detail({**LIVE, "card_number": "PL!N-bp1-025-L", "id": 117, "attack": "ALL1"}),
        _detail({**LIVE, "card_number": "PL!N-bp1-025-SECL", "id": 900, "attack": "赤1"}),
    ]
    result = normalize_all(details)
    report = validate(result)
    assert any(i.code == "V15" for i in report.issues), "刷り間の不一致を検出できていない"
    assert not any(i.code == "V15" and i.level == "ERROR" for i in report.issues), \
        "V15 は WARN。公式側の記載揺れが実在するため build を止めてはいけない"
    print("  OK V15 が刷り間のブレードハート不一致を検出する")


def test_blade_heart_effects_split_member():
    """メンバーのブレードハートは実データ上すべて色。効果側は常に空になる."""
    card, _ = normalize_card(MEMBER_WITH_BLADE_HEART)
    assert card.blade_hearts == {"BLUE": 1}
    assert card.blade_heart_effects == {}, "メンバーに DRAW/SCORE は実在しない"

    none, _ = normalize_card(MEMBER_NO_BLADE_HEART)
    assert none.blade_hearts == {} and none.blade_heart_effects == {}
    print("  OK メンバーのブレードハートも同じ経路で分離される")


def test_color_mapping_matches_official_string():
    """★V2: heart 文字列と heartNN が一致すること (色マッピング系統A)."""
    for sample in (MEMBER_WITH_BLADE_HEART, MEMBER_NO_BLADE_HEART, LIVE, MULTI_GROUP):
        card, _ = normalize_card(sample)
        expected = heart_icons_to_map(parse_heart_string(sample["heart"]))
        actual = card.hearts or card.required_hearts
        assert expected == actual, f'{sample["card_number"]}: {expected} != {actual}'
    print("  OK 色マッピング系統A が heart 文字列と一致")


def test_multi_group_and_character():
    """総合ルール 2.3.2.1 / 2.4.2.1: 複数キャラ・複数グループ."""
    card, printing = normalize_card(MULTI_GROUP)
    assert card.character_names == ["上原歩夢", "澁谷かのん", "日野下花帆"]
    assert card.group_names == ["虹ヶ咲", "Liella!", "蓮ノ空"]
    assert card.unit_names == []
    assert printing.illustrator == "オペラハウス"
    print("  OK 複数キャラ・複数グループ・イラストレーター")


def test_name_normalization():
    card, _ = normalize_card(ENERGY_ODD_NAME)
    assert card.name == "UEHARA AYUMU", card.name
    print("  OK カード名の改行を正規化")


def test_keywords():
    card, _ = normalize_card(MEMBER_WITH_BLADE_HEART)
    assert "ENTER" in card.keywords
    assert "LIVE_START" in card.keywords
    print("  OK キーワード能力の抽出")


def test_keyword_bracket_variants():
    """★A-2: ターン回数制限の括弧の表記ゆれを吸収する.

    実測 (card.text):
        '[ターン1回]'  半角     271 刷り
        '［ターン1回］' 全角角括弧   9 刷り  ← 4 種で TURN_1 を取り逃していた
        '[ターン2回]'  半角      15 刷り
        '【ターン2回】' 全角墨括弧   0 刷り  ← 予防的に対応する
    """
    for text in ("【自動】[ターン1回]この効果は…",
                 "【自動】［ターン1回］この効果は…",
                 "【自動】【ターン1回】この効果は…"):
        card, _ = normalize_card({**MEMBER_WITH_BLADE_HEART, "text": text})
        assert "TURN_1" in card.keywords, f"{text!r} で TURN_1 が付かない"

    for text in ("【起動】[ターン2回]…", "【起動】【ターン2回】…"):
        card, _ = normalize_card({**MEMBER_WITH_BLADE_HEART, "text": text})
        assert "TURN_2" in card.keywords, f"{text!r} で TURN_2 が付かない"
    print("  OK ★ターン回数制限の括弧ゆれ (半角/全角角括弧/墨括弧) を吸収")


def test_effect_text_not_normalized():
    """★キーワード照合の NFKC が効果テキスト本体を書き換えないこと.

    効果テキストに NFKC をかけると実データ 1,806 刷り中 897 刷りが変化し
    ('：'->':' 669 刷り、'＋'->'+' 212 刷りなど)、表示が公式表記から乖離する。
    正規化してよいのは照合用のコピーだけ。
    """
    text = "【起動】[E]、このメンバーを控え室に置く：スコアを＋１する。"
    card, _ = normalize_card({**MEMBER_WITH_BLADE_HEART, "text": text})
    assert card.effect_text == text, card.effect_text
    assert "：" in card.effect_text and "＋" in card.effect_text and "１" in card.effect_text
    print("  OK 効果テキスト本体は NFKC で書き換えない")


def test_image_path_not_constructed():
    """§5: picture は組み立てず実値をそのまま使う."""
    _, printing = normalize_card(IRREGULAR_IMAGE)
    assert printing.picture == "BP01/PL!N-bp1_034-PE2.png"
    assert "_034" in printing.picture, "ハイフンがアンダースコアになる例外を保持"
    print("  OK 画像パスを組み立てず実値保持")


def test_parallel_from_official_filter():
    """パラレル判定は公式検索 parallel=normal の集合で決まる."""
    details = [
        _detail({**MEMBER_NO_BLADE_HEART, "card_number": "PL!N-bp1-002-R", "id": 74,
                 "rare": "R"}),
        _detail({**MEMBER_NO_BLADE_HEART, "card_number": "PL!N-bp1-002-P", "id": 75,
                 "rare": "P"}),
        _detail({**MEMBER_NO_BLADE_HEART, "card_number": "PL!N-bp1-002-SEC", "id": 78,
                 "rare": "SEC"}),
    ]
    result = normalize_all(details, base_printing_ids={"PL!N-bp1-002-R"})
    normals = sorted(p.printing_id for p in result.printings.values()
                     if not p.is_parallel)
    assert normals == ["PL!N-bp1-002-R"], normals
    assert all(p.parallel_source == "official" for p in result.printings.values())
    print("  OK パラレル判定を parallel=normal の集合で行う")


def test_multiple_normals_from_reprint():
    """★同じカードが複数商品に再録されると通常刷りが複数になる.

    実測で出た形:
        PL!N-bp1-019-N  (ブースター) と PL!N-bp1-019-PR  (プロモ)
        PL!N-sd1-001-SD と PL!N-sd1-001-SD2 (スタートデッキ2種)
    これはエラーではなく正常。公式の parallel=normal も両方返す。
    """
    details = [
        _detail({**MEMBER_NO_BLADE_HEART, "card_number": "PL!N-bp1-019-N",
                 "id": 111, "rare": "N"}),
        _detail({**MEMBER_NO_BLADE_HEART, "card_number": "PL!N-bp1-019-PR",
                 "id": 900, "rare": "PR"}),
        _detail({**MEMBER_NO_BLADE_HEART, "card_number": "PL!N-bp1-019-SEC",
                 "id": 901, "rare": "SEC"}),
    ]
    base = {"PL!N-bp1-019-N", "PL!N-bp1-019-PR"}
    result = normalize_all(details, base_printing_ids=base)
    normals = sorted(p.printing_id for p in result.printings.values()
                     if not p.is_parallel)
    assert normals == ["PL!N-bp1-019-N", "PL!N-bp1-019-PR"], normals

    report = validate(result)
    v4 = [i for i in report.issues if i.code == "V4" and i.level == "ERROR"]
    assert not v4, [i.message for i in v4]
    print("  OK 再録による複数通常刷りをエラーにしない")


def test_energy_parallel_guessed_by_rarity():
    """エネルギーは公式 parallel=normal に含まれないためレアリティから推定する."""
    details = [
        _detail({**ENERGY_ODD_NAME, "card_number": "PL!N-bp1-034-PE",
                 "id": 126, "rare": "PE"}),
        _detail({**ENERGY_ODD_NAME, "card_number": "PL!N-bp1-034-PE\uff0b",
                 "id": 127, "rare": "PE+"}),
    ]
    result = normalize_all(details, base_printing_ids={"OTHER-CARD-R"})
    normals = sorted(p.printing_id for p in result.printings.values()
                     if not p.is_parallel)
    assert normals == ["PL!N-bp1-034-PE"], normals
    assert all(p.parallel_source == "rarity_guess"
               for p in result.printings.values())

    # パラレル表示 OFF で消えないこと
    report = validate(result)
    v4 = [i for i in report.issues if i.code == "V4" and i.level == "ERROR"]
    assert not v4, [i.message for i in v4]
    print("  OK エネルギーのパラレルをレアリティから推定")


def test_parallel_guess_is_deterministic():
    """推定が入力順に依存しないこと."""
    cards = [
        {**ENERGY_ODD_NAME, "card_number": "X-1-SECE", "id": 3, "rare": "SECE"},
        {**ENERGY_ODD_NAME, "card_number": "X-1-LLE", "id": 1, "rare": "LLE"},
        {**ENERGY_ODD_NAME, "card_number": "X-1-PE\uff0b", "id": 2, "rare": "PE+"},
    ]
    picks = []
    for order in ([0, 1, 2], [2, 1, 0], [1, 2, 0]):
        result = normalize_all([_detail(cards[i]) for i in order],
                               base_printing_ids={"OTHER"})
        picks.append(sorted(p.printing_id for p in result.printings.values()
                            if not p.is_parallel))
    assert len(set(map(tuple, picks))) == 1, picks
    assert picks[0] == ["X-1-LLE"], picks[0]
    print("  OK パラレル推定が入力順に依存しない")


def test_canonical_unit_names():
    """★実データの表記ゆれを正典表記に統一する.

    'みらくらぱーく！' (全角) と 'みらくらぱーく!' (半角) が混在しており、
    そのままでは同じユニットが 2 つに分裂して検索が片方しかヒットしない。
    """
    a, _ = normalize_card({**MEMBER_WITH_BLADE_HEART, "unit_name": "みらくらぱーく！"})
    b, _ = normalize_card({**MEMBER_WITH_BLADE_HEART, "unit_name": "みらくらぱーく!"})
    assert a.unit_names == b.unit_names == ["みらくらぱーく！"], (a.unit_names, b.unit_names)

    # 新規ユニットは勝手に変えない
    c, _ = normalize_card({**MEMBER_WITH_BLADE_HEART, "unit_name": "未知のユニット"})
    assert c.unit_names == ["未知のユニット"]
    print("  OK ユニット名の表記ゆれを正典表記に統一")


def test_rarity_normalized():
    """レアリティの全角プラスを半角に統一する (P＋ と P+ の混在)."""
    _, a = normalize_card({**MEMBER_WITH_BLADE_HEART, "rare": "P\uff0b"})
    _, b = normalize_card({**MEMBER_WITH_BLADE_HEART, "rare": "P+"})
    assert a.rarity == b.rarity == "P+", (a.rarity, b.rarity)
    print("  OK レアリティの表記ゆれを統一")


def test_validation_detects_name_variants():
    """V13: 表記ゆれが残っていれば検出すること (回帰防止)."""
    result = normalize_all([_detail(MEMBER_WITH_BLADE_HEART)])
    # 正規化を迂回して意図的にゆれを作る
    card = next(iter(result.cards.values()))
    card.unit_names = ["みらくらぱーく！"]
    other = Card(card_number="X-1", name="x", card_type="メンバー",
                 unit_names=["みらくらぱーく!"])
    result.cards["X-1"] = other

    report = validate(result)
    v13 = [i for i in report.issues if i.code == "V13"]
    assert v13, "表記ゆれを検出できていない"
    print("  OK V13 が表記ゆれを検出する")


def test_relation_cards_across_expansions():
    """★V3: 他商品の刷りが relationCards に含まれても誤検出しないこと.

    relationCards は全商品を横断した一覧を返すため、
    1 商品しか取得していない状態では「公式にあってこちらに無い」が大量に出る。
    それは欠損であって切り出し規則の誤りではない。
    """
    details = [
        _detail({**MEMBER_NO_BLADE_HEART, "card_number": "PL!N-bp1-014-N", "id": 106},
                # 実測で出現した他商品の刷り
                relations=[{"card_number": "PL!N-bp1-014-PRproteinbar"}]),
    ]
    result = normalize_all(details)
    report = validate(result)
    v3_errors = [i for i in report.issues if i.code == "V3" and i.level == "ERROR"]
    assert not v3_errors, [i.message for i in v3_errors]
    print("  OK 他商品の刷りを含む relationCards で誤検出しない")


def test_split_handles_real_suffixes():
    """実測で出現した全レアリティ接尾で切り出しが成立すること."""
    cases = {
        "PL!N-bp1-014-PRproteinbar": "PL!N-bp1-014",
        "PL!SP-bp1-023-SRL": "PL!SP-bp1-023",
        "PL!SP-bp1-025-L\uff0b": "PL!SP-bp1-025",
        "PL!HS-bp1-002-RM": "PL!HS-bp1-002",
        "PL!HS-bp1-019-SECL": "PL!HS-bp1-019",
        "PL!N-bp1-026-SECL": "PL!N-bp1-026",
        "PL!N-bp1-030-SECE": "PL!N-bp1-030",
    }
    for printing_id, expected in cases.items():
        assert split_card_number(printing_id) == expected, printing_id
    print("  OK 実測レアリティ接尾すべてで切り出し成立")


def test_validation_v3_relation_cards():
    """★V3: relationCards と自前グルーピングの一致."""
    details = [
        _detail({**MEMBER_NO_BLADE_HEART, "card_number": "PL!N-bp1-002-P", "id": 75},
                relations=[{"card_number": "PL!N-bp1-002-R\uff0b"},
                           {"card_number": "PL!N-bp1-002-SEC"}]),
        _detail({**MEMBER_NO_BLADE_HEART, "card_number": "PL!N-bp1-002-R\uff0b",
                 "id": 77, "parallel_param": ""}),
        _detail({**MEMBER_NO_BLADE_HEART, "card_number": "PL!N-bp1-002-SEC",
                 "id": 78, "parallel_param": ""}),
    ]
    result = normalize_all(details)
    report = validate(result)
    v3 = [i for i in report.issues if i.code == "V3"]
    assert not v3, [i.message for i in v3]
    assert len(result.cards) == 1, "3 刷りが 1 つの cardNumber に集約される"
    print("  OK V3 relationCards と自前グルーピングが一致")


def test_validation_detects_bad_grouping():
    """切り出し規則が誤っていれば V3 が検出すること (回帰防止)."""
    details = [
        _detail({**MEMBER_NO_BLADE_HEART, "card_number": "PL!N-bp1-002-P", "id": 75},
                relations=[{"card_number": "PL!N-bp1-999-SEC"}]),
    ]
    result = normalize_all(details)
    report = validate(result)
    assert any(i.code == "V3" for i in report.issues), "不一致を検出できていない"
    print("  OK V3 が不一致を検出する")


def test_validation_v7_duplicate_color():
    """V7: 同色のハート音符が重複したら検出すること."""
    details = [_detail({**MEMBER_WITH_BLADE_HEART, "heart": "緑1緑3"})]
    result = normalize_all(details)
    report = validate(result)
    assert any(i.code == "V7" for i in report.issues), "同色重複を検出できていない"
    print("  OK V7 が同色重複を検出する")


def test_faq_dedup():
    faq = {"id": 6017, "qa_id": "63", "question": "Q", "answer": "A",
           "card_names": "[PL!HS-bp1-002-R ： 村野さやか] [PL!N-bp1-002-P ： 中須かすみ]",
           "date": "2026-08-07", "regist_time": "2025-02-07", "update_time": "2025-02-07"}
    details = [
        _detail({**MEMBER_NO_BLADE_HEART, "id": 75}, faqs=[faq]),
        _detail({**MEMBER_WITH_BLADE_HEART, "id": 79}, faqs=[faq]),
    ]
    result = normalize_all(details)
    assert len(result.faqs) == 1, "qa_id で重複排除される"
    assert result.faqs["63"].card_numbers == ["PL!HS-bp1-002-R", "PL!N-bp1-002-P"]
    assert result.faqs["63"].regist_time == "2025-02-07", "date ではなく regist_time"
    print("  OK Q&A の重複排除と関連カード抽出")


if __name__ == "__main__":
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    print(f"テスト {len(tests)} 件を実行\n")
    failed = 0
    for test in tests:
        try:
            test()
        except AssertionError as exc:
            print(f"  NG {test.__name__}: {exc}")
            failed += 1
    print(f"\n{'全て成功' if not failed else f'{failed} 件失敗'}")
    sys.exit(1 if failed else 0)
