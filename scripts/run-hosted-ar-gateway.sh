#!/bin/bash
set -euo pipefail
# Foreground development relay. Provider credentials stay in the ignored ml/.env.
gateway_repo="$(cd "$(dirname "$0")/.." && pwd)"
cd "$gateway_repo/ml"
gateway_uv="$(command -v uv || true)"
if [[ -z "$gateway_uv" ]]; then gateway_uv="$HOME/.local/bin/uv"; fi
command -v cloudflared >/dev/null || { echo 'Install cloudflared before starting the relay.' >&2; exit 1; }
[[ -x "$gateway_uv" && -f .env ]] || { echo 'uv and an ignored ml/.env are required.' >&2; exit 1; }
if lsof -tiTCP:8091 -sTCP:LISTEN >/dev/null; then
    echo 'Port 8091 is already occupied; do not start a second relay.' >&2; exit 1
fi
mkdir -p artifacts/hosted-ar
chmod 700 artifacts/hosted-ar
/usr/bin/python3 - <<'PY'
from pathlib import Path
import secrets
path = Path('artifacts/hosted-ar/gateway.env')
if not path.exists():
    path.write_text('COORDIT_HOSTED_AR_DEVELOPMENT=true\nCOORDIT_HOSTED_AR_TOKEN=' + secrets.token_urlsafe(40) + '\n')
path.chmod(0o600)
PY
"$gateway_uv" run --env-file .env --env-file artifacts/hosted-ar/gateway.env \
    uvicorn coordit_ml.hosted_ar_service:app --host 127.0.0.1 --port 8091 --no-access-log \
    > artifacts/hosted-ar/server.log 2>&1 &
gateway_server_pid=$!
gateway_tunnel_pid=''
gateway_cleanup() {
    if [[ -n "$gateway_tunnel_pid" ]]; then kill "$gateway_tunnel_pid" 2>/dev/null || true; fi
    kill "$gateway_server_pid" 2>/dev/null || true
}
trap gateway_cleanup EXIT
trap 'exit 130' INT TERM
cloudflared tunnel --url http://127.0.0.1:8091 --no-autoupdate \
    > artifacts/hosted-ar/tunnel.log 2>&1 &
gateway_tunnel_pid=$!
/usr/bin/python3 - <<'PY'
from pathlib import Path
import json, re, time, urllib.request
root = Path('artifacts/hosted-ar')
for _ in range(120):
    log = (root / 'tunnel.log').read_text(errors='replace') if (root / 'tunnel.log').exists() else ''
    match = re.search(r'https://[a-z0-9-]+\.trycloudflare\.com', log)
    if match:
        try:
            with urllib.request.urlopen('http://127.0.0.1:8091/health', timeout=1) as response:
                ready = response.status == 200
        except OSError:
            ready = False
        if ready:
            token = next(line.split('=', 1)[1] for line in (root / 'gateway.env').read_text().splitlines()
                         if line.startswith('COORDIT_HOSTED_AR_TOKEN='))
            if len(token) < 32: raise SystemExit('Invalid gateway credential')
            path = root / 'connection.json'
            path.write_text(json.dumps({'url': match.group(), 'token': token}))
            path.chmod(0o600)
            print('Relay ready. Private connection file: ' + str(path.resolve()))
            break
    time.sleep(0.5)
else:
    raise SystemExit('Relay startup timed out; inspect ignored server/tunnel logs.')
PY
echo 'Keep this terminal and Mac awake. A new tunnel URL requires rebuilding the test app.'
wait "$gateway_tunnel_pid"
