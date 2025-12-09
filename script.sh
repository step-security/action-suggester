#!/bin/sh
set -e

# validate subscription status
API_URL="https://agent.api.stepsecurity.io/v1/github/$GITHUB_REPOSITORY/actions/subscription"

# Set a timeout for the curl command (3 seconds)
RESPONSE=$(curl --max-time 3 -s -w "%{http_code}" "$API_URL" -o /dev/null) || true
CURL_EXIT_CODE=$?

# Decide based on curl exit code and HTTP status
if [ $CURL_EXIT_CODE -ne 0 ]; then
  echo "Timeout or API not reachable. Continuing to next step."
elif [ "$RESPONSE" = "200" ]; then
  :
elif [ "$RESPONSE" = "403" ]; then
  echo "Subscription is not valid. Reach out to support@stepsecurity.io"
  exit 1
else
  echo "Timeout or API not reachable. Continuing to next step."
fi

if [ -n "${GITHUB_WORKSPACE}" ]; then
  cd "${GITHUB_WORKSPACE}" || exit
fi

export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

TMPFILE=$(mktemp)
git diff >"${TMPFILE}"

git stash -u

# shellcheck disable=SC2086
reviewdog \
  -name="${INPUT_TOOL_NAME:-reviewdog-suggester}" \
  -f=diff \
  -f.diff.strip=1 \
  -reporter="github-pr-review" \
  -filter-mode="${INPUT_FILTER_MODE}" \
  -fail-level="${INPUT_FAIL_LEVEL}" \
  -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
  -level="${INPUT_LEVEL}" \
  ${INPUT_REVIEWDOG_FLAGS} <"${TMPFILE}" # INPUT_REVIEWDOG_FLAGS is intentionally split to pass multiple flags

EXIT_CODE=$?

if [ "${INPUT_CLEANUP}" = "true" ]; then
  git stash drop || true
else
  git stash pop || true
fi

exit "${EXIT_CODE}"
