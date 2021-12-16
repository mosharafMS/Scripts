# SQL IO Perf Collector

This script is meant to collect IO performance matrices based on dm_io_virtual_file_stats. 

It's meant to be executed on a job based on timer. It calculate the difference between the different collection times to get the delta and calculate the matrices per sec. 



SQL Agent jobs can run as frequent as 10 seconds which would give the most detailed picture of the performance. However for proactive monitoring or sizing activities in the case of migration, 1 to 5 minutes should be enough. 