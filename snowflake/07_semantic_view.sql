-- ============================================================================
-- 07_SEMANTIC_VIEW.SQL — Semantic View for Contact Center Intelligence & CSAT Optimization
-- ============================================================================
USE DATABASE CONTACT_CENTER_AI;
USE SCHEMA APP;

CREATE OR REPLACE SEMANTIC VIEW APP.CONTACT_CENTER_ANALYTICS
  COMMENT = 'Contact center CSAT, sentiment, quality, and SLA analytics'
AS
  TABLES (
    CURATED.ACCOUNT_HEALTH_SCORE AS account_health_score,CURATED.AGENT_SENTIMENT_SCORES AS agent_sentiment_scores,CURATED.INTERACTION_ENRICHED AS interaction_enriched,CURATED.COMPLAINT_PARETO AS complaint_pareto
  );
