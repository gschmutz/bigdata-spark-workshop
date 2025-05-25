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
import argparse

from pyspark.sql import SparkSession
from pyspark.sql.types import *

def main(s3_bucket: str, s3_raw_path: str, s3_refined_path: str):

    spark = SparkSession\
        .builder\
        .appName("FlighTransform")\
        .getOrCreate()
        
    s3_raw_uri = f"s3a://{s3_bucket}/{s3_raw_path}"    
    s3_refined_uri = f"s3a://{s3_bucket}/{s3_refined_path}" 
    print(f"Reading data from raw {s3_raw_uri} and writing to refined {s3_refined_uri}")
    
    airportsRawDF = spark.read.csv(f"{s3_raw_uri}/airports", \
    			sep=",", inferSchema="true", header="true")
    airportsRawDF.write.json(f"{s3_refined_uri}/airports")

    flightSchema = """`year` INTEGER, `month` INTEGER, `dayOfMonth` INTEGER,  `dayOfWeek` INTEGER, `depTime` INTEGER, `crsDepTime` INTEGER, `arrTime` INTEGER, `crsArrTime` INTEGER, `uniqueCarrier` STRING, `flightNum` STRING, `tailNum` STRING, `actualElapsedTime` INTEGER,\
                   `crsElapsedTime` INTEGER, `airTime` INTEGER, `arrDelay` INTEGER,`depDelay` INTEGER,`origin` STRING, `destination` STRING, `distance` INTEGER, `taxiIn` INTEGER, `taxiOut` INTEGER, `cancelled` STRING, `cancellationCode` STRING, `diverted` STRING,
                   `carrierDelay` STRING, `weatherDelay` STRING, `nasDelay` STRING, `securityDelay` STRING, `lateAircraftDelay` STRING"""
                   
    flightsRawDF = spark.read.csv(f"{s3_raw_uri}/flights", \
    			sep=",", inferSchema="false", header="false", schema=flightSchema)

    flightsRawDF.write.partitionBy("year","month").parquet(f"{s3_refined_uri}/flights")

    spark.stop()
    
if __name__ == "__main__":
    """
    Usage:
        spark-submit spark_app.py --s3-bucket <bucket-name> --s3-raw-path <path/to/data> --s3-refined-path <path/to/data>

    Example:
        spark-submit spark_app.py --s3-bucket my-data-bucket --s3-raw-path <path/to/data> --s3-refined-path <path/to/data>
    """
    parser = argparse.ArgumentParser(description="Spark App with S3 input")
    parser.add_argument("--s3-bucket", required=True, help="S3 bucket name (without s3a://)")
    parser.add_argument("--s3-raw-path", required=True, help="Path in the S3 bucket to the raw data")
    parser.add_argument("--s3-refined-path", required=True, help="Path in the S3 bucket to the refined data")
    args = parser.parse_args()

    main(args.s3_bucket, args.s3_raw_path, args.s3_refined_path)    
```

Save it by hitting `Ctrl-O` and exit by hitting `Ctrl-X`.

The application accepts 3 parameters to specify the S3 bucket name, the raw folder and the refined folder.

## Run the application against the Spark Cluster using `spark-submit`

Before we submit the application, let's make sure that the `refined` folder does not exists. Otherwise we will get an error when trying to write to the folder. 

```bash
docker exec -ti awscli s3cmd del --recursive s3://flight-bucket/refined
```

Now we can submit it using `spark-submit` CLI, which is part of the `spark-master` docker container. 

```bash
docker exec -it spark-master spark-submit /data-transfer/app/prep_refined.py --s3-bucket flight-bucket --s3-raw-path raw --s3-refined-path refined
```

and you should see the following successful execution

```
ubuntu@ip-172-26-9-12:~/bigdata-spark-workshop/01-environment/docker$ docker exec -it spark-master spark-submit /data-transfer/app/prep_refined.py --s3-bucket flight-bucket --s3-raw-path raw --s3-refined-path refined
:: loading settings :: url = jar:file:/opt/bitnami/spark/jars/ivy-2.5.1.jar!/org/apache/ivy/core/settings/ivysettings.xml
Ivy Default Cache set to: /opt/bitnami/spark/.ivy2/cache
The jars for the packages stored in: /opt/bitnami/spark/.ivy2/jars
org.apache.spark#spark-avro_2.12 added as a dependency
graphframes#graphframes added as a dependency
:: resolving dependencies :: org.apache.spark#spark-submit-parent-c4ecbc57-52c4-4fe9-ba1a-ba7e681e7f47;1.0
	confs: [default]
	found org.apache.spark#spark-avro_2.12;3.5.2 in central
	found org.tukaani#xz;1.9 in central
	found graphframes#graphframes;0.8.4-spark3.5-s_2.12 in spark-packages
	found org.slf4j#slf4j-api;1.7.16 in central
:: resolution report :: resolve 412ms :: artifacts dl 37ms
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
:: retrieving :: org.apache.spark#spark-submit-parent-c4ecbc57-52c4-4fe9-ba1a-ba7e681e7f47
	confs: [default]
	0 artifacts copied, 4 already retrieved (0kB/12ms)
