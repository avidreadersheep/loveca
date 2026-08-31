"""画像だけのマニフェストの検査 (決定 **D121-1** = 画-5 / **N-2** の画像側).

★★ この検査が見ているもの ★★
`imageHash` は **原本 PNG** のハッシュであって、配る WebP の中身を
名指していない (所見 **D-4**)。★画像をマニフェストに載せ、
**行のハッシュを配るバイト列から作る** ことで、受け取り側では
名前が中身を指す必要が無くなる (決定 **D121-2** の柵)。

★★ 半分しか閉じない。★閉じない側も対で固定する ★★
生成側は出力先が既に在れば作り直さないので、段の設定を変えても
**新しいバイト列がそもそも作られない**。→ その場合ハッシュは変わらない。
★「変わらないこと」も検査に置く —— **閉じたと誤読させないため**である。

ネットワークアクセスは一切しない。実データにも触れない (一時ディレクトリのみ)。
"""

from __future__ import annotations

import hashlib
import json
import shutil
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from loveca_data.build_dist import build_image_manifest  # noqa: E402
from loveca_data.config import Config  # noqa: E402


def _sandbox() -> tuple[Config, Path]:
    """一時ディレクトリの上に段 2 つだけの Config を作る."""
    root = Path(tempfile.mkdtemp(prefix="loveca-imgman-"))
    cfg = Config(root=root)
    # ★段を 2 つに絞る。★3 段だと「段ごとに 1 行出る」を数えるとき
    #   実データの段数に依存してしまう。
    cfg.image_sizes = {"thumb": (200, 80), "normal": (500, 85)}
    return cfg, root


def _put(cfg: Config, rel: str, body: bytes) -> None:
    path = cfg.dist_dir / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(body)


def test_rows_are_made_for_each_size():
    """★段ごとに 1 行できること."""
    cfg, root = _sandbox()
    try:
        _put(cfg, "images/thumb/aaaa.webp", b"thumb-bytes")
        _put(cfg, "images/normal/aaaa.webp", b"normal-bytes")
        files = build_image_manifest(cfg, {"P-1": "aaaa"})
        assert [f["path"] for f in files] == [
            "images/normal/aaaa.webp",
            "images/thumb/aaaa.webp",
        ], f"並びか件数が違う: {files}"
        assert files[0]["bytes"] == len(b"normal-bytes")
        print("  OK 段ごとに 1 行できる")
    finally:
        shutil.rmtree(root, ignore_errors=True)


def test_hash_comes_from_the_bytes_on_disk():
    """★★ 柵: 行のハッシュは配るバイト列から作る (決定 D121-2) ★★"""
    cfg, root = _sandbox()
    try:
        body = b"the-bytes-we-actually-serve"
        _put(cfg, "images/thumb/aaaa.webp", body)
        files = build_image_manifest(cfg, {"P-1": "aaaa"})
        assert files[0]["hash"] == f"sha256:{hashlib.sha256(body).hexdigest()}", (
            "行のハッシュが配るバイト列から作られていない。"
            "★imageHash (原本 PNG のハッシュ) を書いていないか"
        )
        print("  OK 行のハッシュは配るバイト列から作られる")
    finally:
        shutil.rmtree(root, ignore_errors=True)


def test_hash_changes_when_the_bytes_change():
    """★対: 中身を変えると行のハッシュが変わること.

    ★これが D-4 の受け取り側を閉じる根拠そのものである
    (段の生成設定を変えると **必ず** 行が変わる)。
    """
    cfg, root = _sandbox()
    try:
        _put(cfg, "images/thumb/aaaa.webp", b"quality-80")
        before = build_image_manifest(cfg, {"P-1": "aaaa"})[0]["hash"]
        _put(cfg, "images/thumb/aaaa.webp", b"quality-95")
        after = build_image_manifest(cfg, {"P-1": "aaaa"})[0]["hash"]
        assert before != after, (
            "中身を変えても行のハッシュが変わらない。"
            "★名前 (imageHash) から作っている可能性がある"
        )
        print("  OK 中身を変えると行のハッシュが変わる")
    finally:
        shutil.rmtree(root, ignore_errors=True)


