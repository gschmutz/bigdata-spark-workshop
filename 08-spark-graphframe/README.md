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

spark = SparkSession.builder.appName('Jupyter').config(conf=conf).getOrCreate()
spark.sparkContext.setLogLevel("INFO")

sc = spark.sparkContext
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

The `distances` column is a map from landmark ID to hop count. An airport that has a direct flight to LAX will show `{LAX -> 1}`, so the `distances represents the number of flights, not miles or time

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

