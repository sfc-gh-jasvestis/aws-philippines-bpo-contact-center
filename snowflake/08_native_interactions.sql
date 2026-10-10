-- ============================================================================
-- 08_native_interactions.sql - Snowflake-only build: live interaction feed without AWS.
-- Creates RAW.LIVE_INTERACTIONS (same columns as the Snowpipe target created by
-- aws/setup_aws.py) and APP.SIMULATE_INTERACTIONS(N), which inserts synthetic
-- interaction events with the same value ranges and ~8% ABANDONED rate as
-- aws/publish_interactions.py. Rows are inserted directly; this simulates an interaction
-- feed and is not Snowpipe Streaming.
-- Run before 06_intelligence.sql (the alert reads RAW.LIVE_INTERACTIONS).
-- Idempotent: safe to run in the AWS build too.
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS APP;

CREATE TABLE IF NOT EXISTS RAW.LIVE_INTERACTIONS (
  QUEUE_ID VARCHAR, EVENT_TS TIMESTAMP_NTZ, WAIT_SECONDS FLOAT, HANDLE_MINUTES FLOAT,
  STATUS VARCHAR, SENT_TS TIMESTAMP_NTZ, SOURCE_FILE VARCHAR,
  LOADED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());

CREATE OR REPLACE PROCEDURE APP.SIMULATE_INTERACTIONS(N NUMBER)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  IF (N < 1 OR N > 1000) THEN
    RETURN 0;
  END IF;
  INSERT INTO RAW.LIVE_INTERACTIONS (QUEUE_ID, EVENT_TS, WAIT_SECONDS, HANDLE_MINUTES, STATUS, SENT_TS, SOURCE_FILE)
    WITH g AS (
      SELECT 'Q-' || LPAD(UNIFORM(0, 47, RANDOM())::VARCHAR, 4, '0') AS QUEUE_ID,
             UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.08 AS IS_ABANDON,
             SYSDATE() AS TS, SEQ4() AS I
      FROM TABLE(GENERATOR(ROWCOUNT => 1000))
    )
    -- NORMAL() needs constant arguments, so the abandoned-contact offset is applied outside it.
    SELECT QUEUE_ID, TS,
           ROUND(IFF(IS_ABANDON, 210, 38) * EXP(NORMAL(0, 0.3, RANDOM())), 2),
           ROUND(IFF(IS_ABANDON, 0.4, 7.2) * EXP(NORMAL(0, 0.3, RANDOM())), 1),
           IFF(IS_ABANDON, 'ABANDONED', 'OK'), TS, 'APP.SIMULATE_INTERACTIONS'
    FROM g
    WHERE I < :N;
  RETURN SQLROWCOUNT;
END;
$$;

-- Optional continuous feed for longer demos (suspended; RESUME to start, SUSPEND after).
CREATE OR REPLACE TASK APP.TASK_SIMULATE_INTERACTIONS
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '1 MINUTE'
AS
  CALL APP.SIMULATE_INTERACTIONS(5);
