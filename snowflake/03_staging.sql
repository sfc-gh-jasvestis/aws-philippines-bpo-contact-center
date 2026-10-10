-- Validate the producer contract before building downstream objects.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

EXECUTE IMMEDIATE $$
DECLARE
  violations INTEGER;
  invalid_source EXCEPTION (-20001, 'Synthetic source failed grain or measure validation');
BEGIN
  SELECT COUNT(*) INTO :violations FROM (
    SELECT ENTITY_ID, EVENT_DATE
    FROM RAW.QUEUE_DAILY
    GROUP BY ENTITY_ID, EVENT_DATE HAVING COUNT(*) <> 1
    UNION ALL
    SELECT observation.ENTITY_ID, observation.EVENT_DATE
    FROM RAW.QUEUE_DAILY observation
    LEFT JOIN RAW.QUEUES queue ON queue.ID = observation.ENTITY_ID
    WHERE queue.ID IS NULL OR observation.CONTACT_COUNT < 0
       OR observation.LABOR_COST_PHP < 0
       OR observation.SL_MISS_COUNT < 0 OR observation.SL_MISS_COUNT > observation.SL_ALERT_COUNT
       OR observation.SL_ALERT_COUNT > observation.INTERVAL_COUNT
       OR observation.OVERTIME_CALLOUT > observation.SL_MISS_COUNT
       OR observation.REFORECAST_DONE > observation.REFORECAST_DUE
  );
  IF (violations > 0) THEN
    RAISE invalid_source;
  END IF;
END;
$$;
