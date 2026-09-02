# Contact Center Intelligence & CSAT Optimization

**Philippines - BPO & IT Services**
Use case: Contact Center Intelligence

> Philippine BPO agents handle 2.3M calls daily — Snowflake ingests Amazon Connect interactions, classifies intent, scores sentiment in real-time, and surfaces CSAT drivers before client SLAs breach.

## Why Snowflake

Snowflake processes contact center interactions from Amazon Connect, classifies customer intent with AI, scores sentiment for CSAT prediction, and enables natural language analytics — replacing fragmented WFM tools with one platform

- **AI_SENTIMENT on 450K transcripts** - Only demo scoring sentiment at this scale natively in Snowflake
- **AI_CLASSIFY for interaction intent** - Replaces Amazon Comprehend with zero data movement
- **Amazon Connect integration** - Only demo showing Connect → Snowpipe → AI enrichment pipeline
- **Agent coaching via Cortex Complete** - AI generates personalized coaching plans from interaction patterns
- **Philippine BPO voice context** - 70% of world's voice BPO with Filipino agents, US/UK/AU clients
- **450K searchable transcripts** - Cortex Search across half a million call transcripts with attribute filtering

## What is deployed

| | |
|---|---|
| Database | `PH_BPO_CONTACT_CENTER` |
| Service | `PH_BPO_CONTACT_CENTER_APP` |
| Compute pool | `SEA_DEMOS_PHILIPPINES_POOL` |
| Dimension table | `RAW.ACCOUNTS` (20 rows) |
| Fact table | `RAW.INTERACTIONS` (250,000 rows, 90 days) |
| Curated layer | `CURATED.PERFORMANCE_SUMMARY`, `CURATED.TREND_ANALYSIS`, `CURATED.KPI_SUMMARY` |
| Currency | PHP (₱) |

Regions in play: Metro Manila, Cebu, Davao, Pampanga, Iloilo
Segments: Voice Inbound, Voice Outbound, Chat, Email

Dynamic tables are created suspended and refreshed on demand:

```bash
./refresh_demo_data.sh PH_BPO_CONTACT_CENTER
```

## KPI cards

Every card below is served live from `CURATED.KPI_SUMMARY`. The app keeps the
original literal as a fallback, so it still renders if Snowflake is unreachable.

| Card | Value | Backed by |
|---|---|---|
| Calls Handled (MTD) | `2.4M` | total across Accounts |
| Avg Handle Time | `4:32` | average per event |
| CSAT Score | `4.2/5` | average per event |
| Agents Active | `12,400` | total across Accounts |
| First Call Resolution | `78%` | average per event |
| Occupancy Rate | `84%` | average per event |
| Agent Attrition | `4.2%/mo` | average per event |


## Demo flow

1. Executive Cockpit
2. Sentiment Analytics
3. Quality & Coaching
4. Ask AI
5. Architecture & Data

## Talking points

- **620,000** - monthly interactions processed across 35 accounts
- **5 accounts** - below CSAT SLA target (₱890M contract value at risk)
- **450,000** - transcripts scored by AI_SENTIMENT
- **23%** - of interactions scored negative sentiment
- **142 agents** - identified for AI-generated coaching plans
- **18% CSAT improvement** - after completing AI-recommended coaching

## Business impact

- Philippines handles 70% of global voice BPO outsourcing (IBPAP)
- AI-powered quality monitoring improves CSAT 15-25% in contact centers (Gartner)
- Real-time sentiment analysis reduces escalations by 30% (Forrester)
- Contact center AI market projected to reach $4.1B by 2027 (MarketsandMarkets)

---
Generated from `generator/demo_specs/aws-philippines-bpo-contact-center.json`. Do not hand-edit: run
`python3 generator/gen_repo_docs.py aws-philippines-bpo-contact-center` instead.
