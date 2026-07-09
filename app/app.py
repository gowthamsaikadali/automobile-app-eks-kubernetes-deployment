"""
AutoForge - Automobile Manufacturing Dashboard (Two-Tier: Flask + MySQL/RDS)

Reads all configuration from environment variables so it works cleanly
with Kubernetes ConfigMaps (non-sensitive config) and Secrets (DB password).
"""
import os
import socket
import time
from datetime import datetime

from flask import Flask, jsonify, redirect, render_template, request, url_for

import db

app = Flask(__name__)

# ---- Configuration (populated via ConfigMap / Secret env vars) ----
APP_NAME = os.environ.get("APP_NAME", "AutoForge Dashboard")
APP_ENV = os.environ.get("APP_ENV", "dev")
APP_VERSION = os.environ.get("APP_VERSION", "2.0.0")
FEATURE_FLAG_DARK_MODE = os.environ.get("FEATURE_FLAG_DARK_MODE", "false")

START_TIME = time.time()


@app.route("/")
def index():
    vehicles = []
    db_error = None
    try:
        with db.get_cursor() as cursor:
            cursor.execute(
                "SELECT id, model, assembly_line, status, units_produced "
                "FROM vehicles ORDER BY id"
            )
            vehicles = cursor.fetchall()
    except Exception as exc:  # noqa: BLE001
        db_error = str(exc)

    return render_template(
        "index.html",
        app_name=APP_NAME,
        app_env=APP_ENV,
        app_version=APP_VERSION,
        hostname=socket.gethostname(),
        vehicles=vehicles,
        db_error=db_error,
        db_host=db.DB_HOST,
        dark_mode=FEATURE_FLAG_DARK_MODE.lower() == "true",
    )


@app.route("/vehicles/new", methods=["POST"])
def create_vehicle():
    model = request.form.get("model", "").strip()
    assembly_line = request.form.get("assembly_line", "").strip()
    status = request.form.get("status", "In Production").strip()
    units = request.form.get("units_produced", "0").strip() or "0"

    if model and assembly_line:
        with db.get_cursor() as cursor:
            cursor.execute(
                "INSERT INTO vehicles (model, assembly_line, status, units_produced) "
                "VALUES (%s, %s, %s, %s)",
                (model, assembly_line, status, int(units)),
            )
    return redirect(url_for("index"))


@app.route("/vehicles/<int:vehicle_id>/delete", methods=["POST"])
def delete_vehicle(vehicle_id):
    with db.get_cursor() as cursor:
        cursor.execute("DELETE FROM vehicles WHERE id = %s", (vehicle_id,))
    return redirect(url_for("index"))


@app.route("/api/vehicles", methods=["GET"])
def api_vehicles():
    with db.get_cursor() as cursor:
        cursor.execute(
            "SELECT id, model, assembly_line, status, units_produced FROM vehicles ORDER BY id"
        )
        rows = cursor.fetchall()
    return jsonify(vehicles=rows, count=len(rows))


@app.route("/api/vehicles", methods=["POST"])
def api_create_vehicle():
    payload = request.get_json(force=True, silent=True) or {}
    model = payload.get("model")
    assembly_line = payload.get("assembly_line")
    status = payload.get("status", "In Production")
    units = int(payload.get("units_produced", 0))

    if not model or not assembly_line:
        return jsonify(error="model and assembly_line are required"), 400

    with db.get_cursor() as cursor:
        cursor.execute(
            "INSERT INTO vehicles (model, assembly_line, status, units_produced) "
            "VALUES (%s, %s, %s, %s)",
            (model, assembly_line, status, units),
        )
        new_id = cursor.lastrowid

    return jsonify(id=new_id, model=model, assembly_line=assembly_line, status=status,
                   units_produced=units), 201


@app.route("/healthz")
def healthz():
    """Liveness probe endpoint - process is alive. Does NOT depend on the DB,
    so a slow/unreachable DB doesn't cause Kubernetes to kill/restart the pod."""
    return jsonify(status="ok"), 200


@app.route("/readyz")
def readyz():
    """Readiness probe endpoint - only marks the pod ready to receive traffic
    once it can actually reach MySQL."""
    if db.db_health_check():
        return jsonify(status="ready", uptime_seconds=round(time.time() - START_TIME, 2)), 200
    return jsonify(status="not-ready", reason="database unreachable"), 503


@app.route("/api/info")
def api_info():
    db_ok = db.db_health_check()
    return jsonify(
        app_name=APP_NAME,
        environment=APP_ENV,
        version=APP_VERSION,
        hostname=socket.gethostname(),
        db_host=db.DB_HOST,
        db_port=db.DB_PORT,
        db_name=db.DB_NAME,
        db_user=db.DB_USER,
        db_connected=db_ok,
        server_time=datetime.utcnow().isoformat() + "Z",
    )


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
