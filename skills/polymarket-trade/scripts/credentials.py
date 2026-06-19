"""Agent-neutral credential loading for Polymarket trading.

Credentials are resolved in priority order:

1. Process environment variables (``POLYMARKET_*`` preferred; ``PK`` / ``CLOB_*``
   accepted as aliases used by Polymarket's own examples).
2. The file named by ``$POLYMARKET_CREDENTIALS_FILE`` (used exclusively when set).
3. ``./.credentials`` in the current working directory (should be gitignored).
4. ``~/.config/holo-polymarket/credentials``
5. ``~/.openclaw/credentials/polymarket_credentials`` (legacy fallback).

The credentials file is a simple ``KEY=VALUE`` text file (``#`` comments and blank
lines ignored). Recognised keys (case-insensitive) and their aliases:

================  ===========================================  =========================================
Field             Keys accepted                                Meaning
================  ===========================================  =========================================
private_key       PRIVATE_KEY, PK                              EOA private key (hex, ``0x...``)
address           PRIVATE_ADDRESS, ADDRESS, WALLET_ADDRESS     EOA address (``0x...``)
api_key           API_KEY, CLOB_API_KEY                        CLOB L2 API key
api_secret        SECRET, API_SECRET, CLOB_SECRET              CLOB L2 API secret
api_passphrase    PASSPHRASE, API_PASSPHRASE, CLOB_PASS_PHRASE CLOB L2 API passphrase
funder            FUNDER, POLYMARKET_FUNDER                    Funding wallet; defaults to ``address``
signature_type    SIGNATURE_TYPE, POLYMARKET_SIGNATURE_TYPE    0 EOA, 1 email/Magic, 2 browser, 3 deposit
================  ===========================================  =========================================

This module never prints secret values. ``Credentials.redacted()`` returns a
diagnostics dict that only reports which fields are present.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

DEFAULT_HOST = "https://clob.polymarket.com"
DEFAULT_CHAIN_ID = 137  # Polygon

# Each logical field maps to the env vars / file keys that can supply it,
# in priority order. Lookups are case-insensitive for file keys.
_FIELD_ALIASES: dict[str, tuple[str, ...]] = {
    "private_key": ("POLYMARKET_PRIVATE_KEY", "PRIVATE_KEY", "PK"),
    "address": ("POLYMARKET_ADDRESS", "PRIVATE_ADDRESS", "ADDRESS", "WALLET_ADDRESS"),
    "api_key": ("POLYMARKET_API_KEY", "API_KEY", "CLOB_API_KEY"),
    "api_secret": ("POLYMARKET_API_SECRET", "SECRET", "API_SECRET", "CLOB_SECRET"),
    "api_passphrase": (
        "POLYMARKET_API_PASSPHRASE",
        "PASSPHRASE",
        "API_PASSPHRASE",
        "CLOB_PASS_PHRASE",
    ),
    "funder": ("POLYMARKET_FUNDER", "FUNDER"),
    "signature_type": ("POLYMARKET_SIGNATURE_TYPE", "SIGNATURE_TYPE"),
}

_CANDIDATE_FILES = (
    "./.credentials",
    "~/.config/holo-polymarket/credentials",
    "~/.openclaw/credentials/polymarket_credentials",
)


class CredentialError(Exception):
    """Raised when required credentials are missing or malformed."""


@dataclass
class Credentials:
    """Resolved Polymarket trading credentials.

    Read-only commands (market data, price previews) need none of these.
    Account reads (balances, open orders) need the L2 API creds. Placing or
    cancelling orders needs the private key as well.
    """

    private_key: str | None = None
    address: str | None = None
    api_key: str | None = None
    api_secret: str | None = None
    api_passphrase: str | None = None
    funder: str | None = None
    signature_type: int = 0
    host: str = DEFAULT_HOST
    chain_id: int = DEFAULT_CHAIN_ID
    source: str = "none"
    _present: set[str] = field(default_factory=set, repr=False)

    @property
    def effective_funder(self) -> str | None:
        """The funding wallet: explicit ``funder`` or the signer address."""
        return self.funder or self.address

    def has_api_creds(self) -> bool:
        return bool(self.api_key and self.api_secret and self.api_passphrase)

    def has_signer(self) -> bool:
        return bool(self.private_key)

    def require_signer(self) -> None:
        if not self.has_signer():
            raise CredentialError(
                "No private key found. Set POLYMARKET_PRIVATE_KEY or add "
                "PRIVATE_KEY to your credentials file (see references/credentials.md)."
            )

    def require_api_creds(self) -> None:
        if not self.has_api_creds():
            raise CredentialError(
                "Missing CLOB API credentials (API_KEY / SECRET / PASSPHRASE). "
                "See references/credentials.md."
            )

    def redacted(self) -> dict[str, object]:
        """Diagnostics that never expose secret values."""
        return {
            "source": self.source,
            "host": self.host,
            "chain_id": self.chain_id,
            "signature_type": self.signature_type,
            "address": self.address,
            "funder": self.effective_funder,
            "has_private_key": self.has_signer(),
            "has_api_creds": self.has_api_creds(),
            "present_fields": sorted(self._present),
        }


def _parse_kv_file(path: Path) -> dict[str, str]:
    data: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        data[key.strip().upper()] = value.strip().strip('"').strip("'")
    return data


def resolve_credentials_file(explicit: str | None = None) -> Path | None:
    """Return the credentials file to use, or ``None`` if env-only.

    When ``explicit`` or ``$POLYMARKET_CREDENTIALS_FILE`` is set, that path is
    used exclusively (even if it does not exist). Otherwise the first existing
    candidate is returned.
    """
    chosen = explicit or os.environ.get("POLYMARKET_CREDENTIALS_FILE")
    if chosen:
        return Path(chosen).expanduser()
    for candidate in _CANDIDATE_FILES:
        path = Path(candidate).expanduser()
        if path.is_file():
            return path
    return None


def load_credentials(explicit_file: str | None = None) -> Credentials:
    """Load credentials from the environment and the resolved credentials file.

    Environment variables always win over file values. Missing fields are left
    as ``None`` rather than raising; callers enforce what they actually need via
    :meth:`Credentials.require_signer` / :meth:`Credentials.require_api_creds`.
    """
    file_values: dict[str, str] = {}
    source = "env"
    cred_file = resolve_credentials_file(explicit_file)
    if cred_file and cred_file.is_file():
        file_values = _parse_kv_file(cred_file)
        source = str(cred_file)

    present: set[str] = set()

    def pick(field_name: str) -> str | None:
        for alias in _FIELD_ALIASES[field_name]:
            # Env vars are matched exactly; file keys are upper-cased on load.
            if alias in os.environ and os.environ[alias].strip():
                present.add(field_name)
                return os.environ[alias].strip()
            if alias.upper() in file_values and file_values[alias.upper()]:
                present.add(field_name)
                return file_values[alias.upper()]
        return None

    raw_sig = pick("signature_type")
    try:
        signature_type = int(raw_sig) if raw_sig is not None else _default_signature_type()
    except ValueError as exc:
        raise CredentialError(f"signature_type must be an integer, got {raw_sig!r}") from exc

    raw_chain = os.environ.get("POLYMARKET_CHAIN_ID")
    try:
        chain_id = int(raw_chain) if raw_chain is not None else DEFAULT_CHAIN_ID
    except ValueError as exc:
        raise CredentialError(f"chain_id must be an integer, got {raw_chain!r}") from exc

    creds = Credentials(
        private_key=pick("private_key"),
        address=pick("address"),
        api_key=pick("api_key"),
        api_secret=pick("api_secret"),
        api_passphrase=pick("api_passphrase"),
        funder=pick("funder"),
        signature_type=signature_type,
        host=os.environ.get("POLYMARKET_CLOB_HOST", DEFAULT_HOST).rstrip("/"),
        chain_id=chain_id,
        source=source if (file_values or _any_env_present()) else "none",
        _present=present,
    )
    return creds


def _default_signature_type() -> int:
    return 0


def _any_env_present() -> bool:
    for aliases in _FIELD_ALIASES.values():
        for alias in aliases:
            if os.environ.get(alias, "").strip():
                return True
    return False
