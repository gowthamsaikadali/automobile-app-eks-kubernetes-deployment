"""
AutoForge - Automobile Manufacturing Dashboard
Flask application designed to run on Kubernetes (EKS).

Reads all configuration from environment variables so that it works
cleanly with ConfigMaps (non-sensitive config) and Secrets (sensitive config).
"""
import os
import socket
import time
from datetime import datetime

from flask import Flask, jsonify, render_template

app = Flask(__name__)

# ---- Configuration (populated via ConfigMap / Secret env vars) ----
APP_NAME = os.environ.get("APP_NAME", "AutoForge Dashboard")
APP_ENV = os.environ.get("APP_ENV", "dev")
APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")
DB_HOST = os.environ.get("DB_HOST", "not-configured")
DB_NAME = os.environ.get("DB_NAME", "autoforge")
DB_USER = os.environ.get("DB_USER", "autoforge_user")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "")  # comes from a K8s Secret
FEATURE_FLAG_DARK_MODE = os.environ.get("FEATURE_FLAG_DARK_MODE", "false")

START_TIME = time.time()

# In-memory sample data (keeps the app self-contained; no external DB
# dependency is required for the EKS demo to function end-to-end)
VEHICLES = [
    {"id": 1, "model": "Falcon EV", "line": "Assembly Line 1", "status": "In Production", "units": 128},
    {"id": 2, "model": "Titan Pickup", "line": "Assembly Line 2", "status": "Quality Check", "units": 76},
    {"id": 3, "model": "Voyager Hybrid", "line": "Assembly Line 3", "status": "In Production", "units": 54},
    {"id": 4, "model": "Comet Compact", "line": "Assembly Line 1", "status": "Painting", "units": 210},
]


@app.route("/")
def index():
    return render_template(
        "index.html",
        app_name=APP_NAME,
        app_env=APP_ENV,
        app_version=APP_VERSION,
        hostname=socket.gethostname(),
        vehicles=VEHICLES,
        dark_mode=FEATURE_FLAG_DARK_MODE.lower() == "true",
    )


@app.route("/api/vehicles")
def api_vehicles():
    return jsonify(vehicles=VEHICLES, count=len(VEHICLES))


@app.route("/healthz")
def healthz():
    """Liveness probe endpoint."""
    return jsonify(status="ok"), 200


@app.route("/readyz")
def readyz():
    """Readiness probe endpoint."""
    return jsonify(status="ready", uptime_seconds=round(time.time() - START_TIME, 2)), 200


@app.route("/api/info")
def api_info():
    return jsonify(
        app_name=APP_NAME,
        environment=APP_ENV,
        version=APP_VERSION,
        hostname=socket.gethostname(),
        db_host=DB_HOST,
        db_name=DB_NAME,
        db_user=DB_USER,
        db_password_set=bool(DB_PASSWORD),
        server_time=datetime.utcnow().isoformat() + "Z",
    )


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
