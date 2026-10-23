-- =====================================================
-- 03_data_quality_checks.sql
-- Automated checks run after 02_clean_tables.sql.
-- Each query returns ONE row: check name, severity, number of failing rows.
--   severity = 'error'   -> the pipeline stops (the clean tables cannot be trusted)
--   severity = 'warning' -> the pipeline continues but reports it (to investigate)
-- =====================================================

-- 1. No session lost or duplicated by the joins
SELECT 'session_summary has one row per raw session' AS check_name, 'error' AS severity,
       ABS((SELECT COUNT(*) FROM session_summary) - (SELECT COUNT(*) FROM 'data/sessions.parquet')) AS failing_rows
UNION ALL
SELECT 'session_id is unique in session_summary', 'error',
       COUNT(*) - COUNT(DISTINCT session_id) FROM session_summary
UNION ALL
-- 2. One answer per session and question after de-duplication
SELECT 'one answer per (session, question) in answers_clean', 'error',
       COUNT(*) - COUNT(DISTINCT (session_id, question_number)) FROM answers_clean
UNION ALL
-- 3. Referential integrity
SELECT 'every session has a known visitor', 'error',
       COUNT(*) FROM session_summary s
       WHERE NOT EXISTS (SELECT 1 FROM visitors_clean v WHERE v.visitor_id = s.visitor_id)
UNION ALL
-- 4. Business rules
SELECT 'completed <=> outcome present', 'error',
       COUNT(*) FROM session_summary WHERE is_completed <> (outcome_category IS NOT NULL)
UNION ALL
SELECT 'nb_questions_answered between 0 and 5', 'error',
       COUNT(*) FROM session_summary WHERE nb_questions_answered NOT BETWEEN 0 AND 5
UNION ALL
SELECT 'outcome_category in the 3 allowed values', 'error',
       COUNT(*) FROM session_summary
       WHERE outcome_category NOT IN ('no_current_indication', 'possible_risk', 'declared_diagnosed')
UNION ALL
SELECT 'acquisition_source harmonised', 'error',
       COUNT(*) FROM session_summary
       WHERE acquisition_source NOT IN ('google_organic', 'google_ads', 'social', 'email',
                                        'referral', 'chatgpt', 'direct', 'other')
UNION ALL
-- 5. Known anomalies to monitor (warnings)
SELECT 'sessions with 5 answers but no outcome', 'warning',
       COUNT(*) FROM session_summary WHERE flag_5_answers_no_outcome
UNION ALL
SELECT 'direct sessions carrying a campaign', 'warning',
       COUNT(*) FROM session_summary WHERE flag_direct_with_campaign
UNION ALL
SELECT 'visitors aged under 18', 'warning',
       COUNT(*) FROM visitors_clean WHERE age_group = '<18'
UNION ALL
-- 6. Tracking completeness: days with less than half the median daily volume of the previous 7 days
SELECT 'days with abnormally low volume (< 50% of trailing 7-day median)', 'warning',
       COUNT(*) FROM (
           SELECT session_date, nb,
                  MEDIAN(nb) OVER (ORDER BY session_date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) AS trailing_median
           FROM (SELECT session_date, COUNT(*) AS nb FROM session_summary GROUP BY session_date)
       ) WHERE nb < 0.5 * trailing_median;
