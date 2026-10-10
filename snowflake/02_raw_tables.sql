-- Synthetic queue-day observations for a fictional Philippine BPO contact centre.
-- A queue is one inbound line of business served from one site city. Each
-- queue-day has 32 half-hour intervals with a service-level target. Nothing is
-- seeded as a prediction. Randomness is HASH-seeded, so every rebuild is
-- reproducible: per-queue service-level miss propensity, staffing forecast drift
-- between intraday reforecasts, missed reforecasts, line-of-business miss
-- drivers, intervals recovered by intraday action, and two site power
-- interruptions handled by rerouting.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.QUEUES AS
WITH queues AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS QUEUE_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 48))
), draws AS (
  SELECT QUEUE_INDEX,
         MOD(ABS(HASH(QUEUE_INDEX, 'phcc-queue-age')), 1000000) / 1e6 AS U_AGE,
         MOD(ABS(HASH(QUEUE_INDEX, 'phcc-miss-rate')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(QUEUE_INDEX, 'phcc-reforecast-cycle')), 1000000) / 1e6 AS U_REFORECAST,
         MOD(ABS(HASH(QUEUE_INDEX, 'phcc-wfm-discipline')), 1000000) / 1e6 AS U_DISCIPLINE,
         MOD(ABS(HASH(QUEUE_INDEX, 'phcc-tier')), 1000000) / 1e6 AS U_TIER
  FROM queues
)
SELECT 'Q-' || LPAD(QUEUE_INDEX::VARCHAR, 4, '0') AS ID,
       'Synthetic queue ' || LPAD(QUEUE_INDEX::VARCHAR, 4, '0') AS NAME,
       -- Deterministic spread (6 and 5 are coprime): every city and line of business is present.
       CASE MOD(QUEUE_INDEX, 6) WHEN 0 THEN 'Makati City' WHEN 1 THEN 'Taguig'
            WHEN 2 THEN 'Pasig City' WHEN 3 THEN 'Mandaue City'
            WHEN 4 THEN 'Cagayan de Oro' ELSE 'Baguio' END AS REGION,
       CASE MOD(QUEUE_INDEX, 5) WHEN 0 THEN 'Customer care voice'
            WHEN 1 THEN 'Technical support voice' WHEN 2 THEN 'Billing support chat'
            WHEN 3 THEN 'Sales and retention voice' ELSE 'Social messaging care' END AS CATEGORY,
       QUEUE_INDEX,
       1 + FLOOR(U_TIER * 3) AS RISK_TIER,
       ROUND(0.2 + U_AGE * 5.8, 1) AS QUEUE_AGE_YEARS,
       -- Base probability that a half-hour interval is at risk 0.05%-0.17%;
       -- ~20% of queues are understaffed (x1.8).
       (0.0005 + U_RATE * 0.0012) * IFF(U_RATE > 0.8, 1.8, 1) AS BASE_MISS_RATE,
       4 * (1 + FLOOR(U_REFORECAST * 3)) AS REFORECAST_INTERVAL_DAYS,
       0.5 + U_DISCIPLINE * 0.5 AS REFORECAST_COMPLETION_PROB,
       'Active' AS STATUS
FROM draws;

