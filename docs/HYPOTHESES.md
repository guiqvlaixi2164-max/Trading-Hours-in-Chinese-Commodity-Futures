# Pre-registered hypotheses and tests

**Registered:** 2026-09-10, Phase 1, before any file exists in `sql/50_night/` or
`sql/60_closure/`. The git commit that adds this file is the timestamp.

**Rules.** Everything below is fixed. A change after the commit is added as a dated amendment at
the end of this file, with its reason, and the affected result is then reported under both the
original and the amended specification. Parameter names in `code` refer to `config.yaml`.

---

## 1. What was known when this was written

This is not a blind registration. The following were seen before it was written:

- **Facts in `PROJECT_PLAN.md` §2**, observed on the companion's cleaned data while planning:
  - the adoption dates;
  - the 2020 suspension;
  - the 2015, 2016 and 2019 shortenings;
  - holiday cancellations of the night session;
  - the distribution of calendar gaps;
  - unbalanced coverage;
  - **a gold night-session table of mean absolute returns by US daylight-saving regime**
    (plan §2.5).
- **That gold table bears directly on H-A2.** The 21:20 Beijing slot was elevated in US winter and
  not in US summer. The 08:20 ET event in `seeds/us_scheduled_events.csv` was chosen with that
  table in view. So H-A2 is not a blind test for gold. For that reason, §4.2 pre-specifies the
  test with gold and silver excluded as well.
- **Phase 0 checks on the reference files:** row counts, flag counts and the trading calendar
  used to date cohorts (§5.2).
- **The literature** in `docs/METHODOLOGY.md` §1. Earlier studies report lower daytime and opening
  volatility after night sessions began (Jiang, Kellard and Liu 2020; Xia, Xiong and Li 2024;
  Fung, Mai and Zhao 2016).

No outcome variable in §4 to §6 had been computed on any data when this was written.

---

## 2. Common definitions

- **Panel.** The 34 contracts in `seeds/contracts.csv`, cleaned by the pipeline in its default
  (not compatibility) mode.
- **Valid day for return outcomes.** A trading day in `core.fct_day` with `is_complete_day`, and
  neither `is_rollover` nor `is_stale`. Volume and open-interest outcomes use every complete day.
