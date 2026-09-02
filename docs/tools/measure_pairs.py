# -*- coding: utf-8 -*-
"""対（ペア）を測る道具 —— ★仕込んで走らせ、★戻して突き合わせる.

★★ なぜリポジトリに置くか ★★
これまで毎回★使い捨てのスクリプトで測っていた。★同じ不具合を 3 度踏んでいる ——
  (1) 同じファイルに 2 つ以上仕込むと、★戻すときに途中の状態を書き戻す（2026-09-02 / §64）
  (2) 空文字への置換が★戻すときに全文へ挿し込まれる（2026-09-01 / §43）
  (3) 「読み込みの失敗」を★字面（Error: ）で数え、★assertion の文言を拾う（2026-09-02 / §86-7）
★★手当てを毎回書き直すから毎回抜ける★★。★型は D-2（手動の見張りは忘れられる）。
→ ★道具の側に入れる。★先例は loveca-server/tool/measure_hash_cost.dart と
  loveca-db/tool/probe_sqlite.dart（★どちらも「測り直す手順」を道具にしたもの）。

★★ D-39 の判別法を★人の目ではなく★この道具が持つ ★★
★**対が落ちたように見えても、★★仕込みがそもそも走っていない★★ことがある**（D-39）。
★**判別法は「★★走った件数を見る★★」である** —— ★合計が baseline と同じなら読み込みは成功している。
★★**字面（Error: ）では数えない**★★ —— ★assertion の文言に OS Error: が入るだけで誤検知する
  （2026-09-02 に実際に起きた / §86-7）。
→ ★**--file-reporter json: の testDone を数える。★★隠しスイート（読み込み）の失敗も別に数える★★。**

★★ 使い方 ★★

    python docs/tools/measure_pairs.py <spec.json> [--out out.md] [--keep-json]

spec.json の形（★UTF-8）——

    {
      "cwd": "loveca-core",
      "command": "dart test",
      "mutations": [
        {"label": "(A) 段 3 を外す",
         "edits": [{"file": "lib/src/sync/deck_resolution.dart",
                    "find": "...", "replace": "..."}]}
      ]
    }

★find は★★ちょうど 1 回★★現れること（count で明示できる）。
★replace に★★空文字を書けない★★（★(2) の受け。★番兵を置くこと）。

★★ 絶対にしないこと ★★
★**git checkout を打たない**（D-40 —— ★未追跡の新規ファイルが巻き添えになる）。
★戻すのは★★この道具が自分で読んだ元の中身だけ★★である。
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import subprocess
import sys
import tempfile


def _read(path):
    with io.open(path, encoding="utf-8", newline="") as f:
        return f.read()


def _write(path, text):
    with io.open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)


def _sha(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


class Counts(object):
    """1 回の走りの結果。★★件数だけを持つ（★字面を持たない）★★."""

    def __init__(self, passed, failed, load_failed, exit_code):
        self.passed = passed
        self.failed = failed
        self.load_failed = load_failed
        self.exit_code = exit_code

    @property
    def ran(self):
        return self.passed + self.failed

    def __repr__(self):
        return "Counts(passed=%d, failed=%d, load_failed=%d)" % (
            self.passed,
            self.failed,
            self.load_failed,
        )


def _parse_report(path):
    """--file-reporter json: の出力を数える.

    ★★ 隠しスイート（hidden: true）は「読み込み」である ★★
    ★**読み込みが失敗すると、★その中の test は★★1 件も testDone を出さない★★。**
    → ★**それを★別の欄として数える**（★合計と併せて読む / D-39 の判別法）。
    """
    passed = 0
    failed = 0
    load_failed = 0
    hidden_ids = set()
    with io.open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line.startswith("{"):
                continue
            try:
                event = json.loads(line)
            except ValueError:
                continue
            kind = event.get("type")
            if kind == "testStart":
                test = event.get("test") or {}
                name = test.get("name") or ""
                # ★読み込みスイートは url を持たず、★名前が "loading " で始まる。
                if test.get("url") is None and name.startswith("loading "):
                    hidden_ids.add(test.get("id"))
            elif kind == "testDone":
                if event.get("testID") in hidden_ids:
                    if event.get("result") != "success":
                        load_failed += 1
                    continue
                if event.get("hidden"):
                    continue
                if event.get("result") == "success":
                    passed += 1
                else:
                    failed += 1
    return Counts(passed, failed, load_failed, 0)


def run_once(cwd, command, keep_json):
    fd, report = tempfile.mkstemp(suffix=".json", prefix="measure_pairs_")
    os.close(fd)
    try:
        full = "%s --file-reporter json:%s" % (command, report)
        proc = subprocess.run(
            full,
            cwd=cwd,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        counts = _parse_report(report)
        counts.exit_code = proc.returncode
        return counts
    finally:
        if not keep_json:
            try:
                os.remove(report)
            except OSError:
                pass


def apply_edits(root, edits):
    """仕込む。★★元の中身を★ファイルごとに 1 度だけ覚える★★（★(1) の受け）."""
    original = {}
    for edit in edits:
        path = os.path.join(root, edit["file"])
        if path not in original:
            original[path] = _read(path)
        find = edit["find"]
        replace = edit["replace"]
        if replace == "":
            raise ValueError(
                "★空文字への置換は禁じている（★番兵を置くこと / §43 の事故）: %s" % edit["file"]
            )
        current = _read(path)
        want = int(edit.get("count", 1))
        got = current.count(find)
        if got != want:
            raise ValueError("★当て先が %d 件（★期待 %d 件）: %s" % (got, want, edit["file"]))
        _write(path, current.replace(find, replace))
    return original


def restore(original):
    """戻して★突き合わせる。★★不一致を返す★★（★0 件であること）."""
    bad = []
    for path, text in original.items():
        _write(path, text)
        if _sha(_read(path)) != _sha(text):
            bad.append(path)
    return bad


def main():
    # ★★ 端末の符号化で落ちないようにする（★★測定の途中で例外を出さない★★）★★
    #   ★Windows の既定は cp932 で、★—— や ★ を出すだけで UnicodeEncodeError になる。
    #   ★**表の正は --out のファイル（★UTF-8）である。★端末は控えである。**
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

    parser = argparse.ArgumentParser(description="対を測る")
    parser.add_argument("spec")
    parser.add_argument("--out", default=None)
    parser.add_argument("--keep-json", action="store_true")
    args = parser.parse_args()

    spec = json.loads(_read(args.spec))
    here = os.path.abspath(__file__)
    repo = os.path.dirname(os.path.dirname(os.path.dirname(here)))
    root = os.path.join(repo, spec["cwd"])
    command = spec["command"]

    print("★ baseline を測る: %s (%s)" % (command, spec["cwd"]))
    base = run_once(root, command, args.keep_json)
    print("  baseline: %r" % base)
    if base.failed or base.load_failed:
        print("★★ baseline が緑ではない。★測らずに止める ★★")
        return 2

    rows = []
    for mutation in spec["mutations"]:
        label = mutation["label"]
        original = apply_edits(root, mutation["edits"])
        try:
            counts = run_once(root, command, args.keep_json)
        finally:
            bad = restore(original)
        # ★★ D-39 の判別法 —— ★★件数で見る。★字面では見ない ★★
        #   ★走った合計が baseline と同じなら★読み込みは成功している。
        note = ""
        if counts.load_failed:
            note = "★★読み込みの失敗 %d 件 —— ★対ではない★★" % counts.load_failed
        elif counts.ran != base.ran:
            note = "★★走った件数が %d → %d ＝ ★★読み込みの失敗である★★" % (base.ran, counts.ran)
        elif counts.failed == 0:
            note = "★★0 件 —— ★3 通りに当てること（★対の形 / ★本命の空振り / ★仕込みの弱さ）★★"
        if bad:
            note += " ／ ★★戻しに失敗: %s★★" % ", ".join(bad)
        rows.append((label, counts, note))
        print(
            "  %-44s 落ちた %3d / 走った %4d %s"
            % (label, counts.failed, counts.ran, note)
        )

    lines = []
    lines.append("| 仕込み | ★落ちた件数 | ★走った件数 | ★備考 |")
    lines.append("|---|---|---|---|")
    for label, counts, note in rows:
        lines.append(
            "| %s | %d | %d | %s |" % (label, counts.failed, counts.ran, note or "——")
        )
    lines.append("")
    lines.append(
        "★baseline: 通った %d 件 ／ ★読み込みの失敗 %d 件"
        "（★★字面ではなく件数で見た★★ / D-39）。" % (base.passed, base.load_failed)
    )
    table = "\n".join(lines)
    if args.out:
        _write(args.out, table + "\n")
        print("★ 表を書いた: %s" % args.out)
    else:
        print()
        print(table)
    return 0


if __name__ == "__main__":
    sys.exit(main())
