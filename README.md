# Doctoome – Type 2 Diabetes Awareness Questionnaire: Data Case Study

Analysis of the journey on Doctoome's type 2 diabetes awareness page: data quality audit, cleaning, funnel, acquisition, questionnaire outcomes, weekly trends, and robustness checks against audience composition.

> **Disclaimer:** all data is synthetic. The questionnaire and its three outcome categories (`no_current_indication`, `possible_risk`, `declared_diagnosed`) are **fictional analytical categories**, not medical diagnoses or clinical recommendations. Patterns in the data (e.g. risk rising with age) describe the dataset; they do not validate the questionnaire.

> **How to read the figures:** unless stated otherwise, rates are **per session** (26,000 sessions from 20,000 unique visitors). Results are **associations**; explanations are flagged as **hypotheses**, and none of the analyses proves a causal effect.

---

## Presentation

- PDF: [presentation/Doctoome_case_presentation.pdf](presentation/Doctoome_case_presentation.pdf)
- Canva: https://canva.link/bijeyk203kulaom

---

## What changed in this version (after review)

| Review point | What was done | Where |
|---|---|---|
| Sessions vs unique visitors | All rates relabelled as session rates; funnel recomputed per unique visitor (33.5% never start, 47.3% reach a result; 2,276 possible_risk results = 2,190 people) | Step 36 |
| Mobile/Q4 explanation as a hypothesis | Q4 gap compared within age, source and new/returning groups, then adjusted for all three (Mantel-Haenszel, standardisation): the gap remains (17.1% vs 8.0%, OR 2.33). Cause kept as a hypothesis; ~700 results presented as a scenario with assumptions and sensitivity | Steps 37–38, chart 7 |
| Audience composition in the 45plus recommendation | Age-standardised comparison: 45plus 14.8 → 13.0 per 100 sessions; vs social_awareness 3.5× → 2.4×. Recommendation reframed as a controlled test judged on cost | Step 39, chart 8 |
| Email and returning users | Completion compared on new and returning sessions separately: email 64.7% → 56.8% on new sessions, ranking unchanged | Step 40, chart 9 |
| Clinical and business interpretations | Removed "the age pattern makes the data credible"; the north-star metric is presented as a proposed proxy | Steps 25, 34, answers |
| Weekly trend (correlation) | Rise split into campaign-mix vs within-campaign effects: 57% mix, 43% within campaigns | Step 41 |
| Path dependence / production thinking | Notebook runs from any folder; `src/run_pipeline.py` rebuilds the tables, runs 12 automated data quality checks, exports clean tables and weekly KPIs | `src/`, `sql/03_data_quality_checks.sql` |

---

## Key findings

| # | Finding (observed) | What it means / next step |
|---|---|---|
| 1 | **35.5% of sessions end on the landing page without starting** (63% of all lost sessions). 43.7% of sessions reach a result; per unique visitor, 33.5% never start and 47.3% reach a result. | First lever: A/B test the landing page (message, call to action, trust signals). |
| 2 | **Q4 (physical activity) is the main drop-off inside the questionnaire**: 13.5% of sessions reaching Q4 stop there vs ~5% elsewhere, **16.9% on mobile vs 8.0% on desktop**. The gap holds within every age group, source and new/returning segment. | The cause (display, context of use) is a **hypothesis**: UX review, then A/B test of a redesigned Q4. Scenario: up to ~700 extra results over the period if mobile matched desktop (upper bound). |
| 3 | **Volume is not quality.** Paid sources bring the most sessions but complete below average (google_ads 39.0%, social 28.9%); email (64.7%), referral (60.4%) and chatgpt (52.9%) complete best. Email's lead is partly due to returning sessions (56.8% on new sessions). | Compare channels on new and returning sessions separately, and on the results they bring. |
| 4 | **1 in 5 completions is `possible_risk`**, rising with age (9.9% → 36.2%). `diabetes_45plus` brings **14.8 possible_risk results per 100 sessions** vs 4.2 for `diabetes_social_awareness` (average 8.8); **13.0 vs 5.4 at equal age**. | Test a budget shift towards 45plus in a controlled way; judge it on cost per result, then per booked consultation. |
| 5 | **Sessions +68% and possible_risk results per 100 sessions +46% in 8 weeks.** 57% of the rise comes from the change in campaign mix (45plus launch), 43% from campaigns performing better. | Association, not proof: validate the reallocation with a controlled test. |

