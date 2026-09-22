from flask import Flask, jsonify
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST

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
    return jsonify({
        "status": "healthy"
    }), 200


@app.route("/ready")
def ready():
    return jsonify({
        "status": "ready"
    }), 200


@app.route("/metrics")
def metrics():
    return generate_latest(), 200, {
        "Content-Type": CONTENT_TYPE_LATEST
    }


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=5000
    )
