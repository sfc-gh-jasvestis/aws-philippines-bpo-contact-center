import { NextResponse } from 'next/server';
import { demoPlatform } from '@/lib/platform';
import { executeQuery } from '@/lib/snowflake';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export async function GET() {
  try {
    const [kpis, trend, types, queues, freshness, risk, holdout, forecast, live, liveSummary, anomalies, alerts] = await Promise.all([
      executeQuery<{ TITLE: string; DISPLAY: string; STATUS: string }>(
        'SELECT TITLE, DISPLAY, STATUS FROM CURATED.KPI_SUMMARY ORDER BY SORT_ORDER'),
      executeQuery<{ PERIOD: string; SL_ALERTS: number | null; SL_MISSES: number | null }>(`
        SELECT TO_CHAR(METRIC_DATE, 'YYYY-MM-DD') AS PERIOD,
               SL_ALERT_COUNT AS SL_ALERTS, SL_MISS_COUNT AS SL_MISSES
        FROM CURATED.TREND_ANALYSIS ORDER BY METRIC_DATE`),
      executeQuery<{ MISS_DRIVER: string; SL_ALERTS: number; SL_MISSES: number }>(`
        SELECT MISS_DRIVER, SL_ALERT_COUNT AS SL_ALERTS, SL_MISS_COUNT AS SL_MISSES
        FROM CURATED.MISS_DRIVER_SUMMARY ORDER BY SL_MISS_COUNT DESC, SL_ALERT_COUNT DESC`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, ENTITY_NAME, REGION, CATEGORY, RISK_TIER, EVENT_COUNT, CONTACT_COUNT, SL_ALERT_COUNT,
               SL_MISS_COUNT, OVERTIME_CALLOUT_COUNT, ALERT_MISS_PCT, REFORECAST_PCT, ROUND(LABOR_COST_PHP / 1e6, 2) AS LABOR_COST_PHP_M
        FROM CURATED.PERFORMANCE_SUMMARY ORDER BY ENTITY_ID LIMIT 200`),
      executeQuery<{ RAW_WATERMARK: string | null; CURATED_WATERMARK: string | null }>(`
        SELECT (SELECT TO_CHAR(MAX(EVENT_DATE), 'YYYY-MM-DD') FROM RAW.QUEUE_DAILY) AS RAW_WATERMARK,
               (SELECT TO_CHAR(MAX(METRIC_DATE), 'YYYY-MM-DD') FROM CURATED.TREND_ANALYSIS) AS CURATED_WATERMARK`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, TO_CHAR(SCORED_AS_OF, 'YYYY-MM-DD') AS SCORED_AS_OF, MISS_PROB_7D, RISK_BAND
        FROM ML.SL_MISS_SCORES ORDER BY MISS_PROB_7D DESC`),
      executeQuery<Record<string, string | number | null>>(
        'SELECT N, BASE_RATE, PRECISION_AT_50, RECALL_AT_50 FROM ML.SL_MISS_HOLDOUT_METRICS'),
      executeQuery<Record<string, string | number | null>>(`
        SELECT TO_CHAR(FORECAST_DATE, 'YYYY-MM-DD') AS PERIOD, SL_ALERT_COUNT, LOWER_BOUND, UPPER_BOUND
        FROM ML.SL_ALERT_FORECAST ORDER BY FORECAST_DATE`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT QUEUE_ID, TO_CHAR(EVENT_TS, 'YYYY-MM-DD HH24:MI:SS') AS EVENT_TS, ROUND(WAIT_SECONDS, 2) AS WAIT_SECONDS,
               HANDLE_MINUTES, STATUS, TO_CHAR(LOADED_AT, 'YYYY-MM-DD HH24:MI:SS TZH:TZM') AS LOADED_AT
        FROM RAW.LIVE_INTERACTIONS ORDER BY EVENT_TS DESC LIMIT 25`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT COUNT(*) AS N, COUNT_IF(STATUS = 'ABANDONED') AS SL_ALERTS,
               TO_CHAR(MAX(LOADED_AT), 'YYYY-MM-DD HH24:MI:SS TZH:TZM') AS LAST_LOADED,
               ROUND(MEDIAN(DATEDIFF('second', SENT_TS, CONVERT_TIMEZONE('UTC', LOADED_AT)::TIMESTAMP_NTZ)), 0) AS MEDIAN_LAG_S
        FROM RAW.LIVE_INTERACTIONS`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, TO_CHAR(EVENT_DATE, 'YYYY-MM-DD') AS EVENT_DATE, ROUND(ABANDON_RATE, 2) AS ABANDON_RATE,
               ROUND(EXPECTED, 2) AS EXPECTED, ROUND(UPPER_BOUND, 2) AS UPPER_BOUND
        FROM ML.ABANDON_ANOMALIES WHERE IS_ANOMALY ORDER BY EVENT_DATE DESC, ENTITY_ID LIMIT 50`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT QUEUE_ID, TO_CHAR(EVENT_TS, 'YYYY-MM-DD HH24:MI:SS') AS EVENT_TS, ROUND(WAIT_SECONDS, 2) AS WAIT_SECONDS,
               HANDLE_MINUTES, SOP_HINT
        FROM APP.ALERT_LOG ORDER BY ALERTED_AT DESC, EVENT_TS DESC LIMIT 25`),
    ]);
    const numberOrNull = (value: unknown): number | null => {
      if (value === null || value === undefined) return null;
      const numeric = Number(value);
      if (!Number.isFinite(numeric)) throw new Error('Non-numeric measure in curated contract');
      return numeric;
    };
    const watermark = freshness[0]?.CURATED_WATERMARK ?? null;
    const ageDays = watermark ? (Date.now() - Date.parse(`${watermark}T00:00:00Z`)) / 86400000 : null;
    return NextResponse.json({
      platform: demoPlatform(),
      kpiCards: kpis.map((row) => ({ title: row.TITLE, value: row.DISPLAY, status: row.STATUS })),
      timeseries: trend.map((row) => ({ period: row.PERIOD, alerts: numberOrNull(row.SL_ALERTS), missed: numberOrNull(row.SL_MISSES) })),
      categories: types.map((row) => ({ category: row.MISS_DRIVER, alerts: numberOrNull(row.SL_ALERTS), missed: numberOrNull(row.SL_MISSES) })),
      entities: queues.map((row) => ({
        id: row.ENTITY_ID, name: row.ENTITY_NAME, region: row.REGION, category: row.CATEGORY, tier: row.RISK_TIER,
        contacts: numberOrNull(row.CONTACT_COUNT), alerts: numberOrNull(row.SL_ALERT_COUNT), missed: numberOrNull(row.SL_MISS_COUNT),
        callouts: numberOrNull(row.OVERTIME_CALLOUT_COUNT), missRate: numberOrNull(row.ALERT_MISS_PCT),
        value: numberOrNull(row.LABOR_COST_PHP_M), reforecast: numberOrNull(row.REFORECAST_PCT), events: numberOrNull(row.EVENT_COUNT),
      })),
      reforecastRisk: queues.map((row) => ({
        name: row.ENTITY_NAME, compliance: numberOrNull(row.REFORECAST_PCT), missed: numberOrNull(row.SL_MISS_COUNT),
      })).filter((row) => row.compliance !== null && row.missed !== null),
      sourceWatermark: watermark,
      rawWatermark: freshness[0]?.RAW_WATERMARK ?? null,
      stale: ageDays === null || ageDays > 2,
      pipelineBehind: freshness[0]?.RAW_WATERMARK !== watermark,
      requestedAt: new Date().toISOString(),
      synthetic: true,
      risk: risk.map((row) => ({
        id: row.ENTITY_ID, scoredAsOf: row.SCORED_AS_OF,
        probability: numberOrNull(row.MISS_PROB_7D), band: row.RISK_BAND,
      })),
      holdout: holdout[0] ? {
        n: numberOrNull(holdout[0].N), baseRate: numberOrNull(holdout[0].BASE_RATE),
        precision: numberOrNull(holdout[0].PRECISION_AT_50), recall: numberOrNull(holdout[0].RECALL_AT_50),
      } : null,
      forecast: forecast.map((row) => ({
        period: row.PERIOD, value: numberOrNull(row.SL_ALERT_COUNT),
        lower: numberOrNull(row.LOWER_BOUND), upper: numberOrNull(row.UPPER_BOUND),
      })),
      modelStatus: holdout[0] ? 'holdout_evaluated' : 'missing',
      live: live.map((row) => ({
        id: row.QUEUE_ID, eventTs: row.EVENT_TS, wait: numberOrNull(row.WAIT_SECONDS),
        handle: numberOrNull(row.HANDLE_MINUTES), status: row.STATUS, loadedAt: row.LOADED_AT,
      })),
      liveSummary: {
        n: numberOrNull(liveSummary[0]?.N), alerts: numberOrNull(liveSummary[0]?.SL_ALERTS),
        lastLoaded: liveSummary[0]?.LAST_LOADED ?? null, medianLagSeconds: numberOrNull(liveSummary[0]?.MEDIAN_LAG_S),
      },
      anomalies: anomalies.map((row) => ({
        id: row.ENTITY_ID, date: row.EVENT_DATE, abandonRate: numberOrNull(row.ABANDON_RATE),
        expected: numberOrNull(row.EXPECTED), upper: numberOrNull(row.UPPER_BOUND),
      })),
      alerts: alerts.map((row) => ({
        id: row.QUEUE_ID, eventTs: row.EVENT_TS, wait: numberOrNull(row.WAIT_SECONDS),
        handle: numberOrNull(row.HANDLE_MINUTES), hint: row.SOP_HINT,
      })),
    }, { headers: { 'Cache-Control': 'no-store' } });
  } catch {
    return NextResponse.json({ error: 'Contact centre data is unavailable. Verify the core deployment and application role.' },
      { status: 503, headers: { 'Cache-Control': 'no-store' } });
  }
}
