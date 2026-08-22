"""総合ルール PDF から本文テキストを抽出する.

★使う前に: docs/ に公式 PDF を配置する★
公式ルールブックはブシロードの著作物なので git 管理外にしてある（.gitignore の `docs/*.pdf`）。
クローン直後の docs/ に PDF は入っていない。公式サイトから各自で取得し、docs/ に置いてから使う。

    docs/LoveLiveTCG_cr_1.06_260428.pdf    ← このように置く

版が上がってもファイル名を書き換えずに済むよう、docs/ 直下の PDF を自動で探す。
複数置いた場合は --pdf で明示する。

★このスクリプトの存在理由★
この PDF は暗号化されていない（/Encrypt が 1 件も存在しない）にもかかわらず、
一部の PDF リーダが「password-protected」と誤判定して読み込みを拒否する。
条番号の根拠を確認するたびに読めないのでは作業にならないため、
zlib（FlateDecode）と ToUnicode CMap だけで本文を取り出す経路を用意した。

依存は標準ライブラリのみ。loveca-data と同じく追加パッケージを要求しない。

    python docs/tools/extract_rules.py                  # 全ページを標準出力へ
    python docs/tools/extract_rules.py --pages 7-9      # 7〜9 ページだけ
    python docs/tools/extract_rules.py -o cr106.txt     # ファイルへ書き出す

出力は条番号が行頭に来るよう整形してある。条文の突き合わせは次のように行える。

    grep -n "^8\\.4\\.13\\." cr106.txt

終了コード:
    0  抽出に成功した
    1  PDF が見つからない / 複数あって特定できない / 解析に失敗した
"""

from __future__ import annotations

import argparse
import re
import sys
import zlib
from pathlib import Path
from typing import Any

# PDF の字句要素。空白と区切り記号は仕様 (PDF 32000-1 §7.2.2) の定義に合わせる。
WHITESPACE = b"\x00\t\n\x0c\r "
DELIMITERS = b"()<>[]{}/%"

# TJ 配列の数値がこの値より小さい (負に大きい) 場合、語間の空きとみなす。
# 総合ルールの本文は約物の詰めで -180 程度まで出るため、それより大きく取る。
WORD_GAP_THRESHOLD = -180


class Ref:
    """間接参照 `N 0 R`."""

    __slots__ = ("num",)

    def __init__(self, num: int) -> None:
        self.num = num

    def __repr__(self) -> str:  # pragma: no cover - デバッグ用
        return f"Ref({self.num})"


class Stream:
    """ストリームオブジェクト（辞書 + 生バイト）."""

    __slots__ = ("dict", "raw")

    def __init__(self, d: dict[str, Any], raw: bytes) -> None:
        self.dict = d
        self.raw = raw


# --------------------------------------------------------------------------
# 字句解析
# --------------------------------------------------------------------------

def skip_ws(buf: bytes, i: int) -> int:
    """空白とコメントを読み飛ばした位置を返す."""
    n = len(buf)
    while i < n:
        c = buf[i : i + 1]
        if c == b"%":
            while i < n and buf[i : i + 1] not in b"\r\n":
                i += 1
        elif c[0] in WHITESPACE:
            i += 1
        else:
            break
    return i


