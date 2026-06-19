"""Live CLOB adapter built on the official Polymarket Python client.

This module is imported ONLY when actually placing/cancelling orders or reading
account state through the signed client. Read-only market data and dry-run
previews never import it, so the rest of the skill works with no third-party
packages installed.

Library note (2026): Polymarket migrated to CLOB **V2** on 2026-04-28. The
legacy ``py-clob-client`` (v1) is archived and rejected by the production
exchange. This adapter targets ``py-clob-client-v2`` but resolves method names
defensively (falling back to v1 names) so it tolerates API drift between
versions. Because the live trading surface is still stabilising upstream, treat
live execution as best-effort and rely on the dry-run preview first.
"""

from __future__ import annotations

import importlib
from typing import Any

# Candidate package roots, newest first.
_PACKAGE_ROOTS = ("py_clob_client_v2", "py_clob_client")


class ClobError(Exception):
    """Raised when the CLOB client is unavailable or a live call fails."""


def _import_first(submodule: str):
    """Import ``<root>.<submodule>`` for the first available package root."""
    last_exc: Exception | None = None
    for root in _PACKAGE_ROOTS:
        try:
            return importlib.import_module(f"{root}.{submodule}"), root
        except ImportError as exc:  # try the next root
            last_exc = exc
    raise ClobError(
        "No Polymarket CLOB client installed. Install it with:\n"
        "    pip install py-clob-client-v2\n"
        "(needed only for live order placement / account reads; market data and "
        "dry-run previews do not require it)."
    ) from last_exc


def _import_optional(name: str):
    """Import ``<root>.<name>`` (or top-level ``<root>``) without raising.

    Returns ``(module, root)`` for the first package root that imports, else
    ``(None, None)``. Unlike :func:`_import_first` this never aborts, so an
    optional submodule that a client version dropped does not break startup.
    """
    for root in _PACKAGE_ROOTS:
        target = root if name == root else f"{root}.{name}"
        try:
            return importlib.import_module(target), root
        except ImportError:
            continue
    return None, None


def _first_method(obj: Any, *names: str):
    """Return the first attribute present on ``obj`` from ``names``."""
    for name in names:
        method = getattr(obj, name, None)
        if callable(method):
            return method, name
    return None, None


