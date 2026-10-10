'use client';

import { useEffect, useState } from 'react';
import { AppLayout } from '@/components/AppLayout';
import { KPICard } from '@/components/KPICard';
import { Chart } from '@/components/Chart';
import { DataTable } from '@/components/DataTable';
import { AskAI } from '@/components/AskAI';
import { ActionMemo } from '@/components/ActionMemo';

interface ContactCenterData {
  platform: 'snowflake' | 'aws';
  kpiCards: { title: string; value: string }[];
  timeseries: { period: string; alerts: number | null; missed: number | null }[];
  categories: { category: string; alerts: number | null; missed: number | null }[];
  entities: Record<string, string | number | null>[];
  reforecastRisk: { name: string; compliance: number; missed: number }[];
  sourceWatermark: string | null;
  rawWatermark: string | null;
  requestedAt: string;
  stale: boolean;
  pipelineBehind: boolean;
  risk: Record<string, string | number | null>[];
  holdout: { n: number | null; baseRate: number | null; precision: number | null; recall: number | null } | null;
  forecast: { period: string; value: number | null; lower: number | null; upper: number | null }[];
  live: Record<string, string | number | null>[];
  liveSummary: { n: number | null; alerts: number | null; lastLoaded: string | null; medianLagSeconds: number | null };
  anomalies: Record<string, string | number | null>[];
  alerts: Record<string, string | number | null>[];
}

const pct = (value: number | null) => (value === null ? 'n/a' : `${(value * 100).toFixed(0)}%`);