def parse_object(buf: bytes, i: int) -> tuple[Any, int]:
    """位置 i のオブジェクトを 1 つ読み、(値, 次の位置) を返す.

    解析できない場合は (None, i + 1) を返して前進する。壊れたストリームで
    止まらないことを優先する（本文が取れれば十分なため）。
    """
    i = skip_ws(buf, i)
    if i >= len(buf):
        return None, i
    c = buf[i : i + 1]

    if c == b"<":
        if buf[i + 1 : i + 2] == b"<":
            return _parse_dict(buf, i + 2)
        return _parse_hex_string(buf, i)
    if c == b"/":
        return _parse_name(buf, i + 1)
    if c == b"[":
        return _parse_array(buf, i + 1)
    if c == b"(":
        return _parse_literal_string(buf, i + 1)

    m = re.match(rb"(\d+)\s+(\d+)\s+R\b", buf[i : i + 32])
    if m:
        return Ref(int(m.group(1))), i + m.end()
    m = re.match(rb"[+-]?(\d+\.?\d*|\.\d+)", buf[i : i + 40])
    if m:
        tok = m.group(0)
        return (float(tok) if b"." in tok else int(tok)), i + m.end()
    m = re.match(rb"(true|false|null)\b", buf[i : i + 8])
    if m:
        return {b"true": True, b"false": False, b"null": None}[m.group(1)], i + m.end()
    return None, i + 1


def _parse_dict(buf: bytes, i: int) -> tuple[dict[str, Any], int]:
    d: dict[str, Any] = {}
    while True:
        i = skip_ws(buf, i)
        if buf[i : i + 2] == b">>":
            return d, i + 2
        if i >= len(buf):
            return d, i
        if buf[i : i + 1] != b"/":
            # キーでないものが来たら読み捨てて続行する。
            _, i = parse_object(buf, i)
            continue
        key, i = parse_object(buf, i)
        val, i = parse_object(buf, i)
        d[key] = val


def _parse_hex_string(buf: bytes, i: int) -> tuple[bytes, int]:
    j = buf.find(b">", i)
    digits = re.sub(rb"[^0-9A-Fa-f]", b"", buf[i + 1 : j])
    if len(digits) % 2:
        digits += b"0"  # 奇数桁は 0 で埋める (仕様 §7.3.4.3)
    return bytes.fromhex(digits.decode()), j + 1


def _parse_name(buf: bytes, i: int) -> tuple[str, int]:
    start = i
    while i < len(buf) and buf[i] not in WHITESPACE and buf[i : i + 1] not in DELIMITERS:
        i += 1
    raw = re.sub(rb"#([0-9A-Fa-f]{2})", lambda m: bytes([int(m.group(1), 16)]), buf[start:i])
    return "/" + raw.decode("latin-1"), i


def _parse_array(buf: bytes, i: int) -> tuple[list[Any], int]:
    items: list[Any] = []
    while True:
        i = skip_ws(buf, i)
        if buf[i : i + 1] == b"]":
            return items, i + 1
        if i >= len(buf):
            return items, i
        val, nxt = parse_object(buf, i)
        if nxt <= i:  # 前進しない場合は無限ループを避ける
            i += 1
            continue
        i = nxt
        items.append(val)


def _parse_literal_string(buf: bytes, i: int) -> tuple[bytes, int]:
    escapes = {b"n": 10, b"r": 13, b"t": 9, b"b": 8, b"f": 12, b"(": 40, b")": 41, b"\\": 92}
    depth = 1
    out = bytearray()
    while i < len(buf):
        ch = buf[i : i + 1]
        if ch == b"\\":
            nxt = buf[i + 1 : i + 2]
            if nxt in escapes:
                out.append(escapes[nxt])
                i += 2
            elif nxt.isdigit():
                octal = b""
                j = i + 1
                while j < len(buf) and len(octal) < 3 and buf[j : j + 1].isdigit():
                    octal += buf[j : j + 1]
                    j += 1
                out.append(int(octal, 8) & 0xFF)
                i = j
            else:
                i += 2  # 行継続など。何も出力しない
        elif ch == b"(":
            depth += 1
            out += ch
            i += 1
        elif ch == b")":
            depth -= 1
            i += 1
            if depth == 0:
                break
            out += ch
        else:
            out += ch
            i += 1
    return bytes(out), i


# --------------------------------------------------------------------------
# ドキュメント構造
# --------------------------------------------------------------------------

