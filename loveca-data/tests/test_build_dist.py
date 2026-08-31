"""配信物生成の引数の検査.

★★ この検査の存在理由 ★★
`min_app_version` は長いあいだ **生成関数のキーワード既定値** で、
CLI に露出していなかった。その結果これまでに作った dist はすべて
「アプリ 1.0.0 以上」を要求し、M1 では **アプリの版を上げて** 回避した。
データに合わせてアプリを変える、という本来と逆の向きである
(`ルール整合性チェック_v1.06.md` の所見 **D-7**)。

→ ★既定値そのものを消し、CLI へ露出した (決定 **D118-5** = 既-3)。

★★ 出る側だけを見ない ★★
「省略できないこと」だけを見ると、**引数の綴りを間違えた検査** でも通る
(存在しない名前は当然 required に見える)。★対で「渡せば通り、値が届くこと」
を必ず置く。

ネットワークアクセスは一切しない。ファイルも 1 つも書かない
—— `build` は引数の束縛で TypeError になるので **本体まで進まない**。
"""

from __future__ import annotations

import inspect
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from loveca_data.build_dist import build  # noqa: E402
from loveca_data.cli import build_parser  # noqa: E402


def _rejects(argv: list[str]) -> bool:
    """パーサが `argv` を拒むか.

    ★argparse は拒むときに usage を stderr へ書く。そのままだと
    テストの出力が読めなくなるので、ここでだけ捨てる。
    ★捨てるのは出力であって判定ではない (SystemExit を見ている)。
    """
    import contextlib
    import io as _io

    try:
        with contextlib.redirect_stderr(_io.StringIO()):
            build_parser().parse_args(argv)
    except SystemExit:
        return True
    return False


def _accepts(argv: list[str]):
    """パーサに `argv` を通し、結果を返す.

    ★argparse は拒むとき `SystemExit` を投げる。★`SystemExit` は
    `Exception` ではない (`BaseException`) ので、下の走らせ方では
    **捕まらずにこのファイルごと落ちる** —— 残りの検査が 1 つも走らない。
    → ★ここで AssertionError に畳む。
    """
    import contextlib
    import io as _io

    try:
        with contextlib.redirect_stderr(_io.StringIO()):
            return build_parser().parse_args(argv)
    except SystemExit as exc:
        raise AssertionError(
            f"通るはずの引数が拒まれた (引数名が違う可能性がある): {argv}"
        ) from exc


def test_build_requires_min_app_version():
    """`build` の `min_app_version` に既定値が無いこと (決定 D118-5)."""
    param = inspect.signature(build).parameters["min_app_version"]
    assert param.default is inspect.Parameter.empty, (
        "min_app_version に既定値が復活している。"
        "既定値を置くと D-7 の機構がそのまま戻る"
    )
    assert param.kind is inspect.Parameter.KEYWORD_ONLY
    print("  OK build の min_app_version に既定値が無い")


def test_signature_check_can_see_a_default():
    """★対: 既定値を持つ引数は「持つ」と読めること.

    これが無いと、上の検査が **何も見ていなくても** 通る
    (例: 属性名を間違えて常に empty を返すような書き方)。
    """
    param = inspect.signature(build).parameters["with_images"]
    assert param.default is True, "with_images は既定値 True を持つはず"
    print("  OK 既定値を持つ引数は「持つ」と読める")


def test_build_raises_without_min_app_version():
    """★呼び出し側が省略すると TypeError になること.

    ★本体まで進まないのでファイルは 1 つも書かれない。
    """
    try:
        build(None, None, data_version=1)  # type: ignore[arg-type]
    except TypeError as exc:
        assert "min_app_version" in str(exc), f"別の TypeError である: {exc}"
        print("  OK 省略すると TypeError になる")
        return
    except Exception as exc:  # noqa: BLE001
        # ★既定値が復活すると本体まで進み、別の例外が出る。
        #   ★そのまま投げるとこのファイルごと落ちて **他の検査も走らない**
        #     ので、AssertionError に畳んでから報告する。
        raise AssertionError(
            f"TypeError ではなく {type(exc).__name__} が出た "
            f"(既定値が復活している可能性がある): {exc}"
        ) from exc
    raise AssertionError("省略しても通ってしまった")


