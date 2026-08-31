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


def build_image_manifest(cfg: Config, image_hashes: dict[str, str]) -> list[dict]:
    """配る画像だけのマニフェストの行を組み立てる.

    ★★ 画像は「別のマニフェスト」に載せる (決定 D121-1 = 画-5 / N-2) ★★
      カードとメタのマニフェスト (`manifest.json`) には 1 行も足さない。
      決め手は **カードとメタのマニフェストの意味を 1 ミリも動かさないこと**
      であり、そこには 決定 D118-1 (商品単位) と 決定 D118-3 (版ゲート) が
      乗っている。★カードの変更と画像の変更が独立に運べる。

    ★★ 柵: 行のハッシュは「配るバイト列」から作る (決定 D121-2) ★★
      `imageHash` は **原本 PNG** のハッシュであって、配る WebP の中身を
      名指していない (所見 **D-4**)。★ここで名前ではなく **ディスク上の
      バイト列** を読んでハッシュを取るので、段の生成設定を変えれば
      行のハッシュが必ず変わる。★名前が中身を指す必要が無くなる。

    ★★ これは D-4 を半分しか閉じない (決定 D121-2) ★★
      閉じるのは **受け取り側** だけである。★生成側は出力先が既に在れば
      作り直さない (`build_images` の `if dest.exists()`) ので、
      設定を変えても **新しいバイト列がそもそも作られない**。
      → その場合ここが読むのは古いバイト列で、行のハッシュも変わらない。
      ★★手当ては別に要る。ここでは閉じていない。★★

    ★同じ `imageHash` を複数の刷りが共有しうるので重複を落とす
      (実データでは今日 0 件だが、原本がバイト単位で同じなら起きる / D-10)。
    """
    seen: set[str] = set()
    files: list[dict] = []
    for image_hash in image_hashes.values():
        if image_hash in seen:
            continue
        seen.add(image_hash)
        # ★リサイズ済みの 3 段。★Pillow が無い環境では原本がそのまま置かれる
        #   ので、そちらも拾う (置いてあるものが配られるものである)。
        candidates = [f"images/{name}/{image_hash}.webp" for name in cfg.image_sizes]
        candidates.append(f"images/original/{image_hash}.png")
        for rel_path in candidates:
            path = cfg.dist_dir / rel_path
            if not path.exists():
                continue
            body = path.read_bytes()
            files.append({
                "path": rel_path,
                "hash": f"sha256:{_sha256(body)}",
                "bytes": len(body),
            })
    files.sort(key=lambda f: f["path"])
    return files


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

    # ---- 画像だけのマニフェスト (決定 D121-1 = 画-5) ---------------------
    # ★★ dataVersion を載せない ★★
    #   載せると、カードを 1 文字直して版を上げるたびにこの物のバイト列が
    #   変わる。★画-5 の利得は「カードの変更と画像の変更が独立に運べる」
    #   ことなので、それを自分で潰すことになる。
    #   ★整合は version.json の imageManifestHash が持つ。
    #
    # ★★ --skip-images のときは書かない。列も出さない ★★
    #   ★空の物を書くと「画像が 0 枚である」という宣言になる。
    #   受け取り側に削除の計画を足したとき (順序の 7)、それは
    #   **全部消せ** と読める。★--skip-images は imageHash も空にする
    #   開発用の近道であって、配信物ではない (CLAUDE.md §7-3)。
    #   → ★「まだ無い」と「0 枚である」を書き分ける。
    version = {
        "dataVersion": data_version,
        "minAppVersion": min_app_version,
        "manifestPath": "/data/manifest.json",
        "manifestHash": f"sha256:{manifest_hash}",
    }
    image_files: list[dict] = []
    if with_images:
        image_files = build_image_manifest(cfg, image_hashes)
        image_manifest_hash = _write(
            cfg.dist_dir / "image_manifest.json", {"files": image_files})
        version["imageManifestPath"] = "/data/image_manifest.json"
        version["imageManifestHash"] = f"sha256:{image_manifest_hash}"
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
    if with_images:
        log.info("  画像マニフェスト %s 行 / %.1f MB",
                 len(image_files),
                 sum(f["bytes"] for f in image_files) / 1024 / 1024)
    else:
        log.warning("  ★ --skip-images: 画像マニフェストを書いていません。"
                    "配信物として使わないこと")

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