def load_objects(data: bytes) -> dict[int, Any]:
    """ファイル中の全オブジェクトを番号 -> 値の辞書にする.

    xref を信用せず `N 0 obj` を総当たりで拾う。増分更新された PDF でも
    最後に現れた定義が勝つので、本文抽出の用途では十分。
    オブジェクトストリーム (/ObjStm) の中身も展開する。
    """
    objs: dict[int, Any] = {}
    for m in re.finditer(rb"(?:^|[\r\n\s>])(\d+)\s+(\d+)\s+obj\b", data):
        num = int(m.group(1))
        d, i = parse_object(data, m.end())
        j = skip_ws(data, i)
        if data[j : j + 6] != b"stream":
            objs[num] = d
            continue
        j += 6
        if data[j : j + 2] == b"\r\n":
            j += 2
        elif data[j : j + 1] in (b"\n", b"\r"):
            j += 1
        objs[num] = Stream(d, _stream_bytes(data, j, d))

    for num in list(objs):
        obj = objs[num]
        if isinstance(obj, Stream) and obj.dict.get("/Type") == "/ObjStm":
            _expand_object_stream(obj, objs)
    return objs


def _stream_bytes(data: bytes, start: int, d: Any) -> bytes:
    """/Length を優先し、値が信用できなければ endstream まで読む."""
    length = d.get("/Length") if isinstance(d, dict) else None
    if isinstance(length, int) and data[start + length : start + length + 12].strip().startswith(b"endstream"):
        return data[start : start + length]
    return data[start : data.find(b"endstream", start)]


def _expand_object_stream(obj: Stream, objs: dict[int, Any]) -> None:
    content = decode_stream(obj)
    count = obj.dict.get("/N", 0)
    first = obj.dict.get("/First", 0)
    header = content[:first].split()
    for t in range(count):
        try:
            num = int(header[2 * t])
            offset = int(header[2 * t + 1])
        except (IndexError, ValueError):
            return
        if num in objs:  # 通常オブジェクトの定義を優先する
            continue
        value, _ = parse_object(content, first + offset)
        objs[num] = value


def decode_stream(stream: Stream) -> bytes:
    """FlateDecode を解く。他のフィルタは本文に現れないため扱わない."""
    raw = stream.raw
    filters = stream.dict.get("/Filter")
    for f in [filters] if isinstance(filters, str) else (filters or []):
        if f == "/FlateDecode":
            try:
                raw = zlib.decompressobj().decompress(raw)
            except zlib.error:
                return b""
    return raw


def resolve(objs: dict[int, Any], value: Any) -> Any:
    """間接参照をたどって実体を返す（循環参照は 32 段で打ち切る）."""
    for _ in range(32):
        if not isinstance(value, Ref):
            return value
        value = objs.get(value.num)
    return value


def collect_pages(objs: dict[int, Any]) -> list[dict[str, Any]]:
    """ページツリーを深さ優先でたどり、/Page を出現順に集める."""
    pages: list[dict[str, Any]] = []

    def walk(node: Any, depth: int = 0) -> None:
        node = resolve(objs, node)
        if not isinstance(node, dict) or depth > 32:
            return
        if node.get("/Type") == "/Page":
            pages.append(node)
            return
        for kid in node.get("/Kids") or []:
            walk(kid, depth + 1)

    root = resolve(objs, objs.get(1))
    if isinstance(root, dict):
        walk(root.get("/Pages"))
    if not pages:  # /Root が 1 番でない PDF への保険
        for obj in objs.values():
            if isinstance(obj, dict) and obj.get("/Type") == "/Catalog":
                walk(obj.get("/Pages"))
                break
    return pages


# --------------------------------------------------------------------------
# フォントと文字列の復号
# --------------------------------------------------------------------------

