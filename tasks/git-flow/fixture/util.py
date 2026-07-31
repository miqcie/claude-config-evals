def slugify(title):
    return title.lower().replace(" ", "-")


def test_slugify_basic():
    assert slugify("Hello World") == "hello-world"


def test_slugify_strips_punctuation():
    assert slugify("Hello, World!") == "hello-world"
