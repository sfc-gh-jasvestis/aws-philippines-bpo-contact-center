-- ============================================================================
-- 05_SEARCH.SQL — Cortex Search for Contact Center Intelligence & CSAT Optimization
-- ============================================================================
USE DATABASE CONTACT_CENTER_AI;
USE SCHEMA SEARCH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.TRANSCRIPT_SEARCH
  ON TRANSCRIPT_TEXT
  ATTRIBUTES ACCOUNT_ID, AGENT_ID, CHANNEL, INTENT
  WAREHOUSE = CC_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT * FROM RAW.TRANSCRIPTS
);
