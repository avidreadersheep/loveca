"""段階 0-3: 公式サイトからの取得.

実装仕様書 v1.0 §6 に対応。

ここだけが公式サイトにアクセスする。取得結果は生のまま raw/ に保存し、
以降の段階は raw/ のみを入力とする (P2: 取得と正規化の分離)。

再実行時は既に保存済みのファイルをスキップするため、中断しても安全に再開できる。
"""

from __future__ import annotations

import json
import logging
import unicodedata
from pathlib import Path

from .config import Config
from .constants import API_BASE, IMAGE_BASE, KIND_ENERGY, NO_VALUE
from .http_client import AbortError, FetchError, RateLimitedClient

log = logging.getLogger(__name__)


def _save_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


# ---------------------------------------------------------------------------
# 段階 0: 検索フォーム定義 (全商品コードの取得元)
# ---------------------------------------------------------------------------
def fetch_search_form(cfg: Config, client: RateLimitedClient, *, force: bool = False) -> dict:
    if cfg.search_form_path.exists() and not force:
        log.info("段階0: search_form はキャッシュ済み")
        return json.loads(cfg.search_form_path.read_text(encoding="utf-8"))

    log.info("段階0: 検索フォーム定義を取得")
    data = client.get_json(f"{API_BASE}/createSearchForm")
    _save_json(cfg.search_form_path, data)
    return data


def _field_iter(search_form: dict):
    """items[*].fields[*] を (name, label, field) で列挙する."""
    for group in search_form.get("items") or []:
        if not isinstance(group, dict):
            continue
        for field in group.get("fields") or []:
            if isinstance(field, dict):
                yield field.get("name", ""), field.get("label", ""), field


def extract_expansions(search_form: dict) -> list[str]:
    """検索フォーム定義から商品コード一覧を取り出す.

    実測した構造 (2026-08 時点):
        expansion_categories : dict  キーが商品コード、値がカテゴリ
        items[*].fields[*]   : 検索フォームの各項目。master に選択肢が入る
        legacy               : 旧形式のマッピング

    ★ 辞書の「キー」側に商品コードが入るため、値だけを見ても見つからない。
    """
    # 1) expansion_categories のキー (最有力)
    node = search_form.get("expansion_categories")
    if isinstance(node, dict) and node:
        return [k for k in node.keys() if k]

    # 2) 収録商品を選ぶフィールドの master のキー
    for name, label, field in _field_iter(search_form):
        if name in ("title", "expansion", "expansion_id") or label in ("title", "収録商品"):
            master = field.get("master")
            if isinstance(master, dict) and master:
                return [k for k in master.keys() if k and k not in ("all", "")]
            if isinstance(master, list) and master:
                out = []
                for item in master:
                    if isinstance(item, dict):
                        for key in ("id", "value", "code"):
                            if item.get(key):
                                out.append(str(item[key]))
                                break
                    elif isinstance(item, str) and item:
                        out.append(item)
                if out:
                    return out

    # 3) 既知のキー候補の配列
    for key in ("expansions", "expansion", "titles", "products", "expansionList"):
        seq = search_form.get(key)
        if isinstance(seq, list) and seq:
            out = []
            for item in seq:
                if isinstance(item, dict):
                    for id_key in ("id", "value", "code", "key", "slug"):
                        if item.get(id_key):
                            out.append(str(item[id_key]))
                            break
                elif isinstance(item, str) and item:
                    out.append(item)
            if out:
                return out

    return []


def extract_rarities(search_form: dict) -> list[str]:
    """レアリティの全一覧を取り出す (検証・診断用).

    実測: N R P PP RM AR SEC SRE RE PE SECE LLE L SRL SECL SECS SD SD2 CL PR
    ★ ただし card_number の接尾はこの一覧に無い値も取りうる
      (例: PRproteinbar)。ホワイトリスト化してはいけない。
    """
    legacy = search_form.get("legacy")
    if isinstance(legacy, dict):
        node = legacy.get("rare_select")
        if isinstance(node, dict) and node:
            return [k for k in node.keys() if k]
    for name, label, field in _field_iter(search_form):
        if name in ("rare", "rarity"):
            master = field.get("master")
            if isinstance(master, dict) and master:
                return [k for k in master.keys() if k]
    return []