---

## Repository structure

```
doctoome-case/
├── data/                           # the 6 Parquet files provided (input, never modified)
├── sql/
│   ├── 02_clean_tables.sql         # cleaning: builds the 4 clean tables in DuckDB
│   └── 03_data_quality_checks.sql  # 12 automated checks (8 blocking errors, 4 warnings)
├── src/
│   └── run_pipeline.py             # command-line pipeline: build -> checks -> exports
├── notebook/
│   └── analysis.ipynb              # exploration -> cleaning -> analyses -> charts -> robustness checks
├── outputs/
│   ├── figures/                    # the 9 charts (PNG)
│   └── kpis_weekly.csv             # weekly KPIs produced by the pipeline
├── docs/
│   └── documentation.md            # detailed write-up of every step, finding and decision
├── presentation/
│   └── Doctoome_case_presentation.pdf   # 15-minute C-level presentation
├── requirements.txt
└── README.md
```

---

## How to reproduce

**Requirements:** Python 3.11+ (developed with Python 3.13).

```bash
# 1. Create and activate a virtual environment
python -m venv .venv
.venv\Scripts\activate          # Windows
source .venv/bin/activate       # macOS / Linux

# 2. Install the dependencies
pip install -r requirements.txt

# 3a. Run the pipeline (clean tables, data quality checks, exports)
python src/run_pipeline.py

# 3b. Or open the notebook for the full analysis and charts
jupyter lab notebook/analysis.ipynb
```

- **Notebook:** run all cells (**Run All**). It finds the project root by itself, so it works whether it is opened from the root or from `notebook/`. It builds the clean tables, computes every analysis and saves the charts in `outputs/figures/`.
- **Pipeline:** `src/run_pipeline.py` can be run from any folder. It stops with exit code 1 if a blocking data quality check fails, which makes it usable as a scheduled job (e.g. daily) or in CI.
- Both read the Parquet files directly with DuckDB (no database to install); a full run takes a few seconds.

---

## Method

| Phase | Steps | What it does |
|---|---|---|
| **1. Exploration & quality audit** | 1–14 | Volumes, schemas, profiling, distinct values, duplicates, answer validity, outcome consistency, referential integrity, time consistency. Nothing is modified. |
| **2. Cleaning** | 15–19 | `sql/02_clean_tables.sql` builds `visitors_clean`, `sessions_clean`, `answers_clean` and the central table `session_summary` (one row per session). Every transformation is checked with "before = after" counts. |
| **3. Analyses** | 20–28 | Funnel (overall and by device), acquisition (source, campaign), outcomes, possible_risk results per 100 sessions, weekly trends and campaign mix. |
| **4. Visualisations** | 29–35 | Six charts, one message each, each followed by its interpretation. |
| **5. Robustness checks** | 36–41 | Sessions vs unique visitors; Q4 gap within and across audience groups (stratification, standardisation, Mantel-Haenszel odds ratio); Q4 scenario with explicit assumptions; age-standardised campaign comparison; new vs returning sessions by source; mix vs rate decomposition of the weekly trend. |

**Stack:** Python, DuckDB (SQL directly on Parquet), pandas, matplotlib.
**Principle:** suspicious rows are never deleted; they get a **flag column** so they can be counted or excluded depending on the analysis.

---

## Data quality issues and decisions

| # | Issue | Rows affected | Decision |
|---|---|---|---|
| 1 | Data stops on **2 August 16:44 UTC** (1 August already abnormally low) instead of end of August | 626 sessions | Kept for global analyses; weekly trends use the 8 complete weeks only (1 June – 26 July) |
| 2 | `gender` coded several ways (`F`, `Female`, `M`, `Male`) | 993 visitors | Harmonised to `female` / `male` |
| 3 | `region` with inconsistent case, accents, hyphens | 868 visitors | Mapped to the official region name |
| 4 | `acquisition_source` variants | 1,670 sessions | `google`/`Google` → `google_organic`; `facebook`/`instagram` → `social`; `ChatGPT`/`AI Assistant` → `chatgpt` |
| 5 | Missing gender / region / birth year | 653 / 804 / 761 | Kept as `unknown` |
| 6 | Two answers to the same question (change of mind, ~10 s apart) | 697 cases | Latest answer kept, `flag_answer_changed` |
| 7 | 5 answers but no outcome | 105 sessions | Counted as not completed, `flag_5_answers_no_outcome` |
| 8 | `direct` sessions with a campaign | 219 sessions | Kept, `flag_direct_with_campaign` |

