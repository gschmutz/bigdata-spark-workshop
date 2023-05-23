# Working with different data types

In this workshop we will working with various data types. To make it not more complex than necessary, we just use the local filesystem to store the data using different data types and not S3 object storage.

We assume that the **Data Platform** described [here](../01-environment) is running and accessible. 

## Read CSV File

Let's read the raw airport data in CSV file format. 

```python
%pyspark
from pyspark.sql.types import *
airportsRawDF = spark.read.csv("file:///data-transfer/flight-data/airports.csv", 
    	sep=",", inferSchema="true", header="true")
airportsRawDF.show(5)
```

## Write as JSON

Store the data using the `json` data type:

```python
%pyspark
airportsRawDF.write.json("file:///data-transfer/tmp/json")
```

## Write as Avro

Store the data using the `avro` data type:

```python
%pyspark
airportsRawDF.write.format("avro").save("file:///data-transfer/tmp/avro")
```

check for the output using the `tree` command

```bash
$ tree data-transfer/tmp/avro
data-transfer/tmp/avro
├── _SUCCESS
└── part-00000-facaf478-33c0-42e9-b358-c9e6b3e56921-c000.avro
```

Let's see the first 2 lines of the avro file. 

```bash
$ head -n 2 data-transfer/tmp/avro/part-00000-facaf478-33c0-42e9-b358-c9e6b3e56921-c000.avro
Objavro.schema�{"type":"record","name":"topLevelRecord","fields":[{"name":"iata","type":["string","null"]},{"name":"airport","type":["string","null"]},{"name":"city","type":["string","null"]},{"name":"state","type":["string","null"]},{"name":"country","type":["string","null"]},{"name":"lat","type":["double","null"]},{"name":"long","type":["double","null"]}]}0org.apache.spark.version
3.2.4avro.codec
               snappy.}]�ҹԠ�ekDiaL�������00MThigpen Bay SpringsMSUSA�z��)�?@� OV�7R(Liv)8ton Municipal
                                                                                                      TX	B@[
                                                                                                                   �>@�2��%�W�B\VMeadow Lake Colorado�CO	?<�c�LyC@im�!y$Z?D1GPerry-Warsaw
```

Let's use the Avro tools to inspect the Avro files.

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

To see how many records are in an Avro file, use the `count` tool

```bash
$ docker compose run --rm  avro-tools count /data-transfer/tmp/avro/part-00000-facaf478-33c0-42e9-b358-c9e6b3e56921-c000.avro
23/05/20 20:16:42 WARN util.NativeCodeLoader: Unable to load native-hadoop library for your platform... using builtin-java classes where applicable
3376
```

Let's use `tojson`to dump the Avro file as JSON, one line per record and only showing the first 10 records (using the `--head` option)

```bash
$ docker compose run --rm avro-tools tojson --head /data-transfer/tmp/avro/part-00000-facaf478-33c0-42e9-b358-c9e6b3e56921-c000.avro
23/05/20 20:11:42 WARN util.NativeCodeLoader: Unable to load native-hadoop library for your platform... using builtin-java classes where applicable
{"iata":{"string":"00M"},"airport":{"string":"Thigpen "},"city":{"string":"Bay Springs"},"state":{"string":"MS"},"country":{"string":"USA"},"lat":{"double":31.95376472},"long":{"double":-89.23450472}}
{"iata":{"string":"00R"},"airport":{"string":"Livingston Municipal"},"city":{"string":"Livingston"},"state":{"string":"TX"},"country":{"string":"USA"},"lat":{"double":30.68586111},"long":{"double":-95.01792778}}
{"iata":{"string":"00V"},"airport":{"string":"Meadow Lake"},"city":{"string":"Colorado Springs"},"state":{"string":"CO"},"country":{"string":"USA"},"lat":{"double":38.94574889},"long":{"double":-104.5698933}}
{"iata":{"string":"01G"},"airport":{"string":"Perry-Warsaw"},"city":{"string":"Perry"},"state":{"string":"NY"},"country":{"string":"USA"},"lat":{"double":42.74134667},"long":{"double":-78.05208056}}
{"iata":{"string":"01J"},"airport":{"string":"Hilliard Airpark"},"city":{"string":"Hilliard"},"state":{"string":"FL"},"country":{"string":"USA"},"lat":{"double":30.6880125},"long":{"double":-81.90594389}}
{"iata":{"string":"01M"},"airport":{"string":"Tishomingo County"},"city":{"string":"Belmont"},"state":{"string":"MS"},"country":{"string":"USA"},"lat":{"double":34.49166667},"long":{"double":-88.20111111}}
{"iata":{"string":"02A"},"airport":{"string":"Gragg-Wade "},"city":{"string":"Clanton"},"state":{"string":"AL"},"country":{"string":"USA"},"lat":{"double":32.85048667},"long":{"double":-86.61145333}}
{"iata":{"string":"02C"},"airport":{"string":"Capitol"},"city":{"string":"Brookfield"},"state":{"string":"WI"},"country":{"string":"USA"},"lat":{"double":43.08751},"long":{"double":-88.17786917}}
{"iata":{"string":"02G"},"airport":{"string":"Columbiana County"},"city":{"string":"East Liverpool"},"state":{"string":"OH"},"country":{"string":"USA"},"lat":{"double":40.67331278},"long":{"double":-80.64140639}}
{"iata":{"string":"03D"},"airport":{"string":"Memphis Memorial"},"city":{"string":"Memphis"},"state":{"string":"MO"},"country":{"string":"USA"},"lat":{"double":40.44725889},"long":{"double":-92.22696056}}
```

