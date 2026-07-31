from inventory import apply_discount, total


def test_known_code():
    assert apply_discount([10.0], "SAVE10") == [9.0]


def test_unknown_code_is_noop():
    assert apply_discount([10.0], "BOGUS") == [10.0]


def test_total():
    assert total([1.10, 2.20]) == 3.30
