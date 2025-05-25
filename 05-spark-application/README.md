# Creating and running a self-contained Spark Application

In this workshop we will create a Spark Application to submit to a Spark cluster. The application will perform the logic to create the `refined` layer as seen in [Workshop 4 - Data Reading and Writing using DataFrames](../04-spark-dataframe).

We assume that the **Data Platform** described [here](../01-environment) is running and accessible. 

## Prepare the data, if no longer available

The data needed here has been uploaded in workshop 2 - [Working with MinIO Object Storage](02-object-storage). You can skip this section, if you still have the data available in MinIO. We show both `s3cmd` and the `mc` version of the commands:

Create the flight bucket:

```bash
docker exec -ti awscli s3cmd mb s3://flight-bucket
```

or with `mc`
 
```bash
docker exec -ti minio-mc mc mb minio-1/flight-bucket
```

**Airports:**

```bash
docker exec -ti awscli s3cmd put /data-transfer/airports-data/airports.csv s3://flight-bucket/raw/airports/airports.csv
```

**Flights:**

```bash
docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_4_1.csv s3://flight-bucket/raw/flights/ &&
   docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_4_2.csv s3://flight-bucket/raw/flights/ &&
   docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_5_1.csv s3://flight-bucket/raw/flights/ &&
   docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_5_2.csv s3://flight-bucket/raw/flights/ &&
   docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_5_3.csv s3://flight-bucket/raw/flights/
```

## Create the self-contained Spark Application

To create a Spark application using Python, you use PySpark, the Python API for Apache Spark.

First let's create a folder for the Spark application 

```bash
cd $DATAPLATFORM_HOME
mkdir -p ./data-transfer/app
```

Create a file, e.g. `prep_refined.py` and save it into the `./data-transfer/app` folder

Use Nano editor to edit the file `nano ./data-transfer/app/prep_refined.py` and copy the following code into editor window.

```python
import sys
from random import random

from pyspark.sql import SparkSession
from pyspark.sql.types import *

if __name__ == "__main__":
    """
        Usage: pi [partitions]
    """
    spark = SparkSession\
        .builder\
        .appName("FlighTransform")\
        .getOrCreate()

    airportsRawDF = spark.read.csv("s3a://flight-bucket/raw/airports", \
    			sep=",", inferSchema="true", header="true")
    airportsRawDF.write.json("s3a://flight-bucket/refined/airports")

    flightSchema = """`year` INTEGER, `month` INTEGER, `dayOfMonth` INTEGER,  `dayOfWeek` INTEGER, `depTime` INTEGER, `crsDepTime` INTEGER, `arrTime` INTEGER, `crsArrTime` INTEGER, `uniqueCarrier` STRING, `flightNum` STRING, `tailNum` STRING, `actualElapsedTime` INTEGER,\
                   `crsElapsedTime` INTEGER, `airTime` INTEGER, `arrDelay` INTEGER,`depDelay` INTEGER,`origin` STRING, `destination` STRING, `distance` INTEGER, `taxiIn` INTEGER, `taxiOut` INTEGER, `cancelled` STRING, `cancellationCode` STRING, `diverted` STRING,
                   `carrierDelay` STRING, `weatherDelay` STRING, `nasDelay` STRING, `securityDelay` STRING, `lateAircraftDelay` STRING"""
                   
    flightsRawDF = spark.read.csv("s3a://flight-bucket/raw/flights", \
    			sep=",", inferSchema="false", header="false", schema=flightSchema)

    flightsRawDF.write.partitionBy("year","month").parquet("s3a://flight-bucket/refined/flights")

    spark.stop()
```

Save it by hitting `Ctrl-O` and exit by hitting `Ctrl-X`.

## Run the application against the Spark Cluster using `spark-submit`

Before we submit the application, let's make sure that the `refined` folder does not exists. Otherwise we will get an error when trying to write to the folder. 

```bash
docker exec -ti awscli s3cmd del --recursive s3://flight-bucket/refined
```

Now we can submit it using `spark-submit` CLI, which is part of the `spark-master` docker container. 

```bash
docker exec -it spark-master spark-submit /data-transfer/app/prep_refined.py
```

and you should see the following successful execution

