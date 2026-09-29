#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DEVHUB:-}" ]]; then
  echo "Set DEVHUB to your Dev Hub org alias or username." >&2
  exit 1
fi

PACKAGE_NAME="${1:-}"
if [[ -z "$PACKAGE_NAME" ]]; then
  echo "Usage: DEVHUB=<alias> $0 <GetRecordTypeId|GetPicklistValues>" >&2
  exit 1
fi

sf package version create --package "$PACKAGE_NAME" --installation-key-bypass \
  --code-coverage --wait 30 --target-dev-hub "$DEVHUB"

echo "Promote with: sf package version promote --package <04t> --no-prompt --target-dev-hub $DEVHUB"
