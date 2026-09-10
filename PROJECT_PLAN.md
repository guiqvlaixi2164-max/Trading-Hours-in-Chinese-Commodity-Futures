# Project Plan — Trading Hours in Chinese Commodity Futures

**A DuckDB + Power BI study of when volatility, volume and price discovery happen, what
changes when trading hours are extended, and what accumulates while the market is shut.**

**Date:** 2026-09-10
**Data:** the same Wind five-minute bars as the companion repository `cc_commodity`
(rough volatility and forecasting). This project shares no code with it; it rebuilds the data
pipeline in SQL and uses the companion's outputs only as a reconciliation reference.
**Working repository name:** `cn-futures-trading-hours`

---

## 0. How to use this plan

- The project runs in **twelve phases** (§8). Each ends with a **gate**: a list of checks that
  must pass before the next phase starts, then a commit made by hand. A suggested commit subject
  is given for each phase.
- **All computation is SQL, executed by DuckDB.** Python is limited to a small runner that
  executes the SQL files in order, runs the SQL tests and exports the result tables. Power BI
  reads only the exported result tables and computes no estimators.
- The facts in §2 were observed while this plan was written, on the companion's cleaned data.
  Re-verify each one on the new pipeline's output in Phases 3 and 4 before relying on it.
- Record every decision that is not fixed here in `docs/DECISIONS.md`, with the date and the
  reason.

---

## 1. Objective and research questions

### 1.1 Umbrella question

> How do trading hours shape volatility, liquidity and price discovery in Chinese commodity
> futures?

The Chinese exchanges changed their trading hours repeatedly over the sample. Night sessions
were introduced contract by contract between 2013 and 2019, shortened in 2015, 2016 and 2019,
switched off for every contract from February to May 2020, and are cancelled before every long
public holiday. Each change is an intervention on trading hours that is recorded in the bar data,
with a date, a set of affected contracts and, usually, a set of unaffected ones. This study uses
those interventions.

### 1.2 Three parts

| Part | Question | Character |
|---|---|---|
| **A. Intraday atlas** | When during the trading day do volume and volatility occur, how does the profile differ by sector, and are the night-session peaks driven by overseas clocks? | Descriptive, with one sharp test (US daylight saving time) |
| **B. Night-session adoption** | When a contract gains a night session, does total daily variance rise (trading generates variance) or is existing variance only redistributed from the morning opening gap into the night? | Causal-leaning: staggered difference-in-differences |
| **C. Market closures** | How does the variance of the non-trading return grow with the length of the closure, and does it grow faster for contracts whose overseas benchmark keeps trading while China is shut? | Cross-sectional, in the spirit of French and Roll (1986) |

### 1.3 Hypotheses

These are fixed in `docs/HYPOTHESES.md` and committed **before** any Part B or Part C estimate is
computed (Phase 1).

- **H-A1 (U-shape).** Within each session block, mean absolute five-minute returns and volume
  shares are highest in the opening and closing slots, with the largest peaks at the 21:00 and
  09:00 opens.
- **H-A2 (US clock).** Night-session volatility peaks of internationally linked contracts sit at
  Beijing clock times tied to scheduled US events. Those peaks move by exactly one hour when US
  daylight saving time switches. Day-session slots, which fall in the US night, show no such
  shift; they are the placebo.
- **H-B1 (redistribution) vs H-B2 (generation).** Under H-B1, adoption leaves the
  15:00-to-15:00 close-to-close variance unchanged and moves variance out of the 09:00 opening
  gap into night trading. Under H-B2, adoption raises close-to-close variance because trading
  itself generates variance. The primary outcome is log monthly close-to-close variance.
- **H-B3 (day session).** After adoption, the share of daily variance realised in the pre-09:00
  gap falls, and day-session volume changes, while day-session hours stay the same.
- **H-C1 (French–Roll).** Variance of the non-trading return rises with non-trading hours, at a
  rate per hour far below the variance rate during trading hours.
- **H-C2 (linkage).** The slope of H-C1 is steeper for contracts with an actively traded overseas
  benchmark than for domestic-only contracts.
- **H-C3 (de-risking).** Open interest falls over the last trading days before long closures,
  relative to matched ordinary days.

### 1.4 Success criteria

1. One command, `python pipeline.py all`, rebuilds every table, test and exported mart from the
   raw CSVs, with no manual edits.
2. The SQL cleaning pipeline reproduces the companion's cleaned bars exactly in compatibility
   mode (§8, Phase 3). Every deliberate departure from it is listed with its row-count effect.
3. Every headline number in the report comes with an inference (bootstrap interval,
   randomisation p-value, or placebo) and a robustness row (Phase 9).
4. The raw data, the DuckDB warehouse, the marts and the Power BI data cache never enter version
   control.
5. The Power BI report is committed as a Power BI Project (text files, diffable) without data,
   plus a PDF export and screenshots.

### 1.5 Non-goals

Volatility forecasting (covered by the companion repository), trading strategies, any outside
data (overseas prices, inventories, margins), and tick-level microstructure (there are no ticks
or quotes, only five-minute bars).

---

## 2. What the data already shows (observed 2026-09-10, re-verify in Phases 3–4)

### 2.1 Night-session adoption is staggered and dated in the bars

The first trading day with night-session bars, per contract. The pre-adoption and post-adoption
counts are trading days in the companion's cleaned data.

| Adoption (trading day) | Contracts | Pre-adoption days |
|---|---|---|
| 2013-07-08 | gold, silver | 1,289 / 251 |
| 2013-12-23 | copper, aluminium, zinc | 2,698 / 2,507 / 1,604 |
| 2014-07-07 | coke | 748 |
| 2014-12-15 | methanol, sugar | 726 / 2,125 |
| 2014-12-29 | soybean oil, soybean meal, rubber, rebar, iron ore, coking coal | 2,128 / 2,972 / 2,912 / 1,360 / 267 / 429 |
| 2015-01-06 | bitumen | 233 |
| 2019-04-01 | polypropylene, PVC, corn starch | 1,215 / 2,357 / 1,017 |

- **Eligible treated units: 18 contracts in 7 adoption dates** (bitumen is borderline; see
  Phase 7).
- **Not usable as treated:**
  - MEG (61 pre-adoption days) and LPG (24).
  - Contracts listed with a night session from their first day: tin, soybean No.2, crude oil,
    fuel oil, TSR 20 rubber, low-sulphur fuel oil, PSF, international copper, butadiene rubber.
- **Never treated:** apple, egg, jujube, peanut, urea. These are day-only contracts, all
  agricultural or chemical.
- The companion's `config/sessions.yaml` says gold and silver night trading began in December
  2013. The bars say the first night session was the evening of Friday 2013-07-05 (trading day
  2013-07-08). Trust the bars.

### 2.2 Night trading was switched off in 2020

- The week of 2020-01-20 had 24 contracts with night sessions.
- From the week of 2020-02-03 through the week of 2020-04-27 there were **zero**.
- From the week of 2020-05-04 there were 25.
- Every night contract lost the session at once, while the day-only contracts were unaffected.

### 2.3 Night sessions were shortened

A preliminary check of each contract's last night bar per year shows the close moving earlier:

- **2015:** DCE soybean meal, soybean oil, iron ore, coke and coking coal, from past midnight to
  23:30.
- **2016:** SHFE rebar and bitumen, from past midnight to 23:00.
- **2019:** the same DCE contracts, from 23:30 to 23:00.

CZCE sugar and methanol appear to have closed at 23:30 before 2019 (see §2.6). Phase 4 derives
the exact session history.

### 2.4 Long holidays cancel the night session

