

WITH suspects
AS
(
SELECT * FROM 
perf.performanceCounters
WHERE counter_name ='Page life expectancy'
AND cntr_value < 500
UNION 
SELECT * FROM perf.performanceCounters
WHERE counter_name IN ('Page reads/sec','Page writes/sec')
AND cntr_value > 150
UNION
SELECT * FROM perf.performanceCounters
WHERE counter_name IN('Lazy writes/sec','Memory Grants Outstanding','Memory Grants Pending')
AND cntr_value>0)
SELECT * FROM perf.performanceCounters p
JOIN suspects s ON p.collectionTime=s.collectionTime;