**Checked with no issue:** unique IDs, referential integrity between tables, chronological order, `first_seen_at`, `is_returning_visitor`, answer validity against `allowed_answers`, consistency between outcomes, `questionnaire_complete` events and 5 answers. These checks are now automated in `sql/03_data_quality_checks.sql`.

---

## Assumptions and limitations

- **Unit of analysis:** rates are per session. One visitor can have several sessions (3,000 visitors have 3); visitor-level rates are given in step 36.
- **Time zone:** all timestamps are processed in UTC, as stated in the brief.
- **Observation period:** the data actually covers **1 June – 2 August 2026**, not June–August. No conclusion is drawn about August.
- **`google` / `Google` sources** are classified as `google_organic` because none of them has a campaign while 100% of `google_ads` sessions do. This is a deduction, not a certainty.
- **Changed answers:** when a visitor answered the same question twice, the latest answer is considered final.
- **Funnel:** questions are assumed to be answered in order (3 answers = Q1, Q2 and Q3).
- **possible_risk results per 100 sessions:** sessions without a result count as 0. It is a **proposed proxy KPI**; its value as the primary business metric is an assumption until bookings are measured.
- **Age** is computed as 2026 − birth year. 42 visitors are under 18; they are kept but should be flagged for a health questionnaire.
- **Confounding:** adjustments cover the variables available (age, source, returning status, campaign mix). Unobserved differences (intent, browser, other risk factors, ad targeting) may remain.
- **Correlation ≠ causation:** neither the Q4/mobile gap nor the effect of 45plus is a measured causal effect; both call for a controlled test.
- **No cost data:** channel performance is measured on outcomes, not on cost per result.
- **Synthetic data:** patterns resembling known medical facts do not validate the data or the questionnaire.

---

## Charts

| File | Message |
|---|---|
| `01_funnel.png` | 35.5% of sessions end before starting, then Q4 loses 3× more than other questions |
| `02_dropoff_by_device.png` | Q4 drop-off is 2× higher on mobile than on desktop |
| `03_sources_volume_vs_completion.png` | Volume is not quality: paid sources bring sessions but complete below average |
| `04_risk_per_100_by_campaign.png` | `diabetes_45plus` brings the most possible_risk results per 100 sessions (crude) |
| `05_risk_by_age.png` | The possible_risk share rises steadily with age: from 10% to 36% |
| `06_weekly_trend.png` | Sessions +68% and possible_risk results per 100 sessions +46% in 8 weeks |
| `07_q4_gap_by_age.png` | The mobile gap at Q4 is present in every age group |
| `08_campaigns_age_adjusted.png` | 45plus still leads at equal age, but by less (14.8 → 13.0) |
| `09_completion_new_vs_returning.png` | Email completes well partly because 77% of its sessions are returning |

---

## Answers to the four questions

### 1. What are the most important findings?

1. **The landing page is the biggest leak: 35.5% of sessions end without starting the questionnaire** (33.5% of unique visitors never start). This represents 63% of all lost sessions. Overall, 43.7% of sessions reach a result (47.3% of unique visitors).
2. **Q4 (physical activity) is the main drop-off inside the questionnaire, and it is concentrated on mobile.** 13.5% of sessions reaching Q4 stop there vs ~5% at the other questions; on mobile 16.9% vs 8.0% on desktop. The gap holds within every age group, source and new/returning segment (step 37), so it is not explained by audience composition. Its cause (display, context of use) remains a hypothesis. Scenario: if mobile matched desktop at Q4, up to ~700 more results over the period (+6%, upper bound).
3. **Volume is not quality.** Paid sources bring the most sessions but complete below average (google_ads 39.0%, social 28.9%), while small sources complete best (email 64.7%, referral 60.4%, chatgpt 52.9%). Part of email's lead comes from returning sessions (77% of its sessions): on new sessions only it completes at 56.8%, still among the best (step 40).
4. **possible_risk results per 100 sessions is a useful proposed metric, and diabetes_45plus leads on it.** 1 in 5 completions is `possible_risk`, and this share rises with age (9.9% → 36.2%). diabetes_45plus brings 14.8 per 100 sessions vs 4.2 for diabetes_social_awareness (average 8.8). **At equal age** the lead shrinks (13.0 vs 5.4, from 3.5× to 2.4×) but remains (step 39). Without cost and booking data, this is not yet a return-on-investment result.
5. **Performance improved over the period.** Sessions grew +68% and possible_risk results per 100 sessions +46% in 8 weeks. About 60% of the rise comes from the change in campaign mix (launch of 45plus, decline of social_awareness); the rest comes from campaigns performing better, including sessions without a campaign (step 41). This is an association, not a measured causal effect.
6. **The data is reliable after cleaning, with one major limit:** it only covers 1 June – 2 August 2026, not June–August.

