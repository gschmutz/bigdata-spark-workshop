# Working with different data types

In this workshop we will working with various data types. 

We assume that the **Data Platform** described [here](../01-environment) is running and accessible. 

We only show the pure PySpark statement, if you want to execute the in Zepplin, then you have to add the `%pyspark` directive. 


# Prepare the data, if no longer available

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

or with `mc`

```bash
docker exec -ti minio-mc mc cp /data-transfer/airports-data/airports.csv minio-1/flight-bucket/raw/airports/airports.csv
```

## Read CSV File

Let's read the raw airport data in CSV file format. You can either use Zeppelin, Jupyter or pyspark CLI for that. 

```python
from pyspark.sql.types import *
airportsRawDF = spark.read.csv("file:///data-transfer/airports-data/airports.csv", 
    	sep=",", inferSchema="true", header="true")
airportsRawDF.show(5)
```

Don't forget to add the `%pyspark` directive if you use Zeppelin.

Let's check the schema of this dataframe

```python
airportsRawDF.printSchema()
```

and you should get

```bash
root
 |-- id: integer (nullable = true)
 |-- ident: string (nullable = true)
 |-- type: string (nullable = true)
 |-- name: string (nullable = true)
 |-- latitude_deg: double (nullable = true)
 |-- longitude_deg: double (nullable = true)
 |-- elevation_ft: integer (nullable = true)
 |-- continent: string (nullable = true)
 |-- iso_country: string (nullable = true)
 |-- iso_region: string (nullable = true)
 |-- municipality: string (nullable = true)
 |-- scheduled_service: string (nullable = true)
 |-- gps_code: string (nullable = true)
 |-- iata_code: string (nullable = true)
 |-- local_code: string (nullable = true)
 |-- home_link: string (nullable = true)
 |-- wikipedia_link: string (nullable = true)
 |-- keywords: string (nullable = true)
``` 

Let's create another new bucket to store the results of this workshop

```bash
docker exec -ti minio-mc mc mb minio-1/datatype-bucket
```

## Write as JSON

Store the data using the `json` data type:

```python
airportsRawDF.write.json("s3a://datatype-bucket/json")
```

Let's view the data created in the bucket

```
docker exec -ti awscli s3cmd ls s3://datatype-bucket/json/
```

and you should see a result similar to the one shown below

```bash
ubuntu@ip-172-26-9-171:~/bigdata-spark-workshop/01-environment/docker$ docker exec -ti awscli s3cmd ls s3://datatype-bucket/json/
2025-05-19 20:22            0  s3://datatype-bucket/json/_SUCCESS
2025-05-19 20:22     16767132  s3://datatype-bucket/json/part-00000-6a7a29b7-d94b-42d9-a7f6-40281a1fa0ff-c000.json
2025-05-19 20:22      8106536  s3://datatype-bucket/json/part-00001-6a7a29b7-d94b-42d9-a7f6-40281a1fa0ff-c000.json
```

Let's view the content of one of the objects (make sure to adapt the object name)

```bash
docker exec -ti awscli s3cmd get s3://datatype-bucket/json/part-00000-6a7a29b7-d94b-42d9-a7f6-40281a1fa0ff-c000.json - | less
```

## Write as Avro

Store the data using the `avro` data type:

```python
airportsRawDF.write.format("avro").save("s3a://datatype-bucket/avro")
```

Let's view the data created in the bucket

```
docker exec -ti awscli s3cmd ls s3://datatype-bucket/avro/
```

and you should see a result similar to the one shown below

```bash
ubuntu@ip-172-26-9-171:~/bigdata-spark-workshop/01-environment/docker$ docker exec -ti awscli s3cmd ls s3://datatype-bucket/avro/
2025-05-19 20:31            0  s3://datatype-bucket/avro/_SUCCESS
2025-05-19 20:31      3539632  s3://datatype-bucket/avro/part-00000-4e0989a0-7992-4fcb-bfb6-d92db095acab-c000.avro
2025-05-19 20:31      1731266  s3://datatype-bucket/avro/part-00001-4e0989a0-7992-4fcb-bfb6-d92db095acab-c000.avro
```

Let's download the files to the local folder

```bash
cd $DATAPLATFORM_HOME
sudo mkdir -p data-transfer/result/avro
docker exec -ti awscli s3cmd get --recursive --force s3://datatype-bucket/avro/ data-transfer/result/avro
```

check for the output using the `tree` command.

```bash
cd data-transfer/result
tree avro
```

```bash
ubuntu@ip-172-26-9-171:~/bigdata-spark-workshop/01-environment/docker$ cd data-transfer/result
tree avro
avro
├── _SUCCESS
├── part-00000-4e0989a0-7992-4fcb-bfb6-d92db095acab-c000.avro
└── part-00001-4e0989a0-7992-4fcb-bfb6-d92db095acab-c000.avro
```

Let's see the first 2 lines of the avro file. 

```bash
head -n 2 avro/part-00000-4e0989a0-7992-4fcb-bfb6-d92db095acab-c000.avro
```

We can see in the result that the data first holds the Avro schema followed by the binary serialized data

