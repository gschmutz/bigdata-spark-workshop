# Job Scheduling with Airflow

In this workshop we will see how we can use [Apache Airflow](http://airflow.apache.org) to schedule a Spark Job. 

## Prepare the data, if no longer available

The data needed here has been uploaded in workshop 2 - [Working with MinIO Object Storage](02-object-storage). You can skip this section, if you still have the data available in MinIO. We show both `s3cmd` and the `mc` version of the commands:

Create the flight bucket:

```bash
docker exec -ti awscli s3cmd mb s3://flight-bucket
```

**Flights:**

```bash
docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_4_1.csv s3://flight-bucket/raw/flights/ &&
   docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_4_2.csv s3://flight-bucket/raw/flights/ &&
   docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_5_1.csv s3://flight-bucket/raw/flights/ &&
   docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_5_2.csv s3://flight-bucket/raw/flights/ &&
   docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_5_3.csv s3://flight-bucket/raw/flights/
```


## Create the Spark Python program

```python
import sys
from random import random
from operator import add

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

    partitions = int(sys.argv[1]) if len(sys.argv) > 1 else 2
    n = 100000 * partitions

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


```python
"""
Example Airflow DAG to submit Apache Spark applications using
`SparkSubmitOperator`, `SparkJDBCOperator` and `SparkSqlOperator`.
"""
import airflow
from datetime import timedelta
from airflow import DAG
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator 
from airflow.utils.dates import days_ago
from airflow.providers.amazon.aws.transfers.local_to_s3 import (
    LocalFilesystemToS3Operator,
)
from airflow.providers.amazon.aws.operators.s3 import (
    S3CopyObjectOperator,
    S3DeleteObjectsOperator,
)

args = {
    'owner': 'Airflow',
}

with DAG(
    dag_id='example_spark_operator',
    default_args=args,
    schedule_interval=None,
    start_date=days_ago(2),
    tags=['example'],
) as dag:

    create_local_to_s3_job = LocalFilesystemToS3Operator(
       task_id="create_local_to_s3_job",
       filename="/data-transfer/flight-data/airports.csv",
       dest_key="raw/airports/airports.csv",
       dest_bucket="flight-bucket",
       replace=True,
    )
    
    pyspark_submit_job = SparkSubmitOperator(
        application="/data-transfer/spark/python/pi.py", task_id="python_job"
    )
    

    create_local_to_s3_job >> pyspark_submit_job

```

    
    
    
    
    
    
    