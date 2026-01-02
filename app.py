import os, time, socket

from flask import Flask, jsonify, request
from datetime import datetime, timezone

app = Flask(__name__)

def now_iso():
    return datetime.now(timezone.utc).isoformat()

@app.get("/")
def index():
    return jsonify({
        "service": "aws-signal-app",
        "hostname": socket.gethostname(),
        "timestamp": now_iso(),
        "note": "Here's some info about the EC2 instance serving you behind the ALB!"
    })

@app.get("/health")
def health():
    return jsonify({
        "status": "ok",
        "timestamp": now_iso()
    }), 200

@app.get("/work")
def work():
    ms = request.args.get("ms", default="200")
    try:
        #ms clamped to integer between 0 and 5000
        ms_int = max(0, min(5000, int(ms)))
    except ValueError:
        return jsonify({"error": "ms must be an integer"}), 400
    
    end = time.perf_counter() + (ms_int / 1000.0)
    x = 0
    while time.perf_counter() < end:
        x += 1

    return jsonify({
        "work_ms": ms_int,
        "iterations": x,
        "hostname": socket.gethostname(),
        "timestamp": now_iso()
    }), 200


if __name__ == "__main__":
    # Local dev
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))