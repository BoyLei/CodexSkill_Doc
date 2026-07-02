# Directory Junction Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the existing batch file into a safe generic directory migration tool, then migrate TRAE SOLO CN data from C: to H: behind a Junction.

**Architecture:** One batch file accepts absolute source and destination paths. It defaults to dry-run; `/apply` copies with `robocopy`, stages the original directory as a rollback backup, creates and verifies a Junction, then removes the backup only after success.

**Tech Stack:** Windows batch, `robocopy`, `mklink /J`, `fsutil`

---

### Task 1: Refactor the migration script

**Files:**
- Modify: `scripts/tools/拷贝目录链接新目录.bat`

- [ ] Replace fixed roots and the directory array with required source and destination arguments plus optional `/apply`.
- [ ] Set dry-run as the default and reject missing, relative, or identical paths.
- [ ] Add idempotent handling for an existing Junction.
- [ ] In apply mode, create the destination and run `robocopy "%SRC%" "%DST%" /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /XJ`.
- [ ] Treat robocopy exit codes `0` through `7` as success and larger codes as failure.
- [ ] Rename the source to a sibling rollback directory, create the Junction, verify it, and restore the source if link creation or verification fails.
- [ ] Delete the rollback directory only after successful verification.
- [ ] Normalize the edited file to UTF-8 without BOM and CRLF.

### Task 2: Run the smallest complete self-check

**Files:**
- Test only: `tmp/junction-test-source`
- Test only: `tmp/junction-test-target`

- [ ] Create a source test directory with one known text file.
- [ ] Run the script without `/apply`; expect no target and no Junction.
- [ ] Run with `/apply`; expect robocopy success and a verified Junction.
- [ ] Read the known file through the original source path and compare its content.
- [ ] Run `/apply` again; expect a successful no-op because the source is already a Junction.
- [ ] Remove only the temporary test directories after resolving and verifying their absolute workspace paths.

### Task 3: Migrate TRAE SOLO CN

**Files:**
- Source: `C:\Users\dl\AppData\Roaming\TRAE SOLO CN`
- Destination: `H:\Cache\Users\dl\AppData\Roaming\TRAE SOLO CN`

- [ ] Verify both exact paths with `Test-Path -LiteralPath` and confirm the source is not already a reparse point.
- [ ] Check for running TRAE processes and close them before copying to prevent an inconsistent profile snapshot.
- [ ] Run the script without `/apply`; expect a dry-run report and no filesystem changes.
- [ ] Run `scripts\tools\拷贝目录链接新目录.bat "C:\Users\dl\AppData\Roaming\TRAE SOLO CN" "H:\Cache\Users\dl\AppData\Roaming\TRAE SOLO CN" /apply`.
- [ ] Verify `fsutil reparsepoint query` succeeds on the source and the destination exists.
- [ ] Compare representative file access and recursive file counts between the Junction path and destination.
- [ ] Start TRAE SOLO CN and confirm its profile loads from the redirected path.

### Task 4: Final verification

**Files:**
- Verify: `scripts/tools/拷贝目录链接新目录.bat`

- [ ] Re-read the batch file and confirm default dry-run behavior matches its help text.
- [ ] Run `git diff --check -- scripts/tools/拷贝目录链接新目录.bat` and expect no whitespace errors.
- [ ] Report the verified Junction target and any skipped application-level check.
