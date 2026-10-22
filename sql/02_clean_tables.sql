-- =====================================================
-- 02_clean_tables.sql
-- Builds the cleaned tables from the raw Parquet files.
-- All cleaning decisions are documented in docs/documentation.md
-- =====================================================

-- -----------------------------------------------------
-- 1. visitors_clean
--   - gender : F/Female -> female, M/Male -> male, NULL -> unknown
--   - region : official name (case, accents, hyphens), NULL -> unknown
--   - age and age group (reference year: 2026)
-- -----------------------------------------------------
CREATE OR REPLACE TABLE visitors_clean AS
SELECT
    visitor_id,
    birth_year,
    first_seen_at,

    -- Harmonised gender
    CASE
        WHEN gender IS NULL                       THEN 'unknown'
        WHEN lower(gender) IN ('f', 'female')     THEN 'female'
        WHEN lower(gender) IN ('m', 'male')       THEN 'male'
        ELSE lower(gender)                        -- other, prefer_not_to_say
    END AS gender,

    -- Harmonised region: compare a "simplified" version
    -- (lowercase, no accents, hyphens replaced by spaces)
    CASE strip_accents(lower(replace(region, '-', ' ')))
        WHEN 'auvergne rhone alpes'       THEN 'Auvergne-Rhône-Alpes'
        WHEN 'bretagne'                   THEN 'Bretagne'
        WHEN 'grand est'                  THEN 'Grand Est'
        WHEN 'hauts de france'            THEN 'Hauts-de-France'
        WHEN 'ile de france'              THEN 'Île-de-France'
        WHEN 'nouvelle aquitaine'         THEN 'Nouvelle-Aquitaine'
        WHEN 'occitanie'                  THEN 'Occitanie'
        WHEN 'pays de la loire'           THEN 'Pays de la Loire'
        WHEN 'provence alpes cote d''azur' THEN 'Provence-Alpes-Côte d''Azur'
        ELSE 'unknown'                    -- NULL or unrecognised value
    END AS region,

    -- Age and age group (reference year 2026)
    2026 - birth_year AS age,
    CASE
        WHEN birth_year IS NULL        THEN 'unknown'
        WHEN 2026 - birth_year < 18    THEN '<18'
        WHEN 2026 - birth_year < 30    THEN '18-29'
        WHEN 2026 - birth_year < 45    THEN '30-44'
        WHEN 2026 - birth_year < 60    THEN '45-59'
        WHEN 2026 - birth_year < 75    THEN '60-74'
        ELSE '75+'
    END AS age_group

FROM '../data/visitors.parquet';

-- -----------------------------------------------------
-- 2. sessions_clean
--   - harmonised acquisition_source
--   - campaign_name : NULL -> 'none'
--   - quality flags: direct with a campaign (ambiguous attribution),
--     incomplete period (1-2 August)
--   - date columns for time-based analyses
-- -----------------------------------------------------
CREATE OR REPLACE TABLE sessions_clean AS
SELECT
    session_id,
    visitor_id,
    session_started_at,
    CAST(session_started_at AS DATE)             AS session_date,
    date_trunc('week', session_started_at)::DATE AS session_week,   -- Monday of the week

    -- Harmonised source
    CASE
        WHEN lower(acquisition_source) = 'google'                     THEN 'google_organic'  -- no campaign -> organic
        WHEN lower(acquisition_source) IN ('facebook', 'instagram')   THEN 'social'
        WHEN lower(acquisition_source) IN ('chatgpt', 'ai assistant') THEN 'chatgpt'
        ELSE lower(acquisition_source)
    END AS acquisition_source,

    acquisition_source AS acquisition_source_raw,     -- original value kept for traceability
    COALESCE(campaign_name, 'none') AS campaign_name,
    device_type,
    landing_page,
    is_returning_visitor,

    -- Quality flags
    (acquisition_source = 'direct' AND campaign_name IS NOT NULL) AS flag_direct_with_campaign,
    (CAST(session_started_at AS DATE) > DATE '2026-07-31')        AS flag_incomplete_period

FROM '../data/sessions.parquet';

-- -----------------------------------------------------
-- 3. answers_clean
--   - a single answer per (session, question): the most recent one
--     (697 changed answers, ~10 s apart)
-- -----------------------------------------------------
CREATE OR REPLACE TABLE answers_clean AS
SELECT answer_id, session_id, visitor_id, question_id,
       question_number, answer_value, answered_at,
       nb_answers > 1 AS flag_answer_changed      -- the visitor changed their answer to this question
FROM (
    SELECT *,
           -- rank 1 = most recent answer for this session and question
           ROW_NUMBER() OVER (PARTITION BY session_id, question_number
                              ORDER BY answered_at DESC) AS answer_rank,
           -- total number of answers for this session and question
           COUNT(*)     OVER (PARTITION BY session_id, question_number) AS nb_answers
    FROM '../data/questionnaire_answers.parquet'
)
WHERE answer_rank = 1;

-- -----------------------------------------------------
-- 4. session_summary : one row per session
--   Combines source, visitor profile, progression and outcome.
--   Base table for every analysis.
-- -----------------------------------------------------
CREATE OR REPLACE TABLE session_summary AS
WITH events_per_session AS (
    -- what each session did, based on the events
    SELECT session_id,
           BOOL_OR(event_type = 'questionnaire_start')    AS has_started,
           MIN(event_timestamp) FILTER (WHERE event_type = 'questionnaire_start') AS started_at,
           MAX(question_number) FILTER (WHERE event_type = 'question_view')       AS last_question_viewed
    FROM '../data/questionnaire_events.parquet'
    GROUP BY session_id
),
answers_per_session AS (
    -- how many questions the session answered (after de-duplication)
    SELECT session_id,
           COUNT(*)                      AS nb_questions_answered,
           MAX(question_number)          AS last_question_answered,
           BOOL_OR(flag_answer_changed)  AS has_changed_answer
    FROM answers_clean
    GROUP BY session_id
)
SELECT
    -- session
    s.session_id, s.visitor_id, s.session_started_at, s.session_date, s.session_week,
    s.acquisition_source, s.campaign_name, s.device_type, s.is_returning_visitor,
    s.flag_direct_with_campaign, s.flag_incomplete_period,

    -- visitor
    v.gender, v.region, v.age, v.age_group,

    -- progression
    COALESCE(e.has_started, FALSE)            AS has_started,
    COALESCE(r.nb_questions_answered, 0)      AS nb_questions_answered,
    COALESCE(r.last_question_answered, 0)     AS last_question_answered,
    e.last_question_viewed,
    COALESCE(r.has_changed_answer, FALSE)     AS has_changed_answer,

    -- outcome
    (o.session_id IS NOT NULL)                AS is_completed,
    o.outcome_category,
    o.completed_at,
    date_diff('second', e.started_at, o.completed_at) AS completion_seconds,

    -- quality flag: 5 answers but no outcome
    (COALESCE(r.nb_questions_answered, 0) = 5 AND o.session_id IS NULL) AS flag_5_answers_no_outcome

FROM sessions_clean s
LEFT JOIN visitors_clean v         USING (visitor_id)
LEFT JOIN events_per_session e     USING (session_id)
LEFT JOIN answers_per_session r    USING (session_id)
LEFT JOIN '../data/questionnaire_outcomes.parquet' o USING (session_id);
