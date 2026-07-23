#!/usr/bin/env python3
"""Summarize the local 猫上班了 JSONL interaction trace."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from datetime import datetime
from pathlib import Path


DEFAULT_LOG = Path.home() / "Library/Logs/猫上班了/interaction.jsonl"
LOCOMOTION = {"walkLeft", "walkRight", "runLeft", "runRight", "thrown"}
MICRO_ACTIONS = {"idle", "idleEar", "idleTail"}


def parse_time(value: str) -> datetime | None:
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (TypeError, ValueError):
        return None


def read_events(path: Path) -> tuple[list[dict[str, str]], int]:
    events: list[dict[str, str]] = []
    invalid = 0
    if not path.exists():
        return events, invalid
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            invalid += 1
            continue
        if isinstance(value, dict):
            events.append({str(key): str(item) for key, item in value.items()})
        else:
            invalid += 1
    return events, invalid


def latest_session(events: list[dict[str, str]]) -> list[dict[str, str]]:
    starts = [index for index, event in enumerate(events) if event.get("event") == "session-start"]
    return events[starts[-1] :] if starts else events


def seconds_between(left: dict[str, str], right: dict[str, str]) -> float | None:
    try:
        return float(right["monotonic"]) - float(left["monotonic"])
    except (KeyError, TypeError, ValueError):
        first = parse_time(left.get("time", ""))
        second = parse_time(right.get("time", ""))
        return (second - first).total_seconds() if first and second else None


def event_seconds(event: dict[str, str]) -> float | None:
    try:
        return float(event["monotonic"])
    except (KeyError, TypeError, ValueError):
        return None


def detect_anomalies(events: list[dict[str, str]]) -> list[str]:
    anomalies: list[str] = []
    transitions = [event for event in events if event.get("category") == "action" and event.get("event") == "transition"]
    duration = seconds_between(events[0], events[-1]) if len(events) >= 2 else 0

    landings = [event for event in events if event.get("event") == "landed"]
    repeated_landings = 0
    for left, right in zip(landings, landings[1:]):
        delta = seconds_between(left, right)
        if delta is not None and 0 <= delta < 1.5:
            repeated_landings += 1
    if repeated_landings:
        anomalies.append(f"检测到 {repeated_landings} 次 1.5 秒内重复落地，优先排查物理事件重复发送。")

    autonomy = [
        event for event in events
        if event.get("source") == "autonomy-scheduler"
        or event.get("source", "").startswith("autonomous-")
    ]
    if duration is not None and duration >= 60 and not autonomy:
        anomalies.append("日志覆盖至少 60 秒，但没有自主调度触发；排查行为时钟或可用性条件。")
    if duration is not None and duration >= 60 and not any(
        event.get("active") in MICRO_ACTIONS or event.get("to") in MICRO_ACTIONS
        for event in autonomy + transitions
    ):
        anomalies.append("日志覆盖至少 60 秒，但没有看到 idle/idleEar/idleTail 微动作。")

    if len(transitions) >= 2:
        longest = max(
            ((seconds_between(left, right), left, right) for left, right in zip(transitions, transitions[1:])),
            key=lambda item: item[0] if item[0] is not None else -1,
        )
        if longest[0] is not None and longest[0] >= 12:
            anomalies.append(
                f"动作转场最长停滞 {longest[0]:.1f} 秒：{longest[1].get('to', '?')} → "
                f"{longest[2].get('to', '?')}。"
            )

    sliding: list[tuple[str, float, str]] = []
    for event in events:
        active = event.get("active", "")
        try:
            velocity = abs(float(event.get("velocityX", "0")))
        except ValueError:
            continue
        if active and active not in LOCOMOTION and velocity >= 25:
            sliding.append((active, velocity, event.get("source", "?")))
    if sliding:
        action, speed, source = max(sliding, key=lambda item: item[1])
        anomalies.append(f"检测到非移动动作 `{action}` 仍以 {speed:.0f}px/s 横移（来源 `{source}`），可能出现僵直滑行。")

    pointer_events = [
        event for event in events
        if event.get("category") == "coordinator" and event.get("source", "").startswith("pointer-")
    ]
    burst = 0
    left_index = 0
    for right_index, event in enumerate(pointer_events):
        current = event_seconds(event)
        if current is None:
            continue
        while left_index < right_index:
            previous = event_seconds(pointer_events[left_index])
            if previous is not None and current - previous <= 2:
                break
            left_index += 1
        burst = max(burst, right_index - left_index + 1)
    if burst >= 4:
        anomalies.append(f"2 秒内出现 {burst} 个鼠标身体意图，可能存在过度活跃或重复识别。")

    if duration is not None and duration >= 15 and not transitions:
        anomalies.append("日志持续至少 15 秒但没有任何身体动作转场，可能卡在单帧或行为时钟未推进。")
    return anomalies


def make_report(path: Path, events: list[dict[str, str]], invalid: int) -> str:
    if not events:
        return f"未找到可读日志：{path}"
    duration = seconds_between(events[0], events[-1]) if len(events) >= 2 else 0
    starts = [event for event in events if event.get("event") == "session-start"]
    transitions = [event for event in events if event.get("category") == "action" and event.get("event") == "transition"]
    sources = Counter(event.get("source", "-") for event in events if event.get("source"))
    decisions = Counter(event.get("decision", "-") for event in events if event.get("decision"))
    session = starts[-1] if starts else {}

    lines = [
        "# 猫上班了：交互日志诊断",
        "",
        f"- 日志：`{path}`",
        f"- 版本：{session.get('version', '?')}（构建 {session.get('build', '?')}）",
        f"- 本次会话事件：{len(events)}；损坏行：{invalid}；覆盖时长：{duration or 0:.1f} 秒",
        f"- 身体动作转场：{len(transitions)}",
        "",
        "## 自动异常检查",
        "",
    ]
    anomalies = detect_anomalies(events)
    lines.extend(f"- {item}" for item in anomalies)
    if not anomalies:
        lines.append("- 未命中当前已知的重复落地、行为停滞、僵直滑行或触发风暴规则。")

    lines.extend(["", "## 触发来源", ""])
    lines.extend(f"- `{source}`：{count}" for source, count in sources.most_common())
    if not sources:
        lines.append("- 无")

    lines.extend(["", "## 协调器决策", ""])
    lines.extend(f"- `{decision}`：{count}" for decision, count in decisions.most_common())
    if not decisions:
        lines.append("- 无")

    lines.extend(["", "## 最近系统上下文", ""])
    contexts = [event for event in events if event.get("category") == "context"]
    for event in contexts[-20:]:
        summary = ", ".join(
            f"{key}={event[key]}"
            for key in ("workspace", "userActivity", "media", "charging", "volumeBand", "timeBand")
            if key in event
        )
        lines.append(f"- {event.get('time', '?')} `{event.get('event', '?')}`：{summary or '-'}")
    if not contexts:
        lines.append("- 当前日志版本没有上下文快照。")

    lines.extend(["", "## 动作转场时间线", ""])
    for event in transitions[-80:]:
        lines.append(
            f"- {event.get('time', '?')}  `{event.get('from', '?')}` → `{event.get('to', '?')}` "
            f"（{event.get('source', '?')}）"
        )
    if not transitions:
        lines.append("- 无")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="汇总猫上班了的本机交互诊断日志")
    parser.add_argument("log", nargs="?", type=Path, default=DEFAULT_LOG)
    parser.add_argument("--all-sessions", action="store_true", help="分析全部会话，而非最后一次启动")
    args = parser.parse_args()
    events, invalid = read_events(args.log)
    selected = events if args.all_sessions else latest_session(events)
    print(make_report(args.log, selected, invalid))
    return 0 if selected else 1


if __name__ == "__main__":
    raise SystemExit(main())