def test_name_alone_does_not_change_the_hash():
    """★対: 名前 (imageHash) が同じでも中身が同じならハッシュも同じ.

    ★上の 2 つだけだと「毎回違う値を返す」実装でも通る。
    """
    cfg, root = _sandbox()
    try:
        _put(cfg, "images/thumb/aaaa.webp", b"same-bytes")
        first = build_image_manifest(cfg, {"P-1": "aaaa"})[0]["hash"]
        second = build_image_manifest(cfg, {"P-1": "aaaa"})[0]["hash"]
        assert first == second
        print("  OK 中身が同じならハッシュも同じ")
    finally:
        shutil.rmtree(root, ignore_errors=True)


def test_generation_side_is_not_closed():
    """★★ 閉じていない側を固定する (決定 D121-2 / 所見 D-4 の残り半分) ★★

    生成側は出力先が既に在れば作り直さない。★段の設定を変えても
    **バイト列が作られない** ので、ここが読むのは古いバイト列である。
    → ★行のハッシュも変わらない。★受け取り側は何も気づけない。

    ★これを「閉じた」と誤読させないために、**変わらないこと** を固定する。
    ★直すときはこの検査が落ちるので、そのとき合図になる。
    """
    cfg, root = _sandbox()
    try:
        # ★「設定を変えたが、ファイルは前のまま」を作る。
        _put(cfg, "images/thumb/aaaa.webp", b"old-quality-bytes")
        before = build_image_manifest(cfg, {"P-1": "aaaa"})[0]["hash"]
        cfg.image_sizes = {"thumb": (200, 95), "normal": (500, 85)}
        after = build_image_manifest(cfg, {"P-1": "aaaa"})[0]["hash"]
        assert before == after, (
            "設定だけ変えたのに行のハッシュが変わった。"
            "★生成側の飛ばしが直ったのなら、この検査を書き直すこと"
        )
        print("  OK 生成側は閉じていない（設定だけ変えても変わらない）")
    finally:
        shutil.rmtree(root, ignore_errors=True)


def test_missing_files_are_skipped():
    """★存在しない段は行にしないこと (置いていないものは配れない)."""
    cfg, root = _sandbox()
    try:
        _put(cfg, "images/thumb/aaaa.webp", b"only-thumb")
        files = build_image_manifest(cfg, {"P-1": "aaaa"})
        assert [f["path"] for f in files] == ["images/thumb/aaaa.webp"]
        print("  OK 存在しない段は行にしない")
    finally:
        shutil.rmtree(root, ignore_errors=True)


def test_shared_image_hash_is_not_duplicated():
    """★同じ imageHash を 2 つの刷りが共有しても 1 行になること.

    ★実データでは今日 0 件だが、原本がバイト単位で同じなら起きる
    (0 件は「起こりえない」ではない / 所見 **D-10**)。
    """
    cfg, root = _sandbox()
    try:
        _put(cfg, "images/thumb/aaaa.webp", b"shared")
        files = build_image_manifest(cfg, {"P-1": "aaaa", "P-2": "aaaa"})
        assert len(files) == 1, f"重複が落ちていない: {files}"
        print("  OK 同じ imageHash は 1 行になる")
    finally:
        shutil.rmtree(root, ignore_errors=True)


def test_original_png_is_picked_up():
    """★Pillow が無い環境で置かれる原本も行にすること.

    ★置いてあるものが配られるものである。★見ないと
    「マニフェストに無い画像が配られる」状態になる。
    """
    cfg, root = _sandbox()
    try:
        _put(cfg, "images/original/aaaa.png", b"raw-png")
        files = build_image_manifest(cfg, {"P-1": "aaaa"})
        assert [f["path"] for f in files] == ["images/original/aaaa.png"]
        print("  OK 原本 PNG も行にする")
    finally:
        shutil.rmtree(root, ignore_errors=True)


