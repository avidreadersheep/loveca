"""CLI.

推奨する実行順序 (実装仕様書 v1.0 §11):

    # 1. まず BP01 だけで一巡させ、V2/V3/V7 が通ることを確認する
    python -m loveca_data fetch --expansion BP01
    python -m loveca_data normalize
    python -m loveca_data validate

    # 2. 検証が通ってから全商品に拡大する
    python -m loveca_data fetch --all
    python -m loveca_data normalize && python -m loveca_data validate
    python -m loveca_data build --data-version 1 --min-app-version 0.3.0

3,000 件取ってから色マッピングの誤りに気づくのは、
時間と相手サーバへの負荷の両方の無駄になる。必ず 1 で止めて確認すること。
"""

from __future__ import annotations

import argparse
import json
import logging
import sys
from dataclasses import asdict
from pathlib import Path

from .build_dist import build
from .config import Config
from .constants import KIND_ENERGY
from .fetch import (
    describe_search_form, extract_expansions, extract_rarities, fetch_all_details,
    fetch_base_printing_ids, fetch_images, fetch_list, fetch_search_form,
    load_all_list_items, load_base_printing_ids, load_normalize_input,
)
from .http_client import RateLimitedClient
from .normalize import normalize_all
from .stats import summarize
from .validate import load_previous_card_numbers, validate

log = logging.getLogger("loveca_data")


def _setup_logging(verbose: bool) -> None:
    logging.basicConfig(
        level=logging.DEBUG if verbose else logging.INFO,
        format="%(asctime)s %(levelname)-5s %(message)s",
        datefmt="%H:%M:%S",
    )


def cmd_fetch(args, cfg: Config) -> int:
    cfg.ensure_dirs()
    client = RateLimitedClient(cfg)

    if cfg.user_agent.find("REPLACE_WITH_YOUR_CONTACT") >= 0:
        log.warning("User-Agent に連絡先が設定されていません。config.py を編集してください。")

    search_form = fetch_search_form(cfg, client, force=args.force)

    if args.expansions:
        expansions = [e.strip() for e in args.expansions.split(",") if e.strip()]
    elif args.expansion:
        expansions = [args.expansion]
    else:
        expansions = extract_expansions(search_form)
        if not expansions:
            log.error("商品コードを自動抽出できませんでした。")
            log.error("次のコマンドで構造を確認してください:")
            log.error("    python -m loveca_data expansions")
            log.error("判明したら次のように明示指定できます:")
            log.error("    python -m loveca_data fetch --expansions BP01,BP02,SD01")
            return 1
        log.info("商品コードを自動抽出しました: %s 件", len(expansions))

    log.info("対象商品: %s", ", ".join(expansions))

    all_ids: list[int] = []
    totals: dict[str, int] = {}
    energy_count = 0
    for expansion in expansions:
        items = fetch_list(cfg, client, expansion, force=args.force)
        totals[expansion] = len(items)
        for item in items:
            if item.get("id") is None:
                continue
            # エネルギーカードは性能差が無いため detail を取得しない。
            # デッキ構築と盤面表示に必要な情報は list だけで揃う。
            if (item.get("card_kind") or "").strip() == KIND_ENERGY:
                energy_count += 1
                continue
            all_ids.append(int(item["id"]))
        log.info("段階1: %s -> %s 件", expansion, len(items))

    if energy_count:
        log.info("段階1: エネルギーカード %s 件は detail 取得をスキップします", energy_count)

    (cfg.raw_dir / "totals.json").write_text(
        json.dumps(totals, ensure_ascii=False, indent=2), encoding="utf-8")

    # パラレル表示 ON/OFF に必要な「基本刷り」の集合を取得する。
    # card.parallel_param は基本刷りフラグではないため、公式検索フィルタを正典とする。
    base_ids = fetch_base_printing_ids(cfg, client, expansions, force=args.force)
    log.info("段階1: 基本刷り 合計 %s 件", len(base_ids))

    log.info("段階2: 詳細 %s 件を取得します (既取得はスキップ)", len(all_ids))
    ok, failed = fetch_all_details(cfg, client, all_ids, force=args.force)
    log.info("段階2: 成功 %s / 失敗 %s", ok, len(failed))
    if failed:
        log.error("失敗した id: %s", failed[:50])

    if not args.no_images:
        # 画像はエネルギーカードにも必要 (デッキ構築の絵柄選択・盤面表示)
        pictures = [i["picture"] for i in load_all_list_items(cfg) if i.get("picture")]
        log.info("段階3: 画像 %s 枚 (重複除去後)", len(set(pictures)))
        ok_img, failed_img = fetch_images(cfg, client, pictures, force=args.force)
        log.info("段階3: 成功 %s / 失敗 %s", ok_img, len(failed_img))
        if failed_img:
            log.error("失敗した画像: %s", failed_img[:50])

    return 0


