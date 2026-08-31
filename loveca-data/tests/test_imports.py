"""モジュール整合性の検査.

★この検査の存在理由★
コードをパッチで書き換えた際、関数ブロックを丸ごと置換して
間にあった別の関数を巻き込み削除する事故が実際に起きた。
Pylance が指摘するまで気づけなかったため、機械的に検出できるようにする。

ネットワークアクセスは一切しない。
"""

from __future__ import annotations

import ast
import importlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

PACKAGE = ROOT / "loveca_data"

# 各モジュールが公開していなければならない関数・クラス
REQUIRED = {
    "loveca_data.config": ["Config"],
    "loveca_data.constants": ["HEART_FIELD", "HEART_ICON", "HEART_NAME", "RULE_CONFIG"],
    "loveca_data.http_client": ["RateLimitedClient", "FetchError", "AbortError"],
    "loveca_data.fetch": [
        "fetch_search_form", "extract_expansions", "extract_rarities",
        "describe_search_form", "fetch_list", "fetch_base_printing_ids",
        "load_base_printing_ids", "fetch_detail", "fetch_all_details",
        "fetch_images", "load_all_list_items", "energy_pseudo_details",
        "load_normalize_input", "load_all_details",
    ],
    "loveca_data.normalize": [
        "nfkc", "clean_text", "clean_name", "split_card_number", "split_slash",
        "split_ampersand", "parse_heart_string", "parse_heart_fields",
        "heart_icons_to_map", "normalize_card", "normalize_faqs", "normalize_all",
    ],
    "loveca_data.validate": ["validate", "load_previous_card_numbers"],
    "loveca_data.build_dist": ["build", "build_images"],
    "loveca_data.stats": ["summarize"],
    "loveca_data.cli": ["main", "build_parser"],
}


def test_all_modules_import():
    """全モジュールが構文エラーなく import できること."""
    for module_name in REQUIRED:
        importlib.import_module(module_name)
    print(f"  OK 全 {len(REQUIRED)} モジュールが import 可能")


def test_required_symbols_exist():
    """各モジュールに必要な関数・クラスが存在すること (削除事故の検出)."""
    missing = []
    for module_name, symbols in REQUIRED.items():
        module = importlib.import_module(module_name)
        for symbol in symbols:
            if not hasattr(module, symbol):
                missing.append(f"{module_name}.{symbol}")
    assert not missing, f"以下が存在しません: {missing}"
    total = sum(len(v) for v in REQUIRED.values())
    print(f"  OK 必須シンボル {total} 個がすべて存在")


def test_no_undefined_names():
    """モジュール内で未定義の名前を参照していないこと.

    Pylance の reportUndefinedVariable 相当を簡易的に検査する。
    モジュールレベルで定義された名前・import された名前・組み込み名の
    いずれでもない関数呼び出しを検出する。
    """
    import builtins

    problems = []
    for path in sorted(PACKAGE.glob("*.py")):
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))

        defined: set[str] = set(dir(builtins))
        for node in ast.walk(tree):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
                defined.add(node.name)
            elif isinstance(node, ast.Import):
                for alias in node.names:
                    defined.add(alias.asname or alias.name.split(".")[0])
            elif isinstance(node, ast.ImportFrom):
                for alias in node.names:
                    defined.add(alias.asname or alias.name)
            elif isinstance(node, ast.Name) and isinstance(node.ctx, ast.Store):
                defined.add(node.id)
            elif isinstance(node, ast.arg):
                defined.add(node.arg)
            elif isinstance(node, (ast.ExceptHandler,)) and node.name:
                defined.add(node.name)
            elif isinstance(node, (ast.comprehension,)):
                for n in ast.walk(node.target):
                    if isinstance(n, ast.Name):
                        defined.add(n.id)

        # 関数呼び出しの対象が定義済みかを確認する
        for node in ast.walk(tree):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
                if node.func.id not in defined:
                    problems.append(f"{path.name}:{node.lineno} {node.func.id}")

    assert not problems, "未定義の関数を呼び出しています:\n  " + "\n  ".join(problems)
    print("  OK 未定義の名前を参照していない")


if __name__ == "__main__":
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    print(f"整合性テスト {len(tests)} 件を実行\n")
    failed = 0
    for test in tests:
        try:
            test()
        except AssertionError as exc:
            print(f"  NG {test.__name__}: {exc}")
            failed += 1
    print(f"\n{'全て成功' if not failed else f'{failed} 件失敗'}")
    sys.exit(1 if failed else 0)
