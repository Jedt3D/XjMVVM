#!/usr/bin/env python3
"""
XjMVVM API Test Script
======================
Tests all authenticated JSON API endpoints of the running XjMVVM app.

Usage:
    python3 test_api.py
    python3 test_api.py --host http://127.0.0.1:9090
    python3 test_api.py --user myuser --password mypass
    python3 test_api.py --signup   # auto-create test user if not exist

Endpoints tested:
    Unauthenticated access      → 401
    GET  /api/notes             → 200  list notes
    POST /api/notes (no title)  → 422  validation error
    POST /api/notes             → 201  create note
    GET  /api/notes/:id         → 200  note + embedded tags
    GET  /api/notes/999999      → 404  not found
    GET  /api/tags              → 200  list tags
    GET  /api/tags/:id          → 200  tag detail  (skipped if no tags)
    GET  /api/tags/999999       → 404  not found
"""

import argparse
import hashlib
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime

# ── ANSI colours ──────────────────────────────────────────────────────────────
GREEN  = "\033[92m"
RED    = "\033[91m"
YELLOW = "\033[93m"
CYAN   = "\033[96m"
DIM    = "\033[2m"
BOLD   = "\033[1m"
RESET  = "\033[0m"

# ── Defaults ──────────────────────────────────────────────────────────────────
DEFAULT_HOST = "http://127.0.0.1:9090"
DEFAULT_USER = "api_tester"
DEFAULT_PASS = "testpass123"


# ── Helpers ───────────────────────────────────────────────────────────────────

def sha256hex(s: str) -> str:
    """SHA-256 hex digest — mirrors the browser Web Crypto API call in login.html."""
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


def http(url: str, method: str = "GET", data: dict = None, cookie: str = None):
    """
    Minimal HTTP request wrapper.
    Returns (status_code, response_headers_dict, body_str).
    Never raises on HTTP errors — returns the error status instead.
    """
    headers = {}
    if cookie:
        headers["Cookie"] = cookie
    body_bytes = None
    if data is not None:
        body_bytes = urllib.parse.urlencode(data).encode("utf-8")
        headers["Content-Type"] = "application/x-www-form-urlencoded"

    req = urllib.request.Request(url, data=body_bytes, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status, dict(resp.headers), resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers), e.read().decode("utf-8")
    except urllib.error.URLError as e:
        raise ConnectionError(f"Cannot reach {url} — {e.reason}")


def parse_json(body: str):
    """Parse JSON body, return None on failure."""
    try:
        return json.loads(body)
    except json.JSONDecodeError:
        return None


# ── Auth ──────────────────────────────────────────────────────────────────────

def login(host: str, username: str, password: str) -> str | None:
    """
    POST /login with SHA-256-hashed password (matching the browser behaviour).
    Returns the full 'mvvm_auth=...' cookie string on success, None on failure.
    """
    hashed = sha256hex(password)
    status, headers, body = http(
        f"{host}/login",
        method="POST",
        data={"username": username, "password": hashed, "next": "/notes"},
    )
    set_cookie = headers.get("Set-Cookie", "")
    if "mvvm_auth=" in set_cookie:
        return set_cookie.split(";")[0].strip()   # "mvvm_auth=<value>"
    return None


def signup(host: str, username: str, password: str) -> bool:
    """
    POST /signup — create a new user.
    Returns True on success (redirects to /notes), False otherwise.
    """
    hashed = sha256hex(password)
    status, headers, body = http(
        f"{host}/signup",
        method="POST",
        data={"username": username, "password": hashed, "confirm": hashed},
    )
    return "mvvm_auth=" in headers.get("Set-Cookie", "")


# ── Test runner ───────────────────────────────────────────────────────────────

class Result:
    def __init__(self, name, method, path, expected, got, passed, note="", data=None):
        self.name     = name
        self.method   = method
        self.path     = path
        self.expected = expected
        self.got      = got
        self.passed   = passed
        self.note     = note
        self.data     = data


