# Decision log

Every decision not fixed in `PROJECT_PLAN.md`, with its date and reason. Newest entries at the
bottom. Entries are never deleted; a reversed decision gets a new entry that points to the old one.

## Initial decisions (from `PROJECT_PLAN.md` §10), 2026-09-10

1. **DuckDB, not a database server.** The data fits in an in-process engine, it reads Parquet and
   CSV directly, and it has the statistical aggregates the study needs (`corr`, `regr_slope`,
   `quantile_cont`, window `median`). No server competes with Power BI for memory.
2. **Plain SQL files and a small runner, not dbt.** Around 40 SQL files do not need a framework.
   Reconsider dbt-duckdb if the model count passes about 60 or if lineage docs become important.
3. **Power BI reads Parquet exports, not a live DuckDB connection.** No ODBC driver to install,
   reproducible refreshes, and the `.pbip` stays free of connection credentials.
4. **The companion pipeline is a reference, not a dependency.** Rebuilding the cleaning step in SQL
   is part of the work, and reconciliation proves it.
5. **Session hours are derived from the data over time**, not from one template per contract.
6. **Randomness is hash-based**, so every bootstrap and permutation is reproducible regardless of
   thread count.
7. **No two-way fixed-effects regression for the staggered design**; group-time means instead
   (Callaway and Sant'Anna 2021).
8. **Monthly grain for Part B**, to average out daily noise in squared returns and to keep the
   event-study tables small.
9. **Tableau is out of scope.**

## Phase 0, 2026-09-10

10. **Repository location.** The repository is `cc_sql/cn-futures-trading-hours/`. The companion's
    files had already been copied into `cc_sql/`; they were *moved* from there into the
    repository, not copied a second time. This project never reads the companion repository
    itself.
11. **Reference layout follows the plan.** The 34 cleaned-bar Parquet files are in
    `data/reference/interim/`; `rv_panel.parquet`, `cleaning_report.csv` and
    `rollover_candidates.csv` are in `data/reference/`.
12. **Conda environment.** A dedicated environment `tradinghours` at
    `D:\CondaData\envs\tradinghours`, created from `environment.yml`. The existing `daenv`
    environment was not reused: it has no DuckDB and carries many unneeded packages. Resolved
    versions: Python 3.13.15, DuckDB 1.4.1, PyYAML 6.0.3, SQLFluff 4.3.0.
13. **`commodities.yaml` is not carried into the repository.** It was read once to generate
    `seeds/contracts.csv` and stays outside the repository in `cc_sql/config/`.
14. **Linkage classification is the draft in plan Phase 0, step 6**, with a one-line reason per
    contract in `seeds/contracts.csv`. It is final only once committed in Phase 1.
15. **Seed formats.**
    - `session_blocks.csv`: the `night` row is the corrected rule's envelope (21:00 to 03:00,
      last stamp 02:55). Each contract's actual night end is derived from the data in Phase 4.
    - `us_scheduled_events.csv`: `days_of_week` holds ISO weekday numbers (Monday = 1) of the US
      Eastern date, separated by `|`. The whole Beijing night session, 21:00 to 02:30, falls on a
      single US Eastern date. `applies_to` is `all` or a `|`-separated list of slugs. A
      `description` column was added.
16. **Outlier reconciliation target.** Phase 3 reconciles `is_outlier` against the interim Parquet
    files (8,845 flags, equal to `sum(rv_panel.n_outliers)`), not against `n_outliers_zeroed` in
    `cleaning_report.csv` (10,979). The likely cause, to confirm in Phase 3: the report counts
    flags before step `080_zero_rv` drops days whose only non-zero returns were zeroed outliers.
    Aluminium shows the largest gap (3,686 against 1,934).
17. **Reference schemas.** The interim Parquet files have no `slug` column (the slug is the file
    name). Their `trading_day`, and `rv_panel.date`, are `TIMESTAMP_NS`; `rv_panel` names the
    trading day `date`. Reconciliation tests cast these to `DATE`.
18. **Runner conventions.** `pipeline.py` turns each leaf key of `config.yaml` (except the
    `duckdb` section) into a DuckDB variable of the same name, e.g. `getvariable('mad_k')`, and
    refuses duplicate names. Lists become DuckDB lists; decimals are cast to `DOUBLE`, because a
    bare `10.0` literal is a `DECIMAL`. **`getvariable()` is used only in `CREATE TABLE` bodies,
    never in a view:** a view is re-bound on every read, and in a session without the variables
    (the DuckDB CLI, for instance) it returns NULLs and fails with a type error. `export` writes
    `mart.*` to `marts/*.parquet`; CSV exports to `outputs/tables/` are added when the first
    evidentiary table exists (Phase 3).