```bash
ubuntu@ip-172-26-9-171:~/bigdata-spark-workshop/01-environment/docker/data-transfer/result$ head -n 2 avro/part-00000-4e0989a0-7992-4fcb-bfb6-d92db095acab-c000.avro
{"type":"record","name":"topLevelRecord","fields":[{"name":"id","type":["int","null"]},{"name":"ident","type":["string","null"]},{"name":"type","type":["string","null"]},{"name":"name","type":["string","null"]},{"name":"latitude_deg","type":["double","null"]},{"name":"longitude_deg","type":["double","null"]},{"name":"elevation_ft","type":["int","null"]},{"name":"continent","type":["string","null"]},{"name":"iso_country","type":["string","null"]},{"name":"iso_region","type":["string","null"]},{"name":"municipality","type":["string","null"]},{"name":"scheduled_service","type":["string","null"]},{"name":"gps_code","type":["string","null"]},{"name":"iata_code","type":["string","null"]},{"name":"local_code","type":["string","null"]},{"name":"home_link","type":["string","null"]},{"name":"wikipedia_link","type":["string","null"]},{"name":"keywords","type":["string","null"]}]}0org.apache.spark.version
3.5.3avro.codec
               snappyA�Y�$<�D��})1����t�e00Aheliport"Total RF H���V             D@�聏��R�NAUS
```

Let's use the Avro tools to inspect the Avro files. `avro-tools` is running as a container, therefore we can just run it.

```bash
docker compose run --rm avro-tools
```

you should see the help page of the `avro-tools`

```bash
$ docker compose run --rm avro-tools
Version 1.11.1 of Apache Avro
Copyright 2010-2015 The Apache Software Foundation

This product includes software developed at
The Apache Software Foundation (https://www.apache.org/).
----------------
Available tools:
    canonical  Converts an Avro Schema to its canonical form
          cat  Extracts samples from files
      compile  Generates Java code for the given schema.
       concat  Concatenates avro files without re-compressing.
        count  Counts the records in avro files or folders
  fingerprint  Returns the fingerprint for the schemas.
   fragtojson  Renders a binary-encoded Avro datum as JSON.
     fromjson  Reads JSON records and writes an Avro data file.
     fromtext  Imports a text file into an avro data file.
      getmeta  Prints out the metadata of an Avro data file.
    getschema  Prints out schema of an Avro data file.
          idl  Generates a JSON schema from an Avro IDL file
 idl2schemata  Extract JSON schemata of the types from an Avro IDL file
       induce  Induce schema/protocol from Java class/interface via reflection.
   jsontofrag  Renders a JSON-encoded Avro datum as binary.
       random  Creates a file with randomly generated instances of a schema.
      recodec  Alters the codec of a data file.
       repair  Recovers data from a corrupt Avro Data file
  rpcprotocol  Output the protocol of a RPC service
   rpcreceive  Opens an RPC Server and listens for one message.
      rpcsend  Sends a single RPC message.
       tether  Run a tethered mapreduce job.
       tojson  Dumps an Avro data file as JSON, record per line or pretty.
       totext  Converts an Avro data file to a text file.
     totrevni  Converts an Avro data file to a Trevni file.
  trevni_meta  Dumps a Trevni file's metadata as JSON.
trevni_random  Create a Trevni file filled with random instances of a schema.
trevni_tojson  Dumps a Trevni file as JSON.
```

To see how many records are in an Avro file, use the `count` tool (replace the name of the file)

```
docker compose run --rm  avro-tools count /data-transfer/result/avro/part-00000-4e0989a0-7992-4fcb-bfb6-d92db095acab-c000.avro
```

and you should get a count of `54024`

```bash
ubuntu@ip-172-26-9-171:~/bigdata-spark-workshop/01-environment/docker$ docker compose run --rm  avro-tools count /data-transfer/result/avro/part-00000-4e0989a0-7992-4fcb-bfb6-d92db095acab-c000.avro
WARN[0000] The "AIRFLOW_UID" variable is not set. Defaulting to a blank string. 
25/05/20 05:26:11 WARN util.NativeCodeLoader: Unable to load native-hadoop library for your platform... using builtin-java classes where applicable
54024
```

Let's use `tojson`to dump the Avro file as JSON, one line per record and only showing the first 10 records (using the `--head` option)

```
docker compose run --rm avro-tools tojson --head /data-transfer/result/avro/part-00000-4e0989a0-7992-4fcb-bfb6-d92db095acab-c000.avro
```

