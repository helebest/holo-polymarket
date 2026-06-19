from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TRADE = ROOT / "skills/polymarket-trade/scripts/trade.py"


def run(*args: str):
    return subprocess.run(
        [sys.executable, str(TRADE), *args], text=True, capture_output=True, check=False
    )


def test_help_works_without_dependencies() -> None:
    result = run("--help")
    assert result.returncode == 0, result.stderr
    assert "usage:" in result.stdout


def test_dry_run_limit_buy_is_offline_and_previews_cost() -> None:
    result = run("buy", "--token-id", "123", "--limit", "0.40", "--shares", "10")
    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    assert payload["mode"] == "dry-run"
    assert payload["side"] == "BUY"
    assert payload["kind"] == "limit"
    assert payload["estimated_usdc"] == 4.0
    assert payload["confirm_token"]
    assert "--execute --confirm" in payload["hint"]


def test_market_buy_amount_is_usdc_and_sell_is_shares() -> None:
    buy = json.loads(run("buy", "--token-id", "1", "--amount", "25").stdout)
    sell = json.loads(run("sell", "--token-id", "1", "--amount", "50").stdout)
    assert buy["kind"] == "market" and buy["amount_unit"] == "USDC"
    assert sell["kind"] == "market" and sell["amount_unit"] == "shares"


def test_execute_without_confirm_is_blocked() -> None:
    result = run("buy", "--token-id", "1", "--limit", "0.40", "--shares", "10", "--execute")
    assert result.returncode == 2
    payload = json.loads(result.stdout)
    assert payload["mode"] == "blocked"


def test_execute_with_wrong_confirm_is_blocked() -> None:
    result = run(
        "buy",
        "--token-id",
        "1",
        "--limit",
        "0.40",
        "--shares",
        "10",
        "--execute",
        "--confirm",
        "deadbeef",
    )
    assert result.returncode == 2
    assert json.loads(result.stdout)["mode"] == "blocked"


def test_confirm_token_is_deterministic_and_parameter_bound() -> None:
    a = json.loads(run("buy", "--token-id", "1", "--limit", "0.40", "--shares", "10").stdout)
    b = json.loads(run("buy", "--token-id", "1", "--limit", "0.40", "--shares", "10").stdout)
    c = json.loads(run("buy", "--token-id", "1", "--limit", "0.41", "--shares", "10").stdout)
    assert a["confirm_token"] == b["confirm_token"]
    assert a["confirm_token"] != c["confirm_token"]


def test_confirm_token_binds_neg_risk_order_type_and_tick() -> None:
    """Flipping any execution parameter must change the confirm token."""
    base = json.loads(run("buy", "--token-id", "1", "--amount", "25").stdout)["confirm_token"]
    neg = json.loads(run("buy", "--token-id", "1", "--amount", "25", "--neg-risk").stdout)[
        "confirm_token"
    ]
    order_type = json.loads(
        run("buy", "--token-id", "1", "--amount", "25", "--order-type", "FAK").stdout
    )["confirm_token"]
    tick = json.loads(
        run("buy", "--token-id", "1", "--amount", "25", "--tick-size", "0.001").stdout
    )["confirm_token"]
    assert len({base, neg, order_type, tick}) == 4


def test_stale_token_cannot_execute_a_modified_order() -> None:
    """A dry-run token must not authorize a different (neg-risk) live order."""
    token = json.loads(run("buy", "--token-id", "1", "--amount", "25").stdout)["confirm_token"]
    result = run(
        "buy", "--token-id", "1", "--amount", "25", "--neg-risk", "--execute", "--confirm", token
    )
    assert result.returncode == 2
    assert json.loads(result.stdout)["mode"] == "blocked"


def test_non_positive_size_is_rejected() -> None:
    for args in (
        ("buy", "--token-id", "1", "--limit", "0.40", "--shares", "-5"),
        ("buy", "--token-id", "1", "--limit", "0.40", "--shares", "0"),
        ("buy", "--token-id", "1", "--amount", "-25"),
        ("buy", "--token-id", "1", "--amount", "0"),
    ):
        result = run(*args)
        assert result.returncode != 0, args
        assert "must be positive" in result.stderr, args


def test_cancel_requires_a_matching_confirm_token() -> None:
    dry = json.loads(run("cancel", "0xABC").stdout)
    assert dry["mode"] == "dry-run"
    assert dry["confirm_token"]

    blocked = run("cancel", "0xABC", "--execute")
    assert blocked.returncode == 2
    assert json.loads(blocked.stdout)["mode"] == "blocked"

    wrong = run("cancel", "0xABC", "--execute", "--confirm", "deadbeef00")
    assert wrong.returncode == 2
    assert json.loads(wrong.stdout)["mode"] == "blocked"

    # `--all` is bound to a distinct token from a specific order id.
    all_token = json.loads(run("cancel", "--all").stdout)["confirm_token"]
    assert all_token != dry["confirm_token"]


def test_malformed_chain_id_raises_clean_error(tmp_path, monkeypatch) -> None:
    import credentials as creds_mod

    monkeypatch.setenv("POLYMARKET_CHAIN_ID", "not-a-number")
    try:
        creds_mod.load_credentials()
    except creds_mod.CredentialError as exc:
        assert "chain_id" in str(exc)
    else:
        raise AssertionError("expected CredentialError for a malformed chain id")


def test_price_must_match_tick_size() -> None:
    result = run(
        "buy", "--token-id", "1", "--limit", "0.405", "--shares", "10", "--tick-size", "0.01"
    )
    assert result.returncode != 0
    assert "not a multiple" in result.stderr


def test_whoami_reports_presence_without_leaking_secrets(tmp_path: Path) -> None:
    secret_key = "0xPRIVATEKEYSECRETVALUE"
    secret_api = "supersecretapikeyvalue"
    cred = tmp_path / ".credentials"
    cred.write_text(
        "PRIVATE_KEY=" + secret_key + "\n"
        "PRIVATE_ADDRESS=0xPublicAddress\n"
        "API_KEY=" + secret_api + "\n"
        "SECRET=base64secret==\n"
        "PASSPHRASE=passphrasevalue\n",
        encoding="utf-8",
    )
    result = run("whoami", "--credentials-file", str(cred))
    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    assert payload["has_private_key"] is True
    assert payload["has_api_creds"] is True
    assert payload["address"] == "0xPublicAddress"
    # No secret value may appear anywhere in the output.
    assert secret_key not in result.stdout
    assert secret_api not in result.stdout
    assert "base64secret" not in result.stdout
    assert "passphrasevalue" not in result.stdout


def test_credentials_env_overrides_file(tmp_path, monkeypatch) -> None:
    import credentials as creds_mod

    cred = tmp_path / ".credentials"
    cred.write_text("PRIVATE_ADDRESS=0xFromFile\n", encoding="utf-8")
    monkeypatch.setenv("POLYMARKET_ADDRESS", "0xFromEnv")
    loaded = creds_mod.load_credentials(str(cred))
    assert loaded.address == "0xFromEnv"
    assert loaded.effective_funder == "0xFromEnv"
