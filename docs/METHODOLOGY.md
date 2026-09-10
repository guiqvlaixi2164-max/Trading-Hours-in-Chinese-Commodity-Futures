# Methodology

Definitions and estimators, with formulas, are added here as each phase builds them (Phases 3 to
9). This first section is the Phase 1 literature review. Full references are in
`PROJECT_PLAN.md` §11 and, from Phase 11, in `report/REPORT.md`.

## 1. Literature review (Phase 1, 2026-09-10)

Each source is summarised in two lines: what it shows, then what it means for this study.
Summaries of the China-specific papers come from their published abstracts.

### 1.1 Intraday patterns and periodicity

- **Admati and Pfleiderer (1988).** Discretionary liquidity traders bunch their trades in time, and
  informed traders follow them, which concentrates volume and price variability in a few periods.
  *Here:* the theoretical basis for the U-shape in H-A1.
- **Andersen and Bollerslev (1997).** The intraday periodicity in five-minute returns hides
  volatility persistence unless it is filtered out first. *Here:* the Periodicity Factor measure,
  i.e. each slot's mean absolute return relative to the day's average.
- **Andersen and Bollerslev (1998).** One year of five-minute DM–dollar returns, modelling the
  intraday pattern, announcement effects and persistence together, with the daylight-saving
  shifts of the pattern handled explicitly. *Here:* the precedent for letting the intraday
  profile move with the overseas clock (H-A2).
- **Harju and Hussain (2011).** Five-minute returns on European stock indices show intraday
  seasonalities tied to scheduled US announcements and the US open. *Here:* one market's
  intraday profile set by another market's clock, which is the mechanism H-A2 tests.

### 1.2 Trading, non-trading and market closures

- **French and Roll (1986).** Variance per hour is far higher when the exchange is open than when
  it is shut, and the 1968 Wednesday closures suggest that trading itself generates variance.
  *Here:* H-C1, and the "generation" side of H-B2.
- **Barclay, Litzenberger and Warner (1990).** When the Tokyo Stock Exchange opened on Saturdays,
  weekend variance rose but weekly variance did not, despite higher weekly volume. *Here:* the
  closest precedent for H-B1 against H-B2, with the same outcome logic (total variance over a
  fixed window, not the variance of the new session).
- **Stoll and Whaley (1990).** Open-to-open variance exceeds close-to-close variance on the NYSE,
  which they attribute to private information revealed at the open and temporary pricing errors.
  *Here:* the reason to treat the opening gap as a separate segment.
- **Ito, Lyons and Melvin (1998).** When lunch-hour trading was allowed in Tokyo FX, lunch variance
  doubled and the intraday U-shape flattened, although public information flow was unchanged.
  *Here:* a clean trading-hours intervention in another market; the model for Part B's design.
- **Hong and Wang (2000).** In a model with periodic closures, returns show U-shaped mean and
  volatility, open-to-open returns are more volatile than close-to-close returns, and trading
  periods are more volatile than non-trading periods. *Here:* theoretical predictions for
  Parts A and C.

### 1.3 Price discovery

- **Barclay and Warner (1993).** Medium-sized trades account for most cumulative price change;
  they introduce weighted price contribution. *Here:* the WPC measure in §7.3 of the plan.
- **Cao, Ghysels and Hatheway (2000).** Non-binding pre-open quotes on Nasdaq already carry price
  discovery. *Here:* the first bar's open comes from the call auction (20:55–21:00 and
  08:55–09:00), so the opening segments measure call-auction price discovery.
- **Barclay and Hendershott (2003).** On Nasdaq, after-hours trades are few but carry information;
  how much price discovery happens depends on the volume of liquidity trading. *Here:* a thin
  night session may move variance without improving price efficiency.

### 1.4 Scheduled announcements and linkage to overseas markets

- **Andersen, Bollerslev, Diebold and Vega (2003).** FX rates jump within minutes of US macro
  surprises, and the response is asymmetric. *Here:* the scheduled US event times in
  `seeds/us_scheduled_events.csv`.
- **Cai, Ahmed, Jiang and Liu (2020).** For eight Chinese commodity futures in 2013–2016, surprises
  in 19 US announcements move returns, volume and volatility, gold and silver most. *Here:* the
  closest evidence for H-A2; this study identifies the same channel from the DST clock shift,
  without announcement data (outside data are a non-goal).
