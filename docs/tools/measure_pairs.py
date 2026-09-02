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

★★ 仕込みの形は 3 つある（★2026-09-03 に 2 つ足した）★★

    {"file": "a/b.dart", "find": "...", "replace": "..."}   ★置換
    {"file": "loveca-probe/lib/probe.dart", "create": "..."} ★★新設（既に在れば断る）★★
    {"file": "a/b.dart", "delete": true}                     ★★削除（無ければ断る）★★

★★新設したものは★戻すときに★消す★★（★書き戻さない / D-40）。★作ったディレクトリも★★空のときだけ消す★★。
★★「パッケージを 1 つ足すと走査テストが落ちるか」の類は★この形で測る★★
  （★2026-09-03 まで★使い捨ての sh で測っており、★★ファイル名を間違えて `+0 -1` が 4 本並んだ★★ / §97）。

★★ どこまでを★この道具に載せるか（★線 / 2026-09-03 / 運転指示【0】(3) ★★）★★

★★**載せる** —— ★★仕込んで走らせ、★戻して突き合わせる形★★（＝ ★対を測るもの）。
★★**載せない** —— ★★仕込みを持たない形★★（＝ ★数えるだけ / ★同じものを N 回走らせるだけ）。

★**この回までに使った★使い捨ての測定 4 つに当てた**（★★それ以外は数えていない★★ / D-28）——

| ★測定 | ★形 | ★★載せるか★★ |
|---|---|---|
| ★台帳の写しの頻度（★履歴を歩いて数える / §96-2） | ★仕込み無し | ★★載せない★★ |
| ★U33 の発生率（★同じ試験を N 回 / D-34） | ★仕込み無し（★反復） | ★★載せない★★ |
| ★★パッケージを 1 つ足すと走査テストが落ちるか（§97）★★ | ★★仕込み（新設）★★ | ★★**載せた**★★（★下の (2)） |
| ★落ちたときの文言を採る（§96-3） | ★仕込み（置換） | ★★既に載っている★★（★`--keep-json` の json に文言が出る） |

★★**載せられないもの**★★ ——
★**仕込みが★★ファイルの編集で表せないもの★★**（★例: ★環境変数を変える / ★別の機械で走らせる / ★時計を進める）。
★★**今日そういう測定は 1 つも使っていない**★★（★上の 4 つに当てた）。★**出てきたら★★その日に線を引き直すこと★★。**

★★ 絶対にしないこと ★★
★**git checkout を打たない**（D-40 —— ★未追跡の新規ファイルが巻き添えになる）。
★戻すのは★★この道具が自分で読んだ元の中身だけ★★である。

★★ 同じリポジトリに対して★2 つ同時に走らせない（★柵で塞いである）★★
★**この道具は★★作業ツリーを書き換える★★**。★2 つ同時に走ると ——
  (1) ★片方の「戻す」が★★もう片方の仕込みを元の中身として書き戻す★★
      （★型は §64 の不具合と★同じ列である。★★あちらは 1 プロセスの中、★こちらはプロセスの外★★）／
  (2) ★★同じパッケージの `flutter test` を 2 つ同時に走らせると★ツールごと落ちる★★
      （★`build/native_assets/windows/sqlite3.dll` の写しで衝突する / ★2026-09-02 実測 / ★★再現する★★ / D-34）。
→ ★**リポジトリごとの★★排他の印★★を取ってから走る。★取れなければ★★測らずに止める★★**（★終了コード 3）。
★★**古い印を★自分で消さない**★★ —— ★**生きているかを判定する手段が無い**（D-28 —— ★推測で埋めない）。
  ★**消すのは人である。★印の場所と中身を出す。**
