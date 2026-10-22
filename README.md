# Doctoome – Type 2 Diabetes Awareness Questionnaire: Data Case Study

Analysis of the visitor journey on Doctoome's type 2 diabetes awareness page: data quality audit, cleaning, funnel, acquisition, questionnaire outcomes and weekly trends.

> **Disclaimer:** all data is synthetic. The questionnaire and its three outcome categories (`no_current_indication`, `possible_risk`, `declared_diagnosed`) are **fictional analytical categories**, not medical diagnoses or clinical recommendations.

---
## Presentation

- PDF: [presentation/Doctoome_case_presentation.pdf](presentation/Doctoome_case_presentation.pdf)
- Canva: https://canva.link/bijeyk203kulaom

## Key findings

| # | Finding | Recommendation |
|---|---|---|
| 1 | **35% of visitors leave the landing page without starting** the questionnaire (63% of all lost visitors). Overall, 43.7% of visitors reach a result (67.7% of those who start). | Rework the landing page (message, call to action, trust signals) and A/B test it. |
| 2 | **Q4 (physical activity) is the main drop-off inside the questionnaire**: 13.5% of visitors stop there vs ~5% at other questions, and **16.9% on mobile vs 8.0% on desktop**. Mobile is 65% of traffic. | Redesign Q4 for mobile (shorter labels, full-width buttons). Estimated gain: ~700 extra results over the period (+6%). |
| 3 | **Volume is not quality.** Paid sources bring traffic but complete below average (google_ads 39.0%, social 28.9%), while small sources complete best (email 64.7%, referral 60.4%, chatgpt 52.9%). | Judge channels on the profiles they bring, not on traffic. |
| 4 | **1 in 5 completers gets `possible_risk`**, and the share rises with age (9.9% for 18–29 → 36.2% for 75+). The `diabetes_45plus` campaign brings **14.8 at-risk profiles per 100 sessions**, vs **4.2** for `diabetes_social_awareness` (average 8.8). | Shift budget from `diabetes_social_awareness` to `diabetes_45plus`. |
| 5 | **Traffic grew +68% and at-risk yield +46% in 8 weeks**; the jump coincides with the launch of `diabetes_45plus` (week of 29 June). | Keep the reallocation; confirm causality with an A/B test. |

---

## Repository structure

```
doctoome-case/
├── data/                       # the 6 Parquet files provided (input, never modified)
├── sql/
│   └── 02_clean_tables.sql     # cleaning: builds the 4 clean tables in DuckDB
├── notebook/
│   └── analysis.ipynb          # main notebook: exploration → cleaning → analyses → charts
├── outputs/
│   └── figures/                # the 6 charts (PNG)
├── docs/
│   └── documentation.md        # detailed write-up of every step, finding and decision
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
source .venv/bin/activate      

# 2. Install the dependencies
pip install -r requirements.txt

# 3. Open the notebook
jupyter lab notebook/analysis.ipynb
```

Then run all cells (**Run All**). The notebook:
1. reads the Parquet files in `data/` directly with DuckDB (no database to install);
2. runs `sql/02_clean_tables.sql` to build the clean tables;
3. computes every analysis and saves the charts in `outputs/figures/`.

The notebook must be run **from the `notebook/` folder** (paths such as `../data/` are relative to it). The full run takes a few seconds.

---

## Method

The work follows four phases, each documented in the notebook and in `docs/documentation.md`.

| Phase | Steps | What it does |
|---|---|---|
| **1. Exploration & quality audit** | 1–14 | Volumes, schemas, profiling, distinct values, duplicates, answer validity, outcome consistency, referential integrity, time consistency. Nothing is modified. |
| **2. Cleaning** | 15–19 | `sql/02_clean_tables.sql` builds `visitors_clean`, `sessions_clean`, `answers_clean` and the central table `session_summary` (one row per session). Every transformation is checked with "before = after" counts. |
| **3. Analyses** | 20–28 | Funnel (overall and by device), acquisition (source, campaign), outcomes (by age, source, campaign, at-risk profiles per 100 sessions), weekly trends and campaign mix. |
| **4. Visualisations** | 29–35 | Six charts, one message each, each followed by its interpretation. |

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

**Checked with no issue:** unique IDs, referential integrity between tables, chronological order, `first_seen_at`, `is_returning_visitor`, answer validity against `allowed_answers`, consistency between outcomes, `questionnaire_complete` events and 5 answers.

---

## Assumptions that may affect the conclusions

- **Time zone:** all timestamps are processed in UTC, as stated in the brief.
- **Observation period:** the data actually covers **1 June – 2 August 2026**, not June–August. No conclusion is drawn about August.
- **`google` / `Google` sources** are classified as `google_organic` because none of them has a campaign while 100% of `google_ads` sessions do. This is a deduction, not a certainty.
- **Changed answers:** when a visitor answered the same question twice, the latest answer is considered final.
- **Funnel:** questions are assumed to be answered in order (3 answers = Q1, Q2 and Q3).
- **At-risk profiles per 100 sessions:** sessions without a result count as 0.
- **Age** is computed as 2026 − birth year. 42 visitors are under 18; they are kept but should be flagged for a health questionnaire.
- **Correlation ≠ causation:** the quality improvement after the `diabetes_45plus` launch is a correlation; other changes may have happened at the same time.
- **No cost data:** channel performance is measured on outcomes, not on cost per result.

---

## Charts

