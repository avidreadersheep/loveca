"""段階 6: 配信物の生成.

設計書 STEP 10 §10.2 に対応。

- 画像はコンテンツハッシュで命名する。これにより画像は不変となり、
  CDN の immutable キャッシュが使える。「差し替え時のキャッシュ無効化」問題が構造的に消える。
- カードデータは商品単位に分割する。新弾追加時に既存ファイルが変化しないため差分更新が効く。
"""

from __future__ import annotations

import hashlib
import json
import logging
from collections import defaultdict
from pathlib import Path

from .config import Config
from .constants import RULE_CONFIG
from .normalize import NormalizeResult

log = logging.getLogger(__name__)


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _write(path: Path, payload: dict) -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    path.write_bytes(body)
    return _sha256(body)


def build_images(cfg: Config, result: NormalizeResult) -> dict[str, str]:
    """3 サイズを生成し、printingId -> imageHash を返す.

    Pillow が無い環境では原本をそのままコピーし、ハッシュのみ確定させる。
    """
    try:
        from PIL import Image
    except ImportError:
        Image = None
        log.warning("=" * 60)
        log.warning("Pillow が見つからないため、画像をリサイズできません。")
        log.warning("原本をそのままコピーします (数 GB になる可能性があります)。")
        log.warning("")
        log.warning("  python -m pip install Pillow")
        log.warning("")
        log.warning("インストール後、dist/images を削除してから build し直してください。")
        log.warning("=" * 60)

    hashes: dict[str, str] = {}
    for printing in result.printings.values():
        src = cfg.raw_images_dir / printing.picture
        if not src.exists():
            continue
        image_hash = _sha256(src.read_bytes())[:32]
        hashes[printing.printing_id] = image_hash

        if Image is None:
            dest = cfg.dist_dir / "images" / "original" / f"{image_hash}.png"
            if not dest.exists():
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(src.read_bytes())
            continue

        for name, (width, quality) in cfg.image_sizes.items():
            dest = cfg.dist_dir / "images" / name / f"{image_hash}.webp"
            if dest.exists():
                continue
            dest.parent.mkdir(parents=True, exist_ok=True)
            with Image.open(src) as img:
                img = img.convert("RGB")
                ratio = width / img.width
                resized = img.resize((width, max(1, round(img.height * ratio))), Image.LANCZOS)
                resized.save(dest, "WEBP", quality=quality)

    return hashes


