#!/usr/bin/env python3
"""Mine opening build orders from Kane's Wrath replay files.

A .KWReplay is a recorded command stream, so build orders can be extracted
without running the game. Uses the vendored KWReplayAutoSaver parser
(Tools/KWReplayAutoSaver).

    py tools/mine_openers.py <dir-or-file>... [--faction GDI] [--minutes 6]
                             [--players 2] [--md out.md] [--json out.json]

For every player of the requested faction (Random players are attributed by
what they build) it prints the first N minutes of production/placement
orders, then aggregates the structure order, timings of key milestones, and
the first units across all games.
"""
from __future__ import annotations

import argparse
import json
import statistics
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "Tools" / "KWReplayAutoSaver"))

from chunks import Command, KWReplayWithCommands  # noqa: E402

FPS = 15  # time codes are logic frames

# Faction prefixes used in KWReplayAutoSaver's UNITNAMES ("GDI Power plant", ...)
FACTION_PREFIX = {
    "GDI": "GDI", "ST": "ST", "ZCM": "ZOCOM",
    "Nod": "Nod", "BH": "BH", "MoK": "MoK",
    "Sc": "Scrin", "R17": "R17", "T59": "T59",
}


def fmt_t(frames: int) -> str:
    s = frames // FPS
    return f"{s // 60}:{s % 60:02d}"


def load(path: Path):
    try:
        rep = KWReplayWithCommands(str(path))
        rep.fix_pid()
        # The library only decodes command payloads on demand.
        for chunk in rep.replay_body.chunks:
            for cmd in chunk.commands:
                try:
                    chunk.decode_cmd(cmd)
                except Exception:
                    cmd.cmd_ty = Command.NONE
        return rep
    except Exception as e:  # corrupt / truncated files are common in the wild
        print(f"  skip {path.name}: {type(e).__name__}: {e}", file=sys.stderr)
        return None


def player_commands(rep, pid: int, max_frames: int) -> list[Command]:
    out = []
    for chunk in rep.replay_body.chunks:
        if chunk.time_code > max_frames:
            break
        for cmd in chunk.commands:
            if cmd.player_id == pid and cmd.cmd_ty in (
                Command.PLACEDOWN, Command.QUEUE, Command.HOLD,
                Command.SELL, Command.UPGRADE, Command.POWERDOWN,
            ):
                out.append(cmd)
    return out


def cmd_name(cmd: Command) -> str:
    if cmd.cmd_ty == Command.PLACEDOWN:
        return str(cmd.building_type)
    if cmd.cmd_ty in (Command.QUEUE, Command.HOLD):
        return str(cmd.unit_ty)
    if cmd.cmd_ty == Command.UPGRADE:
        return str(cmd.upgrade)
    return ""


def infer_faction(cmds: list[Command]) -> str | None:
    """Random players: read the faction off the first named thing they build."""
    for c in cmds:
        n = cmd_name(c)
        for code, prefix in FACTION_PREFIX.items():
            if n.startswith(prefix + " "):
                return code
    return None


def strip_prefix(name: str) -> str:
    for prefix in FACTION_PREFIX.values():
        if name.startswith(prefix + " "):
            return name[len(prefix) + 1:]
    return name


KIND = {
    Command.PLACEDOWN: "place", Command.QUEUE: "queue", Command.HOLD: "cancel",
    Command.SELL: "sell", Command.UPGRADE: "upgrade", Command.POWERDOWN: "power",
}


def describe(cmds: list[Command]) -> list[dict]:
    rows = []
    for c in cmds:
        kind = KIND[c.cmd_ty]
        name = strip_prefix(cmd_name(c))
        cnt = getattr(c, "cnt", 1) if kind == "queue" else 1
        rows.append({"t": c.time_code, "kind": kind, "name": name, "cnt": cnt})
    return rows


