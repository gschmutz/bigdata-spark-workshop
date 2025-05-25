# Creating a Spark Application

To create a Spark application using Python, you use PySpark, the Python API for Apache Spark. Below is a step-by-step guide to building and running a basic Spark application.


Create a file, e.g. `prep_refined.py`.

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
                   `crsElapsedTime` INTEGER, `airTime` INTEGER, `arrDelay` INTEGER,`depDelay` INTEGER,`origin` STRING, `destination` STRING, `distance` INTEGER, `taxiIn` INTEGER, `taxiOut` INTEGER, `cancelled` STRING, `cancellationCode` STRING, `diverted` STRING,\ 
                   `carrierDelay` STRING, `weatherDelay` STRING, `nasDelay` STRING, `securityDelay` STRING, `lateAircraftDelay` STRING"""
    
    flightsRawDF = spark.read.csv("s3a://flight-bucket/raw/flights", \
    			sep=",", inferSchema="false", header="false", schema=flightSchema)

    flightsRawDF.write.partitionBy("year","month").parquet("s3a://flight-bucket/refined/flights")

    spark.stop()
```
