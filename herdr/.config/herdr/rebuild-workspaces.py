#!/usr/bin/env python3
"""Rebuild the pi-duo / pi-trio Herdr workspaces.

Use this after a Herdr server wipe, or on a new machine, to recreate the
layout. Requires a running Herdr server (`herdr server`).

PITFALL LEARNED THE HARD WAY: do NOT start two panes with `pi -c`.
`pi -c` continues "the most recent session for this cwd", so two panes
launched seconds apart both adopt the SAME session file and then write to
it concurrently. Start fresh `pi` in every pane and run `pi -c` yourself in
exactly ONE pane if you want your most recent conversation back.

Workspaces:
  pi-duo   2x2 grid -- nvim (top-left) | pi (top-right)
                      shell (bottom-left) | pi (bottom-right)
  pi-trio  three tabs, one fresh pi each
"""

import json
import os
import shutil
import subprocess
import sys
import time

HERDR = shutil.which("herdr") or os.path.expanduser("~/.local/bin/herdr")
HOME = os.path.expanduser("~")
ENV = dict(os.environ, PATH=f"{HOME}/.local/bin:" + os.environ.get("PATH", "/usr/bin:/bin"))


def h(*args):
    p = subprocess.run([HERDR, *args], capture_output=True, text=True, env=ENV)
    if p.returncode != 0:
        print(f"  !! failed: herdr {' '.join(args)}\n     {p.stderr.strip()[:300]}")
        return None
    try:
        return json.loads(p.stdout).get("result", {})
    except Exception:
        return {}


def split(pane_id, direction):
    r = h("pane", "split", "--pane", pane_id, "--direction", direction,
          "--cwd", HOME, "--no-focus")
    return r.get("pane", {}).get("pane_id") if r else None


def run(pane_id, cmd):
    h("pane", "run", pane_id, cmd)


def existing_labels():
    return {w.get("label") for w in (h("workspace", "list") or {}).get("workspaces", [])}


def main():
    if not os.path.exists(HERDR):
        sys.exit(f"herdr not found at {HERDR}")

    labels = existing_labels()
    made = []

    if "pi-duo" in labels:
        print("pi-duo already exists -- skipping")
    else:
        print("=== pi-duo (2x2: nvim | pi / shell | pi) ===")
        r = h("workspace", "create", "--label", "pi-duo", "--cwd", HOME, "--no-focus")
        if not r:
            sys.exit("workspace create failed")
        root = r["root_pane"]["pane_id"]
        print(f"  {root} -> nvim")
        run(root, "nvim")
        time.sleep(1)

        top_right = split(root, "right")
        if top_right:
            print(f"  {top_right} -> pi")
            run(top_right, "pi")
        bottom_left = split(root, "down")
        if bottom_left:
            print(f"  {bottom_left} -> shell (left at the prompt)")
        if top_right:
            bottom_right = split(top_right, "down")
            if bottom_right:
                print(f"  {bottom_right} -> pi")
                run(bottom_right, "pi")
        made.append("pi-duo")

    if "pi-trio" in labels:
        print("pi-trio already exists -- skipping")
    else:
        print("=== pi-trio (three tabs, one pi each) ===")
        r = h("workspace", "create", "--label", "pi-trio", "--cwd", HOME, "--no-focus")
        if r:
            ws = r["workspace"]["workspace_id"]
            first = r["root_pane"]["pane_id"]
            print(f"  {first} -> pi")
            run(first, "pi")
            time.sleep(3)
            for n in (2, 3):
                rt = h("tab", "create", "--workspace", ws, "--label", f"pi-{n}",
                       "--cwd", HOME, "--no-focus")
                if rt:
                    pane = rt["root_pane"]["pane_id"]
                    print(f"  {pane} -> pi")
                    run(pane, "pi")
                    time.sleep(3)
            made.append("pi-trio")

    time.sleep(4)
    print()
    print("=== agents ===")
    agents = (h("agent", "list") or {}).get("agents", [])
    seen = {}
    for a in agents:
        sess = (a.get("agent_session") or {}).get("value", "")
        seen.setdefault(sess, []).append(a["pane_id"])
    for sess, panes in seen.items():
        flag = "  <-- SHARED SESSION (bad)" if len(panes) > 1 else ""
        print(f"  {','.join(panes):16} {sess.split('/')[-1]}{flag}")
    print(f"\n{len(agents)} agents, {len(seen)} distinct sessions")
    if made:
        print("\nName them for easier targeting, e.g.:")
        for a in agents[:1]:
            print(f"  herdr agent rename {a['pane_id']} reviewer")


if __name__ == "__main__":
    main()
