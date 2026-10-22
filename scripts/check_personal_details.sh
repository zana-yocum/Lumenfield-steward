#!/usr/bin/env bash
# ST-13 · S-15
# Stops personal details from reaching the public repo. The org fills some settings with a real
# person's details: a new site's email sender and its admin, for example. Every email address or
# username under the given folder must be on a reserved example domain (example.com or *.example).
# Prints only the file and line of anything else, never the address itself, because GitHub Actions
# logs of a public repo are public too.
#
# Usage: scripts/check_personal_details.sh force-app
# Exit codes: 0 nothing personal found, 1 personal details found, 2 bad usage
set -euo pipefail

folder="${1:-}"
if [ -z "$folder" ] || [ ! -d "$folder" ]; then
  echo "Usage: scripts/check_personal_details.sh <folder>" >&2
  exit 2
fi

matches=$(grep -rnoI -E '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$folder" || true)
found=$(printf '%s\n' "$matches" | grep -v -E '@([A-Za-z0-9-]+\.)*example(\.com)?$' | grep -v '^$' || true)

if [ -n "$found" ]; then
  echo "::error::An email address or username that isn't on an example domain is in these places. Replace it with a placeholder such as name@example.com, or a value on the org's service user, before it's committed:"
  printf '%s\n' "$found" | cut -d: -f1,2 | sort -u
  exit 1
fi
echo "No personal details found in $folder."
