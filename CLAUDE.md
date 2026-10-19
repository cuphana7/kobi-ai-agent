# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

This is the build/packaging repo for **Kobi (KB AI Assistant)** — an offline, no-install distribution of Qwen Code (Windows and Linux CLI, plus an optional Tauri-based Windows desktop GUI), customized for KB Card's internal (air-gapped) network. It is not an application codebase; it's a packaging pipeline plus a set of custom Qwen Code "skills" (agent tool extensions) that get bundled into portable installer archives.

There is a `GEMINI.md` in the repo root with project instructions aimed at Gemini CLI (read `README.md` first, enforce the security guardrails below). Treat it as equally binding for this project.

`main` was merged with a long-running `feat/kobi-desktop-gui` branch (2026-09-22) that added Linux support, the Desktop GUI, and the trimmed-build env-var system described below — check `git log --oneline -20` / `git branch -a` before assuming `main` is the only line of work; other branches (e.g. `ci/tauri-windows-test`) may still be active.

## Repository layout

- `make.sh` — the build script. Rebuilds each `*.skill` zip from its source folder, pre-installs Qwen Code + a portable Node.js runtime (and, on Windows, portable MinGit) into `Kobi_Installer/Kobi_Runtime/`, generates the launcher script(s), and packages everything into an installer archive + a `.sha256` checksum. Also optionally bumps the pinned `@qwen-code/qwen-code` version via the npm registry.
- `Kobi_Installer/` — installer source. `Install-Kobi.ps1`/`Uninstall-Kobi.ps1` (Windows) and `install.sh`/`uninstall.sh` (Linux) are the real logic; the `.cmd` files just launch the PowerShell ones. `Install-Kobi.ps1` / `install.sh` no longer gate installation on a username allow-list (`$AllowedUsers`/`ALLOWED_USERS` was removed 2026-09-23 at deployment-admin request — see `README.md` §12 `v20260923_0006`); anyone able to run the installer can install.
- `Kobi_Installer/assets/config/settings.json` and `QWEN.md` — the single source-of-truth settings/system-prompt shipped to end users' `~/.qwen/`. This is where the security guardrails (denied tools, denied file patterns, denied bash commands) and Korean-language/approval-mode behavior are actually enforced at the agent level. `make.sh` in-place patches a copy of `settings.json` per target/flavor (see below) rather than maintaining separate settings files per variant — follow that pattern for any new platform/flavor-specific tweak instead of forking the file.
- `<skill-name>/` (source) + `<skill-name>.skill` (built zip) — one pair per skill: `jennifer-monitor`, `frism-cm`, `office-edit`, `project-bootstrap`, `kbpay-service-check`. The `.skill` file is a zip of the skill folder's contents, rebuilt by `make.sh` and copied into `Kobi_Installer/assets/`.
- `desktop-brand/` — tooling to rebrand the official Qwen Code Desktop (Electron/Tauri, Apache-2.0) as "Kobi Desktop" on an internet-connected build machine; produces `Kobi_Installer/assets/desktop/Kobi-Desktop-x64.exe` (gitignored — exceeds GitHub's 100MB limit, only its `.sha256` is tracked) which `make.sh` bundles into Windows packages when present. See `desktop-brand/README.md` and `desktop-brand/TAURI_MIGRATION.md`.
- `.github/workflows/build-desktop-tauri.yml` — CI that builds the Tauri desktop shell on `windows-latest`.
- `npm-seed/` — a minimal `package.json` pinning the `@qwen-code/qwen-code` version, used to populate `Kobi_Installer/assets/npm-cache/` (offline npm cache) and to fetch the `.tgz` packed into `Kobi_Installer/assets/pkg/`. `npm-seed/node_modules` is committed (it's the offline-verifiable dependency snapshot, not disposable) — after bumping the pinned version, regenerate it with a real `npm install` rather than hand-editing.
- `SKILL_GUIDE.md` — the authoritative spec for authoring a new Kobi skill (structure, JSON I/O contract, security gates, Java/Node hybrid pattern, `make.sh`/installer wiring). Read this before adding or modifying a skill.
- `download/` — reference materials (e.g. Jennifer OpenAPI docs), not part of the build.

## Building the installer

```bash
./make.sh [linux|windows|windows-full|windows-gui|skills] [version]
```

- First arg selects the target/flavor (defaults to `windows`): `linux` (tar.gz, no Desktop/Computer Use), `windows`/`win` (default — **core CLI only**: `NO_DESKTOP`/`NO_SKILLS`/`NO_COMPUTER_USE`/`NO_GIT` default to `1`; pass e.g. `NO_GIT=0` to re-include one), `windows-full`/`full` (everything: CLI+Desktop+skills+Computer Use+MinGit — the pre-2026-10-19 default), `windows-gui`/`gui` (Desktop-only, no CLI agent or skills — smaller download), `skills` (standalone `Kobi_Skills_v<version>.zip` bundle of all 5 `.skill` files for users who already have Kobi installed, unzipped into `~/.qwen`).
- Remaining arg is `version`, defaulting to `YYYYMMDD_HHMM`.
- Trimming env vars (combine freely; already all `1` by default for `windows`, opt-in for `windows-full`/`windows-gui`):
  - `NO_GIT=1` — exclude portable MinGit (assumes target PC already has git).
  - `NO_SKILLS=1` — exclude the 5 skills (distribute separately via `./make.sh skills`).
  - `NO_DESKTOP=1` — exclude the Desktop GUI installer, even if `assets/desktop/Kobi-Desktop-*.exe` is present.
  - `NO_COMPUTER_USE=1` — exclude the Computer Use driver asset and in-place patch `settings.json` to `tools.computerUse.enabled: false`.
- Every trim degrades gracefully when the underlying asset is simply missing too (e.g. no Desktop exe built yet → CLI-only with a warning, not an error) — `Install-Kobi.ps1`/`install.sh` skip any step whose asset file isn't present, each with an explicit "skipping" message. Keep that contract when adding a new asset: never silently create empty state, and never error out just because an optional asset is absent.
- Requires `npm`, `zip`, `unzip`, `python3` available on the build machine (Linux/macOS), even when targeting Windows.
- The script checks the npm registry for a newer `@qwen-code/qwen-code` and interactively offers to bump it (skipped automatically in non-interactive shells, and skipped entirely for the `skills` target since it doesn't touch the CLI runtime).
- Requires the relevant portable Node.js archive in `Kobi_Installer/assets/` (`node-v*-win-x64.zip` or `node-v*-linux-x64.tar.xz`) and a Qwen Code `.tgz` in `Kobi_Installer/assets/pkg/` to already be present — the script does not fetch these itself. Windows builds also look for `MinGit-*-64-bit.zip` (optional unless `NO_GIT=1` is not set and you want git bundled).
- Fails fast (`exit 1`) if the resulting `cli-entry.js` isn't produced by the offline `npm install`, so a broken installer is never packaged.
- Output: `Kobi_Installer_v<version>.zip` (or `_gui_`/`_linux_.tar.gz`/`Kobi_Skills_v<version>.zip`) + `.sha256` in the repo root; build intermediates (`dist/`, `dist_skills/`, `Kobi_Installer/Kobi_Runtime/`) are cleaned up afterward.

To rebuild just one skill's zip without a full package build, mirror the relevant block in `make.sh`, e.g.:
```bash
rm -f office-edit.skill Kobi_Installer/assets/office-edit.skill
(cd office-edit && zip -rq ../office-edit.skill *)
cp office-edit.skill Kobi_Installer/assets/office-edit.skill
```

## Skill architecture (how Kobi calls out to tools)

Every skill is a self-contained directory with a `SKILL.md` (YAML frontmatter `name` + `description` that Qwen Code uses to decide when to invoke it, followed by usage docs) and a `scripts/<skill>.cjs` CommonJS entry point that the agent shells out to. Three invariants apply across all skills (defined in `SKILL_GUIDE.md`):

1. **stdout contract**: every invocation prints exactly one JSON line to stdout, success or failure — `{"success": true, "data": {...}, "message": "..."}` or `{"success": false, "errorCode": "...", "errorMessage": "...", "errorDetail": "..."}`. Never multi-line or pretty-printed output; the agent parses it directly.
2. **Security gates live in the skill core**, not just in the installer's `settings.json`. Destructive/unauthorized operations (e.g. `frism-cm`'s `deploy-real` production deploy) must be blocked inside the script itself and return a `SECURITY_BLOCK` errorCode, so the guardrail holds even if the outer agent policy is bypassed.
3. **Java interop via Node wrapper**: where the underlying integration is a legacy Java API (`frism-cm`), the `.cjs` script is a thin `spawn('java', ...)` wrapper that builds the classpath from the skill's own `lib/`/`bin/` and forwards argv. Cross-platform classpath separators (`;` vs `:`) are handled via `process.platform`.

Skill-specific notes:
- **frism-cm**: Node wrapper (`scripts/frism-cm.cjs`) spawns a Java CLI (`com.kbcard.cm.cli.CmCli`, compiled `.class` in `bin/`, source in `src/`) against bundled JARs in `lib/` (Frism API, Oracle JDBC). Rebuild with `frism-cm/build.bat` (Windows only — cross-compiles with `--release 8` targeting JDK 1.8, source encoding EUC-KR). Korean string literals in the Java source are stored as `\uXXXX` escapes to survive EUC-KR/UTF-8 environment mismatches. `deploy-real` (production deploy) is permanently blocked; only `deploy-stage` is allowed.
- **office-edit**: pure Node.js (`scripts/office-edit.cjs`), no external binaries — uses `exceljs`, `mammoth`, `docxtemplater`, `pizzip`, `docx`. Safety defaults: edits never overwrite the source file unless `--in-place` is passed (default is `<name>.edited.<ext>`); `create-xlsx`/`create-docx` refuse to overwrite an existing path unless `--force` is passed.
- **jennifer-monitor**: `scripts/monitor.cjs` talks to an internal Jennifer APM view-server REST API (v2 with v1 fallback) over the internal network; connection URL/token have in-script defaults overridable via `--url`/`--token` or `JENNIFER_URL`/`JENNIFER_TOKEN`.
- **project-bootstrap**: not a live API integration — it's a set of PowerShell inventory scripts (`scripts/Get-ProjectInventory.ps1`, etc.) plus Markdown templates (`resources/templates/`) that Kobi fills in to generate a `.kobi/` project-memory doc set (`INDEX.md`, `ARCHITECTURE.md`, `FLOW.md`, ...) inside a *target* project being analyzed by Kobi — not inside this repo.
- **kbpay-service-check**: `scripts/kbpay-service-check.cjs`, a KB Pay-specific service-delay check built on the same Jennifer APM integration as `jennifer-monitor`; also ships a `monitor/jennifer-ai-monitor.bat` helper.

Skills are installed via the `Install-KobiSkill` PowerShell helper in `Install-Kobi.ps1` (a `$Skills` array of `{Dir, Asset, Msg, SkipMsg}` fed through one shared function) — when adding a 6th skill, add one entry to that array (and the equivalent spot in `install.sh`/`make.sh`'s skill-rebuild loop) rather than duplicating the install logic. The helper only creates the target folder and installs when the `.skill` asset is actually present in `assets/`; otherwise it prints `SkipMsg` and does nothing (no empty folder). Preserve that contract — it's what makes `NO_SKILLS=1` / missing-asset builds produce an accurate install log instead of silently claiming things that didn't happen.

## Installer flow (`Install-Kobi.ps1`, Windows)

1. Kills any running Kobi/qwen-code/node-pty node processes to release file locks.
2. Copies `config/QWEN.md` to `~/.qwen/QWEN.md` and installs each present skill via `Install-KobiSkill` (see above), then stages the Computer Use driver into `~/.qwen/computer-use/` after verifying its SHA-256 against a hardcoded expected hash (skipped with a message if the asset or checksum doesn't match).
3. If bundled, merges the CLI's `settings.json` into `~/.qwen/settings.json` (the file Desktop reads) so Desktop is pre-connected to the internal vLLM without needing the CLI's `QWEN_CODE_SYSTEM_SETTINGS_PATH` env var.
4. If a Desktop installer (`assets/desktop/Kobi-Desktop-*.exe`) is bundled, silently installs it (`/S`, per-user, no admin needed); otherwise skips with a message.
5. Registers `Kobi_Runtime\{bin,node,git}` on the user's `Path` env var as applicable (removing any prior Kobi path entries first), then runs a smoke test: the bundled CLI with `--version` for CLI builds, or just `node --version` for a GUI-only build (`$IsGuiOnly`, detected by the absence of the CLI entry point).

At every `kobi` invocation (not just install), the launcher (`kobi.ps1`/`kobi` shell script) calls `Test-KobiApiKey`/`check_api_key`: it pings each configured `baseUrl/models` with the stored key, and if the internal vLLM responds `401`, prompts interactively for a new key and saves it into `settings.json` — this is how a first-run or rotated API key gets captured, not a placeholder value in the shipped config. Don't try to solve "how does the user's real key get in" by editing the shipped placeholder; that prompt-on-401 flow is the mechanism.

Computer Use is wired for **read-only screen awareness** only — `settings.json`'s `permissions.deny` blocks every mouse/keyboard-control tool (`click`, `type_text`, `hotkey`, `scroll`, `launch_app`, etc.); only inspection tools (`list_windows`, `get_accessibility_tree`, `get_screen_size`) are allowed, and each still requires per-call user approval. The internal LLM doesn't support vision input, so screen state is read as a Markdown accessibility tree (`get_window_state` with `mode: "ax"`), never as a screenshot. It's Windows-only (no `cua-driver-rs` Linux binary): `make.sh` always disables it in-place for the `linux` target, and `NO_COMPUTER_USE=1` disables it the same way for a trimmed Windows build.

## `install.sh`/`Uninstall-Kobi.ps1` (Linux install, Windows uninstall)

`install.sh` mirrors the Windows installer flow for the `linux` target (process cleanup → skill install via the same `.skill` assets → `~/.local/bin/kobi` symlink + shell rc `PATH` update; no Desktop/Computer Use step, since neither exists for Linux). `Uninstall-Kobi.ps1` additionally finds and silently removes an installed Desktop via its HKCU/HKLM uninstall-registry entry (`/S`), and cleans `Kobi_Runtime\{git,node}` out of `PATH` alongside `\bin`.

## Security posture (baked into `settings.json` / `QWEN.md`, shipped to every install)

- Blocks `WebFetch` entirely (air-gapped network).
- Blocks reading/editing credential-shaped files: `.env`, `*.jks`, `*.p12`, `*.key`, `*.pem`.
- Blocks destructive shell commands: `git push`, `del`, `rm`, `format`.
- Default Korean-only responses; requires presenting a change plan and getting developer approval before editing files, especially anything with production impact.
- Any new skill or config change should preserve these gates rather than working around them — they reflect internal security-team sign-off (see version history in `README.md` §12 and `NOTICE_2026-07.md`), not incidental defaults.

## Versioning / changelog

`README.md` §12 has the full version history (Korean). When making a change that would ship in a new package build, update that changelog table and add an entry, following the existing format (version = `vYYYYMMDD[_HHMM]`, category, bullet list of changes, author).
