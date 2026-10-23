"""

Runs the same cleaning as the notebook, then automated data quality checks,
then exports the clean tables and the weekly KPIs. It can be run from any folder:

    python src/run_pipeline.py

Steps
    1. build the clean tables          (sql/02_clean_tables.sql)
    2. run the data quality checks     (sql/03_data_quality_checks.sql)
       -> stops with exit code 1 if an 'error' check fails
    3. export the clean tables         (outputs/clean/*.parquet)
    4. export the weekly KPIs          (outputs/kpis_weekly.csv)

The notebook (notebook/analysis.ipynb) remains the place for exploration and charts;
this script is the reproducible, schedulable part (e.g. a daily job).
"""
import sys
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]          # project root, whatever the current folder
CLEAN_TABLES = ["visitors_clean", "sessions_clean", "answers_clean", "session_summary"]


def run_sql_file(con, relative_path):
    """Run a SQL file whose paths ('data/...') are relative to the project root."""
    return con.execute((ROOT / relative_path).read_text(encoding="utf-8"))


def main():
    import os
    os.chdir(ROOT)                                   # the SQL files use paths relative to the root
    con = duckdb.connect()
    con.execute("SET TimeZone = 'UTC'")

    # 1. Clean tables
    run_sql_file(con, "sql/02_clean_tables.sql")
    for t in CLEAN_TABLES:
        print(f"[build] {t}: {con.execute(f'SELECT COUNT(*) FROM {t}').fetchone()[0]:,} rows")

    # 2. Data quality checks
    checks = run_sql_file(con, "sql/03_data_quality_checks.sql").df()
    print("\n[checks]")
    for _, c in checks.iterrows():
        status = "OK  " if c.failing_rows == 0 else ("FAIL" if c.severity == "error" else "WARN")
        print(f"  {status} {c.check_name}: {int(c.failing_rows)}")
    errors = checks[(checks.severity == "error") & (checks.failing_rows > 0)]
    if len(errors):
        print(f"\n{len(errors)} blocking check(s) failed: outputs not exported.")
        sys.exit(1)

    # 3. Export the clean tables
    out = ROOT / "outputs" / "clean"
    out.mkdir(parents=True, exist_ok=True)
    for t in CLEAN_TABLES:
        con.execute(f"COPY {t} TO '{(out / t).as_posix()}.parquet' (FORMAT parquet)")
    print(f"\n[export] clean tables -> {out.relative_to(ROOT)}/")

    # 4. Weekly KPIs (complete weeks only), the metrics proposed for monitoring
    kpis = con.execute("""
        SELECT session_week,
               COUNT(*)                                                            AS sessions,
               COUNT(DISTINCT visitor_id)                                          AS unique_visitors,
               ROUND(100 * AVG(has_started::INT), 1)                               AS start_rate_pct,
               ROUND(100 * AVG(is_completed::INT), 1)                              AS completion_rate_pct,
               ROUND(100 * AVG(COALESCE(outcome_category = 'possible_risk', FALSE)::INT), 1)
                                                                                   AS possible_risk_per_100_sessions,
               ROUND(100 * AVG(CASE WHEN nb_questions_answered >= 3 AND device_type = 'mobile'
                                    THEN (nb_questions_answered = 3 AND NOT is_completed)::INT END), 1)
                                                                                   AS q4_dropoff_mobile_pct,
               ROUND(100 * AVG(CASE WHEN nb_questions_answered >= 3 AND device_type = 'desktop'
                                    THEN (nb_questions_answered = 3 AND NOT is_completed)::INT END), 1)
                                                                                   AS q4_dropoff_desktop_pct
        FROM session_summary
        WHERE session_week < DATE '2026-07-27'      -- the last week is incomplete (data stops on 2 August)
        GROUP BY session_week
        ORDER BY session_week
    """).df()
    kpis.to_csv(ROOT / "outputs" / "kpis_weekly.csv", index=False)
    print("[export] weekly KPIs -> outputs/kpis_weekly.csv\n")
    print(kpis.to_string(index=False))


if __name__ == "__main__":
    main()