class Runner:
    def __init__(self, host: str, cookie: str = None):
        self.host    = host
        self.cookie  = cookie
        self.results: list[Result] = []

    def check(
        self,
        name: str,
        method: str,
        path: str,
        expected_status: int,
        data: dict = None,
        validate=None,   # callable(json_data) -> (bool, str)
        cookie_override = ...,  # sentinel: use self.cookie
    ) -> dict | list | None:
        """Run one test, record the result, return parsed JSON (or None)."""
        cookie = self.cookie if cookie_override is ... else cookie_override
        url    = f"{self.host}{path}"

        try:
            status, headers, body = http(url, method=method, data=data, cookie=cookie)
        except ConnectionError as e:
            self.results.append(Result(name, method, path, expected_status, "ERR", False, str(e)))
            return None

        jdata = parse_json(body)
        passed = (status == expected_status)
        note   = ""

        if passed and validate and jdata is not None:
            ok, msg = validate(jdata)
            if not ok:
                passed = False
            note = msg

        self.results.append(Result(name, method, path, expected_status, status, passed, note, jdata))
        return jdata


# ── Summary printer ───────────────────────────────────────────────────────────

def print_summary(results: list[Result], host: str, user: str, elapsed_ms: int):
    W = 66
    print()
    print(f"{BOLD}{'─' * W}{RESET}")
    print(f"{BOLD}  XjMVVM API Test Results{RESET}")
    print(f"{DIM}  {host}  ·  user: {user}  ·  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}{RESET}")
    print(f"{BOLD}{'─' * W}{RESET}")

    for r in results:
        icon    = f"{GREEN}✓{RESET}" if r.passed else f"{RED}✗{RESET}"
        m_color = CYAN if r.method == "GET" else YELLOW
        s_color = GREEN if r.passed else RED
        note    = f"  {DIM}{r.note}{RESET}" if r.note else ""
        print(
            f"  {icon}  {m_color}{r.method:<4}{RESET}  "
            f"{r.path:<32}  "
            f"{s_color}{r.got}{RESET}{DIM}(≡{r.expected}){RESET}"
            f"{note}"
        )

    passed = sum(1 for r in results if r.passed)
    total  = len(results)
    color  = GREEN if passed == total else RED
    print(f"{BOLD}{'─' * W}{RESET}")
    print(f"  {color}{BOLD}{passed}/{total} passed{RESET}  {DIM}({elapsed_ms} ms){RESET}")
    print(f"{BOLD}{'─' * W}{RESET}")
    print()


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="XjMVVM API smoke-test",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--host",     default=DEFAULT_HOST, help="App base URL (default: %(default)s)")
    parser.add_argument("--user",     default=DEFAULT_USER, help="Username (default: %(default)s)")
    parser.add_argument("--password", default=DEFAULT_PASS, help="Plaintext password (default: %(default)s)")
    parser.add_argument("--signup",   action="store_true",  help="Auto-create the test user if login fails")
    args = parser.parse_args()

    host, user, password = args.host, args.user, args.password

    print(f"\n{BOLD}XjMVVM API Tester{RESET}")
    print(f"  {DIM}Host : {host}")
    print(f"  User : {user}")
    print(f"  Time : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}{RESET}")
    print()

    start_ms = int(datetime.now().timestamp() * 1000)

    # ── Login ─────────────────────────────────────────────────────────────────
    print(f"  {CYAN}➜ Logging in as '{user}'...{RESET}", end=" ", flush=True)
    try:
        cookie = login(host, user, password)
    except ConnectionError as e:
        print(f"{RED}ERROR{RESET}")
        print(f"\n  {RED}Cannot connect:{RESET} {e}")
        print(f"  Is the app running at {host}?\n")
        sys.exit(1)

    if not cookie and args.signup:
        print(f"{YELLOW}not found — signing up...{RESET}", end=" ", flush=True)
        try:
            ok = signup(host, user, password)
        except ConnectionError as e:
            ok = False
        if ok:
            cookie = login(host, user, password)

    if not cookie:
        print(f"{RED}FAILED{RESET}")
        print(f"\n  {RED}Login failed.{RESET} Possible causes:")
        print(f"    • User '{user}' does not exist → run with --signup to create it")
        print(f"    • Wrong password")
        print(f"    • App not running at {host}\n")
        sys.exit(1)

    print(f"{GREEN}OK{RESET}  {DIM}({cookie[:48]}...){RESET}")
    print()

    runner = Runner(host, cookie)

    # ── Test 1: Unauthenticated access ────────────────────────────────────────
    runner.check(
        "Unauthenticated → 401",
        "GET", "/api/notes", 401,
        cookie_override=None,
        validate=lambda j: (
            j.get("error") == "Authentication required",
            f'error="{j.get("error")}"',
        ),
    )

    # ── Test 2: List notes ────────────────────────────────────────────────────
    notes = runner.check(
        "List notes",
        "GET", "/api/notes", 200,
        validate=lambda j: (isinstance(j, list), f"{len(j)} note(s)"),
    )

    # ── Test 3: Create note — validation error (empty title) ──────────────────
    runner.check(
        "Create note — missing title → 422",
        "POST", "/api/notes", 422,
        data={"title": "", "body": "body with no title"},
        validate=lambda j: (
            j.get("error") == "Title is required",
            f'error="{j.get("error")}"',
        ),
    )

    # ── Test 4: Create note ───────────────────────────────────────────────────
    ts = datetime.now().strftime("%H:%M:%S")
    new_note = runner.check(
        "Create note → 201",
        "POST", "/api/notes", 201,
        data={"title": f"API Test [{ts}]", "body": "Created by test_api.py"},
        validate=lambda j: (
            "id" in j and j.get("title", "").startswith("API Test"),
            f'id={j.get("id")} title="{j.get("title","")[:35]}"',
        ),
    )
    note_id = new_note.get("id") if new_note else None

    # ── Test 5: Get note by ID ────────────────────────────────────────────────
    if note_id:
        runner.check(
            f"Get note by ID ({note_id})",
            "GET", f"/api/notes/{note_id}", 200,
            validate=lambda j: (
                "tags" in j,
                f'id={j.get("id")}  tags={json.dumps(j.get("tags", []))}',
            ),
        )
    else:
        # Fall back to first note in the list
        fallback_id = notes[0].get("id") if notes else "1"
        runner.check(
            f"Get note by ID (fallback={fallback_id})",
            "GET", f"/api/notes/{fallback_id}", 200,
            validate=lambda j: ("tags" in j, f'id={j.get("id")} tags embedded'),
        )

    # ── Test 6: Get note — not found ──────────────────────────────────────────
    runner.check(
        "Get note — not found → 404",
        "GET", "/api/notes/999999", 404,
        validate=lambda j: (
            j.get("error") == "Note not found",
            f'error="{j.get("error")}"',
        ),
    )

    # ── Test 7: List tags ─────────────────────────────────────────────────────
    tags = runner.check(
        "List tags",
        "GET", "/api/tags", 200,
        validate=lambda j: (isinstance(j, list), f"{len(j)} tag(s)"),
    )

    # ── Test 8: Get tag by ID ─────────────────────────────────────────────────
    if tags and len(tags) > 0:
        tag_id = tags[0].get("id")
        runner.check(
            f"Get tag by ID ({tag_id})",
            "GET", f"/api/tags/{tag_id}", 200,
            validate=lambda j: (
                "id" in j and "name" in j,
                f'id={j.get("id")} name="{j.get("name")}"',
            ),
        )
    else:
        # No tags in DB — mark as skipped (expect 404 since there are no tags)
        runner.check(
            "Get tag by ID — no tags in DB",
            "GET", "/api/tags/1", 404,
        )

    # ── Test 9: Get tag — not found ───────────────────────────────────────────
    runner.check(
        "Get tag — not found → 404",
        "GET", "/api/tags/999999", 404,
        validate=lambda j: (
            j.get("error") == "Tag not found",
            f'error="{j.get("error")}"',
        ),
    )

    # ── Summary ───────────────────────────────────────────────────────────────
    elapsed = int(datetime.now().timestamp() * 1000) - start_ms
    print_summary(runner.results, host, user, elapsed)

    all_passed = all(r.passed for r in runner.results)
    sys.exit(0 if all_passed else 1)


if __name__ == "__main__":
    main()