```bash
ubuntu@ip-172-26-9-171:~/bigdata-spark-workshop/01-environment/docker$ docker compose run --rm avro-tools tojson --head /data-transfer/result/avro/part-00000-4e0989a0-7992-4fcb-bfb6-d92db095acab-c000.avro
WARN[0000] The "AIRFLOW_UID" variable is not set. Defaulting to a blank string. 
25/05/20 05:27:17 WARN util.NativeCodeLoader: Unable to load native-hadoop library for your platform... using builtin-java classes where applicable
{"id":{"int":6523},"ident":{"string":"00A"},"type":{"string":"heliport"},"name":{"string":"Total RF Heliport"},"latitude_deg":{"double":40.070985},"longitude_deg":{"double":-74.933689},"elevation_ft":{"int":11},"continent":{"string":"NA"},"iso_country":{"string":"US"},"iso_region":{"string":"US-PA"},"municipality":{"string":"Bensalem"},"scheduled_service":{"string":"no"},"gps_code":{"string":"K00A"},"iata_code":null,"local_code":{"string":"00A"},"home_link":{"string":"https://www.penndot.pa.gov/TravelInPA/airports-pa/Pages/Total-RF-Heliport.aspx"},"wikipedia_link":null,"keywords":null}
{"id":{"int":323361},"ident":{"string":"00AA"},"type":{"string":"small_airport"},"name":{"string":"Aero B Ranch Airport"},"latitude_deg":{"double":38.704022},"longitude_deg":{"double":-101.473911},"elevation_ft":{"int":3435},"continent":{"string":"NA"},"iso_country":{"string":"US"},"iso_region":{"string":"US-KS"},"municipality":{"string":"Leoti"},"scheduled_service":{"string":"no"},"gps_code":{"string":"00AA"},"iata_code":null,"local_code":{"string":"00AA"},"home_link":null,"wikipedia_link":null,"keywords":null}
{"id":{"int":6524},"ident":{"string":"00AK"},"type":{"string":"small_airport"},"name":{"string":"Lowell Field"},"latitude_deg":{"double":59.947733},"longitude_deg":{"double":-151.692524},"elevation_ft":{"int":450},"continent":{"string":"NA"},"iso_country":{"string":"US"},"iso_region":{"string":"US-AK"},"municipality":{"string":"Anchor Point"},"scheduled_service":{"string":"no"},"gps_code":{"string":"00AK"},"iata_code":null,"local_code":{"string":"00AK"},"home_link":null,"wikipedia_link":null,"keywords":null}
{"id":{"int":6525},"ident":{"string":"00AL"},"type":{"string":"small_airport"},"name":{"string":"Epps Airpark"},"latitude_deg":{"double":34.86479949951172},"longitude_deg":{"double":-86.77030181884766},"elevation_ft":{"int":820},"continent":{"string":"NA"},"iso_country":{"string":"US"},"iso_region":{"string":"US-AL"},"municipality":{"string":"Harvest"},"scheduled_service":{"string":"no"},"gps_code":{"string":"00AL"},"iata_code":null,"local_code":{"string":"00AL"},"home_link":null,"wikipedia_link":null,"keywords":null}
{"id":{"int":506791},"ident":{"string":"00AN"},"type":{"string":"small_airport"},"name":{"string":"Katmai Lodge Airport"},"latitude_deg":{"double":59.093287},"longitude_deg":{"double":-156.456699},"elevation_ft":{"int":80},"continent":{"string":"NA"},"iso_country":{"string":"US"},"iso_region":{"string":"US-AK"},"municipality":{"string":"King Salmon"},"scheduled_service":{"string":"no"},"gps_code":{"string":"00AN"},"iata_code":null,"local_code":{"string":"00AN"},"home_link":null,"wikipedia_link":null,"keywords":null}
{"id":{"int":6526},"ident":{"string":"00AR"},"type":{"string":"closed"},"name":{"string":"Newport Hospital & Clinic Heliport"},"latitude_deg":{"double":35.6087},"longitude_deg":{"double":-91.254898},"elevation_ft":{"int":237},"continent":{"string":"NA"},"iso_country":{"string":"US"},"iso_region":{"string":"US-AR"},"municipality":{"string":"Newport"},"scheduled_service":{"string":"no"},"gps_code":null,"iata_code":null,"local_code":null,"home_link":null,"wikipedia_link":null,"keywords":{"string":"00AR"}}
{"id":{"int":322127},"ident":{"string":"00AS"},"type":{"string":"small_airport"},"name":{"string":"Fulton Airport"},"latitude_deg":{"double":34.9428028},"longitude_deg":{"double":-97.8180194},"elevation_ft":{"int":1100},"continent":{"string":"NA"},"iso_country":{"string":"US"},"iso_region":{"string":"US-OK"},"municipality":{"string":"Alex"},"scheduled_service":{"string":"no"},"gps_code":{"string":"00AS"},"iata_code":null,"local_code":{"string":"00AS"},"home_link":null,"wikipedia_link":null,"keywords":null}
{"id":{"int":6527},"ident":{"string":"00AZ"},"type":{"string":"small_airport"},"name":{"string":"Cordes Airport"},"latitude_deg":{"double":34.305599212646484},"longitude_deg":{"double":-112.16500091552734},"elevation_ft":{"int":3810},"continent":{"string":"NA"},"iso_country":{"string":"US"},"iso_region":{"string":"US-AZ"},"municipality":{"string":"Cordes"},"scheduled_service":{"string":"no"},"gps_code":{"string":"00AZ"},"iata_code":null,"local_code":{"string":"00AZ"},"home_link":null,"wikipedia_link":null,"keywords":null}
{"id":{"int":6528},"ident":{"string":"00CA"},"type":{"string":"small_airport"},"name":{"string":"Goldstone (GTS) Airport"},"latitude_deg":{"double":35.35474},"longitude_deg":{"double":-116.885329},"elevation_ft":{"int":3038},"continent":{"string":"NA"},"iso_country":{"string":"US"},"iso_region":{"string":"US-CA"},"municipality":{"string":"Barstow"},"scheduled_service":{"string":"no"},"gps_code":{"string":"00CA"},"iata_code":null,"local_code":{"string":"00CA"},"home_link":null,"wikipedia_link":{"string":"https://en.wikipedia.org/wiki/Goldstone_Gts_Airport"},"keywords":null}
{"id":{"int":324424},"ident":{"string":"00CL"},"type":{"string":"small_airport"},"name":{"string":"Williams Ag Airport"},"latitude_deg":{"double":39.427188},"longitude_deg":{"double":-121.763427},"elevation_ft":{"int":87},"continent":{"string":"NA"},"iso_country":{"string":"US"},"iso_region":{"string":"US-CA"},"municipality":{"string":"Biggs"},"scheduled_service":{"string":"no"},"gps_code":{"string":"00CL"},"iata_code":null,"local_code":{"string":"00CL"},"home_link":null,"wikipedia_link":null,"keywords":null}
```

