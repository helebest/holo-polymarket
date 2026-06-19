# Hermes distribution

Hermes consumes the canonical `skills/` directory directly, so it does not depend
on the Codex/Claude plugin wrapper. The root `skills/` directory is the single
source of truth.

Recommended options:

1. Register this repository's `skills/` directory in `~/.hermes/config.yaml` as an
   external skill directory:

   ```yaml
   skills:
     external_dirs:
       - ${HOLO_POLYMARKET_REPO}/skills
   ```

   External directories are scanned for discovery; Hermes writes new/edited
   skills to `~/.hermes/skills/`, and a local skill of the same name shadows the
   external copy.

2. Install from a GitHub path once the repository is published.

3. Host the generated `.well-known/agent-skills/index.json` and install through
   Hermes well-known discovery.

The well-known indexes are generated from `skills/` by `holo-polymarket-build`
(see [openclaw.md](openclaw.md) and the well-known template). This repository does
not keep a separate Hermes copy.
