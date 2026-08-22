"""実行設定とディレクトリ構成.

実装仕様書 v1.0 §6 に対応。

段階 1-3 (取得) と段階 4-6 (正規化以降) を完全に分離するため、
生レスポンスは raw/ に保存し、正規化は raw/ のみを入力とする。
これにより正規化ロジックを何度直しても公式サイトを再度叩かない。
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class Config:
    # ---- ディレクトリ ----------------------------------------------------
    root: Path = field(default_factory=lambda: Path(os.environ.get("LOVECA_DATA_DIR", "./data")))

    # ---- 取得設定 (相手サーバへの配慮。緩めないこと) ----------------------
    request_interval_sec: float = 1.5   # 直列実行の最小間隔
    timeout_sec: float = 30.0
    max_retries: int = 3
    backoff_base_sec: float = 2.0
    consecutive_failure_limit: int = 5   # これだけ連続失敗したら停止
    per_page: int = 100                  # 実測で通る上限。これ以上増やさない

    # ---- User-Agent -----------------------------------------------------
    # ★公開時は必ず連絡先を実在するものに書き換えること。
    user_agent: str = (
        "LovecaSimBot/1.0 (personal card database builder; "
        "contact: REPLACE_WITH_YOUR_CONTACT)"
    )

    # ---- 画像 ------------------------------------------------------------
    image_sizes: dict = field(default_factory=lambda: {
        "thumb": (200, 80),    # (幅px, WebP品質)
        "normal": (500, 85),
        "large": (1000, 90),
    })

    @property
    def raw_dir(self) -> Path:
        return self.root / "raw"

    @property
    def raw_list_dir(self) -> Path:
        return self.raw_dir / "list"

    @property
    def raw_detail_dir(self) -> Path:
        return self.raw_dir / "detail"

    @property
    def raw_images_dir(self) -> Path:
        return self.raw_dir / "images"

    @property
    def normalized_dir(self) -> Path:
        return self.root / "normalized"

    @property
    def dist_dir(self) -> Path:
        return self.root / "dist"

    @property
    def search_form_path(self) -> Path:
        return self.raw_dir / "search_form.json"

    def ensure_dirs(self) -> None:
        for d in (
            self.raw_dir, self.raw_list_dir, self.raw_detail_dir,
            self.raw_images_dir, self.normalized_dir, self.dist_dir,
        ):
            d.mkdir(parents=True, exist_ok=True)


DEFAULT = Config()
