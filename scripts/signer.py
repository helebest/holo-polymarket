#!/usr/bin/env python3
"""
Polymarket EIP-712 Order Signer

Uses py-clob-client to create properly signed orders for the Polymarket CLOB API.
Called from bash scripts via: uv run python scripts/signer.py [args]

Security: Use --credentials-stdin to pass secrets via stdin (not visible in ps).
Output: JSON object with signed order ready for POST /orders
"""

import argparse
import json
import sys


def parse_args():
    parser = argparse.ArgumentParser(
        description="Sign a Polymarket CLOB order using EIP-712"
    )
    parser.add_argument("--credentials-stdin", action="store_true",
                        help="Read credentials JSON from stdin (private_key, api_key, api_secret, api_passphrase)")
    parser.add_argument("--private-key", default=None, help="Ethereum private key (hex) — prefer --credentials-stdin")
    parser.add_argument("--token-id", required=True, help="CLOB token ID")
    parser.add_argument("--price", required=True, type=float, help="Order price (0.01-0.99)")
    parser.add_argument("--size", required=True, type=float, help="Order size")
    parser.add_argument("--side", required=True, choices=["BUY", "SELL"], help="Order side")
    parser.add_argument("--order-type", default="GTC", choices=["GTC", "FOK", "GTD"], help="Order type")
    parser.add_argument("--neg-risk", default="false", choices=["true", "false"], help="Neg-risk market flag")
    parser.add_argument("--tick-size", default="0.01", choices=["0.1", "0.01", "0.001", "0.0001"], help="Tick size")
    parser.add_argument("--api-key", default=None, help="CLOB API key — prefer --credentials-stdin")
    parser.add_argument("--api-secret", default=None, help="CLOB API secret — prefer --credentials-stdin")
    parser.add_argument("--api-passphrase", default=None, help="CLOB API passphrase — prefer --credentials-stdin")
    return parser.parse_args()


def main():
    args = parse_args()

    private_key = args.private_key
    api_key = args.api_key
    api_secret = args.api_secret
    api_passphrase = args.api_passphrase

    # Read credentials from stdin if requested (secure: not visible in ps)
    if args.credentials_stdin:
        creds = json.load(sys.stdin)
        private_key = creds.get("private_key", private_key)
        api_key = creds.get("api_key", api_key)
        api_secret = creds.get("api_secret", api_secret)
        api_passphrase = creds.get("api_passphrase", api_passphrase)

    if not private_key:
        json.dump({"error": "missing private_key"}, sys.stdout)
        sys.stdout.write("\n")
        sys.exit(1)

    if not api_key:
        json.dump({"error": "missing api_key"}, sys.stdout)
        sys.stdout.write("\n")
        sys.exit(1)

    # Lazy imports — only load heavy crypto libs after arg validation
    from py_clob_client.clob_types import OrderArgs, CreateOrderOptions
    from py_clob_client.constants import POLYGON
    from py_clob_client.signer import Signer
    from py_clob_client.order_builder.builder import OrderBuilder

    neg_risk = args.neg_risk == "true"

    signer = Signer(private_key, POLYGON)
    builder = OrderBuilder(signer, sig_type=0, funder=signer.address())

    order_args = OrderArgs(
        token_id=args.token_id,
        price=args.price,
        size=args.size,
        side=args.side,
    )

    options = CreateOrderOptions(
        tick_size=args.tick_size,
        neg_risk=neg_risk,
    )

    signed_order = builder.create_order(order_args, options)

    # Build the POST body expected by CLOB /orders endpoint
    # owner must be api_key (not wallet address) per py-clob-client's order_to_json
    result = {
        "order": signed_order.dict(),
        "owner": api_key,
        "orderType": args.order_type,
    }

    json.dump(result, sys.stdout, default=str)
    sys.stdout.write("\n")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as e:
        # Output sanitized JSON error — never expose secrets or tracebacks
        error_type = type(e).__name__
        error_msg = str(e)
        # Strip any content that looks like a private key or secret
        for prefix in ("0x", "--private-key", "--api-key", "--api-secret", "--api-passphrase"):
            if prefix in error_msg:
                error_msg = f"{error_type}: signing failed"
                break
        json.dump({"error": error_msg}, sys.stdout)
        sys.stdout.write("\n")
        sys.exit(1)