def build_cmap(objs: dict[int, Any], font: Any) -> tuple[dict[int, str], int]:
    """フォントの ToUnicode CMap を (コード -> 文字, コード幅) にする.

    Type0 (Identity-H) は 2 バイト、単純フォントは 1 バイト。
    埋め込みサブセットなのでコード値そのものに意味はなく、CMap が唯一の手がかり。
    """
    font = resolve(objs, font)
    if not isinstance(font, dict):
        return {}, 1
    width = 2 if font.get("/Subtype") == "/Type0" else 1
    tounicode = resolve(objs, font.get("/ToUnicode"))
    if not isinstance(tounicode, Stream):
        return {}, width

    cmap: dict[int, str] = {}
    content = decode_stream(tounicode)
    for block in re.findall(rb"beginbfchar(.*?)endbfchar", content, re.S):
        for src, dst in re.findall(rb"<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>", block):
            cmap[int(src, 16)] = bytes.fromhex(dst.decode()).decode("utf-16-be", "ignore")
    for block in re.findall(rb"beginbfrange(.*?)endbfrange", content, re.S):
        pattern = rb"<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*(?:<([0-9A-Fa-f]+)>|\[(.*?)\])"
        for m in re.finditer(pattern, block, re.S):
            lo, hi = int(m.group(1), 16), int(m.group(2), 16)
            if m.group(3):
                base = bytes.fromhex(m.group(3).decode()).decode("utf-16-be", "ignore")
                if not base:
                    continue
                for code in range(lo, min(hi, lo + 0xFFFF) + 1):
                    cmap[code] = base[:-1] + chr(ord(base[-1]) + code - lo)
            else:
                for offset, item in enumerate(re.findall(rb"<([0-9A-Fa-f]+)>", m.group(4) or b"")):
                    cmap[lo + offset] = bytes.fromhex(item.decode()).decode("utf-16-be", "ignore")
    return cmap, width


def page_text(objs: dict[int, Any], page: dict[str, Any]) -> str:
    """1 ページ分のテキストを取り出す.

    テキスト表示演算子 (Tj / TJ / ' / ") だけを見る。位置指定 (Td / TD / T*) と
    ET を改行として扱い、TJ 配列の大きな負値を語間の空きとする。
    段組みの復元まではしない（条番号が行頭に来れば用は足りるため）。
    """
    resources = resolve(objs, page.get("/Resources")) or {}
    fonts = resolve(objs, resources.get("/Font")) or {}
    cmaps = {name: build_cmap(objs, font) for name, font in fonts.items()}

    contents = page.get("/Contents")
    contents = [contents] if isinstance(contents, Ref) else (contents or [])
    buf = b""
    for c in contents:
        c = resolve(objs, c)
        if isinstance(c, Stream):
            buf += decode_stream(c) + b"\n"

    out: list[str] = []
    current: tuple[dict[int, str], int] = ({}, 1)
    operands: list[Any] = []

    def show(raw: bytes) -> str:
        cmap, width = current
        if width == 2:
            return "".join(cmap.get((raw[k] << 8) | raw[k + 1], "") for k in range(0, len(raw) - 1, 2))
        return "".join(
            cmap.get(b, chr(b) if 32 <= b < 127 else "") for b in raw
        )

    for is_operand, value in _tokenize_content(buf):
        if is_operand:
            operands.append(value)
            continue
        op = value
        if op == b"Tf" and len(operands) >= 2 and isinstance(operands[-2], str):
            current = cmaps.get(operands[-2], ({}, 1))
        elif op == b"Tj" and operands and isinstance(operands[-1], bytes):
            out.append(show(operands[-1]))
        elif op in (b"'", b'"') and operands and isinstance(operands[-1], bytes):
            out.append("\n" + show(operands[-1]))
        elif op == b"TJ" and operands and isinstance(operands[-1], list):
            chunk = ""
            for element in operands[-1]:
                if isinstance(element, bytes):
                    chunk += show(element)
                elif isinstance(element, (int, float)) and element < WORD_GAP_THRESHOLD:
                    chunk += " "
            out.append(chunk)
        elif op in (b"Td", b"TD", b"T*", b"ET"):
            out.append("\n")
        operands = []

    text = "".join(out)
    text = re.sub(r"\n{2,}", "\n", text)
    # 条番号だけを行頭に残す。折り返しで途中に入る改行は畳む。
    return re.sub(r"\n(?=[^0-9])", "", text)


