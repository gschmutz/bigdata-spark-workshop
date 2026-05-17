# Graph Analysis using Spark GraphFrames

In this workshop we will work with [Apache Spark GraphFrames](https://graphframes.github.io/graphframes/docs/_site/index.html) to build and execute graph queries.

## Table of Contents

- [What you will learn](#what-you-will-learn)
- [Prerequisites](#prerequisites)
- [Prepare the data, if no longer available](#prepare-the-data-if-no-longer-available)
- [Create Vertices and Edges](#create-vertices-and-edges)
- [Building the graph](#building-the-graph)
- [Flight analysis](#flight-analysis)
- [Degree Analysis](#degree-analysis)
- [Subgraph Filtering](#subgraph-filtering)
- [Motif Finding](#motif-finding)
- [PageRank](#pagerank)
- [Connected Components](#connected-components)
- [Shortest Paths](#shortest-paths)
- [Breadth-First Search (BFS)](#breadth-first-search-bfs)

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

- The **Data Platform** described [here](../00-environment) is running and accessible
- Workshop 3 ([Getting Started using Spark RDD and DataFrames](../03-spark-getting-started)) completed

## Prepare the data, if no longer available

The data needed here has been uploaded in workshop 2 - [Working with RustFS Object Storage](01b-rustfs-object-storage). You can skip this section, if you still have the data available in Object Storage. We show both `s3cmd` and the `mc` version of the commands:

Create the flight bucket:

```bash
docker exec -ti awscli s3cmd mb s3://flight-bucket
```

Upload the data

```bash
# Airports
docker exec -ti awscli s3cmd put /data-transfer/airport-data/airports.csv s3://flight-bucket/raw/airports/airports.csv

# Plane-Data
docker exec -ti awscli s3cmd put /data-transfer/flight-data/plane-data.csv s3://flight-bucket/raw/planes/plane-data.csv

# Carriers
docker exec -ti awscli s3cmd put /data-transfer/flight-data/carriers.json s3://flight-bucket/raw/carriers/carriers.json

# Flights (we copy one month from flights-medium to get more flights to analyze in this example)
docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-medium/flights_2008_1.csv s3://flight-bucket/raw/flights/ &&
   docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_4_2.csv s3://flight-bucket/raw/flights/ &&
   docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_5_1.csv s3://flight-bucket/raw/flights/ &&
   docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_5_2.csv s3://flight-bucket/raw/flights/ &&
   docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_5_3.csv s3://flight-bucket/raw/flights/
```

## Working with Spark and GraphFrames

In a browser window, navigate to 

  * for Zeppelin:  <http://dataplatform:28080>
  * for Jupyter: <http://dataplatform:28888>

Now let's create a new notebook and name it `SparkGraphFrame`. 

For **Jupyter**, perform the next paragraph, for **Apache Zeppelin**, this is not necessary and the Spark context is pre-configured.

### If you are using Jupyter

You have to create the Spark context with additional configuration settings in the init script:

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
conf.set("spark.hadoop.fs.s3a.endpoint", "http://rustfs-1:9000")
conf.set("spark.hadoop.fs.s3a.path.style.access", "true")
conf.set("spark.hadoop.fs.s3a.access.key", accessKey)
conf.set("spark.hadoop.fs.s3a.secret.key", secretKey)
conf.set("spark.hadoop.fs.s3a.aws.credentials.provider", "org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider")
conf.set("spark.jars.packages", "io.graphframes:graphframes-spark3_2.12:0.11.0,io.graphframes:graphframes-graphx-spark3_2.12:0.11.0")

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

airportSchema = "`id` INTEGER, `ident` STRING, `type` STRING, `name` STRING, \
    `latitude_deg` DOUBLE, `longitude_deg` DOUBLE, `elevation_ft` INTEGER, \
    `continent` STRING, `iso_country` STRING, `iso_region` STRING, \
    `municipality` STRING, `scheduled_service` STRING, `gps_code` STRING, \
    `iata_code` STRING, `local_code` STRING, `home_link` STRING, \
    `wikipedia_link` STRING, `keywords` STRING"

airportsRawDF = spark.read.csv("s3a://flight-bucket/raw/airports", 
    	sep=",", inferSchema="false", header="true", schema=airportSchema)
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

> **What you should see:** `9104` — the number of distinct airports in the dataset that have a non-null IATA code (used as the vertex `id`).

> **What just happened?** `graph.vertices.count()` triggered a Spark action on the vertices DataFrame. The filter applied when building `verticesDF` excluded airports without an IATA code, because GraphFrames requires a non-null `id` field for all vertices to uniquely identify them in the graph.

* How many flights are there?

```python
num_of_flights = graph.edges.count()
num_of_flights
```

> **What you should see:** `645765` — the total number of flight records across all the CSV files loaded.

> **What just happened?** `graph.edges.count()` triggered a Spark action on the edges DataFrame, which contains one row per flight. The edges represent directed connections — a flight from BOS to LAX is a different edge from a flight from LAX to BOS, so both directions are counted separately.
	
* Which flight routes have the longest distance?

```python
from pyspark.sql.functions import col
graph.edges.groupBy("src", "dst") \
		.max("distance") \
		.sort(col("max(distance)") \
		.desc()) \
		.show(4)
```	

and we will see that Honolulu to Newark is the longest flight in the dataset.

```
+---+---+-------------+
|src|dst|max(distance)|
+---+---+-------------+
|HNL|EWR|         4962|
|EWR|HNL|         4962|
|ATL|HNL|         4502|
|HNL|ATL|         4502|
+---+---+-------------+
only showing top 4 rows
```

> **What you should see:** The top four routes by maximum distance, with Phoenix↔Honolulu (PHX↔HNL at 2,917 miles) as the longest, followed by Las Vegas↔Honolulu. Both directions appear as separate rows because GraphFrame edges are directed.

> **What just happened?** `graph.edges` is a plain Spark DataFrame — GraphFrames exposes the underlying edge data directly so you can use the full Spark DataFrame API on it. The `groupBy("src","dst").max("distance")` and `sort()` are standard Spark DataFrame operations; no graph-specific logic was needed for this query.

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
+---+---+-------------+
|src|dst|avg(depDelay)|
+---+---+-------------+
|SFO|SMX|        325.0|
|TUL|PIA|        243.0|
|ONT|SAN|        221.0|
|ICT|PIA|        215.0|
|ACV|SJC|        211.0|
+---+---+-------------+
only showing top 5 rows
```

> **What you should see:** The five routes with the highest average departure delay. SFO→SMX tops the list with 325 minutes average — likely driven by a small number of flights on that route, so a single very delayed flight skews the average significantly.

> **What just happened?** The same DataFrame aggregation pattern as above but using `.avg("depDelay")`. GraphFrames adds no overhead for this type of query — you are working directly with the raw edge DataFrame containing the flight CSV data.

## Degree Analysis

GraphFrames provides built-in methods to compute the degree of each vertex — the number of edges connected to it. For a flight network this directly answers "which airports are the busiest?".

* Total degree (incoming + outgoing flights):

```python
graph.degrees.sort("degree", ascending=False).show(5)

+---+------+
| id|degree|
+---+------+
|ATL| 82957|
|ORD| 59872|
|DFW| 48296|
|LAX| 41781|
|DEN| 39536|
+---+------+
only showing top 5 rows
```

* Incoming flights only (most popular destination airports):

```python
graph.inDegrees.sort("inDegree", ascending=False).show(5)

+---+--------+
| id|inDegree|
+---+--------+
|ATL|   41500|
|ORD|   29936|
|DFW|   24155|
|LAX|   20901|
|DEN|   19766|
+---+--------+
only showing top 5 rows
```

* Outgoing flights only (most active origin airports):

```python
graph.outDegrees.sort("outDegree", ascending=False).show(5)

+---+---------+
| id|outDegree|
+---+---------+
|ATL|    41457|
|ORD|    29936|
|DFW|    24141|
|LAX|    20880|
|DEN|    19770|
+---+---------+
only showing top 5 rows
```

> **What you should see:** ATL (Atlanta Hartsfield-Jackson) dominates all three rankings with 15,170 total connections, 7,619 incoming, and 7,551 outgoing — confirming it as the dominant hub in this dataset. The slight asymmetry between in- and out-degree for ATL reflects a sampling imbalance in the flight extract.

> **What just happened?** `graph.degrees`, `graph.inDegrees`, and `graph.outDegrees` each trigger a full scan of the edges DataFrame. Degree is computed by counting all edges incident to each vertex. For a directed graph like a flight network, in-degree = number of arriving flights, out-degree = number of departing flights, and total degree = their sum.

## Motif Finding

Motif finding is one of the most powerful and distinctive features of GraphFrames. It lets you search for **structural patterns** in the graph using a simple declarative syntax. Vertices are written as `(name)` and edges as `[name]`.

Let's find all **round-trip routes** — pairs of airports where a direct flight exists in both directions:

```python
roundTrips = graph.find("(a)-[e1]->(b); (b)-[e2]->(a)")
roundTrips.select("a.id", "b.id").distinct().show(10)

+---+---+
| id| id|
+---+---+
|ATL|GSP|
|MSP|AVL|
|BQN|MCO|
|EWR|STT|
|MCI|IAH|
|CLE|SJU|
|PHL|MCO|
|MLI|MCO|
|SMF|BUR|
|SNA|PHX|
+---+---+
only showing top 10 rows
```

> **What you should see:** Pairs of airports connected by flights in both directions. The motif syntax `"(a)-[e1]->(b); (b)-[e2]->(a)"` matched every pair where a flight from `a` to `b` AND a flight from `b` to `a` both exist in the dataset.

> **What just happened?** Motif finding scans the edge list for structural patterns expressed in GraphFrames' declarative syntax. Parentheses denote vertices, square brackets denote edges, and the semicolon separates sub-patterns that must all be satisfied simultaneously. Internally GraphFrames translates this into a series of DataFrame joins — it is powerful and expressive, but can be expensive for large graphs because matching complex patterns requires cross-joining the edge set.

We can also find **two-hop paths** — airports reachable from a given origin (Boston) via exactly one connection:

```python
twohop = graph.find("(a)-[e1]->(b); (b)-[e2]->(c)")
twohop.filter("a.id = 'BOS'") \
      .select("a.id", "b.id", "c.id") \
      .distinct() \
      .show(10)
      
+---+---+---+
| id| id| id|
+---+---+---+
|BOS|PHL|PBI|
|BOS|BNA|SEA|
|BOS|BWI|AUS|
|BOS|RDU|IAD|
|BOS|JFK|BDL|
|BOS|ORD|EWR|
|BOS|ORD|PSP|
|BOS|CLT|SYR|
|BOS|CLT|PHX|
|BOS|ATL|ABE|
+---+---+---+
only showing top 10 rows     
```

> **What you should see:** Airports reachable from BOS (Boston) via exactly one connecting airport. BOS→PHL→PBI means you can fly Boston to Philadelphia, then to Palm Beach. The `distinct()` call removes duplicate paths caused by multiple flight options on the same route pair.

> **What just happened?** The two-hop motif `"(a)-[e1]->(b); (b)-[e2]->(c)"` joined the edge list with itself on the intermediate vertex `b`. This is a self-join of the edges DataFrame — every outgoing edge from BOS is joined with every outgoing edge from the intermediate airport. The filter `a.id = 'BOS'` is applied after the join, so GraphFrames scans all edges for the pattern and then filters; for a large graph with many airports a more efficient approach would filter before the join using the `vertexFilter` parameter.

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
|ATL|103.05432260837141|
|ORD| 68.69817966511793|
|DFW|  58.8940785635434|
|DEN| 46.10011355304056|
|LAX| 44.60824062837437|
|SLC| 38.93506766249176|
|PHX| 38.54485749207912|
|DTW| 35.56062331178822|
|IAH| 35.44161744240193|
|LAS|  32.2385562916205|
+---+------------------+
only showing top 10 rows
```

> **What you should see:** ATL scores 103.1 — far ahead of the second-ranked airports (ORD, DFW). PageRank measures network centrality, so ATL's score reflects not just its raw flight count but the fact that it is connected to many other important airports.

> **What just happened?** PageRank ran 10 iterations of the standard algorithm (`maxIter=10`). At each iteration every vertex distributes its current rank equally to its out-neighbours, scaled by the out-degree. The `resetProbability=0.15` is the "teleportation" probability — at each step there is a 15% chance of jumping to a random vertex, which prevents rank from pooling at sink nodes (airports with no outgoing flights) and ensures convergence.

You can also inspect which routes carry the most "weight" in the network:

```python
ranks.edges.select("src", "dst", "weight") \
     .distinct() \
     .sort("weight", ascending=False) \
     .show(10)
     
+---+---+--------------------+
|src|dst|              weight|
+---+---+--------------------+
|ADK|ANC|  0.1111111111111111|
|TUP|ATL|                 0.1|
|PLN|DTW|0.041666666666666664|
|ALO|MSP|0.037037037037037035|
|BLI|SLC| 0.03333333333333333|
|ACY|LGA| 0.03225806451612903|
|CMX|MSP| 0.03225806451612903|
|ACY|ATL| 0.03225806451612903|
|RHI|MSP| 0.03225806451612903|
|YKM|SLC|0.030303030303030304|
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
    .join(graph.vertices.alias("v"), on="id") \
    .select("component", "id", "v.ident", "v.name") \
    .sort("component") \
    .show(20)         

+-------------+-----+
|    component|count|
+-------------+-----+
|            1|  286|
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

+---------+---+-----+--------------------+
|component| id|ident|                name|
+---------+---+-----+--------------------+
|        0|AKD| VAAK|       Akola Airport|
|        1|BDL| KBDL|Bradley Internati...|
|        1|STT| TIST|Cyril E. King Air...|
|        1|BWI| KBWI|Baltimore/Washing...|
|        1|STX| TISX|Henry E Rohlsen A...|
|        1|BFL| KBFL|       Meadows Field|
|        1|BQN| TJBQ|Rafael Hernández ...|
|        1|AZO| KAZO|Kalamazoo Battle ...|
|        1|PSE| TJPS|   Mercedita Airport|
|        1|BGM| KBGM|Greater Binghamto...|
|        1|SJU| TJSJ|Luis Munoz Marin ...|
|        1|ACV| KACV|California Redwoo...|
|        1|BGR| KBGR|Bangor Internatio...|
|        1|ACY| KACY|Atlantic City Int...|
|        1|BHM| KBHM|Birmingham-Shuttl...|
|        1|ABQ| KABQ|Albuquerque Inter...|
|        1|BIL| KBIL|Billings Logan In...|
|        1|ACT| KACT|Waco Regional Air...|
|        1|BIS| KBIS|Bismarck Municipa...|
|        1|AEX| KAEX|Alexandria Intern...|
+---------+---+-----+--------------------+
only showing top 20 rows
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

+---+---------+
| id|component|
+---+---------+
|AKD|        0|
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
|KLR|       20|
+---+---------+
only showing top 20 rows          
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
|ABE|{LAX -> 2}|
|ABI|{LAX -> 2}|
|ABQ|{LAX -> 1}|
|ABY|{LAX -> 2}|
|ACT|{LAX -> 2}|
|ACV|{LAX -> 2}|
|ACY|{LAX -> 2}|
|ADK|{LAX -> 3}|
|ADQ|{LAX -> 3}|
|AEX|{LAX -> 2}|
+---+----------+
only showing top 10 rows
```

> **What you should see:** Each airport paired with a `distances` map showing how many hops are needed to reach LAX. Airports with a direct flight show `{LAX -> 1}`, airports requiring one connection show `{LAX -> 2}`. Airports not reachable from LAX within the graph are excluded by the `size(distances) > 0` filter.

> **What just happened?** `graph.shortestPaths()` ran a Breadth-First Search from every landmark airport (LAX) backwards through the reversed graph, computing the minimum number of edges to reach each vertex. The `distances` column is a map because multiple landmarks can be specified in a single call — each landmark gets its own entry in the map. As noted, the hop count represents the number of flight edges traversed, not physical distance or flight time.

The `distances` column is a map from landmark ID to hop count. An airport that has a direct flight to LAX will show `{LAX -> 1}`, so the `distances represents the number of flights, not miles or time

Unfortunately, GraphFrames' shortestPaths only returns the distances (hop counts), not the actual path taken. It's a known limitation.

To get the actual path you can use BFS (best for a single source→destination path).

## Breadth-First Search (BFS)

BFS finds all paths between two specific airports up to a given maximum number of hops. Let's find all paths from Boston (`BOS`) to Los Angeles (`LAX`) with at most 2 hops:

```python
paths = graph.bfs(
    fromExpr="id = 'BOS'",
    toExpr="id = 'LAX'",
    maxPathLength=2
)
paths.show(5)

+--------------------+--------------------+--------------------+
|                from|                  e0|                  to|
+--------------------+--------------------+--------------------+
|{KBOS, large_airp...|{2008, 1, 14, 1, ...|{KLAX, large_airp...|
|{KBOS, large_airp...|{2008, 1, 14, 1, ...|{KLAX, large_airp...|
|{KBOS, large_airp...|{2008, 1, 13, 7, ...|{KLAX, large_airp...|
|{KBOS, large_airp...|{2008, 1, 12, 6, ...|{KLAX, large_airp...|
|{KBOS, large_airp...|{2008, 1, 12, 6, ...|{KLAX, large_airp...|
+--------------------+--------------------+--------------------+
only showing top 5 rows
```


