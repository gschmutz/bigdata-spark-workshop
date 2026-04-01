# Working with Apache Iceberg Table Format

In this workshop we will work with [Apache Iceberg](https://iceberg.apache.org/), an open table format for huge analytic datasets that brings ACID transactions, schema evolution, and time travel to Apache Spark™ and big data workloads.

The same data as in the [Object Storage Workshop](../02a-minio-object-storage/README.md) will be used. We will show later how to re-upload the files, if you no longer have them available.

We assume that you have done Workshop 3 **Getting Started using Spark RDD and DataFrames**, where you have learnt how to use Spark from either `pyspark`, Apache Zeppelin or Jupyter Notebook.

## Prepare the data, if no longer available

The data needed here has been uploaded in workshop 2a - [Working with MinIO Object Storage](../02a-minio-object-storage). You can skip this section, if you still have the data available in MinIO.

Create the flight bucket:

```bash
docker exec -ti awscli s3cmd mb s3://flight-bucket
```

or with `mc`

```bash
docker exec -ti minio-mc mc mb minio-1/flight-bucket
```

**Airports**:

```bash
docker exec -ti awscli s3cmd put /data-transfer/airport-data/airports.csv s3://flight-bucket/raw/airports/airports.csv
```

or with `mc`

```bash
docker exec -ti minio-mc mc cp /data-transfer/airport-data/airports.csv minio-1/flight-bucket/raw/airports/airports.csv
```

## If you want to use `pyspark` instead of Zeppelin

This workshop is written for Zeppelin. If you want to use `pyspark` instead, add the following configuration to the init script:

```python
import os
# get the accessKey and secretKey from Environment
accessKey = os.environ['AWS_ACCESS_KEY_ID']
secretKey = os.environ['AWS_SECRET_ACCESS_KEY']

import pyspark
from pyspark.sql import SparkSession

conf = pyspark.SparkConf()

# point to mesos master or zookeeper entry (e.g., zk://10.10.10.10:2181/mesos)
conf.setMaster("spark://spark-master:7077")

# set other options as desired
conf.set("spark.executor.memory", "8g")
conf.set("spark.executor.cores", "1")
conf.set("spark.core.connection.ack.wait.timeout", "1200")
conf.set("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
conf.set("spark.hadoop.fs.s3a.endpoint", "http://minio-1:9000")
conf.set("spark.hadoop.fs.s3a.path.style.access", "true")
conf.set("spark.hadoop.fs.s3a.access.key", accessKey)
conf.set("spark.hadoop.fs.s3a.secret.key", secretKey)
conf.set("spark.hadoop.fs.s3a.aws.credentials.provider", "org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider")
conf.set("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
conf.set("spark.sql.catalog.iceberg", "org.apache.iceberg.spark.SparkCatalog")
conf.set("spark.sql.catalog.iceberg.type", "hadoop")
conf.set("spark.sql.catalog.iceberg.warehouse", "s3a://flight-bucket/iceberg/warehouse")
conf.set("spark.jars", "/opt/bitnami/spark/jars/iceberg-spark-runtime-3.5_2.12-1.6.1.jar")

spark = SparkSession.builder.appName('Jupyter').config(conf=conf).getOrCreate()
spark.sparkContext.setLogLevel("INFO")

sc = spark.sparkContext
```

For Apache Zeppelin, this is not necessary and the configuration in `spark.jars` is used.

## Create a new Zeppelin notebook

For this workshop we will be using Zeppelin discussed above.

But you can easily adapt it to use either **PySpark** or **Apache Jupyter**.

In a browser window, navigate to <http://dataplatform:28080>.

Now let's create a new notebook by clicking on the **Create new note** link and set the **Note Name** to `SparkIceberg` and set the **Default Interpreter** to `spark`.

Click on **Create Note** and a new Notebook is created with one cell which is empty.

### Add some Markdown first

Navigate to the first cell and start with a title. By using the `%md` directive we can switch to the Markdown interpreter, which can be used for displaying static text.

```
%md # Spark Iceberg sample with airport data
```

Click on the **>** symbol on the right or enter **Shift** + **Enter** to run the paragraph.

The markdown code should now be rendered as a Heading-1 title.

## Read the airport data and store it as an Iceberg Table

First add another title, this time as a Heading-2.

```
%md ## Read the airport data and store it as an Iceberg Table
```

Now let's work with the Airports data, which we have uploaded to `s3://flight-bucket/raw/airports/`.

First import the required Spark Python API. Don't forget to add the `%pyspark` directive in Zeppelin:

```python
from pyspark.sql.types import *
```

Next let's import the airports data into a DataFrame and show the first 5 rows. We use `header=true` to use the header line for naming the columns and specify to infer the schema.

```python
airportsRawDF = spark.read.csv("s3a://flight-bucket/raw/airports",
        sep=",", inferSchema="true", header="true")
airportsRawDF.show(5)
```

The output will show the header line followed by the 5 data lines.

```
+------+-----+-------------+--------------------+-----------------+------------------+------------+---------+-----------+----------+------------+-----------------+--------+---------+----------+--------------------+--------------+--------+
|    id|ident|         type|                name|     latitude_deg|     longitude_deg|elevation_ft|continent|iso_country|iso_region|municipality|scheduled_service|gps_code|iata_code|local_code|           home_link|wikipedia_link|keywords|
+------+-----+-------------+--------------------+-----------------+------------------+------------+---------+-----------+----------+------------+-----------------+--------+---------+----------+--------------------+--------------+--------+
|  6523|  00A|     heliport|   Total RF Heliport|        40.070985|        -74.933689|          11|       NA|         US|     US-PA|    Bensalem|               no|    K00A|     NULL|       00A|https://www.pennd...|          NULL|    NULL|
|323361| 00AA|small_airport|Aero B Ranch Airport|        38.704022|       -101.473911|        3435|       NA|         US|     US-KS|       Leoti|               no|    00AA|     NULL|      00AA|                NULL|          NULL|    NULL|
|  6524| 00AK|small_airport|        Lowell Field|        59.947733|       -151.692524|         450|       NA|         US|     US-AK|Anchor Point|               no|    00AK|     NULL|      00AK|                NULL|          NULL|    NULL|
|  6525| 00AL|small_airport|        Epps Airpark|34.86479949951172|-86.77030181884766|         820|       NA|         US|     US-AL|     Harvest|               no|    00AL|     NULL|      00AL|                NULL|          NULL|    NULL|
|506791| 00AN|small_airport|Katmai Lodge Airport|        59.093287|       -156.456699|          80|       NA|         US|     US-AK| King Salmon|               no|    00AN|     NULL|      00AN|                NULL|          NULL|    NULL|
+------+-----+-------------+--------------------+-----------------+------------------+------------+---------+-----------+----------+------------+-----------------+--------+---------+----------+--------------------+--------------+--------+
only showing top 5 rows
```

Now let's write the data as an Iceberg table. We use the `iceberg` catalog configured above and create a namespace `db` to organise our tables:

```python
spark.sql("CREATE NAMESPACE IF NOT EXISTS iceberg.db")
```

and write the data as an Iceberg table

```python
airportsRawDF.writeTo("iceberg.db.airports").create()
```

Let's view the resulting objects using the `s3cmd` command line tool

```bash
docker exec -ti awscli s3cmd ls --recursive s3://flight-bucket/iceberg/warehouse/db/airports/
```

and you should see that the data has been written as parquet files under a `data/` folder, with an `metadata/` folder holding the Iceberg metadata

```bash
2025-05-22 11:55       3366543  s3://flight-bucket/iceberg/warehouse/db/airports/data/part-00000-a1b2c3d4-e5f6-7890-abcd-ef1234567890.parquet
2025-05-22 11:55       1618896  s3://flight-bucket/iceberg/warehouse/db/airports/data/part-00001-b2c3d4e5-f6a7-8901-bcde-f12345678901.parquet
2025-05-22 11:55          4821  s3://flight-bucket/iceberg/warehouse/db/airports/metadata/00000-a1b2c3d4-e5f6-7890-abcd-ef1234567890.metadata.json
2025-05-22 11:55          6312  s3://flight-bucket/iceberg/warehouse/db/airports/metadata/snap-1234567890123456789-1-a1b2c3d4.avro
2025-05-22 11:55          5987  s3://flight-bucket/iceberg/warehouse/db/airports/metadata/a1b2c3d4-e5f6-7890-abcd-ef1234567890.avro
```

We can also use the MinIO console to see the data.

![Alt Image Text](images/spark-iceberg-1st-write.png "Spark Iceberg 1st write")

click on the `metadata/` folder to see the Iceberg metadata

![Alt Image Text](images/spark-iceberg-1st-write-2.png "Spark Iceberg 1st write metadata")

### Viewing the Iceberg table metadata

Unlike Delta Lake which uses plain JSON files for its transaction log, Iceberg uses a combination of JSON metadata files and Avro manifest files.

Let's download and inspect the initial table metadata JSON file:

```bash
docker exec -ti awscli s3cmd get s3://flight-bucket/iceberg/warehouse/db/airports/metadata/00000-a1b2c3d4-e5f6-7890-abcd-ef1234567890.metadata.json --force /data-transfer/iceberg-metadata.json
```

Let's view the content using the `jq` utility

```bash
cd $DATAPLATFORM_HOME
jq < ./data-transfer/iceberg-metadata.json
```

you should see content similar to the one shown below

```json
{
  "format-version": 2,
  "table-uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "location": "s3a://flight-bucket/iceberg/warehouse/db/airports",
  "last-sequence-number": 1,
  "last-updated-ms": 1747914926643,
  "last-column-id": 18,
  "current-schema-id": 0,
  "schemas": [
    {
      "type": "struct",
      "schema-id": 0,
      "fields": [
        { "id": 1, "name": "id", "required": false, "type": "int" },
        { "id": 2, "name": "ident", "required": false, "type": "string" },
        { "id": 3, "name": "type", "required": false, "type": "string" },
        { "id": 4, "name": "name", "required": false, "type": "string" },
        ...
      ]
    }
  ],
  "default-spec-id": 0,
  "partition-specs": [{ "spec-id": 0, "fields": [] }],
  "current-snapshot-id": 1234567890123456789,
  "snapshots": [
    {
      "snapshot-id": 1234567890123456789,
      "sequence-number": 1,
      "timestamp-ms": 1747914926643,
      "summary": {
        "operation": "append",
        "added-data-files": "2",
        "added-records": "81193",
        "added-files-size": "4985439",
        "total-data-files": "2",
        "total-records": "81193",
        "total-files-size": "4985439"
      },
      "manifest-list": "s3a://flight-bucket/iceberg/warehouse/db/airports/metadata/snap-1234567890123456789-1-a1b2c3d4.avro",
      "schema-id": 0
    }
  ],
  "snapshot-log": [
    {
      "timestamp-ms": 1747914926643,
      "snapshot-id": 1234567890123456789
    }
  ]
}
```

Iceberg also provides convenient metadata tables that you can query directly with SQL. These are much easier to inspect than raw files:

```python
spark.sql("SELECT * FROM iceberg.db.airports.snapshots").show(truncate=False)
```

```
+-------------------+-------------------+-------------------+---------+---------+----------------------------------------------------+
|committed_at       |snapshot_id        |parent_id          |operation|manifest_list                                       |summary                                             |
+-------------------+-------------------+-------------------+---------+---------+----------------------------------------------------+
|2025-05-22 11:55:26|1234567890123456789|null               |append   |s3a://...|{added-data-files -> 2, added-records -> 81193, ...}|
+-------------------+-------------------+-------------------+---------+---------+----------------------------------------------------+
```

```python
spark.sql("SELECT * FROM iceberg.db.airports.history").show(truncate=False)
```

```python
spark.sql("SELECT * FROM iceberg.db.airports.files").show(5, truncate=False)
```

## Update the Iceberg Table

First let's create some updates we want to apply to the Iceberg table. We have a new Airport with the code "ADD" (which does not yet exist) and update the name of the existing airport with code "00A" to uppercase.

```python
newAirportsData = [(999, "ADD", "small_airport", "This is a new airport", 0.0, 0.0, 0, "US", "US", "CA", "San Francisco", "", "", "ADD", "", "", "", ""),
        (6523, "00A", "heliport", "TOTAL RF HELIPORT", 40.070985, -74.933689, 11, "NA", "US", "US-PA", "Bensalem", "no", "K00A", "", "00A", "https://www.penndot.pa.gov/TravelInPA/airports-pa/Pages/Total-RF-Heliport.aspx", "", "")]
```

Let's create a DataFrame from it:

```python
newAirportsRDD = spark.sparkContext.parallelize(newAirportsData)

newAirportsDF = spark.createDataFrame(newAirportsRDD, airportsRawDF.schema)
newAirportsDF.show()
```

This `newAirportsDF` dataframe represents the new raw data we would get from a source system.

Register the new data as a temporary view so we can reference it in the SQL MERGE statement:

```python
newAirportsDF.createOrReplaceTempView("newAirports")
```

Now perform the merge using Iceberg's SQL MERGE INTO statement:

```python
spark.sql("""
    MERGE INTO iceberg.db.airports AS target
    USING newAirports AS source
    ON target.ident = source.ident
    WHEN MATCHED THEN UPDATE SET *
    WHEN NOT MATCHED THEN INSERT *
""")
```

Let's view the resulting objects using the `s3cmd` command line tool

```bash
docker exec -ti awscli s3cmd ls --recursive s3://flight-bucket/iceberg/warehouse/db/airports/
```

and you should see that new data files have been written, and that a new metadata JSON file and a new snapshot Avro file have been created in the `metadata/` folder

```bash
2025-05-22 11:55       3366543  s3://flight-bucket/iceberg/warehouse/db/airports/data/part-00000-a1b2c3d4-e5f6-7890-abcd-ef1234567890.parquet
2025-05-22 11:55       1618896  s3://flight-bucket/iceberg/warehouse/db/airports/data/part-00001-b2c3d4e5-f6a7-8901-bcde-f12345678901.parquet
2025-05-22 18:12       1749796  s3://flight-bucket/iceberg/warehouse/db/airports/data/part-00000-c3d4e5f6-a7b8-9012-cdef-123456789012.parquet
2025-05-22 18:12       1763568  s3://flight-bucket/iceberg/warehouse/db/airports/data/part-00001-d4e5f6a7-b8c9-0123-def0-234567890123.parquet
2025-05-22 18:12        320512  s3://flight-bucket/iceberg/warehouse/db/airports/data/delete-00000-e5f6a7b8.parquet
2025-05-22 11:55          4821  s3://flight-bucket/iceberg/warehouse/db/airports/metadata/00000-a1b2c3d4.metadata.json
2025-05-22 18:12          6103  s3://flight-bucket/iceberg/warehouse/db/airports/metadata/00001-b2c3d4e5.metadata.json
2025-05-22 11:55          6312  s3://flight-bucket/iceberg/warehouse/db/airports/metadata/snap-1234567890123456789-1-a1b2c3d4.avro
2025-05-22 18:12          7841  s3://flight-bucket/iceberg/warehouse/db/airports/metadata/snap-9876543210987654321-1-b2c3d4e5.avro
```

We can also see the snapshots via the metadata table:

![Alt Image Text](images/spark-iceberg-1st-merge.png "Spark Iceberg 1st merge")

```python
spark.sql("SELECT * FROM iceberg.db.airports.snapshots").show(truncate=False)
```

You should now see two snapshots — the initial `append` and a new `overwrite` from the merge:

```
+-------------------+-------------------+-------------------+---------+------------------------------------+
|committed_at       |snapshot_id        |parent_id          |operation|summary                             |
+-------------------+-------------------+-------------------+---------+------------------------------------+
|2025-05-22 11:55:26|1234567890123456789|null               |append   |{added-data-files -> 2, ...}        |
|2025-05-22 18:12:23|9876543210987654321|1234567890123456789|overwrite|{added-data-files -> 3, ...}        |
+-------------------+-------------------+-------------------+---------+------------------------------------+
```

Let's read the Iceberg table and register it as a temporary view so we can query it using SQL:

```python
spark.read.format("iceberg").load("iceberg.db.airports").createOrReplaceTempView("airports")
```

```sql
%sql
SELECT * FROM airports WHERE ident IN ('00A','ADD')
```

and you should see two rows in the result — the updated record and the newly inserted one.

## Compaction of small files

Iceberg can improve the speed of read queries by rewriting small data files into larger ones using the `rewrite_data_files` stored procedure.

```python
spark.sql("""
    CALL iceberg.system.rewrite_data_files(
        table => 'db.airports',
        options => map('target-file-size-bytes', '134217728')
    )
""").show()
```

The output will show how many files were rewritten:

```
+--------------------+--------------------------+-------------------+---------------------+
|rewritten_data_files|added_data_files          |rewritten_bytes    |added_bytes          |
+--------------------+--------------------------+-------------------+---------------------+
|5                   |1                         |8498354            |5124102              |
+--------------------+--------------------------+-------------------+---------------------+
```

## Read older versions of data using time travel

Iceberg time travel allows you to query an older snapshot of an Iceberg table by snapshot ID or timestamp.

First, let's retrieve the snapshot IDs so we know which version to travel to:

```python
snapshots = spark.sql("SELECT snapshot_id, committed_at, operation FROM iceberg.db.airports.snapshots").collect()
for s in snapshots:
    print(s)
```

**Time travel by snapshot ID** — go back to the first snapshot (initial insert):

```python
firstSnapshotId = snapshots[0]["snapshot_id"]

airportsBeforeDF = spark.read.format("iceberg") \
    .option("snapshot-id", firstSnapshotId) \
    .load("iceberg.db.airports")

airportsBeforeDF.createOrReplaceTempView("airportsTimeTravel")
```

if we query for the "00A" and "ADD" codes, we can see that we are getting the original data (no "ADD" airport, original name for "00A"):

```sql
%sql
SELECT * FROM airportsTimeTravel WHERE ident IN ('00A','ADD')
```

**Time travel by timestamp** — you can also use a timestamp string:

```python
airportsBeforeDF = spark.read.format("iceberg") \
    .option("as-of-timestamp", "1747914926643") \
    .load("iceberg.db.airports")

airportsBeforeDF.createOrReplaceTempView("airportsTimeTravel")
```

Or using SQL syntax:

```sql
%sql
SELECT * FROM iceberg.db.airports TIMESTAMP AS OF '2025-05-22 11:55:26'
```

Now let's switch to the latest snapshot and perform another select:

```python
latestSnapshotId = snapshots[-1]["snapshot_id"]

airportsLatestDF = spark.read.format("iceberg") \
    .option("snapshot-id", latestSnapshotId) \
    .load("iceberg.db.airports")

airportsLatestDF.createOrReplaceTempView("airportsTimeTravel")
```

```sql
%sql
SELECT * FROM airportsTimeTravel WHERE ident IN ('00A','ADD')
```

and we can see that we again get the data after the merge operation was applied.

By default, Iceberg retains all snapshots until they are explicitly expired. This means you can always travel back to any point in time, as long as the snapshots have not been expired.

## Expire old snapshots

You can remove snapshots older than a given timestamp using the `expire_snapshots` stored procedure. This is similar to Delta Lake's vacuum command and removes snapshot metadata (and optionally orphan data files) that are no longer needed.

```python
from datetime import datetime, timedelta

# Expire snapshots older than 7 days
expire_before = datetime.now() - timedelta(days=7)
expire_before_ms = int(expire_before.timestamp() * 1000)

spark.sql(f"""
    CALL iceberg.system.expire_snapshots(
        table => 'db.airports',
        older_than => TIMESTAMP '{expire_before.strftime('%Y-%m-%d %H:%M:%S')}'
    )
""").show()
```

The output shows how many snapshots and files were removed:

```
+--------------------+---------------------+------------------+-----------------------+
|deleted_data_files  |deleted_position_files|deleted_manifests |deleted_manifest_lists |
+--------------------+---------------------+------------------+-----------------------+
|2                   |1                    |3                 |1                      |
+--------------------+---------------------+------------------+-----------------------+
```

You can also remove orphan files (data files not referenced by any snapshot) using:

```python
spark.sql("""
    CALL iceberg.system.remove_orphan_files(table => 'db.airports')
""").show()
```

Let's view the resulting objects using the `s3cmd` command line tool after the cleanup:

```bash
docker exec -ti awscli s3cmd ls --recursive s3://flight-bucket/iceberg/warehouse/db/airports/
```

and you should see that the old data files and metadata entries for expired snapshots have been removed.