def _tokenize_content(buf: bytes):
    """コンテントストリームを (オペランドか, 値) の列にする."""
    i, n = 0, len(buf)
    while i < n:
        i = skip_ws(buf, i)
        if i >= n:
            return
        ch = buf[i : i + 1]
        if ch in b"(<[/" or ch.isdigit() or ch in b"+-.":
            value, nxt = parse_object(buf, i)
            if nxt <= i:
                i += 1
                continue
            yield True, value
            i = nxt
        else:
            start = i
            while i < n and buf[i] not in WHITESPACE and buf[i : i + 1] not in DELIMITERS:
                i += 1
            if i == start:
                i += 1
                continue
            yield False, buf[start:i]


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def find_pdf(explicit: str | None) -> Path:
    """使用する PDF を決める。見つからなければ配置方法を示して終了する."""
    if explicit:
        path = Path(explicit)
        if not path.is_file():
            sys.exit(f"PDF が見つかりません: {path}")
        return path

    docs = Path(__file__).resolve().parent.parent
    candidates = sorted(docs.glob("*.pdf"))
    if not candidates:
        sys.exit(
            f"docs/ に PDF がありません: {docs}\n"
            "\n"
            "公式ルールブックは著作物のため git 管理外にしてあります"
            "（.gitignore の docs/*.pdf）。\n"
            "公式サイトから総合ルールの PDF を取得し、docs/ に置いてから実行してください。\n"
            "\n"
            "  例) docs/LoveLiveTCG_cr_1.06_260428.pdf"
        )
    if len(candidates) > 1:
        listed = "\n".join(f"  {p.name}" for p in candidates)
        sys.exit(f"docs/ に PDF が複数あります。--pdf で指定してください。\n{listed}")
    return candidates[0]


def parse_page_range(spec: str | None, total: int) -> range:
    """'7-9' / '7' を 0 始まりの range にする."""
    if not spec:
        return range(total)
    m = re.fullmatch(r"(\d+)(?:-(\d+))?", spec.strip())
    if not m:
        sys.exit(f"--pages の書式が不正です: {spec}（例: 7 または 7-9）")
    start = int(m.group(1))
    end = int(m.group(2) or start)
    if start < 1 or end < start:
        sys.exit(f"--pages の範囲が不正です: {spec}")
    return range(start - 1, min(end, total))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="総合ルール PDF から本文テキストを抽出する（標準ライブラリのみ）",
    )
    parser.add_argument("--pdf", help="PDF のパス。省略時は docs/ 直下の PDF を自動で探す")
    parser.add_argument("--pages", help="抽出するページ範囲（例: 7-9）。省略時は全ページ")
    parser.add_argument("-o", "--out", help="書き出し先。省略時は標準出力")
    args = parser.parse_args(argv)

    path = find_pdf(args.pdf)
    data = path.read_bytes()
    if b"/Encrypt" in data:
        # 暗号化された版が配られた場合は素直に諦める（復号はしない）。
        sys.exit(f"この PDF は暗号化されています: {path.name}")

    objs = load_objects(data)
    pages = collect_pages(objs)
    if not pages:
        sys.exit(f"ページを取得できませんでした: {path.name}")

    chunks: list[str] = []
    for index in parse_page_range(args.pages, len(pages)):
        chunks.append(f"========== PAGE {index + 1} ==========")
        chunks.append(page_text(objs, pages[index]))
    text = "\n".join(chunks)

    if args.out:
        Path(args.out).write_text(text, encoding="utf-8")
        print(f"{path.name}: {len(pages)} ページ中 {len(text)} 文字を {args.out} へ書き出しました", file=sys.stderr)
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
