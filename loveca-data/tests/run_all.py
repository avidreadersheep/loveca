"""全テストを実行する.

    python tests/run_all.py

ネットワークアクセスは一切しないので、いつでも安全に実行できる。
"""
import subprocess
import sys
from pathlib import Path

TESTS = ["test_imports.py", "test_normalize.py", "test_build_dist.py"]
here = Path(__file__).parent

failed = []
for name in TESTS:
    print(f"\n{'=' * 60}\n{name}\n{'=' * 60}")
    result = subprocess.run([sys.executable, str(here / name)])
    if result.returncode != 0:
        failed.append(name)

print(f"\n{'=' * 60}")
if failed:
    print(f"失敗: {', '.join(failed)}")
    sys.exit(1)
print("全テスト成功")