On the first trading day after a gap of 4 or more calendar days, only **3.6 percent** of
contract-days (of 1,514) carry a night block, against 97.1 percent on ordinary days.

Calendar gaps of 4 or more days in copper range up to 18 days:

| Gap (calendar days) | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 18 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Count | 66 | 27 | 11 | 4 | 16 | 4 | 19 | 6 | 3 | 1 | 2 |

Some of the longest gaps may be missing data rather than holidays; Phase 4 separates the two.

### 2.5 The US clock is visible in gold

Mean absolute five-minute return in the gold night session, 2014 onwards, with a rough split
into US winter (December to February) and US summer (April to October):

| Beijing slot | 21:15 | **21:20** | 21:25 | 21:30 | 21:35 |
|---|---|---|---|---|---|
| US winter (EST) | 4.85 bp | **6.12 bp** | 4.38 bp | 6.60 bp | 5.05 bp |
| US summer (EDT) | 5.01 bp | **4.67 bp** | 4.19 bp | 5.93 bp | 5.76 bp |

Bars are left-stamped, so the 21:20 bar covers 21:20–21:25. That is 08:20 New York time only in
US winter; in summer it is 07:20.

The 21:30 slot is elevated in both regimes. In winter it is 08:30 ET, the US macro-release time;
in summer it is 09:30 ET, the US equity open. So 21:30 on its own cannot separate the two
drivers, and Phase 6 uses the full shift test instead.

### 2.6 The companion pipeline dropped some night bars

The companion gives each contract **one** session template, taken from recent session hours, and
discards bars outside it. According to its cleaning report this removed:

- **7,092** bars each for sugar and methanol;
- **1,549** bars for soybean No.2;
- **zero** for every other contract.

For a study of night trading, those bars matter. The new pipeline derives session hours from the
data over time (Phase 3) and lists this as a deliberate departure.

### 2.7 Coverage is unbalanced

Contracts in the panel by year: 4 until 2005, 13 in 2012, 20 in 2015, 28 in 2019, and 34 from
2023. Cross-sectional comparisons must state their period.

---

## 3. Toolchain on this machine

| Tool | Status | Use |
|---|---|---|
| DuckDB 1.4.1 (Python package, miniconda base) | Installed, verified: scans 5.9M bars in 0.03 s | The SQL engine and warehouse |
| Power BI Desktop | Being installed (Microsoft Store build, which auto-updates) | Semantic model and report |
| Python 3.13 (miniconda) | Installed | `pipeline.py` runner only |
| VS Code | Installed | Editing SQL; optional DuckDB and SQLFluff extensions |
| DuckDB CLI | Optional: `winget install DuckDB.cli` | Interactive queries against the warehouse. **Pin it to the same version as the Python package** so both can open the same `.duckdb` file |
| `make` | Not installed | Not needed: `pipeline.py` replaces the Makefile |
| SQLFluff | Optional: `pip install sqlfluff` | SQL linting with `dialect = duckdb` |

### 3.1 Machine constraints

7.8 GB RAM, 2 cores / 4 threads, 19.7 GB free on C: and 44.7 GB on D:.

- In every DuckDB session, set `SET memory_limit = '3GB'; SET threads = 4;
  SET temp_directory = 'data/tmp';` so DuckDB and Power BI can run side by side.
- Never import bar-level data into Power BI. Every mart is aggregated to the contract-day grain
  or coarser (§7.4).
- Close the DuckDB CLI before running `pipeline.py`: a DuckDB file accepts only one writer at a
  time.

### 3.2 Environment

Create a dedicated conda environment in the existing envs directory on D::

```yaml
# environment.yml
name: tradinghours
channels: [conda-forge]
dependencies:
  - python=3.13
  - pip
  - pip:
      - duckdb==1.4.1
      - pyyaml>=6
      - sqlfluff>=3     # optional
```

### 3.3 Power BI Desktop settings to check once

- **Options → Preview features:** enable *Power BI Project (.pbip) save option* and *Store
  semantic model using TMDL format* if your build still lists them as previews.
- **Options → Regional settings → Application language:** set English if the Windows display
  language makes the menus harder to follow against this plan. DAX function names are English
  regardless.
- **Options → Data load:** turn off *Auto date/time* for new files. Hidden date tables per date
  column bloat the model, and `dim_date` replaces them.

---

## 4. Repository layout

```
cn-futures-trading-hours/
├── README.md                      # research brief: question, findings, how to run
├── PROJECT_PLAN.md                # this file (move to docs/ once Phase 0 is done)
├── LICENSE                        # MIT for code; data explicitly excluded
├── .gitignore
├── .sqlfluff                      # dialect = duckdb, max_line_length = 100
├── environment.yml
├── config.yaml                    # every tunable parameter (§6.4)
├── pipeline.py                    # runner: build | test | export | all | verify-raw
│
├── seeds/                         # small hand-made reference tables, TRACKED
│   ├── contracts.csv              # slug, code, exchange, name_en, name_cn, sector, raw_file,
│   │                              #   linkage, linkage_reason
│   ├── session_blocks.csv         # block, clock start, clock end, last stamp, order
│   └── us_scheduled_events.csv    # event, et_time, days_of_week, applies_to
│
├── sql/
│   ├── 00_setup/                  # schemas, settings, macros, seeds -> seed.*
│   ├── 10_staging/                # raw CSV -> stg.*
│   ├── 20_clean/                  # sessions, trading days, returns, outliers -> clean.*
│   ├── 30_core/                   # daily facts, calendar, dimensions -> core.*
│   ├── 40_atlas/                  # Part A -> atlas.*
│   ├── 50_night/                  # Part B -> night.*
│   ├── 60_closure/                # Part C -> closure.*
│   ├── 70_robust/                 # robustness variants -> robust.*
│   └── 90_mart/                   # the views Power BI reads -> mart.*
│
├── tests/
│   ├── sql/                       # assertion queries: each must return ZERO rows
│   └── reconcile/                 # comparisons against data/reference/ (Phase 3)
│
├── powerbi/
│   ├── TradingHours.pbip
│   ├── TradingHours.SemanticModel/   # TMDL; .pbi/cache.abf is git-ignored
│   ├── TradingHours.Report/
│   └── theme.json
│
├── outputs/
│   ├── tables/                    # small aggregated CSVs, TRACKED (evidentiary)
│   └── figures/dashboard/         # PNG screenshots of report pages, TRACKED
│
├── report/
│   ├── REPORT.md                  # the technical report
│   └── TradingHours.pdf           # Power BI PDF export
│
├── docs/
│   ├── HYPOTHESES.md              # pre-registered in Phase 1
│   ├── DATA_DICTIONARY.md         # every table and column in clean/core/mart
│   ├── METHODOLOGY.md             # definitions and estimators, with formulas
│   └── DECISIONS.md               # dated decision log
│
├── data/                          # git-ignored in its entirety except the manifest
│   ├── raw/                       # 34 Wind CSVs + MANIFEST.sha256
│   ├── reference/                 # companion outputs, for reconciliation only
│   ├── warehouse.duckdb
│   └── tmp/
├── marts/                         # git-ignored: Parquet exports that Power BI reads
└── logs/                          # git-ignored: build logs
```

---

## 5. Data handling and licensing

### 5.1 What to copy from `cc_commodity`

**Copy, do not move.** The companion repository needs its data to stay reproducible.

