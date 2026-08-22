"""ラブカ カードデータの定数定義.

実装仕様書 v1.0 §3 に対応。

★★ 最重要 ★★
色マッピングは 3 系統存在し、系統 A と系統 B は 02/03/04/05 が食い違う。
絶対に共用しないこと。混同すると効果テキストの色表示が全件誤る。
"""

from __future__ import annotations

BASE_URL = "https://llofficial-cardgame.com"
API_BASE = f"{BASE_URL}/manage/card-list-user"
IMAGE_BASE = f"{BASE_URL}/wordpress/wp-content/images/cardlist"
TEXTICON_BASE = f"{BASE_URL}/wordpress/wp-content/images/texticon"

# --------------------------------------------------------------------------
# カード種別
# --------------------------------------------------------------------------
KIND_MEMBER = "メンバー"
KIND_LIVE = "ライブ"
KIND_ENERGY = "エネルギー"
KNOWN_KINDS = frozenset({KIND_MEMBER, KIND_LIVE, KIND_ENERGY})

# --------------------------------------------------------------------------
# 色 (内部表現)
# --------------------------------------------------------------------------
PINK, RED, YELLOW, GREEN, BLUE, PURPLE = "PINK", "RED", "YELLOW", "GREEN", "BLUE", "PURPLE"
GRAY = "GRAY"  # 総合ルール 2.1.1.2 色を指定しないハート (必要ハート側で使用)
ALL = "ALL"    # 総合ルール 2.1.1.3 任意の 1 色として扱えるハート (所有側で使用)

SIX_COLORS = (PINK, RED, YELLOW, GREEN, BLUE, PURPLE)

# --------------------------------------------------------------------------
# 系統 A: JSON の heartNN フィールド / CSS クラス .heartNN
#   検証: PL!N-bp1-003-P "緑1青3" -> heart04=1, heart05=3
# --------------------------------------------------------------------------
HEART_FIELD = {
    "heart0": GRAY,
    "heart01": PINK,
    "heart02": RED,
    "heart03": YELLOW,
    "heart04": GREEN,
    "heart05": BLUE,
    "heart06": PURPLE,
}

# --------------------------------------------------------------------------
# 系統 B: 画像ファイル heart_NN.png / 効果テキスト中の [heartNN] トークン
#   根拠: PL!N-bp1-027-L の効果テキストが
#         [heart01][heart04][heart05][heart02][heart03][heart06] の順で
#         6 色を列挙しており、この対応だと 桃赤黄緑青紫 (総合ルール 2.1.1.1 の標準順) になる
#   ★系統 A とは 02/03/04/05 が食い違う★
# --------------------------------------------------------------------------
HEART_ICON = {
    "heart_00": GRAY,
    "heart_01": PINK,
    "heart_02": GREEN,
    "heart_03": BLUE,
    "heart_04": RED,
    "heart_05": YELLOW,
    "heart_06": PURPLE,
}

# --------------------------------------------------------------------------
# 系統 C: heart / blade_heart / attack / cost の日本語文字列
# --------------------------------------------------------------------------
HEART_NAME = {
    "桃": PINK,
    "赤": RED,
    "黄": YELLOW,
    "緑": GREEN,
    "青": BLUE,
    "紫": PURPLE,
    "無": GRAY,
    "ALL": ALL,
}

# ブレードハートの特殊アイコン (エール時に色ではない処理を発生させる)
BH_DRAW = "DRAW"    # 総合ルール 8.3.12.1 カードを 1 枚引く
BH_SCORE = "SCORE"  # 総合ルール 8.4.2.1 スコア +1

BLADE_HEART_SPECIAL = {
    "ドロー": BH_DRAW,
    "スコア": BH_SCORE,
}

# --------------------------------------------------------------------------
# キーワード能力 (総合ルール 11 章 + textIcons 実測)
# --------------------------------------------------------------------------
KEYWORD_TOKENS = {
    "【登場】": "ENTER",
    "【常時】": "CONTINUOUS",
    "【起動】": "ACTIVATED",
    "【自動】": "AUTO",
    "【ライブ開始時】": "LIVE_START",
    "【ライブ成功時】": "LIVE_SUCCESS",
    "【センター】": "CENTER",
    "【左サイド】": "LEFT_SIDE",
    "【右サイド】": "RIGHT_SIDE",
    "[ターン1回]": "TURN_1",
    "【ターン1回】": "TURN_1",
    "[ターン2回]": "TURN_2",
}

# --------------------------------------------------------------------------
# 総合ルール 6.1 デッキ構築条件 (RuleConfig の既定値)
# --------------------------------------------------------------------------
RULE_CONFIG = {
    "mainDeckSize": 60,
    "memberCount": 48,
    "liveCount": 12,
    "energyDeckSize": 12,
    "maxCopiesPerCardNumber": 4,
    "initialHandSize": 6,
    "initialEnergyOnField": 3,
    "liveSlotMax": 3,
    "winCondition": 3,
    "stageAreaCount": 3,
}

# --------------------------------------------------------------------------
# 総合ルール 付録 A: グループ名 (検証用)
# --------------------------------------------------------------------------
OFFICIAL_GROUPS = frozenset({
    "μ's", "Aqours", "虹ヶ咲", "Liella!", "蓮ノ空",
    "A-RISE", "Saint Snow", "Sunny Passion",
})

# ★ 比較時は必ず NFKC 正規化すること。
#   公式サイトは 'みらくらぱーく!' (半角)、総合ルール付録Aは 'みらくらぱーく！' (全角) と揺れる。
OFFICIAL_UNITS = frozenset({
    "Printemps", "BiBi", "lily white",
    "CYaRon！", "AZALEA", "Guilty Kiss",
    "QU4RTZ", "A・ZU・NA", "DiverDiva", "R3BIRTH",
    "CatChu!", "KALEIDOSCORE", "5yncri5e!",
    "スリーズブーケ", "DOLLCHESTRA", "みらくらぱーく！",
    "Edel Note", "AiScReam",
})

# 基本刷りを示すマーカー (U+3007 IDEOGRAPHIC NUMBER ZERO)
# ★ 文字リテラル比較はせず `!= ""` で判定すること。ここは記録用。
PARALLEL_PARAM_BASE = "\u3007"

NO_VALUE = "-"  # 「無し」を表す公式の表現
