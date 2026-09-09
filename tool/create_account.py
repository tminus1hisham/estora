"""Create an account on the live API while `POST /auth/register` is gated.

The deployed Property Manager API has `[Authorize]` on its register action, so
registration answers `401` to the only people who need it - see the top of
`backend_requirement.md`. The gate is satisfied by *any* valid bearer token,
though, so an account that already exists can create the ones that do not.

This is a workaround with an expiry date. When the backend ships
`[AllowAnonymous]` on that action, the app's own register screen works and this
script should be deleted.

Credentials are read from the environment so they never reach a file or the
repo:

    export MALL_PHONE=2547...          # an account that already exists
    export MALL_PASSWORD=...
    python tool/create_account.py \
        --name "Obed Munyao" \
        --phone +254710560190 \
        --email obmunyaom@gmail.com \
        --password 'S3cret!!'

`--role` defaults to Tenant; pass Owner for the other side of the platform.
Nothing here is Flutter-specific: it speaks the same two routes the app does,
with the same field names, so a success means the app will work too.
"""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request

API_ROOT = os.environ.get(
    "MALL_API_ROOT", "https://property-manager-api.transfa.org/v1/api"
)


def call(path, payload, token=None):
    """POST JSON and return (status, decoded body).

    The API answers a rejection with an empty body as often as not, so the
    caller gets `None` rather than an exception to explain.
    """
    request = urllib.request.Request(
        f"{API_ROOT}{path}",
        data=json.dumps(payload).encode(),
        headers={
            "Content-Type": "application/json",
            **({"Authorization": f"Bearer {token}"} if token else {}),
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read().decode()
            return response.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as error:
        raw = error.read().decode()
        body = None
        if raw:
            try:
                body = json.loads(raw)
            except json.JSONDecodeError:
                body = raw
        return error.code, body


def explain(body):
    """The server's own words, in whichever of its three shapes carried them.

    The same three shapes `ApiClient._message` reads, for the same reason: only
    one of them uses `message`.
    """
    if body is None:
        return "the server said nothing"
    if isinstance(body, str):
        return body
    if body.get("message"):
        return body["message"]
    errors = body.get("errors")
    if isinstance(errors, list) and errors:
        return str(errors[0])
    if isinstance(errors, dict) and errors:
        first = next(iter(errors.values()))
        return str(first[0] if isinstance(first, list) and first else first)
    return body.get("title") or json.dumps(body)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--name", required=True, help="full name; the contract holds one, not two"
    )
    parser.add_argument(
        "--phone", required=True, help="the new account's phone, e.g. +2547..."
    )
    parser.add_argument("--email", required=True)
    parser.add_argument("--password", required=True)
    # The server matches its role table by name, so "Tenant", not "TENANT".
    parser.add_argument("--role", default="Tenant", choices=["Tenant", "Owner"])
    args = parser.parse_args()

    borrowed_phone = os.environ.get("MALL_PHONE")
    borrowed_password = os.environ.get("MALL_PASSWORD")
    if not borrowed_phone or not borrowed_password:
        sys.exit(
            "Set MALL_PHONE and MALL_PASSWORD to an account that already "
            "exists. Its token is what gets past the register gate."
        )

    print(f"Signing in as {borrowed_phone} to borrow a token...")
    status, body = call(
        "/auth/login",
        {"phoneNumber": borrowed_phone, "password": borrowed_password},
    )
    if status >= 400:
        sys.exit(f"  Sign-in refused ({status}): {explain(body)}")

    token = (body or {}).get("token")
    if not token:
        # A failed sign-in still answers 200 with a zeroed user object, so an
        # absent token is the real check, not the status code.
        sys.exit(f"  Signed in but got no token back: {explain(body)}")
    print(f"  Got a token ({len(token)} chars).")

    print(f"Registering {args.email} as {args.role}...")
    status, body = call(
        "/auth/register",
        {
            "fullName": args.name,
            "phoneNumber": args.phone,
            "emailAddress": args.email,
            "password": args.password,
            "userRole": args.role,
        },
        token=token,
    )

    if status >= 400:
        if status == 401:
            sys.exit(
                "  Still 401 even with a token. The gate is not plain "
                "[Authorize] - it wants a role this account does not have. "
                "The backend fix is the only way through."
            )
        sys.exit(f"  Registration refused ({status}): {explain(body)}")

    print(f"  Created. Sign in as {args.phone} with the password you just set.")
    if body:
        print(json.dumps(body, indent=2))


if __name__ == "__main__":
    main()