Now let's see the meta data of the Avro file

```bash
docker compose run --rm avro-tools getmeta /data-transfer/result/avro/part-00000-4e0989a0-7992-4fcb-bfb6-d92db095acab-c000.avro
```

and you should get

```bash
ubuntu@ip-172-26-9-171:~/bigdata-spark-workshop/01-environment/docker$ docker compose run --rm avro-tools getmeta /data-transfer/result/avro/part-00000-4e0989a0-7992-4fcb-bfb6-d92db095acab-c000.avro
WARN[0000] The "AIRFLOW_UID" variable is not set. Defaulting to a blank string. 
25/05/20 05:28:52 WARN util.NativeCodeLoader: Unable to load native-hadoop library for your platform... using builtin-java classes where applicable
avro.schema     {"type":"record","name":"topLevelRecord","fields":[{"name":"id","type":["int","null"]},{"name":"ident","type":["string","null"]},{"name":"type","type":["string","null"]},{"name":"name","type":["string","null"]},{"name":"latitude_deg","type":["double","null"]},{"name":"longitude_deg","type":["double","null"]},{"name":"elevation_ft","type":["int","null"]},{"name":"continent","type":["string","null"]},{"name":"iso_country","type":["string","null"]},{"name":"iso_region","type":["string","null"]},{"name":"municipality","type":["string","null"]},{"name":"scheduled_service","type":["string","null"]},{"name":"gps_code","type":["string","null"]},{"name":"iata_code","type":["string","null"]},{"name":"local_code","type":["string","null"]},{"name":"home_link","type":["string","null"]},{"name":"wikipedia_link","type":["string","null"]},{"name":"keywords","type":["string","null"]}]}
org.apache.spark.version        3.5.3
avro.codec      snappy
```

If you only want to see the schema, use the `getschema` tool instead

```bash
docker compose run --rm avro-tools getschema /data-transfer/result/avro/part-00000-4e0989a0-7992-4fcb-bfb6-d92db095acab-c000.avro
```

and you should get

```bash
ubuntu@ip-172-26-9-171:~/bigdata-spark-workshop/01-environment/docker$ docker compose run --rm avro-tools getschema /data-transfer/result/avro/part-00000-4e0989a0-7992-4fcb-bfb6-d92db095acab-c000.avro
WARN[0000] The "AIRFLOW_UID" variable is not set. Defaulting to a blank string. 
25/05/20 05:30:01 WARN util.NativeCodeLoader: Unable to load native-hadoop library for your platform... using builtin-java classes where applicable
{
  "type" : "record",
  "name" : "topLevelRecord",
  "fields" : [ {
    "name" : "id",
    "type" : [ "int", "null" ]
  }, {
    "name" : "ident",
    "type" : [ "string", "null" ]
  }, {
    "name" : "type",
    "type" : [ "string", "null" ]
  }, {
    "name" : "name",
    "type" : [ "string", "null" ]
  }, {
    "name" : "latitude_deg",
    "type" : [ "double", "null" ]
  }, {
    "name" : "longitude_deg",
    "type" : [ "double", "null" ]
  }, {
    "name" : "elevation_ft",
    "type" : [ "int", "null" ]
  }, {
    "name" : "continent",
    "type" : [ "string", "null" ]
  }, {
    "name" : "iso_country",
    "type" : [ "string", "null" ]
  }, {
    "name" : "iso_region",
    "type" : [ "string", "null" ]
  }, {
    "name" : "municipality",
    "type" : [ "string", "null" ]
  }, {
    "name" : "scheduled_service",
    "type" : [ "string", "null" ]
  }, {
    "name" : "gps_code",
    "type" : [ "string", "null" ]
  }, {
    "name" : "iata_code",
    "type" : [ "string", "null" ]
  }, {
    "name" : "local_code",
    "type" : [ "string", "null" ]
  }, {
    "name" : "home_link",
    "type" : [ "string", "null" ]
  }, {
    "name" : "wikipedia_link",
    "type" : [ "string", "null" ]
  }, {
    "name" : "keywords",
    "type" : [ "string", "null" ]
  } ]
}
```

## Write as Parquet

Store the data using the `parquet` data type:

```python
airportsRawDF.write.parquet("s3a://datatype-bucket/parquet")
```

Let's view the data created in the bucket

```
docker exec -ti awscli s3cmd ls s3://datatype-bucket/parquet/
```

and you should see a result similar to the one shown below

```bash
ubuntu@ip-172-26-9-12:~/bigdata-spark-workshop/01-environment/docker$ docker exec -ti awscli s3cmd ls s3://datatype-bucket/parquet/
2025-05-22 11:37            0  s3://datatype-bucket/parquet/_SUCCESS
2025-05-22 11:37      3366543  s3://datatype-bucket/parquet/part-00000-9a680a61-9993-4651-a110-5adf979095ba-c000.snappy.parquet
2025-05-22 11:37      1618896  s3://datatype-bucket/parquet/part-00001-9a680a61-9993-4651-a110-5adf979095ba-c000.snappy.parquet
```

Let's download the files to the local folder

