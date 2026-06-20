#!/usr/bin/env python3
"""Polymarket trading CLI (official CLOB API).

Safety model
------------
Every order command defaults to **dry-run**: it resolves the market, validates
price/size against the market's tick size and minimum, previews the cost, and
prints a deterministic confirmation token — but sends nothing. To actually place
an order you must pass BOTH ``--execute`` and ``--confirm <token>`` where the
token matches the one printed by the dry-run for those exact parameters.

Read-only commands (``market``, ``whoami``, ``positions``) and dry-run previews
work without any third-party packages. Live placement / cancellation / balance
reads require ``py-clob-client-v2`` (see references/trading.md).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys

# Allow running both as a file and as a module.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import credentials as creds_mod  # noqa: E402
import market_data as md  # noqa: E402

DATA_API = os.environ.get("DATA_API_BASE", "https://data-api.polymarket.com").rstrip("/")


def _confirm_token(parts: list[str]) -> str:
    digest = hashlib.sha256("|".join(str(p) for p in parts).encode("utf-8")).hexdigest()
    return digest[:10]


def _scrub(creds, text: str) -> str:
    """Remove any secret values from an error string before it is displayed.

    Third-party signing libraries occasionally embed inputs (including the
    private key, API secret, or passphrase) in exception messages. Strip them so
    a live-execution error path can never leak a credential to stdout.
    """
    for secret in (
        getattr(creds, "private_key", None),
        getattr(creds, "api_secret", None),
        getattr(creds, "api_passphrase", None),
    ):
        if secret and secret in text:
            text = text.replace(secret, "***REDACTED***")
    return text


def _print_json(payload: dict) -> None:
    print(json.dumps(payload, ensure_ascii=False, indent=2))


def _validate_price(price: float, tick: float) -> None:
    if not 0 < price < 1:
        raise SystemExit(f"error: price must be between 0 and 1 (exclusive), got {price}")
    if tick > 0:
        steps = round(price / tick)
        if abs(price - steps * tick) > 1e-9:
            raise SystemExit(
                f"error: price {price} is not a multiple of the market tick size {tick}"
            )


# --------------------------------------------------------------------------
# order commands
# --------------------------------------------------------------------------
def _resolve_target(args) -> tuple[str, str | None, md.Market | None, float]:
    """Return ``(token_id, outcome_label, market_or_None, indicative_price)``.

    Supports ``--token-id`` for offline/direct use, or ``<slug> <outcome>`` which
    resolves via the Gamma API.
    """
    if getattr(args, "token_id", None):
        return args.token_id, None, None, float("nan")
    if not args.market or not args.outcome:
        raise SystemExit("error: provide either --token-id, or both <market-slug> and <outcome>")
    market = md.fetch_market(args.market)
    token_id, label, price = market.token_for(args.outcome)
    return token_id, label, market, price


def _cmd_order(args, side: str) -> int:
    try:
        token_id, label, market, indicative = _resolve_target(args)
    except md.MarketDataError as exc:
        raise SystemExit(f"error: {exc}")

    tick = args.tick_size if args.tick_size is not None else (market.tick_size if market else 0.01)
    min_size = market.min_size if market else 0.0
    neg_risk = market.neg_risk if market else bool(args.neg_risk)

    warnings: list[str] = []
    payload: dict = {
        "action": side.lower(),
        "market": args.market,
        "outcome": label or args.outcome,
        "token_id": token_id,
        "side": side,
        "neg_risk": neg_risk,
        "tick_size": tick,
    }

    if args.limit is not None:
        # Limit order: price + shares.
        if args.shares is None:
            raise SystemExit("error: limit orders require --shares")
        if args.shares <= 0:
            raise SystemExit(f"error: --shares must be positive, got {args.shares}")
        _validate_price(args.limit, tick)
        if min_size and args.shares < min_size:
            warnings.append(f"size {args.shares} is below market minimum {min_size}")
        effective_order_type = args.order_type or "GTC"
        payload.update(
            order_type=effective_order_type,
            price=args.limit,
            size=args.shares,
            estimated_usdc=round(args.limit * args.shares, 6),
            kind="limit",
        )
        # The token binds EVERY parameter that affects the placed order, so a
        # dry-run token can never execute a materially different live order.
        token_parts = [
            side,
            token_id,
            "limit",
            args.limit,
            args.shares,
            tick,
            int(neg_risk),
            effective_order_type,
        ]
    else:
        # Market order: BUY amount is USDC to spend; SELL amount is shares.
        if args.amount is None:
            raise SystemExit("error: market orders require --amount (BUY: USDC, SELL: shares)")
        if args.amount <= 0:
            raise SystemExit(f"error: --amount must be positive, got {args.amount}")
        effective_order_type = args.order_type or "FOK"
        payload.update(order_type=effective_order_type, kind="market", amount=args.amount)
        if side == "BUY":
            payload["amount_unit"] = "USDC"
            if indicative == indicative:  # not NaN
                payload["estimated_shares"] = (
                    round(args.amount / indicative, 4) if indicative else None
                )
        else:
            payload["amount_unit"] = "shares"
            if min_size and args.amount < min_size:
                warnings.append(f"size {args.amount} is below market minimum {min_size}")
            if indicative == indicative:
                payload["estimated_usdc"] = round(args.amount * indicative, 6)
        # The token binds EVERY parameter that affects the placed order.
        token_parts = [
            side,
            token_id,
            "market",
            args.amount,
            tick,
            int(neg_risk),
            effective_order_type,
        ]

    if indicative == indicative:
        payload["indicative_price"] = indicative
    confirm = _confirm_token(token_parts)
    payload["confirm_token"] = confirm
    payload["warnings"] = warnings

    # Surface the wallet the order would actually use, so the operator can
    # confirm it targets the funded proxy (the funder) rather than the bare
    # signer EOA before executing. Loading is best-effort: a missing or
    # malformed credentials file must never block a dry-run preview.
    try:
        _order_creds = creds_mod.load_credentials(args.credentials_file)
    except creds_mod.CredentialError:
        _order_creds = None
    if _order_creds is not None:
        if _order_creds.effective_funder:
            payload["funder"] = _order_creds.effective_funder
        payload["signature_type"] = _order_creds.signature_type

    if not args.execute:
        payload["mode"] = "dry-run"
        payload["hint"] = f"to execute: re-run with --execute --confirm {confirm}"
        _print_json(payload)
        return 0

    if args.confirm != confirm:
        payload["mode"] = "blocked"
        payload["error"] = (
            "missing or mismatched --confirm token; expected "
            f"{confirm} (dry-run first to obtain it)"
        )
        _print_json(payload)
        return 2

    # Live execution.
    creds = None
    try:
        import clob

        creds = creds_mod.load_credentials(args.credentials_file)
        adapter = clob.ClobAdapter(creds)
        if payload["kind"] == "limit":
            result = adapter.place_limit_order(
                token_id,
                args.limit,
                args.shares,
                side,
                tick,
                neg_risk,
                order_type=payload["order_type"],
            )
        else:
            result = adapter.place_market_order(
                token_id,
                args.amount,
                side,
                tick,
                neg_risk,
                order_type=payload["order_type"],
            )
        payload["mode"] = "executed"
        payload["result"] = result if isinstance(result, dict) else str(result)
        _print_json(payload)
        return 0
    except Exception as exc:  # noqa: BLE001
        # Any failure from the client library (e.g. an exchange rejection like
        # PolyApiException) must surface as a clean, secret-scrubbed error rather
        # than an uncaught traceback that could leak inputs.
        payload["mode"] = "error"
        payload["error"] = _scrub(creds, f"{type(exc).__name__}: {exc}")
        _print_json(payload)
        return 1


# --------------------------------------------------------------------------
# read commands
# --------------------------------------------------------------------------
def _cmd_market(args) -> int:
    try:
        market = md.fetch_market(args.market)
    except md.MarketDataError as exc:
        raise SystemExit(f"error: {exc}")
    _print_json(
        {
            "slug": market.slug,
            "question": market.question,
            "condition_id": market.condition_id,
            "neg_risk": market.neg_risk,
            "tick_size": market.tick_size,
            "min_size": market.min_size,
            "outcomes": [
                {"outcome": o, "token_id": t, "price": p}
                for o, t, p in zip(market.outcomes, market.token_ids, market.outcome_prices)
            ],
        }
    )
    return 0


def _cmd_whoami(args) -> int:
    creds = creds_mod.load_credentials(args.credentials_file)
    _print_json(creds.redacted())
    return 0


def _cmd_positions(args) -> int:
    creds = creds_mod.load_credentials(args.credentials_file)
    # Positions live in the funding wallet (the proxy for email/Magic logins),
    # never the bare signer EOA. Default to the funder so a configured account
    # resolves to the wallet that actually holds the positions.
    address = args.address or creds.effective_funder
    if not address:
        raise SystemExit("error: no address given and none found in credentials")
    try:
        import requests
    except ImportError:
        raise SystemExit(
            "error: the 'requests' package is required (pip install -r requirements.txt)"
        )
    try:
        resp = requests.get(
            f"{DATA_API}/positions",
            params={
                "user": address,
                "limit": str(args.limit),
                "sortBy": "CURRENT",
                "sortDirection": "DESC",
            },
            timeout=15,
        )
        resp.raise_for_status()
        _print_json({"address": address, "positions": resp.json()})
        return 0
    except requests.RequestException as exc:
        raise SystemExit(f"error: request failed ({exc})")


def _cmd_balance(args) -> int:
    creds = creds_mod.load_credentials(args.credentials_file)
    try:
        import clob

        adapter = clob.ClobAdapter(creds)
        _print_json({"collateral": adapter.balance("COLLATERAL")})
        return 0
    except (Exception,) as exc:  # noqa: BLE001
        raise SystemExit(f"error: {_scrub(creds, str(exc))}")


def _cmd_orders(args) -> int:
    creds = creds_mod.load_credentials(args.credentials_file)
    try:
        import clob

        adapter = clob.ClobAdapter(creds)
        _print_json({"open_orders": adapter.list_orders()})
        return 0
    except (Exception,) as exc:  # noqa: BLE001
        raise SystemExit(f"error: {_scrub(creds, str(exc))}")


def _cmd_cancel(args) -> int:
    creds = creds_mod.load_credentials(args.credentials_file)
    if not args.all and not args.order_id:
        raise SystemExit("error: provide an order id or --all")
    target = "ALL open orders" if args.all else args.order_id
    # Cancel is state-changing, so it follows the same two-factor model as orders:
    # the confirm token is bound to the cancellation target.
    confirm = _confirm_token(["cancel", "ALL" if args.all else args.order_id])

    if not args.execute:
        _print_json(
            {
                "action": "cancel",
                "target": target,
                "confirm_token": confirm,
                "mode": "dry-run",
                "hint": f"to execute: re-run with --execute --confirm {confirm}",
            }
        )
        return 0

    if args.confirm != confirm:
        _print_json(
            {
                "action": "cancel",
                "target": target,
                "mode": "blocked",
                "error": (
                    "missing or mismatched --confirm token; expected "
                    f"{confirm} (dry-run first to obtain it)"
                ),
            }
        )
        return 2

    try:
        import clob

        adapter = clob.ClobAdapter(creds)
        result = adapter.cancel_all() if args.all else adapter.cancel(args.order_id)
        _print_json({"action": "cancel", "target": target, "mode": "executed", "result": result})
        return 0
    except (Exception,) as exc:  # noqa: BLE001
        raise SystemExit(f"error: {_scrub(creds, str(exc))}")


# --------------------------------------------------------------------------
# argument parser
# --------------------------------------------------------------------------
def _add_credentials_arg(p: argparse.ArgumentParser) -> None:
    p.add_argument("--credentials-file", default=None, help="path to a KEY=VALUE credentials file")


def _add_order_args(p: argparse.ArgumentParser) -> None:
    p.add_argument("market", nargs="?", help="market slug (omit if using --token-id)")
    p.add_argument("outcome", nargs="?", help="outcome: yes/no, an outcome label, or an index")
    p.add_argument("--token-id", help="trade a CLOB token id directly (skips slug resolution)")
    p.add_argument(
        "--amount", type=float, help="market order size (BUY: USDC to spend, SELL: shares)"
    )
    p.add_argument("--shares", type=float, help="limit order size in shares")
    p.add_argument("--limit", type=float, help="limit price in (0,1); omit for a market order")
    p.add_argument("--order-type", help="GTC/GTD/FOK/FAK (default GTC for limit, FOK for market)")
    p.add_argument("--tick-size", type=float, default=None, help="override market tick size")
    p.add_argument(
        "--neg-risk", action="store_true", help="force neg-risk flag when using --token-id"
    )
    p.add_argument(
        "--execute", action="store_true", help="actually place the order (default: dry-run)"
    )
    p.add_argument("--confirm", default=None, help="confirmation token from the dry-run output")
    _add_credentials_arg(p)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="trade.py",
        description="Polymarket trading CLI (official CLOB API). Orders are dry-run by default.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_buy = sub.add_parser("buy", help="buy an outcome (dry-run unless --execute)")
    _add_order_args(p_buy)
    p_buy.set_defaults(func=lambda a: _cmd_order(a, "BUY"))

    p_sell = sub.add_parser("sell", help="sell an outcome (dry-run unless --execute)")
    _add_order_args(p_sell)
    p_sell.set_defaults(func=lambda a: _cmd_order(a, "SELL"))

    p_market = sub.add_parser("market", help="show market token ids and trading parameters")
    p_market.add_argument("market", help="market slug")
    p_market.set_defaults(func=_cmd_market)

    p_positions = sub.add_parser("positions", help="show positions for an address (Data API)")
    p_positions.add_argument(
        "address", nargs="?", help="wallet address (default: credentials funder)"
    )
    p_positions.add_argument("--limit", type=int, default=20)
    _add_credentials_arg(p_positions)
    p_positions.set_defaults(func=_cmd_positions)

    p_balance = sub.add_parser("balance", help="show collateral (pUSD) balance (needs API creds)")
    _add_credentials_arg(p_balance)
    p_balance.set_defaults(func=_cmd_balance)

    p_orders = sub.add_parser("orders", help="list open orders (needs API creds)")
    _add_credentials_arg(p_orders)
    p_orders.set_defaults(func=_cmd_orders)

    p_cancel = sub.add_parser(
        "cancel", help="cancel an order or all orders (dry-run unless --execute)"
    )
    p_cancel.add_argument("order_id", nargs="?", help="order id to cancel")
    p_cancel.add_argument("--all", action="store_true", help="cancel all open orders")
    p_cancel.add_argument(
        "--execute", action="store_true", help="actually cancel (default: dry-run)"
    )
    p_cancel.add_argument("--confirm", default=None, help="confirmation token from the dry-run")
    _add_credentials_arg(p_cancel)
    p_cancel.set_defaults(func=_cmd_cancel)

    p_whoami = sub.add_parser("whoami", help="show resolved credential diagnostics (no secrets)")
    _add_credentials_arg(p_whoami)
    p_whoami.set_defaults(func=_cmd_whoami)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
