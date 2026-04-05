# Graph Analysis using Spark GraphFrames

In this workshop we will work with [Apache Spark GraphFrames](https://graphframes.github.io/graphframes/docs/_site/index.html) to build and execute graph queries.

The same data as in the [Object Storage Workshop](../02-object-storage/README.md) will be used. We will show later how to re-upload the files, if you no longer have them available.

## What you will learn

- How to build a GraphFrame from tabular data (airports as vertices, flights as edges)
- How to run basic graph queries: count vertices/edges, longest routes, highest delays
- How to analyse vertex degrees (`degrees`, `inDegrees`, `outDegrees`) to find the busiest airports
- How to create focused subgraphs by filtering vertices and edges
- How to use motif finding to detect structural patterns such as round-trips and two-hop paths
- How to run PageRank to identify the most important hub airports
- How to find connected components to discover isolated clusters in the network
- How to compute shortest paths (minimum hops) from every airport to a set of landmarks
- How to use Breadth-First Search (BFS) to find all routes between two airports within N hops

## Prerequisites

- The **Data Platform** described [here](../01-environment) is running and accessible
- Workshop 3 ([Getting Started using Spark RDD and DataFrames](../03-spark-getting-started)) completed
- Airport, plane, carrier, and flight data uploaded to MinIO (instructions provided if needed)

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
docker exec -ti awscli s3cmd put /data-transfer/airport-data/airports.csv s3://flight-bucket/raw/airports/airports.csv
```

or with `mc`

```bash
docker exec -ti minio-mc mc cp /data-transfer/airport-data/airports.csv minio-1/flight-bucket/raw/airports/airports.csv
```

**Plane-Data:**

```bash
docker exec -ti awscli s3cmd put /data-transfer/flight-data/plane-data.csv s3://flight-bucket/raw/planes/plane-data.csv
```

or with `mc`

```bash
docker exec -ti minio-mc mc cp /data-transfer/flight-data/plane-data.csv minio-1/flight-bucket/raw/planes/plane-data.csv
```

**Carriers:**

```bash
docker exec -ti awscli s3cmd put /data-transfer/flight-data/carriers.json s3://flight-bucket/raw/carriers/carriers.json
```

or with `mc`

```bash
docker exec -ti minio-mc mc cp /data-transfer/flight-data/carriers.json minio-1/flight-bucket/raw/carriers/carriers.json
```

**Flights:**

```bash
docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-medium/flights_2008_1.csv s3://flight-bucket/raw/flights/ &&
   docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_4_2.csv s3://flight-bucket/raw/flights/ &&
   docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_5_1.csv s3://flight-bucket/raw/flights/ &&
   docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_5_2.csv s3://flight-bucket/raw/flights/ &&
   docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_5_3.csv s3://flight-bucket/raw/flights/
```

or with `mc`

```bash
docker exec -ti minio-mc mc cp /data-transfer/flight-data/flights-small/flights_2008_4_1.csv minio-1/flight-bucket/raw/flights/ &&
   docker exec -ti minio-mc mc cp /data-transfer/flight-data/flights-small/flights_2008_4_2.csv minio-1/flight-bucket/raw/flights/ &&
   docker exec -ti minio-mc mc cp /data-transfer/flight-data/flights-small/flights_2008_5_1.csv minio-1/flight-bucket/raw/flights/ &&
   docker exec -ti minio-mc mc cp /data-transfer/flight-data/flights-small/flights_2008_5_2.csv minio-1/flight-bucket/raw/flights/ &&
   docker exec -ti minio-mc mc cp /data-transfer/flight-data/flights-small/flights_2008_5_3.csv minio-1/flight-bucket/raw/flights/
```

## Working with Spark and GraphFrames

In a browser window, navigate to 

  * for Zeppelin:  <http://dataplatform:28080>
  * for Jupyter: <http://dataplatform:28888>

Now let's create a new notebook and name it `SparkGraphFrame`. 

For **Jupyter**, perform the next paragraph, for **Apache Zeppelin**, this is not necessary and the Spark context is pre-configured.

### If you are using Jupyter

This workshop can be done with either Zeppelin or Jupyter, but to use Jupyter, you have to extend the Spark context with additional configuration settings in the init script:

```python
import os
# get the accessKey and secretKey from Environment
accessKey = os.environ['AWS_ACCESS_KEY_ID']
secretKey = os.environ['AWS_SECRET_ACCESS_KEY']

from pyspark.sql import SparkSession
spark = (
    SparkSession.builder
        .appName("Jupyter")
        .master("spark://spark-master:7077")

        .config("spark.jars.packages",
                "org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.10.1,"
                "org.apache.iceberg:iceberg-aws-bundle:1.10.1")

        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
        .config("spark.hadoop.fs.s3a.endpoint", "http://minio-1:9000")
        .config("spark.hadoop.fs.s3a.path.style.access", "true")
        .config("spark.hadoop.fs.s3a.access.key", accessKey)
        .config("spark.hadoop.fs.s3a.secret.key", secretKey)
        .config("spark.hadoop.fs.s3a.aws.credentials.provider", "org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider")

        # ==== Iceberg catalog (Hive Metastore) ===
        .config("spark.sql.catalog.hive_iceberg", "org.apache.iceberg.spark.SparkCatalog")
        .config("spark.sql.catalog.hive_iceberg.type", "hive")
        .config("spark.sql.catalog.hive_iceberg.uri", "thrift://hive-metastore:9083")
        .config("spark.sql.catalog.hive_iceberg.warehouse.dir", "s3a://admin-bucket/iceberg/warehouse")

        # ==== REQUIRED FOR MINIO WITH ICEBERG AWS SDK ===
        .config("spark.sql.catalog.hiverest.s3.endpoint", "http://minio-1:9000")
        .config("spark.sql.catalog.hiverest.s3.path-style-access", "true")
        .config("spark.sql.catalog.hiverest.s3.access-key-id", accessKey)
        .config("spark.sql.catalog.hiverest.s3.secret-access-key", secretKey)
    
        # use "hive_iceberg" as the default catalog
        .config("spark.sql.defaultCatalog", "hive_iceberg")

        .config(
            "spark.sql.extensions",
            "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions"
        )

        .getOrCreate()
)
```

Also enable sql magic in Jupyter (this will enable the `%%sql` directive to execute plain SQL statements)

```python
%load_ext sql
%config SqlMagic.autopandas = True
%config SqlMagic.displaycon = False

# Connect using the active SparkSession
%sql spark
```

### Add some Markdown first

Navigate to the first cell and start with a title. By using the `%md` directive we can switch to the Markdown interpreter, which can be used for displaying static text.

```
%md 
# Analyzing Flight Data with Spark GraphFrames
```

The markdown code should now be rendered as a Heading-1 title.

## Create Vertices and Edges

The data for vertices (airports) and edges (flights) is provided in CSV format. We will read these datafiles in a similar way as in workshop 4 and create two DataFrames, one for vertices and one for edges. Then we’ll use these to create a graph represented as an instance of GraphFrame.

```
%md 
## Reading the Airport data
```

Now let's load the data for the vertices (airports), which we have uploaded to `s3://flight-bucket/raw/airports/`. We rename `iata` to `id` to conform with the requirements of a GraphFrame.

```python
from pyspark.sql.types import *

from pyspark.sql.types import *

airportsRawDF = spark.read.csv("s3a://flight-bucket/raw/airports", 
    	sep=",", inferSchema="true", header="true")
verticesDF = airportsRawDF.filter("iata_code IS NOT NULL").drop("id").withColumnRenamed("iata_code", "id")
verticesDF.show(5)
```

Now let's load the data for the edges (flight data)

```python
flightSchema = """`year` INTEGER, `month` INTEGER, `dayOfMonth` INTEGER,  `dayOfWeek` INTEGER, `depTime` INTEGER, `crsDepTime` INTEGER, `arrTime` INTEGER, `crsArrTime` INTEGER, `uniqueCarrier` STRING, `flightNum` STRING, `tailNum` STRING, `actualElapsedTime` INTEGER,
                   `crsElapsedTime` INTEGER, `airTime` INTEGER, `arrDelay` INTEGER,`depDelay` INTEGER,`origin` STRING, `destination` STRING, `distance` INTEGER, `taxiIn` INTEGER, `taxiOut` INTEGER, `cancelled` STRING, `cancellationCode` STRING, `diverted` STRING, 
                   `carrierDelay` STRING, `weatherDelay` STRING, `nasDelay` STRING, `securityDelay` STRING, `lateAircraftDelay` STRING"""

flightsRawDF = spark.read.csv("s3a://flight-bucket/raw/flights", 
    	sep=",", inferSchema="false", header="false", schema=flightSchema)
edgesDF = flightsRawDF.withColumnRenamed("origin", "src").withColumnRenamed("destination", "dst")
edgesDF.show(5)
```

## Building the graph

To build a graph as an instance of GraphFrame, we have to create two DataFrames. 

```python
from graphframes import GraphFrame
graph = GraphFrame(verticesDF, edgesDF)
graph
```

## Flight analysis

Now that we have created a graph, we can execute queries on it. For example, now we can query the `GraphFrame` to answer the following questions.

* How many airports are there?

```python
num_of_airports = graph.vertices.count()
num_of_airports
```

and you will see that there are `9104` airports in the dataset.

* How many flights are there?

```python
num_of_flights = graph.edges.count()
num_of_flights
```

and you will see that there are `50000` flights in the dataset.	
	
* Which flight routes have the longest distance?

```python
from pyspark.sql.functions import col
graph.edges.groupBy("src", "dst") \
		.max("distance") \
		.sort(col("max(distance)") \
		.desc()) \
		.show(4)
```	

and we will see that Phoenix to Honolulu is the longest flight in the dataset.

```
+---+---+-------------+
|src|dst|max(distance)|
+---+---+-------------+
|PHX|HNL|         2917|
|HNL|PHX|         2917|
|LAS|HNL|         2762|
|HNL|LAS|         2762|
+---+---+-------------+
only showing top 4 rows
```

* Which flight routes have the highest average delays?

```python
graph.edges.groupBy("src", "dst") \
        .avg("depDelay") \
        .sort(col("avg(depDelay)") \
        .desc()) \
        .show(5)
```

will return this result

```
+---+---+------------------+
|src|dst|     avg(depDelay)|
+---+---+------------------+
|MCO|TUL|              93.0|
|MCO|SLC|              68.0|
|HNL|PHX| 66.29032258064517|
|SFO|IND|              53.0|
|MCI|SMF|46.333333333333336|
+---+---+------------------+
only showing top 5 rows
```

## Degree Analysis

GraphFrames provides built-in methods to compute the degree of each vertex — the number of edges connected to it. For a flight network this directly answers "which airports are the busiest?".

* Total degree (incoming + outgoing flights):

```python
graph.degrees.sort("degree", ascending=False).show(5)

+---+------+
| id|degree|
+---+------+
|ATL| 15170|
|MCO|  5070|
|BWI|  4761|
|LAX|  4555|
|HNL|  4254|
+---+------+
only showing top 5 rows
```

* Incoming flights only (most popular destination airports):

```python
graph.inDegrees.sort("inDegree", ascending=False).show(5)

+---+--------+
| id|inDegree|
+---+--------+
|ATL|    7619|
|MCO|    2544|
|BWI|    2389|
|LAX|    2288|
|HNL|    2127|
+---+--------+
only showing top 5 rows
```

* Outgoing flights only (most active origin airports):

```python
graph.outDegrees.sort("outDegree", ascending=False).show(5)

+---+---------+
| id|outDegree|
+---+---------+
|ATL|     7551|
|MCO|     2526|
|BWI|     2372|
|LAX|     2267|
|HNL|     2127|
+---+---------+
only showing top 5 rows
```

## Motif Finding

Motif finding is one of the most powerful and distinctive features of GraphFrames. It lets you search for **structural patterns** in the graph using a simple declarative syntax. Vertices are written as `(name)` and edges as `[name]`.

Let's find all **round-trip routes** — pairs of airports where a direct flight exists in both directions:

```python
roundTrips = graph.find("(a)-[e1]->(b); (b)-[e2]->(a)")
roundTrips.select("a.id", "b.id").distinct().show(10)

+-----+-----+
|ident|ident|
+-----+-----+
| KBHM| KPHX|
| KBHM| KLAS|
| KBWI| KBHM|
| KCMH| KMDW|
| KHOU| KDAL|
| KPHX| KOKC|
| KPIT| KPHL|
| KTPA| KRDU|
| KBDL| KLAS|
| KDEN| KATL|
+-----+-----+
only showing top 10 rows
```

We can also find **two-hop paths** — airports reachable from a given origin via exactly one connection:

```python
twohop = graph.find("(a)-[e1]->(b); (b)-[e2]->(c)")
twohop.filter("a.id = 'BOS'") \
      .select("a.id", "b.id", "c.id") \
      .distinct() \
      .show(10)
      
+---+---+---+
| id| id| id|
+---+---+---+
|BOS|MDW|SAT|
|BOS|BWI|AUS|
|BOS|BWI|MIA|
|BOS|MCO|IAD|
|BOS|MCO|CAK|
|BOS|BWI|BHM|
|BOS|MDW|LAS|
|BOS|MDW|SRQ|
|BOS|BWI|DAY|
|BOS|ATL|RIC|
+---+---+---+
only showing top 10 rows      
```

## PageRank

PageRank ranks vertices by their importance in the network — airports that are connected to many other well-connected airports score higher. In a flight network, this reveals the true hubs.

```python
ranks = graph.pageRank(resetProbability=0.15, maxIter=10)
ranks.vertices \
     .select("id", "pagerank") \
     .sort("pagerank", ascending=False) \
     .show(10)
     
+---+------------------+
| id|          pagerank|
+---+------------------+
|ATL| 91.10094958290752|
|MCO|30.632088151948064|
|BWI|30.432641628675686|
|LAX| 27.76072868698972|
|LAS|22.438247150782466|
|MDW|22.265006379376754|
|HNL| 18.69727857097317|
|PHX|16.054050168125137|
|HOU|14.584142572179879|
|SAN|14.155859998873886|
+---+------------------+
only showing top 10 rows     
```

You can also inspect which routes carry the most "weight" in the network:

```python
ranks.edges \
     .select("src", "dst", "weight") \
     .distinct() \    
     .sort("weight", ascending=False) \
     .show(10)
     
+---+---+--------------------+
|src|dst|              weight|
+---+---+--------------------+
|BTV|BWI|0.041666666666666664|
|XNA|LAX| 0.03225806451612903|
|CRP|HOU|             0.03125|
|DAB|LGA|0.023255813953488372|
|DAB|BWI|0.023255813953488372|
|DAB|ATL|0.023255813953488372|
|JAN|MDW|                0.02|
|JAN|HOU|                0.02|
|JAN|BWI|                0.02|
|JAN|MCO|                0.02|
+---+---+--------------------+
only showing top 10 rows     
```

## Connected Components

Connected components finds groups of airports that are reachable from each other. In a well-connected flight network you would expect a single giant component, but isolated or regional airports may form smaller ones.

GraphFrames requires a Spark checkpoint directory for this algorithm:

```python
spark.sparkContext.setCheckpointDir("s3a://flight-bucket/checkpoints")

components = graph.connectedComponents()
components.groupBy("component") \
          .count() \
          .sort("count", ascending=False) \
          .show(10)
          
          
components \
    .join(graph.vertices, on="id") \
    .select("component", "id", "ident", "name") \
    .sort("component") \
    .show(20)          
```

To see which airports belong to the smaller components (if any):

```python
from pyspark.sql.functions import count

smallComponents = components.groupBy("component") \
    .count() \
    .filter("count < 10")

components.join(smallComponents, "component") \
          .select("id", "component") \
          .sort("component") \
          .show()
```

## Shortest Paths

Shortest paths computes the minimum number of hops from every airport to a set of landmark airports. Let's find how many stops are needed to reach `LAX` (Los Angeles) or `JFK` (New York) from any airport in the network:

```python
results = graph.shortestPaths(landmarks=["LAX"])
results.select("id", "distances") \
       .filter("size(distances) > 0") \
       .sort("id") \
       .show(10)
       

READY
Analyzing Flight Data with Spark GraphFrames
READY
Reading the Airport data
 SPARK JOB
FINISHED
%pyspark
from pyspark.sql.types import *

airportsRawDF = spark.read.csv("s3a://flight-bucket/raw/airports", 
    	sep=",", inferSchema="true", header="true")
verticesDF = airportsRawDF.filter("iata_code IS NOT NULL").drop("id").withColumnRenamed("iata_code", "id")
verticesDF.show(5)

+-----+-------------+--------------------+---------------+----------------+------------+---------+-----------+----------+--------------+-----------------+--------+---+----------+--------------------+--------------------+--------------+
|ident|         type|                name|   latitude_deg|   longitude_deg|elevation_ft|continent|iso_country|iso_region|  municipality|scheduled_service|gps_code| id|local_code|           home_link|      wikipedia_link|      keywords|
+-----+-------------+--------------------+---------------+----------------+------------+---------+-----------+----------+--------------+-----------------+--------+---+----------+--------------------+--------------------+--------------+
|  03N|small_airport|      Utirik Airport|      11.222219|      169.851429|           4|       OC|         MH|    MH-UTI| Utirik Island|              yes|     03N|UTK|       03N|                NULL|https://en.wikipe...|          NULL|
| 07FA|small_airport|Ocean Reef Club A...|25.325399398804|-80.274803161621|           8|       NA|         US|     US-FL|     Key Largo|               no|    07FA|OCA|      07FA|https://www.ocean...|https://en.wikipe...|          NULL|
| 07TE|small_airport|       Cuddihy Field|        27.7211|      -97.512802|          39|       NA|         US|     US-TX|Corpus Christi|               no|    07TE|CUX|      07TE|                NULL|                NULL|          NULL|
| 0CO2|small_airport|Crested Butte Air...|      38.851918|     -106.928341|        8980|       NA|         US|     US-CO| Crested Butte|               no|    0CO2|CSE|      0CO2|                NULL|                NULL|Buckhorn Ranch|
| 0NM0|small_airport|    Columbus Airport|      31.823898|     -107.629924|        4024|       NA|         US|     US-NM|      Columbus|               no|    0NM0|CUS|      0NM0|                NULL|https://en.wikipe...|          NULL|
+-----+-------------+--------------------+---------------+----------------+------------+---------+-----------+----------+--------------+-----------------+--------+---+----------+--------------------+--------------------+--------------+
only showing top 5 rows

Took 4 seconds. Last updated by admin at April 05 2026, 4:39:20 PM.
 SPARK JOB
FINISHED
%pyspark
flightSchema = """`year` INTEGER, `month` INTEGER, `dayOfMonth` INTEGER,  `dayOfWeek` INTEGER, `depTime` INTEGER, `crsDepTime` INTEGER, `arrTime` INTEGER, `crsArrTime` INTEGER, `uniqueCarrier` STRING, `flightNum` STRING, `tailNum` STRING, `actualElapsedTime` INTEGER,
                   `crsElapsedTime` INTEGER, `airTime` INTEGER, `arrDelay` INTEGER,`depDelay` INTEGER,`origin` STRING, `destination` STRING, `distance` INTEGER, `taxiIn` INTEGER, `taxiOut` INTEGER, `cancelled` STRING, `cancellationCode` STRING, `diverted` STRING, 
                   `carrierDelay` STRING, `weatherDelay` STRING, `nasDelay` STRING, `securityDelay` STRING, `lateAircraftDelay` STRING"""

flightsRawDF = spark.read.csv("s3a://flight-bucket/raw/flights", 
    	sep=",", inferSchema="false", header="false", schema=f
+----+-----+----------+---------+-------+----------+-------+----------+-------------+---------+-------+-----------------+--------------+-------+--------+--------+---+---+--------+------+-------+---------+----------------+--------+------------+------------+--------+-------------+-----------------+
|year|month|dayOfMonth|dayOfWeek|depTime|crsDepTime|arrTime|crsArrTime|uniqueCarrier|flightNum|tailNum|actualElapsedTime|crsElapsedTime|airTime|arrDelay|depDelay|src|dst|distance|taxiIn|taxiOut|cancelled|cancellationCode|diverted|carrierDelay|weatherDelay|nasDelay|securityDelay|lateAircraftDelay|
+----+-----+----------+---------+-------+----------+-------+----------+-------------+---------+-------+-----------------+--------------+-------+--------+--------+---+---+--------+------+-------+---------+----------------+--------+------------+------------+--------+-------------+-----------------+
|2008|    5|        15|        4|   1512|      1512|   1707|      1659|           FL|      776| N318AT|              115|           107|     91|       8|       0|ATL|FLL|     581|     5|     19|       \N|            NULL|      \N|          NA|          NA|      NA|           NA|               NA|
|2008|    5|        15|        4|   1643|      1624|   1829|      1814|           FL|       76| N926AT|              106|           110|     81|      15|      19|ATL|FLL|     581|     5|     20|       \N|            NULL|      \N|           0|           0|       0|            0|               15|
|2008|    5|        15|        4|   1846|      1848|   2031|      2037|           FL|       75| N300AT|              105|           109|     82|      -6|      -2|ATL|FLL|     581|     6|     17|       \N|            NULL|      \N|          NA|          NA|      NA|           NA|               NA|
|2008|    5|        15|        4|   2218|      2125|      8|      2311|           FL|       79| N166AT|              110|           106|     81|      57|      53|ATL|FLL|     581|     5|     24|       \N|            NULL|      \N|           0|           0|       4|            0|               53|
|2008|    5|        15|        4|   2302|      2305|     43|        46|           FL|       77| N288AT|              101|           101|     81|      -3|      -3|ATL|FLL|     581|     5|     15|       \N|            NULL|      \N|          NA|          NA|      NA|           NA|               NA|
+----+-----+----------+---------+-------+----------+-------+----------+-------------+---------+-------+-----------------+--------------+-------+--------+--------+---+---+--------+------+-------+---------+----------------+--------+------------+------------+--------+-------------+-----------------+
only showing top 5 rows

Took 1 second. Last updated by admin at April 05 2026, 4:39:26 PM.
FINISHED
%pyspark
from graphframes import GraphFrame
graph = GraphFrame(verticesDF, edgesDF)
graph
GraphFrame(v:DataFrame[id: string, ident: string, type: string, name: string, latitude_deg: double, longitude_deg: double, elevation_ft: int, continent: string, iso_country: string, iso_region: string, municipality: string, scheduled_service: string, gps_code: string, local_code: string, home_link: string, wikipedia_link: string, keywords: string], e:DataFrame[src: string, dst: string, year: int, month: int, dayOfMonth: int, dayOfWeek: int, depTime: int, crsDepTime: int, arrTime: int, crsArrTime: int, uniqueCarrier: string, flightNum: string, tailNum: string, actualElapsedTime: int, crsElapsedTime: int, airTime: int, arrDelay: int, depDelay: int, distance: int, taxiIn: int, taxiOut: int, cancelled: string, cancellationCode: string, diverted: string, carrierDelay: string, weatherDelay: string, nasDelay: string, securityDelay: string, lateAircraftDelay: string])
Took 0 seconds. Last updated by admin at April 05 2026, 4:39:29 PM.
 SPARK JOB
FINISHED
%pyspark
graph.edges.filter("src = 'LAX' AND dst = 'SFO'").show()
+----+-----+----------+---------+-------+----------+-------+----------+-------------+---------+-------+-----------------+--------------+-------+--------+--------+---+---+--------+------+-------+---------+----------------+--------+------------+------------+--------+-------------+-----------------+
|year|month|dayOfMonth|dayOfWeek|depTime|crsDepTime|arrTime|crsArrTime|uniqueCarrier|flightNum|tailNum|actualElapsedTime|crsElapsedTime|airTime|arrDelay|depDelay|src|dst|distance|taxiIn|taxiOut|cancelled|cancellationCode|diverted|carrierDelay|weatherDelay|nasDelay|securityDelay|lateAircraftDelay|
+----+-----+----------+---------+-------+----------+-------+----------+-------------+---------+-------+-----------------+--------------+-------+--------+--------+---+---+--------+------+-------+---------+----------------+--------+------------+------------+--------+-------------+-----------------+
|2008|    4|         7|        1|   1902|      1900|   2016|      2025|           WN|      344| N269WN|               74|            85|     62|      -9|       2|LAX|SFO|     337|     4|      8|       \N|            NULL|      \N|          NA|          NA|      NA|           NA|               NA|
|2008|    4|         7|        1|   1357|      1340|   1514|      1505|           WN|      450| N207WN|               77|            85|     60|       9|      17|LAX|SFO|     337|     4|     13|       \N|            NULL|      \N|          NA|          NA|      NA|           NA|               NA|
|2008|    4|         7|        1|    800|       800|    909|       925|           WN|      730| N384SW|               69|            85|     59|     -16|       0|LAX|SFO|     337|     4|      6|       \N|            NULL|      \N|          NA|          NA|      NA|           NA|               NA|
|2008|    4|         7|        1|   1744|      1740|   1854|      1905|           WN|     1658| N901WN|               70|            85|     58|     -11|       4|LAX|SFO|     337|     4|      8|       \N|            NULL|      \N|          NA|          NA|      NA|           NA|               NA|
|2008|    4|         7|        1|   1111|      1035|   1226|      1200|           WN|     2039| N728SW|               75|            85|     64|      26|      36|LAX|SFO|     337|     4|      7|       \N|            NULL|      \N|          11|           0|       0|            0|               15|
|2008|    4|         7|        1|   1159|      1200|   1308|      1325|           WN|     2470| N300SW|               69|            85|     57|     -17|      -1|LAX|SFO|     337|     4|      8|       \N|            NULL|      \N|          NA|          NA|      NA|           NA|               NA|
|2008|    4|         7|        1|   2114|      2115|   2231|      2240|           WN|     2877| N389SW|               77|            85|     58|      -9|      -1|LAX|SFO|     337|     7|     12|       \N|            NULL|      \N|          NA|          NA|      NA|           NA|               NA|
|2008|    4|         7|        1|   1620|      1625|   1732|      1750|           WN|     3135| N723SW|               72|            85|     58|     -18|      -5|LAX|SFO|     337|     4|     10|       \N|            NULL|      \N|          NA|          NA|      NA|           NA|               NA|
|2008|    4|         7|        1|    949|       950|   1058|      1115|           WN|     3149| N413WN|               69|            85|     59|     -17|      -1|LAX|SFO|     337|     4|      6|       \N|            NULL|      \N|          NA|          NA|      NA|           NA|               NA|
|2008|    4|         7|        1|   2024|      2020|   2141|      2145|           WN|     3254| N323SW|               77|            85|     58|      -4|       4|LAX|SFO|     337|     5|     14|       \N|            NULL|      \N|          NA|          NA|      NA|           NA|               NA|
|2008|    4|         7|        1|    630|       630|    740|       755|           WN|     3495| N691WN|               70|            85|     56|     -15|       0|LAX|SFO|     337|     6|      8|       \N|            NULL|      \N|          NA|          NA|      NA|           NA|               NA|
|2008|    4|         7|        1|   1531|      1510|   1640|      1635|           WN|     3500| N752SW|               69|            85|     59|       5|      21|LAX|SFO|     337|     4|      6|       \N|            NULL|      \N|          NA|          NA|      NA|           NA|               NA|
|2008|    4|         8|        2|   1859|      1900|   2011|      2025|           WN|      344| N718SW|               72|            85|     58|     -14|      -1|LAX|SFO|     337|     5|      9|       \N|            NULL|      \N|          NA|          NA|      NA|           NA|               NA|
|2008|    4|         8|        2|   1342|      1340|   1456|      1505|           WN|      450| N227WN|               74|            85|     58|      -9|       2|LAX|SFO|     337|     3|     13|       \N|            NULL|      \N|          NA|          NA|      NA|           NA|               NA|
|2008|    4|         8|        2|    759|       800|    906|       925|           WN|      730| N389SW|               67|            85|     56|     -19|      -1|LAX|SFO|     337|     4|      7|       \N|            NULL|      \N|          NA|          NA|      NA|           NA|               NA|
|2008|    4|         8|        2|   1741|      1740|   1852|      1905|           WN|     1658| N733SA|               71|            85|     60|     -13|       1|LAX|SFO|     337|     4|      7|       \N|            NULL|      \N|          NA|          NA|      NA|           NA|               NA|
|2008|    4|         8|        2|   NULL|      1035|   NULL|      1200|           WN|     2039|   NULL|             NULL|            85|   NULL|    NULL|    NULL|LAX|SFO|     337|  NULL|   NULL|       \N|               A|      \N|          NA|          NA|      NA|           NA|               NA|
|2008|    4|         8|        2|   1209|      1200|   1318|      1325|           WN|     2470| N625SW|               69|            85|     58|      -7|       9|LAX|SFO|     337|     4|      7|       \N|            NULL|      \N|          NA|          NA|      NA|           NA|               NA|
|2008|    4|         8|        2|   2148|      2115|   2305|      2240|           WN|     2877| N323SW|               77|            85|     61|      25|      33|LAX|SFO|     337|     4|     12|       \N|            NULL|      \N|          25|           0|       0|            0|                0|
|2008|    4|         8|        2|   1632|      1625|   1745|      1750|           WN|     3135| N797MX|               73|            85|     60|      -5|       7|LAX|SFO|     337|     4|      9|       \N|            NULL|      \N|          NA|          NA|      NA|           NA|               NA|
+----+-----+----------+---------+-------+----------+-------+----------+-------------+---------+-------+-----------------+--------------+-------+--------+--------+---+---+--------+------+-------+---------+----------------+--------+------------+------------+--------+-------------+-----------------+
only showing top 20 rows

Took 2 seconds. Last updated by admin at April 05 2026, 4:35:40 PM.
 SPARK JOB
FINISHED
%pyspark
graph.vertices.select("id", "ident").show(5)
+---+-----+
| id|ident|
+---+-----+
|UTK|  03N|
|OCA| 07FA|
|CUX| 07TE|
|CSE| 0CO2|
|CUS| 0NM0|
+---+-----+
only showing top 5 rows

Took 2 seconds. Last updated by admin at April 05 2026, 4:40:15 PM.
 SPARK JOB
FINISHED
%pyspark
num_of_airports = graph.vertices.count()
num_of_airports
9104
Took 2 seconds. Last updated by admin at April 05 2026, 4:40:18 PM.
 SPARK JOB
FINISHED
%pyspark
num_of_flights = graph.edges.count()
num_of_flights
50000
Took 2 seconds. Last updated by admin at April 05 2026, 4:40:20 PM.
 SPARK JOB
FINISHED
%pyspark
from pyspark.sql.functions import col
graph.edges.groupBy("src", "dst") \
		.max("distance") \
		.sort(col("max(distance)") \
		.desc()) \
		.show(4)
+---+---+-------------+
|src|dst|max(distance)|
+---+---+-------------+
|HNL|PHX|         2917|
|PHX|HNL|         2917|
|HNL|LAS|         2762|
|LAS|HNL|         2762|
+---+---+-------------+
only showing top 4 rows

Took 2 seconds. Last updated by admin at April 05 2026, 4:40:24 PM.
 SPARK JOB
FINISHED
%pyspark
graph.edges.groupBy("src", "dst") \
        .avg("depDelay") \
        .sort(col("avg(depDelay)") \
        .desc()) \
        .show(5)
+---+---+------------------+
|src|dst|     avg(depDelay)|
+---+---+------------------+
|MCO|TUL|              93.0|
|MCO|SLC|              68.0|
|HNL|PHX| 66.29032258064517|
|SFO|IND|              53.0|
|MCI|SMF|46.333333333333336|
+---+---+------------------+
only showing top 5 rows

Took 1 second. Last updated by admin at April 05 2026, 4:40:39 PM.
 SPARK JOB
FINISHED
%pyspark
graph.degrees.sort("degree", ascending=False).show(5)

+---+------+
| id|degree|
+---+------+
|ATL| 15170|
|MCO|  5070|
|BWI|  4761|
|LAX|  4555|
|HNL|  4254|
+---+------+
only showing top 5 rows

Took 1 second. Last updated by admin at April 05 2026, 4:40:46 PM.
 SPARK JOB
FINISHED
%pyspark
graph.inDegrees.sort("inDegree", ascending=False).show(5)
+---+--------+
| id|inDegree|
+---+--------+
|ATL|    7619|
|MCO|    2544|
|BWI|    2389|
|LAX|    2288|
|HNL|    2127|
+---+--------+
only showing top 5 rows

Took 2 seconds. Last updated by admin at April 05 2026, 4:24:22 PM.
 SPARK JOB
FINISHED
%pyspark
graph.outDegrees.sort("outDegree", ascending=False).show(5)
+---+---------+
| id|outDegree|
+---+---------+
|ATL|     7551|
|MCO|     2526|
|BWI|     2372|
|LAX|     2267|
|HNL|     2127|
+---+---------+
only showing top 5 rows

Took 2 seconds. Last updated by admin at April 05 2026, 4:24:26 PM.
 SPARK JOB
FINISHED
%pyspark
roundTrips = graph.find("(a)-[e1]->(b); (b)-[e2]->(a)")
roundTrips.select("a.ident", "b.ident").distinct().show(10)
+-----+-----+
|ident|ident|
+-----+-----+
| KBHM| KPHX|
| KBHM| KLAS|
| KBWI| KBHM|
| KCMH| KMDW|
| KHOU| KDAL|
| KPHX| KOKC|
| KPIT| KPHL|
| KTPA| KRDU|
| KBDL| KLAS|
| KDEN| KATL|
+-----+-----+
only showing top 10 rows

Took 6 seconds. Last updated by admin at April 05 2026, 4:41:22 PM.
 SPARK JOB
FINISHED
%pyspark
twohop = graph.find("(a)-[e1]->(b); (b)-[e2]->(c)")
twohop.filter("a.id = 'BOS'") \
      .select("a.id", "b.id", "c.id") \
      .distinct() \
      .show(10)
+---+---+---+
| id| id| id|
+---+---+---+
|BOS|MDW|SAT|
|BOS|BWI|AUS|
|BOS|BWI|MIA|
|BOS|MCO|IAD|
|BOS|MCO|CAK|
|BOS|BWI|BHM|
|BOS|MDW|LAS|
|BOS|MDW|SRQ|
|BOS|BWI|DAY|
|BOS|ATL|RIC|
+---+---+---+
only showing top 10 rows

Took 3 seconds. Last updated by admin at April 05 2026, 4:42:05 PM.
 SPARK JOB
FINISHED
%pyspark
ranks = graph.pageRank(resetProbability=0.15, maxIter=10)
ranks.vertices \
     .select("id", "pagerank") \
     .sort("pagerank", ascending=False) \
     .show(10)
+---+------------------+
| id|          pagerank|
+---+------------------+
|ATL| 91.10094958290752|
|MCO|30.632088151948064|
|BWI|30.432641628675686|
|LAX| 27.76072868698972|
|LAS|22.438247150782466|
|MDW|22.265006379376754|
|HNL| 18.69727857097317|
|PHX|16.054050168125137|
|HOU|14.584142572179879|
|SAN|14.155859998873886|
+---+------------------+
only showing top 10 rows

Took 1 minute. Last updated by admin at April 05 2026, 4:43:39 PM.
 SPARK JOB
FINISHED
%pyspark
ranks.edges \
     .select("src", "dst", "weight") \
     .distinct() \
     .sort("weight", ascending=False) \
     .show(10)
+---+---+--------------------+
|src|dst|              weight|
+---+---+--------------------+
|BTV|BWI|0.041666666666666664|
|XNA|LAX| 0.03225806451612903|
|CRP|HOU|             0.03125|
|DAB|LGA|0.023255813953488372|
|DAB|BWI|0.023255813953488372|
|DAB|ATL|0.023255813953488372|
|JAN|MDW|                0.02|
|JAN|HOU|                0.02|
|JAN|BWI|                0.02|
|JAN|MCO|                0.02|
+---+---+--------------------+
only showing top 10 rows

Took 6 seconds. Last updated by admin at April 05 2026, 4:45:44 PM.
 SPARK JOB
FINISHED
%pyspark
spark.sparkContext.setCheckpointDir("s3a://flight-bucket/checkpoints")

components = graph.connectedComponents()
components.groupBy("component") \
          .count() \
          .sort("count", ascending=False) \
          .show(10)
+-------------+-----+
|    component|count|
+-------------+-----+
|  17179869205|  105|
|1477468749826|    1|
|1013612281883|    1|
| 592705486881|    1|
|1614907703302|    1|
|1606317768750|    1|
|1348619730952|    1|
| 257698037791|    1|
|1125281431585|    1|
|1554778161163|    1|
+-------------+-----+
only showing top 10 rows

Took 2 minutes. Last updated by admin at April 05 2026, 4:48:49 PM.
 SPARK JOB
ERROR
components \
    .join(graph.vertices, on="id") \
    .select("component", "id", "ident", "name") \
    .sort("component") \
    .show(20)   
+-------------+-----+
|    component|count|
+-------------+-----+
|  17179869205|  105|
|1477468749826|    1|
|1013612281883|    1|
| 592705486881|    1|
|1614907703302|    1|
|1606317768750|    1|
|1348619730952|    1|
| 257698037791|    1|
|1125281431585|    1|
|1554778161163|    1|
+-------------+-----+
only showing top 10 rows

Fail to execute line 13:     .select("component", "id", "ident", "name") \
Traceback (most recent call last):
  File "/tmp/python5751616112060373850/zeppelin_python.py", line 167, in <module>
    exec(code, _zcUserQueryNameSpace)
  File "<stdin>", line 13, in <module>
  File "/opt/bitnami/spark/python/pyspark/sql/dataframe.py", line 3229, in select
    jdf = self._jdf.select(self._jcols(*cols))
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/bitnami/spark/python/lib/py4j-0.10.9.7-src.zip/py4j/java_gateway.py", line 1322, in __call__
    return_value = get_return_value(
                   ^^^^^^^^^^^^^^^^^
  File "/opt/bitnami/spark/python/pyspark/errors/exceptions/captured.py", line 185, in deco
    raise converted from None
pyspark.errors.exceptions.captured.AnalysisException: [AMBIGUOUS_REFERENCE] Reference `ident` is ambiguous, could be: [`ident`, `ident`].
Took 1 minute. Last updated by admin at April 05 2026, 4:54:01 PM.
 SPARK JOB
FINISHED
%pyspark
from pyspark.sql.functions import count

smallComponents = components.groupBy("component") \
    .count() \
    .filter("count < 10")

components.join(smallComponents, "component") \
          .select("id", "component") \
          .sort("component") \

+---+---------+
| id|component|
+---+---------+
|AKD|        0|
|BGM|        1|
|BOX|        2|
|BZT|        3|
|CCK|        4|
|CLQ|        5|
|CNU|        6|
|CRS|        7|
|CSR|        8|
|DWR|        9|
|FAV|       10|
|FIZ|       11|
|FMY|       12|
|GIS|       13|
|GZW|       14|
|HYL|       15|
|ITJ|       16|
|KEB|       17|
|KGL|       18|
|KKQ|       19|
+---+---------+
only showing top 20 rows

Took 3 seconds. Last updated by admin at April 05 2026, 4:49:13 PM.
 SPARK JOB
FINISHED
%pyspark
results = graph.shortestPaths(landmarks=["LAX"])
results.select("id", "distances") \
       .filter("size(distances) > 0") \
       .sort("id") \
       .show(20)
+---+----------+
| id| distances|
+---+----------+
|ABQ|{LAX -> 1}|
|ALB|{LAX -> 2}|
|AMA|{LAX -> 2}|
|ATL|{LAX -> 1}|
|AUS|{LAX -> 1}|
|BDL|{LAX -> 2}|
|BHM|{LAX -> 2}|
|BMI|{LAX -> 2}|
|BNA|{LAX -> 1}|
|BOI|{LAX -> 2}|
|BOS|{LAX -> 2}|
|BTV|{LAX -> 2}|
|BUF|{LAX -> 2}|
|BUR|{LAX -> 2}|
|BWI|{LAX -> 1}|
|CAK|{LAX -> 2}|
|CHS|{LAX -> 2}|
|CLE|{LAX -> 2}|
|CLT|{LAX -> 2}|
|CMH|{LAX -> 2}|
+---+----------+
only showing top 20 rows      
```

The `distances` column is a map from landmark ID to hop count. An airport that has a direct flight to LAX will show `{LAX -> 1}`, so the `distances` represents the number of flights, not miles or time

Unfortunately, GraphFrames' shortestPaths only returns the distances (hop counts), not the actual path taken. It's a known limitation.

To get the actual path you can use BFS (best for a single source→destination path).

## Breadth-First Search (BFS)

BFS finds all paths between two specific airports up to a given maximum number of hops. Let's find all paths from Boston (`BOS`) to Los Angeles (`LAX`) with at most one connection:

```python
paths = graph.bfs(
    fromExpr="id = 'BOS'",
    toExpr="id = 'LAX'",
    maxPathLength=2
)
paths.show(5)

+--------------------+--------------------+--------------------+--------------------+--------------------+
|                from|                  e0|                  v1|                  e1|                  to|
+--------------------+--------------------+--------------------+--------------------+--------------------+
|{KBOS, large_airp...|{2008, 5, 31, 6, ...|{KATL, large_airp...|{2008, 5, 31, 6, ...|{KLAX, large_airp...|
|{KBOS, large_airp...|{2008, 5, 31, 6, ...|{KATL, large_airp...|{2008, 5, 31, 6, ...|{KLAX, large_airp...|
|{KBOS, large_airp...|{2008, 5, 31, 6, ...|{KATL, large_airp...|{2008, 5, 31, 6, ...|{KLAX, large_airp...|
|{KBOS, large_airp...|{2008, 5, 31, 6, ...|{KATL, large_airp...|{2008, 5, 31, 6, ...|{KLAX, large_airp...|
|{KBOS, large_airp...|{2008, 5, 31, 6, ...|{KATL, large_airp...|{2008, 5, 31, 6, ...|{KLAX, large_airp...|
+--------------------+--------------------+--------------------+--------------------+--------------------+
only showing top 5 rows
```

Each row in the result is a complete path: `from` vertex → edge → (intermediate vertex → edge →) `to` vertex. You can filter by edge properties — for example, only paths where neither leg is cancelled:

```python
paths = graph.bfs(
    fromExpr="id = 'BOS'",
    toExpr="id = 'LAX'",
    edgeFilter="cancelled IS NOT NULL",
    maxPathLength=2
)
paths.select("from.id", "e0.flightNum", "v1.id", "e1.flightNum", "to.id").show(5)

+---+---------+---+---------+---+
| id|flightNum| id|flightNum| id|
+---+---------+---+---------+---+
|BOS|      492|ATL|       41|LAX|
|BOS|      492|ATL|       50|LAX|
|BOS|      492|ATL|       40|LAX|
|BOS|      492|ATL|       49|LAX|
|BOS|      492|ATL|       54|LAX|
+---+---------+---+---------+---+
only showing top 5 rows
```	

