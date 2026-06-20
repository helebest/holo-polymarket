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


def test_dry_run_preview_surfaces_funder_and_signature_type(tmp_path: Path) -> None:
    """Operators must see which wallet an order would use before executing."""
    cred = tmp_path / ".credentials"
    cred.write_text("FUNDER=0xProxyWallet\nSIGNATURE_TYPE=1\n", encoding="utf-8")
    payload = json.loads(
        run(
            "buy",
            "--token-id",
            "1",
            "--limit",
            "0.40",
            "--shares",
            "10",
            "--credentials-file",
            str(cred),
        ).stdout
    )
    assert payload["mode"] == "dry-run"
    assert payload["funder"] == "0xProxyWallet"
    assert payload["signature_type"] == 1


def test_dry_run_preview_works_without_any_credentials(tmp_path: Path) -> None:
    """A missing credentials file must never block a dry-run preview."""
    missing = tmp_path / "absent"
    payload = json.loads(
        run(
            "buy",
            "--token-id",
            "1",
            "--limit",
            "0.40",
            "--shares",
            "10",
            "--credentials-file",
            str(missing),
        ).stdout
    )
    assert payload["mode"] == "dry-run"
    assert "funder" not in payload  # nothing configured -> nothing surfaced


def test_positions_defaults_to_funder_not_signer(monkeypatch) -> None:
    """`positions` with no address must query the funder (proxy), not the EOA."""
    import types

    import trade as trade_mod

    captured: dict[str, str] = {}

    class _Resp:
        def raise_for_status(self) -> None:
            pass

        def json(self) -> list:
            return []

    def _get(url, params=None, timeout=None):
        captured.update(params or {})
        return _Resp()

    monkeypatch.setitem(
        sys.modules, "requests", types.SimpleNamespace(get=_get, RequestException=Exception)
    )
    # Funder (proxy) and a different signer EOA both present: the funder wins.
    monkeypatch.setenv("POLYMARKET_FUNDER", "0xProxyWallet")
    monkeypatch.setenv("POLYMARKET_ADDRESS", "0xSignerEOA")

    args = types.SimpleNamespace(address=None, credentials_file=None, limit=5)
    assert trade_mod._cmd_positions(args) == 0
    assert captured["user"] == "0xProxyWallet"


def _bare_adapter():
    """A ClobAdapter instance without running __init__ (no client package)."""
    import clob

    return clob.ClobAdapter.__new__(clob.ClobAdapter)


def test_list_orders_uses_get_open_orders() -> None:
    adapter = _bare_adapter()
    seen = {}

    class _Client:
        def get_open_orders(self, params=None):
            seen["called"] = "get_open_orders"
            return []

    class _Types:
        class OpenOrderParams:
            pass

    class _Creds:
        def require_api_creds(self):
            pass

    adapter._client, adapter._types, adapter._creds = _Client(), _Types, _Creds()
    assert adapter.list_orders() == []
    assert seen["called"] == "get_open_orders"


def test_cancel_uses_cancel_order_with_payload() -> None:
    adapter = _bare_adapter()
    seen = {}

    class _Payload:
        def __init__(self, orderID=None):
            self.orderID = orderID

    class _Client:
        def cancel_order(self, payload):
            seen["id"] = payload.orderID
            return {"canceled": payload.orderID}

    class _Types:
        OrderPayload = _Payload

    class _Creds:
        def require_signer(self):
            pass

    adapter._client, adapter._types, adapter._creds = _Client(), _Types, _Creds()
    assert adapter.cancel("0xABC")["canceled"] == "0xABC"
    assert seen["id"] == "0xABC"


