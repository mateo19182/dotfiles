#!/usr/bin/env python3
"""Operate saved VPN profiles without reading or exposing their secrets."""
import json
import subprocess
import sys


def run(*args):
    return subprocess.run(["nmcli", "--wait", "30", *args], check=True,
                          text=True, capture_output=True, timeout=40).stdout


def fields(line):
    # nmcli escapes colons and backslashes in terse output.
    result, value, escaped = [], "", False
    for char in line:
        if escaped:
            value += char
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == ":":
            result.append(value)
            value = ""
        else:
            value += char
    return result + [value]


def profiles():
    output = run("-t", "-f", "UUID,NAME,TYPE,STATE", "connection", "show")
    rows = []
    for line in output.splitlines():
        uuid, name, kind, state = fields(line)
        if kind in ("vpn", "wireguard"):
            rows.append(dict(uuid=uuid, name=name, kind=kind,
                             active=state == "activated", state=state))
    return sorted(rows, key=lambda p: p["name"].casefold())


def main():
    rows = profiles()
    if len(sys.argv) == 1:
        print(json.dumps(rows))
        return
    target = next((p for p in rows if p["uuid"] == sys.argv[1]), None)
    if not target:
        raise ValueError("VPN profile no longer exists")
    if target["active"]:
        run("connection", "down", "uuid", target["uuid"])
    else:
        # Switch rather than stack VPN default routes. Leave Tailscale alone.
        for profile in rows:
            if profile["active"]:
                run("connection", "down", "uuid", profile["uuid"])
        run("connection", "up", "uuid", target["uuid"])


if __name__ == "__main__":
    try:
        main()
    except (subprocess.SubprocessError, ValueError) as error:
        print(getattr(error, "stderr", None) or str(error), file=sys.stderr)
        sys.exit(1)