def test_card_manifest_is_untouched():
    """★★ カードとメタのマニフェストに 1 行も足さないこと ★★

    ★決定 D121-1 の決め手そのものである —— 決定 D118-1 (商品単位) と
    決定 D118-3 (版ゲート) は `manifest.json` の上に乗っている。

    ★★ 書かれた `manifest.json` を読む ★★
      最初の版は `build_image_manifest` の戻り値だけを見ていた。
      ★`build` の側でその戻り値をカードのマニフェストに連結しても
      **1 件も落ちなかった** (実測 / 所見 **D-27**)。
    """
    cfg, root = _sandbox()
    try:
        _put(cfg, "images/thumb/aaaa.webp", b"x")
        _build(cfg, with_images=True, image_hashes={"P-1": "aaaa"})
        card_paths = [f["path"] for f in _manifest_of(cfg)["files"]]
        assert not any(p.startswith("images/") for p in card_paths), (
            f"カードのマニフェストに画像の行が混ざっている: {card_paths}"
        )
        # ★対: 画像のマニフェストの側にはちゃんと在ること。
        #   ★これが無いと「どちらにも書かない」実装でも通る。
        image_files = _image_manifest_of(cfg)["files"]
        assert [f["path"] for f in image_files] == ["images/thumb/aaaa.webp"]
        # ★対: 行の形がカードのマニフェストと同じであること。
        #   ★形が違うと受け取り側で読み方を 2 つ持つことになる。
        assert set(image_files[0]) == {"path", "hash", "bytes"}
        print("  OK カードのマニフェストに 1 行も足さない")
    finally:
        shutil.rmtree(root, ignore_errors=True)


def test_image_manifest_has_no_data_version():
    """★★ 画像のマニフェストに dataVersion を載せないこと ★★

    ★載せると、カードを 1 文字直して版を上げるたびにこの物のバイト列が
    変わる。★画-5 の利得 (カードの変更と画像の変更が独立に運べる) を
    自分で潰すことになる。★整合は version.json の imageManifestHash が持つ。

    ★★ 組み立てた値ではなく **書かれた物** を読む ★★
      最初の版は `build_image_manifest` の戻り値を包み直して見ていた。
      ★`build` の側で `dataVersion` を足しても **1 件も落ちなかった**
      (実測)。★対を置いても対象を見ていないことがある (所見 **D-27**)。
    """
    cfg, root = _sandbox()
    try:
        _put(cfg, "images/thumb/aaaa.webp", b"x")
        _build(cfg, with_images=True, image_hashes={"P-1": "aaaa"})
        payload = _image_manifest_of(cfg)
        assert set(payload) == {"files"}, (
            f"dataVersion などが載っている: {sorted(payload)}"
        )
        assert payload["files"][0]["path"] == "images/thumb/aaaa.webp"
        print("  OK 画像のマニフェストに dataVersion を載せない")
    finally:
        shutil.rmtree(root, ignore_errors=True)


# ===========================================================================
# ★★ version.json への繋ぎこみ (決定 D121-1 = 画-5) ★★
# ===========================================================================
#
# ★`build` を通す。★カードが 0 件の `NormalizeResult` で回せるので、
#   実データにもネットワークにも触れない。


def _build(cfg: Config, *, with_images: bool,
           image_hashes: dict[str, str] | None = None) -> dict:
    """`build` を一時ディレクトリの上で回す.

    ★カードが 0 件の `NormalizeResult` で回るので実データに触れない。
    ★`build_images` は差し替える —— 実物は原本 PNG を要求し、
      Pillow でリサイズまでする。★ここで見たいのは **その後** である。
    """
    from unittest import mock

    from loveca_data import build_dist
    from loveca_data.normalize import NormalizeResult

    with mock.patch.object(
            build_dist, "build_images", lambda c, r: dict(image_hashes or {})):
        return build_dist.build(
            cfg,
            NormalizeResult(),
            data_version=7,
            min_app_version="0.3.0",
            with_images=with_images,
        )