- **Returns.** Natural-log returns, as decimals.
- **Segments.** The eight segments of plan Phase 4, step 4. On a day without a night block,
  `pre_night_gap` and `night` are 0, and `pre_day_gap` = ln(09:00 first open / previous
  trading day's last close).
- **US daylight-saving regime (EST or EDT).** Whether New York observes daylight saving at the
  bar's timestamp, converted with the ICU time-zone data. A whole night session falls on one US
  Eastern date, so it always has a single regime.
- **Significance.** 5 percent, two-sided, for every test.
- **Resampling.** 999 replications for every bootstrap and permutation (`bootstrap_reps`,
  `permutation_reps`). Draws are hash-based: replication `r`, draw `k` of analysis `a` uses
  `hash(a || '-' || r || '-' || k)`.
  - Permutation p-value: (1 + #{|T*| ≥ |T|}) / 1000.
  - Bootstrap interval: the 2.5th and 97.5th percentiles.
- **Multiplicity.** There are three confirmatory tests (§3), one per research part, each on a
  separate question. They are not adjusted for multiplicity. Everything else is exploratory and
  is reported with unadjusted intervals, labelled as exploratory.

---

## 3. Confirmatory and exploratory analyses

| Hypothesis | Status | Primary statistic | Inference |
|---|---|---|---|
| H-A1 U-shape | Exploratory (descriptive) | Opening and closing periodicity ratios | None (median and range across contracts) |
| **H-A2 US clock** | **Confirmatory** | `T`, §4.2 | Week-level permutation of regime labels |
| **H-B1 vs H-B2** | **Confirmatory** | `θ_post` on `log_var_cc`, §5.4 | Randomisation inference over adoption dates; cluster bootstrap interval |
| H-B3 day session | Exploratory | `θ_post` on secondary outcomes | Same as H-B |
| 2020 reversal | Exploratory, pre-specified | Share outcomes, §5.7 | Week-level permutation |
| Shortenings | Descriptive | Before/after, §5.8 | None |
| H-C1 French–Roll | Exploratory | Mean `variance_ratio` by gap-length bin | Closure-event bootstrap |
| **H-C2 linkage** | **Confirmatory** | `Δ` = slope(international) − slope(domestic), §6.3 | Closure-event bootstrap |
| H-C3 de-risking | Exploratory | Δln(open interest), days −3 to −1 | Closure-event bootstrap |

---

## 4. Part A — intraday atlas

### 4.1 H-A1 (exploratory)

- **Return used:** the bar-internal return ln(close / open).
- **Sample:** trading days from 1 January 2014 (`first_year`), or from the contract's adoption if
  later. Days that are not valid are excluded.
- **Per contract and block, three measures:**
  - opening-slot periodicity factor / block median;
  - closing-slot periodicity factor / block median;
  - volume share of the first and last 15 minutes.
- **Reported:** median and range across contracts, and by sector.
- **H-A1 is described as holding** if the median ratio exceeds 1 at every block's opening and
  closing slot, and the 21:00 and 09:00 opening ratios are the two largest.

### 4.2 H-A2 (confirmatory)

**Slot means.** For contract `c`, regime `R` and clock slot `s`:

- `m_R(s)` = mean |bar-internal return| over the valid-day bars at `s` in regime `R`, on the §4.1
  sample.
- A slot mean needs at least 100 bars in each regime. Otherwise that pair is dropped for the
  contract.

**Spike.** `S_R(s) = m_R(s) − mean{ m_R(s+k) : k ∈ {−3, −2, +2, +3} }`, where the reference
slots:

- skip `s±1` to avoid spill-over;
- must lie in the same block as `s`;
- must not be a predicted slot (table below) in either regime.

At least two reference slots must remain, or the pair is dropped for the contract.

**Predicted pairs.** Beijing = ET + 13 h in EST and ET + 12 h in EDT. Only pairs whose slot, and
whose reference slots, can lie inside a night session are used.

| Clock slot | Predicted in | Event (ET) | Other regime at that clock time |
|---|---|---|---|
| 21:20 | EST | CME metals open, 08:20 | 09:20 ET: no event |
| 22:30 | EST | US equity open, 09:30 | 10:30 ET: no all-contract event |
| 23:00 | EST | Second-tier releases, 10:00 | 11:00 ET: no event |
| 22:00 | EDT | Second-tier releases, 10:00 | 09:00 ET: no event |

**Pairs excluded:**

- **21:30:** it is predicted in both regimes (08:30 macro releases in EST, 09:30 equity open in
  EDT), so the difference between regimes has no predicted sign.
- **08:20 and 08:30 ET in EDT:** these map to 20:20 and 20:30 Beijing, before the night open.
- **23:00** is available only for contracts whose night session ran past 23:15 (last stamp 23:25
  or later) during the sample.

**Statistic.**

- For each pair: `d_c(s) = S_pred(s) − S_other(s)`.
- For each contract: `T_c` = the mean of `d_c` over its available pairs.
- **`T` = the mean of `T_c` over the 17 `international` contracts**, equally weighted.
- H-A2 predicts `T > 0`.

**Inference.** A permutation test:

- Each calendar week (Monday to Friday, US Eastern dates) keeps its bars together.
- The EST and EDT labels are shuffled across weeks, with the number of weeks in each regime kept
  as observed.
- The same permutation is applied to every contract, so dependence across contracts is kept.

**Decision.** H-A2 is supported if `T > 0` and `p < 0.05`, **and the placebo passes**.

**Placebo (day session).**

- The same statistic on the predicted pairs shifted back by 12 hours: 09:20 (EST) and 11:00 (EST).
- The 10:30 and 10:00 shifts are dropped because their reference slots fall outside a block.
- Beijing 09:00–15:00 is the US night.
- The placebo fails if its `p < 0.05`. Then the H-A2 result is reported as not credible,
  whatever `T` shows.
- The full EST-minus-EDT day-session profile is also shown, descriptively.

**Secondary tests (pre-specified, not confirmatory):**

1. **Linkage contrast:** `T_international − T_domestic`, where the domestic group is the domestic
   contracts with night sessions (rebar, coke, PVC, corn starch). Same permutation. H-A2 predicts
   a positive difference.
2. **Energy (EIA):** for crude oil, fuel oil and low-sulphur fuel oil, `E = m_Wed(s) −
   m_other weekdays(s)`, at 23:30 in EST and 22:30 in EDT (the EIA report at 10:30 ET), where
   each slot lies inside the contract's night session.
   - The prediction is `E > 0` in the predicted regime, and larger than at the same clock slot in
     the other regime.
   - Permutation: within each week, the Wednesday label is moved to a randomly drawn weekday.
3. **Without gold and silver:** `T` recomputed on the other 15 international contracts (see §1).

---

## 5. Part B — night-session adoption

### 5.1 Units and treatment

- **Treatment:** having a night session.
- **Adoption day:** the contract's first trading day with at least 5 night bars
  (`min_night_bars_first_day`).
- **Shortenings and the 2020 suspension do not change treatment status.** The suspension is
  handled in §5.5.

### 5.2 Cohorts and base periods

- **Cohort month `g`:**
  - the adoption month, if adoption falls within its first 5 trading days;
  - otherwise the following month.
- **Base month `b`:** the last calendar month that lies entirely before adoption.
  - When adoption falls later than the 5th trading day, `b = g − 2`. The adoption month
    (`g − 1`) is then partly treated, so it is dropped for that contract.
  - Otherwise `b = g − 1`.

On the exchange trading calendar the rule gives:

| Adoption day | Trading day of month | `g` | `b` | Contracts |
|---|---|---|---|---|
| 2013-07-08 | 6th | 2013-08 | 2013-06 | gold, silver |
| 2013-12-23 | 16th | 2014-01 | 2013-11 | copper, aluminium, zinc |
| 2014-07-07 | 5th | 2014-07 | 2014-06 | coke |
| 2014-12-15 | 11th | 2015-01 | 2014-11 | methanol, sugar |
| 2014-12-29 | 21st | 2015-01 | 2014-11 | soybean oil, soybean meal, rubber, rebar, iron ore, coking coal |
| 2015-01-06 | 2nd | 2015-01 | 2014-12 | bitumen |
| 2019-04-01 | 1st | 2019-04 | 2019-03 | polypropylene, PVC, corn starch |

- That gives 18 treated contracts in **6 `(g, b)` groups and 5 cohort months**.
- Phase 7 recomputes these from the pipeline's own tables. Any difference is an amendment.

**Eligibility:**

- A treated contract is eligible with at least 12 **pre months** and at least 12 **post months**.
  - Pre months: months `≤ b` with at least 10 valid days.
  - Post months: months `≥ g` with at least 10 valid days, excluding February to April 2020.
- **Bitumen is included in the primary estimate even if it has fewer than 12 pre months**; the
  balanced-panel robustness row drops it.
- MEG and LPG are not eligible as treated units.
- Contracts listed with a night session from their first day are never treated units, and never
  controls.

### 5.3 Outcomes

Monthly values per contract `c` and calendar month `t`. A month enters only with at least
10 valid days (for return outcomes) or 10 complete days (for volume and open interest).

| Outcome | Definition | Role |
|---|---|---|
| `log_var_cc` | ln( mean over valid days of `ret_cc`² ), where `ret_cc` is the 15:00-to-15:00 close-to-close return | **Primary** |
| `pre_day_gap_share` | Σ `pre_day_gap`² / Σ over the 8 segments of segment² (sums over the month's valid days) | Secondary (H-B3) |
| `nontrading_share` | (Σ `pre_night_gap`² + Σ `pre_day_gap`²) / Σ over the 8 segments of segment² | Secondary |
| `log_rv_day` | ln( mean day-session realised variance ), where day-session RV is the sum of squared within-block five-minute returns in `morning_1`, `morning_2` and `afternoon` | Secondary |
| `log_vol_day` | ln( mean day-session volume ) | Secondary |
| `log_vol_total` | ln( mean total volume ) | Secondary |
| `log_oi` | ln( mean closing open interest ) | Exploratory |

### 5.4 Estimator and the confirmatory test

**Group-time effect.** For each group `(g, b)` and month `t`:

- `ATT(g, b, t)` = mean over the group of (`Y_t − Y_b`) − mean over the controls of
  (`Y_t − Y_b`).
- **Controls:** every contract whose first night month is later than `max(t, b)`, eligible as a
  treated unit or not, plus the never-treated contracts (apple, egg, jujube, peanut, urea).
- Every contract used must have `Y` at both `t` and `b`.

**Event time.**

- `e = t − g`, over the event window −12 to +12 (`event_window`).
- `ATT(e)` = Σ `w · ATT(g, b, g + e)`, where each group's weight `w` is proportional to its number
  of treated contracts observed at `g + e`.
- `e = −1` is missing for the late-adopting groups (the dropped adoption month).

**Summaries.**

- **Post:** `θ_post` = the mean of `ATT(e)` for `e` = 0 to 11, over the event times at which it
  is defined.
- **Pre-trend:** `θ_pre` = the mean of `ATT(e)` for `e` = −12 to −3. This leaves out −2 and −1,
  which are base months for some groups.

**Inference.**

- **Randomisation inference (primary p-value).** The 18 observed `(g, b)` assignments are
  reassigned across the 18 treated contracts by hash-seeded permutation, 999 times, and
  `θ_post` is recomputed. A contract assigned a period where it has no data contributes only
  where both `t` and `b` are observed, the same rule as the actual estimate.
- **Cluster bootstrap (interval).** 999 replications. The 18 treated contracts are resampled with
  replacement, and so are the never-treated contracts. A drawn treated contract also serves as a
  not-yet-treated control for other groups, as in the original sample.

**Confirmatory decision** (`log_var_cc`):

- `θ_post > 0` and `p < 0.05`: evidence for **generation (H-B2)**.
- The 95 percent bootstrap interval lies inside **±0.10** (about ±10 percent in variance):
  evidence for **redistribution (H-B1)**. The margin is small next to the rise that
  proportional generation would imply: 2 to 5.5 extra trading hours on a 3.75-hour day session.
- Neither: **inconclusive**. The interval is reported as the range of effects the data cannot
  rule out.
- `θ_post < 0` and `p < 0.05`: reported as a fall in variance, which neither hypothesis predicts.

**Parallel trends.**

- `θ_pre` is reported with its interval and randomisation p-value, whatever it shows, together
  with every pre-period `ATT(e)`.
- If `θ_pre` has `p < 0.05`, parallel trends are rejected. The report then leads Part B with the
  2020 reversal (§5.7) and the share outcomes.

### 5.5 Months removed

- **February to April 2020 are dropped from the Part B panel for every contract.** No contract
  had a night session then, so treatment was switched off.
  - For the 2019-04 cohort this removes event months 10 and 11 from `θ_post`.
- Months in which a contract has fewer than 10 valid days are missing (§5.3).

### 5.6 H-B3 (exploratory)

- The same estimator and inference, applied to `pre_day_gap_share`, `nontrading_share`,
  `log_rv_day`, `log_vol_day`, `log_vol_total` and `log_oi`.
- **Predictions:**
  - `pre_day_gap_share` falls;
  - `log_rv_day` changes little, because the day session's hours are unchanged;
  - day-session volume changes, sign not predicted.

### 5.7 The 2020 reversal (exploratory, pre-specified)

- **Treated:** contracts with a night session in January 2020.
- **Controls:** apple, egg, jujube and urea.
- **Window:** weekly, from January to June 2020.
- **Periods:**
  - *off*: weeks from 2020-02-03 to the last week without night bars;
  - *before*: January 2020 before the Spring Festival;
  - *after*: May and June 2020.
- **Statistic:** the difference-in-differences of the weekly `pre_day_gap_share` and
  `nontrading_share` (off minus the mean of before and after, treated minus controls).
- **Prediction:** both shares rise while the night session is off.
- **Inference:** permutation of treated and control labels across contracts, 999 times.
- **Level outcomes** such as `log_var_cc` are shown descriptively only, because of COVID-19.

### 5.8 Shortenings (descriptive)

For each change in the modal night end found in `core.session_history`, the report shows night
variance per trading hour and `pre_day_gap_share`, for the six months before and after. There is
no test.

---

## 6. Part C — market closures

### 6.1 Gap sample and variance ratio

- **Gaps included:** every `overnight`, `weekend` and `holiday` gap in `core.gaps`.
- **Gaps excluded:**
  - intraday breaks, suspensions and data gaps;
  - gaps next to a data gap;
  - gaps whose reopening day is `is_rollover`.
- **Ratio.** `variance_ratio` = `ret_gap`² / `V`, where `V` is the contract's mean of `ret_cc`²
  over its valid days in trading days −60 to −6 and +6 to +60 around the gap
  (`baseline_window`).
  - At least 60 valid baseline days are required.
  - The ratio measures the closure's variance in units of one ordinary day's variance.
- **Why a daily baseline, not the plan's overnight one.** The plan scaled by the mean squared
  ordinary overnight gap. That gap is 18 hours for a day-only contract but only 6 to 10 hours for
  a night contract, whose night session absorbs overseas news. So the plan's baseline would
  mechanically steepen the international slope in H-C2. The overnight-gap baseline is kept as a
  robustness row.
- **2020 Spring Festival closure:** excluded from every primary estimate and reported separately.

### 6.2 H-C1 (exploratory)

- **Bins of `gap_hours`:** 6–18, 18–30, 54–70, 70–120, 120–200, and over 200 hours.
- **Reported:** the mean `variance_ratio` per bin, with 95 percent bootstrap intervals.
  - The bootstrap resamples closure events (each gap interval on the exchange calendar, with all
    of its contract rows), 999 times.
- **Also reported:** variance per non-trading hour against variance per trading hour, from
  `core.fct_day`.
- **H-C1 is described as holding** if the mean ratio rises with gap length and the non-trading
  variance per hour is below the trading variance per hour.

### 6.3 H-C2 (confirmatory)

- **Sample:** `holiday` gaps (4 or more calendar days between trading days,
  `holiday_min_calendar_days`) that start on or after 2010-01-01, when both linkage groups have at
  least two contracts.
- **Slopes:** `β_G` = `regr_slope(variance_ratio, gap_hours)` over the `(contract, holiday)` rows
  of group `G`.
- **Statistic:** `Δ = β_international − β_domestic`. The `partial` group is left out.
- **Inference:** bootstrap over holidays; each holiday is resampled with all of its contract rows,
  999 times.
- **Decision:** H-C2 is supported if `Δ > 0` and the 95 percent interval excludes 0.
- **Robustness:** `partial` added to either side; all holidays instead of those from 2010; the
  plan's overnight-gap baseline; `variance_ratio` winsorised at the 99th percentile.

### 6.4 H-C3 (exploratory)

- **Closures:** closures of 7 or more calendar days, excluding closures within ±3 trading days of
  a rollover.
- **Measures:**
  - Δln(open interest) and ln(volume ratio) on days −3 to −1, each against the same weekday in
    the baseline window;
  - the day-session RV ratio on days +1 to +5.
- **Inference:** closure-event bootstrap intervals.
- **Prediction:** open interest falls before long closures.

---

## 7. Linkage classification

The classification is fixed as committed in `seeds/contracts.csv` (`linkage`, `linkage_reason`):

- **17 `international`:** gold, silver, copper, international copper, aluminium, zinc, tin, crude
  oil, fuel oil, low-sulphur fuel oil, soybean meal, soybean oil, soybean No.2, natural rubber,
  TSR 20 rubber, sugar, iron ore.
- **8 `partial`:** bitumen, LPG, MEG, methanol, polypropylene, PSF, butadiene rubber, coking coal.
- **9 `domestic`:** apple, jujube, egg, peanut, corn starch, rebar, coke, PVC, urea.

**The rule:** `international` if an actively traded overseas contract exists for the same
commodity; `domestic` if there is none, or if import controls separate the Chinese price from
overseas prices (Fung, Leung and Xu 2003); otherwise `partial`.

---

## 8. Primary specification and robustness

- **Primary specification for all parts:** default (session-aware) cleaning; valid days as in §2
  (rollover and limit days excluded).
- **Robustness rows** (Phase 9): the variants in `PROJECT_PLAN.md` Phase 9, read as:
  - "exclude rollover days and ±1 day": also drops the day before and after each rollover;
  - "exclude limit (stale) days": inverted, since they are excluded in the primary specification,
    so this row *includes* them;
  - leave one cohort out: 5 runs, one per cohort month.
- **Added here:**
  - H-A2 without gold and silver;
  - H-C2 on all holidays;
  - H-C2 with the overnight-gap baseline.

---

## Amendments

None yet.