| File | Message |
|---|---|
| `01_funnel.png` | 35% leave before starting, then Q4 loses 3× more than other questions |
| `02_dropoff_by_device.png` | Q4 drop-off is a mobile problem: 2× higher than on desktop |
| `03_sources_volume_vs_completion.png` | Volume is not quality: paid sources bring traffic but complete below average |
| `04_risk_per_100_by_campaign.png` | `diabetes_45plus` brings 3.5× more at-risk profiles per visit than `social_awareness` |
| `05_risk_by_age.png` | The at-risk share rises steadily with age: from 10% to 36% |
| `06_weekly_trend.png` | Traffic +68% and at-risk yield +46% in 8 weeks, accelerating after the 45plus launch |

---

## Answers to the four questions

### 1. What are the most important findings?

1. **The landing page is the biggest leak: 35% of visitors leave without starting the questionnaire.** This represents 63% of all lost visitors. Overall, 43.7% of visitors reach a result (67.7% of those who start).
2. **Q4 (physical activity) is the main drop-off inside the questionnaire, and it is mostly a mobile problem.** 13.5% of visitors stop at Q4 vs ~5% at the other questions; on mobile it reaches 16.9% vs 8.0% on desktop. Mobile is 65% of traffic: fixing Q4 on mobile would add ~700 results over the period (+6%).
3. **Volume is not quality.** Paid sources bring the most traffic but complete below average (google_ads 39.0%, social 28.9%), while small sources complete best (email 64.7%, referral 60.4%, chatgpt 52.9%).
4. **The right metric is at-risk profiles per 100 sessions, and diabetes_45plus wins by far.** 1 in 5 completers gets `possible_risk`, and this share rises with age (9.9% → 36.2%). diabetes_45plus brings 14.8 at-risk profiles per 100 sessions vs 4.2 for diabetes_social_awareness (average 8.8).
5. **Performance improved over the period.** Traffic grew +68% and at-risk yield +46% in 8 weeks; the jump coincides with the launch of diabetes_45plus (week of 29 June) and the decline of social_awareness.
6. **The data is reliable after cleaning, with one major limit:** it only covers 1 June – 2 August 2026, not June–August.

### 2. Which questions remain unanswered?

- **Why do 35% of visitors leave the landing page?** We have no data on load time, scroll depth or time spent on the page.
- **Is the Q4 drop-off really a mobile display issue?** The device gap strongly suggests it, but only a UX review or an A/B test of a redesigned Q4 can confirm it.
- **Did diabetes_45plus cause the quality improvement?** It is a correlation in time; other changes (page, seasonality) may have happened at the same time.
- **What happens after the result?** We do not know whether `possible_risk` visitors book a consultation, which is the real business outcome for Doctoome.
- **Which channels are the most cost-efficient?** Without campaign costs, we cannot compute a cost per completion or per at-risk profile.
- **Why does the data stop on 2 August, with 1 August already abnormally low?** Extraction limit or tracking incident?
- **Are some attributions wrong?** 219 `direct` sessions carry a campaign, `other` is undefined, and 105 sessions answered all 5 questions without an outcome (abandonment or tracking bug).

### 3. What additional data would you collect?

| Data | Why |
|---|---|
| **Post-result actions**: click on "book a consultation", appointment booked, consultation held | Measure the real business conversion, especially for `possible_risk` profiles |
| **Campaign costs** (spend, impressions, clicks) | Compute cost per completion and cost per at-risk profile per channel |
| **Landing page behaviour**: load time, scroll depth, time on page, clicks on the start button, JS errors | Understand the 35% who leave before starting |
| **Questionnaire UX**: screen size, browser, "back" clicks, time spent per question | Confirm the mobile display hypothesis for Q4 |
| **Questionnaire / page version ID** | Run and analyse A/B tests properly |
| **Full UTM parameters** (source, medium, campaign, content, term) and referrer | Remove attribution ambiguities (`google`, `direct` with campaign, `other`, AI assistants) |
| **The complete August data** + tracking completeness logs | Analyse the full period and detect tracking incidents |
| **A short feedback question after the result** | Understand perceived usefulness and trust |
| **Age verification / consent** | Handle minors (42 visitors under 18) in a health questionnaire |

### 4. What would you track if the questionnaire stayed live for 12 months?

**North-star metric:** **at-risk (`possible_risk`) profiles per 100 sessions** — and, once tracked, **consultations booked per 100 sessions**.

| Area | KPIs |
|---|---|
| **Funnel** | Landing → start rate; completion rate (overall and among starters); drop-off rate per question; mobile vs desktop gap at Q4 |
| **Acquisition** | Sessions, completion rate and at-risk profiles per 100 sessions **by channel and campaign**; cost per completion and per at-risk profile (once costs are available); share of traffic from AI assistants |
| **Outcomes** | Distribution of the 3 categories; `possible_risk` share by age group; share of visitors aged 45+ |
| **Business** | Consultation booking rate among `possible_risk` profiles; booking → consultation held |
| **Data quality (alerts)** | Daily volume of events (alert on sudden drops, as on 1–2 August); % sessions with 5 answers but no outcome; % unmapped source values; % missing demographics; % duplicate answers |
| **Seasonality & tests** | Month-over-month trends (summer vs autumn, World Diabetes Day on 14 November); results of A/B tests on the landing page and Q4 |

**Cadence:** a weekly dashboard for the marketing and product teams, a monthly review of channel allocation, and automated alerts on data quality.
