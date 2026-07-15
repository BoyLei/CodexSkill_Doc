#!/usr/bin/env python3

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import statistics
import sqlite3
from pathlib import Path
from typing import Any

TERMINAL_TOOL_NAMES = {"exec_command", "write_stdin", "read_thread_terminal"}
CLAIM_ID_PATTERN = re.compile(r"\bC-\d{3}\b")
REQUIRED_TASK_ARTIFACTS = [
    "architecture-baseline.md",
    "current-brief.md",
    "decision-log.md",
    "open-risks.md",
    "verification-checklist.md",
    "evidence-ledger.md",
    "handoff-checklist.md",
    "subagent-report.md",
]
CLAIM_REQUIRED_FILES = [
    "architecture-baseline.md",
    "current-brief.md",
    "decision-log.md",
    "open-risks.md",
    "verification-checklist.md",
]


def parse_args() -> argparse.Namespace:
    home = Path.home() / ".codex"
    parser = argparse.ArgumentParser(
        description="Analyze Codex token usage from local rollout logs."
    )
    parser.add_argument("--codex-home", type=Path, default=home)
    parser.add_argument(
        "--thread-id",
        action="append",
        dest="thread_ids",
        default=[],
        help="Codex thread id to analyze. Repeat for multiple threads.",
    )
    parser.add_argument(
        "--task-dir",
        type=Path,
        help="Optional docs/refactor task directory to audit for protocol hygiene.",
    )
    parser.add_argument("--output", type=Path, help="Write JSON report to this file.")
    parser.add_argument("--top-turns", type=int, default=5)
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--self-test", action="store_true", help="Run a tiny self-check and exit")
    return parser.parse_args()


def analyze_threads(
    codex_home: Path,
    thread_ids: list[str],
    top_turns: int,
    verbose: bool,
    task_dir: Path | None = None,
) -> dict:
    db_path = codex_home / "state_5.sqlite"
    sessions_root = codex_home / "sessions"
    normalized_ids = [item.strip() for item in thread_ids if item and item.strip()]
    unique_ids = list(dict.fromkeys(normalized_ids))
    thread_rows = load_thread_rows(db_path, unique_ids)
    rollout_files = iter_rollout_files(sessions_root, set(unique_ids))
    parsed_rollouts = [parse_rollout(path) for path in rollout_files]
    task_protocol = analyze_task_dir(task_dir)

    threads_out: list[dict[str, Any]] = []
    turns_out: list[dict[str, Any]] = []
    signals_out: list[dict[str, Any]] = []

    rollouts_by_thread: dict[str, list[dict[str, Any]]] = {thread_id: [] for thread_id in unique_ids}
    for rollout in parsed_rollouts:
        for related_id in rollout["related_thread_ids"]:
            if related_id in rollouts_by_thread:
                rollouts_by_thread[related_id].append(rollout)

    for thread_id in unique_ids:
        row = thread_rows.get(thread_id)
        thread_rollouts = rollouts_by_thread.get(thread_id, [])
        thread_report, thread_turns, thread_signals = build_thread_report(
            thread_id=thread_id,
            row=row,
            rollouts=thread_rollouts,
            top_turns=top_turns,
            verbose=verbose,
            task_protocol=task_protocol,
        )
        threads_out.append(thread_report)
        turns_out.extend(thread_turns)
        signals_out.extend(thread_signals)

    return {
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "codex_home": str(codex_home),
        "task_protocol": task_protocol,
        "threads": threads_out,
        "turns": turns_out,
        "signals": signals_out,
        "usage_template": {
            "python": "python .\\scripts\\analyze_codex_tokens.py --thread-id <id1> --thread-id <id2> --task-dir .\\docs\\refactor\\<task-name> --output .\\tmp\\codex-token-report.json --top-turns 5 --verbose",
            "powershell": "powershell -ExecutionPolicy Bypass -File .\\scripts\\analyze-codex-tokens.ps1 -ThreadId @('<id1>','<id2>') -TaskDir .\\docs\\refactor\\<task-name> -OutputPath .\\tmp\\codex-token-report.json -TopTurns 5 -Detailed",
        },
    }


def load_thread_rows(db_path: Path, thread_ids: list[str]) -> dict[str, dict[str, Any]]:
    if not db_path.exists():
        raise FileNotFoundError(f"database not found: {db_path}")
    if not thread_ids:
        return {}
    placeholders = ",".join("?" for _ in thread_ids)
    query = (
        "SELECT id, archived, model_provider, updated_at "
        f"FROM threads WHERE id IN ({placeholders})"
    )
    conn = sqlite3.connect(db_path)
    try:
        rows = conn.execute(query, thread_ids).fetchall()
    finally:
        conn.close()
    return {
        str(thread_id): {
            "thread_id": str(thread_id),
            "archived": bool(archived),
            "model_provider": model_provider or "openai",
            "updated_at": updated_at,
        }
        for thread_id, archived, model_provider, updated_at in rows
    }


def iter_rollout_files(sessions_root: Path, thread_ids: set[str]) -> list[Path]:
    if not sessions_root.exists():
        raise FileNotFoundError(f"sessions not found: {sessions_root}")
    matches: list[Path] = []
    for path in sessions_root.rglob("rollout-*.jsonl"):
        if any(thread_id in path.name for thread_id in thread_ids):
            matches.append(path)
    matches.sort()
    return matches


