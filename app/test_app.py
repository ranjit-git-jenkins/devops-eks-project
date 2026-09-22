from app import app


def test_home():
    client = app.test_client()

    response = client.get("/")

    assert response.status_code == 200

    data = response.get_json()

    assert data["status"] == "running"
    assert data["environment"] == "AWS EKS"


def test_health():
    client = app.test_client()

    response = client.get("/health")

    assert response.status_code == 200

    data = response.get_json()

    assert data["status"] == "healthy"


def test_ready():
    client = app.test_client()

    response = client.get("/ready")

    assert response.status_code == 200

    data = response.get_json()

    assert data["status"] == "ready"


def test_metrics():
    client = app.test_client()

    response = client.get("/metrics")

    assert response.status_code == 200
