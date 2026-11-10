#!/usr/bin/env bash
# Mint a fresh GitHub Actions OIDC token for pub.dev (same flow as dart-lang/setup-dart).
# Sourced from tool/release/publish_pub_packages.sh on the --execute path only.

mint_pub_dev_oidc_token() {
  local request_url="${ACTIONS_ID_TOKEN_REQUEST_URL:-}"
  local request_token="${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-}"

  if [[ -z "$request_url" ]]; then
    if declare -F fail >/dev/null 2>&1; then
      fail "execute mode requires ACTIONS_ID_TOKEN_REQUEST_URL (GitHub Actions OIDC)"
    fi
    echo "mint_pub_dev_oidc_token: execute mode requires ACTIONS_ID_TOKEN_REQUEST_URL (GitHub Actions OIDC)" >&2
    return 1
  fi
  if [[ -z "$request_token" ]]; then
    if declare -F fail >/dev/null 2>&1; then
      fail "execute mode requires ACTIONS_ID_TOKEN_REQUEST_TOKEN (GitHub Actions OIDC)"
    fi
    echo "mint_pub_dev_oidc_token: execute mode requires ACTIONS_ID_TOKEN_REQUEST_TOKEN (GitHub Actions OIDC)" >&2
    return 1
  fi

  local response
  if ! response="$(curl -fsS \
    -H "Authorization: bearer ${request_token}" \
    "${request_url}&audience=https://pub.dev")"; then
    if declare -F fail >/dev/null 2>&1; then
      fail "failed to request GitHub OIDC token for pub.dev"
    fi
    echo "mint_pub_dev_oidc_token: failed to request GitHub OIDC token for pub.dev" >&2
    return 1
  fi

  PUB_TOKEN="$(printf '%s' "$response" | ruby -rjson -e '
    j = JSON.parse(STDIN.read)
    v = j["value"]
    abort "missing OIDC token value" if v.nil? || v.empty?
    print v
  ')"
  export PUB_TOKEN
  dart pub token add https://pub.dev --env-var PUB_TOKEN
}