class ClobAdapter:
    """Thin wrapper over the CLOB client with version-tolerant method dispatch."""

    def __init__(self, creds) -> None:
        self._creds = creds
        client_mod, root = _import_first("client")
        types_mod, _ = _import_first("clob_types")
        self._root = root
        self._types = types_mod
        self.BUY, self.SELL = self._resolve_sides(root, types_mod)

        api_creds = None
        if creds.has_api_creds():
            api_creds = types_mod.ApiCreds(
                api_key=creds.api_key,
                api_secret=creds.api_secret,
                api_passphrase=creds.api_passphrase,
            )

        client_cls = client_mod.ClobClient
        kwargs: dict[str, Any] = {
            "key": creds.private_key,
            "chain_id": creds.chain_id,
            "signature_type": creds.signature_type,
        }
        if api_creds is not None:
            kwargs["creds"] = api_creds
        if creds.effective_funder:
            kwargs["funder"] = creds.effective_funder
        try:
            self._client = client_cls(creds.host, **kwargs)
        except Exception as exc:  # noqa: BLE001 - surface any construction failure
            raise ClobError(f"failed to construct CLOB client: {exc}") from exc

        # Upgrade to L2 if we were not given API creds but have a signer.
        if api_creds is None and creds.has_signer():
            derive, _ = _first_method(
                self._client, "create_or_derive_api_creds", "create_or_derive_api_key"
            )
            setter, _ = _first_method(self._client, "set_api_creds", "set_api_key")
            if derive and setter:
                setter(derive())

    # -- order options ----------------------------------------------------
    def _order_options(self, tick_size: float, neg_risk: bool):
        opts_cls = getattr(self._types, "PartialCreateOrderOptions", None)
        if opts_cls is None:
            return None
        try:
            return opts_cls(tick_size=str(tick_size), neg_risk=neg_risk)
        except TypeError:
            return opts_cls(tick_size=str(tick_size))

    def _order_type(self, name: str):
        order_type = getattr(self._types, "OrderType", None)
        if order_type is None:
            return name
        return getattr(order_type, name, name)

    @staticmethod
    def _resolve_sides(root, types_mod):
        """Resolve BUY/SELL side constants tolerantly across client versions.

        Order of preference: (1) the v1 ``order_builder.constants`` BUY/SELL
        strings, (2) a ``Side`` enum (``Side.BUY``/``Side.SELL``) exported by
        the top-level v2 package or ``clob_types``, and (3) the literal strings
        ``"BUY"``/``"SELL"``. A missing ``order_builder.constants`` submodule
        (dropped in v2) must NOT abort construction.
        """
        const_mod, _ = _import_optional("order_builder.constants")
        pkg_mod, _ = _import_optional(root)
        for module in (const_mod, pkg_mod, types_mod):
            if module is None:
                continue
            buy = getattr(module, "BUY", None)
            sell = getattr(module, "SELL", None)
            if buy is not None and sell is not None:
                return buy, sell
            side = getattr(module, "Side", None)
            if side is not None and hasattr(side, "BUY") and hasattr(side, "SELL"):
                return side.BUY, side.SELL
        return "BUY", "SELL"

    def _side(self, side: str):
        return self.BUY if side.upper() == "BUY" else self.SELL

    # -- live operations --------------------------------------------------
    def place_limit_order(
        self,
        token_id: str,
        price: float,
        size: float,
        side: str,
        tick_size: float,
        neg_risk: bool,
        order_type: str = "GTC",
    ) -> dict:
        self._creds.require_signer()
        args = self._types.OrderArgs(
            token_id=token_id, price=price, size=size, side=self._side(side)
        )
        options = self._order_options(tick_size, neg_risk)
        ot = self._order_type(order_type)
        # v2 combined call first, else v1 create_order + post_order.
        combined, _ = _first_method(self._client, "create_and_post_order")
        if combined:
            return self._call_with_options(combined, args, options, ot)
        signed = (
            self._client.create_order(args, options) if options else self._client.create_order(args)
        )
        return self._client.post_order(signed, ot)

    def place_market_order(
        self,
        token_id: str,
        amount: float,
        side: str,
        tick_size: float,
        neg_risk: bool,
        price: float = 0.0,
        order_type: str = "FOK",
    ) -> dict:
        self._creds.require_signer()
        margs = self._types.MarketOrderArgs(token_id=token_id, amount=amount, side=self._side(side))
        if price:
            setattr(margs, "price", price)
        options = self._order_options(tick_size, neg_risk)
        ot = self._order_type(order_type)
        combined, _ = _first_method(self._client, "create_and_post_market_order")
        if combined:
            return self._call_with_options(combined, margs, options, ot)
        signed = (
            self._client.create_market_order(margs, options)
            if options
            else self._client.create_market_order(margs)
        )
        return self._client.post_order(signed, ot)

    @staticmethod
    def _call_with_options(method, args, options, order_type):
        """Call a combined create+post method tolerating signature variants."""
        attempts = (
            lambda: method(args, options=options, order_type=order_type),
            lambda: method(args, order_type=order_type),
            lambda: method(args, options),
            lambda: method(args),
        )
        last_exc: Exception | None = None
        for attempt in attempts:
            try:
                return attempt()
            except TypeError as exc:
                last_exc = exc
        raise ClobError(f"could not invoke order method: {last_exc}")

    def cancel(self, order_id: str) -> dict:
        self._creds.require_signer()
        return self._client.cancel(order_id)

    def cancel_all(self) -> dict:
        self._creds.require_signer()
        return self._client.cancel_all()

    def list_orders(self) -> list:
        self._creds.require_api_creds()
        method, _ = _first_method(self._client, "get_orders")
        if not method:
            raise ClobError("client has no get_orders method")
        params_cls = getattr(self._types, "OpenOrderParams", None)
        return method(params_cls()) if params_cls else method()

    def balance(self, asset_type: str = "COLLATERAL", token_id: str | None = None) -> dict:
        self._creds.require_api_creds()
        params_cls = getattr(self._types, "BalanceAllowanceParams", None)
        asset_enum = getattr(self._types, "AssetType", None)
        method, _ = _first_method(self._client, "get_balance_allowance")
        if not (params_cls and method):
            raise ClobError("client has no balance/allowance support")
        at = getattr(asset_enum, asset_type, asset_type) if asset_enum else asset_type
        params = (
            params_cls(asset_type=at, token_id=token_id) if token_id else params_cls(asset_type=at)
        )
        return method(params)