19. **`.gitattributes` forces LF line endings.** This machine has `core.autocrlf = true`, which
    would rewrite seeds and `outputs/tables/*.csv` with CRLF on checkout and break the Phase 11
    check that a fresh clone reproduces `outputs/tables/` byte-for-byte.

## Phase 1, 2026-09-10

20. **Cohorts are `(g, b)` groups, not adoption dates.** The plan's rule (the adoption month
    counts only if adoption falls within its first 5 trading days) conflicts with a fixed base
    month `g − 1`: for a late-month adopter, `g − 1` is the partly treated adoption month. The
    base month `b` is therefore the last month entirely before adoption, and the adoption month is
    dropped. On the trading calendar the 7 adoption dates give 6 `(g, b)` groups in 5 cohort
    months (`HYPOTHESES.md` §5.2). "Leave one cohort out" therefore has 5 runs, not 7.
21. **The pre-trend summary is `e = −12..−3`**, not `−12..−2`. `e = −2` is the base month of the
    late-adopting groups and would add structural zeros.
22. **February to April 2020 are dropped from the Part B panel.** Every night session was
    suspended, so treatment was switched off. This removes event months 10 and 11 of the 2019
    cohort.
23. **Part C scales gap variance by daily close-to-close variance**, not by the ordinary overnight
    gap. The overnight gap is 18 hours for day-only contracts but 6 to 10 hours for night
    contracts, whose night session absorbs overseas news. The plan's baseline would therefore
    steepen the international slope in H-C2 by construction. It is kept as a robustness row.
24. **H-C2 uses holidays from 2010 onward**, when both linkage groups have at least two contracts.
    All holidays is a robustness row.
25. **H-A2 predicted pairs:** 21:20 and 22:30 and 23:00 in EST, and 22:00 in EDT.
    - 21:30 is excluded because it is predicted in both regimes.
    - The 08:20 and 08:30 ET events in EDT fall before the 21:00 open.
    - Reference slots that are themselves predicted slots are dropped from the spike's reference
      mean.
    - The day-session placebo uses the pairs shifted back by 12 hours whose reference slots stay
      inside one block (09:20 and 11:00).
26. **Primary specification excludes rollover and limit (stale) days in all three parts.** The
    plan's robustness rows are read as "also drop ±1 day around rollovers" and "include stale
    days".
27. **Equivalence margin for H-B1: ±0.10 in log variance.** Redistribution is supported only if
    the 95 percent interval for `θ_post` lies inside it. Otherwise a non-significant result is
    reported as inconclusive, not as support for H-B1.
28. **Bitumen is a pre-specified exception to the 12-pre-month rule**, as in the plan; the
    balanced-panel robustness row drops it.
29. **The Chinese-language literature search (CNKI, Baidu Scholar) could not be done from this
    machine's tools**; both sites refuse automated access. The English-language search is
    recorded in `METHODOLOGY.md` §1.
30. **`HYPOTHESES.md` was committed (448155f) with the CNKI search still open**, with the
    author's approval, together with all Phase 1 proposals (entries 20–28). This supersedes the
    note in `METHODOLOGY.md` §2 that the search must come first.

## Phase 2, 2026-09-10

31. **Raw data profile.**
    - 6,014,790 bars in 34 files with identical headers.
    - No NULL or NaN fields, every stamp on the five-minute grid, no duplicate
      `(slug, ts)`.
    - 19 bars have a volume ending in .5 (sugar 2009–2011, a few copper, aluminium, soybean oil,
      zinc and tin bars), so `volume` stays `DOUBLE`.
    - `tests/sql/stg_no_nulls.sql` guards the clean profile against a changed raw file.
32. **`stg.bars` is stored in `(slug, ts)` order.** It costs about a second at build time and
    helps every later window function over `(slug, ts)`. Build time is about 4.5 s, and the
    warehouse is 227 MB after staging.
33. **Seed tables carry clock minutes as well as `TIME`.** `seed.session_blocks` has `start_min`,
    `end_min` and `last_stamp_min`, and `seed.us_scheduled_events` has `et_min`, all comparable
    with `stg.bars.clock_min`. `days_of_week` and `applies_to` become lists.
34. **Two tests beyond the plan's three:** `seed_contracts.sql` (unique keys, known exchanges,
    and the pre-registered linkage counts 17/8/9) and `stg_no_nulls.sql`. Each Phase 2 test was
    checked to fail on a deliberately broken copy of the data.
35. **SQLFluff is kept clean from Phase 2 on**, rather than only at release. Its column-order rule
    (ST06) puts plain columns before computed ones, which is accepted.
