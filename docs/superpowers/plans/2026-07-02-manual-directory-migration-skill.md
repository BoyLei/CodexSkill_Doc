# Manual Directory Migration Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install a manually invoked directory-migration skill and regenerate the local extension index.

**Architecture:** Build the skill in a workspace staging directory with the official skill initializer, validate it, then copy it to the personal Codex skills directory. Keep the skill thin: it calls the existing migration batch file and disables implicit invocation in `agents/openai.yaml`.

**Tech Stack:** Markdown, YAML, Python skill-creator utilities, PowerShell

---

### Task 1: Establish the failing installation check

**Files:**
- Verify absent: `C:\Users\dl\.codex\skills\migrate-directory-to-parent\SKILL.md`

- [ ] Run a PowerShell assertion requiring `SKILL.md`, `agents/openai.yaml`, and `allow_implicit_invocation: false`; expect failure because the skill is not installed.

### Task 2: Initialize and author the skill

**Files:**
- Create: `tmp/skill-staging/migrate-directory-to-parent/SKILL.md`
- Create: `tmp/skill-staging/migrate-directory-to-parent/agents/openai.yaml`

- [ ] Run `init_skill.py migrate-directory-to-parent --path tmp/skill-staging` with interface values for display name, description, and a `$migrate-directory-to-parent` default prompt.
- [ ] Replace `SKILL.md` with the approved manual-only workflow, including absolute-path validation, `B\leaf(A)` target calculation, dry-run, `/apply`, process handling, and independent verification.
- [ ] Set `policy.allow_implicit_invocation: false` in `agents/openai.yaml`.
- [ ] Normalize both files to UTF-8 without BOM and CRLF.

### Task 3: Validate and install

**Files:**
- Install: `C:\Users\dl\.codex\skills\migrate-directory-to-parent\SKILL.md`
- Install: `C:\Users\dl\.codex\skills\migrate-directory-to-parent\agents\openai.yaml`

- [ ] Run `quick_validate.py` against the staged skill; expect success.
- [ ] Assert the staged YAML contains `allow_implicit_invocation: false` and the skill references the verified migration script.
- [ ] Copy the validated directory to `C:\Users\dl\.codex\skills`.
- [ ] Re-run the same assertions against the installed files; expect success.

### Task 4: Regenerate 插件简介.md

**Files:**
- Modify: `插件简介.md`

- [ ] Locate and run `scripts/codex-extension-docs.ps1 -Mode index` with `-ExecutionPolicy Bypass`.
- [ ] Verify `插件简介.md` contains `migrate-directory-to-parent`, its installed path, and a manual-invocation summary.
- [ ] Verify the generated Markdown is UTF-8 without BOM and CRLF.