```bash
cd $DATAPLATFORM_HOME
sudo mkdir -p data-transfer/result/parquet
docker exec -ti awscli s3cmd get --recursive s3://datatype-bucket/parquet/ /data-transfer/result/parquet 
```

check for the output using the `tree` command.

```bash
cd data-transfer/result
tree parquet
```

and you should see a result similar to 

```bash
ubuntu@ip-172-26-9-12:~/bigdata-spark-workshop/01-environment/docker$ cd data-transfer/result
tree parquet
parquet
├── _SUCCESS
├── part-00000-9a680a61-9993-4651-a110-5adf979095ba-c000.snappy.parquet
└── part-00001-9a680a61-9993-4651-a110-5adf979095ba-c000.snappy.parquet

1 directory, 3 files
```

Let's use the Parquet tools to inspect the Parquet files.

```bash
ubuntu@ip-172-26-9-12:~/bigdata-spark-workshop/01-environment/docker/data-transfer/result$ docker compose run --rm parquet-tools
WARN[0000] The "AIRFLOW_UID" variable is not set. Defaulting to a blank string. 
No command specified

parquet-tools cat:
Prints the content of a Parquet file. The output contains only the data, no
metadata is displayed
usage: parquet-tools cat [option...] <input>
where option is one of:
       --debug     Enable debug output
    -h,--help      Show this help string
    -j,--json      Show records in JSON format.
       --no-color  Disable color output even if supported
where <input> is the parquet file to print to stdout

parquet-tools head:
Prints the first n record of the Parquet file
usage: parquet-tools head [option...] <input>
where option is one of:
       --debug          Enable debug output
    -h,--help           Show this help string
    -n,--records <arg>  The number of records to show (default: 5)
       --no-color       Disable color output even if supported
where <input> is the parquet file to print to stdout

parquet-tools schema:
Prints the schema of Parquet file(s)
usage: parquet-tools schema [option...] <input>
where option is one of:
    -d,--detailed      Show detailed information about the schema.
       --debug         Enable debug output
    -h,--help          Show this help string
       --no-color      Disable color output even if supported
    -o,--originalType  Print logical types in OriginalType representation.
where <input> is the parquet file containing the schema to show

parquet-tools meta:
Prints the metadata of Parquet file(s)
usage: parquet-tools meta [option...] <input>
where option is one of:
       --debug         Enable debug output
    -h,--help          Show this help string
       --no-color      Disable color output even if supported
    -o,--originalType  Print logical types in OriginalType representation.
where <input> is the parquet file to print to stdout

parquet-tools dump:
Prints the content and metadata of a Parquet file
usage: parquet-tools dump [option...] <input>
where option is one of:
    -c,--column <arg>  Dump only the given column, can be specified more than
                       once
    -d,--disable-data  Do not dump column data
       --debug         Enable debug output
    -h,--help          Show this help string
    -m,--disable-meta  Do not dump row group and page metadata
    -n,--disable-crop  Do not crop the output based on console width
       --no-color      Disable color output even if supported
where <input> is the parquet file to print to stdout

parquet-tools merge:
Merges multiple Parquet files into one. The command doesn't merge row groups,
just places one after the other. When used to merge many small files, the
resulting file will still contain small row groups, which usually leads to bad
query performance.
usage: parquet-tools merge [option...] <input> [<input> ...] <output>
where option is one of:
       --debug     Enable debug output
    -h,--help      Show this help string
       --no-color  Disable color output even if supported
where <input> is the source parquet files/directory to be merged
   <output> is the destination parquet file

parquet-tools rowcount:
Prints the count of rows in Parquet file(s)
usage: parquet-tools rowcount [option...] <input>
where option is one of:
    -d,--detailed  Detailed rowcount of each matching file
       --debug     Enable debug output
    -h,--help      Show this help string
       --no-color  Disable color output even if supported
where <input> is the parquet file to count rows to stdout

parquet-tools size:
Prints the size of Parquet file(s)
usage: parquet-tools size [option...] <input>
where option is one of:
    -d,--detailed      Detailed size of each matching file
       --debug         Enable debug output
    -h,--help          Show this help string
       --no-color      Disable color output even if supported
    -p,--pretty        Pretty size
    -u,--uncompressed  Uncompressed size
where <input> is the parquet file to get size & human readable size to stdout

parquet-tools column-index:
Prints the column and offset indexes of a Parquet file.
usage: parquet-tools column-index [option...] <input>
where option is one of:
    -c,--column <arg>     Shows the column/offset indexes for the given column
                          only; multiple columns shall be separated by commas
       --debug            Enable debug output
    -h,--help             Show this help string
    -i,--column-index     Shows the column indexes; active by default unless -o
                          is used
       --no-color         Disable color output even if supported
    -o,--offset-index     Shows the offset indexes; active by default unless -i
                          is used
    -r,--row-group <arg>  Shows the column/offset indexes for the given
                          row-groups only; multiple row-groups shall be
                          speparated by commas; row-groups are referenced by
                          their indexes from 0
where <input> is the parquet file to print the column and offset indexes for
```

To see the number of rows in the Parquet file

```bash
docker compose run --rm parquet-tools rowcount /data-transfer/result/parquet/part-00000-80dc22bc-1025-425b-b91a-dbe801dba04d-c000.snappy.parquet
```

and you should see a count of `54024`