def describe_search_form(search_form: dict) -> str:
    """search_form.json の構造を人間可読に要約する (診断用)."""
    lines = ["--- トップレベルのキー ---"]
    for key, value in search_form.items():
        kind = type(value).__name__
        size = f" ({len(value)} 件)" if isinstance(value, (list, dict)) else ""
        lines.append(f"  {key}: {kind}{size}")

    # 辞書型のトップレベル要素は「キー」に情報があることが多い
    lines.append("")
    lines.append("--- 辞書型トップレベル要素のキー ---")
    for key, value in search_form.items():
        if isinstance(value, dict) and value:
            keys = list(value.keys())
            shown = ", ".join(map(str, keys[:30]))
            more = f" ... 他 {len(keys) - 30} 件" if len(keys) > 30 else ""
            lines.append(f"  {key}: {shown}{more}")

    lines.append("")
    lines.append("--- 検索フォームの項目と選択肢 ---")
    for name, label, field in _field_iter(search_form):
        master = field.get("master")
        if isinstance(master, dict) and master:
            keys = list(master.keys())
            shown = ", ".join(map(str, keys[:25]))
            more = f" ... 他 {len(keys) - 25} 件" if len(keys) > 25 else ""
            lines.append(f"  {name} ({label}) [{field.get('type')}]: {shown}{more}")
        elif isinstance(master, list) and master:
            lines.append(f"  {name} ({label}) [{field.get('type')}]: "
                         f"{json.dumps(master[:3], ensure_ascii=False)[:200]}")
        else:
            lines.append(f"  {name} ({label}) [{field.get('type')}]")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# 段階 1: 一覧 (id の収集)
# ---------------------------------------------------------------------------
def fetch_list(cfg: Config, client: RateLimitedClient, expansion: str,
               *, parallel: str | None = None, force: bool = False) -> list[dict]:
    """1 商品の全ページを取得し、items を連結して返す.

    parallel: 公式検索の絞り込み。'normal' を指定すると
        パラレル表示 OFF 時に表示される刷りだけが返る。
        基本刷り (isBasePrinting) の判定に使う。
    """
    items: list[dict] = []
    page = 1
    total: int | None = None
    suffix = f"_{parallel}" if parallel else ""

    while True:
        path = cfg.raw_list_dir / f"{expansion}_{page}{suffix}.json"
        if path.exists() and not force:
            data = json.loads(path.read_text(encoding="utf-8"))
        else:
            log.info("段階1: list %s page=%s%s", expansion, page,
                     f" parallel={parallel}" if parallel else "")
            params = {
                "expansion": expansion,
                "per_page": cfg.per_page,
                "page": page,
                "sort": "new",
            }
            if parallel:
                params["parallel"] = parallel
            data = client.get_json(f"{API_BASE}/list", params)
            _save_json(path, data)

        batch = data.get("items") or []
        items.extend(batch)
        total = data.get("total", total)

        if not batch or total is None or len(items) >= int(total):
            break
        page += 1

    if total is not None and len(items) != int(total):
        log.warning("段階1: %s の件数不一致 取得=%s total=%s", expansion, len(items), total)
    return items


def fetch_base_printing_ids(cfg: Config, client: RateLimitedClient,
                            expansions: list[str], *, force: bool = False) -> set[str]:
    """公式検索 parallel=normal の集合を取得し、基本刷りの printingId 集合を返す.

    ★ card.parallel_param は基本刷りフラグではないことが実測で判明した ★
      レアリティ P/P+/SEC/PE/PE+ で非空、R/R+/N/L/LLE/SECE で空となり、
      1 つの cardNumber に複数の「基本刷り」が現れてしまう。
      公式の検索フィルタこそが定義なので、そちらを正典とする。

    detail は増えないので、追加コストは商品あたり数リクエストのみ。
    """
    path = cfg.raw_dir / "base_printings.json"
    if path.exists() and not force:
        return set(json.loads(path.read_text(encoding="utf-8")))

    ids: set[str] = set()
    for expansion in expansions:
        items = fetch_list(cfg, client, expansion, parallel="normal", force=force)
        for item in items:
            number = item.get("card_number")
            if number:
                ids.add(unicodedata.normalize("NFKC", number).strip())
        log.info("段階1: %s の基本刷り %s 件", expansion, len(items))

    _save_json(path, sorted(ids))
    return ids


def load_base_printing_ids(cfg: Config) -> set[str] | None:
    """保存済みの基本刷り集合を読む (ネットワーク不要)."""
    path = cfg.raw_dir / "base_printings.json"
    if not path.exists():
        return None
    return set(json.loads(path.read_text(encoding="utf-8")))


# ---------------------------------------------------------------------------
# 段階 2: 詳細
# ---------------------------------------------------------------------------
def fetch_detail(cfg: Config, client: RateLimitedClient, card_id: int,
                 *, force: bool = False) -> dict | None:
    path = cfg.raw_detail_dir / f"{card_id}.json"
    if path.exists() and not force:
        return json.loads(path.read_text(encoding="utf-8"))

    try:
        data = client.get_json(f"{API_BASE}/detail", {"id": card_id})
    except FetchError as exc:
        log.error("段階2: detail id=%s 取得失敗: %s", card_id, exc)
        return None

    _save_json(path, data)
    return data


