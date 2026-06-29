#!/usr/bin/env python3
import argparse
import json
import shutil
import sqlite3
import sys
from datetime import datetime
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover
    tomllib = None

TARGET_PROVIDERS = ("headroom", "custom")


def load_provider(config_path: Path) -> str:
    if tomllib is None:
        raise RuntimeError("Python 3.11+ is required for tomllib")
    with config_path.open("rb") as fh:
        data = tomllib.load(fh)
    provider = data.get("model_provider")
    if isinstance(provider, str) and provider.strip():
        return provider.strip()
    return "openai"


def count_target_threads(conn: sqlite3.Connection) -> int:
    row = conn.execute(
        """
        SELECT COUNT(*)
        FROM threads
        WHERE archived = 0
          AND model_provider IN ('headroom', 'custom')
        """
    ).fetchone()
    return int(row[0])


def list_target_thread_ids(conn: sqlite3.Connection) -> list[str]:
    rows = conn.execute(
        """
        SELECT id
        FROM threads
        WHERE archived = 0
          AND model_provider IN ('headroom', 'custom')
        ORDER BY updated_at DESC, id DESC
        """
    ).fetchall()
    return [str(thread_id) for (thread_id,) in rows]


def provider_breakdown(conn: sqlite3.Connection) -> list[tuple[str, int]]:
    rows = conn.execute(
        """
        SELECT COALESCE(model_provider, '<null>') AS provider, COUNT(*)
        FROM threads
        WHERE archived = 0
        GROUP BY COALESCE(model_provider, '<null>')
        ORDER BY provider
        """
    ).fetchall()
    return [(str(provider), int(count)) for provider, count in rows]


def backup_db(db_path: Path, stamp: str) -> Path:
    backup_dir = db_path.parent / "backups"
    backup_dir.mkdir(parents=True, exist_ok=True)
    backup_path = backup_dir / f"{db_path.name}.{stamp}.bak"
    shutil.copy2(db_path, backup_path)
    return backup_path


def sync_provider(db_path: Path, provider: str) -> int:
    conn = sqlite3.connect(db_path)
    try:
        cur = conn.execute(
            """
            UPDATE threads
            SET model_provider = ?
            WHERE archived = 0
              AND model_provider IN ('headroom', 'custom')
            """,
            (provider,),
        )
        conn.commit()
        return int(cur.rowcount)
    finally:
        conn.close()


def iter_session_files(sessions_root: Path, thread_ids: set[str]) -> list[Path]:
    matches: list[Path] = []
    for path in sessions_root.rglob("rollout-*.jsonl"):
        if any(thread_id in path.name for thread_id in thread_ids):
            matches.append(path)
    matches.sort()
    return matches


def backup_session_file(path: Path, codex_home: Path, stamp: str) -> Path:
    backup_root = codex_home / "backups" / f"sessions-{stamp}"
    relative = path.relative_to(codex_home)
    backup_path = backup_root / relative
    backup_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, backup_path)
    return backup_path


def sync_session_file(path: Path, provider: str) -> bool:
    changed = False
    new_lines: list[str] = []
    with path.open("r", encoding="utf-8", errors="strict", newline="") as fh:
        for line in fh:
            if not line.strip():
                new_lines.append(line)
                continue
            obj = json.loads(line)
            if (
                obj.get("type") == "session_meta"
                and isinstance(obj.get("payload"), dict)
                and obj["payload"].get("model_provider") in TARGET_PROVIDERS
            ):
                obj["payload"]["model_provider"] = provider
                changed = True
                newline = "\r\n" if line.endswith("\r\n") else "\n"
                new_lines.append(
                    json.dumps(obj, ensure_ascii=False, separators=(",", ":")) + newline
                )
                continue
            new_lines.append(line)
    if changed:
        with path.open("w", encoding="utf-8", newline="") as fh:
            fh.writelines(new_lines)
    return changed


def sync_session_files(
    codex_home: Path, thread_ids: list[str], provider: str, stamp: str, backup: bool
) -> tuple[int, list[Path], list[Path]]:
    session_files = iter_session_files(codex_home / "sessions", set(thread_ids))
    backups: list[Path] = []
    changed = 0
    for path in session_files:
        if backup:
            backups.append(backup_session_file(path, codex_home, stamp))
        if sync_session_file(path, provider):
            changed += 1
    return changed, session_files, backups


