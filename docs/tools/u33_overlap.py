# -*- coding: utf-8 -*-
"""**U33**（`ルール整合性チェック_v1.06.md` **D-34**）の生出力から、★★同時に走っていた suite を数える★★.

★★ なぜリポジトリに置くか ★★
★**D-34 は「★4 例目が出たときに★★同時に走っていた検査ファイルの一覧も残すこと★★」と定めている。**
★**4 例目（2026-09-02）で★実際に組み立てたが、★★使い捨てのスクリプトだった★★。**
→ ★**5 例目でまた書き直すことになり、★★毎回抜ける★★**（★型は **D-2** / ★先例は `measure_pairs.py` の doc）。

★★ 何を数えるか ★★
  1. ★**suite ごとの窓**（★その suite の `testStart` / `testDone` の time の最小・最大）
  2. ★★**一時 DB を作る suite**★★ —— ★`systemTemp` を含み、
     ★かつ `NativeDatabase` / `openAppDatabase` を含むファイル（★★ソースを読んで判定する★★）
  3. ★**その同時実行のピーク**と、★**落ちた検査の時点での在籍数**

★★ 判定を字面で写さない ★★
★**「どれが一時 DB を作るか」を★★この道具に書き並べない★★** ——
  ★書くと★★テストが増えたときに黙って古くなる★★（★型は **D-20** / **D-31**）。
  → ★**走らせるたびに★ソースを読んで判定する。**

★★ 使い方 ★★

    python docs/tools/u33_overlap.py <報告の json> <パッケージの根>

★`<報告の json>` は `--file-reporter json:` の出力（**D-34** の作法）。
★`<パッケージの根>` は suite の path を解決する根（例: `loveca-ui`）。

★★ 因果は測っていない ★★
★**この道具が出すのは★★「その時間帯に何が同時に在籍していたか」までである★★**（**D-28**）。
"""

from __future__ import annotations

import io
import json
import os
import sys


def _load(report):
    """★報告の json を読み、★(suites, 窓, 落ちた検査) を返す."""
    suites = {}
    win = {}
    tests = {}
    failed = []
    for line in io.open(report, encoding="utf-8"):
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            event = json.loads(line)
        except ValueError:
            continue
        kind = event.get("type")
        if kind == "suite":
            suite = event["suite"]
            suites[suite["id"]] = suite.get("path")
        elif kind == "testStart":
            test = event.get("test") or {}
            sid = test.get("suiteID")
            tests[test.get("id")] = sid
            _touch(win, sid, event.get("time"))
        elif kind == "testDone":
            sid = tests.get(event.get("testID"))
            _touch(win, sid, event.get("time"))
            if not event.get("hidden") and event.get("result") != "success":
                failed.append((event.get("testID"), sid, event.get("time")))
    return suites, win, failed


def _touch(win, sid, time_ms):
    if sid is None or time_ms is None:
        return
    span = win.setdefault(sid, [time_ms, time_ms])
    span[0] = min(span[0], time_ms)
    span[1] = max(span[1], time_ms)


def _classify(suites, root):
    """★★ソースを読んで★一時 DB を作る suite を選ぶ（★字面を書き並べない）★★."""
    tempdb = set()
    temponly = set()
    for sid, path in suites.items():
        if not path:
            continue
        full = os.path.join(root, path)
        if not os.path.exists(full):
            continue
        src = io.open(full, encoding="utf-8", errors="replace").read()
        if "systemTemp" not in src:
            continue
        if ("NativeDatabase" in src) or ("openAppDatabase" in src):
            tempdb.add(sid)
        else:
            temponly.add(sid)
    return tempdb, temponly


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    report, root = sys.argv[1], sys.argv[2]
    suites, win, failed = _load(report)
    tempdb, temponly = _classify(suites, root)

    def name(sid):
        path = suites.get(sid)
        return os.path.basename(path) if path else "?"

    print("★ suite 総数=%d ／ ★一時 DB を作る=%d ／ ★一時ディレクトリだけ=%d"
          % (len(suites), len(tempdb), len(temponly)))
    print("★ 一時 DB を作る suite: %s"
          % ", ".join(sorted(name(s) for s in tempdb)))
    print()

    # ★★ 掃引してピークを出す ★★
    events = []
    for sid in tempdb:
        if sid in win:
            events.append((win[sid][0], 1, sid))
            events.append((win[sid][1], -1, sid))
    events.sort()
    live, cur, peak, peak_at, peak_set = set(), 0, 0, None, set()
    for time_ms, delta, sid in events:
        if delta == 1:
            live.add(sid)
        cur += delta
        if delta == 1 and cur > peak:
            peak, peak_at, peak_set = cur, time_ms, set(live)
        if delta == -1:
            live.discard(sid)
    print("★★ 一時 DB を作る suite の★同時実行のピーク: %d 件（t=%s ms）★★"
          % (peak, peak_at))
    print("   %s" % ", ".join(sorted(name(s) for s in peak_set)))
    print()

    for _, sid, time_ms in failed:
        here = [s for s in tempdb
                if s in win and win[s][0] <= time_ms <= win[s][1]]
        print("★ 落ちた: %-30s t=%s ms ／ ★その時点で一時 DB の suite が %d 件在籍"
              % (name(sid), time_ms, len(here)))
        print("   %s" % ", ".join(sorted(name(s) for s in here)))
    print()

    print("| suite | ★窓(ms) |")
    print("|---|---|")
    for sid in sorted(tempdb, key=lambda s: win.get(s, [0])[0]):
        if sid in win:
            print("| %s | %d .. %d |" % (name(sid), win[sid][0], win[sid][1]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
