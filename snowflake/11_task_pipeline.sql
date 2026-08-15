-- ============================================================================
-- 11_TASK_PIPELINE.SQL — Task DAG for Contact Center Intelligence & CSAT Optimization
-- ============================================================================
USE DATABASE CONTACT_CENTER_AI;
USE SCHEMA APP;

CREATE OR REPLACE TASK APP.TASK_ENRICH_INTERACTIONS
  WAREHOUSE = CC_WH
  SCHEDULE = 'USING CRON 0 */2 * * * UTC'
  COMMENT = 'Classify intent and score sentiment for new interactions'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_UPDATE_HEALTH_SCORES
  WAREHOUSE = CC_WH
  AFTER APP.TASK_ENRICH_INTERACTIONS
  COMMENT = 'Refresh account health scores'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_GENERATE_COACHING
  WAREHOUSE = CC_WH
  AFTER APP.TASK_UPDATE_HEALTH_SCORES
  COMMENT = 'Generate coaching recommendations for bottom-quartile agents'
AS
  SELECT 1; -- Replace with actual refresh logic

ALTER TASK APP.TASK_GENERATE_COACHING RESUME;
ALTER TASK APP.TASK_UPDATE_HEALTH_SCORES RESUME;
ALTER TASK APP.TASK_ENRICH_INTERACTIONS RESUME;
