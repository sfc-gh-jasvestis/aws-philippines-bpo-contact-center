# Demo Script: Contact Center Intelligence & CSAT Optimization
## ~4-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: Customer meeting / booth loop / social share
**Narrative**: "Snowflake processes contact center interactions from Amazon Connect, classifies customer intent with AI, scores sentiment for CSAT prediction, and enables natural language analytics — replacing fragmented WFM tools with one platform"
**Demo Mode**: Open app with `?demo=true` for presenter notes

---

## Two Personas

| Persona | Role | Tool | What they care about |
|---|---|---|---|
| **Patricia Angela Villanueva** | VP Client Services | React App (SPCS) | Client CSAT scores, SLA compliance, NPS trends, escalation rates |
| **Rafael Miguel Chua** | Quality Assurance Lead | Amazon QuickSight | Call quality scoring, agent coaching, root cause of negative sentiment, compliance |

---

## What's Built

| Layer | Component | Detail |
|---|---|---|
| **RAW** | 7 tables | ACCOUNTS (35), AGENTS (8500), INTERACTIONS (620000), TRANSCRIPTS (450000), CSAT_SURVEYS (185000), SLA_DEFINITIONS (35), QUALITY_AUDITS (42000) |
| **CURATED** | 4 Dynamic Tables | ACCOUNT_HEALTH_SCORE, AGENT_SENTIMENT_SCORES, INTERACTION_ENRICHED, COMPLAINT_PARETO |
| **ML** | ML.CLASSIFICATION + ML.FORECAST | Forecasting + anomaly detection |
| **AI** | AI_CLASSIFY, AI_SENTIMENT, COMPLETE | Classification + extraction |
| **Search** | Cortex Search | 450000 documents indexed |
| **Agent** | CONTACT_CENTER_AGENT | Semantic View + Search tools |


---

## The Story

A Philippine BPO giant operates 12 contact centers handling 620,000 interactions monthly for 35 enterprise clients. Five accounts worth ₱890M in annual contracts are below CSAT SLA targets — but with interactions split across voice, chat, and email, nobody could pinpoint the root cause until now. Amazon Connect captures every interaction; Snowflake's AI classifies, scores, and surfaces the patterns.

---

## Script

### [0:00–0:45] EXECUTIVE COCKPIT

**Show**: Executive Cockpit tab

> "Six hundred twenty thousand interactions processed this month across 35 client accounts."

**Action**: Point at 620K interactions processed KPI

### [0:45–1:30] SENTIMENT ANALYTICS

**Show**: Sentiment Analytics tab

> "AI_SENTIMENT processed 450,000 transcripts — 23% scored negative this month."

**Action**: Show sentiment distribution chart

### [1:30–2:15] QUALITY & COACHING

**Show**: Quality & Coaching tab

> "142 agents in bottom quartile for sentiment scores — candidates for coaching."

**Action**: Show agent performance quadrant

### [2:15–3:00] ASK AI

**Show**: Ask AI tab

> "Patricia asks: 'Which account has the highest escalation rate this week?'"

**Action**: Type: 'Which account has highest escalation rate?'

### [3:00–3:45] ARCHITECTURE & DATA

**Show**: Architecture & Data tab

> "Amazon Connect feeds interactions → Snowpipe Streaming → AI enrichment → real-time dashboards."

**Action**: Walk through architecture diagram


---

## Key Demo Differentiators

1. **AI_SENTIMENT on 450K transcripts** — Only demo scoring sentiment at this scale natively in Snowflake
2. **AI_CLASSIFY for interaction intent** — Replaces Amazon Comprehend with zero data movement
3. **Amazon Connect integration** — Only demo showing Connect → Snowpipe → AI enrichment pipeline
4. **Agent coaching via Cortex Complete** — AI generates personalized coaching plans from interaction patterns
5. **Philippine BPO voice context** — 70% of world's voice BPO with Filipino agents, US/UK/AU clients
6. **450K searchable transcripts** — Cortex Search across half a million call transcripts with attribute filtering


---

## Demo Prep Checklist

### Data Verification
- [ ] `SELECT COUNT(*) FROM CONTACT_CENTER_AI.RAW.INTERACTIONS` → 620000
- [ ] `SELECT COUNT(*) FROM CONTACT_CENTER_AI.RAW.TRANSCRIPTS` → 450000
- [ ] `SELECT COUNT(DISTINCT ACCOUNT_ID) FROM CONTACT_CENTER_AI.CURATED.ACCOUNT_HEALTH_SCORE WHERE CSAT_STATUS = 'BELOW_SLA'` → 5

### ML Model Verification
- [ ] `SELECT COUNT(*) FROM CONTACT_CENTER_AI.ML.CSAT_CLASSIFICATION_RESULTS` → >0

### AI/Agent Verification
- [ ] `SELECT COUNT(*) FROM CONTACT_CENTER_AI.AI.SENTIMENT_SCORES WHERE SENTIMENT < -0.3` → >100000
- [ ] `SELECT COUNT(DISTINCT INTENT) FROM CONTACT_CENTER_AI.AI.INTENT_CLASSIFICATION` → >=4