- **Fung, Leung and Xu (2003).** Copper and soybeans: the US market transmits information to
  China; wheat, which is heavily regulated, is segmented. *Here:* the basis of the linkage rule:
  import restrictions make a contract `domestic` (e.g. corn starch).
- **Liu and An (2011).** Bidirectional but asymmetric price and volatility transmission between US
  and Chinese copper and soybean futures and spot markets. *Here:* supports `international` for
  copper and the soybean complex.

### 1.5 Night trading in Chinese futures (the specific search)

- **Fung, Mai and Zhao (2016).** Daily data on 23 commodity futures: after night sessions
  launched, prices became more efficient, less volatile and closer to normal. *Here:* the broadest
  earlier study; before/after comparison on daily data, no staggered-design estimator.
- **Jiang, Kellard and Liu (2020).** SHFE gold and silver: after the night session, activity and
  liquidity rose, opening volatility fell, Shanghai's price-discovery share fell and spillovers with
  COMEX grew both ways. *Here:* the 2013 gold and silver cohort, studied on its own.
- **Klein and Todorova (2021).** The 2013 night session caused a structural break in copper's
  realised volatility; copper night volatility follows the preceding LME volatility, while
  aluminium is more insulated. *Here:* the 2013 base-metals cohort; supports linkage heterogeneity.
- **Yao, Hui and Kang (2021).** SHFE gold: before night trading, large swings came from overnight
  moves abroad; night sessions improve HAR volatility forecasts. *Here:* forecasting (a non-goal);
  cited for the overnight-information mechanism.
- **Xia, Xiong and Li (2024).** Difference-in-differences on tick data: night trading reduced
  daytime volatility in corn and corn starch futures, mostly in the first session. *Here:* the one
  DID study found, for one contract pair of the 2019 cohort; lower daytime volatility is what
  redistribution (H-B1) predicts, so this result cannot separate H-B1 from H-B2.
- **Ma, Bouri, Xu and Zhou (2025).** In gold and silver, intraday return predictability moved from
  the first half-hour of the day session to the first half-hour of the night session.
  *Here:* supports night opens as the main information events (H-A1).
- **He, Li and Hu (2025).** Night-session realised variance forecasts next-day daytime realised
  volatility for 10 commodity futures, in and out of sample. *Here:* forecasting (a non-goal); night
  variance carries information about the next day.

### 1.6 Staggered difference-in-differences

- **Callaway and Sant'Anna (2021).** Group-time average treatment effects for staggered adoption,
  using not-yet-treated or never-treated controls. *Here:* the Part B estimator, computed as means
  in SQL.
- **Goodman-Bacon (2021).** The two-way fixed-effects DID estimate is a weighted average of all
  two-by-two comparisons, including ones that use earlier-treated units as controls. *Here:* the
  reason not to use a two-way fixed-effects regression (decision 7).
- **Roth, Sant'Anna, Bilinski and Poe (2023).** A synthesis covering heterogeneous effects,
  pre-trend testing and its limits, and inference with few clusters. *Here:* the pre-trend and
  inference choices in Phase 7.

## 2. Positioning

The question is not new: at least seven published studies look at the introduction of night
sessions on Chinese futures exchanges. This study differs from them in five ways:

1. **Design.** Earlier work studies one or two contracts, or compares before and after on daily
   data. None found pools all adoption cohorts (18 contracts, 7 dates) with an estimator that is
   robust to staggered, heterogeneous effects.
2. **Outcome.** Earlier work mostly reports lower daytime or opening volatility after adoption.
   Redistribution (H-B1) predicts exactly that, so it does not separate redistribution from
   generation. The primary outcome here is close-to-close variance, as in Barclay, Litzenberger
   and Warner (1990).
3. **The 2020 reversal.** No study found uses the February–May 2020 suspension and reinstatement
   of every night session as a second intervention.
4. **Identification of overseas timing.** Cai et al. (2020) use US announcement surprises. The US
   daylight-saving shift gives a test that needs no outside data and has a built-in placebo (the
   day session).
5. **Closures.** No study found applies the French and Roll (1986) per-hour comparison to Chinese
   holiday closures of up to 18 days, or splits it by linkage.

**Limits of the search.** It covered English-language journals through web search and Crossref.
The Chinese-language literature (CNKI; search terms 夜盘, 夜盘交易, 夜间交易, 连续交易) was not
reachable from here and must be checked before `HYPOTHESES.md` is committed.
