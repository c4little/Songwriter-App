from fastapi.testclient import TestClient

from web import create_web_app


def client(secret: str | None = "s3cret") -> TestClient:
    return TestClient(create_web_app(get_secret=lambda: secret))


def test_hello_with_secret():
    res = client().get("/hello", headers={"X-Worker-Secret": "s3cret"})
    assert res.status_code == 200
    assert res.json() == {"status": "ok", "service": "songwriter-worker"}


def test_hello_without_secret_is_401():
    assert client().get("/hello").status_code == 401


def test_hello_with_wrong_secret_is_401():
    res = client().get("/hello", headers={"X-Worker-Secret": "wrong"})
    assert res.status_code == 401


def test_hello_fails_closed_when_server_secret_unset():
    res = client(secret=None).get("/hello", headers={"X-Worker-Secret": ""})
    assert res.status_code == 401