export default function HomePage() {
  const [data, setData] = useState<ContactCenterData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError(null);
    setData(null);
    fetch('/api/data', { cache: 'no-store', signal: controller.signal })
      .then(async (response) => {
        if (!response.ok) throw new Error('Data request failed');
        const payload = await response.json();
        if (!Array.isArray(payload.kpiCards) || !Array.isArray(payload.entities)) throw new Error('Invalid contract');
        return payload;
      })
      .then(setData)
      .catch(() => {
        if (!controller.signal.aborted) setError('Snowflake data is unavailable. No fallback values are displayed.');
      })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [attempt]);

  const isAws = (data?.platform ?? 'aws') === 'aws';
  const awsDiagram = { key: 'aws', title: 'AWS + Snowflake', src: '/architecture-aws.html' };
  const sfDiagram = { key: 'snowflake', title: 'Snowflake Only', src: '/architecture-snowflake.html' };
  const diagrams = isAws ? [awsDiagram, sfDiagram] : [sfDiagram, awsDiagram];
  const kpiVal = (title: string) => data?.kpiCards.find((card) => card.title === title)?.value ?? 'Unavailable';
  const executive = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {['Service Level Attainment', 'Service-Level Alerts', 'Intervals Below Service Level', 'Agent Labor Cost (PHP M)'].map((title) => (
          <KPICard key={title} title={title} value={kpiVal(title)} status="neutral" />
        ))}
      </div>
      <p className="text-sm text-slate-600">Service level attainment = half-hour intervals meeting the service-level target / intervals staffed. Alert miss rate = intervals below service level / service-level alerts raised. Agent labor cost is the loaded PHP cost of handled minutes in the snapshot.</p>
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Chart data={data?.timeseries ?? []} type="line" xKey="period"
          yKeys={[{ key: 'alerts', name: 'Service-level alerts' }, { key: 'missed', name: 'Intervals below service level' }]} title="Daily Service-Level Alerts and Missed Intervals" />
        <Chart data={data?.categories ?? []} type="bar" xKey="category"
          yKeys={[{ key: 'alerts', name: 'Alerts' }, { key: 'missed', name: 'Intervals below service level' }]} title="Alerts and Missed Intervals by Miss Driver" />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Queue' }, { key: 'region', header: 'Site city' }, { key: 'category', header: 'Line of business' },
        { key: 'tier', header: 'Risk tier' }, { key: 'contacts', header: 'Contacts offered' }, { key: 'alerts', header: 'Alerts' },
        { key: 'missed', header: 'Missed intervals' }, { key: 'callouts', header: 'Overtime call-outs' }, { key: 'value', header: 'Agent Labor Cost (PHP M)' },
      ]} data={data?.entities ?? []} title="Queue observations, 90 days (fictional queues in 6 Philippine cities)" />
    </div>
  );
  const predictive = (
    <div className="space-y-4">
      <h2 className="font-semibold">7-day service-level miss risk and alert forecast</h2>
      <p className="text-sm text-slate-600">
        Snowflake ML classification predicts the probability that a queue has at least one half-hour interval below service level in the next 7 days,
        from the abandonment rate, average handle time, recent missed intervals, staffing risk tier, queue age and line of business.
      </p>
      {data?.holdout ? (
        <p role="status" className="text-sm text-slate-700">
          Out-of-time holdout ({data.holdout.n} queue-days): precision {pct(data.holdout.precision)} and recall{' '}
          {pct(data.holdout.recall)} at a 0.5 threshold, versus a {pct(data.holdout.baseRate)} base rate.
        </p>
      ) : (
        <p role="status">Model outputs are not deployed. Run snowflake/05_ml.sql.</p>
      )}
      <DataTable columns={[
        { key: 'id', header: 'Queue' }, { key: 'band', header: 'Risk band' },
        { key: 'probability', header: 'P(missed interval in 7 days)' }, { key: 'scoredAsOf', header: 'Scored as of' },
      ]} data={data?.risk ?? []} title="Service-level miss risk by queue" />
      <Chart data={data?.forecast ?? []} type="line" xKey="period"
        yKeys={[{ key: 'value', name: 'Forecast' }, { key: 'lower', name: 'Lower' }, { key: 'upper', name: 'Upper' }]}
        title="Contact-centre-wide service-level alert forecast, next 14 days (alerts per day)" />
      <DataTable columns={[
        { key: 'id', header: 'Queue' }, { key: 'date', header: 'Date' }, { key: 'abandonRate', header: 'Abandonment rate (%)' },
        { key: 'expected', header: 'Expected' }, { key: 'upper', header: 'Upper bound' },
      ]} data={data?.anomalies ?? []} title="Abandonment rate anomalies, last 15 days (Snowflake ML anomaly detection, trained on the prior 75 days)" />
    </div>
  );
  const liveTab = (
    <div className="space-y-4">
      <h2 className="font-semibold">{isAws ? 'Live interactions: Amazon Data Firehose to S3 to Snowpipe' : 'Live interactions: Snowflake-native simulator'}</h2>
      <p className="text-sm text-slate-600">
        {isAws
          ? 'Simulated contact events are sent to the Firehose stream ph-bpo-contact-center-interactions (aws/publish_interactions.py). Firehose writes batches to S3, and Snowpipe auto-ingest loads them into RAW.LIVE_INTERACTIONS.'
          : 'CALL APP.SIMULATE_INTERACTIONS(n) inserts simulated contact events directly into RAW.LIVE_INTERACTIONS (or resume APP.TASK_SIMULATE_INTERACTIONS for a feed every minute). This simulates an interaction feed; it is not Snowpipe Streaming.'}
        {' '}The alert APP.LIVE_INTERACTION_ALERT logs ABANDONED contacts and emails the on-shift real-time analyst.
      </p>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KPICard title="Interaction events loaded" value={String(data?.liveSummary?.n ?? 'n/a')} />
        <KPICard title="ABANDONED contacts" value={String(data?.liveSummary?.alerts ?? 'n/a')} />
        <KPICard title={isAws ? 'Median send to table lag (s)' : 'Median generated to table lag (s)'} value={String(data?.liveSummary?.medianLagSeconds ?? 'n/a')} />
        <KPICard title="Last load" value={data?.liveSummary?.lastLoaded ?? 'none'} />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Queue' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'wait', header: 'Wait (s)' },
        { key: 'handle', header: 'Handle time (min)' }, { key: 'status', header: 'Status' }, { key: 'loadedAt', header: 'Loaded' },
      ]} data={data?.live ?? []} title="Latest 25 interaction events" />
      <DataTable columns={[
        { key: 'id', header: 'Queue' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'wait', header: 'Wait (s)' },
        { key: 'handle', header: 'Handle time (min)' }, { key: 'hint', header: 'Action hint' },
      ]} data={data?.alerts ?? []} title="Alert log" />
    </div>
  );
  const planning = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <KPICard title="Reforecast Compliance" value={kpiVal('Reforecast Compliance')} />
        <KPICard title="Agent Skill Coverage" value={kpiVal('Agent Skill Coverage')} />
        <KPICard title="Agents In Nesting" value={kpiVal('Agents In Nesting')} />
      </div>
      <Chart data={data?.reforecastRisk ?? []} type="scatter" xKey="compliance" xName="Reforecast compliance"
        yKeys={[{ key: 'missed', name: 'Intervals below service level' }]} yDomain={[0, 'auto']}
        title="Reforecast compliance (%) vs intervals below service level by queue" />
      <p className="text-sm text-slate-600">Synthetic associations are not evidence that intraday reforecasts prevented missed intervals.</p>
      <ActionMemo persona={{ name: 'Jericho Manalastas', role: 'Head of Workforce Management (fictional persona)' }} context={{}}
        onGenerate={async () => {
          const r = await fetch('/api/ask', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ mode: 'memo' }) });
          if (!r.ok) throw new Error('memo failed');
          const j = await r.json();
          return { subject: 'Draft workforce actions (synthetic data, human review required)', body: j.answer, urgency: 'review', actions: [] };
        }} />
      <p role="status" className="text-sm text-slate-600">{isAws ? 'Draft generated by Amazon Bedrock (Claude) through a Snowflake external-access function' : 'Draft generated by Snowflake Cortex AI_COMPLETE (Claude Sonnet 4.5)'}, from the KPI, queue, miss-driver and risk tables only. No notification is sent.</p>
    </div>
  );
  const ai = (
    <div className="space-y-4">
      <p role="status">Answers come from the Cortex Agent APP.CONTACT_CENTER_AGENT. It uses Cortex Analyst over the semantic view APP.CONTACT_CENTER_ANALYTICS for metrics, and Cortex Search over synthetic service-level recovery SOPs for procedures. The generated SQL is shown with each answer.</p>
      <div className="h-[500px]">
        <AskAI title="Ask the contact centre agent" mode="advisor" sampleQuestions={['Which 3 queues have the most intervals below service level?', 'Which queues are high risk this week, and which SOP applies?', 'What is the miss share by miss driver?']}
          onSubmit={async (question) => {
            const r = await fetch('/api/agent', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ question }) });
            if (!r.ok) throw new Error('agent failed');
            const j = await r.json();
            const cites = j.sops?.length ? `\n\nSOPs: ${j.sops.join(', ')}` : '';
            return { answer: `${j.answer}${cites}`, sql: j.sql ?? undefined };
          }} />
      </div>
    </div>
  );
  const architecture = (
    <div className="space-y-4">
      {diagrams.map((d, i) => (
        <div key={d.key} className="space-y-2">
          <h2 className="font-semibold">Architecture: {d.title}{i === 0 ? ' (this deployment)' : ''}</h2>
          <iframe src={d.src} title={`${d.title} architecture diagram`} className="h-[620px] w-full rounded border border-slate-200" />
          <p className="text-sm text-slate-600">Hover a component for details. <a className="underline" href={d.src} target="_blank" rel="noreferrer">Open full screen</a></p>
        </div>
      ))}
      <h2 className="font-semibold">Implementation status</h2>
      <p>Core source: 48 synthetic queues in 6 Philippine cities across 5 lines of business, daily queue observations over 32 half-hour intervals, and agent skill coverage per queue. Curated dynamic tables compute numerator/denominator metrics and are suspended after on-demand initialization.</p>
      <p>Application: Next.js server queries the explicit curated contract. Request time and source observation watermark are separate.</p>
      <p>ML: SNOWFLAKE.ML.CLASSIFICATION service-level miss risk model evaluated on a time-based holdout, plus a 14-day service-level alert FORECAST with prediction intervals.</p>
      <p>ML: ANOMALY_DETECTION flags abandonment rate outliers per queue over the last 15 days.</p>
      <p>AI: Cortex Agent (Cortex Analyst over a semantic view, plus Cortex Search over SOPs) answers questions. The action memo uses {isAws ? 'Amazon Bedrock Claude through an external-access UDF' : 'Cortex AI_COMPLETE (Claude Sonnet 4.5)'}.</p>
      {isAws ? (
        <>
          <p>AWS ingestion: Amazon Data Firehose to S3 to Snowpipe auto-ingest (SQS) into RAW.LIVE_INTERACTIONS, with a Snowflake alert and email on ABANDONED contacts.</p>
          <p>QuickSight: Snowflake DIRECT_QUERY dashboard (daily service-level alerts, missed intervals by queue, service-level miss risk) through a PAT-only service user, with a Q topic.</p>
        </>
      ) : (
        <>
          <p>Ingestion: APP.SIMULATE_INTERACTIONS inserts simulated contact events into RAW.LIVE_INTERACTIONS, with a Snowflake alert and email on ABANDONED contacts. No AWS account is used.</p>
          <p>BI: this SPCS app is the dashboard; natural-language questions go to the Cortex Agent.</p>
        </>
      )}
      <p>Orchestration: the task graph APP.TASK_REFRESH_CURATED, then TASK_RESCORE_RISK, runs on demand. Alerts and tasks stay suspended between demos.</p>
    </div>
  );
  const tabs = [
    { id: 'executive-cockpit', label: 'Executive Cockpit', icon: '', content: executive },
    { id: 'predictive', label: 'Predictive', icon: '', content: predictive },
    { id: 'planning', label: 'Controls', icon: '', content: planning },
    { id: 'live', label: 'Live Interactions', icon: '', content: liveTab },
    { id: 'ask-ai', label: 'Ask AI', icon: '', content: ai },
    { id: 'architecture', label: 'Architecture & Data', icon: '', content: architecture },
  ].map((tab) => ({ ...tab, content: tab.id === 'architecture' ? tab.content : (
    <div className="space-y-4">
      <p className="text-sm text-slate-600">Synthetic demo data for a fictional Philippine BPO contact centre. On-demand snapshots are not live customer operations.</p>
      {loading ? <p role="status">Loading Snowflake data...</p> : error ? (
        <div role="alert" className="rounded border border-red-200 p-4">
          <p>{error}</p>
          <button className="mt-3 rounded border px-3 py-2" onClick={() => setAttempt((value) => value + 1)}>Retry data connection</button>
        </div>
      ) : !data?.entities.length ? <p role="status">No queue observations are available in this snapshot.</p> : (
        <>
          <p className="text-sm">Observation watermark: {data.sourceWatermark ?? 'Unavailable'}. Request time: {data.requestedAt}.</p>
          {(data.stale || data.pipelineBehind) && <p role="status" className="text-amber-700">Stale or lagging snapshot. Refresh the on-demand pipeline before presenting current results.</p>}
          {tab.content}
        </>
      )}
    </div>
  ) }));
  return <AppLayout title="Philippines BPO Contact Center" tabs={tabs} />;
}
