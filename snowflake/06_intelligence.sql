-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live-interaction alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes checked __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_INTERACTIONS.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic workforce management knowledge base (clearly synthetic SOPs) ----------
CREATE OR REPLACE TABLE SEARCH.WFM_DOCS AS
WITH types AS (
  SELECT DISTINCT r.MISS_DRIVER, q.CATEGORY
  FROM RAW.QUEUE_DAILY r JOIN RAW.QUEUES q ON q.ID = r.ENTITY_ID
  WHERE r.SL_MISS_COUNT > 0
)
SELECT
  'SOP-' || LPAD(ROW_NUMBER() OVER (ORDER BY CATEGORY, MISS_DRIVER)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  CATEGORY,
  MISS_DRIVER,
  CATEGORY || ' - ' || MISS_DRIVER || ' service-level recovery' AS TITLE,
  'Synthetic demo SOP. Line of business: ' || CATEGORY || '. Miss driver: ' || MISS_DRIVER || '. '
  || 'Step 1: the real-time analyst confirms the service-level alert, notes the interval and the queue, and informs the team lead on shift within 10 minutes. '
  || 'Step 2: ' || CASE
       WHEN MISS_DRIVER = 'Inbound volume spike' THEN 'compare offered contacts with the interval forecast, open overflow to cross-skilled agents, and move offline activities (coaching, team meetings) out of the next two intervals.'
       WHEN MISS_DRIVER = 'Unplanned absenteeism' THEN 'check the attendance board, call in agents on the voluntary overtime list, and ask the workforce planner to reforecast the rest of the shift.'
       WHEN MISS_DRIVER = 'Schedule gap' THEN 'compare scheduled heads with the required heads per interval, shift break and lunch slots out of the gap, and log the gap for the next scheduling cycle.'
       WHEN MISS_DRIVER = 'Long handle times' THEN 'pull the longest open contacts, send a floor walker to agents above the handle time threshold, and share the latest known-issue note.'
       WHEN MISS_DRIVER = 'System latency' THEN 'raise a ticket with the site IT desk, ask agents to log the affected contacts, and switch to the documented manual workaround until latency clears.'
       WHEN MISS_DRIVER = 'Chat concurrency cap' THEN 'raise the concurrent chat limit for experienced agents within the approved range, and move agents in nesting to single-chat mode.'
       WHEN MISS_DRIVER = 'Billing cycle surge' THEN 'publish the billing cycle quick answer to the agent desktop, enable the billing self-service message in the chat queue, and add cross-skilled agents.'
       WHEN MISS_DRIVER = 'Campaign volume spike' THEN 'confirm the campaign schedule with the client team, open overflow from the customer care queue, and reforecast the next three intervals.'
       WHEN MISS_DRIVER = 'Backlog carryover' THEN 'sort the open conversations by age, assign the oldest to senior agents, and post an expected response time on the channel.'
       ELSE 'review the interval against the queue profile and raise it with the operations manager if unexplained.'
     END
  || ' Step 3: if the abandonment rate for the queue exceeds 8% or the average handle time exceeds 12 minutes after the action, keep the alert open and request an intraday reforecast. '
  || 'Step 4: record the outcome; if the interval stayed below service level or an overtime call-out was made, log it for the weekly workforce review.' AS CONTENT
FROM types;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.WFM_SOP_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, MISS_DRIVER
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, MISS_DRIVER, CONTENT FROM SEARCH.WFM_DOCS);

