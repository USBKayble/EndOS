import os
import sys
import time
import json
import requests
import subprocess

# ── Copilot API config ─────────────────────────────────────────────────────────
COPILOT_API_URL = "https://api.githubcopilot.com/chat/completions"
MODEL = "claude-sonnet-4-6"
GITHUB_TOKEN = os.environ["GH_TOKEN"]
REPO = os.environ["GITHUB_REPOSITORY"]

HEADERS = {
    "Authorization": f"Bearer {GITHUB_TOKEN}",
    "Content-Type": "application/json",
    # Server-side integration headers — no VS Code spoofing
    "Copilot-Integration-Id": "github-actions",
    "X-GitHub-Token": GITHUB_TOKEN,
}

STATE_FILE = ".github/agent-state.json"

# ── Tool definitions ───────────────────────────────────────────────────────────
TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "read_file",
            "description": "Read a file from the repository",
            "parameters": {
                "type": "object",
                "properties": {"path": {"type": "string"}},
                "required": ["path"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "write_file",
            "description": "Write or overwrite a file in the repository",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string"},
                    "content": {"type": "string"}
                },
                "required": ["path", "content"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "run_command",
            "description": "Run a shell command and return stdout+stderr",
            "parameters": {
                "type": "object",
                "properties": {"command": {"type": "string"}},
                "required": ["command"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "wait_for_event",
            "description": "Poll GitHub until a CI check or PR state changes. Use after pushing commits to wait for CI results.",
            "parameters": {
                "type": "object",
                "properties": {
                    "event_type": {
                        "type": "string",
                        "enum": ["ci_result", "pr_merge", "pr_close"]
                    },
                    "target_id": {
                        "type": "integer",
                        "description": "PR number for pr_merge/pr_close, or 0 to use HEAD commit for ci_result"
                    }
                },
                "required": ["event_type", "target_id"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "github_api",
            "description": "Make a GitHub REST API call. Use for opening PRs, closing issues, posting comments, merging PRs.",
            "parameters": {
                "type": "object",
                "properties": {
                    "method": {"type": "string", "enum": ["GET", "POST", "PATCH", "PUT", "DELETE"]},
                    "path": {"type": "string", "description": "API path e.g. /repos/{owner}/{repo}/pulls"},
                    "body": {"type": "object", "description": "Request body for POST/PATCH"}
                },
                "required": ["method", "path"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "save_state",
            "description": "Save current progress to the state file so a rekick can resume if this session is interrupted.",
            "parameters": {
                "type": "object",
                "properties": {
                    "summary": {"type": "string"},
                    "next_action": {"type": "string"}
                },
                "required": ["summary", "next_action"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "done",
            "description": "Signal task complete. Call only when issue is closed, PR is merged, or CI is green.",
            "parameters": {
                "type": "object",
                "properties": {"summary": {"type": "string"}},
                "required": ["summary"]
            }
        }
    }
]

# ── Tool handlers ──────────────────────────────────────────────────────────────
def handle_tool(name, args):
    branch = os.environ.get("AGENT_BRANCH", "agent/fix-unknown")

    if name == "read_file":
        try:
            return open(args["path"]).read()
        except Exception as e:
            return f"ERROR: {e}"

    elif name == "write_file":
        os.makedirs(os.path.dirname(args["path"]) or ".", exist_ok=True)
        open(args["path"], "w").write(args["content"])
        return "written"

    elif name == "run_command":
        r = subprocess.run(args["command"], shell=True, capture_output=True, text=True)
        return (r.stdout + r.stderr).strip() or "(no output)"

    elif name == "wait_for_event":
        return poll_github(args["event_type"], args["target_id"])

    elif name == "github_api":
        url = f"https://api.github.com{args['path'].replace('{owner}/{repo}', REPO)}"
        gh_headers = {"Authorization": f"Bearer {GITHUB_TOKEN}", "Accept": "application/vnd.github+json"}
        resp = requests.request(args["method"], url, headers=gh_headers, json=args.get("body"))
        try:
            return json.dumps(resp.json(), indent=2)
        except Exception:
            return resp.text

    elif name == "save_state":
        state = {"summary": args["summary"], "next_action": args["next_action"], "ts": time.time()}
        os.makedirs(".github", exist_ok=True)
        open(STATE_FILE, "w").write(json.dumps(state, indent=2))
        subprocess.run(
            f"git add {STATE_FILE} && git commit -m 'chore: update agent state' && git push -u origin {branch}",
            shell=True
        )
        return "state saved"

    elif name == "done":
        print(f"\n✅ Agent complete: {args['summary']}")
        if os.path.exists(STATE_FILE):
            os.remove(STATE_FILE)
            subprocess.run(
                f"git add {STATE_FILE} && git commit -m 'chore: clear agent state' && git push -u origin {branch} 2>/dev/null || true",
                shell=True
            )
        sys.exit(0)


def poll_github(event_type, target_id, timeout=270):
    gh_headers = {"Authorization": f"Bearer {GITHUB_TOKEN}", "Accept": "application/vnd.github+json"}
    deadline = time.time() + timeout
    print(f"⏳ Waiting for {event_type}...")

    while time.time() < deadline:
        try:
            if event_type == "ci_result":
                sha = subprocess.run("git rev-parse HEAD", shell=True, capture_output=True, text=True).stdout.strip()
                r = requests.get(f"https://api.github.com/repos/{REPO}/commits/{sha}/check-runs", headers=gh_headers)
                runs = r.json().get("check_runs", [])
                conclusions = [x["conclusion"] for x in runs if x["conclusion"]]
                if not conclusions:
                    time.sleep(20)
                    continue
                if all(c == "success" for c in conclusions):
                    return "ci_passed"
                if any(c in ("failure", "cancelled") for c in conclusions):
                    failed = [x["name"] for x in runs if x["conclusion"] in ("failure", "cancelled")]
                    return f"ci_failed: {', '.join(failed)}"

            elif event_type in ("pr_merge", "pr_close"):
                r = requests.get(f"https://api.github.com/repos/{REPO}/pulls/{target_id}", headers=gh_headers)
                pr = r.json()
                if pr.get("merged"):
                    return "pr_merged"
                if pr.get("state") == "closed":
                    return "pr_closed_unmerged"

        except Exception as e:
            return f"poll_error: {e}"

        time.sleep(20)

    return "timeout — CI did not resolve within 4.5 minutes, check manually"


# ── Main agent loop ────────────────────────────────────────────────────────────
def run_agent(task_prompt: str):
    # Always work on a dedicated branch, never push directly to main
    branch = f"agent/fix-{int(time.time())}"
    subprocess.run(f"git checkout -b {branch}", shell=True)
    os.environ["AGENT_BRANCH"] = branch
    print(f"🌿 Working on branch: {branch}")

    with open(".github/copilot-instructions.md") as f:
        system_prompt = f.read()

    # Check for saved state from a previous interrupted run
    resume_context = ""
    if os.path.exists(STATE_FILE):
        try:
            state = json.loads(open(STATE_FILE).read())
            resume_context = f"\n\n[RESUMING FROM INTERRUPTED SESSION]\nPrevious progress: {state['summary']}\nNext action: {state['next_action']}"
            print(f"📋 Resuming: {state['summary']}")
        except Exception:
            pass

    messages = [{"role": "user", "content": task_prompt + resume_context}]

    print(f"🤖 Agent starting: {task_prompt[:80]}...")

    while True:
        try:
            response = requests.post(
                COPILOT_API_URL,
                headers=HEADERS,
                json={
                    "model": MODEL,
                    "messages": [{"role": "system", "content": system_prompt}] + messages,
                    "tools": TOOLS,
                    "tool_choice": "auto",
                    "max_tokens": 4096,
                    "stream": False
                },
                timeout=120
            )
            response.raise_for_status()
            data = response.json()

        except (requests.exceptions.ConnectionError,
                requests.exceptions.Timeout,
                requests.exceptions.HTTPError) as e:
            # ── Rekick on disconnect ───────────────────────────────────────────
            print(f"⚠️  Connection lost: {e}")
            print("💾 Saving state and triggering rekick...")

            last_assistant = next(
                (m["content"] for m in reversed(messages) if m["role"] == "assistant"),
                "No progress recorded"
            )
            state = {"summary": str(last_assistant)[:500], "next_action": "resume after disconnect", "ts": time.time()}
            os.makedirs(".github", exist_ok=True)
            open(STATE_FILE, "w").write(json.dumps(state, indent=2))
            subprocess.run(
                f"git add {STATE_FILE} && git commit -m 'chore: agent disconnect - saving state' && git push -u origin {branch}",
                shell=True
            )

            requests.post(
                f"https://api.github.com/repos/{REPO}/dispatches",
                headers={"Authorization": f"Bearer {GITHUB_TOKEN}", "Accept": "application/vnd.github+json"},
                json={"event_type": "agent-rekick", "client_payload": {"task": task_prompt}}
            )
            print("🔄 Rekick dispatched. Exiting current run.")
            sys.exit(0)

        choice = data["choices"][0]
        msg = choice["message"]
        messages.append({
            "role": "assistant",
            "content": msg.get("content") or "",
            **({"tool_calls": msg["tool_calls"]} if msg.get("tool_calls") else {})
        })

        if not msg.get("tool_calls"):
            print(msg.get("content", ""))
            break

        for call in msg["tool_calls"]:
            fn_name = call["function"]["name"]
            fn_args = json.loads(call["function"]["arguments"])
            print(f"🔧 {fn_name}({list(fn_args.keys())})")

            result = handle_tool(fn_name, fn_args)

            messages.append({
                "role": "tool",
                "tool_call_id": call["id"],
                "content": str(result)
            })


if __name__ == "__main__":
    run_agent(" ".join(sys.argv[1:]))