| From `cc_commodity` | To the new repository | Size | Role |
|---|---|---|---|
| `data/raw/*.csv` (34 files) | `data/raw/` | 375 MB | **The only analytical input** |
| `data/raw/MANIFEST.sha256` | `data/raw/` (tracked) | small | Checksum verification |
| `data/interim/*.parquet` (34 files) | `data/reference/interim/` | 148 MB | Reconciliation only |
| `data/processed/rv_panel.parquet` | `data/reference/` | small | Reconciliation only |
| `outputs/tables/cleaning_report.csv` | `data/reference/` | small | Reconciliation only |
| `outputs/tables/rollover_candidates.csv` | `data/reference/` | small | Reconciliation only |
| `config/commodities.yaml` | read once in Phase 0, then discarded | small | Source for `seeds/contracts.csv` |

**Not needed:** `data/processed/forecasts/` (1,746 files, 141 MB) and everything under
`notebooks/` and `src/`.

### 5.2 Rules

- The Wind data is licensed and may not be redistributed. `data/`, `marts/`, `logs/` and every
  `*.duckdb` file are git-ignored.
- **A `.pbix` file embeds its data, so never commit one.** Commit the `.pbip` project, and make
  sure `**/.pbi/cache.abf` (the imported data) and `**/.pbi/localSettings.json` are ignored.
  Power BI Desktop writes its own `.gitignore` inside the project folder when saving as
  `.pbip`; check it is there and keep the root rules as a backstop.
- `outputs/tables/` holds only aggregated statistics: estimates, profiles averaged over years,
  counts. No price, volume or open-interest series at daily or finer grain.
- The Power BI Service needs a work or school account, so "Publish to web" is unavailable with
  a personal address. That is just as well, because it would publish derived data publicly.
  Share the PDF export and the screenshots instead.

### 5.3 `.gitignore` (root)

```gitignore
data/*
!data/raw/
data/raw/*
!data/raw/MANIFEST.sha256
marts/
logs/
*.duckdb
*.duckdb.wal
*.pbix
**/.pbi/cache.abf
**/.pbi/localSettings.json
__pycache__/
.ipynb_checkpoints/
```

---

## 6. Architecture

### 6.1 Layers (DuckDB schemas)

| Schema | Contents | Grain |
|---|---|---|
| `seed` | Tables loaded from `seeds/*.csv` | Small |
| `stg` | Raw bars, typed, with `slug` attached; nothing removed | Bar (6.0M) |
| `clean` | Session-assigned, filtered bars with returns and flags | Bar (≈5.9M) |
| `core` | Daily facts, segment returns, calendars, dimensions | Contract-day (≈91k) and below |
| `atlas`, `night`, `closure` | Analysis tables, one schema per part | Aggregated |
| `robust` | Every robustness variant, in one long table | Aggregated |
| `mart` | Views shaped for Power BI (star schema, §7) | Aggregated |

### 6.2 Conventions

- One `CREATE OR REPLACE TABLE` (or view) per file. Files are prefixed with numbers and run in
  lexical order, e.g. `20_clean/030_trading_day.sql`.
- Names are `snake_case`. Tables are nouns; flags start with `is_`; counts start with `n_`;
  returns are log returns, named `ret_*`, as decimals (not percent).
- Parameters come from `config.yaml`. The runner sets each one with `SET VARIABLE name =
  value;`, and SQL reads it with `getvariable('name')`. Numbers never appear in SQL bodies.
- **Randomness is hash-based, never `random()`.** For example, `hash(rep || '-' || k) % n`.
  Results then do not depend on thread scheduling, and every bootstrap is reproducible
  bit-for-bit.
- Marts use only `DATE`, `INTEGER`, `BIGINT`, `DOUBLE`, `VARCHAR` and `BOOLEAN`.
  - Cast away `TIMESTAMP_NS`, `TIME` and `HUGEINT`; for example, `sum()` of a `BIGINT` returns
    `HUGEINT`.
  - Clock times become an integer minute key plus a `VARCHAR` label.
  - This avoids type surprises in Power Query.

### 6.3 The runner, `pipeline.py` (about 150 lines)

```
python pipeline.py verify-raw           # SHA-256 of data/raw/*.csv against MANIFEST.sha256
python pipeline.py build [--from 30_core] [--only 50_night] [--compat]
python pipeline.py test                 # every tests/sql/*.sql must return zero rows
python pipeline.py export               # mart.* -> marts/*.parquet; selected -> outputs/tables/*.csv
python pipeline.py all                  # verify-raw, build, test, export
```

- It opens one connection to `data/warehouse.duckdb`, applies the settings from §3.1, loads the
  `config.yaml` values as DuckDB variables, and executes each SQL file in order.
- It logs the file name, row counts of the tables created and the elapsed time to
  `logs/build.log`.
- It stops at the first failure and prints the file and statement that failed.
- `--compat` sets the variable `compat_mode = true`, which switches the session rule to the
  companion's fixed templates (Phase 3).
- A test fails if it returns any rows; the runner prints up to ten of them.

### 6.4 `config.yaml` (initial values)

```yaml
duckdb: {memory_limit: "3GB", threads: 4}
cleaning:
  daily_volume_percentile_floor: 0.01
  min_bars_per_day: 20
  mad_k: 10.0
  mad_window_before: 30        # centred 60-row window, matching pandas center=True
  mad_window_after: 29
  mad_min_periods: 15
  mad_floor_frac: 0.10
  mad_to_sigma: 1.4826
flags:
  min_nonzero_returns: 10      # limit-day ("stale") flag
  rollover_z: 4.0
night_study:
  min_night_bars_first_day: 5  # adoption = first day with at least this many night bars
  min_pre_months: 12
  min_post_months: 12
  event_window: [-12, 12]
  base_period: -1
  bootstrap_reps: 999
  permutation_reps: 999
closure_study:
  holiday_min_calendar_days: 4
  baseline_window: [-60, -6]   # trading days, mirrored after the event
  prehol_days: 3
atlas:
  first_year: 2014             # first full calendar year with broad night coverage
annualisation_days: 252
```

---

## 7. Power BI design

### 7.1 Connection

- A Power Query text parameter `MartsFolder` holds the absolute path of `marts\`.
- Each table is `Parquet.Document(File.Contents(MartsFolder & "fct_day.parquet"))`.
- The committed parameter value is the author's path; anyone cloning the repository changes
  that one parameter.
- Import mode only: no DuckDB ODBC driver and no DirectQuery.
- Refreshing means running `pipeline.py export`, then **Refresh** in Power BI.

### 7.2 Star schema

| Table | Grain | Key columns |
|---|---|---|
| `dim_contract` | Contract (34) | `slug`, name EN/CN, exchange, sector, sector colour hex, linkage, adoption date, cohort, `is_treated_eligible` |
| `dim_date` | Calendar day 2002-07-01 to 2024-11-30 | date, year, month, year-month, `is_exchange_open`, `us_dst`, `uk_bst`, holiday name and bucket. **Mark as date table** |
| `dim_slot` | Five-minute slot of the trading day | `slot_key` (minutes after 21:00, 0 to 1,079), label `"21:00"`, block, `slot_order` (the **Sort by column** for the label, so 21:00 sorts before 09:00) |
| `dim_segment` | Return segment (8) | segment, group (non-trading, night trading, day trading, intraday breaks), order |
| `dim_event_time` | Event month −12 to +12 | `e`, label |
| `fct_day` | Contract-day | `ret_cc`, `sq_ret_cc`, `abs_ret_cc`, day-session RV, volume by session, open interest, `is_rollover`, `is_stale`, `is_complete_day` |
| `fct_day_segment` | Contract-day-segment | `ret_seg`, `sq_ret_seg`, `signed_ret_seg` = sign(`ret_cc`) × `ret_seg` |
| `fct_slot_profile` | Contract × year × US-DST regime × slot | `n_bars`, `sum_abs_ret`, `sum_sq_ret`, `sum_volume` |
| `fct_session_month` | Contract × month | night minutes, night bars, `has_night` |
| `fct_event_att` | Outcome × cohort (or "all") × event month | `att`, `ci_lo`, `ci_hi`, `n_treated`, `n_control` |
| `fct_contract_month` | Contract × month | The Part B outcomes, for drill-through |
| `fct_gap` | Contract × non-trading interval | `gap_hours`, `ret_gap`, baseline variance, `variance_ratio`, gap type |
| `fct_closure_window` | Contract × closure × day offset −5 to +5 | Open-interest change, volume ratio, RV ratio |
| `fct_robust` | Variant × statistic | estimate, interval, `n` |

- Relationships are one-to-many and single-direction, dimension to fact.
- `dim_segment` relates to `fct_day_segment` only.
- `fct_day` deliberately has no relationship to `dim_segment`, which the WPC measure relies on.

### 7.3 Core DAX measures

```dax
Ann Vol (%) =
SQRT ( DIVIDE ( SUM ( fct_day[sq_ret_cc] ), COUNTROWS ( fct_day ) ) * 252 ) * 100

