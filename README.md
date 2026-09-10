# Trading Hours in Chinese Commodity Futures

A DuckDB + Power BI study of when volatility, volume and price discovery happen in Chinese
commodity futures, what changes when trading hours are extended, and what accumulates while the
market is shut.

**Status:** Phase 3 done: the SQL cleaning pipeline reproduces the reference pipeline exactly in
compatibility mode. The plan is in [`PROJECT_PLAN.md`](PROJECT_PLAN.md);
decisions are logged in [`docs/DECISIONS.md`](docs/DECISIONS.md). This README becomes the research
brief in Phase 11.

## Data

Five-minute bars for 34 contracts on SHFE, INE, DCE and CZCE, from Wind. The data is licensed and
is **not** in this repository; only its checksums are (`data/raw/MANIFEST.sha256`). See `LICENSE`.

## Running

```
conda env create -f environment.yml
# place the 34 raw CSVs in data/raw/
python pipeline.py verify-raw
python pipeline.py all
```