Now let's see the meta data of the Avro file

```bash
$ docker compose run --rm avro-tools getmeta /data-transfer/tmp/avro/part-00000-facaf478-33c0-42e9-b358-c9e6b3e56921-c000.avro
23/05/20 20:13:26 WARN util.NativeCodeLoader: Unable to load native-hadoop library for your platform... using builtin-java classes where applicable
avro.schema	{"type":"record","name":"topLevelRecord","fields":[{"name":"iata","type":["string","null"]},{"name":"airport","type":["string","null"]},{"name":"city","type":["string","null"]},{"name":"state","type":["string","null"]},{"name":"country","type":["string","null"]},{"name":"lat","type":["double","null"]},{"name":"long","type":["double","null"]}]}
org.apache.spark.version	3.2.4
avro.codec	snappy
```

If you only want to see the schema, use the `getschema` tool instead

```bash
$ docker compose run --rm avro-tools getschema /data-transfer/tmp/avro/part-00000-facaf478-33c0-42e9-b358-c9e6b3e56921-c000.avro
23/05/20 20:14:57 WARN util.NativeCodeLoader: Unable to load native-hadoop library for your platform... using builtin-java classes where applicable
{
  "type" : "record",
  "name" : "topLevelRecord",
  "fields" : [ {
    "name" : "iata",
    "type" : [ "string", "null" ]
  }, {
    "name" : "airport",
    "type" : [ "string", "null" ]
  }, {
    "name" : "city",
    "type" : [ "string", "null" ]
  }, {
    "name" : "state",
    "type" : [ "string", "null" ]
  }, {
    "name" : "country",
    "type" : [ "string", "null" ]
  }, {
    "name" : "lat",
    "type" : [ "double", "null" ]
  }, {
    "name" : "long",
    "type" : [ "double", "null" ]
  } ]
}
```

## Write as Parquet

Store the data using the `parquet` data type:

```python
%pyspark
airportsRawDF.write.parquet("file:///data-transfer/tmp/parquet")
```

check for the output using the `tree` command

```bash
$ tree data-transfer/tmp/parquet
data-transfer/tmp/parquet/
├── _SUCCESS
└── part-00000-1f3942a8-da8d-4338-b56a-a347991f1e00-c000.snappy.parquet
```

Let's use the Avro tools to inspect the Avro files.

```bash
$ docker compose run --rm parquet-tools
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
$ docker compose run --rm parquet-tools rowcount /data-transfer/tmp/parquet/part-00000-1f3942a8-da8d-4338-b56a-a347991f1e00-c000.snappy.parquet
Total RowCount: 3376
```

To see the metadata of the Parquet file, use the `meta` tool