def test_cli_build_requires_min_app_version():
    """★CLI の `build` が `--min-app-version` を必須にしていること."""
    assert _rejects(["build", "--data-version", "1"]),         "--min-app-version 無しで通ってしまった"
    print("  OK CLI は --min-app-version 無しを拒む")


def test_cli_build_passes_the_value_through():
    """★対: 渡せば通り、値がそのまま届くこと.

    ★上の検査だけだと、引数名を間違えていても通る
    (存在しない名前は required に見えるため)。
    """
    args = _accepts(["build", "--data-version", "2", "--min-app-version", "0.3.0"])
    # ★`getattr` で受ける —— 引数名を綴り違いにしたときに
    #   AttributeError でこのファイルごと落ちないようにするため。
    assert getattr(args, "min_app_version", None) == "0.3.0",         "--min-app-version の値が届いていない (引数名が違う可能性がある)"
    assert args.data_version == 2
    print("  OK CLI は渡された値をそのまま持つ")


def test_cmd_build_hands_the_value_to_build():
    """★CLI が受け取った値が `build` まで届くこと.

    ★★ ここが D-7 の症状そのものである ★★
    D-7 は「CLI に露出せず、生成関数の既定値が黙って効く」ことだった。
    ★露出させただけでは足りない —— 受け取った値を **渡していなければ**
    症状は 1 ビットも変わらない。★上の 2 つはどちらも
    `cmd_build` を 1 行も通らない。

    ★ネットワークにも実データにも触れない (4 つとも差し替える)。
    """
    from unittest import mock

    from loveca_data import cli

    seen: dict = {}

    def fake_build(cfg, result, **kwargs):
        seen.update(kwargs)
        return {}

    class _Report:
        ok = True

        def summary(self):  # pragma: no cover - 通らない
            return ""

    args = _accepts(
        ["build", "--data-version", "2", "--min-app-version", "0.3.0",
         "--skip-images"]
    )
    with (
        mock.patch.object(cli, "build", fake_build),
        mock.patch.object(cli, "load_normalize_input", lambda cfg: {}),
        mock.patch.object(cli, "normalize_all", lambda d, b: None),
        mock.patch.object(cli, "validate", lambda *a, **k: _Report()),
        mock.patch.object(cli, "load_base_printing_ids", lambda cfg: set()),
    ):
        rc = cli.cmd_build(args, cfg=None)

    assert rc == 0, f"終了コードが 0 ではない: {rc}"
    assert seen.get("min_app_version") == "0.3.0", (
        f"渡された値が build に届いていない: {seen}"
    )
    assert seen.get("data_version") == 2
    print("  OK CLI の値が build まで届く")


def test_data_version_is_the_precedent():
    """★`data_version` が同じ形であること (決定 D118-5 の決め手).

    ★「必須引数なら破られない」の実績はこちらに在る。
    ★同じ形になっていることを機械で見ておく —— 片方だけ既定値に戻ると
    決め手そのものが崩れる。
    """
    param = inspect.signature(build).parameters["data_version"]
    assert param.default is inspect.Parameter.empty
    assert _rejects(["build", "--min-app-version", "0.3.0"]),         "--data-version 無しで通ってしまった"
    print("  OK data_version も必須のまま")


if __name__ == "__main__":
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    print(f"配信物生成テスト {len(tests)} 件を実行\n")
    failed = 0
    for test in tests:
        try:
            test()
        except AssertionError as exc:
            print(f"  NG {test.__name__}: {exc}")
            failed += 1
        except Exception as exc:  # noqa: BLE001
            # ★想定外の例外も 1 件の失敗として数える。
            #   ★投げっぱなしにすると **残りの検査が 1 つも走らない**。
            print(f"  NG {test.__name__}: 想定外の {type(exc).__name__}: {exc}")
            failed += 1
    print(f"\n{'全て成功' if not failed else f'{failed} 件失敗'}")
    sys.exit(1 if failed else 0)
