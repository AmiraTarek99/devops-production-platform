import pytest
from app import app

@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client

def test_health(client):
    r = client.get("/api/health")
    assert r.status_code == 200
    assert r.json["status"] == "healthy"

def test_ready(client):
    r = client.get("/api/ready")
    assert r.status_code == 200

def test_info(client):
    r = client.get("/api/info")
    assert r.status_code == 200
    assert r.json["service"] == "backend-api"