def parse_args() -> argparse.Namespace:
    home = Path.home() / ".codex"
    parser = argparse.ArgumentParser(
        description="Sync unarchived HeadRoom and custom Codex thread providers to the current config provider."
    )
    parser.add_argument("--codex-home", type=Path, default=home)
    parser.add_argument(
        "--apply", action="store_true", help="Write changes to state_5.sqlite and rollout JSONL"
    )
    parser.add_argument("--no-backup", action="store_true", help="Skip the backup")
    parser.add_argument("--self-test", action="store_true", help="Run a tiny self-check and exit")
    return parser.parse_args()


def self_test() -> int:
    import tempfile

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        config_path = root / "config.toml"
        db_path = root / "state_5.sqlite"
        session_dir = root / "sessions" / "2026" / "06" / "29"
        session_dir.mkdir(parents=True)
        session_a = session_dir / "rollout-2026-06-29T10-41-36-a.jsonl"
        session_b = session_dir / "rollout-2026-06-29T10-41-36-b.jsonl"
        config_path.write_bytes(b'model_provider = "openai"\n')
        session_a.write_text(
            '{"type":"session_meta","payload":{"id":"a","model_provider":"headroom"}}\r\n',
            encoding="utf-8",
            newline="",
        )
        session_b.write_text(
            '{"type":"session_meta","payload":{"id":"b","model_provider":"custom"}}\r\n',
            encoding="utf-8",
            newline="",
        )
        conn = sqlite3.connect(db_path)
        conn.execute(
            """
            CREATE TABLE threads (
                id TEXT,
                archived INTEGER,
                model_provider TEXT,
                updated_at INTEGER
            )
            """
        )
        conn.executemany(
            "INSERT INTO threads (id, archived, model_provider, updated_at) VALUES (?, ?, ?, ?)",
            [
                ("a", 0, "headroom", 3),
                ("b", 0, "custom", 2),
                ("c", 0, "openai", 1),
                ("d", 1, "custom", 0),
            ],
        )
        conn.commit()
        thread_ids = list_target_thread_ids(conn)
        conn.close()

        provider = load_provider(config_path)
        assert provider == "openai"
        changed = sync_provider(db_path, provider)
        assert changed == 2
        session_changed, session_files, backups = sync_session_files(
            root, thread_ids, provider, "test-stamp", backup=True
        )
        assert session_changed == 2
        assert len(session_files) == 2
        assert len(backups) == 2

        conn = sqlite3.connect(db_path)
        rows = conn.execute(
            "SELECT id, archived, model_provider FROM threads ORDER BY id"
        ).fetchall()
        conn.close()
        assert rows == [
            ("a", 0, "openai"),
            ("b", 0, "openai"),
            ("c", 0, "openai"),
            ("d", 1, "custom"),
        ]
        with session_a.open("r", encoding="utf-8") as fh:
            payload_a = json.loads(fh.readline())
        with session_b.open("r", encoding="utf-8") as fh:
            payload_b = json.loads(fh.readline())
        assert payload_a["payload"]["model_provider"] == "openai"
        assert payload_b["payload"]["model_provider"] == "openai"
    print("self-test: ok")
    return 0


def main() -> int:
    args = parse_args()
    if args.self_test:
        return self_test()

    codex_home = args.codex_home
    config_path = codex_home / "config.toml"
    db_path = codex_home / "state_5.sqlite"
    sessions_root = codex_home / "sessions"

    if not config_path.exists():
        print(f"config not found: {config_path}", file=sys.stderr)
        return 1
    if not db_path.exists():
        print(f"database not found: {db_path}", file=sys.stderr)
        return 1
    if not sessions_root.exists():
        print(f"sessions not found: {sessions_root}", file=sys.stderr)
        return 1

    provider = load_provider(config_path)
    conn = sqlite3.connect(db_path)
    try:
        before = count_target_threads(conn)
        breakdown = provider_breakdown(conn)
        thread_ids = list_target_thread_ids(conn)
    finally:
        conn.close()

    session_files = iter_session_files(sessions_root, set(thread_ids))

    print(f"current provider: {provider}")
    print("unarchived providers before:")
    for item_provider, count in breakdown:
        print(f"  {item_provider}: {count}")
    print(f"target unarchived threads: {before}")
    print(f"matching session files: {len(session_files)}")

    if not args.apply:
        print("dry-run only; pass --apply to write changes")
        return 0

    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_db_path = None
    if not args.no_backup:
        backup_db_path = backup_db(db_path, stamp)

    changed_threads = sync_provider(db_path, provider)
    changed_sessions, _, session_backups = sync_session_files(
        codex_home, thread_ids, provider, stamp, backup=not args.no_backup
    )

    print(f"updated threads: {changed_threads}")
    print(f"updated session files: {changed_sessions}")
    if backup_db_path is not None:
        print(f"backup db: {backup_db_path}")
    if session_backups:
        print(f"backup session root: {session_backups[0].parents[4]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())