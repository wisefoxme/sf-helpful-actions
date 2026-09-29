# sf-helpful-actions

Small, installable **Flow actions** that resolve Salesforce metadata at runtime: record type Ids and picklist options. Each action ships as its own **Unlocked package**, so you can install one or both without pulling in unrelated code.

After installation, open Flow Builder and add an **Action** element. Both actions appear under the **Utilities** category.

---

## Get Record Type ID

**Package:** `GetRecordTypeId` · **Source:** `packages/get-record-type-id/`  
**Flow action name:** Get Record Type ID

### What it does

Flows often need a record type Id when creating records dynamically—for example when the record type is chosen from a text variable, a custom setting, or a prior step rather than a fixed Id in the flow.

This action looks up the **18-character record type Id** from:

- the object’s API name (e.g. `Account`, `Case`, `MyObject__c`), and  
- the record type’s **developer name** (e.g. `PersonAccount`, `Support_Case`).

Lookup uses the Schema API (`getRecordTypeInfosByDeveloperName()`). It does not query the database and works for any object and record type that exist in the org.

### When to use it

- Create Records with `RecordTypeId` set from a developer name stored in a variable  
- Branch or assign variables when you know the record type by name, not Id  
- Avoid hard-coding Ids that differ between sandboxes and production  

### Inputs and outputs

| Flow input | Required | Description |
|------------|----------|-------------|
| SObject API Name | Yes | API name of the object |
| Record Type Developer Name | Yes | Developer name of the record type (not the label) |

| Flow output | Description |
|-------------|-------------|
| Record Type ID | Id of the matching record type |

The action supports **bulk invocations** (multiple input rows in one call), which matches Flow’s behavior when the action runs inside a loop or on a collection.

### Errors

If the object or record type cannot be resolved, the action throws an error with a short message (unknown object, unknown record type, or missing required input). Handle these in the flow’s fault path or validate inputs earlier in the flow.

---

## Get Picklist Values

**Package:** `GetPicklistValues` · **Source:** `packages/get-picklist-values/`  
**Flow action name:** Get Picklist Values

### What it does

Returns the **allowed values** for a picklist or multi-select picklist field as a collection you can loop over in Flow—useful for building choices, validation lists, or subflows that mirror field metadata.

Each entry includes:

| Field on each option | Meaning |
|----------------------|---------|
| Label | User-facing label |
| Value | API value stored on the record |
| Is Active | Whether the value is active (master describe path) |
| Is Default | Whether the value is the field default for that context |

### Two modes: master vs record type

| Record Type Developer Name | Behavior |
|----------------------------|----------|
| **Left blank** | Uses Schema describe on the field. Returns the **master** picklist value set (all active entries from `DescribeFieldResult.getPicklistValues()`). |
| **Provided** | Uses **Connect API** (`RecordUi.getPicklistValuesByRecordType`) so values match what the UI shows for that **record type**—including record-type-specific subsets. Standard describe alone cannot return those restricted values. |

Object and field API names are matched case-insensitively. Only picklist and multi-select picklist fields are supported; other field types produce a clear error.

### When to use it

- Populate a **collection variable** or **dynamic choices** from a field’s values without maintaining duplicate picklists in the flow  
- Build screens or decisions that depend on the same values as a picklist on Account, Case, or custom objects  
- When record types restrict picklists, pass **Record Type Developer Name** so the list matches create/edit for that record type  

Pair with **Get Record Type ID** when the flow knows the record type by developer name but needs picklist values for that type.

### Inputs and outputs

| Flow input | Required | Description |
|------------|----------|-------------|
| SObject API Name | Yes | API name of the object |
| Field API Name | Yes | API name of the picklist or multi-select picklist field |
| Record Type Developer Name | No | If set, values are scoped to this record type |

| Flow output | Description |
|-------------|-------------|
| Picklist Values | Collection of options (label, value, is active, is default) |

Bulk invocations are supported the same way as the record type action.

### Errors

Clear failures for unknown object, unknown field, non-picklist field, unknown record type, or missing picklist data for the given record type.

---

## Repository layout

| Path | Contents |
|------|----------|
| `packages/get-record-type-id/` | Apex invocable + tests for record type lookup |
| `packages/get-picklist-values/` | Apex invocable + tests for picklist lookup |
| `config/project-scratch-def.json` | Scratch org definition (includes Person Accounts for tests) |
| `scripts/package/` | Optional shell helpers for Dev Hub packaging |

---

## Development

**Prerequisites:** [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli), and a scratch org or sandbox for deploy/test.

Deploy one package and run its tests:

```bash
sf project deploy start --source-dir packages/get-record-type-id --test-level RunLocalTests --wait 30
sf project deploy start --source-dir packages/get-picklist-values --test-level RunLocalTests --wait 30
```

Scratch orgs should enable Person Accounts if you run the full test suite locally (`config/project-scratch-def.json`).

**Picklist tests:** The record-type-scoped code path uses ConnectApi, which does not run in data-siloed Apex tests. One test method uses `@IsTest(SeeAllData=true)` to cover that path; the rest use Schema describe only.

---

## Packaging and installation

Packages are **Unlocked 2GP** (no namespace). Package and version aliases live in `sfdx-project.json` after you register them in a Dev Hub.

**Install released versions (CLI)** — version `1.0.0.1` (`GetRecordTypeId@1.0.0-1`, `GetPicklistValues@1.0.0-1`):

```bash
sf package install --package "GetRecordTypeId@1.0.0-1" --wait 20 --target-org <target>
sf package install --package "GetPicklistValues@1.0.0-1" --wait 20 --target-org <target>
```

**Install in the browser** — open the link while logged into the org where you want the package (or sign in when prompted). Replace `p0` with the subscriber package version Id (`04t…`) from `packageAliases` in `sfdx-project.json` when you publish a new version.

| Package | Production (`login.salesforce.com`) | Sandbox (`test.salesforce.com`) |
|---------|-------------------------------------|----------------------------------|
| Get Record Type ID `1.0.0.1` | [Install](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tHs000000rc52IAA) | [Install](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tHs000000rc52IAA) |
| Get Picklist Values `1.0.0.1` | [Install](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tHs000000rc57IAA) | [Install](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tHs000000rc57IAA) |

**Create new packages in Dev Hub** (once per package):

```bash
sf config set target-dev-hub=<devhub>
sf package create --name GetRecordTypeId --package-type Unlocked --no-namespace \
  --path packages/get-record-type-id --target-dev-hub <devhub>
sf package create --name GetPicklistValues --package-type Unlocked --no-namespace \
  --path packages/get-picklist-values --target-dev-hub <devhub>
```

**Publish a version:** Use `versionNumber` `1.0.0.NEXT` in `sfdx-project.json`, then:

```bash
sf package version create --package <PackageName> --installation-key-bypass \
  --code-coverage --wait 30 --target-dev-hub <devhub>
sf package version promote --package <04t-id-or-alias> --no-prompt --target-dev-hub <devhub>
```

See `scripts/package/create-packages.sh` and `scripts/package/create-version.sh` (`DEVHUB=<alias>`).

Further reading: [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/), [Second-generation packaging](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_dev2gp.htm).