def cmd_normalize(args, cfg: Config) -> int:
    cfg.ensure_dirs()
    details = load_normalize_input(cfg)
    if not details:
        log.error("raw/ が空です。先に fetch を実行してください。")
        return 1

    result = normalize_all(details, load_base_printing_ids(cfg))
    log.info("正規化: カード %s 種 / 刷り %s 件 / Q&A %s 件 / 商品 %s 件",
             len(result.cards), len(result.printings), len(result.faqs), len(result.products))

    out = {
        "cards": [asdict(c) for c in result.cards.values()],
        "printings": [asdict(p) for p in result.printings.values()],
        "faqs": [asdict(f) for f in result.faqs.values()],
        "products": [asdict(p) for p in result.products.values()],
    }
    path = cfg.normalized_dir / "normalized.json"
    path.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
    log.info("出力: %s", path)
    return 0


def cmd_validate(args, cfg: Config) -> int:
    details = load_normalize_input(cfg)
    if not details:
        log.error("raw/ が空です。先に fetch を実行してください。")
        return 1

    result = normalize_all(details, load_base_printing_ids(cfg))

    totals_path = cfg.raw_dir / "totals.json"
    expected = json.loads(totals_path.read_text(encoding="utf-8")) if totals_path.exists() else None

    previous = load_previous_card_numbers(cfg.normalized_dir / "previous.json")

    report = validate(
        result,
        raw_images_dir=cfg.raw_images_dir if not args.skip_images else None,
        expected_totals=expected,
        previous_card_numbers=previous or None,
        complete_dataset=args.complete,
    )
    print(report.summary())
    return 0 if report.ok else 2


def cmd_build(args, cfg: Config) -> int:
    details = load_normalize_input(cfg)
    result = normalize_all(details, load_base_printing_ids(cfg))

    report = validate(result, raw_images_dir=cfg.raw_images_dir if not args.skip_images else None)
    if not report.ok and not args.force:
        print(report.summary())
        log.error("検証エラーのため中止しました。--force で強制実行できます。")
        return 2

    build(
        cfg,
        result,
        data_version=args.data_version,
        # ★既定値を置かない (決定 D118-5 = 既-3 / 所見 D-7)。
        #   ★ここで `getattr(..., "1.0.0")` のような受けを書かないこと ——
        #     既定値を消した意味が無くなる。
        min_app_version=args.min_app_version,
        with_images=not args.skip_images,
    )
    return 0


def cmd_stats(args, cfg: Config) -> int:
    """正規化結果の統計を表示する (ネットワーク不要)."""
    details = load_normalize_input(cfg)
    if not details:
        log.error("raw/ が空です。先に fetch を実行してください。")
        return 1
    result = normalize_all(details, load_base_printing_ids(cfg))
    print(summarize(result))
    return 0


