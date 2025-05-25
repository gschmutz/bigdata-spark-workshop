# Working with Delta Lake Table Format

In this workshop we will work with [Delta Lake](https://delta.io/), an open-source storage format that brings ACID transactions to Apache Spark™ and big data workloads.. 

The same data as in the [Object Storage Workshop](../03-object-storage/README.md) will be used. We will show later how to re-upload the files, if you no longer have them available.

We assume that you have done Workshop 5 **Getting Started using Spark RDD and DataFrames**, where you have learnt how to use Spark form either `pyspark`, Apache Zeppelin or Jupyter Notebook. 
 
## Prepare the data, if no longer available

The data needed here has been uploaded in workshop 3 - [Working with MinIO Object Storage](03-object-storage). You can skip this section, if you still have the data available in MinIO. 

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
docker exec -ti awscli s3cmd put /data-transfer/airports-data/airports.csv s3://flight-bucket/raw/airports/airports.csv
```

or with `mc`

```bash
docker exec -ti minio-mc mc cp /data-transfer/airports-data/airports.csv minio-1/flight-bucket/raw/airports/airports.csv
```

## If you want to use `pyspark` instead of Zeppelin

This workshop is written for Zeppelin, if you want to use `pyspark` instead, you have to specify the dependencies for Delta Lake.

```python
spark.sparkContext.addPyFile("/spark/jars/delta-spark_2.12-3.2.1.jar")
spark.sparkContext.addPyFile("/spark/jars/delta-storage-3.2.1.jar")
```

For Apache Zeppelin, this is not necessary and the configuration in `spark.jars` is used.

## Create a new Zeppelin notebook

For this workshop we will be using Zeppelin discussed above. 

But you can easily adapt it to use either **PySpark** or **Apache Jupyter**.

In a browser window, navigate to <http://dataplatform:28080>.

Now let's create a new notebook by clicking on the **Create new note** link and set the **Note Name** to `SparkDeltaLake` and set the **Default Interpreter** to `spark`. 

Click on **Create Note** and a new Notebook is created with one cell which is empty. 

### Add some Markdown first

Navigate to the first cell and start with a title. By using the `%md` directive we can switch to the Markdown interpreter, which can be used for displaying static text.

```
%md # Spark Delta Lake sample with airport data
```

Click on the **>** symbol on the right or enter **Shift** + **Enter** to run the paragraph.

The markdown code should now be rendered as a Heading-1 title.

## Read the airport data and store it as a Delta Lake Table

First add another title, this time as a Heading-2.

```
%md ## Read the airport data and store it as a Delta Lake Table
```

Now let's work with the Airports data, which we have uploaded to `s3://flight-bucket/raw/airports/`. 

First we have to import the spark python API. Don't forget to add the `%pyspark` directive in Zeppelin

```python
from delta.tables import *
from pyspark.sql.types import *
```

Next let’s import the flights data into a DataFrame and show the first 5 rows. We use header=true to use the header line for naming the columns and specify to infer the schema.  

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

Create a variable for destination of the Delta table

```python
deltaTableDest = "s3a://flight-bucket/delta/airports"
```

and write the data as a Delta table

```python
airportsRawDF.write.format("delta").save(deltaTableDest)
```

Let's view the resulting objects using the `s3cmd` comnand line tool

```bash
docker exec -ti awscli s3cmd ls --recursive s3://flight-bucket/delta/airports/
```

and you should see that the data has been written as parquet files, but that there is also a `_delta_log` folder holding the transactional metadata for the delta table

```bash
ubuntu@ip-172-26-9-12:~/bigdata-spark-workshop/01-environment/docker/data-transfer/result$ docker exec -ti awscli s3cmd ls --recursive s3://flight-bucket/delta/airports/
2025-05-22 11:55         5472  s3://flight-bucket/delta/airports/_delta_log/00000000000000000000.json
2025-05-22 11:55            0  s3://flight-bucket/delta/airports/_delta_log/_commits/
2025-05-22 11:55      3366543  s3://flight-bucket/delta/airports/part-00000-235e5c19-143e-4930-8733-1922fa83f2af-c000.snappy.parquet
2025-05-22 11:55      1618896  s3://flight-bucket/delta/airports/part-00001-4f29c36d-90a0-45ae-a5a1-cc2b4bcbabcc-c000.snappy.parquet
```

We can also alternatively use the MinIO console to see the data

![Alt Image Text](images/spark-delta-lake-1st-write.png "Spark Delta Lake")

click on the `_delta_log/` folder to see the transaction log metedata

![Alt Image Text](images/spark-delta-lake-1st-write-2.png "Spark Delta Lake")

### Viewing the delta table metadata

As we have seen, there is currently one file (`00000000000000000000.json `) in the `_delta_log` folder, representing the first transaction. 

Let's see what is in this file by using the `s3cmd get` command

```
docker exec -ti awscli s3cmd get s3://flight-bucket/delta/airports/_delta_log/00000000000000000000.json --force /data-transfer/
```

Let's view the content downloaded using the `jq` utility, a json pretty-printer

```
cd $DATAPLATFORM_HOME
jq < ./data-transfer/00000000000000000000.json 
```

you should see content similar to the one shown below

```
{
  "commitInfo": {
    "timestamp": 1747914926643,
    "operation": "WRITE",
    "operationParameters": {
      "mode": "ErrorIfExists",
      "partitionBy": "[]"
    },
    "isolationLevel": "Serializable",
    "isBlindAppend": true,
    "operationMetrics": {
      "numFiles": "2",
      "numOutputRows": "81193",
      "numOutputBytes": "4985439"
    },
    "engineInfo": "Apache-Spark/3.5.3 Delta-Lake/3.2.1",
    "txnId": "af51c609-dc06-4c3a-9e71-878b7f193178"
  }
}
{
  "metaData": {
    "id": "2192da69-2b1d-46ab-906a-3f2a797a26d0",
    "format": {
      "provider": "parquet",
      "options": {}
    },
    "schemaString": "{\"type\":\"struct\",\"fields\":[{\"name\":\"id\",\"type\":\"integer\",\"nullable\":true,\"metadata\":{}},{\"name\":\"ident\",\"type\":\"string\",\"nullable\":true,\"metadata\":{}},{\"name\":\"type\",\"type\":\"string\",\"nullable\":true,\"metadata\":{}},{\"name\":\"name\",\"type\":\"string\",\"nullable\":true,\"metadata\":{}},{\"name\":\"latitude_deg\",\"type\":\"double\",\"nullable\":true,\"metadata\":{}},{\"name\":\"longitude_deg\",\"type\":\"double\",\"nullable\":true,\"metadata\":{}},{\"name\":\"elevation_ft\",\"type\":\"integer\",\"nullable\":true,\"metadata\":{}},{\"name\":\"continent\",\"type\":\"string\",\"nullable\":true,\"metadata\":{}},{\"name\":\"iso_country\",\"type\":\"string\",\"nullable\":true,\"metadata\":{}},{\"name\":\"iso_region\",\"type\":\"string\",\"nullable\":true,\"metadata\":{}},{\"name\":\"municipality\",\"type\":\"string\",\"nullable\":true,\"metadata\":{}},{\"name\":\"scheduled_service\",\"type\":\"string\",\"nullable\":true,\"metadata\":{}},{\"name\":\"gps_code\",\"type\":\"string\",\"nullable\":true,\"metadata\":{}},{\"name\":\"iata_code\",\"type\":\"string\",\"nullable\":true,\"metadata\":{}},{\"name\":\"local_code\",\"type\":\"string\",\"nullable\":true,\"metadata\":{}},{\"name\":\"home_link\",\"type\":\"string\",\"nullable\":true,\"metadata\":{}},{\"name\":\"wikipedia_link\",\"type\":\"string\",\"nullable\":true,\"metadata\":{}},{\"name\":\"keywords\",\"type\":\"string\",\"nullable\":true,\"metadata\":{}}]}",
    "partitionColumns": [],
    "configuration": {},
    "createdTime": 1747914919593
  }
}
{
  "protocol": {
    "minReaderVersion": 1,
    "minWriterVersion": 2
  }
}
{
  "add": {
    "path": "part-00000-235e5c19-143e-4930-8733-1922fa83f2af-c000.snappy.parquet",
    "partitionValues": {},
    "size": 3366543,
    "modificationTime": 1747914925000,
    "dataChange": true,
    "stats": "{\"numRecords\":54024,\"minValues\":{\"id\":2,\"ident\":\"00A\",\"type\":\"balloonport\",\"name\":\"\\\"\\\"\\\"Ghost\\\"\\\" International Airport\",\"latitude_deg\":-89.989444,\"longitude_deg\":-179.876999,\"elevation_ft\":-1266,\"continent\":\"AF\",\"iso_country\":\"AD\",\"iso_region\":\"AD-04\",\"municipality\":\"\\\"\\\"\\\"Jaunkalmes\\\"\\\"\",\"scheduled_service\":\" Lejasciema pag.\",\"gps_code\":\" LV4412\\\"\",\"iata_code\":\"AAA\",\"local_code\":\"00A\",\"home_link\":\"http://GillespieField.com/\",\"wikipedia_link\":\"http://de.wikipedia.org/wiki/Alb\",\"keywords\":\"\\\"\\\"\\\"Alas de Rauch\\\"\\\"\\\"\"},\"maxValues\":{\"id\":558440,\"ident\":\"rjns\",\"type\":\"small_airport\",\"name\":\"​Isla de Desecheo Helipad\",\"latitude_deg\":82.75,\"longitude_deg\":179.9757,\"elevation_ft\":17372,\"continent\":\"SA\",\"iso_country\":\"ZW\",\"iso_region\":\"ZW-MW\",\"municipality\":\"Žocene\",\"scheduled_service\":\"yes\",\"gps_code\":\"ZYXC\",\"iata_code\":\"no\",\"local_code\":\"ZZV\",\"home_link\":\"https:/https://www.dynali.com//w�\",\"wikipedia_link\":\"https://zh.wikipedia.org/wiki/%E�\",\"keywords\":\"황수원비행장, 黃水院飛行場\"},\"nullCount\":{\"id\":0,\"ident\":0,\"type\":0,\"name\":0,\"latitude_deg\":0,\"longitude_deg\":0,\"elevation_ft\":10066,\"continent\":0,\"iso_country\":0,\"iso_region\":0,\"municipality\":2895,\"scheduled_service\":0,\"gps_code\":25018,\"iata_code\":47912,\"local_code\":28459,\"home_link\":50494,\"wikipedia_link\":41736,\"keywords\":40762}}"
  }
}
{
  "add": {
    "path": "part-00001-4f29c36d-90a0-45ae-a5a1-cc2b4bcbabcc-c000.snappy.parquet",
    "partitionValues": {},
    "size": 1618896,
    "modificationTime": 1747914924000,
    "dataChange": true,
    "stats": "{\"numRecords\":27169,\"minValues\":{\"id\":7,\"ident\":\"RK41\",\"type\":\"balloonport\",\"name\":\"\\\"Aeropuerto \\\"\\\"General Tomas de H\",\"latitude_deg\":-80.3142,\"longitude_deg\":-179.5,\"elevation_ft\":-223,\"continent\":\"AF\",\"iso_country\":\"AE\",\"iso_region\":\"AE-AZ\",\"municipality\":\"(Old) Scandium City\",\"scheduled_service\":\"no\",\"gps_code\":\"00AR\",\"iata_code\":\"AAB\",\"local_code\":\"00AR\",\"home_link\":\"http://813.mnd.gov.tw/english/\",\"wikipedia_link\":\"http://es.wikipedia.org/wiki/Aer\",\"keywords\":\"\\\"\\\"\\\"Black Bear Creek\\\"\\\"\\\"\"},\"maxValues\":{\"id\":558726,\"ident\":\"spgl\",\"type\":\"small_airport\",\"name\":\"Želiezovce Cropduster Strip\",\"latitude_deg\":81.15,\"longitude_deg\":179.292999,\"elevation_ft\":14965,\"continent\":\"SA\",\"iso_country\":\"ZW\",\"iso_region\":\"ZW-MW\",\"municipality\":\"Охá\",\"scheduled_service\":\"yes\",\"gps_code\":\"ZYYY\",\"iata_code\":\"ZZO\",\"local_code\":\"ZUL\",\"home_link\":\"https://za.geoview.info/himevill�\",\"wikipedia_link\":\"https://zh.wikipedia.org/wiki/%E�\",\"keywords\":\"김해국제공항, 金海國際空港, Kimhae, Pusan\"},\"nullCount\":{\"id\":0,\"ident\":0,\"type\":0,\"name\":0,\"latitude_deg\":0,\"longitude_deg\":0,\"elevation_ft\":4522,\"continent\":0,\"iso_country\":0,\"iso_region\":0,\"municipality\":2105,\"scheduled_service\":0,\"gps_code\":13315,\"iata_code\":24177,\"local_code\":18357,\"home_link\":26464,\"wikipedia_link\":23022,\"keywords\":21120}}"
  }
}
```

You can see besides some metadata, the first transaction applied represented by the `add` fragement.


## Update the Delta Lake Table

First let's create some updates we want to apply to the delta table. We have a new Airport with the code "ADD" (which does not yet exists) and update the name and city of the existing airport with code "00M" to uppercase.

```
newAirportsData = [(999, "ADD", "small_airport", "This is a new airport", 0.0, 0.0, 0, "US", "US", "CA", "San Francisco", "", "", "ADD", "", "", "", ""),
        (6523, "00A", "heliport", "TOTAL RF HELIPORT", 40.070985, -74.933689, 11, "NA", "US", "US-PA", "Bensalem", "no", "K00A", "", "00A", "https://www.penndot.pa.gov/TravelInPA/airports-pa/Pages/Total-RF-Heliport.aspx", "", "")]
```

Let's create a data frame from it. 

```
newAirportsRDD = spark.sparkContext.parallelize(newAirportsData)

newAirportsDF = spark.createDataFrame(newAirportsRDD, airportsRawDF.schema)
newAirportsDF.show() 
```

This `newAirportsDF` dataframe represents the new raw data we would get from a source system.

Now let's update the delta lake table. 
First let's get a reference to the delta table

```
from delta.tables import *
from pyspark.sql.functions import *

deltaTable = DeltaTable.forPath(spark, deltaTableDest)
```

and now perform the merge

```
deltaTable.alias("oldData").merge(
    newAirportsDF.alias("newData"),
    "oldData.ident = newData.ident") \
    	.whenMatchedUpdateAll() \
    	.whenNotMatchedInsertAll() \
    	.execute()
```

Let's view the resulting objects using the `s3cmd` comnand line tool

```bash
docker exec -ti awscli s3cmd ls --recursive s3://flight-bucket/delta/airports/
```

and you should see that more data has been written as parquet files, and that in the `_delta_log` folder an addional json file has been created

```bash
ubuntu@ip-172-26-9-12:~/bigdata-spark-workshop/01-environment/docker$ docker exec -ti awscli s3cmd ls --recursive s3://flight-bucket/delta/airports/
2025-05-22 11:55         5472  s3://flight-bucket/delta/airports/_delta_log/00000000000000000000.json
2025-05-22 18:12         4597  s3://flight-bucket/delta/airports/_delta_log/00000000000000000001.json
2025-05-22 11:55            0  s3://flight-bucket/delta/airports/_delta_log/_commits/
2025-05-22 11:55      3366543  s3://flight-bucket/delta/airports/part-00000-235e5c19-143e-4930-8733-1922fa83f2af-c000.snappy.parquet
2025-05-22 18:12      1749796  s3://flight-bucket/delta/airports/part-00000-e4fc9ba1-f182-40b5-bb4f-cc7a4ba55a44-c000.snappy.parquet
2025-05-22 18:12      1763568  s3://flight-bucket/delta/airports/part-00001-3a745dd6-9d22-4a00-8ca4-253a6fa1232e-c000.snappy.parquet
2025-05-22 11:55      1618896  s3://flight-bucket/delta/airports/part-00001-4f29c36d-90a0-45ae-a5a1-cc2b4bcbabcc-c000.snappy.parquet
```

We can also alternatively use the MinIO console to see the data

![Alt Image Text](images/spark-delta-lake-1st-merge.png "Spark Delta Lake")

click on the `_delta_log/` folder to see the transaction log metedata

![Alt Image Text](images/spark-delta-lake-1st-merge-2.png "Spark Delta Lake")

As we have seen, there is anew file (`00000000000000000001.json `) in the `_delta_log` folder, representing the first transaction. 

Let's see what is in this file by using the `s3cmd get` command

```
docker exec -ti awscli s3cmd get s3://flight-bucket/delta/airports/_delta_log/00000000000000000001.json --force /data-transfer/
```

Let's view the content downloaded using the `jq` utility, a json pretty-printer

```
cd $DATAPLATFORM_HOME
jq < ./data-transfer/00000000000000000001.json 
```

you should see content similar to the one shown below
 
```
ubuntu@ip-172-26-9-12:~/bigdata-spark-workshop/01-environment/docker$ jq < ./data-transfer/00000000000000000001.json 
{
  "commitInfo": {
    "timestamp": 1747937543885,
    "operation": "MERGE",
    "operationParameters": {
      "predicate": "[\"(ident#850 = ident#693)\"]",
      "matchedPredicates": "[{\"actionType\":\"update\"}]",
      "notMatchedPredicates": "[{\"actionType\":\"insert\"}]",
      "notMatchedBySourcePredicates": "[]"
    },
    "readVersion": 0,
    "isolationLevel": "Serializable",
    "isBlindAppend": false,
    "operationMetrics": {
      "numTargetRowsCopied": "54023",
      "numTargetRowsDeleted": "0",
      "numTargetFilesAdded": "2",
      "numTargetBytesAdded": "3513364",
      "numTargetBytesRemoved": "3366543",
      "numTargetDeletionVectorsAdded": "0",
      "numTargetRowsMatchedUpdated": "1",
      "executionTimeMs": "39343",
      "numTargetRowsInserted": "1",
      "numTargetRowsMatchedDeleted": "0",
      "numTargetDeletionVectorsUpdated": "0",
      "scanTimeMs": "29256",
      "numTargetRowsUpdated": "1",
      "numOutputRows": "54025",
      "numTargetDeletionVectorsRemoved": "0",
      "numTargetRowsNotMatchedBySourceUpdated": "0",
      "numTargetChangeFilesAdded": "0",
      "numSourceRows": "2",
      "numTargetFilesRemoved": "1",
      "numTargetRowsNotMatchedBySourceDeleted": "0",
      "rewriteTimeMs": "8703"
    },
    "engineInfo": "Apache-Spark/3.5.3 Delta-Lake/3.2.1",
    "txnId": "261addf6-33d3-42ab-90e1-8124815fa6dc"
  }
}
{
  "add": {
    "path": "part-00000-e4fc9ba1-f182-40b5-bb4f-cc7a4ba55a44-c000.snappy.parquet",
    "partitionValues": {},
    "size": 1749796,
    "modificationTime": 1747937543000,
    "dataChange": true,
    "stats": "{\"numRecords\":26958,\"minValues\":{\"id\":11,\"ident\":\"00AA\",\"type\":\"balloonport\",\"name\":\"\\\"\\\"\\\"Ghost\\\"\\\" International Airport\",\"latitude_deg\":-78.466139,\"longitude_deg\":-179.876999,\"elevation_ft\":-1266,\"continent\":\"AF\",\"iso_country\":\"AD\",\"iso_region\":\"AD-08\",\"municipality\":\"\\\"Academia Militar \\\"\\\"Mcal. Franci\",\"scheduled_service\":\"no\",\"gps_code\":\"00AA\",\"iata_code\":\"AAD\",\"local_code\":\"00AA\",\"home_link\":\"http://GillespieField.com/\",\"wikipedia_link\":\"http://de.wikipedia.org/wiki/Ber\",\"keywords\":\"\\\"\\\"\\\"Garçon\\\"\\\"\\\"\"},\"maxValues\":{\"id\":558333,\"ident\":\"mdwo\",\"type\":\"small_airport\",\"name\":\"Želeč Airstrip\",\"latitude_deg\":81.697844,\"longitude_deg\":179.951004028,\"elevation_ft\":17372,\"continent\":\"SA\",\"iso_country\":\"ZW\",\"iso_region\":\"ZW-MW\",\"municipality\":\"Želeč\",\"scheduled_service\":\"yes\",\"gps_code\":\"ZYXC\",\"iata_code\":\"ZZU\",\"local_code\":\"ZVOL\",\"home_link\":\"https:/https://www.dynali.com//w�\",\"wikipedia_link\":\"https://zh.wikipedia.org/wiki/%E�\",\"keywords\":\"의주비행장, 義州飛行場\"},\"nullCount\":{\"id\":0,\"ident\":0,\"type\":0,\"name\":0,\"latitude_deg\":0,\"longitude_deg\":0,\"elevation_ft\":5019,\"continent\":0,\"iso_country\":0,\"iso_region\":0,\"municipality\":1445,\"scheduled_service\":0,\"gps_code\":12403,\"iata_code\":23930,\"local_code\":14195,\"home_link\":25254,\"wikipedia_link\":20796,\"keywords\":20343}}"
  }
}
{
  "add": {
    "path": "part-00001-3a745dd6-9d22-4a00-8ca4-253a6fa1232e-c000.snappy.parquet",
    "partitionValues": {},
    "size": 1763568,
    "modificationTime": 1747937542000,
    "dataChange": true,
    "stats": "{\"numRecords\":27067,\"minValues\":{\"id\":2,\"ident\":\"00A\",\"type\":\"balloonport\",\"name\":\"\\\"Aeródromo \\\"\\\"Puente de Genave\\\"\\\"\\\"\",\"latitude_deg\":-89.989444,\"longitude_deg\":-179.667007,\"elevation_ft\":-1207,\"continent\":\"AF\",\"iso_country\":\"AD\",\"iso_region\":\"AD-04\",\"municipality\":\"\\\"\\\"\\\"Jaunkalmes\\\"\\\"\",\"scheduled_service\":\"\",\"gps_code\":\"\",\"iata_code\":\"\",\"local_code\":\"\",\"home_link\":\"\",\"wikipedia_link\":\"\",\"keywords\":\"\"},\"maxValues\":{\"id\":558440,\"ident\":\"rjns\",\"type\":\"small_airport\",\"name\":\"​Isla de Desecheo Helipad\",\"latitude_deg\":82.75,\"longitude_deg\":179.9757,\"elevation_ft\":16200,\"continent\":\"US\",\"iso_country\":\"ZW\",\"iso_region\":\"ZW-MW\",\"municipality\":\"Žocene\",\"scheduled_service\":\"yes\",\"gps_code\":\"ZYUH\",\"iata_code\":\"no\",\"local_code\":\"ZZV\",\"home_link\":\"https://yyb.ca/\",\"wikipedia_link\":\"https://zh.wikipedia.org/wiki/%E�\",\"keywords\":\"황수원비행장, 黃水院飛行場\"},\"nullCount\":{\"id\":0,\"ident\":0,\"type\":0,\"name\":0,\"latitude_deg\":0,\"longitude_deg\":0,\"elevation_ft\":5047,\"continent\":0,\"iso_country\":0,\"iso_region\":0,\"municipality\":1450,\"scheduled_service\":0,\"gps_code\":12615,\"iata_code\":23981,\"local_code\":14264,\"home_link\":25240,\"wikipedia_link\":20939,\"keywords\":20418}}"
  }
}
{
  "remove": {
    "path": "part-00000-235e5c19-143e-4930-8733-1922fa83f2af-c000.snappy.parquet",
    "deletionTimestamp": 1747937543788,
    "dataChange": true,
    "extendedFileMetadata": true,
    "partitionValues": {},
    "size": 3366543,
    "stats": "{\"numRecords\":54024}"
  }
} 
``` 

Let's read the delta table and register it as a table, so we can query it using SQL

``` 
spark.read.format("delta").load(deltaTableDest).createOrReplaceTempView("airports")
``` 

```sql
%sql
SELECT * FROM airports WHERE ident IN ("00A","ADD")
``` 

and you should see two rows in the result. One is the new record added and the other one the updated row.

## Compaction of small files

Delta Lake can improve the speed of read queries from a table by coalescing small files into larger ones.

```python
from delta.tables import *

deltaTable = DeltaTable.forPath(spark, deltaTableDest)  # For path-based tables
# For Hive metastore-based tables: deltaTable = DeltaTable.forName(spark, tableName)

deltaTable.optimize().executeCompaction()
```

## Read older versions of data using time travel

Delta Lake time travel allows you to query an older snapshot of a Delta table.

Let's go back to version 0, the version of our first insert of the data and register it as a new table `airportsTimeTravel`

```python
airportsBeforeDF = spark.read.format("delta").option("versionAsOf", 0).load(deltaTableDest)

airportsBeforeDF.createOrReplaceTempView("airportsTimeTravel")
```

if we query for the "00A" and "ADD" code, we can see that we are getting the original data

```sql
%sql
SELECT * FROM airportsTimeTravel WHERE ident IN ("00A","ADD")
``` 

now let's swtich to version 1, register the table

```python
airportsBeforeDF = spark.read.format("delta").option("versionAsOf", 1).load(deltaTableDest)

airportsBeforeDF.createOrReplaceTempView("airportsTimeTravel")
```

and perform another select and we can see that we again get the data after the merge operation applied

``` 
%sql
SELECT * FROM airportsTimeTravel WHERE ident IN ("00A","ADD")
``` 

By default, Delta tables retain the commit history for 30 days. This means that you can specify a version from 30 days ago. 

## Vacuum old versions

You can remove files no longer referenced by a Delta table and are older than the retention threshold by running the vacuum command on the table. vacuum is not triggered automatically. The default retention threshold for the files is 7 days.

```python
from delta.tables import *

deltaTable = DeltaTable.forPath(spark, deltaTableDest) 
```

vacuum files not required by versions older than the default retention period

```python
deltaTable.vacuum()        # vacuum files not required by versions older than the default 
```
vacuum files not required by versions more than 1 hours old

```python
deltaTable.vacuum(1)
``` 

Let's view the resulting objects using the `s3cmd` comnand line tool

```bash
docker exec -ti awscli s3cmd ls --recursive s3://flight-bucket/delta/airports/
```

and you should see that more data has been written as parquet files, and that in the `_delta_log` folder an addional json file has been created

```bash
ubuntu@ip-172-26-9-12:~/bigdata-spark-workshop/01-environment/docker$ docker exec -ti awscli s3cmd ls --recursive s3://flight-bucket/delta/airports/
2025-05-22 11:55         5472  s3://flight-bucket/delta/airports/_delta_log/00000000000000000000.json
2025-05-22 18:12         4597  s3://flight-bucket/delta/airports/_delta_log/00000000000000000001.json
2025-05-22 18:18         2893  s3://flight-bucket/delta/airports/_delta_log/00000000000000000002.json
2025-05-22 11:55            0  s3://flight-bucket/delta/airports/_delta_log/_commits/
2025-05-22 11:55      3366543  s3://flight-bucket/delta/airports/part-00000-235e5c19-143e-4930-8733-1922fa83f2af-c000.snappy.parquet
2025-05-22 18:18      5018495  s3://flight-bucket/delta/airports/part-00000-ccf77767-2ddf-4338-bac0-a103c24b4472-c000.snappy.parquet
2025-05-22 18:12      1749796  s3://flight-bucket/delta/airports/part-00000-e4fc9ba1-f182-40b5-bb4f-cc7a4ba55a44-c000.snappy.parquet
2025-05-22 18:12      1763568  s3://flight-bucket/delta/airports/part-00001-3a745dd6-9d22-4a00-8ca4-253a6fa1232e-c000.snappy.parquet
2025-05-22 11:55      1618896  s3://flight-bucket/delta/airports/part-00001-4f29c36d-90a0-45ae-a5a1-cc2b4bcbabcc-c000.snappy.parquet
```

Let's see what is in this file by using the `s3cmd get` command

```
docker exec -ti awscli s3cmd get s3://flight-bucket/delta/airports/_delta_log/00000000000000000002.json --force /data-transfer/
```

Let's view the content downloaded using the `jq` utility, a json pretty-printer

```
cd $DATAPLATFORM_HOME
jq < ./data-transfer/00000000000000000002.json 
```

