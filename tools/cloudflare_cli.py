"""Run the pinned deployment CLI; credentials stay in process memory only."""
import argparse
import os
import re
import subprocess
import sys
from pathlib import Path


def guide_credentials(guide):
    """Read only Cloudflare's section; use its documented authentication method."""
    source = guide.read_text(encoding="utf-8-sig")
    match = re.search(r"(?ms)^##[^\n]*Cloudflare[^\n]*\n(.*?)(?=^##\s|\Z)", source)
    if not match:
        raise SystemExit("Cloudflare credential section not found; no secret values displayed.")
    section = match.group(1)
    # Global API keys are not necessarily hex strings. A value's shape alone
    # must not override the guide's explicit X-Auth-Key / CLI instructions.
    values = re.findall(r"`([^`\n]+)`", section)
    candidates = [v for v in values if re.fullmatch(r"[A-Za-z0-9_-]{37,100}", v)]
    # Also support a bare labeled key/token without copying the guide elsewhere.
    for line in section.splitlines():
        if re.search(r"(?:CFGlobalAPIKey|CLOUDFLARE_API_(?:KEY|TOKEN)|Global\s+API\s+Key|API\s*(?:Key|Token)|金鑰)\s*(?:\*\*)?\s*[:：=]", line, re.I):
            candidates.extend(re.findall(r"(?<![A-Za-z0-9_-])[A-Za-z0-9_-]{37,100}(?![A-Za-z0-9_-])", line))
    emails = re.findall(r"(?<![\w.+-])[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}(?![\w.-])", section)
    if not candidates:
        raise SystemExit("Cloudflare credential value could not be identified; no values displayed.")
    if re.search(r"CLOUDFLARE_API_KEY|X-Auth-Key|Global\s+API\s+Key|CFGlobalAPIKey", section, re.I):
        if not emails:
            raise SystemExit("Cloudflare email could not be identified; no values displayed.")
        return {"CLOUDFLARE_API_KEY": candidates[0], "CLOUDFLARE_EMAIL": emails[0]}
    return {"CLOUDFLARE_API_TOKEN": candidates[0]}


parser = argparse.ArgumentParser()
parser.add_argument("command", nargs="*", default=["whoami"])
args = parser.parse_args()
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
env = os.environ.copy()
guide = Path.home() / ".secrets/CREDENTIALS.md"
if not env.get("CLOUDFLARE_API_TOKEN") and not (env.get("CLOUDFLARE_API_KEY") and env.get("CLOUDFLARE_EMAIL")):
    for name, value in guide_credentials(guide).items():
        if not env.get(name):
            env[name] = value
env["CLOUDFLARE_ACCOUNT_ID"] = "4470dfd59102595c23aa4febb96211e2"
cmd = ["npx.cmd" if os.name == "nt" else "npx", "--yes", "wrangler@4.147.0"] + (args.command or ["whoami"])
result = subprocess.run(
    cmd,
    cwd=Path(__file__).resolve().parents[1],
    env=env,
    check=False,
    capture_output=True,
    text=True,
    encoding="utf-8",
    errors="replace",
)
# Authentication errors and whoami may echo identifiers; keep even those out
# of terminal/tool output. Credentials never enter a project file or argv.
for output in (result.stdout, result.stderr):
    for name in ("CLOUDFLARE_API_TOKEN", "CLOUDFLARE_API_KEY", "CLOUDFLARE_EMAIL"):
        value = env.get(name)
        if value:
            output = re.sub(re.escape(value), "[REDACTED]", output, flags=re.I)
    if output:
        print(output, end="")
raise SystemExit(result.returncode)
