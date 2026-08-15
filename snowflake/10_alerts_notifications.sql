-- ============================================================================
-- 10_ALERTS_NOTIFICATIONS.SQL — Alerts for Contact Center Intelligence & CSAT Optimization
-- ============================================================================
USE DATABASE CONTACT_CENTER_AI;
USE SCHEMA APP;

-- Notification integration (email)
CREATE OR REPLACE NOTIFICATION INTEGRATION aws_philippines_bpo_contact_center_EMAIL_INT
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('jonathan.asvestis@snowflake.com');

-- Alert: CSAT_BREACH_ALERT
CREATE OR REPLACE ALERT APP.CSAT_BREACH_ALERT
  WAREHOUSE = CC_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Client CSAT below SLA threshold'
IF (EXISTS (
  SELECT 1 FROM CURATED.ACCOUNT_HEALTH_SCORE
  WHERE 1=1 -- Condition: ACCOUNT_CSAT < SLA_TARGET for any account
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_philippines_bpo_contact_center_EMAIL_INT',
    'jonathan.asvestis@snowflake.com',
    '[ALERT] Contact Center Intelligence & CSAT Optimization: Client CSAT below SLA threshold',
    'Client CSAT below SLA threshold'
  );

ALTER ALERT APP.CSAT_BREACH_ALERT RESUME;

-- Alert: SENTIMENT_DROP_ALERT
CREATE OR REPLACE ALERT APP.SENTIMENT_DROP_ALERT
  WAREHOUSE = CC_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Negative sentiment spike detected'
IF (EXISTS (
  SELECT 1 FROM CURATED.ACCOUNT_HEALTH_SCORE
  WHERE 1=1 -- Condition: DAILY_AVG_SENTIMENT < -0.3 for any account
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_philippines_bpo_contact_center_EMAIL_INT',
    'jonathan.asvestis@snowflake.com',
    '[ALERT] Contact Center Intelligence & CSAT Optimization: Negative sentiment spike detected',
    'Negative sentiment spike detected'
  );

ALTER ALERT APP.SENTIMENT_DROP_ALERT RESUME;

