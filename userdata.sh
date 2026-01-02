#!/bin/bash
set -euo pipefail

#EC2 user data script for aws-signal-app
#Installs dependencies and starts the systemd service

APP_DIR="/opt/aws-signal-app"
APP_PORT="8080"

echo "[userdata] Updating system and installing packages..."
apt-get update -y
apt-get install -y python3 python3-pip

echo "[userdata] Creating app directory..."
mkdir -p "${APP_DIR}"

echo "[userdata] Creating requirements.txt..."
cat > "${APP_DIR}/requirements.txt" << 'EOF'
Flask==3.0.3
gunicorn==22.0.0
EOF

echo "[userdata] Creating app.py..."
cat > "${APP_DIR}/app.py" << 'EOF'
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
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
EOF

echo "[userdata] Installing Python dependencies..."
python3 -m pip install --upgrade pip
pip3 install -r "${APP_DIR}/requirements.txt"

echo "[userdata] gunicorn path: $(command -v gunicorn || true)"

echo "[userdata] Creating aws-signal-app.service..."
cat > "/etc/systemd/system/aws-signal-app.service" << EOF
[Unit]
Description=AWS Signal App (Flask via Gunicorn)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${APP_DIR}
ExecStart=/usr/bin/env gunicorn -w 2 -b 0.0.0.0:${APP_PORT} app:app
Restart=always
RestartSec=2
User=ubuntu
Group=ubuntu

[Install]
WantedBy=multi-user.target
EOF

echo "[userdata] Setting permissions of service file..."
chmod 644 /etc/systemd/system/aws-signal-app.service

echo "[userdata] Setting ownership of aws-signal-app directory..."
chown -R ubuntu:ubuntu "${APP_DIR}"

echo "[userdata] Enabling and starting service..."
systemctl daemon-reload
systemctl enable aws-signal-app.service
systemctl start aws-signal-app.service

echo "[userdata] User data script successfully finished"