from __future__ import annotations

import json
import re
import subprocess
import sys
import zipfile
from pathlib import Path

from holo_polymarket.build import build
from holo_polymarket.sync_plugin import compare_skill_trees, sync_plugin_skills
from holo_polymarket.validate import (
    CLAUDE_MARKETPLACE_PATH,
    CLAUDE_PLUGIN_MANIFEST,
    CODEX_PLUGIN_MANIFEST,
    MARKETPLACE_NAME,
    MARKETPLACE_PATH,
    OPENCLAW_PLUGIN_MANIFEST,
    OWNER_NAME,
    PLUGIN_NAME,
    PLUGIN_SKILLS_DIR,
    ROOT,
    SKILL_NAMES,
    SKILLS_DIR,
    validate_all,
)

DIGEST_RE = re.compile(r"^sha256:[0-9a-f]{64}$")


def project_version() -> str:
    match = re.search(
        r'^version\s*=\s*"([^"]+)"',
        (ROOT / "pyproject.toml").read_text(encoding="utf-8"),
        flags=re.MULTILINE,
    )
    assert match is not None
    return match.group(1)


def test_skills_validate() -> None:
    validate_all()


def test_trade_cli_shows_help() -> None:
    script = ROOT / "skills/polymarket-trade/scripts/trade.py"
    result = subprocess.run(
        [sys.executable, str(script), "--help"], text=True, capture_output=True, check=False
    )
    assert result.returncode == 0, result.stderr
    assert "usage:" in result.stdout


def test_docs_are_english_only() -> None:
    """All tracked Markdown docs and skill SKILL.md files must be English (no CJK)."""
    han = re.compile(f"[{chr(0x4E00)}-{chr(0x9FFF)}]")  # CJK Unified Ideographs
    md_files = [p for p in ROOT.rglob("*.md") if ".git" not in p.parts and "dist" not in p.parts]
    offenders = [str(p.relative_to(ROOT)) for p in md_files if han.search(p.read_text("utf-8"))]
    assert not offenders, f"Chinese text found in docs: {offenders}"


def test_plugin_manifest_versions_match_project_version() -> None:
    version = project_version()
    for manifest in (CLAUDE_PLUGIN_MANIFEST, CODEX_PLUGIN_MANIFEST, OPENCLAW_PLUGIN_MANIFEST):
        data = json.loads(manifest.read_text(encoding="utf-8"))
        assert data["name"] == PLUGIN_NAME
        assert data["version"] == version


def test_plugin_wrapper_and_codex_marketplace_are_valid() -> None:
    assert not (ROOT / ".claude-plugin/plugin.json").exists()
    assert not (ROOT / ".codex-plugin/plugin.json").exists()
    assert not (ROOT / "openclaw.plugin.json").exists()

    codex = json.loads(CODEX_PLUGIN_MANIFEST.read_text(encoding="utf-8"))
    claude = json.loads(CLAUDE_PLUGIN_MANIFEST.read_text(encoding="utf-8"))
    openclaw = json.loads(OPENCLAW_PLUGIN_MANIFEST.read_text(encoding="utf-8"))
    marketplace = json.loads(MARKETPLACE_PATH.read_text(encoding="utf-8"))

    assert codex["skills"] == "./skills/"
    assert claude["skills"] == "./skills/"
    assert openclaw["skills"] == ["./skills"]

    assert marketplace["plugins"] == [
        {
            "name": PLUGIN_NAME,
            "source": {"source": "local", "path": f"./plugins/{PLUGIN_NAME}"},
            "policy": {"installation": "AVAILABLE", "authentication": "ON_INSTALL"},
            "category": "Finance",
        }
    ]
    assert marketplace["interface"]["displayName"] == PLUGIN_NAME
    assert codex["interface"]["displayName"] == PLUGIN_NAME


def test_claude_marketplace_uses_string_source_and_matches_version() -> None:
    assert CLAUDE_MARKETPLACE_PATH.exists()
    payload = json.loads(CLAUDE_MARKETPLACE_PATH.read_text(encoding="utf-8"))

    assert payload["name"] == MARKETPLACE_NAME
    assert payload["owner"]["name"] == OWNER_NAME
    assert payload["metadata"]["version"] == project_version()

    plugins = payload["plugins"]
    assert len(plugins) == 1
    entry = plugins[0]
    assert entry["name"] == PLUGIN_NAME
    assert entry["source"] == f"./plugins/{PLUGIN_NAME}"
    assert isinstance(entry["source"], str), "Claude Code rejects object source for local plugins"
    assert entry["version"] == project_version()


def test_generated_plugin_skills_in_sync(tmp_path: Path) -> None:
    gitignore = (ROOT / ".gitignore").read_text(encoding="utf-8")
    assert f"plugins/{PLUGIN_NAME}/skills/" not in gitignore

    assert compare_skill_trees(SKILLS_DIR, PLUGIN_SKILLS_DIR) == []

    generated = sync_plugin_skills(tmp_path / "skills")
    assert compare_skill_trees(SKILLS_DIR, generated) == []
    for skill_name in SKILL_NAMES:
        assert (generated / skill_name / "SKILL.md").exists()


def test_build_outputs_are_generated_from_canonical_skills() -> None:
    artifacts = build(clean=True)
    artifact_names = {path.relative_to(ROOT / "dist").as_posix() for path in artifacts}

    for skill_name in SKILL_NAMES:
        assert f"skills/{skill_name}.zip" in artifact_names
        with zipfile.ZipFile(ROOT / "dist" / "skills" / f"{skill_name}.zip") as archive:
            names = archive.namelist()
        assert f"{skill_name}/SKILL.md" in names
        assert not any("/pyproject.toml" in name for name in names)
        assert not any(".credentials" in name for name in names)

    plugin_artifacts = {
        f"plugins/claude-{PLUGIN_NAME}-plugin.zip": ".claude-plugin/plugin.json",
        f"plugins/codex-{PLUGIN_NAME}-plugin.zip": ".codex-plugin/plugin.json",
        f"plugins/openclaw-{PLUGIN_NAME}-plugin.zip": "openclaw.plugin.json",
    }
    for artifact_name, manifest_path in plugin_artifacts.items():
        assert artifact_name in artifact_names
        with zipfile.ZipFile(ROOT / "dist" / artifact_name) as archive:
            names = archive.namelist()
        assert manifest_path in names
        for skill_name in SKILL_NAMES:
            assert f"skills/{skill_name}/SKILL.md" in names
        assert not any(name.startswith("src/") for name in names)
        assert not any(name.startswith("tests/") for name in names)

    for relative in (
        "site/.well-known/agent-skills/index.json",
        "site/.well-known/skills/index.json",
    ):
        assert relative in artifact_names
        payload = json.loads((ROOT / "dist" / relative).read_text(encoding="utf-8"))
        assert [skill["name"] for skill in payload["skills"]] == SKILL_NAMES
        for skill in payload["skills"]:
            # AgentSkills 0.2.0 requires name/type/description/url/digest per skill.
            assert {"name", "type", "description", "url", "digest"} <= set(skill)
            assert DIGEST_RE.match(skill["digest"]), skill["digest"]

    assert (ROOT / "dist/checksums.txt").exists()
