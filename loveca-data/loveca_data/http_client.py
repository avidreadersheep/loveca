"""レート制限つき HTTP クライアント.

実装仕様書 v1.0 §6「リクエスト規約」に対応。

- 直列実行のみ (並列度 1)
- 最小間隔を必ず空ける
- 指数バックオフでリトライ
- 連続失敗が続いたら停止する (相手に迷惑をかけ続けない)

依存を増やさないため標準ライブラリの urllib のみを使う。
"""

from __future__ import annotations

import gzip
import json
import logging
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

from .config import Config

log = logging.getLogger(__name__)


class FetchError(RuntimeError):
    pass


class AbortError(RuntimeError):
    """連続失敗により処理全体を中止する."""


class RateLimitedClient:
    def __init__(self, cfg: Config) -> None:
        self.cfg = cfg
        self._last_request_at = 0.0
        self._consecutive_failures = 0

    # -- 内部 --------------------------------------------------------------
    def _wait(self) -> None:
        elapsed = time.monotonic() - self._last_request_at
        remaining = self.cfg.request_interval_sec - elapsed
        if remaining > 0:
            time.sleep(remaining)

    def _open(self, url: str, accept: str) -> bytes:
        req = urllib.request.Request(
            url,
            headers={
                "User-Agent": self.cfg.user_agent,
                "Accept": accept,
                "Accept-Encoding": "gzip",
            },
        )
        with urllib.request.urlopen(req, timeout=self.cfg.timeout_sec) as res:
            body = res.read()
            if res.headers.get("Content-Encoding") == "gzip":
                body = gzip.decompress(body)
            return body

    def _request(self, url: str, accept: str) -> bytes:
        last_exc: Exception | None = None
        for attempt in range(self.cfg.max_retries):
            self._wait()
            self._last_request_at = time.monotonic()
            try:
                body = self._open(url, accept)
                self._consecutive_failures = 0
                return body
            except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as exc:
                last_exc = exc
                # 4xx はリトライしても無駄なので即座に諦める
                if isinstance(exc, urllib.error.HTTPError) and 400 <= exc.code < 500:
                    break
                wait = self.cfg.backoff_base_sec ** (attempt + 1)
                log.warning("取得失敗 (%s/%s) %s: %s / %.1fs 待機",
                            attempt + 1, self.cfg.max_retries, url, exc, wait)
                time.sleep(wait)

        self._consecutive_failures += 1
        if self._consecutive_failures >= self.cfg.consecutive_failure_limit:
            raise AbortError(
                f"連続 {self._consecutive_failures} 回失敗したため中止します。"
                f"時間をおいて再実行してください。最後のURL: {url}"
            )
        raise FetchError(f"{url}: {last_exc}")

    # -- 公開 --------------------------------------------------------------
    def get_json(self, path: str, params: dict[str, Any] | None = None) -> dict:
        url = path
        if params:
            url = f"{path}?{urllib.parse.urlencode(params)}"
        body = self._request(url, "application/json")
        return json.loads(body.decode("utf-8"))

    def get_bytes(self, url: str) -> bytes:
        return self._request(url, "*/*")
