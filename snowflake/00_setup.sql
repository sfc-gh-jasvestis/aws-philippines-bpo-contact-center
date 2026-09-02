-- Generated from generator/demo_specs/aws-philippines-bpo-contact-center.json
-- Regenerate with: python3 generator/gen_repo_docs.py aws-philippines-bpo-contact-center
-- This is the schema that is actually deployed for PH_BPO_CONTACT_CENTER.

-- PH_BPO_CONTACT_CENTER  (Contact Center Intelligence & CSAT Optimization)
-- generated from generator/demo_specs/aws-philippines-bpo-contact-center.json - do not hand-edit
CREATE DATABASE IF NOT EXISTS PH_BPO_CONTACT_CENTER;
CREATE SCHEMA IF NOT EXISTS PH_BPO_CONTACT_CENTER.RAW;
CREATE SCHEMA IF NOT EXISTS PH_BPO_CONTACT_CENTER.CURATED;
CREATE SCHEMA IF NOT EXISTS PH_BPO_CONTACT_CENTER.APP;
USE DATABASE PH_BPO_CONTACT_CENTER;

-- 5 real regions; entity names carry their region so the two always agree