def fetch_all_details(cfg: Config, client: RateLimitedClient, card_ids: list[int],
                      *, force: bool = False) -> tuple[int, list[int]]:
    """戻り値: (成功件数, 失敗した id のリスト)"""
    ok = 0
    failed: list[int] = []
    total = len(card_ids)

    for i, card_id in enumerate(card_ids, 1):
        path = cfg.raw_detail_dir / f"{card_id}.json"
        if path.exists() and not force:
            ok += 1
            continue
        try:
            if fetch_detail(cfg, client, card_id, force=force) is not None:
                ok += 1
            else:
                failed.append(card_id)
        except AbortError:
            log.error("中止しました。%s/%s 件処理済み。再実行で続きから再開できます。", i, total)
            raise
        if i % 50 == 0:
            log.info("段階2: %s/%s 件", i, total)

    return ok, failed


# ---------------------------------------------------------------------------
# 段階 3: 画像
# ---------------------------------------------------------------------------
def fetch_images(cfg: Config, client: RateLimitedClient, pictures: list[str],
                 *, force: bool = False) -> tuple[int, list[str]]:
    """picture フィールドの実値のみを使う。URL は絶対に組み立てない (仕様書 §5)."""
    ok = 0
    failed: list[str] = []
    unique = sorted(set(pictures))
    total = len(unique)

    for i, picture in enumerate(unique, 1):
        dest = cfg.raw_images_dir / picture
        if dest.exists() and not force:
            ok += 1
            continue
        url = f"{IMAGE_BASE}/{picture}"
        try:
            body = client.get_bytes(url)
        except FetchError as exc:
            log.error("段階3: 画像取得失敗 %s: %s", picture, exc)
            failed.append(picture)
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(body)
        ok += 1
        if i % 50 == 0:
            log.info("段階3: %s/%s 枚", i, total)

    return ok, failed


# ---------------------------------------------------------------------------
# 段階 4 の入力組み立て (ネットワーク不要)
# ---------------------------------------------------------------------------
def load_all_list_items(cfg: Config) -> list[dict]:
    """raw/list/ に保存済みの items を全て読む (parallel 絞り込み版は除く)."""
    seen: dict[str, dict] = {}
    for path in sorted(cfg.raw_list_dir.glob("*.json")):
        # {EXP}_{page}_normal.json はパラレル絞り込み用なので除外
        if path.stem.endswith("_normal") or path.stem.endswith("_parallel"):
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        for item in data.get("items") or []:
            number = item.get("card_number")
            if number:
                seen[number] = item
    return list(seen.values())


def energy_pseudo_details(cfg: Config) -> list[dict]:
    """エネルギーカードを list の情報だけで detail 相当に組み立てる.

    エネルギーカードは性能差が無いため detail を取得しない。
    ただしデッキ構築 (総合ルール 6.1.1.3 でエネルギーデッキ 12 枚ちょうど) と
    盤面表示には cardNumber / 名前 / 画像 / レアリティが必要なので、
    list から取れる範囲で補完する。
    """
    out = []
    for item in load_all_list_items(cfg):
        if (item.get("card_kind") or "").strip() != KIND_ENERGY:
            continue
        out.append({
            "card": {
                **item,
                "work_title": item.get("work_title", ""),
                "unit_name": NO_VALUE,
                "blade_heart": NO_VALUE,
                "comment": "",
                "parallel_param": "",
            },
            "relationCards": [],
            "faqs": [],
            "expansion": {},
        })
    return out


def load_normalize_input(cfg: Config) -> list[dict]:
    """正規化の入力を組み立てる (detail + エネルギーの list 由来分).

    ★エネルギーの detail が既に保存されている場合 (取得スキップを入れる前に
      実行した場合) は、そちらを優先し pseudo は捨てる。
      これをしないと printingId が重複する。
    """
    details = load_all_details(cfg)
    known = {
        (d.get("card") or {}).get("card_number")
        for d in details
        if (d.get("card") or {}).get("card_number")
    }
    for pseudo in energy_pseudo_details(cfg):
        number = pseudo["card"].get("card_number")
        if number and number not in known:
            known.add(number)
            details.append(pseudo)
    return details


def load_all_details(cfg: Config) -> list[dict]:
    """raw/detail/ に保存済みの全 JSON を読み込む (ネットワーク不要)."""
    out = []
    for path in sorted(cfg.raw_detail_dir.glob("*.json"), key=lambda p: int(p.stem)):
        out.append(json.loads(path.read_text(encoding="utf-8")))
    return out
