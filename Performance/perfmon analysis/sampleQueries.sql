
Select distinct MachineName from dbo.PerformanceCountersAggregation
/*
\\NATORSQLCLUS10
\\NATORSQLCLUS14
*/
GO
Select [ObjectName],[CounterName],[InstanceName],[MinimumValue], [MaximumValue] ,[AvgerageValue]
FROM [dbo].[PerformanceCountersAggregation]
WHERE MachineName='\\NATORSQLCLUS10'  ORDER BY AggregationSetDateTime,objectName,counterName; 
GO
Select [ObjectName],[CounterName],[InstanceName],[MinimumValue], [MaximumValue] ,[AvgerageValue]
FROM [dbo].[PerformanceCountersAggregation]
WHERE MachineName='\\MLDBSQL2K5CL01'  AND Day(AggregationSetDateTime)=28


--relative to
Select g.AggregationSetDateTime,g.AvgerageValue,g2.AvgerageValue, g2.AvgerageValue/g.AvgerageValue as 'Ratio' from dbo.PerformanceCountersAggregation g
Join dbo.PerformanceCountersAggregation g2 on g.AggregationSetDateTime=g2.AggregationSetDateTime
Where g.CounterName='Batch Requests/sec' 
And g2.CounterName='Forwarded Records/sec'
order by g.AggregationSetDateTime


--one counter
Select g.AggregationSetDateTime,g.ObjectName,g.CounterName,g.InstanceName,g.InstanceName,g.AvgerageValue
from dbo.PerformanceCountersAggregation g
Where g.CounterName IN ('Disk Read Bytes/sec','Avg. Disk sec/Read') and MachineName='\\NATORSQLCLUS10'
Order by g.AggregationSetDateTime

Select g.AggregationSetDateTime,g.ObjectName,g.CounterName,g.InstanceName,g.InstanceName,g.AvgerageValue,g.AvgerageValue/1024 'KB/sec'
from dbo.PerformanceCountersAggregation g
Where g.CounterName IN ('Disk Read Bytes/sec') and MachineName='\\NATORSQLCLUS10' and g.InstanceName='2 G:'
Order by g.AggregationSetDateTime


--latency
Select g.AggregationSetDateTime,g.InstanceName,g.AvgerageValue,g.AvgerageValue*1000 as 'latency in ms'
from dbo.PerformanceCountersAggregation g
Where g.CounterName='Avg. Disk sec/Read'

--the last one
Select g.ObjectName,g.CounterName,g.InstanceName,cast(g.MaximumValue as decimal(12,2)) as 'max',cast(g.MinimumValue as decimal(12,2)) as 'min',cast(g.AvgerageValue as decimal(12,2)) as 'Avg'
from dbo.PerformanceCountersAggregation g
Where g.AggregationSetDateTime=(Select max(AggregationSetDateTime) from SQL2K8CL002I0)
Order by ObjectName,CounterName;


--total avg
Select g.ObjectName,g.CounterName,g.InstanceName,cast(Min(g.MinimumValue) as decimal(20,2)) as 'min', cast(Max(g.MaximumValue) as decimal(20,2)) as 'max', cast(Avg(g.AvgerageValue) as decimal(20,2)) as 'avg'
from dbo.PerformanceCountersAggregation g 
Group by g.ObjectName,g.CounterName,g.InstanceName
Order by g.ObjectName,g.CounterName,g.InstanceName;