-- ---------- Abandonment rate anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.ABANDON_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, ABANDON_RATE_PCT::FLOAT AS ABANDON_RATE
FROM RAW.QUEUE_DAILY;
CREATE OR REPLACE VIEW ML.ABANDON_TRAIN AS
SELECT * FROM ML.ABANDON_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.ABANDON_SERIES);
CREATE OR REPLACE VIEW ML.ABANDON_DETECT AS
SELECT * FROM ML.ABANDON_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.ABANDON_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.ABANDON_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.ABANDON_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'ABANDON_RATE',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.ABANDON_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS ABANDON_RATE, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.ABANDON_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.ABANDON_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'ABANDON_RATE'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.CONTACT_CENTER_ANALYTICS
  TABLES (
    queues AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      WITH SYNONYMS = ('entities', 'queues', 'contact queues', 'lines of business')
      COMMENT = 'One row per queue (site city and line of business), 90-day totals',
    risk AS ML.SL_MISS_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-7-day service-level miss probability per queue',
    drivers AS CURATED.MISS_DRIVER_SUMMARY PRIMARY KEY (MISS_DRIVER)
      COMMENT = 'Service-level alerts, intervals below service level and overtime call-outs by miss driver, 90 days',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Contact-centre-wide totals per day'
  )
  RELATIONSHIPS (risk_queue AS risk (ENTITY_ID) REFERENCES queues)
  FACTS (
    queues.intervals_f AS INTERVAL_COUNT,
    queues.alerts_f AS SL_ALERT_COUNT,
    queues.misses_f AS SL_MISS_COUNT,
    queues.callouts_f AS OVERTIME_CALLOUT_COUNT,
    queues.contacts_f AS CONTACT_COUNT,
    queues.cost_f AS LABOR_COST_PHP,
    queues.reforecast_due_f AS REFORECAST_DUE,
    queues.reforecast_done_f AS REFORECAST_DONE,
    risk.miss_prob_f AS MISS_PROB_7D,
    drivers.driver_alerts_f AS SL_ALERT_COUNT,
    drivers.driver_misses_f AS SL_MISS_COUNT,
    drivers.driver_callouts_f AS OVERTIME_CALLOUT_COUNT,
    drivers.driver_cost_f AS EXPOSED_COST_PHP,
    daily.day_alerts_f AS SL_ALERT_COUNT,
    daily.day_misses_f AS SL_MISS_COUNT,
    daily.day_cost_f AS LABOR_COST_PHP
  )
  DIMENSIONS (
    queues.queue_id AS ENTITY_ID WITH SYNONYMS = ('queue', 'entity', 'line', 'skill group'),
    queues.queue_name AS ENTITY_NAME,
    queues.city AS REGION WITH SYNONYMS = ('city', 'region', 'site', 'location')
      COMMENT = 'Philippine site city that serves the queue',
    queues.category AS CATEGORY WITH SYNONYMS = ('line of business', 'LOB', 'channel'),
    queues.risk_tier AS RISK_TIER COMMENT = 'Queue staffing risk tier 1 (low) to 3 (high)',
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    drivers.miss_driver AS MISS_DRIVER WITH SYNONYMS = ('driver', 'miss reason', 'root cause'),
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    queues.queue_total AS COUNT(queues.queue_id) WITH SYNONYMS = ('number of queues', 'number of entities', 'how many queues'),
    queues.sl_attainment_rate_pct AS 100 * (SUM(queues.intervals_f) - SUM(queues.misses_f)) / NULLIF(SUM(queues.intervals_f), 0)
      WITH SYNONYMS = ('service level attainment', 'intervals meeting service level')
      COMMENT = 'Intervals meeting service level / intervals staffed',
    queues.alert_miss_rate_pct AS 100 * SUM(queues.misses_f) / NULLIF(SUM(queues.alerts_f), 0)
      COMMENT = 'Intervals below service level / service-level alerts raised',
    queues.sl_alerts_raised AS SUM(queues.alerts_f) WITH SYNONYMS = ('alerts', 'service-level alerts'),
    queues.sl_intervals_missed AS SUM(queues.misses_f) WITH SYNONYMS = ('missed intervals', 'intervals below service level', 'misses'),
    queues.overtime_callouts AS SUM(queues.callouts_f) WITH SYNONYMS = ('overtime', 'call-outs'),
    queues.contacts_offered AS SUM(queues.contacts_f) WITH SYNONYMS = ('contacts', 'contact volume', 'calls'),
    queues.total_labor_cost_php AS SUM(queues.cost_f) WITH SYNONYMS = ('labor cost', 'agent cost', 'cost in PHP'),
    queues.reforecast_compliance_pct AS 100 * SUM(queues.reforecast_done_f) / NULLIF(SUM(queues.reforecast_due_f), 0)
      COMMENT = 'Intraday reforecasts completed / reforecasts due',
    risk.avg_miss_prob AS AVG(risk.miss_prob_f),
    drivers.driver_alerts AS SUM(drivers.driver_alerts_f),
    drivers.driver_misses AS SUM(drivers.driver_misses_f),
    drivers.driver_callouts AS SUM(drivers.driver_callouts_f),
    drivers.driver_miss_share_pct AS 100 * SUM(drivers.driver_misses_f) / NULLIF(SUM(drivers.driver_alerts_f), 0),
    daily.daily_alerts AS SUM(daily.day_alerts_f),
    daily.daily_misses AS SUM(daily.day_misses_f),
    daily.daily_labor_cost_php AS SUM(daily.day_cost_f)
  )
  COMMENT = 'Synthetic Philippine BPO contact centre queue analytics (demo)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.CONTACT_CENTER_AGENT
  COMMENT = 'Contact centre workforce operations assistant over a synthetic Philippine BPO provider'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic. Give queue IDs and numbers with units (PHP, %, intervals)."
  orchestration: "Use queue_analyst for contacts offered, agent labor cost, service-level alerts, intervals below service level, overtime call-outs, service level attainment, reforecast compliance, queues, site cities, lines of business, miss drivers and service-level miss risk. Use sop_search for service-level recovery procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: queue_analyst
      description: "Contacts offered, agent labor cost in PHP, service-level alerts, intervals below service level, overtime call-outs, service level attainment, reforecast compliance, miss drivers and service-level miss risk scores by queue, site city and line of business"
  - tool_spec:
      type: cortex_search
      name: sop_search
      description: "Synthetic service-level recovery SOPs by line of business and miss driver"