CREATE TABLE RAW.QUEUE_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), city_events AS (
  -- Two site power interruptions; every queue at the site raises service-level
  -- alerts, and traffic is rerouted to another site so no interval is missed.
  SELECT * FROM VALUES (27, 'Mandaue City'), (58, 'Baguio') AS o(DAY_INDEX, REGION)
), base AS (
  SELECT q.ID AS ENTITY_ID, q.QUEUE_INDEX, q.CATEGORY, q.REGION, q.QUEUE_AGE_YEARS,
         q.BASE_MISS_RATE, q.REFORECAST_INTERVAL_DAYS, q.REFORECAST_COMPLETION_PROB,
         d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         MOD(d.DAY_INDEX + q.QUEUE_INDEX * 5, q.REFORECAST_INTERVAL_DAYS) AS DAYS_SINCE_REFORECAST,
         MOD(ABS(HASH(q.ID, d.DAY_INDEX, 'phcc-at-risk')), 1000000) / 1e6 AS U_MISS,
         MOD(ABS(HASH(q.ID, d.DAY_INDEX, 'phcc-recover')), 1000000) / 1e6 AS U_DETECT,
         MOD(ABS(HASH(q.ID, d.DAY_INDEX, 'phcc-false-alert')), 1000000) / 1e6 AS U_RESOLVE,
         MOD(ABS(HASH(q.ID, d.DAY_INDEX, 'phcc-driver')), 1000000) / 1e6 AS U_TYPE,
         MOD(ABS(HASH(q.ID, d.DAY_INDEX, 'phcc-reforecast-done')), 1000000) / 1e6 AS U_DONE,
         MOD(ABS(HASH(q.ID, d.DAY_INDEX, 'phcc-offered')), 1000000) / 1e6 AS U_VOLUME,
         MOD(ABS(HASH(q.ID, d.DAY_INDEX, 'phcc-jitter')), 1000000) / 1e6 AS U_NOISE,
         MOD(ABS(HASH(q.ID, d.DAY_INDEX, 'phcc-overtime')), 1000000) / 1e6 AS U_LATE,
         e.REGION IS NOT NULL AS CITY_EVENT
  FROM RAW.QUEUES q CROSS JOIN days d
  LEFT JOIN city_events e ON e.DAY_INDEX = d.DAY_INDEX AND e.REGION = q.REGION
), wfm AS (
  SELECT *,
         IFF(DAYS_SINCE_REFORECAST = 0, 1, 0) AS REFORECAST_DUE,
         IFF(DAYS_SINCE_REFORECAST = 0 AND U_DONE < REFORECAST_COMPLETION_PROB, 1, 0) AS REFORECAST_DONE,
         -- Staffing forecast drift grows between intraday reforecasts; weak
         -- workforce management discipline carries it over.
         DAYS_SINCE_REFORECAST / REFORECAST_INTERVAL_DAYS + (1 - REFORECAST_COMPLETION_PROB) AS DRIFT
  FROM base
), risk AS (
  SELECT *,
         -- Intervals at risk of missing service level (stochastic rounding of the expected count).
         FLOOR(32 * LEAST(0.25, BASE_MISS_RATE * (0.4 + 1.8 * DRIFT) * (1 + 1 / (1 + QUEUE_AGE_YEARS))) * 4
               + U_MISS) AS MISS_RISK_COUNT
  FROM wfm
), outcomes AS (
  SELECT *,
         -- Intraday action (overflow, skill moves) recovers part of the at-risk intervals.
         IFF(CITY_EVENT, 0, LEAST(MISS_RISK_COUNT, FLOOR(MISS_RISK_COUNT * 0.35 + U_DETECT))) AS SL_MISS_COUNT,
         IFF(CITY_EVENT, 3, MISS_RISK_COUNT + IFF(U_RESOLVE < CASE CATEGORY
               WHEN 'Customer care voice' THEN 0.17 WHEN 'Billing support chat' THEN 0.12
               WHEN 'Technical support voice' THEN 0.14 ELSE 0.08 END, 1, 0)) AS SL_ALERT_COUNT
  FROM risk
), measured AS (
  SELECT *,
         ROUND(CASE CATEGORY WHEN 'Customer care voice' THEN 1450 WHEN 'Technical support voice' THEN 820
                             WHEN 'Billing support chat' THEN 960 WHEN 'Sales and retention voice' THEN 600
                             ELSE 700 END
               * (0.7 + 0.6 * U_VOLUME) * (1 + 0.08 * MISS_RISK_COUNT)) AS CONTACT_COUNT,
         ROUND(CASE CATEGORY WHEN 'Customer care voice' THEN 6.2 WHEN 'Technical support voice' THEN 9.8
                             WHEN 'Billing support chat' THEN 7.5 WHEN 'Sales and retention voice' THEN 8.4
                             ELSE 5.1 END
               + 1.9 * DRIFT + 0.7 * MISS_RISK_COUNT + U_NOISE * 1.3, 1) AS AVG_HANDLE_MIN
  FROM outcomes
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE,
       32 AS INTERVAL_COUNT,
       CONTACT_COUNT,
       -- Loaded agent cost per handled minute, PHP 9-12.
       ROUND(CONTACT_COUNT * AVG_HANDLE_MIN * (9 + 3 * U_NOISE), 0) AS LABOR_COST_PHP,
       SL_ALERT_COUNT, SL_MISS_COUNT,
       IFF(SL_MISS_COUNT > 0 AND U_LATE < 0.45, 1, 0) AS OVERTIME_CALLOUT,
       CASE WHEN SL_ALERT_COUNT = 0 THEN 'None'
            WHEN CITY_EVENT THEN 'Site power interruption'
            WHEN CATEGORY = 'Customer care voice' THEN IFF(U_TYPE < 0.45, 'Inbound volume spike', IFF(U_TYPE < 0.8, 'Unplanned absenteeism', 'Schedule gap'))
            WHEN CATEGORY = 'Technical support voice' THEN IFF(U_TYPE < 0.5, 'Long handle times', IFF(U_TYPE < 0.8, 'System latency', 'Unplanned absenteeism'))
            WHEN CATEGORY = 'Billing support chat' THEN IFF(U_TYPE < 0.55, 'Chat concurrency cap', 'Billing cycle surge')
            WHEN CATEGORY = 'Sales and retention voice' THEN IFF(U_TYPE < 0.5, 'Campaign volume spike', 'Schedule gap')
            ELSE IFF(U_TYPE < 0.5, 'Backlog carryover', IFF(U_TYPE < 0.75, 'Unplanned absenteeism', 'Inbound volume spike')) END AS MISS_DRIVER,
       REFORECAST_DUE, REFORECAST_DONE,
       ROUND(LEAST(30, 2.4 + 2.1 * DRIFT + 1.3 * SL_MISS_COUNT + U_NOISE * 1.5), 2) AS ABANDON_RATE_PCT,
       AVG_HANDLE_MIN,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM measured;

-- Agent skill coverage per queue (snapshot): agents the queue needs skilled in
-- its line of business, agents skilled, and agents still in nesting (supervised
-- floor support after training).
CREATE TABLE RAW.AGENT_SKILLS AS
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Customer care voice' THEN 'Customer care voice skill'
                     WHEN 'Technical support voice' THEN 'Tier 1 technical support skill'
                     WHEN 'Billing support chat' THEN 'Billing chat skill'
                     WHEN 'Sales and retention voice' THEN 'Retention offers skill'
                     ELSE 'Social messaging skill' END AS DOC_TYPE,
       6 + MOD(ABS(HASH(ID, 'phcc-skill-req')), 10) AS REQUIRED_QTY,
       3 + MOD(ABS(HASH(ID, 'phcc-skill-held')), 12) AS ON_FILE_QTY,
       IFF(3 + MOD(ABS(HASH(ID, 'phcc-skill-held')), 12) < 6 + MOD(ABS(HASH(ID, 'phcc-skill-req')), 10),
           MOD(ABS(HASH(ID, 'phcc-nesting')), 4), 0) AS PENDING_QTY,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM RAW.QUEUES;
