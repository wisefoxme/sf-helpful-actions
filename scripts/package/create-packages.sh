#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DEVHUB:-}" ]]; then
  echo "Set DEVHUB to your Dev Hub org alias or username." >&2
  exit 1
fi

sf package create --name GetRecordTypeId --package-type Unlocked --no-namespace \
  --path packages/get-record-type-id --target-dev-hub "$DEVHUB"

sf package create --name GetPicklistValues --package-type Unlocked --no-namespace \
  --path packages/get-picklist-values --target-dev-hub "$DEVHUB"

echo "Commit sfdx-project.json packageAliases if the CLI updated them."
