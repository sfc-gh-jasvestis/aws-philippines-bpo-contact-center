-- ============================================================================
-- 03_STAGING.SQL — Generate synthetic data for Contact Center Intelligence & CSAT Optimization
-- Country: PHILIPPINES | Currency: PHP
-- ============================================================================
USE DATABASE CONTACT_CENTER_AI;
USE SCHEMA RAW;

-- Data generation scripts are demo-specific.
-- See the handcrafted SQL in the aws-malaysia-semiconductor-yield demo for
-- the full pattern: GENERATOR + UNIFORM + LATERAL for distribution,
-- Cortex Complete for text generation, engineered key demo numbers.

-- Target row counts:
-- ACCOUNTS: 35 rows — Client accounts served (US/UK/AU enterprise clients)
-- AGENTS: 8,500 rows — Contact center agents across 12 sites
-- INTERACTIONS: 620,000 rows — 30 days of call/chat/email interactions from Amazon Connect
-- TRANSCRIPTS: 450,000 rows — Call transcripts from Amazon Transcribe
-- CSAT_SURVEYS: 185,000 rows — Post-interaction customer satisfaction surveys
-- SLA_DEFINITIONS: 35 rows — Per-account SLA thresholds (AHT, FCR, CSAT, ASA)
-- QUALITY_AUDITS: 42,000 rows — Manual QA scores and coaching notes