25/05/25 20:04:20 WARN NativeCodeLoader: Unable to load native-hadoop library for your platform... using builtin-java classes where applicable
25/05/25 20:04:21 INFO SparkContext: Running Spark version 3.5.3
25/05/25 20:04:21 INFO SparkContext: OS info Linux, 6.8.0-1029-aws, amd64
25/05/25 20:04:21 INFO SparkContext: Java version 17.0.13
25/05/25 20:04:21 INFO ResourceUtils: ==============================================================
25/05/25 20:04:21 INFO ResourceUtils: No custom resources configured for spark.driver.
25/05/25 20:04:21 INFO ResourceUtils: ==============================================================
25/05/25 20:04:21 INFO SparkContext: Submitted application: FlighTransform
25/05/25 20:04:21 INFO ResourceProfile: Default ResourceProfile created, executor resources: Map(cores -> name: cores, amount: 1, script: , vendor: , memory -> name: memory, amount: 2048, script: , vendor: , offHeap -> name: offHeap, amount: 0, script: , vendor: ), task resources: Map(cpus -> name: cpus, amount: 1.0)
25/05/25 20:04:21 INFO ResourceProfile: Limiting resource is cpu
25/05/25 20:04:21 INFO ResourceProfileManager: Added ResourceProfile id: 0
25/05/25 20:04:21 INFO SecurityManager: Changing view acls to: spark
25/05/25 20:04:21 INFO SecurityManager: Changing modify acls to: spark
25/05/25 20:04:21 INFO SecurityManager: Changing view acls groups to:
25/05/25 20:04:21 INFO SecurityManager: Changing modify acls groups to:
25/05/25 20:04:21 INFO SecurityManager: SecurityManager: authentication disabled; ui acls disabled; users with view permissions: spark; groups with view permissions: EMPTY; users with modify permissions: spark; groups with modify permissions: EMPTY
25/05/25 20:04:21 INFO Utils: Successfully started service 'sparkDriver' on port 34813.
25/05/25 20:04:21 INFO SparkEnv: Registering MapOutputTracker
25/05/25 20:04:21 INFO SparkEnv: Registering BlockManagerMaster
25/05/25 20:04:21 INFO BlockManagerMasterEndpoint: Using org.apache.spark.storage.DefaultTopologyMapper for getting topology information
25/05/25 20:04:21 INFO BlockManagerMasterEndpoint: BlockManagerMasterEndpoint up
25/05/25 20:04:21 INFO SparkEnv: Registering BlockManagerMasterHeartbeat
25/05/25 20:04:21 INFO DiskBlockManager: Created local directory at /tmp/blockmgr-1a8714ff-4ef8-4d9d-9b2e-bdd22776c428
25/05/25 20:04:21 INFO MemoryStore: MemoryStore started with capacity 434.4 MiB
25/05/25 20:04:21 INFO SparkEnv: Registering OutputCommitCoordinator
25/05/25 20:04:22 INFO JettyUtils: Start Jetty 0.0.0.0:4040 for SparkUI
25/05/25 20:04:22 INFO Utils: Successfully started service 'SparkUI' on port 4040.
25/05/25 20:04:22 INFO SparkContext: Added JAR file:///opt/bitnami/spark/jars/delta-spark_2.12-3.2.1.jar at spark://spark-master:34813/jars/delta-spark_2.12-3.2.1.jar with timestamp 1748203461388
25/05/25 20:04:22 INFO SparkContext: Added JAR file:///opt/bitnami/spark/jars/delta-storage-3.2.1.jar at spark://spark-master:34813/jars/delta-storage-3.2.1.jar with timestamp 1748203461388
25/05/25 20:04:22 INFO SparkContext: Added JAR file:///opt/bitnami/spark/.ivy2/jars/org.apache.spark_spark-avro_2.12-3.5.2.jar at spark://spark-master:34813/jars/org.apache.spark_spark-avro_2.12-3.5.2.jar with timestamp 1748203461388
25/05/25 20:04:22 INFO SparkContext: Added JAR file:///opt/bitnami/spark/.ivy2/jars/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar at spark://spark-master:34813/jars/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar with timestamp 1748203461388
25/05/25 20:04:22 INFO SparkContext: Added JAR file:///opt/bitnami/spark/.ivy2/jars/org.tukaani_xz-1.9.jar at spark://spark-master:34813/jars/org.tukaani_xz-1.9.jar with timestamp 1748203461388
25/05/25 20:04:22 INFO SparkContext: Added JAR file:///opt/bitnami/spark/.ivy2/jars/org.slf4j_slf4j-api-1.7.16.jar at spark://spark-master:34813/jars/org.slf4j_slf4j-api-1.7.16.jar with timestamp 1748203461388
25/05/25 20:04:22 INFO SparkContext: Added file file:///opt/bitnami/spark/.ivy2/jars/org.apache.spark_spark-avro_2.12-3.5.2.jar at file:///opt/bitnami/spark/.ivy2/jars/org.apache.spark_spark-avro_2.12-3.5.2.jar with timestamp 1748203461388
25/05/25 20:04:22 INFO Utils: Copying /opt/bitnami/spark/.ivy2/jars/org.apache.spark_spark-avro_2.12-3.5.2.jar to /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/org.apache.spark_spark-avro_2.12-3.5.2.jar
25/05/25 20:04:22 INFO SparkContext: Added file file:///opt/bitnami/spark/.ivy2/jars/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar at file:///opt/bitnami/spark/.ivy2/jars/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar with timestamp 1748203461388
25/05/25 20:04:22 INFO Utils: Copying /opt/bitnami/spark/.ivy2/jars/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar to /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar
25/05/25 20:04:22 INFO SparkContext: Added file file:///opt/bitnami/spark/.ivy2/jars/org.tukaani_xz-1.9.jar at file:///opt/bitnami/spark/.ivy2/jars/org.tukaani_xz-1.9.jar with timestamp 1748203461388
25/05/25 20:04:22 INFO Utils: Copying /opt/bitnami/spark/.ivy2/jars/org.tukaani_xz-1.9.jar to /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/org.tukaani_xz-1.9.jar
25/05/25 20:04:22 INFO SparkContext: Added file file:///opt/bitnami/spark/.ivy2/jars/org.slf4j_slf4j-api-1.7.16.jar at file:///opt/bitnami/spark/.ivy2/jars/org.slf4j_slf4j-api-1.7.16.jar with timestamp 1748203461388
25/05/25 20:04:22 INFO Utils: Copying /opt/bitnami/spark/.ivy2/jars/org.slf4j_slf4j-api-1.7.16.jar to /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/org.slf4j_slf4j-api-1.7.16.jar
25/05/25 20:04:22 INFO Executor: Starting executor ID driver on host spark-master
25/05/25 20:04:22 INFO Executor: OS info Linux, 6.8.0-1029-aws, amd64
25/05/25 20:04:22 INFO Executor: Java version 17.0.13
25/05/25 20:04:22 INFO Executor: Starting executor with user classpath (userClassPathFirst = false): ''
25/05/25 20:04:22 INFO Executor: Created or updated repl class loader org.apache.spark.util.MutableURLClassLoader@2dd870f7 for default.
25/05/25 20:04:22 INFO Executor: Fetching file:///opt/bitnami/spark/.ivy2/jars/org.apache.spark_spark-avro_2.12-3.5.2.jar with timestamp 1748203461388
25/05/25 20:04:22 INFO Utils: /opt/bitnami/spark/.ivy2/jars/org.apache.spark_spark-avro_2.12-3.5.2.jar has been previously copied to /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/org.apache.spark_spark-avro_2.12-3.5.2.jar
25/05/25 20:04:22 INFO Executor: Fetching file:///opt/bitnami/spark/.ivy2/jars/org.tukaani_xz-1.9.jar with timestamp 1748203461388
25/05/25 20:04:22 INFO Utils: /opt/bitnami/spark/.ivy2/jars/org.tukaani_xz-1.9.jar has been previously copied to /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/org.tukaani_xz-1.9.jar
25/05/25 20:04:22 INFO Executor: Fetching file:///opt/bitnami/spark/.ivy2/jars/org.slf4j_slf4j-api-1.7.16.jar with timestamp 1748203461388
25/05/25 20:04:22 INFO Utils: /opt/bitnami/spark/.ivy2/jars/org.slf4j_slf4j-api-1.7.16.jar has been previously copied to /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/org.slf4j_slf4j-api-1.7.16.jar
25/05/25 20:04:22 INFO Executor: Fetching file:///opt/bitnami/spark/.ivy2/jars/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar with timestamp 1748203461388
25/05/25 20:04:22 INFO Utils: /opt/bitnami/spark/.ivy2/jars/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar has been previously copied to /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar
25/05/25 20:04:22 INFO Executor: Fetching spark://spark-master:34813/jars/org.tukaani_xz-1.9.jar with timestamp 1748203461388
25/05/25 20:04:22 INFO TransportClientFactory: Successfully created connection to spark-master/172.18.0.12:34813 after 39 ms (0 ms spent in bootstraps)
25/05/25 20:04:22 INFO Utils: Fetching spark://spark-master:34813/jars/org.tukaani_xz-1.9.jar to /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/fetchFileTemp11387442480902420489.tmp
25/05/25 20:04:22 INFO Utils: /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/fetchFileTemp11387442480902420489.tmp has been previously copied to /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/org.tukaani_xz-1.9.jar
25/05/25 20:04:22 INFO Executor: Adding file:/tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/org.tukaani_xz-1.9.jar to class loader default
25/05/25 20:04:22 INFO Executor: Fetching spark://spark-master:34813/jars/org.apache.spark_spark-avro_2.12-3.5.2.jar with timestamp 1748203461388
25/05/25 20:04:22 INFO Utils: Fetching spark://spark-master:34813/jars/org.apache.spark_spark-avro_2.12-3.5.2.jar to /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/fetchFileTemp19085459838036559.tmp
25/05/25 20:04:22 INFO Utils: /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/fetchFileTemp19085459838036559.tmp has been previously copied to /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/org.apache.spark_spark-avro_2.12-3.5.2.jar
25/05/25 20:04:22 INFO Executor: Adding file:/tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/org.apache.spark_spark-avro_2.12-3.5.2.jar to class loader default
25/05/25 20:04:22 INFO Executor: Fetching spark://spark-master:34813/jars/org.slf4j_slf4j-api-1.7.16.jar with timestamp 1748203461388
25/05/25 20:04:22 INFO Utils: Fetching spark://spark-master:34813/jars/org.slf4j_slf4j-api-1.7.16.jar to /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/fetchFileTemp16861852530201910344.tmp
25/05/25 20:04:22 INFO Utils: /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/fetchFileTemp16861852530201910344.tmp has been previously copied to /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/org.slf4j_slf4j-api-1.7.16.jar
25/05/25 20:04:22 INFO Executor: Adding file:/tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/org.slf4j_slf4j-api-1.7.16.jar to class loader default
25/05/25 20:04:22 INFO Executor: Fetching spark://spark-master:34813/jars/delta-storage-3.2.1.jar with timestamp 1748203461388
25/05/25 20:04:22 INFO Utils: Fetching spark://spark-master:34813/jars/delta-storage-3.2.1.jar to /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/fetchFileTemp3249658527221108418.tmp
25/05/25 20:04:22 INFO Executor: Adding file:/tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/delta-storage-3.2.1.jar to class loader default
25/05/25 20:04:22 INFO Executor: Fetching spark://spark-master:34813/jars/delta-spark_2.12-3.2.1.jar with timestamp 1748203461388
25/05/25 20:04:22 INFO Utils: Fetching spark://spark-master:34813/jars/delta-spark_2.12-3.2.1.jar to /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/fetchFileTemp10771371299500651089.tmp
25/05/25 20:04:22 INFO Executor: Adding file:/tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/delta-spark_2.12-3.2.1.jar to class loader default
25/05/25 20:04:22 INFO Executor: Fetching spark://spark-master:34813/jars/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar with timestamp 1748203461388
25/05/25 20:04:22 INFO Utils: Fetching spark://spark-master:34813/jars/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar to /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/fetchFileTemp5414616277941208208.tmp
25/05/25 20:04:22 INFO Utils: /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/fetchFileTemp5414616277941208208.tmp has been previously copied to /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar
25/05/25 20:04:22 INFO Executor: Adding file:/tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/userFiles-6ab28eb5-6cf6-41f8-a066-06bae593103d/graphframes_graphframes-0.8.4-spark3.5-s_2.12.jar to class loader default
25/05/25 20:04:22 INFO Utils: Successfully started service 'org.apache.spark.network.netty.NettyBlockTransferService' on port 40781.
25/05/25 20:04:22 INFO NettyBlockTransferService: Server created on spark-master:40781
25/05/25 20:04:22 INFO BlockManager: Using org.apache.spark.storage.RandomBlockReplicationPolicy for block replication policy
25/05/25 20:04:22 INFO BlockManagerMaster: Registering BlockManager BlockManagerId(driver, spark-master, 40781, None)
25/05/25 20:04:22 INFO BlockManagerMasterEndpoint: Registering block manager spark-master:40781 with 434.4 MiB RAM, BlockManagerId(driver, spark-master, 40781, None)
25/05/25 20:04:22 INFO BlockManagerMaster: Registered BlockManager BlockManagerId(driver, spark-master, 40781, None)
25/05/25 20:04:22 INFO BlockManager: Initialized BlockManager: BlockManagerId(driver, spark-master, 40781, None)
25/05/25 20:04:22 INFO SingleEventLogFileWriter: Logging events to file:/var/log/spark/logs/local-1748203462404.inprogress
Reading data from raw s3a://flight-bucket/raw and writing to refined s3a://flight-bucket/refined
25/05/25 20:04:23 INFO SharedState: Setting hive.metastore.warehouse.dir ('null') to the value of spark.sql.warehouse.dir.
25/05/25 20:04:23 WARN MetricsConfig: Cannot locate configuration: tried hadoop-metrics2-s3a-file-system.properties,hadoop-metrics2.properties
25/05/25 20:04:23 INFO MetricsSystemImpl: Scheduled Metric snapshot period at 10 second(s).
25/05/25 20:04:23 INFO MetricsSystemImpl: s3a-file-system metrics system started
25/05/25 20:04:24 INFO SharedState: Warehouse path is 's3a://admin-bucket/hive/warehouse'.
25/05/25 20:04:25 INFO InMemoryFileIndex: It took 286 ms to list leaf files for 1 paths.
25/05/25 20:04:25 INFO InMemoryFileIndex: It took 18 ms to list leaf files for 1 paths.
25/05/25 20:04:29 INFO FileSourceStrategy: Pushed Filters:
25/05/25 20:04:29 INFO FileSourceStrategy: Post-Scan Filters: (length(trim(value#0, None)) > 0)
25/05/25 20:04:29 INFO CodeGenerator: Code generated in 264.497486 ms
25/05/25 20:04:29 INFO MemoryStore: Block broadcast_0 stored as values in memory (estimated size 207.0 KiB, free 434.2 MiB)
25/05/25 20:04:29 INFO MemoryStore: Block broadcast_0_piece0 stored as bytes in memory (estimated size 36.6 KiB, free 434.2 MiB)
25/05/25 20:04:29 INFO BlockManagerInfo: Added broadcast_0_piece0 in memory on spark-master:40781 (size: 36.6 KiB, free: 434.4 MiB)
25/05/25 20:04:29 INFO SparkContext: Created broadcast 0 from csv at NativeMethodAccessorImpl.java:0
25/05/25 20:04:29 INFO FileSourceScanExec: Planning scan with bin packing, max size: 4194304 bytes, open cost is considered as scanning 4194304 bytes.
25/05/25 20:04:29 INFO SparkContext: Starting job: csv at NativeMethodAccessorImpl.java:0
25/05/25 20:04:30 INFO DAGScheduler: Got job 0 (csv at NativeMethodAccessorImpl.java:0) with 1 output partitions
25/05/25 20:04:30 INFO DAGScheduler: Final stage: ResultStage 0 (csv at NativeMethodAccessorImpl.java:0)
25/05/25 20:04:30 INFO DAGScheduler: Parents of final stage: List()
25/05/25 20:04:30 INFO DAGScheduler: Missing parents: List()
25/05/25 20:04:30 INFO DAGScheduler: Submitting ResultStage 0 (MapPartitionsRDD[3] at csv at NativeMethodAccessorImpl.java:0), which has no missing parents
25/05/25 20:04:30 INFO MemoryStore: Block broadcast_1 stored as values in memory (estimated size 13.5 KiB, free 434.1 MiB)
25/05/25 20:04:30 INFO MemoryStore: Block broadcast_1_piece0 stored as bytes in memory (estimated size 6.4 KiB, free 434.1 MiB)
25/05/25 20:04:30 INFO BlockManagerInfo: Added broadcast_1_piece0 in memory on spark-master:40781 (size: 6.4 KiB, free: 434.4 MiB)
25/05/25 20:04:30 INFO SparkContext: Created broadcast 1 from broadcast at DAGScheduler.scala:1585
25/05/25 20:04:30 INFO DAGScheduler: Submitting 1 missing tasks from ResultStage 0 (MapPartitionsRDD[3] at csv at NativeMethodAccessorImpl.java:0) (first 15 tasks are for partitions Vector(0))
25/05/25 20:04:30 INFO TaskSchedulerImpl: Adding task set 0.0 with 1 tasks resource profile 0
25/05/25 20:04:30 INFO TaskSetManager: Starting task 0.0 in stage 0.0 (TID 0) (spark-master, executor driver, partition 0, PROCESS_LOCAL, 10712 bytes)
25/05/25 20:04:30 INFO Executor: Running task 0.0 in stage 0.0 (TID 0)
25/05/25 20:04:30 INFO CodeGenerator: Code generated in 17.274149 ms
25/05/25 20:04:30 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/airports/airports.csv, range: 0-4194304, partition values: [empty row]
25/05/25 20:04:30 INFO CodeGenerator: Code generated in 16.282069 ms
25/05/25 20:04:30 INFO Executor: Finished task 0.0 in stage 0.0 (TID 0). 1854 bytes result sent to driver
25/05/25 20:04:30 INFO TaskSetManager: Finished task 0.0 in stage 0.0 (TID 0) in 292 ms on spark-master (executor driver) (1/1)
25/05/25 20:04:30 INFO TaskSchedulerImpl: Removed TaskSet 0.0, whose tasks have all completed, from pool
25/05/25 20:04:30 INFO DAGScheduler: ResultStage 0 (csv at NativeMethodAccessorImpl.java:0) finished in 0.430 s
25/05/25 20:04:30 INFO DAGScheduler: Job 0 is finished. Cancelling potential speculative or zombie tasks for this job
25/05/25 20:04:30 INFO TaskSchedulerImpl: Killing all running tasks in stage 0: Stage finished
25/05/25 20:04:30 INFO DAGScheduler: Job 0 finished: csv at NativeMethodAccessorImpl.java:0, took 0.479992 s
25/05/25 20:04:30 INFO CodeGenerator: Code generated in 9.877878 ms
25/05/25 20:04:30 INFO FileSourceStrategy: Pushed Filters:
25/05/25 20:04:30 INFO FileSourceStrategy: Post-Scan Filters:
25/05/25 20:04:30 INFO MemoryStore: Block broadcast_2 stored as values in memory (estimated size 207.0 KiB, free 433.9 MiB)
25/05/25 20:04:30 INFO MemoryStore: Block broadcast_2_piece0 stored as bytes in memory (estimated size 36.6 KiB, free 433.9 MiB)
25/05/25 20:04:30 INFO BlockManagerInfo: Added broadcast_2_piece0 in memory on spark-master:40781 (size: 36.6 KiB, free: 434.3 MiB)
25/05/25 20:04:30 INFO SparkContext: Created broadcast 2 from csv at NativeMethodAccessorImpl.java:0
25/05/25 20:04:30 INFO FileSourceScanExec: Planning scan with bin packing, max size: 4194304 bytes, open cost is considered as scanning 4194304 bytes.
25/05/25 20:04:30 INFO BlockManagerInfo: Removed broadcast_1_piece0 on spark-master:40781 in memory (size: 6.4 KiB, free: 434.3 MiB)
25/05/25 20:04:30 INFO SparkContext: Starting job: csv at NativeMethodAccessorImpl.java:0
25/05/25 20:04:30 INFO DAGScheduler: Got job 1 (csv at NativeMethodAccessorImpl.java:0) with 3 output partitions
25/05/25 20:04:30 INFO DAGScheduler: Final stage: ResultStage 1 (csv at NativeMethodAccessorImpl.java:0)
25/05/25 20:04:30 INFO DAGScheduler: Parents of final stage: List()
25/05/25 20:04:30 INFO DAGScheduler: Missing parents: List()
25/05/25 20:04:30 INFO DAGScheduler: Submitting ResultStage 1 (MapPartitionsRDD[9] at csv at NativeMethodAccessorImpl.java:0), which has no missing parents
25/05/25 20:04:30 INFO MemoryStore: Block broadcast_3 stored as values in memory (estimated size 31.2 KiB, free 433.9 MiB)
25/05/25 20:04:30 INFO MemoryStore: Block broadcast_3_piece0 stored as bytes in memory (estimated size 13.9 KiB, free 433.9 MiB)
25/05/25 20:04:30 INFO BlockManagerInfo: Added broadcast_3_piece0 in memory on spark-master:40781 (size: 13.9 KiB, free: 434.3 MiB)
25/05/25 20:04:30 INFO SparkContext: Created broadcast 3 from broadcast at DAGScheduler.scala:1585
25/05/25 20:04:30 INFO DAGScheduler: Submitting 3 missing tasks from ResultStage 1 (MapPartitionsRDD[9] at csv at NativeMethodAccessorImpl.java:0) (first 15 tasks are for partitions Vector(0, 1, 2))
25/05/25 20:04:30 INFO TaskSchedulerImpl: Adding task set 1.0 with 3 tasks resource profile 0
25/05/25 20:04:30 INFO TaskSetManager: Starting task 0.0 in stage 1.0 (TID 1) (spark-master, executor driver, partition 0, PROCESS_LOCAL, 10712 bytes)
25/05/25 20:04:30 INFO TaskSetManager: Starting task 1.0 in stage 1.0 (TID 2) (spark-master, executor driver, partition 1, PROCESS_LOCAL, 10712 bytes)
25/05/25 20:04:30 INFO TaskSetManager: Starting task 2.0 in stage 1.0 (TID 3) (spark-master, executor driver, partition 2, PROCESS_LOCAL, 10712 bytes)
25/05/25 20:04:30 INFO Executor: Running task 0.0 in stage 1.0 (TID 1)
25/05/25 20:04:30 INFO Executor: Running task 1.0 in stage 1.0 (TID 2)
25/05/25 20:04:30 INFO Executor: Running task 2.0 in stage 1.0 (TID 3)
25/05/25 20:04:30 INFO CodeGenerator: Code generated in 15.934827 ms
25/05/25 20:04:30 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/airports/airports.csv, range: 4194304-8388608, partition values: [empty row]
25/05/25 20:04:30 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/airports/airports.csv, range: 8388608-11879081, partition values: [empty row]
25/05/25 20:04:30 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/airports/airports.csv, range: 0-4194304, partition values: [empty row]
25/05/25 20:04:31 INFO BlockManagerInfo: Removed broadcast_0_piece0 on spark-master:40781 in memory (size: 36.6 KiB, free: 434.4 MiB)
25/05/25 20:04:31 INFO Executor: Finished task 2.0 in stage 1.0 (TID 3). 1787 bytes result sent to driver
25/05/25 20:04:31 INFO TaskSetManager: Finished task 2.0 in stage 1.0 (TID 3) in 1241 ms on spark-master (executor driver) (1/3)
25/05/25 20:04:32 INFO Executor: Finished task 1.0 in stage 1.0 (TID 2). 1744 bytes result sent to driver
25/05/25 20:04:32 INFO Executor: Finished task 0.0 in stage 1.0 (TID 1). 1744 bytes result sent to driver
25/05/25 20:04:32 INFO TaskSetManager: Finished task 1.0 in stage 1.0 (TID 2) in 1349 ms on spark-master (executor driver) (2/3)
25/05/25 20:04:32 INFO TaskSetManager: Finished task 0.0 in stage 1.0 (TID 1) in 1354 ms on spark-master (executor driver) (3/3)
25/05/25 20:04:32 INFO TaskSchedulerImpl: Removed TaskSet 1.0, whose tasks have all completed, from pool
25/05/25 20:04:32 INFO DAGScheduler: ResultStage 1 (csv at NativeMethodAccessorImpl.java:0) finished in 1.383 s
25/05/25 20:04:32 INFO DAGScheduler: Job 1 is finished. Cancelling potential speculative or zombie tasks for this job
25/05/25 20:04:32 INFO TaskSchedulerImpl: Killing all running tasks in stage 1: Stage finished
25/05/25 20:04:32 INFO DAGScheduler: Job 1 finished: csv at NativeMethodAccessorImpl.java:0, took 1.392696 s
25/05/25 20:04:32 INFO FileSourceStrategy: Pushed Filters:
25/05/25 20:04:32 INFO FileSourceStrategy: Post-Scan Filters:
25/05/25 20:04:32 WARN AbstractS3ACommitterFactory: Using standard FileOutputCommitter to commit work. This is slow and potentially unsafe.
25/05/25 20:04:32 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 20:04:32 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 20:04:32 INFO AbstractS3ACommitterFactory: Using Committer FileOutputCommitter{PathOutputCommitter{context=TaskAttemptContextImpl{JobContextImpl{jobId=job_20250525200432324478952810597304_0000}; taskId=attempt_20250525200432324478952810597304_0000_m_000000_0, status=''}; org.apache.hadoop.mapreduce.lib.output.FileOutputCommitter@1df4ae1b}; outputPath=s3a://flight-bucket/refined/airports, workPath=s3a://flight-bucket/refined/airports/_temporary/0/_temporary/attempt_20250525200432324478952810597304_0000_m_000000_0, algorithmVersion=1, skipCleanup=false, ignoreCleanupFailures=false} for s3a://flight-bucket/refined/airports
25/05/25 20:04:32 INFO SQLHadoopMapReduceCommitProtocol: Using output committer class org.apache.hadoop.mapreduce.lib.output.FileOutputCommitter
25/05/25 20:04:32 INFO MemoryStore: Block broadcast_4 stored as values in memory (estimated size 206.9 KiB, free 433.9 MiB)
25/05/25 20:04:32 INFO MemoryStore: Block broadcast_4_piece0 stored as bytes in memory (estimated size 36.5 KiB, free 433.9 MiB)
25/05/25 20:04:32 INFO BlockManagerInfo: Added broadcast_4_piece0 in memory on spark-master:40781 (size: 36.5 KiB, free: 434.3 MiB)
25/05/25 20:04:32 INFO SparkContext: Created broadcast 4 from json at NativeMethodAccessorImpl.java:0
25/05/25 20:04:32 INFO FileSourceScanExec: Planning scan with bin packing, max size: 4194304 bytes, open cost is considered as scanning 4194304 bytes.
25/05/25 20:04:32 INFO SparkContext: Starting job: json at NativeMethodAccessorImpl.java:0
25/05/25 20:04:32 INFO DAGScheduler: Got job 2 (json at NativeMethodAccessorImpl.java:0) with 3 output partitions
25/05/25 20:04:32 INFO DAGScheduler: Final stage: ResultStage 2 (json at NativeMethodAccessorImpl.java:0)
25/05/25 20:04:32 INFO DAGScheduler: Parents of final stage: List()
25/05/25 20:04:32 INFO DAGScheduler: Missing parents: List()
25/05/25 20:04:32 INFO DAGScheduler: Submitting ResultStage 2 (MapPartitionsRDD[12] at json at NativeMethodAccessorImpl.java:0), which has no missing parents
25/05/25 20:04:32 INFO MemoryStore: Block broadcast_5 stored as values in memory (estimated size 225.3 KiB, free 433.7 MiB)
25/05/25 20:04:32 INFO MemoryStore: Block broadcast_5_piece0 stored as bytes in memory (estimated size 81.3 KiB, free 433.6 MiB)
25/05/25 20:04:32 INFO BlockManagerInfo: Added broadcast_5_piece0 in memory on spark-master:40781 (size: 81.3 KiB, free: 434.2 MiB)
25/05/25 20:04:32 INFO SparkContext: Created broadcast 5 from broadcast at DAGScheduler.scala:1585
25/05/25 20:04:32 INFO DAGScheduler: Submitting 3 missing tasks from ResultStage 2 (MapPartitionsRDD[12] at json at NativeMethodAccessorImpl.java:0) (first 15 tasks are for partitions Vector(0, 1, 2))
25/05/25 20:04:32 INFO TaskSchedulerImpl: Adding task set 2.0 with 3 tasks resource profile 0
25/05/25 20:04:32 INFO TaskSetManager: Starting task 0.0 in stage 2.0 (TID 4) (spark-master, executor driver, partition 0, PROCESS_LOCAL, 10712 bytes)
25/05/25 20:04:32 INFO TaskSetManager: Starting task 1.0 in stage 2.0 (TID 5) (spark-master, executor driver, partition 1, PROCESS_LOCAL, 10712 bytes)
25/05/25 20:04:32 INFO TaskSetManager: Starting task 2.0 in stage 2.0 (TID 6) (spark-master, executor driver, partition 2, PROCESS_LOCAL, 10712 bytes)
25/05/25 20:04:32 INFO Executor: Running task 0.0 in stage 2.0 (TID 4)
25/05/25 20:04:32 INFO Executor: Running task 2.0 in stage 2.0 (TID 6)
25/05/25 20:04:32 INFO Executor: Running task 1.0 in stage 2.0 (TID 5)
25/05/25 20:04:32 WARN AbstractS3ACommitterFactory: Using standard FileOutputCommitter to commit work. This is slow and potentially unsafe.
25/05/25 20:04:32 WARN AbstractS3ACommitterFactory: Using standard FileOutputCommitter to commit work. This is slow and potentially unsafe.
25/05/25 20:04:32 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 20:04:32 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 20:04:32 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 20:04:32 WARN AbstractS3ACommitterFactory: Using standard FileOutputCommitter to commit work. This is slow and potentially unsafe.
25/05/25 20:04:32 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 20:04:32 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 20:04:32 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 20:04:32 INFO AbstractS3ACommitterFactory: Using Committer FileOutputCommitter{PathOutputCommitter{context=TaskAttemptContextImpl{JobContextImpl{jobId=job_202505252004324112366001342762426_0002}; taskId=attempt_202505252004324112366001342762426_0002_m_000000_4, status=''}; org.apache.hadoop.mapreduce.lib.output.FileOutputCommitter@7a80376f}; outputPath=s3a://flight-bucket/refined/airports, workPath=s3a://flight-bucket/refined/airports/_temporary/0/_temporary/attempt_202505252004324112366001342762426_0002_m_000000_4, algorithmVersion=1, skipCleanup=false, ignoreCleanupFailures=false} for s3a://flight-bucket/refined/airports
25/05/25 20:04:32 INFO AbstractS3ACommitterFactory: Using Committer FileOutputCommitter{PathOutputCommitter{context=TaskAttemptContextImpl{JobContextImpl{jobId=job_202505252004324112366001342762426_0002}; taskId=attempt_202505252004324112366001342762426_0002_m_000001_5, status=''}; org.apache.hadoop.mapreduce.lib.output.FileOutputCommitter@346cd9e1}; outputPath=s3a://flight-bucket/refined/airports, workPath=s3a://flight-bucket/refined/airports/_temporary/0/_temporary/attempt_202505252004324112366001342762426_0002_m_000001_5, algorithmVersion=1, skipCleanup=false, ignoreCleanupFailures=false} for s3a://flight-bucket/refined/airports
25/05/25 20:04:32 INFO AbstractS3ACommitterFactory: Using Committer FileOutputCommitter{PathOutputCommitter{context=TaskAttemptContextImpl{JobContextImpl{jobId=job_202505252004324112366001342762426_0002}; taskId=attempt_202505252004324112366001342762426_0002_m_000002_6, status=''}; org.apache.hadoop.mapreduce.lib.output.FileOutputCommitter@1ccb456a}; outputPath=s3a://flight-bucket/refined/airports, workPath=s3a://flight-bucket/refined/airports/_temporary/0/_temporary/attempt_202505252004324112366001342762426_0002_m_000002_6, algorithmVersion=1, skipCleanup=false, ignoreCleanupFailures=false} for s3a://flight-bucket/refined/airports
25/05/25 20:04:32 INFO SQLHadoopMapReduceCommitProtocol: Using output committer class org.apache.hadoop.mapreduce.lib.output.FileOutputCommitter
25/05/25 20:04:32 INFO SQLHadoopMapReduceCommitProtocol: Using output committer class org.apache.hadoop.mapreduce.lib.output.FileOutputCommitter
25/05/25 20:04:32 INFO SQLHadoopMapReduceCommitProtocol: Using output committer class org.apache.hadoop.mapreduce.lib.output.FileOutputCommitter
25/05/25 20:04:32 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/airports/airports.csv, range: 4194304-8388608, partition values: [empty row]
25/05/25 20:04:32 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/airports/airports.csv, range: 8388608-11879081, partition values: [empty row]
25/05/25 20:04:32 INFO CodeGenerator: Code generated in 37.247575 ms
25/05/25 20:04:32 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/airports/airports.csv, range: 0-4194304, partition values: [empty row]
25/05/25 20:04:33 INFO BlockManagerInfo: Removed broadcast_3_piece0 on spark-master:40781 in memory (size: 13.9 KiB, free: 434.2 MiB)
25/05/25 20:04:33 INFO BlockManagerInfo: Removed broadcast_2_piece0 on spark-master:40781 in memory (size: 36.6 KiB, free: 434.3 MiB)
25/05/25 20:04:34 INFO FileOutputCommitter: Saved output of task 'attempt_202505252004324112366001342762426_0002_m_000000_4' to s3a://flight-bucket/refined/airports/_temporary/0/task_202505252004324112366001342762426_0002_m_000000
25/05/25 20:04:34 INFO FileOutputCommitter: Saved output of task 'attempt_202505252004324112366001342762426_0002_m_000002_6' to s3a://flight-bucket/refined/airports/_temporary/0/task_202505252004324112366001342762426_0002_m_000002
25/05/25 20:04:34 INFO SparkHadoopMapRedUtil: attempt_202505252004324112366001342762426_0002_m_000000_4: Committed. Elapsed time: 154 ms.
25/05/25 20:04:34 INFO SparkHadoopMapRedUtil: attempt_202505252004324112366001342762426_0002_m_000002_6: Committed. Elapsed time: 171 ms.
25/05/25 20:04:34 INFO Executor: Finished task 2.0 in stage 2.0 (TID 6). 2545 bytes result sent to driver
25/05/25 20:04:34 INFO Executor: Finished task 0.0 in stage 2.0 (TID 4). 2545 bytes result sent to driver
25/05/25 20:04:34 INFO TaskSetManager: Finished task 2.0 in stage 2.0 (TID 6) in 2031 ms on spark-master (executor driver) (1/3)
25/05/25 20:04:34 INFO TaskSetManager: Finished task 0.0 in stage 2.0 (TID 4) in 2038 ms on spark-master (executor driver) (2/3)
25/05/25 20:04:34 INFO FileOutputCommitter: Saved output of task 'attempt_202505252004324112366001342762426_0002_m_000001_5' to s3a://flight-bucket/refined/airports/_temporary/0/task_202505252004324112366001342762426_0002_m_000001
25/05/25 20:04:34 INFO SparkHadoopMapRedUtil: attempt_202505252004324112366001342762426_0002_m_000001_5: Committed. Elapsed time: 171 ms.
25/05/25 20:04:34 INFO Executor: Finished task 1.0 in stage 2.0 (TID 5). 2502 bytes result sent to driver
25/05/25 20:04:34 INFO TaskSetManager: Finished task 1.0 in stage 2.0 (TID 5) in 2070 ms on spark-master (executor driver) (3/3)
25/05/25 20:04:34 INFO TaskSchedulerImpl: Removed TaskSet 2.0, whose tasks have all completed, from pool
25/05/25 20:04:34 INFO DAGScheduler: ResultStage 2 (json at NativeMethodAccessorImpl.java:0) finished in 2.121 s
25/05/25 20:04:34 INFO DAGScheduler: Job 2 is finished. Cancelling potential speculative or zombie tasks for this job
25/05/25 20:04:34 INFO TaskSchedulerImpl: Killing all running tasks in stage 2: Stage finished
25/05/25 20:04:34 INFO DAGScheduler: Job 2 finished: json at NativeMethodAccessorImpl.java:0, took 2.126592 s
25/05/25 20:04:34 INFO FileFormatWriter: Start to commit write Job d573ff8a-f388-44ab-b6f4-570a18cca3da.
25/05/25 20:04:34 INFO FileFormatWriter: Write Job d573ff8a-f388-44ab-b6f4-570a18cca3da committed. Elapsed time: 383 ms.
25/05/25 20:04:35 INFO FileFormatWriter: Finished processing stats for write job d573ff8a-f388-44ab-b6f4-570a18cca3da.
25/05/25 20:04:35 INFO InMemoryFileIndex: It took 8 ms to list leaf files for 1 paths.
25/05/25 20:04:35 INFO FileSourceStrategy: Pushed Filters:
25/05/25 20:04:35 INFO FileSourceStrategy: Post-Scan Filters:
25/05/25 20:04:35 WARN SparkStringUtils: Truncated the string representation of a plan since it was too large. This behavior can be adjusted by setting 'spark.sql.debug.maxToStringFields'.
25/05/25 20:04:35 INFO ParquetUtils: Using default output committer for Parquet: org.apache.parquet.hadoop.ParquetOutputCommitter
25/05/25 20:04:35 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 20:04:35 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 20:04:35 INFO SQLHadoopMapReduceCommitProtocol: Using user defined output committer class org.apache.parquet.hadoop.ParquetOutputCommitter
25/05/25 20:04:35 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 20:04:35 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 20:04:35 INFO SQLHadoopMapReduceCommitProtocol: Using output committer class org.apache.parquet.hadoop.ParquetOutputCommitter
25/05/25 20:04:35 INFO CodeGenerator: Code generated in 22.777056 ms
25/05/25 20:04:35 INFO MemoryStore: Block broadcast_6 stored as values in memory (estimated size 206.9 KiB, free 433.7 MiB)
25/05/25 20:04:35 INFO MemoryStore: Block broadcast_6_piece0 stored as bytes in memory (estimated size 36.5 KiB, free 433.6 MiB)
25/05/25 20:04:35 INFO BlockManagerInfo: Added broadcast_6_piece0 in memory on spark-master:40781 (size: 36.5 KiB, free: 434.2 MiB)
25/05/25 20:04:35 INFO SparkContext: Created broadcast 6 from parquet at NativeMethodAccessorImpl.java:0
25/05/25 20:04:35 INFO FileSourceScanExec: Planning scan with bin packing, max size: 6481057 bytes, open cost is considered as scanning 4194304 bytes.
25/05/25 20:04:35 INFO SparkContext: Starting job: parquet at NativeMethodAccessorImpl.java:0
25/05/25 20:04:35 INFO DAGScheduler: Got job 3 (parquet at NativeMethodAccessorImpl.java:0) with 3 output partitions
25/05/25 20:04:35 INFO DAGScheduler: Final stage: ResultStage 3 (parquet at NativeMethodAccessorImpl.java:0)
25/05/25 20:04:35 INFO DAGScheduler: Parents of final stage: List()
25/05/25 20:04:35 INFO DAGScheduler: Missing parents: List()
25/05/25 20:04:35 INFO DAGScheduler: Submitting ResultStage 3 (MapPartitionsRDD[16] at parquet at NativeMethodAccessorImpl.java:0), which has no missing parents
25/05/25 20:04:35 INFO MemoryStore: Block broadcast_7 stored as values in memory (estimated size 237.6 KiB, free 433.4 MiB)
25/05/25 20:04:35 INFO MemoryStore: Block broadcast_7_piece0 stored as bytes in memory (estimated size 87.2 KiB, free 433.3 MiB)
25/05/25 20:04:35 INFO BlockManagerInfo: Added broadcast_7_piece0 in memory on spark-master:40781 (size: 87.2 KiB, free: 434.2 MiB)
25/05/25 20:04:35 INFO SparkContext: Created broadcast 7 from broadcast at DAGScheduler.scala:1585
25/05/25 20:04:35 INFO DAGScheduler: Submitting 3 missing tasks from ResultStage 3 (MapPartitionsRDD[16] at parquet at NativeMethodAccessorImpl.java:0) (first 15 tasks are for partitions Vector(0, 1, 2))
25/05/25 20:04:35 INFO TaskSchedulerImpl: Adding task set 3.0 with 3 tasks resource profile 0
25/05/25 20:04:35 INFO TaskSetManager: Starting task 0.0 in stage 3.0 (TID 7) (spark-master, executor driver, partition 0, PROCESS_LOCAL, 10828 bytes)
25/05/25 20:04:35 INFO TaskSetManager: Starting task 1.0 in stage 3.0 (TID 8) (spark-master, executor driver, partition 1, PROCESS_LOCAL, 10828 bytes)
25/05/25 20:04:35 INFO TaskSetManager: Starting task 2.0 in stage 3.0 (TID 9) (spark-master, executor driver, partition 2, PROCESS_LOCAL, 10719 bytes)
25/05/25 20:04:35 INFO Executor: Running task 0.0 in stage 3.0 (TID 7)
25/05/25 20:04:35 INFO Executor: Running task 2.0 in stage 3.0 (TID 9)
25/05/25 20:04:35 INFO Executor: Running task 1.0 in stage 3.0 (TID 8)
25/05/25 20:04:35 INFO CodeGenerator: Code generated in 19.494573 ms
25/05/25 20:04:35 INFO CodeGenerator: Code generated in 18.078025 ms
25/05/25 20:04:35 INFO CodeGenerator: Code generated in 9.423609 ms
25/05/25 20:04:35 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 20:04:35 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 20:04:35 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 20:04:35 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 20:04:35 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 20:04:35 INFO SQLHadoopMapReduceCommitProtocol: Using user defined output committer class org.apache.parquet.hadoop.ParquetOutputCommitter
25/05/25 20:04:35 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 20:04:35 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 20:04:35 INFO SQLHadoopMapReduceCommitProtocol: Using output committer class org.apache.parquet.hadoop.ParquetOutputCommitter
25/05/25 20:04:35 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/flights/flights_2008_5_3.csv, range: 0-989831, partition values: [empty row]
25/05/25 20:04:35 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 20:04:35 INFO SQLHadoopMapReduceCommitProtocol: Using user defined output committer class org.apache.parquet.hadoop.ParquetOutputCommitter
25/05/25 20:04:35 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 20:04:35 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 20:04:35 INFO SQLHadoopMapReduceCommitProtocol: Using output committer class org.apache.parquet.hadoop.ParquetOutputCommitter
25/05/25 20:04:35 INFO SQLHadoopMapReduceCommitProtocol: Using user defined output committer class org.apache.parquet.hadoop.ParquetOutputCommitter
25/05/25 20:04:35 INFO FileOutputCommitter: File Output Committer Algorithm version is 1
25/05/25 20:04:35 INFO FileOutputCommitter: FileOutputCommitter skip cleanup _temporary folders under output directory:false, ignore cleanup failures: false
25/05/25 20:04:35 INFO SQLHadoopMapReduceCommitProtocol: Using output committer class org.apache.parquet.hadoop.ParquetOutputCommitter
25/05/25 20:04:35 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/flights/flights_2008_4_1.csv, range: 0-980792, partition values: [empty row]
25/05/25 20:04:35 INFO CodeGenerator: Code generated in 37.88941 ms
25/05/25 20:04:35 INFO CodeGenerator: Code generated in 41.394222 ms
25/05/25 20:04:35 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/flights/flights_2008_5_2.csv, range: 0-1002531, partition values: [empty row]
25/05/25 20:04:35 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/flights/flights_2008_4_2.csv, range: 0-981534, partition values: [empty row]
25/05/25 20:04:35 INFO FileScanRDD: Reading File path: s3a://flight-bucket/raw/flights/flights_2008_5_1.csv, range: 0-998020, partition values: [empty row]
25/05/25 20:04:35 INFO CodeGenerator: Code generated in 11.443898 ms
25/05/25 20:04:35 INFO CodeGenerator: Code generated in 51.118433 ms
25/05/25 20:04:35 INFO CodecConfig: Compression: SNAPPY
25/05/25 20:04:35 INFO CodecConfig: Compression: SNAPPY
25/05/25 20:04:35 INFO CodecConfig: Compression: SNAPPY
25/05/25 20:04:35 INFO CodecConfig: Compression: SNAPPY
25/05/25 20:04:35 INFO CodecConfig: Compression: SNAPPY
25/05/25 20:04:35 INFO CodecConfig: Compression: SNAPPY
25/05/25 20:04:35 INFO ParquetOutputFormat: ParquetRecordWriter [block size: 134217728b, row group padding size: 8388608b, validating: false]
25/05/25 20:04:35 INFO ParquetOutputFormat: ParquetRecordWriter [block size: 134217728b, row group padding size: 8388608b, validating: false]
25/05/25 20:04:35 INFO ParquetOutputFormat: ParquetRecordWriter [block size: 134217728b, row group padding size: 8388608b, validating: false]
25/05/25 20:04:35 INFO ParquetWriteSupport: Initialized Parquet WriteSupport with Catalyst schema:
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


25/05/25 20:04:35 INFO ParquetWriteSupport: Initialized Parquet WriteSupport with Catalyst schema:
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


25/05/25 20:04:35 INFO ParquetWriteSupport: Initialized Parquet WriteSupport with Catalyst schema:
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


25/05/25 20:04:36 INFO CodecPool: Got brand-new compressor [.snappy]
25/05/25 20:04:36 INFO CodecPool: Got brand-new compressor [.snappy]
25/05/25 20:04:36 INFO CodecPool: Got brand-new compressor [.snappy]
25/05/25 20:04:36 INFO BlockManagerInfo: Removed broadcast_4_piece0 on spark-master:40781 in memory (size: 36.5 KiB, free: 434.2 MiB)
25/05/25 20:04:36 INFO BlockManagerInfo: Removed broadcast_5_piece0 on spark-master:40781 in memory (size: 81.3 KiB, free: 434.3 MiB)
25/05/25 20:04:37 INFO CodecConfig: Compression: SNAPPY
25/05/25 20:04:37 INFO CodecConfig: Compression: SNAPPY
25/05/25 20:04:37 INFO ParquetOutputFormat: ParquetRecordWriter [block size: 134217728b, row group padding size: 8388608b, validating: false]
25/05/25 20:04:37 INFO ParquetWriteSupport: Initialized Parquet WriteSupport with Catalyst schema:
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


25/05/25 20:04:37 INFO FileOutputCommitter: Saved output of task 'attempt_202505252004358431051046600078839_0003_m_000002_9' to s3a://flight-bucket/refined/flights/_temporary/0/task_202505252004358431051046600078839_0003_m_000002
25/05/25 20:04:37 INFO SparkHadoopMapRedUtil: attempt_202505252004358431051046600078839_0003_m_000002_9: Committed. Elapsed time: 130 ms.
25/05/25 20:04:37 INFO Executor: Finished task 2.0 in stage 3.0 (TID 9). 3340 bytes result sent to driver
25/05/25 20:04:37 INFO FileOutputCommitter: Saved output of task 'attempt_202505252004358431051046600078839_0003_m_000000_7' to s3a://flight-bucket/refined/flights/_temporary/0/task_202505252004358431051046600078839_0003_m_000000
25/05/25 20:04:37 INFO SparkHadoopMapRedUtil: attempt_202505252004358431051046600078839_0003_m_000000_7: Committed. Elapsed time: 146 ms.
25/05/25 20:04:37 INFO TaskSetManager: Finished task 2.0 in stage 3.0 (TID 9) in 2059 ms on spark-master (executor driver) (1/3)
25/05/25 20:04:37 INFO Executor: Finished task 0.0 in stage 3.0 (TID 7). 3297 bytes result sent to driver
25/05/25 20:04:37 INFO TaskSetManager: Finished task 0.0 in stage 3.0 (TID 7) in 2064 ms on spark-master (executor driver) (2/3)
25/05/25 20:04:37 INFO FileOutputCommitter: Saved output of task 'attempt_202505252004358431051046600078839_0003_m_000001_8' to s3a://flight-bucket/refined/flights/_temporary/0/task_202505252004358431051046600078839_0003_m_000001
25/05/25 20:04:37 INFO SparkHadoopMapRedUtil: attempt_202505252004358431051046600078839_0003_m_000001_8: Committed. Elapsed time: 206 ms.
25/05/25 20:04:37 INFO Executor: Finished task 1.0 in stage 3.0 (TID 8). 3413 bytes result sent to driver
25/05/25 20:04:37 INFO TaskSetManager: Finished task 1.0 in stage 3.0 (TID 8) in 2414 ms on spark-master (executor driver) (3/3)
25/05/25 20:04:37 INFO TaskSchedulerImpl: Removed TaskSet 3.0, whose tasks have all completed, from pool
25/05/25 20:04:37 INFO DAGScheduler: ResultStage 3 (parquet at NativeMethodAccessorImpl.java:0) finished in 2.453 s
25/05/25 20:04:37 INFO DAGScheduler: Job 3 is finished. Cancelling potential speculative or zombie tasks for this job
25/05/25 20:04:37 INFO TaskSchedulerImpl: Killing all running tasks in stage 3: Stage finished
25/05/25 20:04:37 INFO DAGScheduler: Job 3 finished: parquet at NativeMethodAccessorImpl.java:0, took 2.464661 s
25/05/25 20:04:37 INFO FileFormatWriter: Start to commit write Job 3aa9ce10-45a4-4712-9881-bec6b493bfa7.
25/05/25 20:04:38 INFO FileFormatWriter: Write Job 3aa9ce10-45a4-4712-9881-bec6b493bfa7 committed. Elapsed time: 662 ms.
25/05/25 20:04:38 INFO FileFormatWriter: Finished processing stats for write job 3aa9ce10-45a4-4712-9881-bec6b493bfa7.
25/05/25 20:04:38 INFO SparkContext: SparkContext is stopping with exitCode 0.
25/05/25 20:04:38 INFO SparkUI: Stopped Spark web UI at http://18.196.124.192:4040
25/05/25 20:04:38 INFO MapOutputTrackerMasterEndpoint: MapOutputTrackerMasterEndpoint stopped!
25/05/25 20:04:38 INFO MemoryStore: MemoryStore cleared
25/05/25 20:04:38 INFO BlockManager: BlockManager stopped
25/05/25 20:04:38 INFO BlockManagerMaster: BlockManagerMaster stopped
25/05/25 20:04:38 INFO OutputCommitCoordinator$OutputCommitCoordinatorEndpoint: OutputCommitCoordinator stopped!
25/05/25 20:04:38 INFO SparkContext: Successfully stopped SparkContext
25/05/25 20:04:38 INFO ShutdownHookManager: Shutdown hook called
25/05/25 20:04:38 INFO ShutdownHookManager: Deleting directory /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72
25/05/25 20:04:38 INFO ShutdownHookManager: Deleting directory /tmp/spark-1d94b17e-f4dc-4a4d-8b12-91ea137afb72/pyspark-8417a1cc-7458-44a8-914a-5f4fc8a9c0a2
25/05/25 20:04:38 INFO ShutdownHookManager: Deleting directory /tmp/spark-49b98bbe-0656-42d2-a809-6e2b5beb3d8a
25/05/25 20:04:38 INFO MetricsSystemImpl: Stopping s3a-file-system metrics system...
25/05/25 20:04:38 INFO MetricsSystemImpl: s3a-file-system metrics system stopped.
25/05/25 20:04:38 INFO MetricsSystemImpl: s3a-file-system metrics system shutdown complete.
```


