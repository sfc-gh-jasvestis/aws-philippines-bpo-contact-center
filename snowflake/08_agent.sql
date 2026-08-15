-- ============================================================================
-- 08_AGENT.SQL — Cortex Agent for Contact Center Intelligence & CSAT Optimization
-- ============================================================================
USE DATABASE CONTACT_CENTER_AI;
USE SCHEMA APP;

CREATE OR REPLACE CORTEX AGENT APP.CONTACT_CENTER_AGENT
  COMMENT = 'Contact Center Intelligence & CSAT Optimization AI Assistant'
  MODEL = 'claude-opus-4-8'
  TOOLS = (
    SEMANTIC_VIEW_TOOL(SEMANTIC_VIEW => 'CONTACT_CENTER_AI.APP.CONTACT_CENTER_ANALYTICS'),    CORTEX_SEARCH_TOOL(CORTEX_SEARCH_SERVICE => 'CONTACT_CENTER_AI.SEARCH.TRANSCRIPT_SEARCH', TOOL_DESCRIPTION => 'Search documents for BPO & IT Services information')
  )
  SYSTEM_PROMPT = 'You are the Contact Center Intelligence Agent for a Philippine BPO handling 620K monthly interactions across 35 enterprise client accounts.';
