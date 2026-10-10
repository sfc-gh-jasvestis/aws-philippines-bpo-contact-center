# Philippines BPO Contact Center

**Philippines - BPO Contact Center**
Use case: Service levels, staffing risk, intraday reforecasts and abandoned contacts

> Workforce monitoring for 48 fictional inbound queues of a fictional Philippine BPO contact centre, served from Makati City, Taguig, Pasig City, Mandaue City, Cagayan de Oro and Baguio: dynamic tables, a holdout-evaluated service-level miss classifier, a service-level alert forecast and abandonment rate anomaly detection, a Cortex Agent with SOP citations, a live interaction feed with an alert, and an SPCS app.

## Why Snowflake

- **Dynamic tables** reconcile half-hour intervals, service-level alerts, missed intervals, overtime call-outs and reforecast compliance from RAW queue data, with checks in `run_core.py`
- **Service-level miss classification** gives a holdout-evaluated next-7-day probability per queue
- **Service-level alert forecast** projects 14 days of contact-centre-wide alerts with prediction intervals, for real-time cover
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, plus Search over SOPs) shows its SQL and SOP citations
- **Live interactions**: a native simulator (Snowflake only) or Firehose, S3 and Snowpipe (AWS build), then an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.QUEUES` (48 rows) |
| Fact table | `RAW.QUEUE_DAILY` (4,320 queue-days, 90 days, 32 half-hour intervals per day) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `MISS_DRIVER_SUMMARY`, `TREND_ANALYSIS` |
| ML | `ML.SL_MISS_SCORES`, `ML.SL_MISS_HOLDOUT_METRICS`, `ML.SL_ALERT_FORECAST`, `ML.ABANDON_ANOMALIES` |

Currency: PHP. Site cities: Makati City, Taguig, Pasig City, Mandaue City, Cagayan de Oro, Baguio.
Lines of business: Customer care voice, Technical support voice, Billing support chat, Sales and retention voice, Social messaging care.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| Service Level Attainment | 99.59% |
| Service-Level Alerts | 2,240 |
| Intervals Below Service Level | 565 |
| Alert Miss Rate | 25.2% |
| Overtime Call-outs | 265 |
| Agent Labor Cost (PHP M) | 407 |
| Contacts Offered | 4,092,412 |
| Reforecast Compliance | 77.0% |
| Queues Monitored | 48 |
| Agent Skill Coverage | 74.9% |
| Agents In Nesting | 38 |

Values are synthetic. A rebuild reproduces them because the data is HASH-seeded; dates are relative to the build day.

## Demo flow

1. Executive Cockpit: KPIs, daily service-level alerts against missed intervals, alerts and missed intervals by miss driver, queue table
2. Predictive: holdout metrics, risk bands, 14-day service-level alert forecast, abandonment rate anomalies
3. Controls: reforecast compliance, agent skill coverage and agents in nesting, reforecast compliance against missed intervals, then generate the action memo
4. Live Interactions: run `CALL APP.SIMULATE_INTERACTIONS(20)` (Snowflake only) or `python aws/publish_interactions.py --count 20` (AWS build). Then run `EXECUTE ALERT APP.LIVE_INTERACTION_ALERT` and show the alert log and email
5. Ask AI: the Cortex Agent answers metric questions through the semantic view and cites SOPs from Cortex Search. The SQL is shown.
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- 99.59% of half-hour intervals meet service level; the 2,240 service-level alerts are where the real-time team spends its time, and about 1 in 4 of them (25.2%) still end below service level.
- Schedule gap alerts produce the most missed intervals (101 of 302). Site power interruptions hit every queue at a site at once, but traffic is rerouted, so they never end below service level.
- Baguio queues carry the most missed intervals (147); Taguig queues the fewest (63).
- The risk model is evaluated on a time-based holdout: precision 0.67 and recall 0.70 at 0.5, against a 0.58 base rate. Present it as triage, not a verdict.
- Site power interruptions are excluded from model training, because they are not queue-driven.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
