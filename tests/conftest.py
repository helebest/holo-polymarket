"""Make the src/ package and the trade skill scripts importable in tests."""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
TRADE_SCRIPTS = ROOT / "skills" / "polymarket-trade" / "scripts"

for path in (SRC, TRADE_SCRIPTS):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))