```
ubuntu@ip-172-26-9-12:~/bigdata-spark-workshop/01-environment/docker$ docker exec -it spark-master spark-submit /data-transfer/app/prep_refined.py
:: loading settings :: url = jar:file:/opt/bitnami/spark/jars/ivy-2.5.1.jar!/org/apache/ivy/core/settings/ivysettings.xml
Ivy Default Cache set to: /opt/bitnami/spark/.ivy2/cache
The jars for the packages stored in: /opt/bitnami/spark/.ivy2/jars
org.apache.spark#spark-avro_2.12 added as a dependency
graphframes#graphframes added as a dependency
:: resolving dependencies :: org.apache.spark#spark-submit-parent-03a9b512-7ffd-4483-b715-3935f9656e4d;1.0
	confs: [default]
	found org.apache.spark#spark-avro_2.12;3.5.2 in central
	found org.tukaani#xz;1.9 in central
	found graphframes#graphframes;0.8.4-spark3.5-s_2.12 in spark-packages
	found org.slf4j#slf4j-api;1.7.16 in central
:: resolution report :: resolve 416ms :: artifacts dl 19ms
	:: modules in use:
	graphframes#graphframes;0.8.4-spark3.5-s_2.12 from spark-packages in [default]
	org.apache.spark#spark-avro_2.12;3.5.2 from central in [default]
	org.slf4j#slf4j-api;1.7.16 from central in [default]
	org.tukaani#xz;1.9 from central in [default]
	---------------------------------------------------------------------
	|                  |            modules            ||   artifacts   |
	|       conf       | number| search|dwnlded|evicted|| number|dwnlded|
	---------------------------------------------------------------------
	|      default     |   4   |   0   |   0   |   0   ||   4   |   0   |
	---------------------------------------------------------------------
:: retrieving :: org.apache.spark#spark-submit-parent-03a9b512-7ffd-4483-b715-3935f9656e4d
	confs: [default]
	0 artifacts copied, 4 already retrieved (0kB/17ms)
25/05/25 18:11:15 WARN NativeCodeLoader: Unable to load native-hadoop library for your platform... using builtin-java classes where applicable
25/05/25 18:11:16 INFO SparkContext: Running Spark version 3.5.3
25/05/25 18:11:16 INFO SparkContext: OS info Linux, 6.8.0-1029-aws, amd64
25/05/25 18:11:16 INFO SparkContext: Java version 17.0.13
25/05/25 18:11:16 INFO ResourceUtils: ==============================================================
25/05/25 18:11:16 INFO ResourceUtils: No custom resources configured for spark.driver.
25/05/25 18:11:16 INFO ResourceUtils: ==============================================================
25/05/25 18:11:16 INFO SparkContext: Submitted application: FlighTransform
25/05/25 18:11:16 INFO ResourceProfile: Default ResourceProfile created, executor resources: Map(cores -> name: cores, amount: 1, script: , vendor: , memory -> name: memory, amount: 2048, script: , vendor: , offHeap -> name: offHeap, amount: 0, script: , vendor: ), task resources: Map(cpus -> name: cpus, amount: 1.0)
25/05/25 18:11:16 INFO ResourceProfile: Limiting resource is cpu
25/05/25 18:11:16 INFO ResourceProfileManager: Added ResourceProfile id: 0
25/05/25 18:11:16 INFO SecurityManager: Changing view acls to: spark
25/05/25 18:11:16 INFO SecurityManager: Changing modify acls to: spark
25/05/25 18:11:16 INFO SecurityManager: Changing view acls groups to:
25/05/25 18:11:16 INFO SecurityManager: Changing modify acls groups to:
25/05/25 18:11:16 INFO SecurityManager: SecurityManager: authentication disabled; ui acls disabled; users with view permissions: spark; groups with view permissions: EMPTY; users with modify permissions: spark; groups with modify permissions: EMPTY
25/05/25 18:11:16 INFO Utils: Successfully started service 'sparkDriver' on port 39771.
25/05/25 18:11:16 INFO SparkEnv: Registering MapOutputTracker
25/05/25 18:11:16 INFO SparkEnv: Registering BlockManagerMaster
25/05/25 18:11:16 INFO BlockManagerMasterEndpoint: Using org.apache.spark.storage.DefaultTopologyMapper for getting topology information
25/05/25 18:11:16 INFO BlockManagerMasterEndpoint: BlockManagerMasterEndpoint up
25/05/25 18:11:16 INFO SparkEnv: Registering BlockManagerMasterHeartbeat
25/05/25 18:11:16 INFO DiskBlockManager: Created local directory at /tmp/blockmgr-1fef2395-68e3-4ed8-9f2c-8437e8044a3e
25/05/25 18:11:16 INFO MemoryStore: MemoryStore started with capacity 434.4 MiB
25/05/25 18:11:16 INFO SparkEnv: Registering OutputCommitCoordinator
25/05/25 18:11:17 INFO JettyUtils: Start Jetty 0.0.0.0:4040 for SparkUI
25/05/25 18:11:17 INFO Utils: Successfully started service 'SparkUI' on port 4040.
25/05/25 18:11:17 INFO SparkContext: Added JAR file:///opt/bitnami/spark/jars/delta-spark_2.12-3.2.1.jar at spark://spark-master:39771/jars/delta-spark_2.12-3.2.1.jar with timestamp 1748196676399
25/05/25 18:11:17 INFO SparkContext: Added JAR file:///opt/bitnami/spark/jars/delta-storage-3.2.1.jar at spark://spark-master:39771/jars/delta-storage-3.2.1.jar with timestamp 1748196676399
25/05/25 18:11:17 INFO SparkContext: Added JAR file:///opt/bitnami/spark/.ivy2/jars/org.apache.spark_spark-avro_2.12-3.5.2.jar at spark://spark-master:39771/jars/org.apache.spark_spark-avro_2.12-3.5.2.jar with timestamp 1748196676399
25/05/25 18:11:17 INFO SparkContext: Added JAR file:///opt/bitnami/spark/.ivy2/jars/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar at spark://spark-master:39771/jars/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar with timestamp 1748196676399
25/05/25 18:11:17 INFO SparkContext: Added JAR file:///opt/bitnami/spark/.ivy2/jars/org.tukaani_xz-1.9.jar at spark://spark-master:39771/jars/org.tukaani_xz-1.9.jar with timestamp 1748196676399
25/05/25 18:11:17 INFO SparkContext: Added JAR file:///opt/bitnami/spark/.ivy2/jars/org.slf4j_slf4j-api-1.7.16.jar at spark://spark-master:39771/jars/org.slf4j_slf4j-api-1.7.16.jar with timestamp 1748196676399
25/05/25 18:11:17 INFO SparkContext: Added file file:///opt/bitnami/spark/.ivy2/jars/org.apache.spark_spark-avro_2.12-3.5.2.jar at file:///opt/bitnami/spark/.ivy2/jars/org.apache.spark_spark-avro_2.12-3.5.2.jar with timestamp 1748196676399
25/05/25 18:11:17 INFO Utils: Copying /opt/bitnami/spark/.ivy2/jars/org.apache.spark_spark-avro_2.12-3.5.2.jar to /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/org.apache.spark_spark-avro_2.12-3.5.2.jar
25/05/25 18:11:17 INFO SparkContext: Added file file:///opt/bitnami/spark/.ivy2/jars/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar at file:///opt/bitnami/spark/.ivy2/jars/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar with timestamp 1748196676399
25/05/25 18:11:17 INFO Utils: Copying /opt/bitnami/spark/.ivy2/jars/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar to /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar
25/05/25 18:11:17 INFO SparkContext: Added file file:///opt/bitnami/spark/.ivy2/jars/org.tukaani_xz-1.9.jar at file:///opt/bitnami/spark/.ivy2/jars/org.tukaani_xz-1.9.jar with timestamp 1748196676399
25/05/25 18:11:17 INFO Utils: Copying /opt/bitnami/spark/.ivy2/jars/org.tukaani_xz-1.9.jar to /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/org.tukaani_xz-1.9.jar
25/05/25 18:11:17 INFO SparkContext: Added file file:///opt/bitnami/spark/.ivy2/jars/org.slf4j_slf4j-api-1.7.16.jar at file:///opt/bitnami/spark/.ivy2/jars/org.slf4j_slf4j-api-1.7.16.jar with timestamp 1748196676399
25/05/25 18:11:17 INFO Utils: Copying /opt/bitnami/spark/.ivy2/jars/org.slf4j_slf4j-api-1.7.16.jar to /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/org.slf4j_slf4j-api-1.7.16.jar
25/05/25 18:11:17 INFO Executor: Starting executor ID driver on host spark-master
25/05/25 18:11:17 INFO Executor: OS info Linux, 6.8.0-1029-aws, amd64
25/05/25 18:11:17 INFO Executor: Java version 17.0.13
25/05/25 18:11:17 INFO Executor: Starting executor with user classpath (userClassPathFirst = false): ''
25/05/25 18:11:17 INFO Executor: Created or updated repl class loader org.apache.spark.util.MutableURLClassLoader@289ada1 for default.
25/05/25 18:11:17 INFO Executor: Fetching file:///opt/bitnami/spark/.ivy2/jars/org.apache.spark_spark-avro_2.12-3.5.2.jar with timestamp 1748196676399
25/05/25 18:11:17 INFO Utils: /opt/bitnami/spark/.ivy2/jars/org.apache.spark_spark-avro_2.12-3.5.2.jar has been previously copied to /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/org.apache.spark_spark-avro_2.12-3.5.2.jar
25/05/25 18:11:17 INFO Executor: Fetching file:///opt/bitnami/spark/.ivy2/jars/org.tukaani_xz-1.9.jar with timestamp 1748196676399
25/05/25 18:11:17 INFO Utils: /opt/bitnami/spark/.ivy2/jars/org.tukaani_xz-1.9.jar has been previously copied to /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/org.tukaani_xz-1.9.jar
25/05/25 18:11:17 INFO Executor: Fetching file:///opt/bitnami/spark/.ivy2/jars/org.slf4j_slf4j-api-1.7.16.jar with timestamp 1748196676399
25/05/25 18:11:17 INFO Utils: /opt/bitnami/spark/.ivy2/jars/org.slf4j_slf4j-api-1.7.16.jar has been previously copied to /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/org.slf4j_slf4j-api-1.7.16.jar
25/05/25 18:11:17 INFO Executor: Fetching file:///opt/bitnami/spark/.ivy2/jars/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar with timestamp 1748196676399
25/05/25 18:11:17 INFO Utils: /opt/bitnami/spark/.ivy2/jars/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar has been previously copied to /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar
25/05/25 18:11:17 INFO Executor: Fetching spark://spark-master:39771/jars/delta-spark_2.12-3.2.1.jar with timestamp 1748196676399
25/05/25 18:11:17 INFO TransportClientFactory: Successfully created connection to spark-master/172.18.0.12:39771 after 37 ms (0 ms spent in bootstraps)
25/05/25 18:11:17 INFO Utils: Fetching spark://spark-master:39771/jars/delta-spark_2.12-3.2.1.jar to /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/fetchFileTemp16646556082084900041.tmp
25/05/25 18:11:17 INFO Executor: Adding file:/tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/delta-spark_2.12-3.2.1.jar to class loader default
25/05/25 18:11:17 INFO Executor: Fetching spark://spark-master:39771/jars/delta-storage-3.2.1.jar with timestamp 1748196676399
25/05/25 18:11:17 INFO Utils: Fetching spark://spark-master:39771/jars/delta-storage-3.2.1.jar to /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/fetchFileTemp9996957108253092008.tmp
25/05/25 18:11:17 INFO Executor: Adding file:/tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/delta-storage-3.2.1.jar to class loader default
25/05/25 18:11:17 INFO Executor: Fetching spark://spark-master:39771/jars/org.apache.spark_spark-avro_2.12-3.5.2.jar with timestamp 1748196676399
25/05/25 18:11:17 INFO Utils: Fetching spark://spark-master:39771/jars/org.apache.spark_spark-avro_2.12-3.5.2.jar to /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/fetchFileTemp3186712689728211025.tmp
25/05/25 18:11:17 INFO Utils: /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/fetchFileTemp3186712689728211025.tmp has been previously copied to /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/org.apache.spark_spark-avro_2.12-3.5.2.jar
25/05/25 18:11:17 INFO Executor: Adding file:/tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/org.apache.spark_spark-avro_2.12-3.5.2.jar to class loader default
25/05/25 18:11:17 INFO Executor: Fetching spark://spark-master:39771/jars/org.tukaani_xz-1.9.jar with timestamp 1748196676399
25/05/25 18:11:17 INFO Utils: Fetching spark://spark-master:39771/jars/org.tukaani_xz-1.9.jar to /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/fetchFileTemp1345242411864166845.tmp
25/05/25 18:11:17 INFO Utils: /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/fetchFileTemp1345242411864166845.tmp has been previously copied to /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/org.tukaani_xz-1.9.jar
25/05/25 18:11:17 INFO Executor: Adding file:/tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/org.tukaani_xz-1.9.jar to class loader default
25/05/25 18:11:17 INFO Executor: Fetching spark://spark-master:39771/jars/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar with timestamp 1748196676399
25/05/25 18:11:17 INFO Utils: Fetching spark://spark-master:39771/jars/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar to /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/fetchFileTemp1031959512200803401.tmp
25/05/25 18:11:17 INFO Utils: /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/fetchFileTemp1031959512200803401.tmp has been previously copied to /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar
25/05/25 18:11:17 INFO Executor: Adding file:/tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar to class loader default
25/05/25 18:11:17 INFO Executor: Fetching spark://spark-master:39771/jars/org.slf4j_slf4j-api-1.7.16.jar with timestamp 1748196676399
25/05/25 18:11:17 INFO Utils: Fetching spark://spark-master:39771/jars/org.slf4j_slf4j-api-1.7.16.jar to /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/fetchFileTemp17074746635552248034.tmp
25/05/25 18:11:17 INFO Utils: /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/fetchFileTemp17074746635552248034.tmp has been previously copied to /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/org.slf4j_slf4j-api-1.7.16.jar
25/05/25 18:11:17 INFO Executor: Adding file:/tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/userFiles-5ab4bd23-bf31-424b-9bb4-824b1f871204/org.slf4j_slf4j-api-1.7.16.jar to class loader default
25/05/25 18:11:17 INFO Utils: Successfully started service 'org.apache.spark.network.netty.NettyBlockTransferService' on port 40531.
25/05/25 18:11:17 INFO NettyBlockTransferService: Server created on spark-master:40531
25/05/25 18:11:17 INFO BlockManager: Using org.apache.spark.storage.RandomBlockReplicationPolicy for block replication policy
25/05/25 18:11:17 INFO BlockManagerMaster: Registering BlockManager BlockManagerId(driver, spark-master, 40531, None)
25/05/25 18:11:17 INFO BlockManagerMasterEndpoint: Registering block manager spark-master:40531 with 434.4 MiB RAM, BlockManagerId(driver, spark-master, 40531, None)
25/05/25 18:11:17 INFO BlockManagerMaster: Registered BlockManager BlockManagerId(driver, spark-master, 40531, None)
25/05/25 18:11:17 INFO BlockManager: Initialized BlockManager: BlockManagerId(driver, spark-master, 40531, None)
25/05/25 18:11:17 INFO SingleEventLogFileWriter: Logging events to file:/var/log/spark/logs/local-1748196677365.inprogress
25/05/25 18:11:18 INFO SharedState: Setting hive.metastore.warehouse.dir ('null') to the value of spark.sql.warehouse.dir.
25/05/25 18:11:18 WARN MetricsConfig: Cannot locate configuration: tried hadoop-metrics2-s3a-file-system.properties,hadoop-metrics2.properties
25/05/25 18:11:18 INFO MetricsSystemImpl: Scheduled Metric snapshot period at 10 second(s).
25/05/25 18:11:18 INFO MetricsSystemImpl: s3a-file-system metrics system started
25/05/25 18:11:19 INFO SharedState: Warehouse path is 's3a://admin-bucket/hive/warehouse'.
25/05/25 18:11:20 INFO InMemoryFileIndex: It took 76 ms to list leaf files for 1 paths.
25/05/25 18:11:20 INFO InMemoryFileIndex: It took 25 ms to list leaf files for 1 paths.
25/05/25 18:11:24 INFO FileSourceStrategy: Pushed Filters:
25/05/25 18:11:24 INFO FileSourceStrategy: Post-Scan Filters: (length(trim(value#0, None)) > 0)
25/05/25 18:11:24 INFO CodeGenerator: Code generated in 410.298829 ms
25/05/25 18:11:24 INFO MemoryStore: Block broadcast_0 stored as values in memory (estimated size 207.0 KiB, free 434.2 MiB)
25/05/25 18:11:25 INFO MemoryStore: Block broadcast_0_piece0 stored as bytes in memory (estimated size 36.6 KiB, free 434.2 MiB)
25/05/25 18:11:25 INFO BlockManagerInfo: Added broadcast_0_piece0 in memory on spark-master:40531 (size: 36.6 KiB, free: 434.4 MiB)
25/05/25 18:11:25 INFO SparkContext: Created broadcast 0 from csv at NativeMethodAccessorImpl.java:0
25/05/25 18:11:25 INFO FileSourceScanExec: Planning scan with bin packing, max size: 4194304 bytes, open cost is considered as scanning 4194304 bytes.
25/05/25 18:11:25 INFO SparkContext: Starting job: csv at NativeMethodAccessorImpl.java:0
25/05/25 18:11:25 INFO DAGScheduler: Got job 0 (csv at NativeMethodAccessorImpl.java:0) with 1 output partitions
25/05/25 18:11:25 INFO DAGScheduler: Final stage: ResultStage 0 (csv at NativeMethodAccessorImpl.java:0)
25/05/25 18:11:25 INFO DAGScheduler: Parents of final stage: List()
25/05/25 18:11:25 INFO DAGScheduler: Missing parents: List()
25/05/25 18:11:25 INFO DAGScheduler: Submitting ResultStage 0 (MapPartitionsRDD[3] at csv at NativeMethodAccessorImpl.java:0), which has no missing parents
25/05/25 18:11:25 INFO MemoryStore: Block broadcast_1 stored as values in memory (estimated size 13.5 KiB, free 434.1 MiB)
25/05/25 18:11:25 INFO MemoryStore: Block broadcast_1_piece0 stored as bytes in memory (estimated size 6.4 KiB, free 434.1 MiB)
25/05/25 18:11:25 INFO BlockManagerInfo: Added broadcast_1_piece0 in memory on spark-master:40531 (size: 6.4 KiB, free: 434.4 MiB)
25/05/25 18:11:25 INFO SparkContext: Created broadcast 1 from broadcast at DAGScheduler.scala:1585
25/05/25 18:11:25 INFO DAGScheduler: Submitting 1 missing tasks from ResultStage 0 (MapPartitionsRDD[3] at csv at NativeMethodAccessorImpl.java:0) (first 15 tasks are for partitions Vector(0))
25/05/25 18:11:25 INFO TaskSchedulerImpl: Adding task set 0.0 with 1 tasks resource profile 0
25/05/25 18:11:25 INFO TaskSetManager: Starting task 0.0 in stage 0.0 (TID 0) (spark-master, executor driver, partition 0, PROCESS_LOCAL, 10712 bytes)
25/05/25 18:11:25 INFO Executor: Running task 0.0 in stage 0.0 (TID 0)
25/05/25 18:11:26 INFO CodeGenerator: Code generated in 34.728164 ms
25/05/25 18:11:26 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/airports/airports.csv, range: 0-4194304, partition values: [empty row]
25/05/25 18:11:26 INFO CodeGenerator: Code generated in 29.638181 ms
25/05/25 18:11:26 INFO Executor: Finished task 0.0 in stage 0.0 (TID 0). 1811 bytes result sent to driver
25/05/25 18:11:26 INFO TaskSetManager: Finished task 0.0 in stage 0.0 (TID 0) in 780 ms on spark-master (executor driver) (1/1)
25/05/25 18:11:26 INFO TaskSchedulerImpl: Removed TaskSet 0.0, whose tasks have all completed, from pool
25/05/25 18:11:26 INFO DAGScheduler: ResultStage 0 (csv at NativeMethodAccessorImpl.java:0) finished in 1.059 s
25/05/25 18:11:26 INFO DAGScheduler: Job 0 is finished. Cancelling potential speculative or zombie tasks for this job
25/05/25 18:11:26 INFO TaskSchedulerImpl: Killing all running tasks in stage 0: Stage finished
25/05/25 18:11:26 INFO DAGScheduler: Job 0 finished: csv at NativeMethodAccessorImpl.java:0, took 1.190291 s
25/05/25 18:11:26 INFO CodeGenerator: Code generated in 29.09109 ms
25/05/25 18:11:26 INFO BlockManagerInfo: Removed broadcast_1_piece0 on spark-master:40531 in memory (size: 6.4 KiB, free: 434.4 MiB)
25/05/25 18:11:26 INFO FileSourceStrategy: Pushed Filters:
25/05/25 18:11:26 INFO FileSourceStrategy: Post-Scan Filters:
25/05/25 18:11:26 INFO MemoryStore: Block broadcast_2 stored as values in memory (estimated size 207.0 KiB, free 434.0 MiB)
25/05/25 18:11:26 INFO MemoryStore: Block broadcast_2_piece0 stored as bytes in memory (estimated size 36.6 KiB, free 433.9 MiB)
25/05/25 18:11:26 INFO BlockManagerInfo: Added broadcast_2_piece0 in memory on spark-master:40531 (size: 36.6 KiB, free: 434.3 MiB)
25/05/25 18:11:26 INFO SparkContext: Created broadcast 2 from csv at NativeMethodAccessorImpl.java:0
25/05/25 18:11:26 INFO FileSourceScanExec: Planning scan with bin packing, max size: 4194304 bytes, open cost is considered as scanning 4194304 bytes.
25/05/25 18:11:26 INFO SparkContext: Starting job: csv at NativeMethodAccessorImpl.java:0
25/05/25 18:11:26 INFO DAGScheduler: Got job 1 (csv at NativeMethodAccessorImpl.java:0) with 3 output partitions
25/05/25 18:11:26 INFO DAGScheduler: Final stage: ResultStage 1 (csv at NativeMethodAccessorImpl.java:0)
25/05/25 18:11:26 INFO DAGScheduler: Parents of final stage: List()
25/05/25 18:11:26 INFO DAGScheduler: Missing parents: List()
25/05/25 18:11:26 INFO DAGScheduler: Submitting ResultStage 1 (MapPartitionsRDD[9] at csv at NativeMethodAccessorImpl.java:0), which has no missing parents
25/05/25 18:11:27 INFO MemoryStore: Block broadcast_3 stored as values in memory (estimated size 31.2 KiB, free 433.9 MiB)
25/05/25 18:11:27 INFO MemoryStore: Block broadcast_3_piece0 stored as bytes in memory (estimated size 13.9 KiB, free 433.9 MiB)
25/05/25 18:11:27 INFO BlockManagerInfo: Added broadcast_3_piece0 in memory on spark-master:40531 (size: 13.9 KiB, free: 434.3 MiB)
25/05/25 18:11:27 INFO SparkContext: Created broadcast 3 from broadcast at DAGScheduler.scala:1585
25/05/25 18:11:27 INFO DAGScheduler: Submitting 3 missing tasks from ResultStage 1 (MapPartitionsRDD[9] at csv at NativeMethodAccessorImpl.java:0) (first 15 tasks are for partitions Vector(0, 1, 2))
25/05/25 18:11:27 INFO TaskSchedulerImpl: Adding task set 1.0 with 3 tasks resource profile 0
25/05/25 18:11:27 INFO TaskSetManager: Starting task 0.0 in stage 1.0 (TID 1) (spark-master, executor driver, partition 0, PROCESS_LOCAL, 10712 bytes)
25/05/25 18:11:27 INFO TaskSetManager: Starting task 1.0 in stage 1.0 (TID 2) (spark-master, executor driver, partition 1, PROCESS_LOCAL, 10712 bytes)
25/05/25 18:11:27 INFO TaskSetManager: Starting task 2.0 in stage 1.0 (TID 3) (spark-master, executor driver, partition 2, PROCESS_LOCAL, 10712 bytes)
25/05/25 18:11:27 INFO Executor: Running task 0.0 in stage 1.0 (TID 1)
25/05/25 18:11:27 INFO Executor: Running task 2.0 in stage 1.0 (TID 3)
25/05/25 18:11:27 INFO Executor: Running task 1.0 in stage 1.0 (TID 2)
25/05/25 18:11:27 INFO CodeGenerator: Code generated in 23.37357 ms
25/05/25 18:11:27 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/airports/airports.csv, range: 4194304-8388608, partition values: [empty row]
25/05/25 18:11:27 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/airports/airports.csv, range: 8388608-11879081, partition values: [empty row]
25/05/25 18:11:27 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/airports/airports.csv, range: 0-4194304, partition values: [empty row]
25/05/25 18:11:27 INFO BlockManagerInfo: Removed broadcast_0_piece0 on spark-master:40531 in memory (size: 36.6 KiB, free: 434.4 MiB)
25/05/25 18:11:28 INFO Executor: Finished task 0.0 in stage 1.0 (TID 1). 1787 bytes result sent to driver
25/05/25 18:11:28 INFO TaskSetManager: Finished task 0.0 in stage 1.0 (TID 1) in 1397 ms on spark-master (executor driver) (1/3)
25/05/25 18:11:28 INFO Executor: Finished task 2.0 in stage 1.0 (TID 3). 1744 bytes result sent to driver
25/05/25 18:11:28 INFO TaskSetManager: Finished task 2.0 in stage 1.0 (TID 3) in 1417 ms on spark-master (executor driver) (2/3)
25/05/25 18:11:28 INFO Executor: Finished task 1.0 in stage 1.0 (TID 2). 1744 bytes result sent to driver
25/05/25 18:11:28 INFO TaskSetManager: Finished task 1.0 in stage 1.0 (TID 2) in 1542 ms on spark-master (executor driver) (3/3)
25/05/25 18:11:28 INFO TaskSchedulerImpl: Removed TaskSet 1.0, whose tasks have all completed, from pool
25/05/25 18:11:28 INFO DAGScheduler: ResultStage 1 (csv at NativeMethodAccessorImpl.java:0) finished in 1.634 s
25/05/25 18:11:28 INFO DAGScheduler: Job 1 is finished. Cancelling potential speculative or zombie tasks for this job
25/05/25 18:11:28 INFO TaskSchedulerImpl: Killing all running tasks in stage 1: Stage finished
25/05/25 18:11:28 INFO DAGScheduler: Job 1 finished: csv at NativeMethodAccessorImpl.java:0, took 1.657663 s
25/05/25 18:11:28 INFO FileSourceStrategy: Pushed Filters:
25/05/25 18:11:28 INFO FileSourceStrategy: Post-Scan Filters:
25/05/25 18:11:28 INFO BlockManagerInfo: Removed broadcast_3_piece0 on spark-master:40531 in memory (size: 13.9 KiB, free: 434.4 MiB)
25/05/25 18:11:28 WARN AbstractS3ACommitterFactory: Using standard FileOutputCommitter to commit work. This is slow and potentially unsafe.
25/05/25 18:11:28 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 18:11:28 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 18:11:28 INFO AbstractS3ACommitterFactory: Using Committer FileOutputCommitter{PathOutputCommitter{context=TaskAttemptContextImpl{JobContextImpl{jobId=job_202505251811286115167568917474432_0000}; taskId=attempt_202505251811286115167568917474432_0000_m_000000_0, status=''}; org.apache.hadoop.mapreduce.lib.output.FileOutputCommitter@577222e6}; outputPath=s3a://flight-bucket/refined/airports, workPath=s3a://flight-bucket/refined/airports/_temporary/0/_temporary/attempt_202505251811286115167568917474432_0000_m_000000_0, algorithmVersion=1, skipCleanup=false, ignoreCleanupFailures=false} for s3a://flight-bucket/refined/airports
25/05/25 18:11:28 INFO SQLHadoopMapReduceCommitProtocol: Using output committer class org.apache.hadoop.mapreduce.lib.output.FileOutputCommitter
25/05/25 18:11:29 INFO MemoryStore: Block broadcast_4 stored as values in memory (estimated size 206.9 KiB, free 434.0 MiB)
25/05/25 18:11:29 INFO MemoryStore: Block broadcast_4_piece0 stored as bytes in memory (estimated size 36.5 KiB, free 433.9 MiB)
25/05/25 18:11:29 INFO BlockManagerInfo: Added broadcast_4_piece0 in memory on spark-master:40531 (size: 36.5 KiB, free: 434.3 MiB)
25/05/25 18:11:29 INFO SparkContext: Created broadcast 4 from json at NativeMethodAccessorImpl.java:0
25/05/25 18:11:29 INFO FileSourceScanExec: Planning scan with bin packing, max size: 4194304 bytes, open cost is considered as scanning 4194304 bytes.
25/05/25 18:11:29 INFO SparkContext: Starting job: json at NativeMethodAccessorImpl.java:0
25/05/25 18:11:29 INFO DAGScheduler: Got job 2 (json at NativeMethodAccessorImpl.java:0) with 3 output partitions
25/05/25 18:11:29 INFO DAGScheduler: Final stage: ResultStage 2 (json at NativeMethodAccessorImpl.java:0)
25/05/25 18:11:29 INFO DAGScheduler: Parents of final stage: List()
25/05/25 18:11:29 INFO DAGScheduler: Missing parents: List()
25/05/25 18:11:29 INFO DAGScheduler: Submitting ResultStage 2 (MapPartitionsRDD[12] at json at NativeMethodAccessorImpl.java:0), which has no missing parents
25/05/25 18:11:29 INFO MemoryStore: Block broadcast_5 stored as values in memory (estimated size 225.3 KiB, free 433.7 MiB)
25/05/25 18:11:29 INFO MemoryStore: Block broadcast_5_piece0 stored as bytes in memory (estimated size 81.3 KiB, free 433.6 MiB)
25/05/25 18:11:29 INFO BlockManagerInfo: Added broadcast_5_piece0 in memory on spark-master:40531 (size: 81.3 KiB, free: 434.2 MiB)
25/05/25 18:11:29 INFO SparkContext: Created broadcast 5 from broadcast at DAGScheduler.scala:1585
25/05/25 18:11:29 INFO DAGScheduler: Submitting 3 missing tasks from ResultStage 2 (MapPartitionsRDD[12] at json at NativeMethodAccessorImpl.java:0) (first 15 tasks are for partitions Vector(0, 1, 2))
25/05/25 18:11:29 INFO TaskSchedulerImpl: Adding task set 2.0 with 3 tasks resource profile 0
25/05/25 18:11:29 INFO TaskSetManager: Starting task 0.0 in stage 2.0 (TID 4) (spark-master, executor driver, partition 0, PROCESS_LOCAL, 10712 bytes)
25/05/25 18:11:29 INFO TaskSetManager: Starting task 1.0 in stage 2.0 (TID 5) (spark-master, executor driver, partition 1, PROCESS_LOCAL, 10712 bytes)
25/05/25 18:11:29 INFO TaskSetManager: Starting task 2.0 in stage 2.0 (TID 6) (spark-master, executor driver, partition 2, PROCESS_LOCAL, 10712 bytes)
25/05/25 18:11:29 INFO Executor: Running task 2.0 in stage 2.0 (TID 6)
25/05/25 18:11:29 INFO Executor: Running task 1.0 in stage 2.0 (TID 5)
25/05/25 18:11:29 INFO Executor: Running task 0.0 in stage 2.0 (TID 4)
25/05/25 18:11:29 WARN AbstractS3ACommitterFactory: Using standard FileOutputCommitter to commit work. This is slow and potentially unsafe.
25/05/25 18:11:29 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 18:11:29 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 18:11:29 WARN AbstractS3ACommitterFactory: Using standard FileOutputCommitter to commit work. This is slow and potentially unsafe.
25/05/25 18:11:29 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 18:11:29 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 18:11:29 INFO AbstractS3ACommitterFactory: Using Committer FileOutputCommitter{PathOutputCommitter{context=TaskAttemptContextImpl{JobContextImpl{jobId=job_202505251811299023971561298924095_0002}; taskId=attempt_202505251811299023971561298924095_0002_m_000000_4, status=''}; org.apache.hadoop.mapreduce.lib.output.FileOutputCommitter@5d0011a9}; outputPath=s3a://flight-bucket/refined/airports, workPath=s3a://flight-bucket/refined/airports/_temporary/0/_temporary/attempt_202505251811299023971561298924095_0002_m_000000_4, algorithmVersion=1, skipCleanup=false, ignoreCleanupFailures=false} for s3a://flight-bucket/refined/airports
25/05/25 18:11:29 INFO SQLHadoopMapReduceCommitProtocol: Using output committer class org.apache.hadoop.mapreduce.lib.output.FileOutputCommitter
25/05/25 18:11:29 WARN AbstractS3ACommitterFactory: Using standard FileOutputCommitter to commit work. This is slow and potentially unsafe.
25/05/25 18:11:29 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 18:11:29 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 18:11:29 INFO AbstractS3ACommitterFactory: Using Committer FileOutputCommitter{PathOutputCommitter{context=TaskAttemptContextImpl{JobContextImpl{jobId=job_202505251811299023971561298924095_0002}; taskId=attempt_202505251811299023971561298924095_0002_m_000002_6, status=''}; org.apache.hadoop.mapreduce.lib.output.FileOutputCommitter@5c3b6526}; outputPath=s3a://flight-bucket/refined/airports, workPath=s3a://flight-bucket/refined/airports/_temporary/0/_temporary/attempt_202505251811299023971561298924095_0002_m_000002_6, algorithmVersion=1, skipCleanup=false, ignoreCleanupFailures=false} for s3a://flight-bucket/refined/airports
25/05/25 18:11:29 INFO SQLHadoopMapReduceCommitProtocol: Using output committer class org.apache.hadoop.mapreduce.lib.output.FileOutputCommitter
25/05/25 18:11:29 INFO AbstractS3ACommitterFactory: Using Committer FileOutputCommitter{PathOutputCommitter{context=TaskAttemptContextImpl{JobContextImpl{jobId=job_202505251811299023971561298924095_0002}; taskId=attempt_202505251811299023971561298924095_0002_m_000001_5, status=''}; org.apache.hadoop.mapreduce.lib.output.FileOutputCommitter@75924c45}; outputPath=s3a://flight-bucket/refined/airports, workPath=s3a://flight-bucket/refined/airports/_temporary/0/_temporary/attempt_202505251811299023971561298924095_0002_m_000001_5, algorithmVersion=1, skipCleanup=false, ignoreCleanupFailures=false} for s3a://flight-bucket/refined/airports
25/05/25 18:11:29 INFO SQLHadoopMapReduceCommitProtocol: Using output committer class org.apache.hadoop.mapreduce.lib.output.FileOutputCommitter
25/05/25 18:11:29 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/airports/airports.csv, range: 4194304-8388608, partition values: [empty row]
25/05/25 18:11:29 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/airports/airports.csv, range: 8388608-11879081, partition values: [empty row]
25/05/25 18:11:29 INFO CodeGenerator: Code generated in 40.100209 ms
25/05/25 18:11:29 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/airports/airports.csv, range: 0-4194304, partition values: [empty row]
25/05/25 18:11:31 INFO FileOutputCommitter: Saved output of task 'attempt_202505251811299023971561298924095_0002_m_000002_6' to s3a://flight-bucket/refined/airports/_temporary/0/task_202505251811299023971561298924095_0002_m_000002
25/05/25 18:11:31 INFO SparkHadoopMapRedUtil: attempt_202505251811299023971561298924095_0002_m_000002_6: Committed. Elapsed time: 257 ms.
25/05/25 18:11:31 INFO Executor: Finished task 2.0 in stage 2.0 (TID 6). 2545 bytes result sent to driver
25/05/25 18:11:31 INFO TaskSetManager: Finished task 2.0 in stage 2.0 (TID 6) in 2036 ms on spark-master (executor driver) (1/3)
25/05/25 18:11:31 INFO FileOutputCommitter: Saved output of task 'attempt_202505251811299023971561298924095_0002_m_000000_4' to s3a://flight-bucket/refined/airports/_temporary/0/task_202505251811299023971561298924095_0002_m_000000
25/05/25 18:11:31 INFO SparkHadoopMapRedUtil: attempt_202505251811299023971561298924095_0002_m_000000_4: Committed. Elapsed time: 183 ms.
25/05/25 18:11:31 INFO FileOutputCommitter: Saved output of task 'attempt_202505251811299023971561298924095_0002_m_000001_5' to s3a://flight-bucket/refined/airports/_temporary/0/task_202505251811299023971561298924095_0002_m_000001
25/05/25 18:11:31 INFO Executor: Finished task 0.0 in stage 2.0 (TID 4). 2502 bytes result sent to driver
25/05/25 18:11:31 INFO SparkHadoopMapRedUtil: attempt_202505251811299023971561298924095_0002_m_000001_5: Committed. Elapsed time: 166 ms.
25/05/25 18:11:31 INFO TaskSetManager: Finished task 0.0 in stage 2.0 (TID 4) in 2147 ms on spark-master (executor driver) (2/3)
25/05/25 18:11:31 INFO Executor: Finished task 1.0 in stage 2.0 (TID 5). 2502 bytes result sent to driver
25/05/25 18:11:31 INFO TaskSetManager: Finished task 1.0 in stage 2.0 (TID 5) in 2151 ms on spark-master (executor driver) (3/3)
25/05/25 18:11:31 INFO TaskSchedulerImpl: Removed TaskSet 2.0, whose tasks have all completed, from pool
25/05/25 18:11:31 INFO DAGScheduler: ResultStage 2 (json at NativeMethodAccessorImpl.java:0) finished in 2.205 s
25/05/25 18:11:31 INFO DAGScheduler: Job 2 is finished. Cancelling potential speculative or zombie tasks for this job
25/05/25 18:11:31 INFO TaskSchedulerImpl: Killing all running tasks in stage 2: Stage finished
25/05/25 18:11:31 INFO DAGScheduler: Job 2 finished: json at NativeMethodAccessorImpl.java:0, took 2.212596 s
25/05/25 18:11:31 INFO FileFormatWriter: Start to commit write Job 3d284393-1bd7-44fa-b305-ec3421d5837b.
25/05/25 18:11:31 INFO FileFormatWriter: Write Job 3d284393-1bd7-44fa-b305-ec3421d5837b committed. Elapsed time: 525 ms.
25/05/25 18:11:31 INFO FileFormatWriter: Finished processing stats for write job 3d284393-1bd7-44fa-b305-ec3421d5837b.
25/05/25 18:11:31 INFO InMemoryFileIndex: It took 19 ms to list leaf files for 1 paths.
25/05/25 18:11:32 INFO FileSourceStrategy: Pushed Filters:
25/05/25 18:11:32 INFO FileSourceStrategy: Post-Scan Filters:
25/05/25 18:11:32 WARN SparkStringUtils: Truncated the string representation of a plan since it was too large. This behavior can be adjusted by setting 'spark.sql.debug.maxToStringFields'.
25/05/25 18:11:32 INFO ParquetUtils: Using default output committer for Parquet: org.apache.parquet.hadoop.ParquetOutputCommitter
25/05/25 18:11:32 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 18:11:32 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 18:11:32 INFO SQLHadoopMapReduceCommitProtocol: Using user defined output committer class org.apache.parquet.hadoop.ParquetOutputCommitter
25/05/25 18:11:32 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 18:11:32 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 18:11:32 INFO SQLHadoopMapReduceCommitProtocol: Using output committer class org.apache.parquet.hadoop.ParquetOutputCommitter
25/05/25 18:11:32 INFO CodeGenerator: Code generated in 30.938798 ms
25/05/25 18:11:32 INFO MemoryStore: Block broadcast_6 stored as values in memory (estimated size 206.9 KiB, free 433.4 MiB)
25/05/25 18:11:32 INFO MemoryStore: Block broadcast_6_piece0 stored as bytes in memory (estimated size 36.5 KiB, free 433.4 MiB)
25/05/25 18:11:32 INFO BlockManagerInfo: Added broadcast_6_piece0 in memory on spark-master:40531 (size: 36.5 KiB, free: 434.2 MiB)
25/05/25 18:11:32 INFO SparkContext: Created broadcast 6 from parquet at NativeMethodAccessorImpl.java:0
25/05/25 18:11:32 INFO FileSourceScanExec: Planning scan with bin packing, max size: 6481057 bytes, open cost is considered as scanning 4194304 bytes.
25/05/25 18:11:32 INFO SparkContext: Starting job: parquet at NativeMethodAccessorImpl.java:0
25/05/25 18:11:32 INFO DAGScheduler: Got job 3 (parquet at NativeMethodAccessorImpl.java:0) with 3 output partitions
25/05/25 18:11:32 INFO DAGScheduler: Final stage: ResultStage 3 (parquet at NativeMethodAccessorImpl.java:0)
25/05/25 18:11:32 INFO DAGScheduler: Parents of final stage: List()
25/05/25 18:11:32 INFO DAGScheduler: Missing parents: List()
25/05/25 18:11:32 INFO DAGScheduler: Submitting ResultStage 3 (MapPartitionsRDD[16] at parquet at NativeMethodAccessorImpl.java:0), which has no missing parents
25/05/25 18:11:32 INFO MemoryStore: Block broadcast_7 stored as values in memory (estimated size 237.6 KiB, free 433.2 MiB)
25/05/25 18:11:32 INFO MemoryStore: Block broadcast_7_piece0 stored as bytes in memory (estimated size 87.2 KiB, free 433.1 MiB)
25/05/25 18:11:32 INFO BlockManagerInfo: Added broadcast_7_piece0 in memory on spark-master:40531 (size: 87.2 KiB, free: 434.1 MiB)
25/05/25 18:11:32 INFO SparkContext: Created broadcast 7 from broadcast at DAGScheduler.scala:1585
25/05/25 18:11:32 INFO DAGScheduler: Submitting 3 missing tasks from ResultStage 3 (MapPartitionsRDD[16] at parquet at NativeMethodAccessorImpl.java:0) (first 15 tasks are for partitions Vector(0, 1, 2))
25/05/25 18:11:32 INFO TaskSchedulerImpl: Adding task set 3.0 with 3 tasks resource profile 0
25/05/25 18:11:32 INFO TaskSetManager: Starting task 0.0 in stage 3.0 (TID 7) (spark-master, executor driver, partition 0, PROCESS_LOCAL, 10828 bytes)
25/05/25 18:11:32 INFO TaskSetManager: Starting task 1.0 in stage 3.0 (TID 8) (spark-master, executor driver, partition 1, PROCESS_LOCAL, 10828 bytes)
25/05/25 18:11:32 INFO TaskSetManager: Starting task 2.0 in stage 3.0 (TID 9) (spark-master, executor driver, partition 2, PROCESS_LOCAL, 10719 bytes)
25/05/25 18:11:32 INFO Executor: Running task 0.0 in stage 3.0 (TID 7)
25/05/25 18:11:32 INFO Executor: Running task 1.0 in stage 3.0 (TID 8)
25/05/25 18:11:32 INFO Executor: Running task 2.0 in stage 3.0 (TID 9)
25/05/25 18:11:32 INFO CodeGenerator: Code generated in 40.462336 ms
25/05/25 18:11:32 INFO CodeGenerator: Code generated in 24.014093 ms
25/05/25 18:11:32 INFO CodeGenerator: Code generated in 17.748992 ms
25/05/25 18:11:32 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 18:11:32 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 18:11:32 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 18:11:32 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 18:11:32 INFO SQLHadoopMapReduceCommitProtocol: Using user defined output committer class org.apache.parquet.hadoop.ParquetOutputCommitter
25/05/25 18:11:32 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 18:11:32 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 18:11:32 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 18:11:32 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 18:11:32 INFO SQLHadoopMapReduceCommitProtocol: Using user defined output committer class org.apache.parquet.hadoop.ParquetOutputCommitter
25/05/25 18:11:32 INFO SQLHadoopMapReduceCommitProtocol: Using user defined output committer class org.apache.parquet.hadoop.ParquetOutputCommitter
25/05/25 18:11:32 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 18:11:32 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 18:11:32 INFO SQLHadoopMapReduceCommitProtocol: Using output committer class org.apache.parquet.hadoop.ParquetOutputCommitter
25/05/25 18:11:32 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 18:11:32 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 18:11:32 INFO SQLHadoopMapReduceCommitProtocol: Using output committer class org.apache.parquet.hadoop.ParquetOutputCommitter
25/05/25 18:11:32 INFO SQLHadoopMapReduceCommitProtocol: Using output committer class org.apache.parquet.hadoop.ParquetOutputCommitter
25/05/25 18:11:32 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/flights/flights_2008_4_1.csv, range: 0-980792, partition values: [empty row]
25/05/25 18:11:32 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/flights/flights_2008_5_3.csv, range: 0-989831, partition values: [empty row]
25/05/25 18:11:32 INFO CodeGenerator: Code generated in 44.939908 ms
25/05/25 18:11:32 INFO CodeGenerator: Code generated in 41.322701 ms
25/05/25 18:11:32 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/flights/flights_2008_5_2.csv, range: 0-1002531, partition values: [empty row]
25/05/25 18:11:32 INFO BlockManagerInfo: Removed broadcast_5_piece0 on spark-master:40531 in memory (size: 81.3 KiB, free: 434.2 MiB)
25/05/25 18:11:32 INFO BlockManagerInfo: Removed broadcast_4_piece0 on spark-master:40531 in memory (size: 36.5 KiB, free: 434.2 MiB)
25/05/25 18:11:33 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/flights/flights_2008_4_2.csv, range: 0-981534, partition values: [empty row]
25/05/25 18:11:33 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/flights/flights_2008_5_1.csv, range: 0-998020, partition values: [empty row]
25/05/25 18:11:33 INFO CodeGenerator: Code generated in 30.296309 ms
25/05/25 18:11:33 INFO CodeGenerator: Code generated in 76.965518 ms
25/05/25 18:11:33 INFO BlockManagerInfo: Removed broadcast_2_piece0 on spark-master:40531 in memory (size: 36.6 KiB, free: 434.3 MiB)
25/05/25 18:11:33 INFO CodecConfig: Compression: SNAPPY
25/05/25 18:11:33 INFO CodecConfig: Compression: SNAPPY
25/05/25 18:11:33 INFO CodecConfig: Compression: SNAPPY
25/05/25 18:11:33 INFO CodecConfig: Compression: SNAPPY
25/05/25 18:11:33 INFO CodecConfig: Compression: SNAPPY
25/05/25 18:11:33 INFO CodecConfig: Compression: SNAPPY
25/05/25 18:11:33 INFO ParquetOutputFormat: ParquetRecordWriter [block size: 134217728b, row group padding size: 8388608b, validating: false]
25/05/25 18:11:33 INFO ParquetOutputFormat: ParquetRecordWriter [block size: 134217728b, row group padding size: 8388608b, validating: false]
25/05/25 18:11:33 INFO ParquetOutputFormat: ParquetRecordWriter [block size: 134217728b, row group padding size: 8388608b, validating: false]
25/05/25 18:11:33 INFO ParquetWriteSupport: Initialized Parquet WriteSupport with Catalyst schema:
{
  "type" : "struct",
  "fields" : [ {
    "name" : "dayOfMonth",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "dayOfWeek",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "depTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "crsDepTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "arrTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "crsArrTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "uniqueCarrier",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "flightNum",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "tailNum",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "actualElapsedTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "crsElapsedTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "airTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "arrDelay",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "depDelay",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "origin",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "destination",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "distance",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "taxiIn",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "taxiOut",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "cancelled",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "cancellationCode",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "diverted",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "carrierDelay",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "weatherDelay",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "nasDelay",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "securityDelay",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "lateAircraftDelay",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  } ]
}
and corresponding Parquet message type:
message spark_schema {
  optional int32 dayOfMonth;
  optional int32 dayOfWeek;
  optional int32 depTime;
  optional int32 crsDepTime;
  optional int32 arrTime;
  optional int32 crsArrTime;
  optional binary uniqueCarrier (STRING);
  optional binary flightNum (STRING);
  optional binary tailNum (STRING);
  optional int32 actualElapsedTime;
  optional int32 crsElapsedTime;
  optional int32 airTime;
  optional int32 arrDelay;
  optional int32 depDelay;
  optional binary origin (STRING);
  optional binary destination (STRING);
  optional int32 distance;
  optional int32 taxiIn;
  optional int32 taxiOut;
  optional binary cancelled (STRING);
  optional binary cancellationCode (STRING);
  optional binary diverted (STRING);
  optional binary carrierDelay (STRING);
  optional binary weatherDelay (STRING);
  optional binary nasDelay (STRING);
  optional binary securityDelay (STRING);
  optional binary lateAircraftDelay (STRING);
}


25/05/25 18:11:33 INFO ParquetWriteSupport: Initialized Parquet WriteSupport with Catalyst schema:
{
  "type" : "struct",
  "fields" : [ {
    "name" : "dayOfMonth",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "dayOfWeek",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "depTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "crsDepTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "arrTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "crsArrTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "uniqueCarrier",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "flightNum",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "tailNum",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "actualElapsedTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "crsElapsedTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "airTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "arrDelay",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "depDelay",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "origin",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "destination",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "distance",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "taxiIn",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "taxiOut",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "cancelled",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "cancellationCode",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "diverted",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "carrierDelay",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "weatherDelay",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "nasDelay",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "securityDelay",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "lateAircraftDelay",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  } ]
}
and corresponding Parquet message type:
message spark_schema {
  optional int32 dayOfMonth;
  optional int32 dayOfWeek;
  optional int32 depTime;
  optional int32 crsDepTime;
  optional int32 arrTime;
  optional int32 crsArrTime;
  optional binary uniqueCarrier (STRING);
  optional binary flightNum (STRING);
  optional binary tailNum (STRING);
  optional int32 actualElapsedTime;
  optional int32 crsElapsedTime;
  optional int32 airTime;
  optional int32 arrDelay;
  optional int32 depDelay;
  optional binary origin (STRING);
  optional binary destination (STRING);
  optional int32 distance;
  optional int32 taxiIn;
  optional int32 taxiOut;
  optional binary cancelled (STRING);
  optional binary cancellationCode (STRING);
  optional binary diverted (STRING);
  optional binary carrierDelay (STRING);
  optional binary weatherDelay (STRING);
  optional binary nasDelay (STRING);
  optional binary securityDelay (STRING);
  optional binary lateAircraftDelay (STRING);
}


25/05/25 18:11:33 INFO ParquetWriteSupport: Initialized Parquet WriteSupport with Catalyst schema:
{
  "type" : "struct",
  "fields" : [ {
    "name" : "dayOfMonth",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "dayOfWeek",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "depTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "crsDepTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "arrTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "crsArrTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "uniqueCarrier",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "flightNum",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "tailNum",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "actualElapsedTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "crsElapsedTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "airTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "arrDelay",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "depDelay",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "origin",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "destination",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "distance",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "taxiIn",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "taxiOut",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "cancelled",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "cancellationCode",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "diverted",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "carrierDelay",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "weatherDelay",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "nasDelay",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "securityDelay",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "lateAircraftDelay",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  } ]
}
and corresponding Parquet message type:
message spark_schema {
  optional int32 dayOfMonth;
  optional int32 dayOfWeek;
  optional int32 depTime;
  optional int32 crsDepTime;
  optional int32 arrTime;
  optional int32 crsArrTime;
  optional binary uniqueCarrier (STRING);
  optional binary flightNum (STRING);
  optional binary tailNum (STRING);
  optional int32 actualElapsedTime;
  optional int32 crsElapsedTime;
  optional int32 airTime;
  optional int32 arrDelay;
  optional int32 depDelay;
  optional binary origin (STRING);
  optional binary destination (STRING);
  optional int32 distance;
  optional int32 taxiIn;
  optional int32 taxiOut;
  optional binary cancelled (STRING);
  optional binary cancellationCode (STRING);
  optional binary diverted (STRING);
  optional binary carrierDelay (STRING);
  optional binary weatherDelay (STRING);
  optional binary nasDelay (STRING);
  optional binary securityDelay (STRING);
  optional binary lateAircraftDelay (STRING);
}


25/05/25 18:11:33 INFO CodecPool: Got brand-new compressor [.snappy]
25/05/25 18:11:33 INFO CodecPool: Got brand-new compressor [.snappy]
25/05/25 18:11:33 INFO CodecPool: Got brand-new compressor [.snappy]
25/05/25 18:11:35 INFO CodecConfig: Compression: SNAPPY
25/05/25 18:11:35 INFO CodecConfig: Compression: SNAPPY
25/05/25 18:11:35 INFO ParquetOutputFormat: ParquetRecordWriter [block size: 134217728b, row group padding size: 8388608b, validating: false]
25/05/25 18:11:35 INFO ParquetWriteSupport: Initialized Parquet WriteSupport with Catalyst schema:
{
  "type" : "struct",
  "fields" : [ {
    "name" : "dayOfMonth",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "dayOfWeek",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "depTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "crsDepTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "arrTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "crsArrTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "uniqueCarrier",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "flightNum",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "tailNum",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "actualElapsedTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "crsElapsedTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "airTime",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "arrDelay",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "depDelay",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "origin",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "destination",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "distance",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "taxiIn",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "taxiOut",
    "type" : "integer",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "cancelled",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "cancellationCode",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "diverted",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "carrierDelay",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "weatherDelay",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "nasDelay",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "securityDelay",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  }, {
    "name" : "lateAircraftDelay",
    "type" : "string",
    "nullable" : true,
    "metadata" : { }
  } ]
}
and corresponding Parquet message type:
message spark_schema {
  optional int32 dayOfMonth;
  optional int32 dayOfWeek;
  optional int32 depTime;
  optional int32 crsDepTime;
  optional int32 arrTime;
  optional int32 crsArrTime;
  optional binary uniqueCarrier (STRING);
  optional binary flightNum (STRING);
  optional binary tailNum (STRING);
  optional int32 actualElapsedTime;
  optional int32 crsElapsedTime;
  optional int32 airTime;
  optional int32 arrDelay;
  optional int32 depDelay;
  optional binary origin (STRING);
  optional binary destination (STRING);
  optional int32 distance;
  optional int32 taxiIn;
  optional int32 taxiOut;
  optional binary cancelled (STRING);
  optional binary cancellationCode (STRING);
  optional binary diverted (STRING);
  optional binary carrierDelay (STRING);
  optional binary weatherDelay (STRING);
  optional binary nasDelay (STRING);
  optional binary securityDelay (STRING);
  optional binary lateAircraftDelay (STRING);
}


25/05/25 18:11:35 INFO FileOutputCommitter: Saved output of task 'attempt_202505251811325530987418256171368_0003_m_000002_9' to s3a://flight-bucket/refined/flights/_temporary/0/task_202505251811325530987418256171368_0003_m_000002
25/05/25 18:11:35 INFO SparkHadoopMapRedUtil: attempt_202505251811325530987418256171368_0003_m_000002_9: Committed. Elapsed time: 103 ms.
25/05/25 18:11:35 INFO FileOutputCommitter: Saved output of task 'attempt_202505251811325530987418256171368_0003_m_000000_7' to s3a://flight-bucket/refined/flights/_temporary/0/task_202505251811325530987418256171368_0003_m_000000
25/05/25 18:11:35 INFO SparkHadoopMapRedUtil: attempt_202505251811325530987418256171368_0003_m_000000_7: Committed. Elapsed time: 97 ms.
25/05/25 18:11:35 INFO Executor: Finished task 2.0 in stage 3.0 (TID 9). 3340 bytes result sent to driver
25/05/25 18:11:35 INFO Executor: Finished task 0.0 in stage 3.0 (TID 7). 3297 bytes result sent to driver
25/05/25 18:11:35 INFO TaskSetManager: Finished task 2.0 in stage 3.0 (TID 9) in 2615 ms on spark-master (executor driver) (1/3)
25/05/25 18:11:35 INFO TaskSetManager: Finished task 0.0 in stage 3.0 (TID 7) in 2620 ms on spark-master (executor driver) (2/3)
25/05/25 18:11:35 INFO FileOutputCommitter: Saved output of task 'attempt_202505251811325530987418256171368_0003_m_000001_8' to s3a://flight-bucket/refined/flights/_temporary/0/task_202505251811325530987418256171368_0003_m_000001
25/05/25 18:11:35 INFO SparkHadoopMapRedUtil: attempt_202505251811325530987418256171368_0003_m_000001_8: Committed. Elapsed time: 86 ms.
25/05/25 18:11:35 INFO Executor: Finished task 1.0 in stage 3.0 (TID 8). 3413 bytes result sent to driver
25/05/25 18:11:35 INFO TaskSetManager: Finished task 1.0 in stage 3.0 (TID 8) in 2835 ms on spark-master (executor driver) (3/3)
25/05/25 18:11:35 INFO TaskSchedulerImpl: Removed TaskSet 3.0, whose tasks have all completed, from pool
25/05/25 18:11:35 INFO DAGScheduler: ResultStage 3 (parquet at NativeMethodAccessorImpl.java:0) finished in 2.916 s
25/05/25 18:11:35 INFO DAGScheduler: Job 3 is finished. Cancelling potential speculative or zombie tasks for this job
25/05/25 18:11:35 INFO TaskSchedulerImpl: Killing all running tasks in stage 3: Stage finished
25/05/25 18:11:35 INFO DAGScheduler: Job 3 finished: parquet at NativeMethodAccessorImpl.java:0, took 2.932020 s
25/05/25 18:11:35 INFO FileFormatWriter: Start to commit write Job b0fa8538-8aaf-4bb4-afd6-964a098a850e.
25/05/25 18:11:35 INFO FileFormatWriter: Write Job b0fa8538-8aaf-4bb4-afd6-964a098a850e committed. Elapsed time: 395 ms.
25/05/25 18:11:35 INFO FileFormatWriter: Finished processing stats for write job b0fa8538-8aaf-4bb4-afd6-964a098a850e.
25/05/25 18:11:35 INFO SparkContext: SparkContext is stopping with exitCode 0.
25/05/25 18:11:35 INFO SparkUI: Stopped Spark web UI at http://18.196.124.192:4040
25/05/25 18:11:35 INFO MapOutputTrackerMasterEndpoint: MapOutputTrackerMasterEndpoint stopped!
25/05/25 18:11:35 INFO MemoryStore: MemoryStore cleared
25/05/25 18:11:35 INFO BlockManager: BlockManager stopped
25/05/25 18:11:35 INFO BlockManagerMaster: BlockManagerMaster stopped
25/05/25 18:11:35 INFO OutputCommitCoordinator$OutputCommitCoordinatorEndpoint: OutputCommitCoordinator stopped!
25/05/25 18:11:35 INFO SparkContext: Successfully stopped SparkContext
25/05/25 18:11:36 INFO ShutdownHookManager: Shutdown hook called
25/05/25 18:11:36 INFO ShutdownHookManager: Deleting directory /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f/pyspark-9571a93b-b012-4d1c-94cb-7edd6c90570a
25/05/25 18:11:36 INFO ShutdownHookManager: Deleting directory /tmp/spark-35018862-fbc3-4e95-b7c4-97ce974b0c80
25/05/25 18:11:36 INFO ShutdownHookManager: Deleting directory /tmp/spark-ea562426-7b18-4796-84bd-17e0c96c615f
25/05/25 18:11:36 INFO MetricsSystemImpl: Stopping s3a-file-system metrics system...
25/05/25 18:11:36 INFO MetricsSystemImpl: s3a-file-system metrics system stopped.
25/05/25 18:11:36 INFO MetricsSystemImpl: s3a-file-system metrics system shutdown complete.
```


