"""Repository validation for the canonical holo-polymarket skills.

Enforces the cross-runtime invariants that let one repo serve Claude Code,
Codex, OpenClaw, and Hermes from a single canonical ``skills/`` directory.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKILLS_DIR = ROOT / "skills"
PLUGIN_NAME = "holo-polymarket"
PLUGIN_ROOT = ROOT / "plugins" / PLUGIN_NAME
PLUGIN_SKILLS_DIR = PLUGIN_ROOT / "skills"
CODEX_PLUGIN_MANIFEST = PLUGIN_ROOT / ".codex-plugin" / "plugin.json"
CLAUDE_PLUGIN_MANIFEST = PLUGIN_ROOT / ".claude-plugin" / "plugin.json"
OPENCLAW_PLUGIN_MANIFEST = PLUGIN_ROOT / "openclaw.plugin.json"
MARKETPLACE_PATH = ROOT / ".agents" / "plugins" / "marketplace.json"
CLAUDE_MARKETPLACE_PATH = ROOT / ".claude-plugin" / "marketplace.json"
MARKETPLACE_NAME = "holo-polymarket"
OWNER_NAME = "holo"
CATEGORY = "Finance"
SKILL_NAMES = [
    "polymarket-query",
    "polymarket-trade",
]
BANNED_NAMES = {
    ".credentials",
    ".env",
    ".venv",
    "CHANGELOG.md",
    "README.md",
    "dist",
    "pyproject.toml",
    "uv.lock",
}
NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


class ValidationError(Exception):
    """Raised when repository validation fails."""


def load_json(path: Path) -> dict:
    if not path.exists():
        raise ValidationError(f"Missing {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def project_version() -> str:
    text = (ROOT / "pyproject.toml").read_text(encoding="utf-8")
    match = re.search(r'^version\s*=\s*"([^"]+)"', text, flags=re.MULTILINE)
    if match is None:
        raise ValidationError("pyproject.toml is missing project version")
    return match.group(1)


def parse_frontmatter(path: Path) -> dict[str, str]:
    """Parse top-level YAML frontmatter keys (indented/nested keys are ignored)."""
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        raise ValidationError(f"{path} is missing YAML frontmatter")
    end = text.find("\n---", 4)
    if end == -1:
        raise ValidationError(f"{path} has unterminated YAML frontmatter")

    data: dict[str, str] = {}
    for line in text[4:end].splitlines():
        if not line.strip() or line[0] in (" ", "\t", "#", "-"):
            # blank, indented (nested), comment, or list item
            continue
        if ":" not in line:
            raise ValidationError(f"{path} has invalid frontmatter line: {line}")
        key, value = line.split(":", 1)
        data[key.strip()] = value.strip().strip('"').strip("'")
    return data


def _has_python_scripts(scripts_dir: Path) -> bool:
    return any(scripts_dir.glob("*.py"))


def validate_skill(skill_dir: Path) -> None:
    name = skill_dir.name
    if not NAME_RE.match(name):
        raise ValidationError(f"Invalid skill directory name: {name}")

    skill_md = skill_dir / "SKILL.md"
    if not skill_md.exists():
        raise ValidationError(f"Missing {skill_md}")

    frontmatter = parse_frontmatter(skill_md)
    if frontmatter.get("name") != name:
        raise ValidationError(f"{skill_md} name must match directory name")
    if not frontmatter.get("description"):
        raise ValidationError(f"{skill_md} description is required")

    # Language-aware: only skills that ship Python scripts require requirements.txt.
    scripts_dir = skill_dir / "scripts"
    if scripts_dir.is_dir() and _has_python_scripts(scripts_dir):
        if not (scripts_dir / "requirements.txt").exists():
            raise ValidationError(f"{scripts_dir} ships Python and must contain requirements.txt")

    for path in skill_dir.rglob("*"):
        if path.name in BANNED_NAMES:
            raise ValidationError(f"Banned file or directory in skill package: {path}")


def validate_plugin_manifests() -> None:
    legacy_manifests = [
        ROOT / ".claude-plugin" / "plugin.json",
        ROOT / ".codex-plugin" / "plugin.json",
        ROOT / "openclaw.plugin.json",
    ]
    for manifest in legacy_manifests:
        if manifest.exists():
            raise ValidationError(f"{manifest} is a legacy root plugin manifest; use {PLUGIN_ROOT}")

    version = project_version()
    expected = {
        CLAUDE_PLUGIN_MANIFEST: "./skills/",
        CODEX_PLUGIN_MANIFEST: "./skills/",
        OPENCLAW_PLUGIN_MANIFEST: ["./skills"],
    }
    for manifest, expected_skills in expected.items():
        data = load_json(manifest)
        if data.get("name") != PLUGIN_NAME:
            raise ValidationError(f"{manifest} name must be {PLUGIN_NAME}")
        if data.get("version") != version:
            raise ValidationError(f"{manifest} version must match pyproject.toml")
        if data.get("skills") != expected_skills:
            raise ValidationError(f"{manifest} skills must be {expected_skills!r}")

    codex_display = load_json(CODEX_PLUGIN_MANIFEST).get("interface", {}).get("displayName")
    if codex_display != PLUGIN_NAME:
        raise ValidationError(
            f"{CODEX_PLUGIN_MANIFEST} interface.displayName must equal {PLUGIN_NAME!r}"
        )


def validate_marketplace() -> None:
    payload = load_json(MARKETPLACE_PATH)
    plugins = payload.get("plugins")
    if not isinstance(plugins, list):
        raise ValidationError(f"{MARKETPLACE_PATH} plugins must be an array")

    matches = [
        entry for entry in plugins if isinstance(entry, dict) and entry.get("name") == PLUGIN_NAME
    ]
    if len(matches) != 1:
        raise ValidationError(f"{MARKETPLACE_PATH} must contain exactly one {PLUGIN_NAME} entry")

    entry = matches[0]
    if entry.get("source") != {"source": "local", "path": f"./plugins/{PLUGIN_NAME}"}:
        raise ValidationError(f"{MARKETPLACE_PATH} has invalid source for {PLUGIN_NAME}")
    if entry.get("policy") != {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL",
    }:
        raise ValidationError(f"{MARKETPLACE_PATH} has invalid policy for {PLUGIN_NAME}")
    if entry.get("category") != CATEGORY:
        raise ValidationError(f"{MARKETPLACE_PATH} category must be {CATEGORY}")

    display = payload.get("interface", {}).get("displayName")
    if display != PLUGIN_NAME:
        raise ValidationError(
            f"{MARKETPLACE_PATH} interface.displayName must equal {PLUGIN_NAME!r}"
        )


def validate_claude_marketplace() -> None:
    payload = load_json(CLAUDE_MARKETPLACE_PATH)
    version = project_version()

    if payload.get("name") != MARKETPLACE_NAME:
        raise ValidationError(f"{CLAUDE_MARKETPLACE_PATH} name must be {MARKETPLACE_NAME!r}")
    if payload.get("owner", {}).get("name") != OWNER_NAME:
        raise ValidationError(f"{CLAUDE_MARKETPLACE_PATH} owner.name must be {OWNER_NAME!r}")
    if payload.get("metadata", {}).get("version") != version:
        raise ValidationError(
            f"{CLAUDE_MARKETPLACE_PATH} metadata.version must match pyproject.toml"
        )

    plugins = payload.get("plugins")
    if not isinstance(plugins, list) or len(plugins) != 1:
        raise ValidationError(f"{CLAUDE_MARKETPLACE_PATH} plugins must contain exactly one entry")

    entry = plugins[0]
    if entry.get("name") != PLUGIN_NAME:
        raise ValidationError(f"{CLAUDE_MARKETPLACE_PATH} plugin name must be {PLUGIN_NAME!r}")
    if entry.get("source") != f"./plugins/{PLUGIN_NAME}":
        raise ValidationError(
            f"{CLAUDE_MARKETPLACE_PATH} plugin source must be the string "
            f"'./plugins/{PLUGIN_NAME}' (Claude Code rejects object sources for local plugins)"
        )
    if not isinstance(entry.get("source"), str):
        raise ValidationError(f"{CLAUDE_MARKETPLACE_PATH} plugin source must be a string")
    if entry.get("version") != version:
        raise ValidationError(f"{CLAUDE_MARKETPLACE_PATH} plugin version must match pyproject.toml")


def validate_generated_plugin_skills() -> None:
    if not PLUGIN_SKILLS_DIR.exists():
        raise ValidationError(
            f"Missing generated plugin skills directory: {PLUGIN_SKILLS_DIR}. "
            "Run `holo-polymarket-sync-plugin` to regenerate it."
        )

    actual = sorted(path.name for path in PLUGIN_SKILLS_DIR.iterdir() if path.is_dir())
    if actual != sorted(SKILL_NAMES):
        raise ValidationError(f"Unexpected generated plugin skills: {actual}")
    for skill_name in SKILL_NAMES:
        validate_skill(PLUGIN_SKILLS_DIR / skill_name)

    # Detect content drift, not just structural drift, so the single `validate`
    # command catches a stale generated copy. Imported locally to avoid a cycle
    # (sync_plugin imports from this module).
    from holo_polymarket.sync_plugin import compare_skill_trees

    differences = compare_skill_trees(SKILLS_DIR, PLUGIN_SKILLS_DIR)
    if differences:
        raise ValidationError(
            "Generated plugin skills are out of sync with canonical skills "
            f"(run `holo-polymarket-sync-plugin`): {differences}"
        )


def validate_all() -> None:
    if not SKILLS_DIR.exists():
        raise ValidationError("Missing skills directory")

    actual = sorted(path.name for path in SKILLS_DIR.iterdir() if path.is_dir())
    if actual != sorted(SKILL_NAMES):
        raise ValidationError(f"Unexpected skills: {actual}")

    for skill_name in SKILL_NAMES:
        validate_skill(SKILLS_DIR / skill_name)

    validate_plugin_manifests()
    validate_marketplace()
    validate_claude_marketplace()
    validate_generated_plugin_skills()


def main() -> int:
    try:
        validate_all()
    except Exception as exc:  # noqa: BLE001 - top-level CLI guard
        print(f"validation failed: {exc}", file=sys.stderr)
        return 1
    print("validation ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