def parse_rollout(path: Path) -> dict[str, Any]:
    entries: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as fh:
        for raw_line in fh:
            line = raw_line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError:
                continue

    session_meta = next((entry for entry in entries if entry.get("type") == "session_meta"), None)
    session_payload = session_meta.get("payload", {}) if isinstance(session_meta, dict) else {}
    related_ids = {
        stringify(session_payload.get("id")),
        stringify(session_payload.get("parent_thread_id")),
        stringify(session_payload.get("session_id")),
    }
    related_ids.discard("")

    tool_call_turn: dict[str, str] = {}
    turns: dict[str, dict[str, Any]] = {}
    pending_token_events: list[dict[str, Any]] = []
    current_turn_id = ""
    context_blocks: list[dict[str, Any]] = []

    for entry in entries:
        entry_type = stringify(entry.get("type"))
        payload = entry.get("payload", {}) if isinstance(entry.get("payload"), dict) else {}
        derived_turn_id = extract_turn_id(payload)
        if derived_turn_id:
            current_turn_id = derived_turn_id
        if entry_type == "response_item":
            payload_type = stringify(payload.get("type"))
            if payload_type == "function_call":
                turn_id = derived_turn_id or current_turn_id
                call_id = stringify(payload.get("call_id"))
                if turn_id:
                    if call_id:
                        tool_call_turn[call_id] = turn_id
                    turn = ensure_turn(turns, turn_id, path)
                    tool_name = stringify(payload.get("name")) or "unknown"
                    turn["tool_call_count"] += 1
                    turn["tool_names"].append(tool_name)
                    if tool_name in TERMINAL_TOOL_NAMES:
                        turn["terminal_tool_names"].append(tool_name)
                        turn["terminal_tool_call_count"] += 1
                    turn["tool_argument_chars"] += len(stringify(payload.get("arguments")))
                    turn["event_types"].append("function_call")
                    apply_session_meta_to_turn(turn, session_payload)
                    context_blocks.append(
                        build_context_block(
                            line_type="function_call",
                            turn_id=turn_id,
                            payload_type=payload_type,
                            role="tool",
                            tool_name=tool_name,
                            content=stringify(payload.get("arguments")),
                            source_tags=turn["source_tags"],
                        )
                    )
            elif payload_type == "function_call_output":
                turn_id = tool_call_turn.get(stringify(payload.get("call_id"))) or current_turn_id
                if turn_id:
                    turn = ensure_turn(turns, turn_id, path)
                    output_text = stringify(payload.get("output"))
                    turn["tool_output_count"] += 1
                    turn["tool_output_chars"] += len(output_text)
                    terminal_tool_names = set(turn["terminal_tool_names"])
                    if terminal_tool_names:
                        turn["terminal_tool_output_count"] += 1
                        turn["terminal_tool_output_chars"] += len(output_text)
                    turn["event_types"].append("function_call_output")
                    context_blocks.append(
                        build_context_block(
                            line_type="function_call_output",
                            turn_id=turn_id,
                            payload_type=payload_type,
                            role="tool",
                            tool_name=(sorted(terminal_tool_names)[0] if terminal_tool_names else ""),
                            content=output_text,
                            source_tags=turn["source_tags"],
                        )
                    )
            elif payload_type == "message":
                turn_id = derived_turn_id or current_turn_id
                if turn_id:
                    turn = ensure_turn(turns, turn_id, path)
                    message_text = count_message_text(payload)
                    turn["message_char_count"] += len(message_text)
                    turn["event_types"].append(f"message:{stringify(payload.get('role')) or 'unknown'}")
                    apply_session_meta_to_turn(turn, session_payload)
                    context_blocks.append(
                        build_context_block(
                            line_type="message",
                            turn_id=turn_id,
                            payload_type=payload_type,
                            role=stringify(payload.get("role")) or "unknown",
                            tool_name="",
                            content=message_text,
                            source_tags=turn["source_tags"],
                        )
                    )
            elif payload_type in {"custom_tool_call", "custom_tool_call_output"}:
                turn_id = derived_turn_id or current_turn_id
                if turn_id:
                    turn = ensure_turn(turns, turn_id, path)
                    custom_content = stringify(payload.get("input")) or stringify(payload.get("output"))
                    context_blocks.append(
                        build_context_block(
                            line_type=payload_type,
                            turn_id=turn_id,
                            payload_type=payload_type,
                            role="custom_tool",
                            tool_name=stringify(payload.get("name")),
                            content=custom_content,
                            source_tags=turn["source_tags"],
                        )
                    )
        elif entry_type == "event_msg":
            payload_type = stringify(payload.get("type"))
            if payload_type == "token_count":
                token_usage = payload.get("info", {}).get("last_token_usage")
                if not isinstance(token_usage, dict):
                    token_usage = payload.get("info", {}).get("total_token_usage")
                token_event = {
                    "token_usage": normalize_token_usage(token_usage),
                    "timestamp": stringify(entry.get("timestamp")),
                }
                if current_turn_id:
                    turn = ensure_turn(turns, current_turn_id, path)
                    turn["token_usage"] = token_event["token_usage"]
                    turn["token_timestamp"] = token_event["timestamp"]
                    turn["event_types"].append("token_count")
                    apply_session_meta_to_turn(turn, session_payload)
                else:
                    pending_token_events.append(token_event)
            elif payload_type == "task_complete":
                turn_id = stringify(payload.get("turn_id")) or current_turn_id
                if turn_id:
                    current_turn_id = turn_id
                    turn = ensure_turn(turns, turn_id, path)
                    if pending_token_events:
                        token_event = pending_token_events.pop(0)
                        turn["token_usage"] = token_event["token_usage"]
                        turn["token_timestamp"] = token_event["timestamp"]
                    turn["task_complete_timestamp"] = stringify(entry.get("timestamp"))
                    turn["assistant_output_chars"] += len(stringify(payload.get("last_agent_message")))
                    turn["event_types"].append("task_complete")
                    apply_session_meta_to_turn(turn, session_payload)
            elif payload_type in {"mcp_tool_call_end", "mcp_tool_call_start"}:
                turn_id = current_turn_id
                if turn_id:
                    turn = ensure_turn(turns, turn_id, path)
                    invocation = payload.get("invocation")
                    invocation_text = json.dumps(invocation, ensure_ascii=False) if invocation is not None else json.dumps(payload, ensure_ascii=False)
                    context_blocks.append(
                        build_context_block(
                            line_type=payload_type,
                            turn_id=turn_id,
                            payload_type=payload_type,
                            role="mcp",
                            tool_name=extract_mcp_tool_name(payload),
                            content=invocation_text,
                            source_tags=turn["source_tags"],
                        )
                    )

    ordered_turns = sorted(
        turns.values(),
        key=lambda item: (
            item["token_timestamp"] or item["task_complete_timestamp"] or "",
            item["turn_id"],
        ),
    )
    return {
        "path": path,
        "related_thread_ids": sorted(related_ids),
        "session_meta": session_payload,
        "turns": ordered_turns,
        "context_blocks": context_blocks,
    }


