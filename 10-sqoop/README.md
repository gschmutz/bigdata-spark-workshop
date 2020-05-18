# Data Movement with Sqoop

In this workshop we will use Apache Sqoop to load data from a relational Database into Hadoop HDFS. 

[Apache Sqoop(TM)](https://sqoop.apache.org/) is a tool designed for efficiently transferring bulk data between Apache] Hadoop and structured data stores such as relational databases. We will be using Sqoop Version 1 as the latest version 2 is not yet widely supported by the different Hadoop distributions. 

Start a bash shell in the `hadoop-client` container.

```
docker exec -ti hadoop-client bash
```

Set the `HADOOP_COMMON_HOME` environment variable

```
export HADOOP_COMMON_HOME=/opt/hadoop-3.1.1/
```

and also the `HADOOP_MAPRED_HOME ` environment variable

```
export HADOOP_MAPRED_HOME=/opt/hadoop-3.1.1
```

Then navigate to the `lib` folder of the Apache Sqoop installation

```
cd /usr/local/sqoop-1.4.7.bin__hadoop-2.6.0/lib
```

and download the PostgreSQL JDBC driver lib

```
curl -L 'http://central.maven.org/maven2/org/postgresql/postgresql/42.2.5/postgresql-42.2.5.jar' -o postgresql-42.2.5.jar
```

This is necessary, as we are going to use Sqoop to import data from the PostgreSQL instance.

### Load the DRIVER table with the `as-textfile` option

Let’s start by importing the `truck` table. From a terminal window, again first open a bash shell in the `hadoop-client` container 

```
docker exec -ti hadoop-client bash
```

and then perform the following Sqoop `import` command

```
sqoop import \
    --connect 'jdbc:postgresql://postgresql:5432/truckdb' \
    --driver org.postgresql.Driver \
    --username truck  \
    --password truck \
    --table driver \
    --fields-terminated-by '\t' \
    --warehouse-dir truck/data
```

It will start a MapReduce job to import the data of the `truck` table into HDFS. By default the `--as-textfile` option is used, which will load the data as tab delimited text file (due to the `--fields-terminated-by` option). You should see an output similar to that:

```
root@hadoop-client:/usr/local/sqoop-1.4.7.bin__hadoop-2.6.0/lib# sqoop import \
>     --connect 'jdbc:postgresql://postgresql:5432/truckdb' \
>     --driver org.postgresql.Driver \
>     --username truck  \
>     --password truck \
>     --table driver \
>     --fields-terminated-by '\t' \
>     --warehouse-dir truck/data
Warning: /usr/local/sqoop/../hbase does not exist! HBase imports will fail.
Please set $HBASE_HOME to the root of your HBase installation.
Warning: /usr/local/sqoop/../hcatalog does not exist! HCatalog jobs will fail.
Please set $HCAT_HOME to the root of your HCatalog installation.
Warning: /usr/local/sqoop/../accumulo does not exist! Accumulo imports will fail.
Please set $ACCUMULO_HOME to the root of your Accumulo installation.
Warning: /usr/local/sqoop/../zookeeper does not exist! Accumulo imports will fail.
Please set $ZOOKEEPER_HOME to the root of your Zookeeper installation.
WARNING: HADOOP_PREFIX has been replaced by HADOOP_HOME. Using value of HADOOP_PREFIX.
/opt/hadoop-3.1.1//libexec/hadoop-functions.sh: line 2393: HADOOP_ORG.APACHE.SQOOP.SQOOP_USER: bad substitution
/opt/hadoop-3.1.1//libexec/hadoop-functions.sh: line 2358: HADOOP_ORG.APACHE.SQOOP.SQOOP_USER: bad substitution
/opt/hadoop-3.1.1//libexec/hadoop-functions.sh: line 2453: HADOOP_ORG.APACHE.SQOOP.SQOOP_OPTS: bad substitution
2019-06-04 06:29:06,099 INFO sqoop.Sqoop: Running Sqoop version: 1.4.7
2019-06-04 06:29:06,131 WARN tool.BaseSqoopTool: Setting your password on the command-line is insecure. Consider using -P instead.
2019-06-04 06:29:06,188 WARN sqoop.ConnFactory: Parameter --driver is set to an explicit driver however appropriate connection manager is not being set (via --connection-manager). Sqoop is going to fall back to org.apache.sqoop.manager.GenericJdbcManager. Please specify explicitly which connection manager should be used next time.
2019-06-04 06:29:06,198 INFO manager.SqlManager: Using default fetchSize of 1000
2019-06-04 06:29:06,198 INFO tool.CodeGenTool: Beginning code generation
2019-06-04 06:29:06,372 INFO manager.SqlManager: Executing SQL statement: SELECT t.* FROM driver AS t WHERE 1=0
2019-06-04 06:29:06,384 INFO manager.SqlManager: Executing SQL statement: SELECT t.* FROM driver AS t WHERE 1=0
2019-06-04 06:29:06,416 INFO orm.CompilationManager: HADOOP_MAPRED_HOME is /opt/hadoop-3.1.1
Note: /tmp/sqoop-root/compile/66c0403cd9eea3c3f46934e0fddd1945/driver.java uses or overrides a deprecated API.
Note: Recompile with -Xlint:deprecation for details.
2019-06-04 06:29:07,916 INFO orm.CompilationManager: Writing jar file: /tmp/sqoop-root/compile/66c0403cd9eea3c3f46934e0fddd1945/driver.jar
2019-06-04 06:29:07,944 INFO mapreduce.ImportJobBase: Beginning import of driver
2019-06-04 06:29:07,945 INFO Configuration.deprecation: mapred.job.tracker is deprecated. Instead, use mapreduce.jobtracker.address
2019-06-04 06:29:08,066 INFO Configuration.deprecation: mapred.jar is deprecated. Instead, use mapreduce.job.jar
2019-06-04 06:29:08,070 INFO manager.SqlManager: Executing SQL statement: SELECT t.* FROM driver AS t WHERE 1=0
2019-06-04 06:29:08,881 INFO Configuration.deprecation: mapred.map.tasks is deprecated. Instead, use mapreduce.job.maps
2019-06-04 06:29:08,989 INFO client.RMProxy: Connecting to ResourceManager at resourcemanager/172.18.0.29:8032
2019-06-04 06:29:09,244 INFO client.AHSProxy: Connecting to Application History server at historyserver/172.18.0.27:10200
2019-06-04 06:29:09,471 INFO mapreduce.JobResourceUploader: Disabling Erasure Coding for path: /tmp/hadoop-yarn/staging/root/.staging/job_1559629440118_0001
2019-06-04 06:29:12,368 INFO db.DBInputFormat: Using read commited transaction isolation
2019-06-04 06:29:12,368 INFO db.DataDrivenDBInputFormat: BoundingValsQuery: SELECT MIN(id), MAX(id) FROM driver
2019-06-04 06:29:12,371 INFO db.IntegerSplitter: Split size: 24; Num splits: 4 from: 1 to: 100
2019-06-04 06:29:12,413 INFO mapreduce.JobSubmitter: number of splits:4
2019-06-04 06:29:12,445 INFO Configuration.deprecation: yarn.resourcemanager.system-metrics-publisher.enabled is deprecated. Instead, use yarn.system-metrics-publisher.enabled
2019-06-04 06:29:12,574 INFO mapreduce.JobSubmitter: Submitting tokens for job: job_1559629440118_0001
2019-06-04 06:29:12,576 INFO mapreduce.JobSubmitter: Executing with tokens: []
2019-06-04 06:29:12,792 INFO conf.Configuration: resource-types.xml not found
2019-06-04 06:29:12,792 INFO resource.ResourceUtils: Unable to find 'resource-types.xml'.
2019-06-04 06:29:13,602 INFO impl.YarnClientImpl: Submitted application application_1559629440118_0001
2019-06-04 06:29:13,647 INFO mapreduce.Job: The url to track the job: http://resourcemanager:8088/proxy/application_1559629440118_0001/
2019-06-04 06:29:13,648 INFO mapreduce.Job: Running job: job_1559629440118_0001
2019-06-04 06:29:20,808 INFO mapreduce.Job: Job job_1559629440118_0001 running in uber mode : false
2019-06-04 06:29:20,810 INFO mapreduce.Job:  map 0% reduce 0%
2019-06-04 06:29:26,903 INFO mapreduce.Job:  map 25% reduce 0%
2019-06-04 06:29:27,909 INFO mapreduce.Job:  map 50% reduce 0%
2019-06-04 06:29:28,913 INFO mapreduce.Job:  map 75% reduce 0%
2019-06-04 06:29:30,921 INFO mapreduce.Job:  map 100% reduce 0%
2019-06-04 06:29:30,928 INFO mapreduce.Job: Job job_1559629440118_0001 completed successfully
2019-06-04 06:29:31,017 INFO mapreduce.Job: Counters: 32
	File System Counters
		FILE: Number of bytes read=0
		FILE: Number of bytes written=906660
		FILE: Number of read operations=0
		FILE: Number of large read operations=0
		FILE: Number of write operations=0
		HDFS: Number of bytes read=385
		HDFS: Number of bytes written=4999
		HDFS: Number of read operations=24
		HDFS: Number of large read operations=0
		HDFS: Number of write operations=8
	Job Counters
		Launched map tasks=4
		Other local map tasks=4
		Total time spent by all maps in occupied slots (ms)=52284
		Total time spent by all reduces in occupied slots (ms)=0
		Total time spent by all map tasks (ms)=13071
		Total vcore-milliseconds taken by all map tasks=13071
		Total megabyte-milliseconds taken by all map tasks=53538816
	Map-Reduce Framework
		Map input records=100
		Map output records=100
		Input split bytes=385
		Spilled Records=0
		Failed Shuffles=0
		Merged Map outputs=0
		GC time elapsed (ms)=313
		CPU time spent (ms)=3520
		Physical memory (bytes) snapshot=1056653312
		Virtual memory (bytes) snapshot=20431679488
		Total committed heap usage (bytes)=972029952
		Peak Map Physical memory (bytes)=305213440
		Peak Map Virtual memory (bytes)=5119254528
	File Input Format Counters
		Bytes Read=0
	File Output Format Counters
		Bytes Written=4999
2019-06-04 06:29:31,023 INFO mapreduce.ImportJobBase: Transferred 4.8818 KB in 22.1338 seconds (225.8536 bytes/sec)
2019-06-04 06:29:31,025 INFO mapreduce.ImportJobBase: Retrieved 100 records.
```

Let's check in HDFS that the data has really been loaded. You can either use **Hue** or the `hadoop fs` command which is also available in the `hadoop-client` container. Sqoop is running as user root, therefore the data in HDFS is stored under `/user/root`.

```
hadoop fs -ls /user/root/truck/data/driver
```

The subfolder `truck/data` is the one provided in the sqoop command and sqoop creates another subfolder for each table, in our case `driver`:

```
root@hadoop-client:/# hadoop fs -ls /user/root/truck/data/driver
WARNING: HADOOP_PREFIX has been replaced by HADOOP_HOME. Using value of HADOOP_PREFIX.
Found 5 items
-rw-r--r--   3 root supergroup          0 2019-06-04 06:29 /user/root/truck/data/driver/_SUCCESS
-rw-r--r--   3 root supergroup       1246 2019-06-04 06:29 /user/root/truck/data/driver/part-m-00000
-rw-r--r--   3 root supergroup       1252 2019-06-04 06:29 /user/root/truck/data/driver/part-m-00001
-rw-r--r--   3 root supergroup       1266 2019-06-04 06:29 /user/root/truck/data/driver/part-m-00002
-rw-r--r--   3 root supergroup       1235 2019-06-04 06:29 /user/root/truck/data/driver/part-m-00003
```

We have loaded the data of one of the tables into HDFS. We used the `as-textfile` option, which is the default. 

Let’s retry it with the `as-avrodatafile` option. 

### Load the `truck` table with the `as-avrodatafile` option

Let’s first clear the data we have loaded by removing the `driver` folder

```
hadoop fs -rm -R /user/root/truck/data/driver
```

In Hue navigate to the `/truck/data` folder and click on drop down icon next to Move to trash and click on Delete forever.

Now perform the sqoop import with the `--as-avrodatafile` option. Additionally, we also use the `--compression-codec` option to compress the data.

```
sqoop import -Dmapreduce.job.user.classpath.first=true \
   --connect 'jdbc:postgresql://postgresql:5432/truckdb' \
   --driver org.postgresql.Driver \
   --username truck \
   --password truck \
   --table driver \
   --compression-codec=snappy \
   --as-avrodatafile \
   --warehouse-dir truck/data
```

Let's again check in HDFS that the data has really been loaded as Avro serialized data.

```
hadoop fs -ls /user/root/truck/data/driver
```

Again there are 4 files, one for each mapper started in parallel

```
root@hadoop-client:/# hadoop fs -ls /user/root/truck/data/driver
WARNING: HADOOP_PREFIX has been replaced by HADOOP_HOME. Using value of HADOOP_PREFIX.
Found 5 items
-rw-r--r--   3 root supergroup          0 2019-06-04 10:52 /user/root/truck/data/driver/_SUCCESS
-rw-r--r--   3 root supergroup       1847 2019-06-04 10:52 /user/root/truck/data/driver/part-m-00000.avro
-rw-r--r--   3 root supergroup       1846 2019-06-04 10:52 /user/root/truck/data/driver/part-m-00001.avro
-rw-r--r--   3 root supergroup       1842 2019-06-04 10:52 /user/root/truck/data/driver/part-m-00002.avro
-rw-r--r--   3 root supergroup       1805 2019-06-04 10:52 /user/root/truck/data/driver/part-m-00003.avro
```