```bash
$ docker compose run --rm parquet-tools meta  /data-transfer/tmp/parquet/part-00000-1f3942a8-da8d-4338-b56a-a347991f1e00-c000.snappy.parquet
file:        file:/data-transfer/tmp/parquet/part-00000-1f3942a8-da8d-4338-b56a-a347991f1e00-c000.snappy.parquet
creator:     parquet-mr version 1.12.2 (build 77e30c8093386ec52c3cfa6c34b7ef3321322c94)
extra:       org.apache.spark.version = 3.2.4
extra:       org.apache.spark.sql.parquet.row.metadata = {"type":"struct","fields":[{"name":"iata","type":"string","nullable":true,"metadata":{}},{"name":"airport","type":"string","nullable":true,"metadata":{}},{"name":"city","type":"string","nullable":true,"metadata":{}},{"name":"state","type":"string","nullable":true,"metadata":{}},{"name":"country","type":"string","nullable":true,"metadata":{}},{"name":"lat","type":"double","nullable":true,"metadata":{}},{"name":"long","type":"double","nullable":true,"metadata":{}}]}

file schema: spark_schema
--------------------------------------------------------------------------------
iata:        OPTIONAL BINARY L:STRING R:0 D:1
airport:     OPTIONAL BINARY L:STRING R:0 D:1
city:        OPTIONAL BINARY L:STRING R:0 D:1
state:       OPTIONAL BINARY L:STRING R:0 D:1
country:     OPTIONAL BINARY L:STRING R:0 D:1
lat:         OPTIONAL DOUBLE R:0 D:1
long:        OPTIONAL DOUBLE R:0 D:1

row group 1: RC:3376 TS:188503 OFFSET:4
--------------------------------------------------------------------------------
iata:         BINARY SNAPPY DO:0 FPO:4 SZ:15169/23709/1.56 VC:3376 ENC:BIT_PACKED,PLAIN,RLE ST:[min: 00M, max: ZZV, num_nulls: 0]
airport:      BINARY SNAPPY DO:0 FPO:15173 SZ:39581/68276/1.72 VC:3376 ENC:BIT_PACKED,PLAIN,RLE ST:[min: Abbeville Chris Crusta Memorial, max: Zephyrhills Municipal, num_nulls: 0]
city:         BINARY SNAPPY DO:54754 FPO:78407 SZ:28763/39366/1.37 VC:3376 ENC:BIT_PACKED,PLAIN_DICTIONARY,RLE ST:[min: Abbeville, max: Zuni, num_nulls: 0]
state:        BINARY SNAPPY DO:83517 FPO:83790 SZ:2822/2907/1.03 VC:3376 ENC:BIT_PACKED,PLAIN_DICTIONARY,RLE ST:[min: AK, max: WY, num_nulls: 0]
country:      BINARY SNAPPY DO:86339 FPO:86446 SZ:164/159/0.97 VC:3376 ENC:BIT_PACKED,PLAIN_DICTIONARY,RLE ST:[min: Federated States of Micronesia, max: USA, num_nulls: 0]
lat:          DOUBLE SNAPPY DO:0 FPO:86503 SZ:27049/27043/1.00 VC:3376 ENC:BIT_PACKED,PLAIN,RLE ST:[min: 7.367222, max: 71.2854475, num_nulls: 0]
long:         DOUBLE SNAPPY DO:0 FPO:113552 SZ:27049/27043/1.00 VC:3376 ENC:BIT_PACKED,PLAIN,RLE ST:[min: -176.6460306, max: 145.621384, num_nulls: 0]
``` 

and to see the schema, use the `schema` tool

```bash
$ docker compose run --rm parquet-tools schema  /data-transfer/tmp/parquet/part-00000-1f3942a8-da8d-4338-b56a-a347991f1e00-c000.snappy.parquet
message spark_schema {
  optional binary iata (STRING);
  optional binary airport (STRING);
  optional binary city (STRING);
  optional binary state (STRING);
  optional binary country (STRING);
  optional double lat;
  optional double long;
}
```

and finally to see the first 10 records, use the `head` tool with the `-n` option

```bash
$ docker compose run --rm parquet-tools head -n 10  /data-transfer/tmp/parquet/part-00000-1f3942a8-da8d-4338-b56a-a347991f1e00-c000.snappy.parquet
iata = 00M
airport = Thigpen
city = Bay Springs
state = MS
country = USA
lat = 31.95376472
long = -89.23450472

iata = 00R
airport = Livingston Municipal
city = Livingston
state = TX
country = USA
lat = 30.68586111
long = -95.01792778

iata = 00V
airport = Meadow Lake
city = Colorado Springs
state = CO
country = USA
lat = 38.94574889
long = -104.5698933

iata = 01G
airport = Perry-Warsaw
city = Perry
state = NY
country = USA
lat = 42.74134667
long = -78.05208056

iata = 01J
airport = Hilliard Airpark
city = Hilliard
state = FL
country = USA
lat = 30.6880125
long = -81.90594389

iata = 01M
airport = Tishomingo County
city = Belmont
state = MS
country = USA
lat = 34.49166667
long = -88.20111111

iata = 02A
airport = Gragg-Wade
city = Clanton
state = AL
country = USA
lat = 32.85048667
long = -86.61145333

iata = 02C
airport = Capitol
city = Brookfield
state = WI
country = USA
lat = 43.08751
long = -88.17786917

iata = 02G
airport = Columbiana County
city = East Liverpool
state = OH
country = USA
lat = 40.67331278
long = -80.64140639

iata = 03D
airport = Memphis Memorial
city = Memphis
state = MO
country = USA
lat = 40.44725889
long = -92.22696056
```