def ensure_turn(turns: dict[str, dict[str, Any]], turn_id: str, rollout_path: Path) -> dict[str, Any]:
    if turn_id not in turns:
        turns[turn_id] = {
            "turn_id": turn_id,
            "rollout_file": str(rollout_path),
            "token_usage": zero_token_usage(),
            "token_timestamp": "",
            "task_complete_timestamp": "",
            "tool_call_count": 0,
            "tool_output_count": 0,
            "tool_output_chars": 0,
            "tool_argument_chars": 0,
            "assistant_output_chars": 0,
            "message_char_count": 0,
            "tool_names": [],
            "terminal_tool_names": [],
            "terminal_tool_call_count": 0,
            "terminal_tool_output_count": 0,
            "terminal_tool_output_chars": 0,
            "event_types": [],
            "source_tags": [],
        }
    return turns[turn_id]


def extract_turn_id(payload: dict[str, Any]) -> str:
    metadata = payload.get("metadata")
    if isinstance(metadata, dict):
        turn_id = stringify(metadata.get("turn_id"))
        if turn_id:
            return turn_id
    passthrough = payload.get("internal_chat_message_metadata_passthrough")
    if isinstance(passthrough, dict):
        turn_id = stringify(passthrough.get("turn_id"))
        if turn_id:
            return turn_id
    return stringify(payload.get("turn_id"))


def count_message_text(payload: dict[str, Any]) -> str:
    parts: list[str] = []
    content = payload.get("content")
    if isinstance(content, list):
        for item in content:
            if isinstance(item, dict):
                text_value = item.get("text")
                output_value = item.get("output_text")
                if text_value is not None:
                    parts.append(stringify(text_value))
                if output_value is not None:
                    parts.append(stringify(output_value))
    return "".join(parts)


def normalize_token_usage(token_usage: Any) -> dict[str, int]:
    if not isinstance(token_usage, dict):
        return zero_token_usage()
    normalized = zero_token_usage()
    for key in normalized:
        value = token_usage.get(key)
        normalized[key] = int(value) if isinstance(value, (int, float)) else 0
    return normalized


def zero_token_usage() -> dict[str, int]:
    return {
        "input_tokens": 0,
        "cached_input_tokens": 0,
        "output_tokens": 0,
        "reasoning_output_tokens": 0,
        "total_tokens": 0,
    }


def apply_session_meta_to_turn(turn: dict[str, Any], session_payload: dict[str, Any]) -> None:
    provider = stringify(session_payload.get("model_provider"))
    if provider:
        turn["model_provider"] = provider
    source = session_payload.get("source")
    if isinstance(source, dict):
        if "subagent" in source and "subagent" not in turn["source_tags"]:
            turn["source_tags"].append("subagent")
        if "guardian" in json.dumps(source, ensure_ascii=False) and "guardian" not in turn["source_tags"]:
            turn["source_tags"].append("guardian")
    thread_source = stringify(session_payload.get("thread_source"))
    if thread_source and thread_source not in turn["source_tags"]:
        turn["source_tags"].append(thread_source)