def build(cfg: Config, result: NormalizeResult, *, data_version: int,
          min_app_version: str, with_images: bool = True) -> dict:
    """配信物を生成する.

    ★★ min_app_version に既定値を置かない (決定 D118-5 = 既-3 / 所見 D-7) ★★
      以前はここが ``"1.0.0"`` の既定値で、**CLI に露出していなかった**。
      その結果、これまでに作った dist はすべて「アプリ 1.0.0 以上」を要求し、
      ★M1 では**アプリの版を上げて**回避した —— データに合わせてアプリを
      変える、という本来と逆の向きである (所見 D-7)。
      → ★既定値そのものを消す。**作る人が毎回考える**。

    ★★ 同じ形の実績が data_version に在る ★★
      data_version は最初から必須引数で、一度も破られていない。

    ★値の妥当性はここでは見ない。``compareVersions`` (loveca_core) は
      数にできない部分を 0 として扱うので、**綴りを間違えると
      「最小版なし」に化ける**。★例外は出ない。CLI のヘルプに書式を書いてある。
    """
    cfg.dist_dir.mkdir(parents=True, exist_ok=True)
    image_hashes = build_images(cfg, result) if with_images else {}

    files: list[dict] = []

    # ---- 商品単位のカードファイル ---------------------------------------
    by_expansion: dict[str, list] = defaultdict(list)
    for printing in result.printings.values():
        by_expansion[printing.expansion or "UNKNOWN"].append(printing)

    for expansion, printings in sorted(by_expansion.items()):
        card_numbers = {p.card_number for p in printings}
        payload = {
            "expansion": expansion,
            "cards": [
                {
                    "cardNumber": c.card_number,
                    "name": c.name,
                    "cardType": c.card_type,
                    "characterNames": c.character_names,
                    "groupNames": c.group_names,
                    "unitNames": c.unit_names,
                    "effectText": c.effect_text,
                    "keywords": c.keywords,
                    "cost": c.cost,
                    "bladeCount": c.blade_count,
                    "score": c.score,
                    "hearts": c.hearts,
                    "requiredHearts": c.required_hearts,
                    # 総合ルール 8.3.14: ライブ所有ハートに合算する色のみ
                    "bladeHearts": c.blade_hearts,
                    # 総合ルール 8.3.12.1 (ドロー) / 8.4.2.1 (スコア +1)。
                    # ★合算対象ではないので色と別フィールドにする★
                    "bladeHeartEffects": c.blade_heart_effects,
                    "heartTotal": c.heart_total,
                    "requiredHeartTotal": c.required_heart_total,
                    "stats": c.stats,
                    # 公式から消えても既存デッキを壊さないため保持する
                    "isDeleted": c.is_deleted,
                }
                for number, c in sorted(result.cards.items()) if number in card_numbers
            ],
            "printings": [
                {
                    "printingId": p.printing_id,
                    "cardNumber": p.card_number,
                    "expansion": p.expansion,
                    "rarity": p.rarity,
                    "rarity": p.rarity,
                    "isParallel": p.is_parallel,
                    "parallelSource": p.parallel_source,
                    "illustrator": p.illustrator,
                    "imageHash": image_hashes.get(p.printing_id, ""),
                }
                for p in sorted(printings, key=lambda x: x.printing_id)
            ],
        }
        path = cfg.dist_dir / "cards" / f"{expansion}.json"
        files.append({
            "path": f"cards/{expansion}.json",
            "hash": f"sha256:{_write(path, payload)}",
            "bytes": path.stat().st_size,
            "cardCount": len(payload["cards"]),
        })

    # ---- メタ ------------------------------------------------------------
    # ★配信 JSON のキーは camelCase で統一する。
    #  dataclass の asdict() は snake_case になるため明示的に変換する。
    meta_files = {
        "meta/products.json": {
            "products": [
                {
                    "expansionId": p.expansion_id,
                    "name": p.name,
                    "releaseDate": p.release_date,
                    "slug": p.slug,
                    "url": p.url,
                }
                for p in sorted(result.products.values(), key=lambda x: x.expansion_id)
            ]
        },
        "meta/faqs.json": {
            "faqs": [
                {
                    "faqId": f.faq_id,
                    "qaId": f.qa_id,
                    "question": f.question,
                    "answer": f.answer,
                    "registTime": f.regist_time,
                    "updateTime": f.update_time,
                    "cardNumbers": sorted(f.card_numbers),
                }
                for f in sorted(result.faqs.values(), key=lambda x: int(x.qa_id or 0))
            ]
        },
        "meta/ruleConfig.json": RULE_CONFIG,
    }
    for rel_path, payload in meta_files.items():
        path = cfg.dist_dir / rel_path
        files.append({
            "path": rel_path,
            "hash": f"sha256:{_write(path, payload)}",
            "bytes": path.stat().st_size,
        })

    # ---- manifest / version ---------------------------------------------
    manifest = {"dataVersion": data_version, "files": files}
    manifest_hash = _write(cfg.dist_dir / "manifest.json", manifest)

    version = {
        "dataVersion": data_version,
        "minAppVersion": min_app_version,
        "manifestPath": "/data/manifest.json",
        "manifestHash": f"sha256:{manifest_hash}",
    }
    _write(cfg.dist_dir / "version.json", version)

    # ---- 容量レポート ----------------------------------------------------
    def _dir_size(path: Path) -> int:
        if not path.exists():
            return 0
        return sum(f.stat().st_size for f in path.rglob("*") if f.is_file())

    json_bytes = sum(f["bytes"] for f in files)
    log.info("配信物を生成: %s ファイル / カード %s 種 / 刷り %s 件",
             len(files), len(result.cards), len(result.printings))
    log.info("  JSON  %.1f MB", json_bytes / 1024 / 1024)

    images_root = cfg.dist_dir / "images"
    if images_root.exists():
        for sub in sorted(images_root.iterdir()):
            if sub.is_dir():
                size = _dir_size(sub)
                count = sum(1 for _ in sub.glob("*"))
                log.info("  画像 %-9s %6.1f MB (%s 枚)", sub.name, size / 1024 / 1024, count)
        if (images_root / "original").exists():
            log.warning("  ★ images/original はリサイズ未実施の原本です。"
                        "Pillow を入れて再実行してください")

    return manifest
