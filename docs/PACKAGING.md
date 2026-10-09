# Package versioning

Unlocked 2GP versions use **major.minor.patch.build** (for example `1.0.1.1`). The alias in `sfdx-project.json` maps to **major.minor.patch-build** (for example `SplitText@1.0.1-1`).

In [`sfdx-project.json`](../sfdx-project.json), each package directory sets:

- `versionName` — human-readable label (usually matches major.minor.patch)
- `versionNumber` — `major.minor.patch.NEXT`; Salesforce replaces `NEXT` with the next **build** when you run `sf package version create`

## When to bump what

| Change type | Bump | Example (was → new) | `versionNumber` before create |
|-------------|------|---------------------|-------------------------------|
| **Bugfix** (same behavior contract, fixes) | **Patch** | `1.0.0.1` → `1.0.1.1` | Set `1.0.1.NEXT` (do **not** only re-run create on `1.0.0.NEXT` for a fix release) |
| **Feature** (backward-compatible) | **Minor** | `1.0.1.1` → `1.1.0.1` | Set `1.1.0.NEXT` |
| **Breaking change** | **Major** | `1.1.0.1` → `2.0.0.1` | Set `2.0.0.NEXT` |
| **Rebuild** (same code/metadata, no semantic change) | **Build** only | `1.0.1.1` → `1.0.1.2` | Keep `1.0.1.NEXT` and run create again |

After changing `versionName` / `versionNumber` for a patch, minor, or major release, create and promote a new version, then add the subscriber Id to `packageAliases` and update [README.md](../README.md) install tables.

## Commands

```bash
sf config set target-dev-hub=<devhub>
sf package version create --package <PackageName> --installation-key-bypass \
  --code-coverage --wait 30 --target-dev-hub <devhub>
sf package version promote --package <04t-id-or-alias> --no-prompt --target-dev-hub <devhub>
```

Helper: `DEVHUB=<alias> scripts/package/create-version.sh <PackageName>`