def build_thread_report(
    thread_id: str,
    row: dict[str, Any] | None,
    rollouts: list[dict[str, Any]],
    top_turns: int,
    verbose: bool,
    task_protocol: dict[str, Any] | None,
) -> tuple[dict[str, Any], list[dict[str, Any]], list[dict[str, Any]]]:
    all_turns: list[dict[str, Any]] = []
    all_context_blocks: list[dict[str, Any]] = []
    thread_source_tags: set[str] = set()
    thread_provider = row["model_provider"] if row else "unknown"

    for rollout in rollouts:
        session_payload = rollout["session_meta"]
        provider = stringify(session_payload.get("model_provider"))
        if provider:
            thread_provider = provider
        source = session_payload.get("source")
        if isinstance(source, dict) and "subagent" in source:
            thread_source_tags.add("subagent")
        if isinstance(source, dict) and "guardian" in json.dumps(source, ensure_ascii=False):
            thread_source_tags.add("guardian")
        for turn in rollout["turns"]:
            copied = dict(turn)
            copied["thread_id"] = thread_id
            if "model_provider" not in copied:
                copied["model_provider"] = thread_provider
            all_turns.append(copied)
            thread_source_tags.update(copied.get("source_tags", []))
        for block in rollout.get("context_blocks", []):
            copied_block = dict(block)
            copied_block["thread_id"] = thread_id
            all_context_blocks.append(copied_block)

    token_turns = [turn for turn in all_turns if turn["token_usage"]["total_tokens"] > 0]
    total_turns = len(token_turns)
    total_tokens = [turn["token_usage"]["total_tokens"] for turn in token_turns]
    total_inputs = [turn["token_usage"]["input_tokens"] for turn in token_turns]
    median_total = int(statistics.median(total_tokens)) if total_tokens else 0
    median_input = int(statistics.median(total_inputs)) if total_inputs else 0
    total_tool_output_chars = sum(turn["tool_output_chars"] for turn in token_turns)
    total_terminal_output_chars = sum(turn["terminal_tool_output_chars"] for turn in token_turns)
    long_context_turn_count = sum(
        1
        for turn in token_turns
        if turn["token_usage"]["input_tokens"] >= 100000 or cached_ratio(turn["token_usage"]) >= 0.8
    )

    thread_signals: list[dict[str, Any]] = []
    turn_reports: list[dict[str, Any]] = []

    for index, turn in enumerate(sorted(token_turns, key=lambda item: item["token_timestamp"] or item["turn_id"]), start=1):
        signals = infer_turn_signals(turn, index, total_turns, median_total, median_input)
        turn["signals"] = signals
        turn["turn_index"] = index
        turn["total_turns"] = total_turns
        if signals:
            turn_reports.append(build_turn_output(turn, verbose))
            thread_signals.extend(
                build_signal_output(thread_id, turn["turn_id"], signal) for signal in signals
            )

    if total_turns and not turn_reports:
        top_sorted = sorted(token_turns, key=lambda item: item["token_usage"]["total_tokens"], reverse=True)[:top_turns]
        for turn in top_sorted:
            turn_reports.append(build_turn_output(turn, verbose))

    if total_turns:
        ranked = sorted(token_turns, key=lambda item: item["token_usage"]["total_tokens"], reverse=True)
        selected_turn_ids = {turn["turn_id"] for turn in turn_reports}
        for turn in ranked:
            if len(selected_turn_ids) >= top_turns:
                break
            if turn["turn_id"] in selected_turn_ids:
                continue
            turn_reports.append(build_turn_output(turn, verbose))
            selected_turn_ids.add(turn["turn_id"])

    summary = {
        "total_input_tokens": sum(turn["token_usage"]["input_tokens"] for turn in token_turns),
        "total_cached_input_tokens": sum(turn["token_usage"]["cached_input_tokens"] for turn in token_turns),
        "total_output_tokens": sum(turn["token_usage"]["output_tokens"] for turn in token_turns),
        "total_reasoning_output_tokens": sum(turn["token_usage"]["reasoning_output_tokens"] for turn in token_turns),
        "total_tokens": sum(turn["token_usage"]["total_tokens"] for turn in token_turns),
        "max_turn_total_tokens": max(total_tokens) if total_tokens else 0,
        "token_turn_count": total_turns,
    }
    monitoring = {
        "avg_cached_input_ratio": round(
            (
                sum(cached_ratio(turn["token_usage"]) for turn in token_turns) / total_turns
                if total_turns
                else 0.0
            ),
            4,
        ),
        "max_cached_input_ratio": round(
            max((cached_ratio(turn["token_usage"]) for turn in token_turns), default=0.0),
            4,
        ),
        "long_context_turn_count": long_context_turn_count,
        "terminal_tool_call_count": sum(turn["terminal_tool_call_count"] for turn in token_turns),
        "terminal_tool_output_count": sum(turn["terminal_tool_output_count"] for turn in token_turns),
        "terminal_tool_output_chars": total_terminal_output_chars,
        "terminal_tool_output_ratio": round(
            (total_terminal_output_chars / total_tool_output_chars) if total_tool_output_chars else 0.0,
            4,
        ),
        "terminal_tool_names": sorted(
            {
                tool_name
                for turn in token_turns
                for tool_name in turn["terminal_tool_names"]
                if tool_name
            }
        ),
    }
    recommendations = build_recommendations(summary, monitoring, task_protocol)
    top_context_blocks = build_top_context_blocks(all_context_blocks)

    if thread_provider != "unknown":
        thread_signals.append(
            {
                "thread_id": thread_id,
                "turn_id": None,
                "kind": "provider_correlation",
                "confidence": "low",
                "reason": f"Thread used model_provider={thread_provider}; recorded for correlation only, not root-cause attribution.",
            }
        )

    if "subagent" in thread_source_tags or "guardian" in thread_source_tags:
        thread_signals.append(
            {
                "thread_id": thread_id,
                "turn_id": None,
                "kind": "subagent_or_guardian_overhead",
                "confidence": "medium",
                "reason": "Session metadata indicates subagent or guardian involvement, which can add instruction and coordination overhead.",
            }
        )

    notes: list[str] = []
    if row is None:
        notes.append("thread_id not found in state_5.sqlite")
    if not rollouts:
        notes.append("no matching rollout JSONL files found")
    elif not token_turns:
        notes.append("rollout found but no token_count events were present")

    thread_report = {
        "thread_id": thread_id,
        "rollout_files": [str(rollout["path"]) for rollout in rollouts],
        "model_provider": thread_provider,
        "summary": summary,
        "monitoring": monitoring,
        "protocol_hygiene": task_protocol,
        "top_context_blocks": top_context_blocks,
        "recommendations": recommendations,
        "notes": notes,
    }
    if row is not None:
        thread_report["archived"] = row["archived"]
        thread_report["updated_at"] = row["updated_at"]

    turn_reports.sort(key=lambda item: item["token_usage"]["total_tokens"], reverse=True)
    return thread_report, turn_reports[:top_turns], thread_signals