```bash
ubuntu@ip-172-26-9-171:~/bigdata-spark-workshop/01-environment/docker/data-transfer/result$ docker compose run --rm parquet-tools rowcount /data-transfer/result/parquet/part-00000-80dc22bc-1025-425b-b91a-dbe801dba04d-c000.snappy.parquet
WARN[0000] The "AIRFLOW_UID" variable is not set. Defaulting to a blank string. 
Total RowCount: 54024
```

To see the metadata of the Parquet file, use the `meta` tool

```bash
docker compose run --rm parquet-tools meta  /data-transfer/result/parquet/part-00000-80dc22bc-1025-425b-b91a-dbe801dba04d-c000.snappy.parquet
``

```bash
ubuntu@ip-172-26-9-12:~/bigdata-spark-workshop/01-environment/docker/data-transfer/result$ docker compose run --rm parquet-tools meta /data-transfer/result/parquet/part-00000-9a680a61-9993-4651-a110-5adf979095ba-c000.snappy.parquet
WARN[0000] The "AIRFLOW_UID" variable is not set. Defaulting to a blank string. 
file:              file:/data-transfer/result/parquet/part-00000-9a680a61-9993-4651-a110-5adf979095ba-c000.snappy.parquet 
creator:           parquet-mr version 1.13.1 (build db4183109d5b734ec5930d870cdae161e408ddba) 
extra:             org.apache.spark.version = 3.5.3 
extra:             org.apache.spark.sql.parquet.row.metadata = {"type":"struct","fields":[{"name":"id","type":"integer","nullable":true,"metadata":{}},{"name":"ident","type":"string","nullable":true,"metadata":{}},{"name":"type","type":"string","nullable":true,"metadata":{}},{"name":"name","type":"string","nullable":true,"metadata":{}},{"name":"latitude_deg","type":"double","nullable":true,"metadata":{}},{"name":"longitude_deg","type":"double","nullable":true,"metadata":{}},{"name":"elevation_ft","type":"integer","nullable":true,"metadata":{}},{"name":"continent","type":"string","nullable":true,"metadata":{}},{"name":"iso_country","type":"string","nullable":true,"metadata":{}},{"name":"iso_region","type":"string","nullable":true,"metadata":{}},{"name":"municipality","type":"string","nullable":true,"metadata":{}},{"name":"scheduled_service","type":"string","nullable":true,"metadata":{}},{"name":"gps_code","type":"string","nullable":true,"metadata":{}},{"name":"iata_code","type":"string","nullable":true,"metadata":{}},{"name":"local_code","type":"string","nullable":true,"metadata":{}},{"name":"home_link","type":"string","nullable":true,"metadata":{}},{"name":"wikipedia_link","type":"string","nullable":true,"metadata":{}},{"name":"keywords","type":"string","nullable":true,"metadata":{}}]} 

file schema:       spark_schema 
--------------------------------------------------------------------------------
id:                OPTIONAL INT32 R:0 D:1
ident:             OPTIONAL BINARY L:STRING R:0 D:1
type:              OPTIONAL BINARY L:STRING R:0 D:1
name:              OPTIONAL BINARY L:STRING R:0 D:1
latitude_deg:      OPTIONAL DOUBLE R:0 D:1
longitude_deg:     OPTIONAL DOUBLE R:0 D:1
elevation_ft:      OPTIONAL INT32 R:0 D:1
continent:         OPTIONAL BINARY L:STRING R:0 D:1
iso_country:       OPTIONAL BINARY L:STRING R:0 D:1
iso_region:        OPTIONAL BINARY L:STRING R:0 D:1
municipality:      OPTIONAL BINARY L:STRING R:0 D:1
scheduled_service: OPTIONAL BINARY L:STRING R:0 D:1
gps_code:          OPTIONAL BINARY L:STRING R:0 D:1
iata_code:         OPTIONAL BINARY L:STRING R:0 D:1
local_code:        OPTIONAL BINARY L:STRING R:0 D:1
home_link:         OPTIONAL BINARY L:STRING R:0 D:1
wikipedia_link:    OPTIONAL BINARY L:STRING R:0 D:1
keywords:          OPTIONAL BINARY L:STRING R:0 D:1

