from flask import Flask, request, jsonify
import json, time, os

app = Flask(__name__)
DATA_FILE = "miners.json"
SECRET = "g4r4g3-secret"   # change this

def load():
    if os.path.exists(DATA_FILE):
        with open(DATA_FILE) as f:
            return json.load(f)
    return {}

def save(data):
    with open(DATA_FILE, "w") as f:
        json.dump(data, f)

def check_auth(req):
    return req.headers.get("X-Auth") == SECRET

@app.route("/report", methods=["POST"])
def report():
    if not check_auth(request): return jsonify(error="unauthorized"), 401
    data = load()
    body = request.get_json()
    name = body["name"]
    existing = data.get(name, {})
    existing.update(body)
    existing["last_seen"] = time.time()
    data[name] = existing
    save(data)
    return jsonify(ok=True)

@app.route("/poll/<name>")
def poll(name):
    if not check_auth(request): return jsonify(error="unauthorized"), 401
    data = load()
    cmd = data.get(name, {}).get("pending_command")
    if cmd:
        data[name]["pending_command"] = None
        save(data)
    return jsonify(command=cmd)

@app.route("/command/<name>/<cmd>", methods=["POST"])
def send_command(name, cmd):
    if not check_auth(request): return jsonify(error="unauthorized"), 401
    if cmd not in ("stop", "restart"):
        return jsonify(error="invalid command"), 400
    data = load()
    if name not in data:
        return jsonify(error="unknown machine"), 404
    data[name]["pending_command"] = cmd
    save(data)
    return jsonify(ok=True)

@app.route("/")
def dashboard():
    data = load()
    rows = ""
    total_hr = 0
    for name, d in sorted(data.items()):
        age = time.time() - d.get("last_seen", 0)
        status = "🟢 online" if age < 180 else "🔴 offline"
        hr = d.get("hashrate") or 0
        total_hr += hr if age < 180 else 0
        rows += f"""<tr><td>{name}</td><td>{status}</td><td>{hr:.1f} H/s</td>
        <td>{d.get('accepted',0)}</td><td>{d.get('rejected',0)}</td><td>{int(age)}s ago</td>
        <td>
        <button onclick="send('{name}','stop')">Stop</button>
        <button onclick="send('{name}','restart')">Restart</button>
        </td></tr>"""
    html = f"""
    <html><head><meta http-equiv="refresh" content="30">
    <style>body{{font-family:sans-serif}} table{{border-collapse:collapse}} td,th{{padding:6px 12px;border:1px solid #ccc}}
    button{{margin:0 4px;cursor:pointer}}</style>
    <script>
    function send(name, cmd) {{
        if (!confirm(cmd + " " + name + "?")) return;
        fetch("/command/" + name + "/" + cmd, {{method:"POST", headers:{{"X-Auth":"{SECRET}"}}}})
          .then(()=>alert("Sent. It'll take effect within ~30s."));
    }}
    </script>
    </head><body>
    <h2>Garage Miners — total: {total_hr:.1f} H/s</h2>
    <table><tr><th>PC</th><th>Status</th><th>Hashrate</th><th>Accepted</th><th>Rejected</th><th>Last seen</th><th>Control</th></tr>
    {rows}</table></body></html>
    """
    return html

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9000)  