### 2. Which questions remain unanswered?

- **Why do 35% of sessions end on the landing page?** We have no data on load time, scroll depth or time spent on the page.
- **Why is the Q4 drop-off higher on mobile?** The gap is not explained by age, source or returning status (step 37), but display, screen size or context of use cannot be told apart with this data. A UX review and an A/B test of a redesigned Q4 are needed.
- **Did diabetes_45plus cause the quality improvement, and is it cost-effective?** It accounts for about 60% of the rise (step 41) and keeps a lead at equal age (step 39), but it may reach people with other risk factors, and we have no costs. A controlled test (split by region or period) is needed.
- **What happens after the result?** We do not know whether people with a `possible_risk` result book a consultation, which is the real business outcome for Doctoome.
- **Which channels are the most cost-efficient?** Without campaign costs, we cannot compute a cost per completion or per possible_risk result.
- **Why does the data stop on 2 August, with 1 August already abnormally low?** Extraction limit or tracking incident?
- **Are some attributions wrong?** 219 `direct` sessions carry a campaign, `other` is undefined, and 105 sessions answered all 5 questions without an outcome (abandonment or tracking bug).

### 3. What additional data would you collect?

| Data | Why |
|---|---|
| **Post-result actions**: click on "book a consultation", appointment booked, consultation held | Measure the real business conversion, especially after a `possible_risk` result |
| **Campaign costs** (spend, impressions, clicks) | Compute cost per completion and cost per possible_risk result per channel |
| **Landing page behaviour**: load time, scroll depth, time on page, clicks on the start button, JS errors | Understand the 35% of sessions that end before starting |
| **Questionnaire UX**: screen size, browser, "back" clicks, time spent per question | Test the mobile display hypothesis for Q4 |
| **Questionnaire / page version ID** | Run and analyse A/B tests properly |
| **Full UTM parameters** (source, medium, campaign, content, term) and referrer | Remove attribution ambiguities (`google`, `direct` with campaign, `other`, AI assistants) |
| **The complete August data** + tracking completeness logs | Analyse the full period and detect tracking incidents |
| **A short feedback question after the result** | Understand perceived usefulness and trust |
| **Age verification / consent** | Handle minors (42 visitors under 18) in a health questionnaire |

### 4. What would you track if the questionnaire stayed live for 12 months?

**Proposed north-star metric:** **`possible_risk` results per 100 sessions**, as a working proxy, to be replaced by **consultations booked per 100 sessions** once bookings are tracked. Treating it as the primary business metric is an assumption until its link with downstream value is measured.

| Area | KPIs |
|---|---|
| **Funnel** | Landing → start rate, per session and per unique visitor; completion rate (overall and among starters); drop-off rate per question; mobile vs desktop gap at Q4 |
| **Acquisition** | Sessions, completion rate and possible_risk results per 100 sessions **by channel and campaign, for new and returning sessions separately, and age-adjusted**; cost per completion and per possible_risk result (once costs are available); share of traffic from AI assistants |
| **Outcomes** | Distribution of the 3 categories; `possible_risk` share by age group; share of sessions aged 45+; possible_risk results per unique person |
| **Business** | Consultation booking rate after a `possible_risk` result; booking → consultation held |
| **Data quality (alerts)** | Daily volume of events (alert on sudden drops, as on 1–2 August); % sessions with 5 answers but no outcome; % unmapped source values; % missing demographics; % duplicate answers |
| **Seasonality & tests** | Month-over-month trends (summer vs autumn, World Diabetes Day on 14 November); results of A/B tests on the landing page and Q4 |

**Cadence:** the weekly KPIs are already produced by `src/run_pipeline.py` (`outputs/kpis_weekly.csv`); in production: a weekly dashboard for the marketing and product teams, a monthly review of channel allocation, and automated alerts on data quality.
