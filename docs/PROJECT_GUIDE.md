# Synthea Healthcare Warehouse — Complete Project Guide

This document explains **what happens in every model**, **how columns are transformed**, **every test**, and **dbt commands** you can run. For a shorter overview, see [README.md](../README.md).

---

## Table of Contents

1. [What This Project Does](#1-what-this-project-does)
2. [Transformation Macros](#2-transformation-macros)
3. [RAW Sources](#3-raw-sources)
4. [Staging Models](#4-staging-models)
5. [Intermediate Models](#5-intermediate-models)
6. [Marts Models](#6-marts-models)
7. [Reporting Models](#7-reporting-models)
8. [Semantic Layer](#8-semantic-layer)
9. [All Tests](#9-all-tests)
10. [dbt Commands Reference](#10-dbt-commands-reference)

---

## 1. What This Project Does

Synthea generates **synthetic patient healthcare data** (CSV → Snowflake `RAW`). This dbt project:

1. **Cleans and standardizes** RAW tables in **STAGING** (views).
2. **Applies business logic** in **INTERMEDIATE** (insurance periods, enriched encounters, readmissions).
3. **Builds a star schema** in **MARTS** (dimensions + facts with surrogate keys).
4. **Pre-aggregates KPIs** in **REPORTING** (monthly encounters, readmission rates, etc.).
5. **Exposes metrics** via the **Semantic Layer** (`models/semantic/metrics.yml`).
6. **Logs every test run** to `REPORTING.DBT_TEST_RESULTS`.

```
RAW (9 tables, not built by dbt)
  ↓
STAGING (9 views) — rename, parse dates, Yes/No flags
  ↓
INTERMEDIATE (3 views) — SCD2 periods, encounter enrichment, readmission logic
  ↓
MARTS (5 dims + 3 facts, tables) — surrogate keys, point-in-time patient join
  ↓
REPORTING (5 tables) — dashboard-ready aggregates
  ↓
Semantic Layer (YAML) — MetricFlow metrics for BI tools
```

| Snowflake schema | dbt folder | Materialization |
|------------------|------------|-----------------|
| `RAW` | sources only | External load |
| `STAGING` | `models/staging/synthea/` | View |
| `INTERMEDIATE` | `models/intermediate/synthea/` | View |
| `MARTS` | `models/marts/synthea/` | Table |
| `REPORTING` | `models/reporting/synthea/` | Table |

---

## 2. Transformation Macros

Reusable logic in `macros/`:

| Macro | Purpose |
|-------|---------|
| `synthea_rename_id` | `id` → `{entity}_id` |
| `synthea_parse_date` | String → `date` |
| `synthea_parse_timestamp` | String → `timestamp_ntz` |
| `synthea_title_case` | Init-cap names/text |
| `synthea_upper_trim` | Uppercase + trim (e.g. gender → `M`/`F`) |
| `synthea_digits_only` | Strip non-digits (SSN, license) |
| `synthea_address_*` | Standardize address fields |
| `synthea_phone_number` | Normalize phone |
| `synthea_yes_no_from_boolean` | SQL expression → `'Yes'` / `'No'` |
| `synthea_reason_code` / `synthea_reason_description` | Reason code fields |
| `synthea_loaded_at` | `current_timestamp()` audit column |
| `synthea_surrogate_key` | `md5(concat(...))` surrogate keys |
| `synthea_date_key` | Date → `YYYYMMDD` integer for dim join |
| `generate_schema_name` | Maps layer → `STAGING`, `MARTS`, etc. |
| `log_test_results` | Writes test results to audit table on `on-run-end` |

---

## 3. RAW Sources

Defined in `models/staging/synthea/_synthea__sources.yml`. Database: `SYNTHEA_WAREHOUSE`, schema: `RAW`.

| Source table | Staging model |
|--------------|---------------|
| `PATIENTS` | `stg_synthea__patients` |
| `ENCOUNTERS` | `stg_synthea__encounters` |
| `CONDITIONS` | `stg_synthea__conditions` |
| `MEDICATIONS` | `stg_synthea__medications` |
| `PROCEDURES` | `stg_synthea__procedures` |
| `PROVIDERS` | `stg_synthea__providers` |
| `ORGANIZATIONS` | `stg_synthea__organizations` |
| `PAYERS` | `stg_synthea__payers` |
| `PAYER_TRANSITIONS` | `stg_synthea__payer_transitions` |

---

## 4. Staging Models

**Grain:** One row per source record (except payer_transitions = one row per coverage year range).

**Materialization:** View in `STAGING` schema. **Contracts enforced** in `_synthea__models.yml`.

---

### `stg_synthea__patients`

**Source:** `RAW.PATIENTS`  
**Purpose:** Standardize patient demographics and home address.

| Output column | Source / transformation |
|---------------|-------------------------|
| `patient_id` | `id` → renamed |
| `birth_date`, `death_date` | Parsed dates |
| `social_security_number`, `drivers_license_number` | Digits only |
| `passport_number` | As-is |
| `name_prefix`, `first_name`, `last_name`, etc. | Title case |
| `race`, `ethnicity`, `marital_status` | Title case |
| `patient_gender` | `gender` → upper trim (`M`, `F`, etc.) |
| `birth_place` | Title case |
| `home_address_*` | Address macros (line, city, county, state, zip, lat/lon) |
| `healthcare_expenses`, `healthcare_coverage` | As-is (float) |
| `loaded_at` | Current timestamp |

---

### `stg_synthea__encounters`

**Source:** `RAW.ENCOUNTERS`  
**Purpose:** Clinical visits with costs and visit-type flags.

| Output column | Source / transformation |
|---------------|-------------------------|
| `encounter_id` | `id` |
| `started_at`, `ended_at` | `START`, `STOP` → timestamps |
| `patient_id`, `provider_id`, `organization_id`, `payer_id` | As-is |
| `encounter_class` | Raw class string |
| `is_emergency_visit` | `'Yes'` if class = emergency |
| `is_inpatient_visit` | `'Yes'` if class = inpatient |
| `encounter_code`, `encounter_description` | `code`, `description` |
| `base_encounter_cost`, `total_claim_cost` | As-is |
| `encounter_payer_coverage` | `payer_coverage` renamed |
| `encounter_reason_code`, `encounter_reason_description` | Reason macros |
| `loaded_at` | Current timestamp |

---

### `stg_synthea__conditions`

| Output column | Transformation |
|---------------|----------------|
| `started_at`, `stopped_at` | Parsed timestamps |
| `patient_id`, `encounter_id` | As-is |
| `condition_code`, `condition_description` | `code`, `description` |
| `loaded_at` | Current timestamp |

---

### `stg_synthea__medications`

| Output column | Transformation |
|---------------|----------------|
| `started_at`, `stopped_at` | Parsed timestamps |
| `patient_id`, `payer_id`, `encounter_id` | As-is |
| `medication_code`, `medication_description` | Renamed from `code`, `description` |
| `medication_base_cost`, `medication_total_cost` | Renamed costs |
| `medication_dispense_count` | `dispenses` |
| `medication_reason_*`, `medication_payer_coverage` | Reason / coverage |
| `loaded_at` | Current timestamp |

---

### `stg_synthea__procedures`

| Output column | Transformation |
|---------------|----------------|
| `procedure_at` | `DATE` → timestamp |
| `patient_id` | `patient` column |
| `encounter_id` | `encounter` column |
| `procedure_code`, `procedure_description` | Renamed |
| `procedure_base_cost` | `base_cost` |
| `procedure_reason_*` | Reason macros |
| `loaded_at` | Current timestamp |

---

### `stg_synthea__providers`

| Output column | Transformation |
|---------------|----------------|
| `provider_id` | `id` |
| `organization_id` | `organization` |
| `provider_name` | `name` → entity name |
| `provider_gender` | Upper trim |
| `provider_specialty` | `speciality` → title case |
| `address_*` | Address macros |
| `provider_utilization` | `utilization` |
| `loaded_at` | Current timestamp |

---

### `stg_synthea__organizations`

| Output column | Transformation |
|---------------|----------------|
| `organization_id` | `id` |
| `organization_name` | `name` |
| `address_*` | Address macros |
| `organization_phone_number` | Phone macro |
| `organization_revenue`, `organization_utilization` | As-is |
| `loaded_at` | Current timestamp |

---

### `stg_synthea__payers`

| Output column | Transformation |
|---------------|----------------|
| `payer_id` | `id` |
| `payer_name` | `name` |
| `headquarters_address_*` | HQ address fields |
| `payer_phone_number` | Phone |
| `amount_covered`, `amount_uncovered`, `payer_revenue` | Financial metrics |
| `covered_*`, `uncovered_*`, `unique_customers`, `qols_avg`, `member_months` | Payer stats |
| `loaded_at` | Current timestamp |

---

### `stg_synthea__payer_transitions`

| Output column | Transformation |
|---------------|----------------|
| `patient_id` | `patient` |
| `coverage_start_year`, `coverage_end_year` | Year integers |
| `payer_id` | `payer` |
| `coverage_ownership_type` | `ownership` → title case |
| `loaded_at` | Current timestamp |

---

## 5. Intermediate Models

**Materialization:** View in `INTERMEDIATE` schema.

---

### `int_synthea__patient_insurance_periods`

**Grain:** One row per **patient × insurance coverage period** (SCD2 prep).  
**Sources:** `stg_synthea__patients`, `stg_synthea__payer_transitions`, `stg_synthea__payers`

| Output column | Logic |
|---------------|-------|
| `patient_id`, demographics | From `stg_synthea__patients` |
| `payer_id`, `payer_name` | From transitions + payers join |
| `effective_from` | `date_from_parts(coverage_start_year, 1, 1)` |
| `effective_to` | End of `coverage_end_year` (or Dec 31 current year if null) |
| `is_current` | `'Yes'` if end year ≥ current year |
| `scd2_version` | `row_number()` per patient by start year |

---

### `int_synthea__encounter_enriched`

**Grain:** One row per encounter.  
**Sources:** `stg_synthea__encounters` + providers, organizations, payers

| Output column | Logic |
|---------------|-------|
| `encounter_start_time`, `encounter_stop_time` | Renamed from `started_at`, `ended_at` |
| `duration_hours` | `datediff(hour, start, stop)` |
| `care_setting` | Mapped: wellness, ambulatory, emergency, urgent_care, inpatient, other |
| `patient_out_of_pocket` | `total_claim_cost - encounter_payer_coverage` |
| `payer_coverage_pct` | `(payer_coverage / total_claim_cost) * 100` |
| `is_inpatient` | From `is_inpatient_visit` |
| Provider/org/payer attributes | Left joins to staging dims |

---

### `int_synthea__readmission_flags`

**Grain:** One row per **inpatient discharge** (index encounter).  
**Logic:** First encounter after discharge = readmission; flags for 7/30/90 days.

| Output column | Logic |
|---------------|-------|
| `index_encounter_id` | Inpatient encounter with `ended_at` = discharge |
| `readmit_encounter_id` | First later encounter for same patient |
| `discharge_date`, `readmit_date` | Timestamps |
| `days_to_readmission` | Days between discharge and readmit |
| `has_readmission` | Readmit exists |
| `is_7_day_readmission`, `is_30_day_readmission`, `is_90_day_readmission` | Window flags (`'Yes'`/`'No'`) |
| `is_same_organization_readmission` | Same org on index and readmit |

---

## 6. Marts Models

**Materialization:** Table in `MARTS` schema.

---

### Dimensions

#### `dim_synthea__date`
**Grain:** One row per calendar day (1900-01-01 → 2030-12-31). **MetricFlow time spine.**

| Column | Logic |
|--------|-------|
| `date_key` | `YYYYMMDD` integer |
| `calendar_date` | Date spine |
| `day_of_month`, `day_of_week`, `week_of_year`, `month_*`, `quarter_*`, `year_*` | Extracted |
| `fiscal_year`, `fiscal_quarter` | Oct–Sep fiscal calendar |
| `year_month`, `year_quarter` | Formatted strings |
| `is_weekend`, `is_month_start`, `is_month_end` | Yes/No flags |

#### `dim_synthea__patient`
**Grain:** One row per **insurance period** (SCD2).

| Column | Logic |
|--------|-------|
| `patient_key` | `md5(patient_id \|\| effective_from)` |
| All attributes | Pass-through from `int_synthea__patient_insurance_periods` |

#### `dim_synthea__provider`, `dim_synthea__organization`, `dim_synthea__payer`
**Grain:** One row per entity. Surrogate key = `md5(entity_id)`.

---

### Facts

#### `fct_synthea__encounters`
**Grain:** One row per encounter.

| Column | Logic |
|--------|-------|
| `encounter_key` | `md5(encounter_id)` |
| `patient_key` | `md5(patient_id \|\| effective_from)` — join insurance period where encounter date ∈ [effective_from, effective_to] |
| `provider_key`, `organization_key`, `payer_key` | `md5` of respective IDs |
| `encounter_date_key` | From `encounter_start_time` |
| Costs | **`greatest(..., 0)`** — negative costs clamped to 0 |
| `duration_hours` | `< 0` → 0; `> 1000` → null |
| `period_match_rank` | Dedupe to one insurance period per encounter |

#### `fct_synthea__readmissions`
**Grain:** One row per index discharge.

| Column | Logic |
|--------|-------|
| `readmission_key` | `md5(index_encounter_id \|\| readmit_encounter_id)` |
| `patient_key`, `organization_key` | Point-in-time insurance join on discharge date |
| `discharge_date_key`, `readmit_date_key` | Date keys |
| Readmission flags | Pass-through from intermediate |

**Note:** No `payer_key` on this fact — join to encounters for payer analysis.

#### `fct_synthea__clinical_events`
**Grain:** One row per clinical event (condition, procedure, or medication).

| Column | Logic |
|--------|-------|
| `clinical_event_key` | `md5` of patient, encounter, type, code, start |
| `event_type` | `'condition'`, `'procedure'`, or `'medication'` |
| `patient_key`, `encounter_key`, `event_date_key` | Surrogate keys + insurance period join |
| `is_chronic_condition` | Condition with `stopped_at is null` → `'Yes'` |

---

## 7. Reporting Models

**Materialization:** Table in `REPORTING` schema.

---

### `rpt_synthea__monthly_encounters`
**Grain:** Month × care_setting × payer_name

Aggregates from `fct_synthea__encounters` + `dim_synthea__date` + `dim_synthea__payer`: encounter counts, ED/inpatient counts, costs, duration, payer coverage %.

---

### `rpt_synthea__readmission_rate_monthly`
**Grain:** Month × primary_diagnosis × payer_name

- Primary diagnosis from `fct_synthea__clinical_events` (latest condition per index encounter).
- `readmission_30day_rate_pct` = readmits / discharges × 100.
- `quality_flag`: `'Alert'` if rate > 15%, else `'OK'`.

---

### `rpt_synthea__cost_of_care_annual`
**Grain:** Patient × fiscal_year

Annual spend per patient; `cost_category`: High (>100k), Medium (>50k), Low.

---

### `rpt_synthea__provider_performance`
**Grain:** Provider

Volume, cost, readmission rate per provider; `quality_flag`: High Risk (Readmission), High Cost, Low Volume, or OK.

---

### `rpt_synthea__high_risk_patients`
**Grain:** Patient (filtered to Moderate+ risk)

Uses **latest insurance period** per patient (`qualify row_number() ... effective_from desc`). Risk scoring from readmissions, ED visits, cost, chronic conditions.

| `risk_level` | Criteria (simplified) |
|--------------|----------------------|
| Very High | ≥2 readmits or 1 readmit + ≥2 chronic conditions |
| High | Cost >100k, or ≥4 ED visits, or ≥3 chronic conditions |
| Moderate | ≥2 chronic conditions |

---

## 8. Semantic Layer

File: `models/semantic/metrics.yml` (YAML only — not a Snowflake table).

| Semantic model | Source | Grain |
|----------------|--------|-------|
| `encounters` | `fct_synthea__encounters` | Per encounter |
| `readmissions` | `fct_synthea__readmissions` | Per discharge |
| `patients` | `dim_synthea__patient` | Per insurance period |
| `providers`, `payers`, `organizations` | Respective dims | Per entity |

**Key metrics:** `total_encounters`, `readmission_rate_30day`, `ed_utilization_rate`, `avg_cost_per_encounter`, `patient_cost_burden`, `insurance_coverage_rate`, etc.

Yes/No flags in measures use: `case when flag = 'Yes' then 1 else 0 end`.

---

## 9. All Tests

Tests run via `dbt test` / `dbt build`. Results log to `REPORTING.DBT_TEST_RESULTS`.

### 9.1 Custom SQL Tests (`tests/`)

| Test | Layer | What it checks |
|------|-------|----------------|
| `test_stg_encounters_temporal_consistency` | Staging | `ended_at >= started_at` on encounters |
| `test_stg_medications_temporal_consistency` | Staging | `stopped_at >= started_at` on medications (**known fail: 5 Synthea rows**) |
| `test_stg_costs_non_negative` | Staging | No negative costs on encounters, medications, procedures |
| `test_stg_utilization_non_negative` | Staging | No negative utilization on orgs/providers |
| `test_stg_payers_coverage_consistency` | Staging | Payer amounts ≥ 0 |
| `test_int_insurance_effective_dates` | Intermediate | `effective_from <= effective_to` |
| `test_int_scd2_no_overlapping_periods` | Intermediate | No overlapping insurance periods per patient |
| `test_int_scd2_only_one_current_per_patient` | Intermediate | At most one `is_current = 'Yes'` per patient |
| `test_int_encounter_temporal_consistency` | Intermediate | Stop time ≥ start time |
| `test_int_encounter_payer_coverage_lte_total` | Intermediate | Payer coverage ≤ total claim cost |
| `test_int_readmission_dates` | Intermediate | Readmit after discharge; days ≥ 0 |
| `test_int_readmission_flag_consistency` | Intermediate | 7-day ⊆ 30-day ⊆ 90-day; flags match `has_readmission` |
| `test_marts_encounter_costs_and_duration` | Marts | No negative costs; duration 0–1000 on fact |
| `test_marts_readmissions_link_to_encounters` | Marts | Every readmission index exists in encounters fact |
| `test_rpt_readmission_rate_recomputed` | Reporting | Readmission rate between 0 and 100 |

### 9.2 Schema Tests (YAML)

Defined in `_synthea__models.yml`, `_int_synthea__models.yml`, `_marts__models.yml`, `_reporting__models.yml`.

**Common test types:**

| Test type | Purpose |
|-----------|---------|
| `unique` | Primary/surrogate key uniqueness |
| `not_null` | Required fields populated |
| `accepted_values` | Categorical values in allowed list (`Yes`/`No`, care settings, risk levels) |
| `relationships` | Foreign key exists in parent model |
| `dbt_utils.expression_is_true` | Custom SQL expression (e.g. `>= 0`, `between 0 and 100`) |

**Tests with `severity: warn` (do not fail build):**

- `fct_synthea__encounters.patient_key` → `dim_synthea__patient` (~29k orphan rows — encounter outside insurance period)
- `fct_synthea__readmissions.patient_key` → `dim_synthea__patient` (~902 rows)
- Several intermediate cost/payer warnings
- `int_synthea__patient_insurance_periods.patient_gender` accepted values

### 9.3 Test Audit Log

After every `dbt test` or `dbt build`, `log_test_results` writes to `REPORTING.DBT_TEST_RESULTS`:

| Column | Meaning |
|--------|---------|
| `model_layer` | staging \| intermediate \| marts \| reporting |
| `target_model_schema` | Actual Snowflake schema (`MARTS`, etc.) |
| `schema_name` | Same as target model schema (not profile default) |
| `status` | pass \| fail \| warn \| skipped |
| `failures` | Row count that failed |

```bash
python scripts/check_test_audit_log_stages.py
```

---

## 10. dbt Commands Reference

### Setup & connection

```bash
dbt debug
dbt deps
dbt parse
dbt clean
```

### Run models — full project

```bash
dbt run
dbt run --full-refresh
dbt build                    # run + test
dbt build --full-refresh
```

### Run models — by layer

```bash
dbt run --select path:models/staging
dbt run --select path:models/intermediate
dbt run --select path:models/marts
dbt run --select path:models/reporting
```

### Run models — by tag

```bash
dbt run --select tag:daily
```

### Run models — single model & lineage

```bash
# One model
dbt run --select stg_synthea__encounters
dbt run --select fct_synthea__encounters

# Model + everything downstream
dbt run --select stg_synthea__encounters+

# Model + everything upstream
dbt run --select +fct_synthea__encounters

# Model + upstream + downstream
dbt run --select +fct_synthea__encounters+

# All staging and downstream
dbt run --select staging.synthea+
```

### Run models — by folder / package

```bash
dbt run --select staging.synthea
dbt run --select intermediate.synthea
dbt run --select marts.synthea
dbt run --select reporting.synthea
```

### Run models — multiple models

```bash
dbt run --select stg_synthea__patients stg_synthea__encounters
dbt run --select fct_synthea__encounters fct_synthea__readmissions
```

### Run models — exclude

```bash
dbt run --exclude path:models/reporting
dbt run --exclude test_stg_medications_temporal_consistency
```

### Test — full suite

```bash
dbt test
dbt test --store-failures          # if configured
```

### Test — by layer

```bash
dbt test --select path:tests/staging
dbt test --select path:tests/intermediate
dbt test --select path:tests/marts
dbt test --select path:tests/reporting
```

### Test — by model (schema + custom tests for that model)

```bash
dbt test --select stg_synthea__encounters
dbt test --select fct_synthea__encounters
dbt test --select rpt_synthea__readmission_rate_monthly
dbt test --select stg_synthea__encounters+
```

### Test — by test type

```bash
dbt test --select test_type:generic      # schema YAML tests
dbt test --select test_type:data         # custom SQL in tests/
dbt test --select test_type:unit         # unit tests if any
```

### Test — single custom test

```bash
dbt test --select test_stg_encounters_temporal_consistency
dbt test --select test_marts_encounter_costs_and_duration
dbt test --select test_int_readmission_flag_consistency
```

### Test — exclude known failure

```bash
dbt test --exclude test_stg_medications_temporal_consistency
dbt build --exclude test_stg_medications_temporal_consistency
```

### Build — combined run + test

```bash
dbt build
dbt build --select path:models/staging
dbt build --select marts.synthea+
dbt build --select fct_synthea__encounters+
```

### Documentation

```bash
dbt docs generate
dbt docs serve
dbt docs generate --no-compile
```

### Semantic layer

```bash
dbt parse
# Validates semantic_manifest.json
```

### Operations (macros)

```bash
# Truncate all Snowflake tables except RAW
dbt run-operation truncate_non_raw_tables
```

### Compile & preview SQL

```bash
dbt compile
dbt compile --select fct_synthea__encounters
dbt show --select stg_synthea__encounters --limit 10
```

### List resources

```bash
dbt ls
dbt ls --select path:models/marts
dbt ls --resource-type model
dbt ls --resource-type test
dbt ls --select tag:daily
```

### Freshness (sources)

```bash
dbt source freshness
```

### Target / vars

```bash
dbt run --target dev
dbt test --vars '{"test_audit_schema": "REPORTING"}'
```

### Full rebuild workflow

```bash
dbt run-operation truncate_non_raw_tables
dbt build --exclude test_stg_medications_temporal_consistency
dbt docs generate
```

### Utility scripts (after run)

```bash
python scripts/check_test_audit_log_stages.py
python scripts/check_reporting_counts.py
python scripts/check_test_audit_log.py
```

---

## Important Data Caveats

1. **Synthea is synthetic** — readmission rates ~49% vs real-world ~15%.
2. **Patient dim is SCD2** — one row per insurance period; use `count_distinct patient_id` for census.
3. **All `is_current = 'No'`** in Synthea — reports use latest period per patient.
4. **Orphan `patient_key`** on facts when encounter date is outside coverage window.
5. **Medications temporal test** fails on 5 source rows.
6. **Costs clamped** at mart layer — document for row-level analysis.

---

## Acknowledgments

- [dbt Labs](https://www.getdbt.com/) — transformation framework
- [Synthea](https://github.com/synthetichealth/synthea) — synthetic data
- [Kimball Group](https://www.kimballgroup.com/) — dimensional modeling
