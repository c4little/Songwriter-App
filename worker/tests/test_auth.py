from auth import is_authorized


def test_matching_secret_is_authorized():
    assert is_authorized("s3cret", "s3cret")


def test_wrong_secret_is_rejected():
    assert not is_authorized("nope", "s3cret")


def test_missing_values_fail_closed():
    assert not is_authorized(None, "s3cret")
    assert not is_authorized("s3cret", None)
    assert not is_authorized("", "")
