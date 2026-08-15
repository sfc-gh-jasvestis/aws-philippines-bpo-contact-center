-- ============================================================================
-- 04_DYNAMIC_TABLES.SQL — Curated layer for Contact Center Intelligence & CSAT Optimization
-- ============================================================================
USE DATABASE CONTACT_CENTER_AI;
USE SCHEMA CURATED;

-- ACCOUNT_HEALTH_SCORE: Real-time client account health combining CSAT, SLA, NPS
-- Source: ACCOUNTS, INTERACTIONS, CSAT_SURVEYS
CREATE OR REPLACE DYNAMIC TABLE CURATED.ACCOUNT_HEALTH_SCORE
  TARGET_LAG = '5 minutes'
  WAREHOUSE = CC_WH
AS
SELECT * FROM RAW.ACCOUNTS;
-- TODO: Replace with actual join/aggregation logic per demo

-- AGENT_SENTIMENT_SCORES: Per-agent average sentiment and quality metrics
-- Source: AGENTS, TRANSCRIPTS, QUALITY_AUDITS
CREATE OR REPLACE DYNAMIC TABLE CURATED.AGENT_SENTIMENT_SCORES
  TARGET_LAG = '5 minutes'
  WAREHOUSE = CC_WH
AS
SELECT * FROM RAW.AGENTS;
-- TODO: Replace with actual join/aggregation logic per demo

-- INTERACTION_ENRICHED: Interactions enriched with intent, sentiment, and resolution
-- Source: INTERACTIONS, TRANSCRIPTS
CREATE OR REPLACE DYNAMIC TABLE CURATED.INTERACTION_ENRICHED
  TARGET_LAG = '5 minutes'
  WAREHOUSE = CC_WH
AS
SELECT * FROM RAW.INTERACTIONS;
-- TODO: Replace with actual join/aggregation logic per demo

-- COMPLAINT_PARETO: Top complaint categories by volume and CSAT impact
-- Source: INTERACTIONS, CSAT_SURVEYS
CREATE OR REPLACE DYNAMIC TABLE CURATED.COMPLAINT_PARETO
  TARGET_LAG = '5 minutes'
  WAREHOUSE = CC_WH
AS
SELECT * FROM RAW.INTERACTIONS;
-- TODO: Replace with actual join/aggregation logic per demo

