# sf-helpful-actions

Small, installable **Flow utilities** for common automation tasks: invocable actions (record type and picklist lookup, text splitting, duplicate detection) and a **Flow Screen** component for CSV upload with DataWeave conversion. Each ships as its own **Unlocked package**, so you can install one or more without pulling in unrelated code.

After installation, open Flow Builder and add an **Action** element. **Get Record Type ID**, **Get Picklist Values**, and **Split Text** appear under **Utilities**; **Find Possible Duplicates** appears under **Duplicate Management**. For CSV import on a screen flow, add the **CSV DataWeave Dropzone** component to a **Screen** element.

<details>
<summary>Table of contents</summary>

- [Get Record Type ID](#get-record-type-id)
- [Get Picklist Values](#get-picklist-values)
- [Split Text](#split-text)
- [Find Possible Duplicates](#find-possible-duplicates)
- [CSV DataWeave Dropzone](#csv-dataweave-dropzone)
- [Repository layout](#repository-layout)
- [Development](#development)
- [Packaging and installation](#packaging-and-installation)

</details>

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

## Split Text

**Package:** `SplitText` · **Latest release:** `1.0.1.1` · **Source:** `packages/split-text/`  
**Flow action name:** Split Text

### What it does

Splits a **text** value into a **text collection** using a delimiter (default **`;`**). Each segment is trimmed; empty segments after trimming are omitted. Blank input text returns an empty collection without faulting the flow.

Apex `String.split` treats the delimiter as a **regular expression**; this action uses `Pattern.quote` so characters such as `.` or `|` are split literally, not as regex metacharacters.

### When to use it

- Turn semicolon-separated or custom-delimited strings into a collection for **Loop** or **Assignment**  
- Parse values from a long text field, screen input, or formula before iterating in Flow  
- Complement **Get Picklist Values** when the source is stored text rather than field metadata  

### Inputs and outputs

| Flow input | Required | Description |
|------------|----------|-------------|
| Text | No | String to split; null or blank returns an empty **Values** collection |
| Delimiter | No | Separator; defaults to `;` when blank |

| Flow output | Description |
|-------------|-------------|
| Values | Text collection of split segments |

Bulk invocations are supported: one output row per input row, in order.

### Errors

If **Delimiter** is whitespace-only (after trim), the action throws with a short message. Blank **Text** returns an empty **Values** collection.

---

## Find Possible Duplicates

**Package:** `FindPossibleDuplicates` · **Source:** `packages/find-possible-duplicates/`  
**Flow action name:** Find Possible Duplicates

### What it does

Runs the **active duplicate rules** for the record’s object through `Datacloud.FindDuplicates` and returns possible matches. The input record can be saved or unsaved; a saved record is never reported as a duplicate of itself.

The action groups bulk invocations by object type and sends at most **50 records per API call** (the Datacloud limit). When the object has no active duplicate rule, Datacloud throws a `HandledException`; the action catches that and sets **Error Message** on the result instead of failing the Flow.

When matches exist, the action returns the **best match** (highest confidence) plus collections of all matching records and Ids, along with duplicate rule and matching rule API names.

Optionally pass **Matching Rule API Names** to return only hits from those matching rules (developer names from `Datacloud.MatchResult.getRule()`). Salesforce still runs all active duplicate rules; this input filters what the Flow sees. Empty or omitted = all rules. If the allowlist excludes every hit, the row returns no duplicates (no error).

### When to use it

- Check for duplicates **before** creating or updating a record in Flow  
- Screen **unsaved** records built on a screen or from variables  
- Run duplicate checks in a **loop** or on a collection (bulk-safe chunking)  

Your org must have **active duplicate rules** on the objects you pass in; otherwise the action returns an error message per row.

### Inputs and outputs

| Flow input | Required | Description |
|------------|----------|-------------|
| Record | Yes | The record to check (any object with duplicate rules) |
| Matching Rule API Names | No | Collection of matching rule **developer names**; only those rules’ hits are returned |

| Flow output | Description |
|-------------|-------------|
| Has Duplicates | True when at least one possible duplicate was found |
| Duplicate Record | Best match (highest confidence); standard fields only |
| Duplicate Record ID | Id of the best match |
| Duplicate Records | All possible duplicates |
| Duplicate Record IDs | Ids of all possible duplicates |
| Match Confidence | Confidence of the best match, when the rule provides one |
| Duplicate Rule Name | API name of the duplicate rule for the best match |
| Matching Rule Name | API name of the matching rule for the best match |
| Error Message | Why the search could not run (e.g. no active duplicate rule, missing record) |

Bulk invocations are supported: one result row per input record, in order.

### Errors

- **No record was given.** — input record is null  
- **No active duplicate rule** — surfaced in **Error Message** (Flow does not fault)  
- Datacloud search failures — message in **Error Message** for that row  

**Tests:** Integration tests that call real `Datacloud.FindDuplicates` expect the **Standard Contact Duplicate Rule** to be active (typical in Developer Edition and many sandboxes). Stub-based tests cover error handling, best-match selection, chunking, and ordering without Datacloud.

---

## CSV DataWeave Dropzone

**Package:** `CsvDataWeaveDropzone` · **Latest release:** `0.1.0.1` · **Source:** `packages/csv-dataweave-dropzone/`  
**Flow component:** CSV DataWeave Dropzone (Screen flows only)

### What it does

Provides a drag-and-drop CSV upload on a **Flow Screen**. The flow author configures a deployed **DataWeave script API name** and **target object API name**. When the user uploads a file, Apex runs the script and returns in-memory **SObject** rows to the flow. **No DML** is performed; use **Create Records** (or similar) later in the flow if you need to persist data.

The target org must support **DataWeave for Apex** (`DataWeave.Script`). Subscribers deploy their own `.dwl` scripts; the package includes `CsvDataWeaveDropzoneTest` only for Apex test coverage.

### DataWeave script contract

Scripts must be deployed as DataWeave resources in the org. Typical shape:

```dataweave
%dw 2.0
input records application/csv
output application/apex
---
records map(record) -> {
  FirstName: record.first_name,
  LastName: record.last_name,
  Email: record.email
} as Object {class: "Contact"}
```

- **Input:** CSV body is passed as `records` in the Apex payload (along with `targetObjectApiName`).
- **Output:** Must be `application/apex` — a list of SObjects matching the configured target object type.

### Flow configuration

On the screen component, set:

| Property | Description |
|----------|-------------|
| Target object type (`T`) | Generic SObject type for the **Converted Records** output collection |
| DataWeave Script API Name | API name of the `.dwl` resource (no path or extension) |
| Target Object API Name | API name of the SObject type the script produces (must match `T`) |
| Label / Help Text | Optional UI copy |
| Max File Size (bytes) | Client-side limit before calling Apex (default 3,500,000) |

| Output | Description |
|--------|-------------|
| Converted Records | `{T[]}` — rows from DataWeave (not saved) |
| Record Count | Number of rows |
| Conversion Complete | True after a successful run |
| Error Message | Set when validation or conversion fails |

The component implements screen **validation**: users cannot proceed until a CSV is uploaded and converted successfully (or fix errors). Maximum CSV size on the server matches the client default (~3.5M characters).

### When to use it

- Screen flows where admins or users upload CSV files and the flow creates or updates records in bulk  
- Column mapping or cleansing logic maintained in **DataWeave** instead of Apex  
- Prototypes and imports where you want transformation separate from DML  

---

## Repository layout

| Path | Contents |
|------|----------|
| `packages/get-record-type-id/` | Apex invocable + tests for record type lookup |
| `packages/get-picklist-values/` | Apex invocable + tests for picklist lookup |
| `packages/find-possible-duplicates/` | Apex invocable + tests for duplicate detection |
| `packages/split-text/` | Apex invocable + tests for splitting text into collections |
| `packages/csv-dataweave-dropzone/` | Flow screen LWC, Apex, sample DataWeave script + tests for CSV conversion |
| `config/project-scratch-def.json` | Scratch org definition (includes Person Accounts for tests) |
| `scripts/package/` | Optional shell helpers for Dev Hub packaging |
| `docs/PACKAGING.md` | 2GP version numbering (major.minor.patch.build) and when to bump patch vs build |

---

## Development

**Prerequisites:** [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli), and a scratch org or sandbox for deploy/test.

Deploy one package and run its tests:

```bash
sf project deploy start --source-dir packages/get-record-type-id --test-level RunLocalTests --wait 30
sf project deploy start --source-dir packages/get-picklist-values --test-level RunLocalTests --wait 30
sf project deploy start --source-dir packages/find-possible-duplicates \
  --test-level RunSpecifiedTests --tests FindPossibleDuplicatesActionTest --wait 30
sf project deploy start --source-dir packages/split-text \
  --test-level RunSpecifiedTests --tests SplitTextInvocableTest --wait 30
sf project deploy start --source-dir packages/csv-dataweave-dropzone \
  --test-level RunSpecifiedTests \
  --tests DataWeaveCsvConversionServiceTest --tests DataWeaveCsvConversionControllerTest \
  --wait 30
```

Scratch orgs should enable Person Accounts if you run the full test suite locally (`config/project-scratch-def.json`).

**Picklist tests:** The record-type-scoped code path uses ConnectApi, which does not run in data-siloed Apex tests. One test method uses `@IsTest(SeeAllData=true)` to cover that path; the rest use Schema describe only.

---

## Packaging and installation

Packages are **Unlocked 2GP** (no namespace). Package and version aliases live in `sfdx-project.json` after you register them in a Dev Hub.

**Install released versions (CLI)** — Get Record Type ID and Get Picklist Values at `1.0.0.1`; **Split Text** latest is **`1.0.1.1`** (`SplitText@1.0.1-1`); Find Possible Duplicates latest is **`1.1.0.1`** (`FindPossibleDuplicates@1.1.0-1`); **CSV DataWeave Dropzone** latest is **`0.1.0.1`** (`CsvDataWeaveDropzone@0.1.0-1`):

```bash
sf package install --package "GetRecordTypeId@1.0.0-1" --wait 20 --target-org <target>
sf package install --package "GetPicklistValues@1.0.0-1" --wait 20 --target-org <target>
sf package install --package "SplitText@1.0.1-1" --wait 20 --target-org <target>
sf package install --package "FindPossibleDuplicates@1.1.0-1" --wait 20 --target-org <target>
sf package install --package "CsvDataWeaveDropzone@0.1.0-1" --wait 20 --target-org <target>
```

**Install in the browser** — open the link while logged into the org where you want the package (or sign in when prompted). Replace `p0` with the subscriber package version Id (`04t…`) from `packageAliases` in `sfdx-project.json` when you publish a new version.

| Package | Production (`login.salesforce.com`) | Sandbox (`test.salesforce.com`) |
|---------|-------------------------------------|----------------------------------|
| Get Record Type ID `1.0.0.1` | [Install](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tHs000000rc52IAA) | [Install](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tHs000000rc52IAA) |
| Get Picklist Values `1.0.0.1` | [Install](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tHs000000rc57IAA) | [Install](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tHs000000rc57IAA) |
| Find Possible Duplicates `1.1.0.1` | [Install](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tHs000000rc5HIAQ) | [Install](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tHs000000rc5HIAQ) |
| Split Text `1.0.1.1` | [Install](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tHs000000rc5gIAA) | [Install](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tHs000000rc5gIAA) |
| CSV DataWeave Dropzone `0.1.0.1` | [Install](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tHs000000rc5lIAA) | [Install](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tHs000000rc5lIAA) |

**Create new packages in Dev Hub** (once per package):

```bash
sf config set target-dev-hub=<devhub>
sf package create --name GetRecordTypeId --package-type Unlocked --no-namespace \
  --path packages/get-record-type-id --target-dev-hub <devhub>
sf package create --name GetPicklistValues --package-type Unlocked --no-namespace \
  --path packages/get-picklist-values --target-dev-hub <devhub>
sf package create --name FindPossibleDuplicates --package-type Unlocked --no-namespace \
  --path packages/find-possible-duplicates --target-dev-hub <devhub>
sf package create --name SplitText --package-type Unlocked --no-namespace \
  --path packages/split-text --target-dev-hub <devhub>
sf package create --name CsvDataWeaveDropzone --package-type Unlocked --no-namespace \
  --path packages/csv-dataweave-dropzone --target-dev-hub <devhub>
```

**Publish a version:** Set `versionName` and `versionNumber` (`major.minor.patch.NEXT`) on the package directory in `sfdx-project.json`. **Bugfixes bump patch** (e.g. `1.0.1.NEXT` → release `1.0.1.1`), not build alone on the previous patch line. See [docs/PACKAGING.md](docs/PACKAGING.md), then:

```bash
sf package version create --package <PackageName> --installation-key-bypass \
  --code-coverage --wait 30 --target-dev-hub <devhub>
sf package version promote --package <04t-id-or-alias> --no-prompt --target-dev-hub <devhub>
```

See `scripts/package/create-packages.sh` and `scripts/package/create-version.sh` (`DEVHUB=<alias>`).

Further reading: [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/), [Second-generation packaging](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_dev2gp.htm).