"""

from __future__ import annotations

import argparse
import datetime
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


class _Absent(object):
    """★★仕込む前に★そのファイルが存在しなかったことの印★★.

    ★**戻すときは★★書き戻すのではなく★消す★★**（★D-40 —— ★★未追跡のファイルを残さない★★）。
    """

    def __repr__(self):
        return "<absent>"


ABSENT = _Absent()


def apply_edits(root, edits):
    """仕込む。★★元の中身を★ファイルごとに 1 度だけ覚える★★（★(1) の受け）.

    ★★ 途中で失敗したら★★書いた分を戻してから投げる★★ ★★
    ★**1 つの仕込みが 2 つ以上の edit を持つとき、★2 つ目で当て先が見つからないと
      ★★1 つ目だけが適用されたまま残る★★**（★2026-09-02 に実際に起きた）。
    ★**型は §64 の不具合と同じ列である**（★戻し損ね）。

    ★★ 仕込みの形は 3 つある（2026-09-03 に 2 つ足した）★★
    ★**(1) 置換**: `{"file", "find", "replace"[, "count"]}`（★元から在った形）
    ★**(2) 新設**: `{"file", "create": "<中身>"}` —— ★★既に在れば断る★★
    ★**(3) 削除**: `{"file", "delete": true}` —— ★★無ければ断る★★

    ★★ なぜ (2)(3) を足したか ★★
    ★**「パッケージを 1 つ足すと★走査テストが落ちるか」を測るのに、★★道具を通せなかった★★**
      （★2026-09-03 / §97 —— ★★使い捨ての sh で測り、★ファイル名を間違えて `+0 -1` が 4 本並んだ★★）。
    ★★**道具を通していれば★D-39 の判別法が★その場で出ていた**★★（★型は **D-2**）。
    """
    original = {}
    created_dirs = []
    try:
        for edit in edits:
            path = os.path.join(root, edit["file"])

            if "create" in edit:
                if os.path.exists(path):
                    raise ValueError(
                        "★新設しようとしたが★既に在る: %s" % edit["file"]
                    )
                if path not in original:
                    original[path] = ABSENT
                parent = os.path.dirname(path)
                missing = []
                probe = parent
                while probe and not os.path.isdir(probe):
                    missing.append(probe)
                    probe = os.path.dirname(probe)
                if parent:
                    os.makedirs(parent, exist_ok=True)
                created_dirs.extend(missing)
                _write(path, edit["create"])
                continue

            if edit.get("delete"):
                if not os.path.isfile(path):
                    raise ValueError("★消そうとしたが★無い: %s" % edit["file"])
                if path not in original:
                    original[path] = _read(path)
                os.remove(path)
                continue

            if path not in original:
                original[path] = _read(path)
            find = edit["find"]
            replace = edit["replace"]
            if replace == "":
                raise ValueError(
                    "★空文字への置換は禁じている（★番兵を置くこと / §43 の事故）: %s"
                    % edit["file"]
                )
            current = _read(path)
            want = int(edit.get("count", 1))
            got = current.count(find)
            if got != want:
                raise ValueError(
                    "★当て先が %d 件（★期待 %d 件）: %s" % (got, want, edit["file"])
                )
            _write(path, current.replace(find, replace))
    except Exception:
        restore(original, created_dirs)
        raise
    return original, created_dirs


def restore(original, created_dirs=()):
    """戻して★突き合わせる。★★不一致を返す★★（★0 件であること）.

    ★★ 新設したものは★書き戻さず★消す（**D-40**）★★
    ★**残すと★★未追跡のファイルが 1 つ増える★★**。★★消えたことも突き合わせる★★。
    """
    bad = []
    for path, text in original.items():
        if text is ABSENT:
            if os.path.exists(path):
                try:
                    os.remove(path)
                except OSError:
                    pass
            if os.path.exists(path):
                bad.append("★消し損ねた: %s" % path)
            continue
        parent = os.path.dirname(path)
        if parent:
            os.makedirs(parent, exist_ok=True)
        _write(path, text)
        if _sha(_read(path)) != _sha(text):
            bad.append(path)
    # ★作ったディレクトリは★★空のときだけ★★消す（★元から在ったものに触らない）
    for path in sorted(created_dirs, key=len, reverse=True):
        try:
            os.rmdir(path)
        except OSError:
            pass
        if os.path.isdir(path):
            bad.append("★消し損ねた（ディレクトリ）: %s" % path)
    return bad


def lock_path(repo):
    """★リポジトリごとの★排他の印の場所.

    ★★ リポジトリの中に置かない ★★
    ★**置くと★★未追跡のファイルが 1 つ増える★★**（D-40 が警戒している状態そのものを作る）。
    ★**リポジトリの絶対パスから導くので、★別のチェックアウトとは★別の印になる。**
    """
    key = hashlib.sha256(os.path.abspath(repo).encode("utf-8")).hexdigest()[:16]
    return os.path.join(tempfile.gettempdir(), "measure_pairs_%s.lock" % key)


def acquire_lock(repo):
    """★取れたら印のパスを返す。★取れなければ [None, 既に在る印の中身] を返す.

    ★★ O_EXCL である ★★ —— ★「在るか見てから作る」と★★そのあいだに割り込める★★
    （★塞ぎたいものと★同じ形になる / ★先例は `loveca-server` の「確かめてから書くまでを 1 つの読み書きに収めた」）。
    """
    path = lock_path(repo)
    try:
        fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except OSError:
        try:
            return None, _read(path)
        except (OSError, ValueError):
            return None, "(★印は在るが読めない)"
    with os.fdopen(fd, "w") as f:
        # ★★ 逆斜線を 1 つも書かない（D-38 —— ★道具の経路で★改行の印が本物の改行に化ける）★★
        f.write(
            chr(10).join(
                [
                    "pid=%d" % os.getpid(),
                    "repo=%s" % os.path.abspath(repo),
                    "started=%s" % datetime.datetime.now().isoformat(),
                    "",
                ]
            )
        )
    return path, None


def release_lock(path):
    if not path:
        return
    try:
        os.remove(path)
    except OSError:
        pass


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

    # ★★ 柵 —— ★同じリポジトリに 2 つ同時に走らせない（★上の doc）★★
    lock, held = acquire_lock(repo)
    if lock is None:
        print("★★ 既に走っている。★測らずに止める ★★")
        print("★ 印: %s" % lock_path(repo))
        print("★ 中身:")
        for line in (held or "").splitlines():
            print("    %s" % line)
        print("★★ 走っていないと分かっているなら★この印を人が消すこと"
              "（★★道具は消さない —— ★生きているかを判定する手段が無い★★）★★")
        return 3
    try:
        return _measure(spec, root, command, args)
    finally:
        release_lock(lock)


def _measure(spec, root, command, args):
    print("★ baseline を測る: %s (%s)" % (command, spec["cwd"]))
    base = run_once(root, command, args.keep_json)
    print("  baseline: %r" % base)
    if base.failed or base.load_failed:
        print("★★ baseline が緑ではない。★測らずに止める ★★")
        return 2

    rows = []
    for mutation in spec["mutations"]:
        label = mutation["label"]
        original, created_dirs = apply_edits(root, mutation["edits"])
        try:
            counts = run_once(root, command, args.keep_json)
        finally:
            bad = restore(original, created_dirs)
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
