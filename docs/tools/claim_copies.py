# -*- coding: utf-8 -*-
"""★★同じ主張が★何か所に写っているかを数える★★道具（★`docs/同期設計メモ.md` §95）.

★★ なぜリポジトリに置くか ★★
★**§93 は「★同じ偽が★★3 か所に在る★★」と手で数えた。**
★★**4 か所目が無い保証は★どこにも無かった**★★（★相談役の指摘 / 2026-09-02）。
→ ★**実際に★★4 か所目が在った★★**（`docs/同期設計メモ.md` の §N-28 の「今日は決めない」節 / §95-3）。
→ ★**手で数える限り★また抜ける**（★型は **D-2**）。

★★ 何を数えるか ★★
  1. ★**単位は★★行★★。★ただし表の行は★`|` で割って★★セルごとに数える★★**
     （★§N-28 は★★1 行の中に (戊) と (己) の 2 か所を持つ★★ / ★2026-09-02 実測）
  2. ★**`all` に挙げた字面が★★1 つ残らず★★その単位に在るとき★1 件と数える**

★★ 何を数えないか（★★言い切る★★）★★
  1. ★★**言い換えは拾えない**★★ —— ★**字面を 1 つも共有しない写しは★★原理的に見えない★★。**
     ★**`all` に何を入れるかは★★人が決める★★**（★道具は決めない）。
  2. ★★**主張と★注記を分けられない**★★ —— ★**注記は★主張と★★同じ字面を必ず含む★★**（**D-30**）。
     ★**分類は★★人がする★★。★道具は★★全件を並べるだけである★★**
     （★「注記は除外する」規則は書けない —— ★★名乗れば黙らせられる★★ / **D-30** の本文）。
  3. ★★**因果も、★どちらが先に書かれたかも出さない**★★（**D-28**）。

★★ 使い方 ★★

    python docs/tools/claim_copies.py <spec.json>
    python docs/tools/claim_copies.py <spec.json> --out out.md

★spec の形（★JSON）——

    {
      "claim": "★1 行の説明（★道具は読まない。★出力に写すだけ）",
      "all":   ["import が動く"],
      "roots": ["docs", "."],
      "suffixes": [".md"],
      "expect_at_least": 1
    }

★`roots` / `suffixes` / `expect_at_least` は省略できる（★既定は上のとおり）。
★`expect_at_least` は★★陽性対照★★である —— ★下回ったら★★終了コード 2 で止まる★★
（★**D-10** —— ★0 件は「無い」と「見えていない」の区別がつかない）。

★★ 表の正は `--out` のファイルである ★★
★**端末の出力を★報告に写さない**（★先例は `measure_pairs.py` の doc）。
"""

from __future__ import annotations

import io
import json
import os
import sys

_SKIP_DIRS = (".git", ".venv", ".dart_tool", "build", "node_modules", "__pycache__")


def _walk(roots, suffixes):
    """★走査する対象のファイルを★重複なく返す（★根が入れ子でも 1 回だけ）."""
    seen = []
    known = set()
    for root in roots:
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in _SKIP_DIRS]
            for name in sorted(filenames):
                if not name.endswith(tuple(suffixes)):
                    continue
                path = os.path.normpath(os.path.join(dirpath, name))
                key = os.path.abspath(path)
                if key in known:
                    continue
                known.add(key)
                seen.append(path)
    return sorted(seen)


def units(line):
    """★1 行を★★数える単位★★に割る.

    ★**表の行（★行頭が `|`）は★セルごとに割る**（★★1 行に 2 か所在ることが実在する★★）。
    ★**それ以外は★行そのものが 1 単位である。**

    ★返すのは `(セル番号, 字面)` の列。★セル番号は表でないとき 0。
    """
    if line.lstrip().startswith("|"):
        out = []
        for index, cell in enumerate(line.split("|")):
            text = cell.strip()
            if text:
                out.append((index, text))
        return out
    return [(0, line.strip())]


def hits_in(text, needles):
    """★`needles` を★★1 つ残らず★★含む単位を★`(行番号, セル番号, 字面)` で返す."""
    found = []
    for number, line in enumerate(text.splitlines(), start=1):
        for cell, unit in units(line):
            if all(needle in unit for needle in needles):
                found.append((number, cell, unit))
    return found


def scan(spec, base="."):
    """★spec を当てて★`(件数の表, 全件の列)` を返す."""
    needles = list(spec["all"])
    if not needles:
        raise ValueError("all is empty")
    roots = spec.get("roots") or ["docs", "."]
    suffixes = spec.get("suffixes") or [".md"]

    per_file = {}
    rows = []
    for path in _walk([os.path.join(base, r) for r in roots], suffixes):
        try:
            text = io.open(path, encoding="utf-8").read()
        except (IOError, OSError, UnicodeDecodeError):
            continue
        found = hits_in(text, needles)
        if not found:
            continue
        shown = os.path.relpath(path, base).replace(os.sep, "/")
        per_file[shown] = len(found)
        for number, cell, unit in found:
            rows.append((shown, number, cell, unit))
    return per_file, rows


def _clip(text, width=160):
    return text if len(text) <= width else text[: width - 1] + "…"


def render(spec, per_file, rows):
    total = sum(per_file.values())
    out = []
    out.append("# ★ 同じ主張の写し —— " + str(spec.get("claim", "")))
    out.append("")
    out.append("★**探した字面**: " + " ＋ ".join("`" + n + "`" for n in spec["all"]))
    out.append("")
    out.append("★★**分類（★主張 / ★注記）は★人がする。★道具は分けられない**★★（**D-30**）。")
    out.append("")
    out.append("## ★ ファイルごとの件数")
    out.append("")
    out.append("| ファイル | ★件数 |")
    out.append("|---|---|")
    for path in sorted(per_file):
        out.append("| `" + path + "` | " + str(per_file[path]) + " |")
    out.append("| ★★**合計**★★ | ★★**" + str(total) + "**★★ |")
    out.append("")
    out.append("## ★ 全件（★★人が分類する★★）")
    out.append("")
    out.append("| # | 場所 | ★セル | ★字面 | ★主張 / 注記 |")
    out.append("|---|---|---|---|---|")
    for index, (path, number, cell, unit) in enumerate(rows, start=1):
        out.append(
            "| "
            + str(index)
            + " | `"
            + path
            + ":"
            + str(number)
            + "` | "
            + str(cell)
            + " | "
            + _clip(unit).replace("|", "｜")
            + " | ★（未分類） |"
        )
    out.append("")
    return chr(10).join(out)


def _utf8(stream):
    """★端末の符号化が cp932 だと★出せない字がある（★2026-09-02 実測 / ★この機械）."""
    try:
        stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass


def main(argv):
    _utf8(sys.stdout)
    _utf8(sys.stderr)
    if len(argv) < 2:
        sys.stderr.write("usage: claim_copies.py <spec.json> [--out out.md]" + chr(10))
        return 1
    spec = json.loads(io.open(argv[1], encoding="utf-8").read())
    out_path = None
    if "--out" in argv:
        out_path = argv[argv.index("--out") + 1]

    per_file, rows = scan(spec)
    total = sum(per_file.values())

    floor = spec.get("expect_at_least", 1)
    text = render(spec, per_file, rows)
    if out_path:
        io.open(out_path, "w", encoding="utf-8").write(text)
        sys.stdout.write("wrote " + out_path + chr(10))
    else:
        sys.stdout.write(text)

    sys.stdout.write("total " + str(total) + chr(10))
    if total < floor:
        sys.stderr.write(
            "★★陽性対照が落ちた★★: total " + str(total) + " < " + str(floor) + chr(10)
        )
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
