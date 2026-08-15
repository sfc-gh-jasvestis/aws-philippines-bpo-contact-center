-- ============================================================================
-- Contact Center Intelligence & CSAT Optimization
-- Philippine BPO agents handle 2.3M calls daily — Snowflake ingests Amazon Connect interactions, classifies intent, scores sentiment in real-time, and surfaces CSAT drivers before client SLAs breach.
-- ============================================================================
USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS CONTACT_CENTER_AI;
CREATE WAREHOUSE IF NOT EXISTS CC_WH WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 120 AUTO_RESUME = TRUE;
USE DATABASE CONTACT_CENTER_AI;
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS CURATED;
CREATE SCHEMA IF NOT EXISTS ML;
CREATE SCHEMA IF NOT EXISTS AI;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

USE WAREHOUSE CC_WH;