Variance Share =
DIVIDE (
    SUM ( fct_day_segment[sq_ret_seg] ),
    CALCULATE ( SUM ( fct_day_segment[sq_ret_seg] ), REMOVEFILTERS ( dim_segment ) )
)

-- Weighted price contribution (Barclay and Warner 1993). WPC_s = sum(sign(r) * r_s) / sum(|r|);
-- it sums to 1 across segments. Both facts are restricted to complete, non-rollover days in SQL.
WPC =
DIVIDE ( SUM ( fct_day_segment[signed_ret_seg] ), SUM ( fct_day[abs_ret_cc] ) )

Mean Abs Ret (bp) =
DIVIDE ( SUM ( fct_slot_profile[sum_abs_ret] ), SUM ( fct_slot_profile[n_bars] ) ) * 10000

Periodicity Factor =
DIVIDE ( [Mean Abs Ret (bp)], AVERAGEX ( ALLSELECTED ( dim_slot[slot_key] ), [Mean Abs Ret (bp)] ) )

Volume Share =
DIVIDE (
    SUM ( fct_slot_profile[sum_volume] ),
    CALCULATE ( SUM ( fct_slot_profile[sum_volume] ), REMOVEFILTERS ( dim_slot ) )
)
```

A **field parameter** (Modeling → New parameter → Fields) switches the outcome shown on the event
study page and the atlas heatmap, so one visual serves several outcomes.

### 7.4 Report pages

| # | Page | Main visuals |
|---|---|---|
| 1 | **Findings** | KPI cards (contracts, bars, days, one headline number per part); three short text boxes |
| 2 | **Data and sessions** | Heatmap matrix contract × month, coloured by night minutes: adoption, the 2020 switch-off and the shortenings in one picture. Cleaning waterfall. Reconciliation status table |
| 3 | **Intraday atlas** | Heatmap matrix contract × slot, with Periodicity Factor or Volume Share via the field parameter. Line chart of the profile by sector. Slicers for year range and sector |
| 4 | **US clock test** | EST and EDT profiles overlaid for a selected contract. Bar chart of the 21:20 spike by contract, sorted, coloured by linkage. Crude-oil Wednesday panel (Phase 6) |
| 5 | **Night adoption** | Event-time line with error bars (Analytics pane → Error bars, bound to `ci_lo`/`ci_hi`), with the outcome from the field parameter. Small multiples by cohort |
| 6 | **Where prices are discovered** | 100% stacked columns of Variance Share and WPC by segment and year. The 2020 switch-off marked with a shaded band |
| 7 | **Closures** | Scatter of `variance_ratio` against `gap_hours` (log axis), coloured by linkage. Event-window lines for open interest and volume around long closures |
| 8 | **Robustness** | Dot plot of headline estimates across variants, with intervals |
| 9 | **Contract** (drill-through) | Everything above for one contract |

- Tooltip pages on the heatmap cells show the number of observations behind each cell.
- Sector colours are fixed by the hex column in `dim_contract`, applied with conditional
  formatting (Format → Colors → *fx* → Field value), plus a `theme.json` for the base palette.
- Export: File → Export → PDF to `report/TradingHours.pdf`, and one PNG per page to
  `outputs/figures/dashboard/`.

---

## 8. Phases

| Phase | Stage | Rough effort |
|---|---|---|
| 0 | Repository and environment | 0.5 day |
| 1 | Literature and pre-registration | 1 day |
| 2 | Ingestion and staging | 0.5 day |
| 3 | Session-aware cleaning in SQL, and reconciliation | 2–3 days |
| 4 | Core model: calendars, segments, daily facts | 2 days |
| 5 | Power BI setup and a data-quality page | 1 day |
| 6 | Part A: intraday atlas and the US clock test | 2 days |
| 7 | Part B: night-session event study | 3–4 days |
| 8 | Part C: market closures | 2 days |
| 9 | Robustness | 1–2 days |
| 10 | Power BI semantic model and report | 2–3 days |
| 11 | Write-up and release | 2 days |

Effort figures are rough, in focused working days, and are only there to show relative size.

---

### Phase 0 — Repository and environment

**Goal:** an empty but working skeleton, and the data in place and verified.

1. Create the folder and move this file into it. Run `git init`, create the layout in §4 with
   `.gitkeep` files, and add `LICENSE` (MIT, with a paragraph excluding the data) and the
   `.gitignore` from §5.3.
2. Copy the files in §5.1.
3. Create the conda environment from §3.2.
4. Write `pipeline.py` with `verify-raw` and an empty `build` loop. Run `verify-raw` and confirm
   that all 34 hashes match the manifest.
5. Write `seeds/contracts.csv` from the companion's `config/commodities.yaml`: slug, code,
   exchange, English and Chinese names, sector and raw file. Add two new columns:
   - `linkage`: `international`, `partial` or `domestic`;
   - `linkage_reason`: one line naming the overseas benchmark, or why there is none.
6. Draft the linkage proposal, to be finalised in Phase 1:
   - `international`: gold, silver, copper, international copper, aluminium, zinc, tin, crude
     oil, fuel oil, low-sulphur fuel oil, soybean meal, soybean oil, soybean No.2, natural
     rubber, TSR 20 rubber, sugar, iron ore;
   - `partial`: bitumen, LPG, MEG, methanol, polypropylene, PSF, butadiene rubber, coking coal;
   - `domestic`: apple, jujube, egg, peanut, corn starch, rebar, coke, PVC, urea.
7. Write `seeds/session_blocks.csv` for the four clock blocks, and `seeds/us_scheduled_events.csv`
   with 08:20 ET (CME metals open), 08:30 ET (US macro releases), 09:30 ET (US equity open),
   10:00 ET (second-tier releases) and 10:30 ET Wednesday (EIA weekly petroleum report,
   energy contracts only).

**Gate:** `verify-raw` passes; `git status` shows no file under `data/` except the manifest.
**Commit:** `Phase 0: repository skeleton, seeds, raw-data verification`

---

### Phase 1 — Literature and pre-registration

**Goal:** know what is already known, and fix the confirmatory tests before seeing the results.

1. **Literature review.** Aim for 10–20 sources. Summarise each in two lines in
   `docs/METHODOLOGY.md`:
   - Intraday patterns: Admati and Pfleiderer (1988); Andersen and Bollerslev (1997).
   - Trading and non-trading variance: French and Roll (1986).
   - Price discovery: Barclay and Warner (1993); Cao, Ghysels and Hatheway (2000).
   - Announcements: Andersen, Bollerslev, Diebold and Vega (2003).
   - Staggered difference-in-differences: Callaway and Sant'Anna (2021); Goodman-Bacon (2021);
     Roth et al. (2023).
   - **Search specifically for existing studies of SHFE, DCE and CZCE night-trading
     introductions.** Do not assume the question is new. If a close study exists, position this
     one against it: finer data, more cohorts, the 2020 reversal, the SQL pipeline.
2. Write `docs/HYPOTHESES.md`. It fixes:
   - hypotheses H-A1 to H-C3 (§1.3);
   - the primary and secondary outcomes with their exact definitions (Phase 7 table);
   - the event window, base period, control groups and eligibility rules;
   - the inference method and the significance level (5 percent, two-sided);
   - the linkage classification in `seeds/contracts.csv`;
   - which analyses are confirmatory (H-A2, H-B1/H-B2, H-C2) and which are exploratory
     (everything else).
3. Note in the file that the facts in §2 of this plan were seen during planning.

**Gate:** `HYPOTHESES.md` and the final `seeds/contracts.csv` are committed **before** any file
in `sql/50_night/` or `sql/60_closure/` exists. The git history is the timestamp.
**Commit:** `Phase 1: literature notes and pre-registered hypotheses`

---

### Phase 2 — Ingestion and staging

**Goal:** all raw bars in DuckDB, typed and tagged, with nothing removed.

1. `00_setup/010_schemas.sql`: create the schemas in §6.1. `020_seeds.sql`: load `seeds/*.csv`
   into `seed.*` with explicit column types.
2. `10_staging/010_stg_bars.sql`:
   ```sql
   CREATE OR REPLACE TABLE stg.bars AS
   SELECT c.slug,
          r.datetime                         AS ts,
          r.datetime::DATE                   AS cal_date,
          hour(r.datetime) * 60 + minute(r.datetime) AS clock_min,
          r.open, r.high, r.low, r.close, r.volume, r.position
   FROM read_csv('data/raw/*.csv', filename = true, header = true,
                 columns = {'datetime': 'TIMESTAMP', 'open': 'DOUBLE', 'high': 'DOUBLE',
                            'low': 'DOUBLE', 'close': 'DOUBLE', 'volume': 'DOUBLE',
                            'position': 'DOUBLE'}) r
   JOIN seed.contracts c
     ON c.raw_file = regexp_extract(r.filename, '[^/\\]+$');
   ```
3. Tests (`tests/sql/`):
   - `stg_row_counts.sql`: bars per contract equal the companion's `n_raw` in
     `cleaning_report.csv` (6.0M in total).
   - `stg_unique_ts.sql`: no duplicate `(slug, ts)`.
   - `stg_all_files.sql`: all 34 slugs are present.

**Gate:** the tests pass.
**Commit:** `Phase 2: raw bars staged in DuckDB`

---

### Phase 3 — Session-aware cleaning in SQL, and reconciliation

**Goal:** rebuild the companion's cleaning rules in SQL, prove that compatibility mode matches
it exactly, then switch on the corrected session rule.

Steps, one file each, in the companion's order:

1. **`010_ohlc.sql` — OHLC sanity.** Keep bars with `volume > 0`, `low <= high`, open and close
   within `[low, high]`, and `close > 0`.
2. **`020_block.sql` — block assignment.**
   - *Corrected rule (default):* night = clock ≥ 21:00 or clock < 03:00; `morning_1` =
     09:00–10:10; `morning_2` = 10:30–11:25; `afternoon` = 13:30–14:55 (stamps); anything else
     is off-session.
   - *Compatibility rule (`--compat`):* the companion's per-contract template masks, e.g.
     `night_2300` accepts night stamps 21:00–22:55 only.
   - This is the only difference between the two modes.
3. **`030_trading_day.sql` — trading day.**
   - Build `clean.contract_calendar`: the distinct `cal_date` of day-session bars per contract.
   - Evening night bars (clock ≥ 21:00) take the first calendar date **strictly after**
     `cal_date`. Post-midnight night bars take the first **on or after**. Day bars keep their own
     date.
   - Use `ASOF LEFT JOIN`, then count and drop the unmatched rows, which are trailing night bars
     with no following day session:
     ```sql
     SELECT b.*, c.trading_date AS trading_day
     FROM evening_bars b
     ASOF LEFT JOIN clean.contract_calendar c
       ON b.slug = c.slug AND b.cal_date < c.trading_date;
     ```
     The post-midnight version uses `b.cal_date <= c.trading_date`.
   - Test `trading_day_known_cases.sql`: a Friday 21:00 gold bar maps to Monday, a Saturday
     00:30 bar maps to Monday, and a bar before a holiday maps to the first day after it.
4. **`040_volume_floor.sql` — thin days.** Drop trading days whose total volume is below the
   contract's `quantile_cont(daily_volume, 0.01)`. This matches pandas' default linear
   interpolation.
5. **`050_min_bars.sql` — short days.** Drop trading days with fewer than 20 bars.
6. **`060_returns.sql` — returns.**
   - `seq` = `row_number()` over `(slug ORDER BY trading_day, block_order, ts)`, with the
     night block first.
   - `ret` = `ln(close) - lag(ln(close))` within `(slug, trading_day, block)`, NULL on each
     block's first bar.
   - `gap_ret` = `ln(close) - lag(ln(close))` over `seq`, kept **only** where `ret` is NULL.
     This is the companion's definition: close of the previous bar to close of the first bar.
7. **`070_outliers.sql` — outlier repair.** Two passes of centred windows over `seq`, partitioned
   by `slug` only (not by day or block, as in the companion):
   ```sql
   -- pass 1: centred rolling median over rows [i-30, i+29], NULLs ignored
   median(ret) OVER w AS med, count(ret) OVER w AS n_w
   -- pass 2: rolling median of |ret - med| over the same frame
   -- threshold = mad_k * mad_to_sigma * greatest(mad, mad_floor_frac * global_mad)
   -- is_outlier = n_w >= 15 AND threshold > 0 AND abs(ret - med) > threshold
   ```
   Here `global_mad = median(|ret - median(ret)|)` per contract. Flagged returns are set to 0;
   the bar is kept.
8. **`080_zero_rv.sql` — dead days.** Drop trading days whose sum of squared `ret` is 0.
9. **`090_daily_flags.sql` — daily flags.**
   - `is_stale`: fewer than 10 non-zero returns in the day.
   - `is_rollover`: \|first-bar `gap_ret`\| > 4 × stddev_samp **and** \|Δ ln(open interest)\|
     > 4 × stddev_samp, per contract.

**Reconciliation** (`tests/reconcile/`, run with `--compat`):

| Check | Expected |
|---|---|
| Bars per contract after cleaning | Equal to `data/reference/interim` (5,946,851 in total) |
| `(slug, ts)` → `trading_day`, `block` | 100% identical |
| `ret`, `gap_ret` | \|difference\| < 1e-12 |
| `is_outlier` | Identical. The companion zeroed 8,845 returns in total. Any residual must be explained (e.g. median ties) and listed in `DECISIONS.md` |
| Daily RV (sum of squared `ret`) against `rv_panel.rv` | Relative difference < 1e-10 on all 90,835 contract-days |
| `is_rollover`, `is_stale` | The same 199 and 216 contract-days |

Then rebuild **without** `--compat` and record the departure. The expected effect is additional
night bars for sugar, methanol and soybean No.2, in line with the 7,092, 7,092 and 1,549 bars
the companion dropped. Tabulate the actual counts in `DECISIONS.md` and in a small
`outputs/tables/cleaning_departures.csv`.

Also compute the cleaning waterfall per contract (rows removed by each step) into
`core.cleaning_waterfall` for the Power BI data page.

**Gate:** every reconciliation check passes in compatibility mode, and the departure table is
written. **Do not continue until this holds**; every later result rests on it.
**Commit:** `Phase 3: session-aware cleaning in SQL, reconciled to the reference pipeline`

---

### Phase 4 — Core model: calendars, segments, daily facts

**Goal:** the contract-day tables and dimensions that all three parts share.

1. **`core.session_history`.** Per contract and month:
   - night bars;
   - night start and end, as minutes after 21:00 so that midnight crossing is handled:
     `(clock_min - 1260 + 1440) % 1440`;
   - `has_night`.
   - Derive the change points:
     - **adoption:** the first day with at least 5 night bars;
     - **suspension:** runs of 10 or more trading days without night bars after adoption;
     - **shortening or extension:** changes in the modal night end, lasting at least 20 trading
       days.
   - Test: the 2013 adoptions, the 2020 suspension and the 2015/2016/2019 shortenings in §2
     appear.
2. **`core.exchange_calendar`.**
   - The union of trading days across the contracts of each exchange group (SHFE with INE, DCE,
     CZCE), and across all exchanges.
   - An exchange closure is a gap in that union.
   - A contract missing a day on which its exchange was open is a data gap:
     `core.data_gaps`.
   - Test: every closure of 4 or more calendar days is shared by all exchanges, or is listed as
     an explained exception.
3. **Holiday labels.** Label each closure of 4 or more calendar days from the month it starts in
   and its length:
   - January or February and 7 or more days: Spring Festival;
   - late September or October and 7 or more days: National Day;
   - otherwise a short holiday (Qingming, Labour Day, Dragon Boat or Mid-Autumn, by month).
   
   This is a descriptive label; the analysis uses closure length, not the name.
4. **`core.segments`.** Eight segment returns per contract-day, built from **open** and close
   prices so that they add up exactly to the close-to-close return:

   | Segment | Definition | Group |
   |---|---|---|
   | `pre_night_gap` | ln(night first open / previous day's last close) | Non-trading |
   | `night` | ln(night last close / night first open) | Night trading |
   | `pre_day_gap` | ln(09:00 first open / night last close), or / previous close if there is no night block | Non-trading |
   | `morning_1` | ln(last close / first open) within the block | Day trading |
   | `break_1015` | ln(`morning_2` first open / `morning_1` last close) | Intraday break |
   | `morning_2` | Within the block | Day trading |
   | `lunch_gap` | ln(afternoon first open / `morning_2` last close) | Intraday break |
   | `afternoon` | Within the block | Day trading |

   - The first bar's open is the price set in the opening call auction (20:55–21:00,
     08:55–09:00).
   - `is_complete_day` means every block the day's session should have is present, and the
     previous trading day is the contract's own previous day (not across a data gap).
   - Test: on complete days, \|Σ segments − `ret_cc`\| < 1e-12.
5. **`core.fct_day`.** One row per contract-day, with:
   - `ret_cc`; day-session RV (within-block returns only, same hours in every regime); total RV;
   - volume by night and by day session; closing open interest;
   - the flags, plus bar-internal returns for Part A.
   - Test: \|`ret_cc`\| and RV reconcile with the reference `rv_panel` in compatibility mode.
6. **`core.gaps`.** Every non-trading interval per contract:
   - `gap_start` = end of the last bar before it (stamp + 5 minutes); `gap_end` = stamp of the
     first bar after it;
   - `gap_hours`; `ret_gap` = ln(first open after / last close before);
   - the type (`overnight`, `intraday_break`, `weekend`, `holiday`, `suspension`, `data_gap`).
7. **`core.dim_date`.** Calendar days with exchange-open flags and holiday labels.
   - Add US daylight saving time. Convert with the ICU extension, which ships with the Python
     wheel: `(ts AT TIME ZONE 'Asia/Shanghai') AT TIME ZONE 'America/New_York'`.
   - Cross-check against the rule, second Sunday of March to first Sunday of November (from
     2007).
   - Add UK summer time (last Sunday of March to last Sunday of October) for the mismatch weeks.
   - `core.dim_slot` and `core.dim_segment` as in §7.2.

**Gate:** all Phase 4 tests pass. The §2 facts are re-verified on the new tables and any change
is noted in `DECISIONS.md`.
**Commit:** `Phase 4: session history, calendars, segment returns, daily facts`

---

### Phase 5 — Power BI setup and a data-quality page

**Goal:** learn the tool on low-stakes tables, and catch data problems visually early.

1. `90_mart/`: views `mart.dim_contract`, `mart.dim_date`, `mart.fct_session_month` and
   `mart.cleaning_waterfall`. Write `pipeline.py export`: each `mart.*` view is exported with
   `COPY (SELECT * FROM mart.x) TO 'marts/x.parquet' (FORMAT parquet, COMPRESSION zstd)`.
2. In Power BI Desktop:
   - create the `MartsFolder` parameter and load the four tables;
   - build the relationships and mark `dim_date` as the date table;
   - build page 2 of §7.4: the night-session heatmap, the cleaning waterfall and the
     reconciliation table.
3. Save as `.pbip`. Confirm `cache.abf` does not appear in `git status`.

**Gate:** the heatmap shows the adoption dates, the 2020 switch-off and the shortenings, and no
unexplained holes.
**Commit:** `Phase 5: Power BI project, data and sessions page`

---

### Phase 6 — Part A: intraday atlas and the US clock test

**Goal:** H-A1 described, and H-A2 tested.

1. **`atlas.slot_profile`.** Grain: contract × calendar year × US-DST regime × slot. Keep
   `n_bars`, `sum_abs_ret`, `sum_sq_ret` and `sum_volume`, from 2014 on for night slots.
   - Use the **bar-internal return** ln(close/open) for every bar, so that block-opening slots
     have a value.
   - The within-block return leaves the first bar of each block empty, and its gap return
     mixes in the non-trading move.
2. **U-shape statistics (H-A1).** Per contract and block:
   - the ratio of the opening slot's periodicity factor to the block median;
   - the same for the closing slot;
   - volume share of the first and last 15 minutes.
   - Report the median and the range across contracts, and by sector.
3. **US clock test (H-A2).** Primary statistic, for each contract and each night slot `s`: the
   spike
   `S(s) = mean|r|(s) − mean of mean|r| at s±2 and s±3` (skipping `s±1` to avoid spill-over),
   in each DST regime.
   - **Prediction:** each scheduled event in `seeds/us_scheduled_events.csv` produces a spike at
     Beijing time = ET + 13 h in EST and ET + 12 h in EDT.
   - **Test statistic:** the mean of `S` at the predicted slots minus the mean at the same clock
     slots in the other regime, pooled over events.
   - **Inference:** a permutation test. Shuffle the regime labels over whole weeks (so the
     weekly structure is kept), 999 replications with hash-based draws.
   - **Placebo:** the same statistic on day-session slots, which should be about zero because
     09:00–15:00 Beijing is the US night.
   - **Cross-section:** the test statistic by linkage group. H-A2 predicts international >
     domestic.
   - **Second test (energy):** EIA inventory reports on Wednesdays at 10:30 ET mean a Wednesday-
     only spike at 23:30 (EST) or 22:30 (EDT) for crude oil, fuel oil and low-sulphur fuel oil.
     Compare Wednesdays with the other weekdays in the same slot and regime.
4. **Optional extension.** In the two to three weeks each spring and autumn when US and UK
   clocks disagree, a slot that moves with the US clock is US-driven, and one that moves with
   the UK clock is London-driven (LME).
5. `90_mart/`: `mart.fct_slot_profile` and `mart.dim_slot`; Power BI pages 3 and 4.

**Gate:** the tables exist, the placebo is reported next to the test, and
`outputs/tables/us_clock_test.csv` is written.
**Commit:** `Phase 6: intraday atlas and the US daylight-saving test`

---

### Phase 7 — Part B: night-session event study

**Goal:** H-B1 against H-B2, and H-B3.

1. **`night.adoption`.** One row per contract:
   - adoption day;
   - cohort month `g` (the adoption month if adoption falls within the month's first 5 trading
     days, otherwise the next month; in the second case the adoption month is excluded);
   - pre and post months available;
   - `is_eligible` (at least 12 pre and 12 post months).
   - Bitumen (about 11 pre months) enters with a partial pre-window. Record that as a decision,
     and drop it in the balanced-panel robustness check.
2. **`night.contract_month`.** Outcomes per contract and calendar month. Only months with 10 or
   more valid days; days with `is_rollover` or `is_stale` excluded from return outcomes.

   | Outcome | Definition | Role |
   |---|---|---|
   | `log_var_cc` | ln(mean of `ret_cc`² over the month) | **Primary** (H-B1 vs H-B2) |
   | `pre_day_gap_share` | Σ `pre_day_gap`² / Σ over all segments² | Secondary (H-B3) |
   | `nontrading_share` | (Σ `pre_night_gap`² + Σ `pre_day_gap`²) / Σ over all segments² | Secondary |
   | `log_rv_day` | ln(mean day-session RV), same hours before and after | Secondary |
   | `log_vol_day` | ln(mean day-session volume) | Secondary |
   | `log_vol_total` | ln(mean total volume) | Secondary |
   | `log_oi` | ln(mean closing open interest) | Exploratory |

3. **Estimator: Callaway and Sant'Anna group-time effects, computed as means in SQL.**

   ```
   ATT(g, t) = [ mean(Y_t − Y_{g−1} | cohort g) ]
             − [ mean(Y_t − Y_{g−1} | not yet treated at t, or never treated) ]
   ```

   - Controls are contracts not yet treated at month `t`, plus the never-treated contracts that
     have data at both `t` and `g−1`.
   - For the 2013–2015 cohorts, the long-pre-period controls are PVC, polypropylene and corn
     starch (treated only in 2019), plus later 2013–2015 cohorts before their own adoption, plus
     egg (from late 2013).
   - For the 2019 cohort, the controls are the never-treated contracts with data before 2019
     (egg, apple). Say in the report that this is thin.
   - Event-time aggregate: `ATT(e) = Σ_g w_g · ATT(g, g+e)`, with `w_g` proportional to the
     number of contracts in cohort `g` among those observed at `e`.
   - Post-period summary: the mean of `ATT(e)` over e = 0..11. Pre-trend: `ATT(e)` for
     e = −12..−2.
   - Why not a two-way fixed-effects regression: with staggered adoption and heterogeneous
     effects it compares late adopters against early adopters used as controls
     (Goodman-Bacon 2021). Write that down in `DECISIONS.md`.
4. **Inference, all in SQL.**
   - **Contract-cluster bootstrap:** 999 replicates. Treated and control contracts are
     resampled with replacement; draw `k` in replicate `rep` is contract number
     `hash(rep || '-' || k) % n`. Report the 2.5 and 97.5 percentiles.
   - **Randomisation inference:** reassign the observed adoption months across the 18 treated
     contracts (hash-seeded permutations), recompute the post-period summary, 999 times, and
     report the two-sided p-value.
   - **Placebo:** move every adoption date back 12 months and use only pre-adoption data. The
     estimate should be about zero.
5. **The 2020 switch-off (secondary design, reversal).**
   - Treated: every contract that had a night session in January 2020. Controls: the day-only
     contracts trading then (apple, egg, jujube, urea).
   - Window: weekly, January to June 2020.
   - Outcomes: `pre_day_gap_share` and `nontrading_share` are the mechanical prediction — when
     the night session disappears, the 09:00 open must absorb the overnight information. Also
     `log_var_cc`.
   - COVID-19 contaminates the *level* outcomes, so report them as descriptive only. The share
     outcomes are the test.
6. **Night shortenings (secondary, dose).** For each shortening in `core.session_history`,
   compare night-session variance per trading hour and the `pre_day_gap` share in the six months
   before and after. This is descriptive: there is one shortening date per exchange, and no
   clean control.
7. `90_mart/`: `mart.fct_event_att`, `mart.fct_contract_month`, `mart.dim_event_time`,
   `mart.fct_day_segment`. Power BI pages 5 and 6.

**Gate:** the pre-trend coefficients are reported whatever they show. If they reject parallel
trends, the report says so and leads with the 2020 reversal and the share outcomes.
`outputs/tables/night_att.csv` and `night_inference.csv` are written.
**Commit:** `Phase 7: night-session event study, 2020 reversal, shortenings`

---

### Phase 8 — Part C: market closures

**Goal:** H-C1, H-C2 and H-C3.

1. **`closure.gap_variance`.** From `core.gaps`, for every overnight, weekend and holiday gap:
   - `variance_ratio` = `ret_gap`² / baseline;
   - the baseline is the contract's mean squared ordinary overnight gap return in trading days
     −60 to −6 and +6 to +60 around the gap.
   - Exclude rollover-flagged days and data gaps.
2. **H-C1 (French and Roll).** Bin the gaps by `gap_hours` (for example 6–18, 18–30, 54–70,
   70–120, 120–200 and over 200 hours).
   - Report the mean `variance_ratio` per bin with bootstrap intervals, resampled over closure
     events so that every contract's copy of the same holiday moves together.
   - Compare variance per non-trading hour with variance per trading hour, both from
     `core.fct_day`.
3. **H-C2 (linkage).** The same bins by linkage group (`international` against `domestic`;
   `partial` is dropped from the primary test).
   - Statistic: the difference in the slope of `variance_ratio` on `gap_hours` across holiday
     gaps, computed as a closed-form OLS slope with `regr_slope()` per group.
   - Inference: bootstrap over closure events. Robustness: include `partial` on either side.
4. **H-C3 (de-risking).** For closures of 7 or more calendar days:
   - Δln(open interest) and ln(volume ratio) on days −3 to −1, against the same weekday in the
     baseline window;
   - exclude closures within ±3 trading days of a rollover;
   - and on days +1 to +5, the day-session RV ratio, to see how the reopening shock decays.
5. **Special cases.** The 2020 Spring Festival closure was extended, and the market reopened
   into the COVID-19 shock. Report it separately and exclude it from the primary estimates.
6. `90_mart/`: `mart.fct_gap`, `mart.fct_closure_window`. Power BI page 7.

**Gate:** `outputs/tables/closure_bins.csv` and `closure_linkage_test.csv` are written, and the
2020 special case is reported separately.
**Commit:** `Phase 8: market closures, variance per non-trading hour, linkage test`

---

### Phase 9 — Robustness

**Goal:** show which conclusions survive which choices. Put every variant in one long table,
`robust.results` (variant, statistic, estimate, interval, n).

| Variant | Applies to |
|---|---|
| Compatibility pipeline (the companion's fixed session templates) | All |
| Exclude rollover days and ±1 day | A, B, C |
| Exclude limit (stale) days | A, B, C |
| Exclude the second half of 2015 (equity crash) and the first half of 2020 | A, B |
| Event windows ±6 and ±24 months | B |
| Balanced panel only (drops bitumen) | B |
| Controls: never-treated only; not-yet-treated only | B |
| Leave one cohort out (7 runs) | B |
| Levels instead of logs for variance outcomes | B |
| Exclude the week around each US and UK DST switch | A |
| Close-to-close five-minute returns instead of bar-internal returns | A |
| Winsorise `variance_ratio` at the 99th percentile | C |
| Linkage: move `partial` to each side | C |

Power BI page 8 shows the dot plot.

**Gate:** each headline claim in the report names the variants under which it fails, if any.
**Commit:** `Phase 9: robustness variants`

---

### Phase 10 — Power BI semantic model and report

**Goal:** the full report in §7, finished to a publishable standard.

1. Load every mart; complete the star schema in §7.2; write the measures in §7.3, each with a
   description (shown on hover) and in display folders (Volatility, Liquidity, Price discovery,
   Event study, Closures).
2. Build pages 1–9 of §7.4.
3. Model hygiene:
   - hide key columns and raw sums;
   - set formats (percent, basis points);
   - set the sort-by columns (slot, segment, event time);
   - remove unused columns.
   - Check the model size in the Performance analyzer and in the file size, aiming for about
     100 MB or less. Check that no visual takes over 1 second.
4. Accessibility and consistency:
   - one sector palette throughout, and never colour alone to encode a finding;
   - alt text on every visual;
   - titles written as findings ("Night trading moved variance out of the 09:00 gap"), not as
     field names.
5. Add bookmarks for a guided path through the three parts and a *Reset filters* button.
6. Export the PDF to `report/`, and one PNG per page to `outputs/figures/dashboard/`.

**Gate:** a second person, or a fresh look a day later, can answer each research question from
the report alone.
**Commit:** `Phase 10: semantic model and report`

---

### Phase 11 — Write-up and release

**Goal:** a repository that stands on its own.

1. `report/REPORT.md`, about 15–25 pages:
   - abstract;
   - trading-hours background in China;
   - data and the SQL pipeline, including the reconciliation and the departures;
   - Part A, Part B and Part C, each as question, design, result, inference;
   - robustness;
   - limitations: 18 treated contracts, thin 2019 controls, COVID-19, main-contract splicing,
     no overseas data;
   - conclusion; references.
   - Figures are the dashboard PNGs.
2. `README.md` as a research brief, in the same style as the companion:
   - the question and the answer, with the three headline numbers;
   - a screenshot of the report;
   - the data statement and licence note;
   - how to reproduce (`conda env create`, copy the CSVs, `python pipeline.py all`, open the
     `.pbip`, set `MartsFolder`, refresh).
3. `docs/DATA_DICTIONARY.md`: every `clean.*`, `core.*` and `mart.*` column, with its type,
   unit and definition. It can be generated from DuckDB's `information_schema.columns` plus a
   descriptions seed.
4. Final checks:
   - a fresh clone plus the raw CSVs plus `python pipeline.py all` reproduces
     `outputs/tables/` byte-for-byte;
   - `git ls-files` contains no data file, no `.pbix` and no `cache.abf`;
   - SQLFluff is clean.
5. Tag `v1.0`.

**Commit:** `Phase 11: technical report, README, data dictionary`

---

## 9. Risks and mitigations

| Risk | Consequence | Mitigation |
|---|---|---|
| Pre-trends in Part B reject parallel trends | The causal reading of the adoption effect fails | Pre-registered response: report it and lead with the 2020 reversal and the share outcomes, which are mechanical rather than behavioural |
| Few treated units (18) in 7 cohorts | Wide intervals; asymptotic standard errors unreliable | Randomisation inference as the primary p-value; the bootstrap as a secondary interval |
| Thin controls for the 2019 cohort | That cohort's effect is poorly identified | Report cohort-level estimates; leave-one-cohort-out robustness |
| Main-contract splicing puts calendar-spread jumps into gap returns | Inflates non-trading variance in Parts B and C | Exclude `is_rollover` days in the primary specification; the robustness row adds ±1 day |
| Limit days understate intraday variance | Distorts RV-based outcomes | Exclude `is_stale` in the primary specification; robustness row |
| COVID-19 in 2020 | Contaminates level outcomes in the switch-off design | Use share outcomes as the test; levels are descriptive |
| MAD outlier flags do not reconcile exactly (median ties, floating point) | Blocks Phase 3 | Explain and bound every residual row, and accept it only if the total effect on daily RV is below 1e-10 relative |
| 7.8 GB RAM with Power BI and DuckDB open together | Slow or failed refreshes | `memory_limit = 3GB`; aggregate marts only; close the DuckDB CLI during builds |
| Power BI features still in preview in the installed build (`.pbip`, TMDL) | Project format changes | Keep the Desktop build current through the Store; commit only after a successful save and reopen |
| Existing literature on Chinese night trading | Reduced novelty | Phase 1 search; position against it |

---

## 10. Initial decisions (copy to `docs/DECISIONS.md`)

1. **DuckDB, not a database server.** The data fits in an in-process engine, it reads Parquet
   and CSV directly, and it has the statistical aggregates the study needs (`corr`,
   `regr_slope`, `quantile_cont`, window `median`). No server competes with Power BI for memory.
2. **Plain SQL files and a small runner, not dbt.** Around 40 SQL files do not need a framework.
   Reconsider dbt-duckdb if the model count passes about 60 or if lineage docs become important.
3. **Power BI reads Parquet exports, not a live DuckDB connection.** No ODBC driver to install,
   reproducible refreshes, and the `.pbip` stays free of connection credentials.
4. **The companion pipeline is a reference, not a dependency.** Rebuilding the cleaning step in
   SQL is part of the work, and reconciliation proves it.
5. **Session hours are derived from the data over time**, not from one template per contract.
6. **Randomness is hash-based**, so every bootstrap and permutation is reproducible regardless of
   thread count.
7. **No two-way fixed-effects regression for the staggered design**; group-time means instead
   (Callaway and Sant'Anna 2021).
8. **Monthly grain for Part B**, to average out daily noise in squared returns and to keep the
   event-study tables small.
9. **Tableau is out of scope.**

---

## 11. References

- Admati, A. R., and Pfleiderer, P. (1988). A theory of intraday patterns: Volume and price
  variability. *Review of Financial Studies*, 1(1), 3–40.
- Andersen, T. G., and Bollerslev, T. (1997). Intraday periodicity and volatility persistence in
  financial markets. *Journal of Empirical Finance*, 4(2–3), 115–158.
- Andersen, T. G., Bollerslev, T., Diebold, F. X., and Vega, C. (2003). Micro effects of macro
  announcements: Real-time price discovery in foreign exchange. *American Economic Review*,
  93(1), 38–62.
- Barclay, M. J., and Warner, J. B. (1993). Stealth trading and volatility: Which trades move
  prices? *Journal of Financial Economics*, 34(3), 281–305.
- Callaway, B., and Sant'Anna, P. H. C. (2021). Difference-in-differences with multiple time
  periods. *Journal of Econometrics*, 225(2), 200–230.
- Cao, C., Ghysels, E., and Hatheway, F. (2000). Price discovery without trading: Evidence from
  the Nasdaq preopening. *Journal of Finance*, 55(3), 1339–1365.
- French, K. R., and Roll, R. (1986). Stock return variances: The arrival of information and the
  reaction of traders. *Journal of Financial Economics*, 17(1), 5–26.
- Goodman-Bacon, A. (2021). Difference-in-differences with variation in treatment timing.
  *Journal of Econometrics*, 225(2), 254–277.
- Roth, J., Sant'Anna, P. H. C., Bilinski, A., and Poe, J. (2023). What's trending in
  difference-in-differences? A synthesis of the recent econometrics literature. *Journal of
  Econometrics*, 235(2), 2218–2244.
- To add in Phase 1: studies of night-trading introductions on the Chinese commodity exchanges.
