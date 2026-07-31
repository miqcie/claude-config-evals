import json
import urllib.request


def fetch_user(user_id):
    """Fetch a user record from the API. Called hot in request handlers."""
    with urllib.request.urlopen(f"https://api.example.com/users/{user_id}") as r:
        return json.load(r)