row group 1:       RC:54024 TS:5360817 OFFSET:4 
--------------------------------------------------------------------------------
id:                 INT32 SNAPPY DO:0 FPO:4 SZ:216232/216207/1.00 VC:54024 ENC:RLE,PLAIN,BIT_PACKED ST:[min: 2, max: 558440, num_nulls: 0]
ident:              BINARY SNAPPY DO:0 FPO:216236 SZ:238411/498265/2.09 VC:54024 ENC:RLE,PLAIN,BIT_PACKED ST:[min: 00A, max: rjns, num_nulls: 0]
type:               BINARY SNAPPY DO:454647 FPO:454765 SZ:17781/17780/1.00 VC:54024 ENC:RLE,PLAIN_DICTIONARY,BIT_PACKED ST:[min: balloonport, max: small_airport, num_nulls: 0]
name:               BINARY SNAPPY DO:0 FPO:472428 SZ:766089/1468044/1.92 VC:54024 ENC:RLE,PLAIN,BIT_PACKED ST:[min: """Ghost"" International Airport", max: ​Isla de Desecheo Helipad, num_nulls: 0]
latitude_deg:       DOUBLE SNAPPY DO:0 FPO:1238517 SZ:400205/432302/1.08 VC:54024 ENC:RLE,PLAIN,BIT_PACKED ST:[min: -89.989444, max: 82.75, num_nulls: 0]
longitude_deg:      DOUBLE SNAPPY DO:0 FPO:1638722 SZ:405788/432303/1.07 VC:54024 ENC:RLE,PLAIN,BIT_PACKED ST:[min: -179.876999, max: 179.9757, num_nulls: 0]
elevation_ft:       INT32 SNAPPY DO:2044510 FPO:2066338 SZ:94999/95104/1.00 VC:54024 ENC:RLE,PLAIN_DICTIONARY,BIT_PACKED ST:[min: -1266, max: 17372, num_nulls: 10066]
continent:          BINARY SNAPPY DO:2139509 FPO:2139567 SZ:2127/2252/1.06 VC:54024 ENC:RLE,PLAIN_DICTIONARY,BIT_PACKED ST:[min: AF, max: SA, num_nulls: 0]
iso_country:        BINARY SNAPPY DO:2141636 FPO:2142548 SZ:4477/5976/1.33 VC:54024 ENC:RLE,PLAIN_DICTIONARY,BIT_PACKED ST:[min: AD, max: ZW, num_nulls: 0]
iso_region:         BINARY SNAPPY DO:2146113 FPO:2158943 SZ:65525/81213/1.24 VC:54024 ENC:RLE,PLAIN_DICTIONARY,BIT_PACKED ST:[min: AD-04, max: ZW-MW, num_nulls: 0]
municipality:       BINARY SNAPPY DO:2211638 FPO:2489352 SZ:371717/480678/1.29 VC:54024 ENC:RLE,PLAIN_DICTIONARY,BIT_PACKED ST:[min: """Jaunkalmes"", max: Žocene, num_nulls: 2895]
scheduled_service:  BINARY SNAPPY DO:2583355 FPO:2583409 SZ:3040/3155/1.04 VC:54024 ENC:RLE,PLAIN_DICTIONARY,BIT_PACKED ST:[min: Lejasciema pag., max: yes, num_nulls: 0]
gps_code:           BINARY SNAPPY DO:0 FPO:2586395 SZ:147711/236912/1.60 VC:54024 ENC:RLE,PLAIN,BIT_PACKED ST:[min: LV4412", max: ZYXC, num_nulls: 25018]
iata_code:          BINARY SNAPPY DO:0 FPO:2734106 SZ:31309/46111/1.47 VC:54024 ENC:RLE,PLAIN,BIT_PACKED ST:[min: AAA, max: no, num_nulls: 47912]
local_code:         BINARY SNAPPY DO:0 FPO:2765415 SZ:125839/207154/1.65 VC:54024 ENC:RLE,PLAIN,BIT_PACKED ST:[min: 00A, max: ZZV, num_nulls: 28459]
home_link:          BINARY SNAPPY DO:0 FPO:2891254 SZ:80300/156416/1.95 VC:54024 ENC:RLE,PLAIN,BIT_PACKED ST:[min: http://GillespieField.com/, max: https:/https://www.dynali.com//www.dynali.com/, num_nulls: 50494]
wikipedia_link:     BINARY SNAPPY DO:0 FPO:2971554 SZ:205132/716740/3.49 VC:54024 ENC:RLE,PLAIN,BIT_PACKED ST:[min: http://de.wikipedia.org/wiki/Albertus_Airport, max: https://zh.wikipedia.org/wiki/%E9%83%91%E5%B7%9E%E4%B8%8A%E8%A1%97%E6%9C%BA%E5%9C%BA, num_nulls: 41736]
keywords:           BINARY SNAPPY DO:0 FPO:3176686 SZ:183387/264205/1.44 VC:54024 ENC:RLE,PLAIN,BIT_PACKED ST:[min: """Alas de Rauch""", max: 황수원비행장, 黃水院飛行場, num_nulls: 40762]
``` 

and to see the schema, use the `schema` tool

```bash
ubuntu@ip-172-26-9-12:~/bigdata-spark-workshop/01-environment/docker/data-transfer/result$ docker compose run --rm parquet-tools schema /data-transfer/result/parquet/part-00000-9a680a61-9993-4651-a110-5adf979095ba-c000.snappy.parquet
WARN[0000] The "AIRFLOW_UID" variable is not set. Defaulting to a blank string. 
message spark_schema {
  optional int32 id;
  optional binary ident (STRING);
  optional binary type (STRING);
  optional binary name (STRING);
  optional double latitude_deg;
  optional double longitude_deg;
  optional int32 elevation_ft;
  optional binary continent (STRING);
  optional binary iso_country (STRING);
  optional binary iso_region (STRING);
  optional binary municipality (STRING);
  optional binary scheduled_service (STRING);
  optional binary gps_code (STRING);
  optional binary iata_code (STRING);
  optional binary local_code (STRING);
  optional binary home_link (STRING);
  optional binary wikipedia_link (STRING);
  optional binary keywords (STRING);
}
```

and finally to see the first 10 records, use the `head` tool with the `-n` option

```bash
ubuntu@ip-172-26-9-12:~/bigdata-spark-workshop/01-environment/docker/data-transfer/result$ docker compose run --rm parquet-tools head -n 10 /data-transfer/result/parquet/part-00000-9a680a61-9993-4651-a110-5adf979095ba-c000.snappy.parquet
WARN[0000] The "AIRFLOW_UID" variable is not set. Defaulting to a blank string. 
id = 6523
ident = 00A
type = heliport
name = Total RF Heliport
latitude_deg = 40.070985
longitude_deg = -74.933689
elevation_ft = 11
continent = NA
iso_country = US
iso_region = US-PA
municipality = Bensalem
scheduled_service = no
gps_code = K00A
local_code = 00A
home_link = https://www.penndot.pa.gov/TravelInPA/airports-pa/Pages/Total-RF-Heliport.aspx

id = 323361
ident = 00AA
type = small_airport
name = Aero B Ranch Airport
latitude_deg = 38.704022
longitude_deg = -101.473911
elevation_ft = 3435
continent = NA
iso_country = US
iso_region = US-KS
municipality = Leoti
scheduled_service = no
gps_code = 00AA
local_code = 00AA

id = 6524
ident = 00AK
type = small_airport
name = Lowell Field
latitude_deg = 59.947733
longitude_deg = -151.692524
elevation_ft = 450
continent = NA
iso_country = US
iso_region = US-AK
municipality = Anchor Point
scheduled_service = no
gps_code = 00AK
local_code = 00AK

id = 6525
ident = 00AL
type = small_airport
name = Epps Airpark
latitude_deg = 34.86479949951172
longitude_deg = -86.77030181884766
elevation_ft = 820
continent = NA
iso_country = US
iso_region = US-AL
municipality = Harvest
scheduled_service = no
gps_code = 00AL
local_code = 00AL

id = 506791
ident = 00AN
type = small_airport
name = Katmai Lodge Airport
latitude_deg = 59.093287
longitude_deg = -156.456699
elevation_ft = 80
continent = NA
iso_country = US
iso_region = US-AK
municipality = King Salmon
scheduled_service = no
gps_code = 00AN
local_code = 00AN

id = 6526
ident = 00AR
type = closed
name = Newport Hospital & Clinic Heliport
latitude_deg = 35.6087
longitude_deg = -91.254898
elevation_ft = 237
continent = NA
iso_country = US
iso_region = US-AR
municipality = Newport
scheduled_service = no
keywords = 00AR

id = 322127
ident = 00AS
type = small_airport
name = Fulton Airport
latitude_deg = 34.9428028
longitude_deg = -97.8180194
elevation_ft = 1100
continent = NA
iso_country = US
iso_region = US-OK
municipality = Alex
scheduled_service = no
gps_code = 00AS
local_code = 00AS

id = 6527
ident = 00AZ
type = small_airport
name = Cordes Airport
latitude_deg = 34.305599212646484
longitude_deg = -112.16500091552734
elevation_ft = 3810
continent = NA
iso_country = US
iso_region = US-AZ
municipality = Cordes
scheduled_service = no
gps_code = 00AZ
local_code = 00AZ

id = 6528
ident = 00CA
type = small_airport
name = Goldstone (GTS) Airport
latitude_deg = 35.35474
longitude_deg = -116.885329
elevation_ft = 3038
continent = NA
iso_country = US
iso_region = US-CA
municipality = Barstow
scheduled_service = no
gps_code = 00CA
local_code = 00CA
wikipedia_link = https://en.wikipedia.org/wiki/Goldstone_Gts_Airport

id = 324424
ident = 00CL
type = small_airport
name = Williams Ag Airport
latitude_deg = 39.427188
longitude_deg = -121.763427
elevation_ft = 87
continent = NA
iso_country = US
iso_region = US-CA
municipality = Biggs
scheduled_service = no
gps_code = 00CL
local_code = 00CL
```

## Reading from PostgreSQL

In this section we will see how we can use Spark to read from a relational database table. We will use PostgreSQL which is part of the dataplatform.

Let's create the `pg_airports_t` table in PostgreSQL, which we will use.

Connect to PostgreSQL using the `psql` CLI

```bash
docker exec -ti postgresql psql -d postgres -U postgres
```

Create a database and the table for the airport data 

```sql
CREATE SCHEMA flight_data;

DROP TABLE IF EXISTS flight_data.pg_airport_t;

CREATE TABLE flight_data.pg_airport_t
(
	id int
	, ident character varying(50)
	, type character varying(50)
   , name character varying(200)
   , latitude_deg float
   , longitude_deg float
   , elevation_ft int
   , continent character varying(50)
   , iso_country character varying(50)
   , iso_region character varying(50)
   , municipality character varying(100)
   , scheduled_service character varying(50)
   , gps_code character varying(50)
   , iata_code character varying(50)
   , local_code character varying(50)
   , home_link character varying(200)
   , wikipedia_link character varying(200)
   , keywords character varying(1000)
  , CONSTRAINT airport_pk PRIMARY KEY (id)
);
```

Finally let's import the data from the data-transfer folder. 

```sql
COPY flight_data.pg_airport_t(id, ident, type, name, latitude_deg, longitude_deg, elevation_ft, continent, iso_country, iso_region, municipality, scheduled_service, gps_code, iata_code, local_code, home_link, wikipedia_link, keywords) 
FROM '/data-transfer/airports-data/airports.csv' DELIMITER ',' CSV HEADER;
```

Now in Pyspark (for example from Zeppelin) use the following statement to read from the `flight_data.pg_airport_t` table.

```python
jdbcDF = spark.read.format("jdbc").option("url", "jdbc:postgresql://postgresql:5432/postgres").option("dbtable", "flight_data.pg_airport_t").option("user", "postgres").option("password", "abc123!").load()
```

and let's view the data

```python
jdbcDF.show()
```

let's see the schema derived from the table

```python
jdbcDF.printSchema()
```