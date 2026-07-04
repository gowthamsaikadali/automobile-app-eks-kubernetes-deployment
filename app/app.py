import os
from flask import Flask, render_template, request, redirect, url_for, jsonify

app = Flask(__name__)

# In-memory store, deliberately simple — the point of this project is the
# platform around the app (K8s, autoscaling, CI/CD), not the app's own
# data layer. Swap this for real RDS/MySQL calls if you want to extend it.
vehicles = [
    {"id": 1, "model": "Falcon X1", "type": "Sedan", "units_produced": 1200},
    {"id": 2, "model": "Ranger T4", "type": "Truck", "units_produced": 850},
    {"id": 3, "model": "Comet EV",  "type": "Electric", "units_produced": 430},
]

# Read at request time (not import time) so a ConfigMap change followed by
# a pod restart picks up new values without a code change.
def get_env_config():
    return {
        "app_env": os.environ.get("APP_ENV", "unknown"),
        "log_level": os.environ.get("LOG_LEVEL", "info"),
        "feature_new_ui": os.environ.get("FEATURE_NEW_UI", "false") == "true",
    }


@app.route("/healthz")
def healthz():
    # This is the endpoint the Kubernetes liveness/readiness probes hit.
    # Keep it fast and dependency-free — if it ever calls the DB and the DB
    # is slow, Kubernetes will start killing healthy pods for the wrong reason.
    return jsonify(status="ok"), 200


@app.route("/")
def index():
    config = get_env_config()
    return render_template("index.html", vehicles=vehicles, config=config)


@app.route("/add", methods=["GET", "POST"])
def add_vehicle():
    if request.method == "POST":
        new_id = max([v["id"] for v in vehicles], default=0) + 1
        vehicles.append({
            "id": new_id,
            "model": request.form["model"],
            "type": request.form["type"],
            "units_produced": int(request.form["units_produced"]),
        })
        return redirect(url_for("index"))
    return render_template("add.html")


@app.route("/api/vehicles")
def api_vehicles():
    # Simple JSON endpoint — also handy for the load-testing step
    # (hitting this repeatedly is what drives CPU up to trigger HPA).
    return jsonify(vehicles)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
