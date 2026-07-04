import pytest
from app import app as flask_app


@pytest.fixture
def client():
    flask_app.config["TESTING"] = True
    with flask_app.test_client() as client:
        yield client


def test_healthz(client):
    resp = client.get("/healthz")
    assert resp.status_code == 200
    assert resp.get_json()["status"] == "ok"


def test_index_loads(client):
    resp = client.get("/")
    assert resp.status_code == 200
    assert b"AutoForge" in resp.data


def test_api_vehicles(client):
    resp = client.get("/api/vehicles")
    assert resp.status_code == 200
    assert isinstance(resp.get_json(), list)
