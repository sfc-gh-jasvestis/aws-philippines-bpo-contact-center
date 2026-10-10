"""Publish simulated contact-centre interaction events to Amazon Data Firehose (stream <prefix>-interactions).

Firehose batches the records into S3 (interactions/); Snowpipe loads them into RAW.LIVE_INTERACTIONS.
Queue IDs come from RAW.QUEUES (Q-0000..Q-0047). Values are seeded random.
"""
import argparse
import json
import random
import time
from datetime import datetime, timezone


def make_event(rng):
    abandoned = rng.random() < 0.08
    return {'queue_id': f'Q-{rng.randint(0, 47):04d}',
            'event_ts': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3],
            'wait_seconds': round((210 if abandoned else 38) * rng.lognormvariate(0, 0.3), 2),
            'handle_minutes': round((0.4 if abandoned else 7.2) * rng.lognormvariate(0, 0.3), 1),
            'status': 'ABANDONED' if abandoned else 'OK',
            'sent_ms': int(time.time() * 1000)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--region', default='us-west-2')
    ap.add_argument('--prefix', default='ph-bpo-contact-center')
    ap.add_argument('--count', type=int, default=40)
    ap.add_argument('--seed', type=int)
    args = ap.parse_args()
    import boto3
    firehose = boto3.client('firehose', region_name=args.region)
    stream = f'{args.prefix}-interactions'
    rng = random.Random(args.seed)
    records = [{'Data': (json.dumps(make_event(rng)) + '\n').encode()} for _ in range(args.count)]
    for start in range(0, len(records), 500):
        out = firehose.put_record_batch(DeliveryStreamName=stream, Records=records[start:start + 500])
        if out['FailedPutCount']:
            raise RuntimeError(f"{out['FailedPutCount']} records were rejected by Firehose")
    print(f'published {args.count} interaction events to Firehose stream {stream}; S3 delivery buffers up to 60 s')


if __name__ == '__main__':
    main()