tool_resources:
  queue_analyst:
    semantic_view: __DEMO_DB__.APP.CONTACT_CENTER_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  sop_search:
    name: __DEMO_DB__.SEARCH.WFM_SOP_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live-interaction alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), QUEUE_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, WAIT_SECONDS FLOAT, HANDLE_MINUTES FLOAT, SOP_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION PH_BPO_CONTACT_CENTER_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_ALERTS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (QUEUE_ID, EVENT_TS, WAIT_SECONDS, HANDLE_MINUTES, SOP_HINT)
    SELECT p.QUEUE_ID, p.EVENT_TS, p.WAIT_SECONDS, p.HANDLE_MINUTES,
           'Check ' || r.CATEGORY || ' service-level recovery SOPs; current risk band ' || COALESCE(s.RISK_BAND, 'n/a')
    FROM RAW.LIVE_INTERACTIONS p
    JOIN RAW.QUEUES r ON r.ID = p.QUEUE_ID
    LEFT JOIN ML.SL_MISS_SCORES s ON s.ENTITY_ID = p.QUEUE_ID
    WHERE p.STATUS = 'ABANDONED'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.QUEUE_ID = p.QUEUE_ID AND l.EVENT_TS = p.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('PH_BPO_CONTACT_CENTER_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] Abandoned contact alert',
      'New abandoned live contacts logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_INTERACTION_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_INTERACTIONS p
    WHERE p.STATUS = 'ABANDONED'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.QUEUE_ID = p.QUEUE_ID AND l.EVENT_TS = p.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_ALERTS();

-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.MISS_DRIVER_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.SL_MISS_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.SL_MISS_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.SL_MISS_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'RISK_TIER', RISK_TIER, 'QUEUE_AGE_YEARS', QUEUE_AGE_YEARS,
             'ABANDON_RATE_PCT', ABANDON_RATE_PCT, 'AVG_HANDLE_MIN', AVG_HANDLE_MIN,
             'ABANDON_RATE_7D', ABANDON_RATE_7D, 'MISSES_30D', MISSES_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:MISS::FLOAT, 4) AS MISS_PROB_7D,
         CASE WHEN PRED:probability:MISS::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:MISS::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