def test_cancel_all_cancels_each_open_order_id() -> None:
    adapter = _bare_adapter()
    seen = {}

    class _Client:
        def get_open_orders(self, params=None):
            return [{"id": "a"}, {"id": "b"}]

        def cancel_orders(self, order_hashes):
            seen["hashes"] = order_hashes
            return {"canceled": order_hashes}

    class _Types:
        class OpenOrderParams:
            pass

    class _Creds:
        def require_signer(self):
            pass

        def require_api_creds(self):
            pass

    adapter._client, adapter._types, adapter._creds = _Client(), _Types, _Creds()
    assert adapter.cancel_all()["canceled"] == ["a", "b"]
    assert seen["hashes"] == ["a", "b"]


def test_execute_failure_is_clean_error_not_traceback(tmp_path, monkeypatch, capsys) -> None:
    """An exchange/client error during --execute must yield mode:error, not a traceback."""
    import types

    import trade as trade_mod

    cred = tmp_path / ".credentials"
    cred.write_text(
        "POLYMARKET_PRIVATE_KEY=0xPRIVKEY123\nPOLYMARKET_API_KEY=APIKEY123\n"
        "POLYMARKET_API_SECRET=APISECRET123\nPOLYMARKET_API_PASSPHRASE=PASSPHRASE123\n",
        encoding="utf-8",
    )
    base = dict(
        token_id="1",
        market=None,
        outcome=None,
        amount=25.0,
        shares=None,
        limit=None,
        order_type=None,
        tick_size=None,
        neg_risk=False,
        credentials_file=str(cred),
    )
    # Obtain the matching confirm token from a dry-run.
    trade_mod._cmd_order(types.SimpleNamespace(execute=False, confirm=None, **base), "BUY")
    token = json.loads(capsys.readouterr().out)["confirm_token"]

    class _Adapter:
        def __init__(self, creds):
            pass

        def place_market_order(self, *a, **k):
            raise RuntimeError("Unauthorized/Invalid api key")

    monkeypatch.setitem(
        sys.modules, "clob", types.SimpleNamespace(ClobAdapter=_Adapter, ClobError=Exception)
    )
    rc = trade_mod._cmd_order(types.SimpleNamespace(execute=True, confirm=token, **base), "BUY")
    out = json.loads(capsys.readouterr().out)
    assert rc == 1
    assert out["mode"] == "error"
    assert "Invalid api key" in out["error"]


def test_live_order_refused_when_funder_is_bare_eoa_with_proxy_sig_type(tmp_path: Path) -> None:
    """A proxy wallet type whose funder defaulted to the signer EOA must warn and refuse.

    signature_type=1 (email/Magic) keeps funds in a proxy, but here only the EOA
    address is configured, so funder resolves to the bare signer. Executing would
    target an empty wallet, so the dry-run warns and --execute is blocked.
    """
    cred = tmp_path / ".credentials"
    cred.write_text("POLYMARKET_ADDRESS=0xSignerEOA\nSIGNATURE_TYPE=1\n", encoding="utf-8")
    args = ["buy", "--token-id", "1", "--amount", "25", "--credentials-file", str(cred)]
    dry = json.loads(run(*args).stdout)
    assert dry["mode"] == "dry-run"
    assert any("proxy wallet" in w for w in dry["warnings"])

    # Even with the correct confirm token, execution is refused — nothing is sent.
    res = run(*args, "--execute", "--confirm", dry["confirm_token"])
    assert res.returncode == 2
    assert json.loads(res.stdout)["mode"] == "blocked"


def test_no_funder_footgun_when_proxy_differs_from_signer(tmp_path: Path) -> None:
    """A correctly-configured proxy funder (distinct from the signer EOA) raises no warning."""
    cred = tmp_path / ".credentials"
    cred.write_text(
        "POLYMARKET_ADDRESS=0xSignerEOA\nFUNDER=0xProxyWallet\nSIGNATURE_TYPE=1\n",
        encoding="utf-8",
    )
    dry = json.loads(
        run("buy", "--token-id", "1", "--amount", "25", "--credentials-file", str(cred)).stdout
    )
    assert dry["mode"] == "dry-run"
    assert not any("proxy wallet" in w for w in dry["warnings"])
