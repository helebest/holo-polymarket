"""Read-only Polymarket market data (no credentials, no signing).

Resolves a market slug to its tradeable CLOB token ids and per-market trading
parameters (tick size, minimum order size, neg-risk flag, indicative prices),
using the public Gamma API. ``requests`` is imported lazily so that ``--help``
and offline dry-runs work without any third-party packages installed.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass

GAMMA_API = os.environ.get("GAMMA_API_BASE", "https://gamma-api.polymarket.com").rstrip("/")
HTTP_TIMEOUT = float(os.environ.get("POLYMARKET_HTTP_TIMEOUT", "15"))


class MarketDataError(Exception):
    """Raised when market data cannot be fetched or parsed."""


@dataclass
class Market:
    """A single binary CLOB market and its trading parameters."""

    slug: str
    question: str
    condition_id: str
    neg_risk: bool
    tick_size: float
    min_size: float
    outcomes: list[str]
    token_ids: list[str]
    outcome_prices: list[float]

    def outcome_index(self, outcome: str) -> int:
        """Resolve an outcome selector to an index into ``outcomes``.

        Accepts ``yes``/``no`` (case-insensitive), an exact outcome label, or a
        numeric index. Raises :class:`MarketDataError` on an ambiguous or unknown
        selector.
        """
        sel = outcome.strip()
        lowered = [o.lower() for o in self.outcomes]
        if sel.lower() in lowered:
            return lowered.index(sel.lower())
        if sel.isdigit():
            idx = int(sel)
            if 0 <= idx < len(self.token_ids):
                return idx
            raise MarketDataError(f"outcome index {idx} out of range for {self.outcomes}")
        raise MarketDataError(f"unknown outcome {outcome!r}; available outcomes: {self.outcomes}")

    def token_for(self, outcome: str) -> tuple[str, str, float]:
        """Return ``(token_id, outcome_label, indicative_price)`` for an outcome."""
        idx = self.outcome_index(outcome)
        price = self.outcome_prices[idx] if idx < len(self.outcome_prices) else float("nan")
        return self.token_ids[idx], self.outcomes[idx], price


def _get_json(path: str, params: dict[str, str]):
    try:
        import requests  # lazy: only needed for live network calls
    except ImportError as exc:  # pragma: no cover - environment dependent
        raise MarketDataError(
            "The 'requests' package is required for market data. "
            "Install it with: pip install -r requirements.txt"
        ) from exc

    url = f"{GAMMA_API}{path}"
    try:
        resp = requests.get(url, params=params, timeout=HTTP_TIMEOUT)
        resp.raise_for_status()
        return resp.json()
    except requests.RequestException as exc:
        raise MarketDataError(f"request failed: {url} ({exc})") from exc


def _maybe_json_list(value) -> list:
    """Gamma returns some array fields as JSON-encoded strings; normalise them."""
    if value is None:
        return []
    if isinstance(value, list):
        return value
    if isinstance(value, str):
        try:
            parsed = json.loads(value)
            return parsed if isinstance(parsed, list) else [parsed]
        except json.JSONDecodeError:
            return [value]
    return [value]


def _to_float(value, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _market_from_payload(payload: dict) -> Market:
    token_ids = [str(t) for t in _maybe_json_list(payload.get("clobTokenIds"))]
    outcomes = [str(o) for o in _maybe_json_list(payload.get("outcomes"))]
    prices = [_to_float(p) for p in _maybe_json_list(payload.get("outcomePrices"))]
    if not token_ids:
        raise MarketDataError(f"market {payload.get('slug')!r} has no clobTokenIds (not tradeable)")
    return Market(
        slug=str(payload.get("slug", "")),
        question=str(payload.get("question") or payload.get("title") or ""),
        condition_id=str(payload.get("conditionId", "")),
        neg_risk=bool(payload.get("negRisk", False)),
        tick_size=_to_float(payload.get("orderPriceMinTickSize"), 0.01),
        min_size=_to_float(payload.get("orderMinSize"), 0.0),
        outcomes=outcomes,
        token_ids=token_ids,
        outcome_prices=prices,
    )


def fetch_market(slug: str) -> Market:
    """Fetch a single binary market by its market slug from the Gamma API."""
    if not slug:
        raise MarketDataError("a market slug is required")
    data = _get_json("/markets", {"slug": slug})
    markets = data if isinstance(data, list) else data.get("data") or []
    if not markets:
        raise MarketDataError(
            f"no market found for slug {slug!r}. Use the polymarket-query skill "
            "(detail/search) to find the exact market slug."
        )
    if len(markets) > 1:
        # Multiple markets share the slug prefix; prefer an exact slug match.
        exact = [m for m in markets if m.get("slug") == slug]
        markets = exact or markets
    return _market_from_payload(markets[0])
