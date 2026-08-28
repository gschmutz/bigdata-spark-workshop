# Running a Spark Application via Spark Connect

In this workshop we create the same flight-data transformation from [Workshop 5 - Creating and running a self-contained Spark Application](../05-spark-application) but instead of packaging and submitting it with `spark-submit`, we connect to Spark remotely using **Spark Connect**.

With Spark Connect the Python script runs entirely on your local machine (or inside Jupyter) and sends operations over gRPC to the `spark-connect` service. No `docker exec` and no `spark-submit` are needed.

## Table of Contents

- [What you will learn](#what-you-will-learn)
- [Prerequisites](#prerequisites)
- [Upload the data, if no longer available](#upload-the-data-if-no-longer-available)
- [How Spark Connect differs from spark-submit](#how-spark-connect-differs-from-spark-submit)
- [Create the Spark Connect application](#create-the-spark-connect-application)
- [Execute the application](#execute-the-application)
- [Verify the output in Object Storage](#verify-the-output-in-object-storage)

## What you will learn

- How Spark Connect lets you run PySpark code as a plain Python script without `spark-submit`
- How the client-side script no longer needs S3 credentials or cluster configuration (the server handles it)
- How to pass command-line arguments to a Spark Connect application using `argparse`
- The difference between the `spark-submit` and Spark Connect execution models

## Prerequisites

- The **Data Platform** described [here](../00-environment) is running and accessible, including the `spark-connect` service
- Workshop 4 ([Data Reading and Writing using DataFrames](../04-spark-dataframe)) completed
- `pyspark` installed locally (`pip install pyspark`) **or** the script run from the Jupyter terminal
- Airport and flight data uploaded to Object Storage (instructions provided if needed)

## Upload the data, if no longer available

The data needed here has been uploaded in workshop 1 — [Working with MinIO Object Storage](../01a-minio-object-storage) or [Working with RustFS Object Storage](../01b-rustfs-object-storage). You can skip this section if you still have the data available in Object Storage.

Create the flight bucket:

```bash
docker exec -ti awscli s3cmd mb s3://flight-bucket
```

Upload all data

```bash
# Airports
docker exec -ti awscli s3cmd put /data-transfer/airport-data/airports.csv s3://flight-bucket/raw/airports/airports.csv

# Plane Data
docker exec -ti awscli s3cmd put /data-transfer/flight-data/plane-data.csv s3://flight-bucket/raw/planes/plane-data.csv

# Carriers
docker exec -ti awscli s3cmd put /data-transfer/flight-data/carriers.json s3://flight-bucket/raw/carriers/carriers.json

# Flights
docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_4_1.csv s3://flight-bucket/raw/flights/ &&
   docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_4_2.csv s3://flight-bucket/raw/flights/ &&
   docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_5_1.csv s3://flight-bucket/raw/flights/ &&
   docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_5_2.csv s3://flight-bucket/raw/flights/ &&
   docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_5_3.csv s3://flight-bucket/raw/flights/
```

## How Spark Connect differs from spark-submit

| | `spark-submit` (Workshop 5) | Spark Connect (this workshop) |
|---|---|---|
| **Where the driver runs** | Inside the `spark-master` container | On your local machine or Jupyter |
| **How to invoke** | `docker exec … spark-submit script.py` | `python script.py` |
| **S3 / cluster config** | In the script via `SparkConf` | On the server; client needs none |
| **`spark.sparkContext`** | Available | Not available (use DataFrame API) |
| **Dependencies** | Packaged with `spark-submit` | `pyspark` installed locally |

> **Why this matters:** Spark Connect separates the client from the server. The Python process on your machine is just a thin client that serialises DataFrame operations and sends them over gRPC to the `spark-connect` service, which executes them on the cluster. This means you can run Spark jobs from any machine — a laptop, a CI runner, a Jupyter notebook — without SSH-ing into the cluster or using `docker exec`.

## Create the Spark Connect application

In a terminal window, first create a folder for the application script:

```bash
cd $DATAPLATFORM_HOME
mkdir -p ./data-transfer/app-connect
```

Create the file `prep_refined.py` in that folder:

```bash
nano ./data-transfer/app-connect/prep_refined.py
```

Copy the following code into the editor window:

```python
import argparse

from pyspark.sql import SparkSession
from pyspark.sql.types import *

def main(s3_bucket: str, s3_raw_path: str, s3_refined_path: str):

    spark = SparkSession.builder \
        .remote("sc://spark-connect:15002") \
        .appName("FlightTransform") \
        .getOrCreate()

    s3_raw_uri = f"s3a://{s3_bucket}/{s3_raw_path}"
    s3_refined_uri = f"s3a://{s3_bucket}/{s3_refined_path}"
    print(f"Reading data from raw {s3_raw_uri} and writing to refined {s3_refined_uri}")

    airportSchema = """`id` INTEGER, `ident` STRING, `type` STRING, `name` STRING,
        `latitude_deg` DOUBLE, `longitude_deg` DOUBLE, `elevation_ft` INTEGER,
        `continent` STRING, `iso_country` STRING, `iso_region` STRING,
        `municipality` STRING, `scheduled_service` STRING, `gps_code` STRING,
        `iata_code` STRING, `local_code` STRING, `home_link` STRING,
        `wikipedia_link` STRING, `keywords` STRING"""

    airportsRawDF = spark.read.csv(f"{s3_raw_uri}/airports",
                sep=",", header="true", schema=airportSchema)
    airportsRawDF.write.mode("overwrite").json(f"{s3_refined_uri}/airports")

    flightSchema = """`year` INTEGER, `month` INTEGER, `dayOfMonth` INTEGER,  `dayOfWeek` INTEGER, `depTime` INTEGER, `crsDepTime` INTEGER, `arrTime` INTEGER, `crsArrTime` INTEGER, `uniqueCarrier` STRING, `flightNum` STRING, `tailNum` STRING, `actualElapsedTime` INTEGER,\
                   `crsElapsedTime` INTEGER, `airTime` INTEGER, `arrDelay` INTEGER,`depDelay` INTEGER,`origin` STRING, `destination` STRING, `distance` INTEGER, `taxiIn` INTEGER, `taxiOut` INTEGER, `cancelled` STRING, `cancellationCode` STRING, `diverted` STRING,
                   `carrierDelay` STRING, `weatherDelay` STRING, `nasDelay` STRING, `securityDelay` STRING, `lateAircraftDelay` STRING"""

    flightsRawDF = spark.read.csv(f"{s3_raw_uri}/flights",
                sep=",", inferSchema="false", header="false", schema=flightSchema)
    flightsRawDF.write.mode("overwrite").partitionBy("year","month").parquet(f"{s3_refined_uri}/flights")

    spark.stop()

if __name__ == "__main__":
    """
    Usage:
        python prep_refined.py --s3-bucket <bucket> --s3-raw-path <path> --s3-refined-path <path>

    Example:
        python prep_refined.py --s3-bucket flight-bucket --s3-raw-path raw --s3-refined-path refined
    """
    parser = argparse.ArgumentParser(description="Spark Connect App with S3 input")
    parser.add_argument("--s3-bucket", required=True, help="S3 bucket name (without s3a://)")
    parser.add_argument("--s3-raw-path", required=True, help="Path in the S3 bucket to the raw data")
    parser.add_argument("--s3-refined-path", required=True, help="Path in the S3 bucket to the refined data")
    args = parser.parse_args()

    main(args.s3_bucket, args.s3_raw_path, args.s3_refined_path)
```

Save with `Ctrl-O` and exit with `Ctrl-X`.

> **What just happened?** Compared to the `spark-submit` version, three things changed:
> 1. `SparkSession.builder.remote("sc://spark-connect:15002")` replaces the full `SparkConf` block — there is no S3, metastore, or executor configuration on the client side because the `spark-connect` server already has all of that.
> 2. The script is a plain Python file — it does not need to be copied into the Spark container.
> 3. `spark.sparkContext` is not used anywhere, which is correct: Spark Connect does not expose the low-level `SparkContext` API to the client.

## Execute the application

Before running, clear the `refined` folder so there are no conflicts with existing data:

```bash
docker exec -ti awscli s3cmd del --recursive s3://flight-bucket/refined
```

**Option A — Run from the Jupyter terminal** (recommended, no local Python setup needed):

Navigate to <http://dataplatform:28888>, open a **Terminal** from the Launcher, and run:

```bash
python /home/jovyan/data-transfer/app-connect/prep_refined.py \
  --s3-bucket flight-bucket \
  --s3-raw-path raw \
  --s3-refined-path refined
```

> **Note:** Inside Jupyter the `/home/jovyan/data-transfer/` path maps to the same `data-transfer/` volume mounted on the host.

**Option B — Run from the host machine** (requires `pyspark` installed locally and `spark-connect` to be reachable on `dataplatform:15002`. In the Python application, in the `remote` call replace `spark-connect` with `dataplatform` or the IP address of the machine the data platform is running on):

```bash
python ./data-transfer/app-connect/prep_refined.py \
  --s3-bucket flight-bucket \
  --s3-raw-path raw \
  --s3-refined-path refined
```

You should see output similar to:

```
Reading data from raw s3a://flight-bucket/raw and writing to refined s3a://flight-bucket/refined
```

followed by Spark progress lines as the jobs execute. The script finishes in a few seconds once both write operations complete.

> **What just happened?** The Python process on your machine connected to the `spark-connect` service over gRPC (port 15002). The service translated the DataFrame operations into Spark jobs and executed them on the cluster — reading from RustFS and writing Parquet/JSON back to RustFS. Your local process never touched the data directly.

## Verify the output in Object Storage

In a terminal window, confirm the refined data was written:

```bash
docker exec -ti awscli s3cmd ls -r s3://flight-bucket/refined/
```

You should see JSON files under `refined/airports/` and Parquet files partitioned by year and month under `refined/flights/`:

```bash
s3://flight-bucket/refined/airports/part-00000-....json
...
s3://flight-bucket/refined/flights/year=2008/month=4/part-00001-....snappy.parquet
s3://flight-bucket/refined/flights/year=2008/month=5/part-00000-....snappy.parquet
```

The output is identical to the `spark-submit` version — the only difference was how the job was launched.
