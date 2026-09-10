"""Runner for the trading-hours study. All computation is SQL executed by DuckDB.

    python pipeline.py verify-raw           # SHA-256 of data/raw/*.csv against MANIFEST.sha256
    python pipeline.py build [--from 30_core] [--only 50_night] [--compat]
    python pipeline.py test                 # every tests/sql/*.sql must return zero rows
    python pipeline.py export               # mart.* -> marts/*.parquet
    python pipeline.py all                  # verify-raw, build, test, export
"""
import argparse
import hashlib
import logging
import os
import re
import sys
import time
from pathlib import Path

import duckdb
import yaml

ROOT = Path(__file__).resolve().parent
RAW = Path("data/raw")
WAREHOUSE = Path("data/warehouse.duckdb")
TMP = Path("data/tmp")
MARTS = Path("marts")
LOG = Path("logs/build.log")
CREATED = re.compile(
    r"CREATE\s+(?:OR\s+REPLACE\s+)?(?:TEMP(?:ORARY)?\s+)?(?:TABLE|VIEW)\s+"
    r"(?:IF\s+NOT\s+EXISTS\s+)?([\w.]+)",
    re.IGNORECASE,
)
log = logging.getLogger("pipeline")


class BuildError(Exception):
    pass


def verify_raw():
    expected = {}
    for line in (RAW / "MANIFEST.sha256").read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            digest, name = line.split(maxsplit=1)
            expected[name.lstrip("*")] = digest.lower()
    present = {p.name for p in RAW.glob("*.csv")}
    problems = [f"missing: {n}" for n in sorted(expected.keys() - present)]
    problems += [f"not in manifest: {n}" for n in sorted(present - expected.keys())]
    for name in sorted(expected.keys() & present):
        h = hashlib.sha256()
        with open(RAW / name, "rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""):
                h.update(chunk)
        if h.hexdigest() != expected[name]:
            problems.append(f"hash mismatch: {name}")
    for p in problems:
        log.error("verify-raw: %s", p)
    if problems:
        raise BuildError(f"verify-raw failed: {len(problems)} problem(s)")
    log.info("verify-raw: all %d files match the manifest", len(expected))


def sql_literal(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return repr(value)
    if isinstance(value, float):
        return f"{value!r}::DOUBLE"  # a bare 10.0 would be a DECIMAL literal
    if isinstance(value, str):
        return "'" + value.replace("'", "''") + "'"
    if isinstance(value, list):
        return "[" + ", ".join(sql_literal(v) for v in value) + "]"
    raise TypeError(f"unsupported config value: {value!r}")


def config_variables(cfg):
    """Flatten config.yaml (minus the duckdb section) to {leaf_name: value}."""
    out = {}
    for key, value in cfg.items():
        items = value.items() if isinstance(value, dict) else [(key, value)]
        for name, v in items:
            if name in out:
                raise BuildError(f"config.yaml: variable name '{name}' is not unique")
            out[name] = v
    return out


def connect(compat=False):
    cfg = yaml.safe_load(Path("config.yaml").read_text(encoding="utf-8"))
    settings = cfg.pop("duckdb")
    TMP.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(str(WAREHOUSE))
    con.execute(f"SET memory_limit = {sql_literal(settings['memory_limit'])}")
    con.execute(f"SET threads = {int(settings['threads'])}")
    con.execute(f"SET temp_directory = {sql_literal(TMP.as_posix())}")
    for name, value in config_variables(cfg).items():
        con.execute(f"SET VARIABLE {name} = {sql_literal(value)}")
    con.execute(f"SET VARIABLE compat_mode = {sql_literal(compat)}")
    return con


def sql_files(start=None, only=None):
    files = sorted(Path("sql").glob("*/*.sql"))
    if start:
        files = [p for p in files if p.parent.name >= start]
    if only:
        files = [p for p in files if p.parent.name.startswith(only)]
    return files


def run_file(con, path):
    t0 = time.perf_counter()
    text = path.read_text(encoding="utf-8")
    try:
        statements = con.extract_statements(text)
    except duckdb.Error as e:
        raise BuildError(f"{path.as_posix()}: cannot parse\n{e}") from e
    for stmt in statements:
        try:
            con.execute(stmt)
        except duckdb.Error as e:
            raise BuildError(f"{path.as_posix()}: statement failed\n{stmt.query.strip()}\n{e}") from e
    counts = [
        f"{name}={con.execute(f'SELECT count(*) FROM {name}').fetchone()[0]:,}"
        for name in dict.fromkeys(CREATED.findall(text))
    ]
    log.info("%-45s %7.2fs  %s", path.as_posix(), time.perf_counter() - t0, " ".join(counts))


def build(con, start=None, only=None):
    files = sql_files(start, only)
    log.info("build: %d SQL file(s)", len(files))
    for path in files:
        run_file(con, path)


def run_tests(con):
    tests = sorted(Path("tests/sql").glob("*.sql"))
    failed = 0
    for path in tests:
        con.execute(path.read_text(encoding="utf-8"))
        columns = [d[0] for d in con.description]
        rows = con.fetchall()
        if rows:
            failed += 1
            log.error("FAIL %s: %d row(s)\n  %s\n%s", path.as_posix(), len(rows), columns,
                      "\n".join(f"  {r}" for r in rows[:10]))
        else:
            log.info("pass %s", path.as_posix())
    log.info("test: %d passed, %d failed", len(tests) - failed, failed)
    if failed:
        raise BuildError(f"{failed} test(s) failed")


def export(con):
    MARTS.mkdir(exist_ok=True)
    names = [r[0] for r in con.execute(
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema = 'mart' ORDER BY table_name").fetchall()]
    for name in names:
        out = (MARTS / f"{name}.parquet").as_posix()
        con.execute(f"COPY (SELECT * FROM mart.{name}) TO '{out}' (FORMAT parquet, COMPRESSION zstd)")
        log.info("export: mart.%s -> %s", name, out)
    log.info("export: %d mart table(s)", len(names))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("verify-raw")
    b = sub.add_parser("build")
    b.add_argument("--from", dest="start", help="first sql/ directory to run, e.g. 30_core")
    b.add_argument("--only", help="run only this sql/ directory, e.g. 50_night")
    b.add_argument("--compat", action="store_true", help="companion's fixed session templates")
    sub.add_parser("test")
    sub.add_parser("export")
    a = sub.add_parser("all")
    a.add_argument("--compat", action="store_true")
    args = parser.parse_args()

    os.chdir(ROOT)
    LOG.parent.mkdir(exist_ok=True)
    sys.stdout.reconfigure(encoding="utf-8")
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s",
                        handlers=[logging.StreamHandler(sys.stdout),
                                  logging.FileHandler(LOG, encoding="utf-8")])
    t0 = time.perf_counter()
    try:
        if args.command in ("verify-raw", "all"):
            verify_raw()
        if args.command != "verify-raw":
            with connect(getattr(args, "compat", False)) as con:
                if args.command in ("build", "all"):
                    build(con, getattr(args, "start", None), getattr(args, "only", None))
                if args.command in ("test", "all"):
                    run_tests(con)
                if args.command in ("export", "all"):
                    export(con)
    except BuildError as e:
        log.error("%s", e)
        sys.exit(1)
    log.info("%s finished in %.1fs", args.command, time.perf_counter() - t0)


if __name__ == "__main__":
    main()