def main() -> int:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")
        except Exception:
            pass
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--faction", default="GDI", help="faction code: GDI ST ZCM Nod BH MoK Sc R17 T59")
    ap.add_argument("--minutes", type=float, default=6.0)
    ap.add_argument("--players", type=int, default=2, help="only games with this many players (0 = any)")
    ap.add_argument("--md", help="write a markdown report here")
    ap.add_argument("--json", help="write raw per-player sequences here")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    files: list[Path] = []
    for p in map(Path, args.paths):
        if p.is_dir():
            files += sorted(x for x in p.rglob("*") if x.suffix.lower() == ".kwreplay")
        elif p.exists():
            files.append(p)
    if not files:
        print("no replays found", file=sys.stderr)
        return 1

    max_frames = int(args.minutes * 60 * FPS)
    records = []
    for f in files:
        rep = load(f)
        if rep is None:
            continue
        players = [p for p in rep.players if not p.is_observer() and "commentator" not in p.name.lower()]
        if args.players and len(players) != args.players:
            continue
        for pid, p in enumerate(rep.players):
            if p not in players:
                continue
            cmds = player_commands(rep, pid, max_frames)
            if not cmds:
                continue
            fac = p.decode_faction()
            if fac == "Rnd":
                fac = infer_faction(cmds) or "Rnd"
            if fac != args.faction:
                continue
            opp = [f"{q.name} ({q.decode_faction()})" for q in players if q is not p]
            records.append({
                "file": f.name,
                "map": getattr(rep, "map_name", "") or "",
                "player": p.name,
                "opponents": opp,
                "duration_s": rep.final_time_code // FPS,
                "orders": describe(cmds),
            })

    if not records:
        print("no matching players", file=sys.stderr)
        return 1

    # ---------------------------------------------------------------- aggregate
    struct_seq = Counter()
    first_units = Counter()
    milestones = defaultdict(list)
    unit_by_minute = defaultdict(Counter)
    for r in records:
        placed = [o["name"] for o in r["orders"] if o["kind"] == "place"]
        struct_seq[" > ".join(placed[:6])] += 1
        queued = [o for o in r["orders"] if o["kind"] == "queue"]
        for o in queued[:3]:
            first_units[o["name"]] += 1
        seen = {}
        for o in r["orders"]:
            if o["kind"] != "place":
                continue
            key = o["name"]
            seen.setdefault(key, []).append(o["t"])
        for key, ts in seen.items():
            milestones[f"1st {key}"].append(ts[0])
            if len(ts) > 1:
                milestones[f"2nd {key}"].append(ts[1])
        for o in queued:
            unit_by_minute[o["t"] // (60 * FPS)][o["name"]] += o["cnt"]

    lines = []
    lines.append(f"# Mined {args.faction} openers (first {args.minutes:g} min, {len(records)} player-games)")
    lines.append("")
    lines.append("Generated by `tools/mine_openers.py` from public replay files; times are game clock (m:ss).")
    lines.append("")
    lines.append("## Structure order (first six placements)")
    lines.append("")
    lines.append("| Games | Sequence |")
    lines.append("|---|---|")
    for seq, n in struct_seq.most_common(15):
        lines.append(f"| {n} | {seq} |")
    lines.append("")
    lines.append("## Milestone timings (median / min / max, games)")
    lines.append("")
    lines.append("| Milestone | Median | Min | Max | Games |")
    lines.append("|---|---|---|---|---|")
    for key, ts in sorted(milestones.items(), key=lambda kv: statistics.median(kv[1])):
        if len(ts) < max(2, len(records) // 10):
            continue
        lines.append(f"| {key} | {fmt_t(int(statistics.median(ts)))} | {fmt_t(min(ts))} | {fmt_t(max(ts))} | {len(ts)} |")
    lines.append("")
    lines.append("## First three unit queues")
    lines.append("")
    lines.append("| Count | Unit |")
    lines.append("|---|---|")
    for name, n in first_units.most_common(12):
        lines.append(f"| {n} | {name} |")
    lines.append("")
    lines.append("## Units queued per minute (sum over games)")
    lines.append("")
    minutes = sorted(unit_by_minute)
    for m in minutes:
        top = ", ".join(f"{k} ×{v}" for k, v in unit_by_minute[m].most_common(6))
        lines.append(f"- **{m}:00–{m + 1}:00** — {top}")
    lines.append("")
    lines.append("## Per game")
    lines.append("")
    for r in sorted(records, key=lambda r: r["file"]):
        lines.append(f"### {r['file']} — {r['player']} vs {', '.join(r['opponents'])} ({r['duration_s'] // 60} min)")
        lines.append("")
        parts = []
        for o in r["orders"]:
            if o["kind"] in ("cancel", "power"):
                continue
            tag = {"place": "", "queue": "+", "sell": "sell ", "upgrade": "upg "}[o["kind"]]
            cnt = f"×{o['cnt']}" if o["cnt"] > 1 else ""
            parts.append(f"{fmt_t(o['t'])} {tag}{o['name']}{cnt}")
        lines.append("; ".join(parts))
        lines.append("")

    report = "\n".join(lines)
    if args.md:
        Path(args.md).write_text(report, encoding="utf-8")
        print(f"wrote {args.md}")
    if args.json:
        Path(args.json).write_text(json.dumps(records, indent=1), encoding="utf-8")
        print(f"wrote {args.json}")
    if not args.quiet and not args.md:
        print(report)
    return 0


if __name__ == "__main__":
    sys.exit(main())