def infer_turn_signals(
    turn: dict[str, Any],
    turn_index: int,
    total_turns: int,
    median_total: int,
    median_input: int,
) -> list[dict[str, str]]:
    usage = turn["token_usage"]
    signals: list[dict[str, str]] = []
    input_tokens = usage["input_tokens"]
    cached_input_tokens = usage["cached_input_tokens"]
    output_tokens = usage["output_tokens"]
    reasoning_tokens = usage["reasoning_output_tokens"]
    total_tokens = usage["total_tokens"]

    cached_ratio_value = cached_ratio(usage)
    reasoning_ratio_value = reasoning_ratio(usage)

    if input_tokens >= max(1000, int(median_input * 1.5) if median_input else 1000):
        signals.append(
            {
                "kind": "large_input_context",
                "confidence": "high" if input_tokens >= 50000 else "medium",
                "reason": f"Turn input_tokens={input_tokens} is high relative to the thread baseline.",
            }
        )
    if cached_input_tokens >= 500 and cached_ratio_value >= 0.6:
        signals.append(
            {
                "kind": "high_cached_prefix",
                "confidence": "high" if cached_ratio_value >= 0.8 else "medium",
                "reason": f"cached_input_tokens={cached_input_tokens} ({cached_ratio_value:.0%} of input) suggests a heavy repeated prefix or long prior context.",
            }
        )
    if reasoning_tokens >= 200 and reasoning_ratio_value >= 0.25:
        signals.append(
            {
                "kind": "high_reasoning_output",
                "confidence": "high" if reasoning_tokens >= 1000 else "medium",
                "reason": f"reasoning_output_tokens={reasoning_tokens} is a large share of output.",
            }
        )
    if turn["tool_call_count"] >= 3 or turn["tool_output_chars"] >= 2000 or turn["tool_output_count"] >= 2:
        signals.append(
            {
                "kind": "high_tool_output_risk",
                "confidence": "medium",
                "reason": "This turn includes multiple tool calls or long tool outputs that likely inflated context carry-forward.",
            }
        )
    if (
        total_turns >= 4
        and turn_index > max(2, total_turns // 2)
        and total_tokens >= max(1000, int(median_total * 1.25) if median_total else 1000)
    ):
        signals.append(
            {
                "kind": "long_conversation_accumulation",
                "confidence": "medium",
                "reason": "This high-cost turn appears in the later half of the conversation and is consistent with context accumulation.",
            }
        )
    if "subagent" in turn["source_tags"] or "guardian" in turn["source_tags"]:
        signals.append(
            {
                "kind": "subagent_or_guardian_overhead",
                "confidence": "medium",
                "reason": "Session metadata around this turn indicates subagent or guardian overhead.",
            }
        )
    return signals


def build_turn_output(turn: dict[str, Any], verbose: bool) -> dict[str, Any]:
    evidence = {
        "rollout_file": turn["rollout_file"],
        "token_timestamp": turn["token_timestamp"],
        "cached_input_ratio": round(cached_ratio(turn["token_usage"]), 4),
        "reasoning_output_ratio": round(reasoning_ratio(turn["token_usage"]), 4),
        "tool_call_count": turn["tool_call_count"],
        "tool_output_count": turn["tool_output_count"],
        "tool_output_chars": turn["tool_output_chars"],
        "tool_names": sorted(set(name for name in turn["tool_names"] if name)),
        "terminal_tool_call_count": turn["terminal_tool_call_count"],
        "terminal_tool_output_count": turn["terminal_tool_output_count"],
        "terminal_tool_output_chars": turn["terminal_tool_output_chars"],
        "terminal_tool_names": sorted(set(name for name in turn["terminal_tool_names"] if name)),
        "source_tags": sorted(set(turn["source_tags"])),
    }
    if verbose:
        evidence["tool_argument_chars"] = turn["tool_argument_chars"]
        evidence["assistant_output_chars"] = turn["assistant_output_chars"]
        evidence["message_char_count"] = turn["message_char_count"]
        evidence["event_types"] = turn["event_types"]
        evidence["turn_index"] = turn["turn_index"]
        evidence["total_turns"] = turn["total_turns"]
    return {
        "thread_id": turn["thread_id"],
        "turn_id": turn["turn_id"],
        "token_usage": turn["token_usage"],
        "signals": turn["signals"],
        "risk_summary": build_turn_risk_summary(turn),
        "evidence": evidence,
    }


def build_context_block(
    *,
    line_type: str,
    turn_id: str,
    payload_type: str,
    role: str,
    tool_name: str,
    content: str,
    source_tags: list[str],
) -> dict[str, Any]:
    text = content if isinstance(content, str) else stringify(content)
    return {
        "line_type": line_type,
        "payload_type": payload_type,
        "turn_id": turn_id,
        "role": role,
        "tool_name": tool_name,
        "chars": len(text),
        "preview": text[:300].replace("\n", "\\n"),
        "source_tags": sorted(set(source_tags)),
    }


def extract_mcp_tool_name(payload: dict[str, Any]) -> str:
    invocation = payload.get("invocation")
    if isinstance(invocation, dict):
        server = stringify(invocation.get("server"))
        tool = stringify(invocation.get("tool"))
        if server and tool:
            return f"{server}.{tool}"
        return tool or server
    return ""


def build_top_context_blocks(blocks: list[dict[str, Any]], limit: int = 10) -> list[dict[str, Any]]:
    ranked = sorted(
        (block for block in blocks if block.get("chars", 0) > 0),
        key=lambda item: item["chars"],
        reverse=True,
    )
    return ranked[:limit]


def build_signal_output(thread_id: str, turn_id: str, signal: dict[str, str]) -> dict[str, Any]:
    return {
        "thread_id": thread_id,
        "turn_id": turn_id,
        "kind": signal["kind"],
        "confidence": signal["confidence"],
        "reason": signal["reason"],
    }


def stringify(value: Any) -> str:
    if isinstance(value, str):
        return value
    if value is None:
        return ""
    return str(value)


def cached_ratio(usage: dict[str, int]) -> float:
    input_tokens = usage["input_tokens"]
    if input_tokens <= 0:
        return 0.0
    return usage["cached_input_tokens"] / input_tokens


def reasoning_ratio(usage: dict[str, int]) -> float:
    output_tokens = usage["output_tokens"]
    if output_tokens <= 0:
        return 0.0
    return usage["reasoning_output_tokens"] / output_tokens


def build_recommendations(
    summary: dict[str, int],
    monitoring: dict[str, Any],
    task_protocol: dict[str, Any] | None,
) -> list[dict[str, str]]:
    recommendations: list[dict[str, str]] = []
    if monitoring["max_cached_input_ratio"] >= 0.95 or monitoring["long_context_turn_count"] >= 3:
        recommendations.append(
            {
                "kind": "start_new_thread",
                "priority": "high",
                "reason": "The thread shows repeated long-context carry-forward; continuing in the same thread is likely to keep token costs high.",
            }
        )
    if monitoring["terminal_tool_output_chars"] >= 50000 or monitoring["terminal_tool_output_ratio"] >= 0.5:
        recommendations.append(
            {
                "kind": "truncate_terminal_output",
                "priority": "high",
                "reason": "Terminal-style tool output is a major context contributor; keep only summaries, key lines, and errors in follow-up turns.",
            }
        )
    if summary["max_turn_total_tokens"] >= 100000:
        recommendations.append(
            {
                "kind": "stop_after_heavy_turn",
                "priority": "medium",
                "reason": "At least one turn exceeded 100k total tokens; after that point, costs usually keep climbing unless the thread is reset.",
            }
        )
    if monitoring["avg_cached_input_ratio"] >= 0.7:
        recommendations.append(
            {
                "kind": "summarize_and_reset_context",
                "priority": "medium",
                "reason": "Average cached-prefix ratio is high; replace long history with a compact manual summary before continuing.",
            }
        )
    if task_protocol is not None:
        artifact_status = task_protocol["artifact_status"]
        if (
            (monitoring["max_cached_input_ratio"] >= 0.95 or monitoring["long_context_turn_count"] >= 3)
            and not artifact_status["evidence-ledger.md"]
        ):
            recommendations.append(
                {
                    "kind": "missing_evidence_ledger",
                    "priority": "high",
                    "reason": "Long-context carry-forward is present, but the task directory has no evidence-ledger.md to externalize decision-critical facts.",
                }
            )
        if (
            (monitoring["max_cached_input_ratio"] >= 0.95 or monitoring["long_context_turn_count"] >= 3)
            and not artifact_status["handoff-checklist.md"]
        ):
            recommendations.append(
                {
                    "kind": "missing_handoff_compression",
                    "priority": "high",
                    "reason": "The thread is accumulating context, but handoff-checklist.md is missing; the next implementation slice likely lacks a closed decision packet.",
                }
            )
        if (
            (monitoring["terminal_tool_output_chars"] >= 50000 or monitoring["terminal_tool_output_ratio"] >= 0.5)
            and not artifact_status["subagent-report.md"]
        ):
            recommendations.append(
                {
                    "kind": "missing_subagent_compression",
                    "priority": "medium",
                    "reason": "Tool output dominates the thread, but subagent-report.md is missing; raw investigation output may be leaking back into the main thread.",
                }
            )
        if task_protocol["claim_reference_gaps"]:
            gap_list = ", ".join(task_protocol["claim_reference_gaps"])
            recommendations.append(
                {
                    "kind": "claim_reference_gaps",
                    "priority": "medium",
                    "reason": f"Expected claim references are missing in: {gap_list}. Decision-critical summaries may not be traceable back to evidence.",
                }
            )
    if not recommendations:
        recommendations.append(
            {
                "kind": "continue_with_normal_hygiene",
                "priority": "low",
                "reason": "No dominant token inflation pattern crossed the current thresholds.",
            }
        )
    return recommendations


def build_turn_risk_summary(turn: dict[str, Any]) -> str:
    usage = turn["token_usage"]
    parts: list[str] = []
    cached = cached_ratio(usage)
    if cached >= 0.8:
        parts.append(f"cached prefix {cached:.0%}")
    if turn["terminal_tool_output_chars"] > 0:
        parts.append(f"terminal output {turn['terminal_tool_output_chars']} chars")
    elif turn["tool_output_chars"] > 2000:
        parts.append(f"tool output {turn['tool_output_chars']} chars")
    if reasoning_ratio(usage) >= 0.25:
        parts.append(f"reasoning/output {reasoning_ratio(usage):.0%}")
    if usage["total_tokens"] >= 100000:
        parts.append(f"heavy turn {usage['total_tokens']} tokens")
    return ", ".join(parts) if parts else "no dominant risk signal"


def analyze_task_dir(task_dir: Path | None) -> dict[str, Any] | None:
    if task_dir is None:
        return None
    resolved = task_dir.expanduser()
    artifact_status: dict[str, bool] = {}
    claim_reference_counts: dict[str, int] = {}
    artifact_paths: dict[str, str] = {}
    ledger_claim_ids: list[str] = []
    warnings: list[dict[str, str]] = []

    for name in REQUIRED_TASK_ARTIFACTS:
        path = resolved / name
        exists = path.exists()
        artifact_status[name] = exists
        artifact_paths[name] = str(path)
        if exists:
            text = path.read_text(encoding="utf-8")
            claims = CLAIM_ID_PATTERN.findall(text)
            claim_reference_counts[name] = len(claims)
            if name == "evidence-ledger.md":
                ledger_claim_ids = sorted(set(claims))
        else:
            claim_reference_counts[name] = 0

    for name in ("evidence-ledger.md", "handoff-checklist.md", "subagent-report.md"):
        if not artifact_status[name]:
            warnings.append(
                {
                    "kind": f"missing_{name.replace('.md', '').replace('-', '_')}",
                    "priority": "high" if name != "subagent-report.md" else "medium",
                    "reason": f"Required protocol artifact is missing: {name}",
                }
            )

    claim_reference_gaps = [
        name for name in CLAIM_REQUIRED_FILES if artifact_status[name] and claim_reference_counts[name] == 0
    ]
    if artifact_status["evidence-ledger.md"] and not ledger_claim_ids:
        warnings.append(
            {
                "kind": "empty_evidence_ledger",
                "priority": "medium",
                "reason": "evidence-ledger.md exists but contains no Claim IDs.",
            }
        )
    if claim_reference_gaps:
        warnings.append(
            {
                "kind": "missing_claim_references",
                "priority": "medium",
                "reason": "One or more core refactor artifacts do not reference any Claim IDs.",
            }
        )

    return {
        "task_dir": str(resolved),
        "artifact_paths": artifact_paths,
        "artifact_status": artifact_status,
        "claim_reference_counts": claim_reference_counts,
        "ledger_claim_ids": ledger_claim_ids,
        "claim_reference_gaps": claim_reference_gaps,
        "warnings": warnings,
    }


def self_test() -> int:
    import tempfile

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        (root / "sessions" / "2026" / "07" / "08").mkdir(parents=True)
        db_path = root / "state_5.sqlite"
        rollout_path = root / "sessions" / "2026" / "07" / "08" / "rollout-2026-07-08T01-06-31-thread-a.jsonl"
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
        conn.execute(
            "INSERT INTO threads (id, archived, model_provider, updated_at) VALUES (?, ?, ?, ?)",
            ("thread-a", 0, "openai", 1),
        )
        conn.commit()
        conn.close()
        task_dir = root / "docs" / "refactor" / "example"
        task_dir.mkdir(parents=True)
        rollout_lines = [
            {
                "timestamp": "2026-07-07T17:06:31.000Z",
                "type": "session_meta",
                "payload": {
                    "id": "thread-a",
                    "model_provider": "openai",
                    "source": {"subagent": {"other": "guardian"}},
                },
            },
            {
                "timestamp": "2026-07-07T17:06:32.000Z",
                "type": "response_item",
                "payload": {
                    "type": "function_call",
                    "call_id": "call-1",
                    "name": "read_file",
                    "arguments": "{\"path\":\"foo.txt\"}",
                    "metadata": {"turn_id": "turn-a"},
                },
            },
            {
                "timestamp": "2026-07-07T17:06:33.000Z",
                "type": "event_msg",
                "payload": {
                    "type": "token_count",
                    "info": {
                        "total_token_usage": {
                            "input_tokens": 1200,
                            "cached_input_tokens": 900,
                            "output_tokens": 110,
                            "reasoning_output_tokens": 420,
                            "total_tokens": 1310,
                        },
                        "last_token_usage": {
                            "input_tokens": 1200,
                            "cached_input_tokens": 900,
                            "output_tokens": 110,
                            "reasoning_output_tokens": 420,
                            "total_tokens": 1310,
                        },
                    },
                },
            },
            {
                "timestamp": "2026-07-07T17:06:33.500Z",
                "type": "event_msg",
                "payload": {
                    "type": "task_complete",
                    "turn_id": "turn-a",
                },
            },
        ]
        with rollout_path.open("w", encoding="utf-8", newline="") as fh:
            for item in rollout_lines:
                fh.write(json.dumps(item, ensure_ascii=False) + "\r\n")

        task_files = {
            "architecture-baseline.md": "# Architecture Baseline\r\n\r\n- Evidence Claim IDs: C-001\r\n",
            "current-brief.md": "# Current Brief\r\n\r\n- Evidence Claim IDs: C-001\r\n",
            "decision-log.md": "# Decision Log\r\n\r\n- Supported By Claim IDs: C-001\r\n",
            "open-risks.md": "# Open Risks\r\n\r\n- Triggered By Claim IDs: C-001\r\n",
            "verification-checklist.md": "# Verification Checklist\r\n\r\n- Claim IDs: C-001\r\n",
            "evidence-ledger.md": "# Evidence Ledger\r\n\r\n- Claim ID: C-001\r\n",
            "handoff-checklist.md": "# Handoff Checklist\r\n\r\n- Claim IDs: C-001\r\n",
            "subagent-report.md": "# Subagent Report\r\n\r\n- Proposed Claim ID: C-002\r\n",
        }
        for name, content in task_files.items():
            (task_dir / name).write_text(content, encoding="utf-8", newline="")

        report = analyze_threads(root, ["thread-a"], top_turns=5, verbose=False, task_dir=task_dir)
        thread = report["threads"][0]
        assert thread["thread_id"] == "thread-a"
        assert thread["summary"]["total_input_tokens"] == 1200
        assert thread["summary"]["total_cached_input_tokens"] == 900
        assert thread["summary"]["total_reasoning_output_tokens"] == 420
        assert thread["summary"]["max_turn_total_tokens"] == 1310
        assert thread["monitoring"]["avg_cached_input_ratio"] == 0.75
        assert thread["monitoring"]["terminal_tool_call_count"] == 0
        assert len(thread["top_context_blocks"]) >= 1
        assert thread["top_context_blocks"][0]["chars"] > 0
        assert thread["recommendations"][0]["kind"] == "summarize_and_reset_context"
        assert report["task_protocol"]["artifact_status"]["evidence-ledger.md"] is True
        assert report["task_protocol"]["claim_reference_counts"]["current-brief.md"] >= 1
        assert not report["task_protocol"]["claim_reference_gaps"]
        assert report["turns"][0]["turn_id"] == "turn-a"
        assert report["turns"][0]["evidence"]["cached_input_ratio"] == 0.75
        assert "reasoning/output" in report["turns"][0]["risk_summary"]
        signal_kinds = {signal["kind"] for signal in report["turns"][0]["signals"]}
        assert "high_cached_prefix" in signal_kinds
        assert "high_reasoning_output" in signal_kinds
        assert "subagent_or_guardian_overhead" in signal_kinds
        summary_signal_kinds = {signal["kind"] for signal in report["signals"]}
        assert "provider_correlation" in summary_signal_kinds
    print("self-test: ok")
    return 0


def main() -> int:
    args = parse_args()
    if args.self_test:
        return self_test()
    if not args.thread_ids:
        raise SystemExit("--thread-id is required")
    report = analyze_threads(args.codex_home, args.thread_ids, args.top_turns, args.verbose, args.task_dir)
    missing_threads = [thread for thread in report["threads"] if "thread_id not found in state_5.sqlite" in thread["notes"]]
    output_text = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output_text + "\r\n", encoding="utf-8", newline="")
    else:
        print(output_text)
    return 2 if missing_threads else 0


if __name__ == "__main__":
    raise SystemExit(main())
