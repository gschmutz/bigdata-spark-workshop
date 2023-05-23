# Graph Analysis using Spark GraphFrames

In this workshop we will work with [Apache Spark GraphFrames](https://graphframes.github.io/graphframes/docs/_site/index.html) to build and execute graph queries.

We assume that the **Data Platform** described [here](../01-environment) is running and accessible. 

The same data as in the [Object Storage Workshop](../02-object-storage/README.md) will be used. We will show later how to re-upload the files, if you no longer have them available.

We assume that you have done Workshop 3 **Getting Started using Spark RDD and DataFrames**, where you have learnt how to use Spark form either `pyspark`, Apache Zeppelin or Jupyter Notebook. 
 
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
docker exec -ti awscli s3cmd put /data-transfer/flight-data/airports.csv s3://flight-bucket/raw/airports/airports.csv
```

or with `mc`

```bash
docker exec -ti minio-mc mc cp /data-transfer/flight-data/airports.csv minio-1/flight-bucket/raw/airports/airports.csv
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
docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_4_1.csv s3://flight-bucket/raw/flights/ &&
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

## Create a new Zeppelin notebook

For this workshop we will be using Zeppelin discussed above. In a browser window, navigate to <http://dataplatform:28080> and you should see the Apache Zeppelin homepage. Click on **Login** and use `admin` as the **User Name** and `changeme` as the **Password** and click on **Login**. 

But you can easily adapt it to use either **PySpark** or **Apache Jupyter**.

In a browser window, navigate to <http://dataplatform:28080>.

Now let's create a new notebook by clicking on the **Create new note** link and set the **Note Name** to `SparkDataFrame` and set the **Default Interpreter** to `spark`. 

Click on **Create Note** and a new Notebook is created with one cell which is empty. 

### Add some Markdown first

Navigate to the first cell and start with a title. By using the `%md` directive we can switch to the Markdown interpreter, which can be used for displaying static text.

```
%md # Analyzing Flight Data with Spark GraphFrames
```

Click on the **>** symbol on the right or enter **Shift** + **Enter** to run the paragraph.

The markdown code should now be rendered as a Heading-1 title.

## Create Vertices and Edges

The data for vertices (airports) and edges (flights) is provided in CSV format. We will read these datafiles in a similar way as in workshop 4 and create two DataFrames, one for vertices and one for edges. Then we’ll use these to create a graph represented as an instance of GraphFrame.

```
%md ## Reading the Airport data
```

Now let's load the data for the vertices (airports), which we have uploaded to `s3://flight-bucket/raw/airports/`. We rename `iata` to `id` to conform with the requirements of a GraphFrame.

```python
%pyspark
from pyspark.sql.types import *

airportsRawDF = spark.read.csv("s3a://flight-bucket/raw/airports", 
    	sep=",", inferSchema="true", header="true")
verticesDF = airportsRawDF.withColumnRenamed("iata", "id")
verticesDF.show(5)
```

Now let's load the data for the edges (flight data)

```python
%pyspark
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
%pyspark
from graphframes import GraphFrame
graph = GraphFrame(verticesDF, edgesDF)
graph
```

## Flight analysis

Now that we have created a graph, we can execute queries on it. For example, now we can query the `GraphFrame` to answer the following questions.

* How many airports are there?

```python
%pyspark
num_of_airports = graph.vertices.count()
num_of_airports
```

* How many flights are there?

```python
%pyspark
num_of_flights = graph.edges.count()
num_of_flights
```
	
* Which flight routes have the longest distance?

```python
%pyspark
from pyspark.sql.functions import col
graph.edges
        .groupBy("src", "dst") \
		.max("distance") \
		.sort(col("max(distance)") \
		.desc()) \
		.show(4)
```	

* Which flight routes have the highest average delays?

```python
%pyspark
graph.edges
        .groupBy("src", "dst") \
        .avg("depDelay") \
        .sort(col("avg(depDelay)") \
        .desc()) \
        .show(5) \
```	