def _manifest_of(cfg: Config) -> dict:
    return json.loads((cfg.dist_dir / "manifest.json").read_text(encoding="utf-8"))


def _image_manifest_of(cfg: Config) -> dict:
    return json.loads(
        (cfg.dist_dir / "image_manifest.json").read_text(encoding="utf-8"))


def _version_of(cfg: Config) -> dict:
    return json.loads((cfg.dist_dir / "version.json").read_text(encoding="utf-8"))


def test_version_gains_the_image_manifest_columns():
    """★版の情報に画像マニフェストの列が載ること."""
    cfg, root = _sandbox()
    try:
        _build(cfg, with_images=True)
        version = _version_of(cfg)
        assert version["imageManifestPath"] == "/data/image_manifest.json"
        assert version["imageManifestHash"].startswith("sha256:")
        body = (cfg.dist_dir / "image_manifest.json").read_bytes()
        assert version["imageManifestHash"] ==             f"sha256:{hashlib.sha256(body).hexdigest()}",             "宣言されたハッシュが実物と一致しない"
        print("  OK 版の情報に画像マニフェストの列が載る")
    finally:
        shutil.rmtree(root, ignore_errors=True)


def test_skip_images_writes_neither():
    """★★ --skip-images では書かない。★列も出さない ★★

    ★空の物を書くと「画像が 0 枚である」という宣言になる。
    受け取り側に削除の計画を足したとき、それは **全部消せ** と読める。
    ★「まだ無い」と「0 枚である」を書き分ける。
    """
    cfg, root = _sandbox()
    try:
        _build(cfg, with_images=False)
        version = _version_of(cfg)
        assert "imageManifestPath" not in version, f"列が出ている: {sorted(version)}"
        assert "imageManifestHash" not in version
        assert not (cfg.dist_dir / "image_manifest.json").exists()
        print("  OK --skip-images では画像マニフェストも列も出さない")
    finally:
        shutil.rmtree(root, ignore_errors=True)


def test_card_manifest_bytes_are_identical_either_way():
    """★★ 画-5 の決め手そのもの ★★

    ★カードとメタのマニフェストの意味を 1 ミリも動かさない。
    ★画像の有無で `manifest.json` が **1 バイトも変わらない** ことを見る。
    ★これが崩れると 決定 D118-1 (商品単位) と 決定 D118-3 (版ゲート) が
    乗っている土台が動く。
    """
    cfg_a, root_a = _sandbox()
    cfg_b, root_b = _sandbox()
    try:
        _put(cfg_a, "images/thumb/aaaa.webp", b"x")
        _build(cfg_a, with_images=True, image_hashes={"P-1": "aaaa"})
        _build(cfg_b, with_images=False)
        a = (cfg_a.dist_dir / "manifest.json").read_bytes()
        b = (cfg_b.dist_dir / "manifest.json").read_bytes()
        assert a == b, "画像の有無でカードのマニフェストが変わっている"
        # ★対: version.json のほうは変わる (列が載るため)。
        #   ★これが無いと「両方とも何も書いていない」実装でも通る。
        va = (cfg_a.dist_dir / "version.json").read_bytes()
        vb = (cfg_b.dist_dir / "version.json").read_bytes()
        assert va != vb, "版の情報まで同じなら、列が載っていない"
        print("  OK 画像の有無でカードのマニフェストは 1 バイトも変わらない")
    finally:
        shutil.rmtree(root_a, ignore_errors=True)
        shutil.rmtree(root_b, ignore_errors=True)


if __name__ == "__main__":
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    print(f"画像マニフェストテスト {len(tests)} 件を実行\n")
    failed = 0
    for test in tests:
        try:
            test()
        except AssertionError as exc:
            print(f"  NG {test.__name__}: {exc}")
            failed += 1
        except Exception as exc:  # noqa: BLE001
            print(f"  NG {test.__name__}: 想定外の {type(exc).__name__}: {exc}")
            failed += 1
    print(f"\n{'全て成功' if not failed else f'{failed} 件失敗'}")
    sys.exit(1 if failed else 0)
