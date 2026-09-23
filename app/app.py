import os

from flask import Flask, jsonify, Response
from prometheus_client import (
    Counter,
    CollectorRegistry,
    multiprocess,
    generate_latest,
    CONTENT_TYPE_LATEST,
)

app = Flask(__name__)

REQUEST_COUNT = Counter(
    "webapp_requests_total",
    "Total number of requests received by the application"
)


@app.route("/")
def home():
    REQUEST_COUNT.inc()

    return jsonify({
        "application": "DevOps EKS Course Project",
        "status": "running",
        "environment": "AWS EKS",
        "message": "Application is running successfully"
    })


@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200


@app.route("/ready")
def ready():
    return jsonify({"status": "ready"}), 200


@app.route("/metrics")
def metrics():
    multiproc_dir = os.environ.get("PROMETHEUS_MULTIPROC_DIR")

    if multiproc_dir and os.path.isdir(multiproc_dir):
        registry = CollectorRegistry()
        multiprocess.MultiProcessCollector(registry)
        metrics_data = generate_latest(registry)
    else:
        # Local development / pytest mode
        metrics_data = generate_latest()

    return Response(
        metrics_data,
        status=200,
        content_type=CONTENT_TYPE_LATEST
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