def cmd_expansions(args, cfg: Config) -> int:
    """search_form.json の構造を表示し、商品コードの抽出結果を確認する."""
    if not cfg.search_form_path.exists():
        if args.offline:
            log.error("%s がありません。--offline を外すと自動取得します。",
                      cfg.search_form_path)
            return 1
        # 検索フォーム定義は 1 リクエストのみ。取得して先に進めるようにする。
        log.info("%s が無いため取得します (1 リクエスト)", cfg.search_form_path)
        cfg.ensure_dirs()
        fetch_search_form(cfg, RateLimitedClient(cfg))

    search_form = json.loads(cfg.search_form_path.read_text(encoding="utf-8"))

    print(describe_search_form(search_form))
    print()
    rarities = extract_rarities(search_form)
    if rarities:
        print(f"--- レアリティ一覧 ({len(rarities)} 件) ---")
        print("  " + ", ".join(rarities))
        print("  ※ card_number の接尾はこの一覧に無い値も取りうる (例: PRproteinbar)")
        print()
    found = extract_expansions(search_form)
    if found:
        print(f"--- 自動抽出できた商品コード ({len(found)} 件) ---")
        print("  " + ", ".join(found))
        print()
        print("この一覧で取得する場合:")
        print(f"  python -m loveca_data fetch --expansions {','.join(found)}")
    else:
        print("--- 自動抽出できませんでした ---")
        print("上の出力から商品コードを読み取り、次のように指定してください:")
        print("  python -m loveca_data fetch --expansions BP01,BP02,SD01")
    return 0


def build_parser() -> argparse.ArgumentParser:
    """引数パーサを組み立てる.

    ★`main` から切り出してあるのは**テストから引けるようにする**ためである。
      `main` の中に閉じていると、必須引数を確かめるだけで
      `args.func` まで走って実データに触れてしまう。
    """
    parser = argparse.ArgumentParser(prog="loveca_data")
    parser.add_argument("--data-dir", type=Path, default=None)
    parser.add_argument("-v", "--verbose", action="store_true")
    sub = parser.add_subparsers(dest="command", required=True)

    p_fetch = sub.add_parser("fetch", help="段階0-3: 公式サイトから取得")
    p_fetch.add_argument("--expansion", help="商品コード1件 (例: BP01)")
    p_fetch.add_argument("--expansions", help="商品コードをカンマ区切りで複数 (例: BP01,BP02)")
    p_fetch.add_argument("--all", action="store_true", help="全商品 (自動抽出)")
    p_fetch.add_argument("--force", action="store_true", help="キャッシュを無視して再取得")
    p_fetch.add_argument("--no-images", action="store_true")
    p_fetch.set_defaults(func=cmd_fetch)

    p_norm = sub.add_parser("normalize", help="段階4: 正規化 (ネットワーク不要)")
    p_norm.set_defaults(func=cmd_normalize)

    p_val = sub.add_parser("validate", help="段階5: 検証 (ネットワーク不要)")
    p_val.add_argument("--skip-images", action="store_true")
    p_val.add_argument("--complete", action="store_true",
                       help="全商品を取得済みの場合に指定。relationCards の欠損も報告する")
    p_val.set_defaults(func=cmd_validate)

    p_build = sub.add_parser("build", help="段階6: 配信物生成")
    p_build.add_argument("--data-version", type=int, required=True)
    # ★★ 既定値を置かず必須にする (決定 D118-5 = 既-3 / 所見 D-7) ★★
    #   ★書式を書いておく —— compareVersions は数にできない部分を 0 として
    #     扱うので、綴りを間違えると例外も出さずに「最小版なし」に化ける。
    p_build.add_argument(
        "--min-app-version",
        required=True,
        metavar="X.Y.Z",
        help="このデータを読める最小のアプリ版 (例: 0.3.0)。"
             "★既定値は無い。アプリが実際に読める最小版を毎回考えて渡す",
    )
    p_build.add_argument("--skip-images", action="store_true")
    p_build.add_argument("--force", action="store_true")
    p_build.set_defaults(func=cmd_build)

    p_stats = sub.add_parser("stats", help="診断: データの統計を表示 (ネットワーク不要)")
    p_stats.set_defaults(func=cmd_stats)

    p_exp = sub.add_parser("expansions", help="診断: search_form.json の構造と商品コードを表示")
    p_exp.add_argument("--offline", action="store_true",
                       help="取得済みファイルのみを使う (自動取得しない)")
    p_exp.set_defaults(func=cmd_expansions)

    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    _setup_logging(args.verbose)

    cfg = Config(root=args.data_dir) if args.data_dir else Config()
    return args.func(args, cfg)


if __name__ == "__main__":
    sys.exit(main())
