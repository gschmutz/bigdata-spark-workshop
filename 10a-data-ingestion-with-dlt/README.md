# Data Ingestion with dlt

In this workshop we will use [dlt](https://dlthub.com/) (data load tool) to ingest flight data from a local landing zone into Object storage. This covers the same ingestion scenario as [Workshop 10 - Data Ingestion with Apache NiFi](../10-data-ingestion-with-nifi), but uses a lightweight Python-native approach instead of a visual flow tool.

[dlt](https://dlthub.com/product/dlt) is an open-source Python library that turns any data source into a structured, incrementally-loaded pipeline with built-in state tracking, schema inference, and normalization.

## Table of Contents

- [What you will learn](#what-you-will-learn)
- [Prerequisites](#prerequisites)
- [Create the S3 bucket, if not available](#create-the-s3-bucket-if-not-available)
- [Install dlt](#install-dlt)
- [Configure Credentials](#configure-credentials)
- [Create the Landing Zone](#create-the-landing-zone)
- [Create the dlt Pipeline](#create-the-dlt-pipeline)
- [Run the Pipeline](#run-the-pipeline)
- [Verify the Data in Object Storage](#verify-the-data-in-object-storage)
- [Incremental Loading — Run Again with New Files](#incremental-loading--run-again-with-new-files)
- [Inspect the dlt State and Metadata](#inspect-the-dlt-state-and-metadata)
- [Integrating dlt with Airflow](#integrating-dlt-with-airflow)

## What you will learn

- The core dlt concepts: pipelines, sources, resources, and destinations
- How to install dlt and configure RustFS as an S3-compatible filesystem destination
- How to create a dlt source that reads CSV files from a local landing zone
- How to add metadata columns (source filename, ingestion timestamp) to every row
- How to run a dlt pipeline and inspect the load summary
- How dlt's built-in state tracking implements delta loading — only new files are processed on subsequent runs
- How to inspect the dlt metadata and load packages stored alongside your data in Object Storage

## Prerequisites

- The **Data Platform** described [here](../00-environment) is running and accessible
- Python 3.9 or later available on the machine running the pipeline (the host, not inside Docker)
- Write access to the `data-transfer/landing-zone` folder on the host machine

---

## Create the S3 bucket, if not available

For this workshop we will use a new bucket, separate from the other workshops. Use the following command to create the `flight-dlt-bucket`.

```bash
docker exec -ti awscli s3cmd mb s3://flight-dlt-bucket
```

The data will be uploaded by dlt below.

---

## Install dlt

Create a Python virtual environment and install dlt with the filesystem and S3 extras:

```bash
mkdir -p ~/workspace/dlt-ingestion
cd ~/workspace/dlt-ingestion

python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
pip install "dlt[filesystem,s3]" pyarrow
```

Verify the installation:

```bash
dlt --version
```

---

## Configure Credentials

dlt reads credentials from a `secrets.toml` file stored in a `.dlt/` folder next to your pipeline script, or from environment variables.

Create the configuration folder and files:

```bash
mkdir -p .dlt
```

Create `.dlt/config.toml` with the non-secret configuration:

```bash
nano .dlt/config.toml
```

```toml
[runtime]
log_level = "INFO"

[destination.filesystem]
bucket_url = "s3://flight-dlt-bucket"
```

Create `.dlt/secrets.toml` with the Object Storage credentials:

```bash
nano .dlt/secrets.toml
```

```toml
[destination.filesystem.credentials]
aws_access_key_id     = "admin"
aws_secret_access_key = "abc123abc123!"
endpoint_url          = "http://localhost:9005"
region_name           = "us-east-1"
```

> **Note:** `localhost:9005` is the RustFS port exposed on the host machine. Inside Docker containers RustFS is reachable as `rustfs-1:9000`, but the dlt pipeline runs on the host.

---

## Create the Landing Zone

Create the local folder that acts as the ingestion landing zone:

```bash
mkdir -p $DATAPLATFORM_HOME/data-transfer/landing-zone
```

Make sure the folder is writable by your user:

```bash
sudo chown $USER:$USER $DATAPLATFORM_HOME/data-transfer/landing-zone
```

---

## Create the dlt Pipeline

Create the pipeline script:

```bash
nano flight_ingestion.py
```

Paste the following code:

```python
import dlt
import glob
import csv
import os
from datetime import datetime, timezone


LANDING_ZONE = os.path.join(
    os.environ.get("DATAPLATFORM_HOME", "."),
    "data-transfer", "landing-zone"
)


@dlt.resource(
    name="airports",
    write_disposition="append",
    primary_key=["_source_file", "id"],
)
def landing_zone_airports():
    """Yields rows from every new airports CSV file in the landing zone."""
    state = dlt.current.resource_state()
    last_file = state.get("last_file", "")

    pattern = os.path.join(LANDING_ZONE, "airports*.csv")

    for filepath in sorted(glob.glob(pattern)):
        filename = os.path.basename(filepath)

        if filename <= last_file:
            print(f"Skipping already-ingested file: {filename}")
            continue

        print(f"Ingesting file: {filename}")
        ingestion_time = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")

        with open(filepath, newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                row["_source_file"]    = filename
                row["_ingestion_time"] = ingestion_time
                yield row

        state["last_file"] = filename


@dlt.resource(
    name="flights",
    write_disposition="append",
    primary_key=["_source_file", "year", "month", "dayOfMonth",
                 "uniqueCarrier", "flightNum", "origin", "destination"],
)
def landing_zone_flights():
    """Yields rows from every new flights CSV file in the landing zone."""
    state = dlt.current.resource_state()
    last_file = state.get("last_file", "")

    pattern = os.path.join(LANDING_ZONE, "flights*.csv")

    for filepath in sorted(glob.glob(pattern)):
        filename = os.path.basename(filepath)

        if filename <= last_file:
            print(f"Skipping already-ingested file: {filename}")
            continue

        print(f"Ingesting file: {filename}")
        ingestion_time = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")

        with open(filepath, newline="", encoding="utf-8") as f:
            reader = csv.DictReader(
                f,
                fieldnames=[
                    "year","month","dayOfMonth","dayOfWeek","depTime",
                    "crsDepTime","arrTime","crsArrTime","uniqueCarrier",
                    "flightNum","tailNum","actualElapsedTime","crsElapsedTime",
                    "airTime","arrDelay","depDelay","origin","destination",
                    "distance","taxiIn","taxiOut","cancelled","cancellationCode",
                    "diverted","carrierDelay","weatherDelay","nasDelay",
                    "securityDelay","lateAircraftDelay"
                ]
            )
            for row in reader:
                row["_source_file"]    = filename
                row["_ingestion_time"] = ingestion_time
                yield row

        state["last_file"] = filename


@dlt.source
def landing_zone():
    return [landing_zone_airports(), landing_zone_flights()]


if __name__ == "__main__":
    pipeline = dlt.pipeline(
        pipeline_name="flight_ingestion",
        destination="filesystem",
        dataset_name="raw",
    )

    load_info = pipeline.run(landing_zone(), loader_file_format="parquet")
    print(load_info)
```

### Key concepts in this script

| Concept | What it does |
|---|---|
| `@dlt.resource` | Declares a generator function as a dlt data resource |
| `write_disposition="append"` | New rows are appended; existing data is not overwritten |
| `dlt.current.resource_state()` | Persists the high-water mark across runs — enables delta loading |
| `_source_file` | Custom metadata column: which file the row came from |
| `_ingestion_time` | Custom metadata column: when the row was loaded |
| `@dlt.source` | Groups multiple resources into a single source |
| `destination="filesystem"` | Writes output to the Object Storage bucket configured in `.dlt/` |
| `dataset_name="raw"` | Top-level folder inside the bucket |

---

## Run the Pipeline

Copy the first file into the landing zone:

```bash
cp $DATAPLATFORM_HOME/data-transfer/airport-data/airports.csv \
   $DATAPLATFORM_HOME/data-transfer/landing-zone/airports.csv
```

Activate the virtual environment (if not already active) and run the pipeline:

```bash
source venv/bin/activate
python flight_ingestion.py
```

You should see output similar to (INFO log output supressed):

```
Ingesting file: airports.csv
Pipeline flight_ingestion load step completed in 0.44 seconds
1 load package(s) were loaded to destination filesystem and into dataset raw
The filesystem destination used s3://flight-dlt-bucket location to store data
Load package 1779733291.084564 is LOADED and contains no failed jobs
```

> **What you should see:** A log line confirming the file was ingested, followed by a load summary showing the load package ID and destination. The run completes in a few seconds for a single CSV file.

> **What just happened?** dlt ran both resource generators (`landing_zone_airports` and `landing_zone_flights`). Since this was the first run, `last_file` was the empty string for both resources, so every file passed the skip check. The airports rows were yielded, dlt applied schema inference from the CSV headers, and the data was written as a Parquet file to `s3://flight-dlt-bucket/raw/airports/` with the load ID and a content hash embedded in the filename (Parquet is used because `loader_file_format="parquet"` is passed to `pipeline.run()` and `pyarrow` is installed; without this, dlt defaults to JSONL). After the file was fully yielded, the resource set `state["last_file"] = "airports.csv"` via `dlt.current.resource_state()`. dlt persists each resource's state to its pipeline store so the next run knows where to resume. No flights files were in the landing zone yet, so `landing_zone_flights` yielded nothing.

---

## Verify the Data in Object Storage

Use `mc tree` to inspect the bucket structure:

```bash
docker exec -ti rustfs-mc mc tree --files rustfs-1/flight-dlt-bucket/
```

You should see something like:

```
rustfs-1/flight-dlt-bucket/
└─ raw
   ├─ init
   ├─ _dlt_loads
   │  └─ landing_zone__1779735503.326716.jsonl
   ├─ _dlt_pipeline_state
   │  └─ flight_ingestion__1779735503.326716__32bb3b5efed24efe76640fbba3883226ff4bfa8705f09579cab60fc7e3b44c4d.jsonl
   ├─ _dlt_version
   │  └─ landing_zone__1779735508.4355042__32bb3b5efed24efe76640fbba3883226ff4bfa8705f09579cab60fc7e3b44c4d.jsonl
   └─ airports
      └─ 1779735503.326716.6a163d74c7.parquet
```

> **What you should see:** The airports data stored as a Parquet file directly under `raw/airports/`, with the load ID and a content hash embedded in the filename. Plus dlt's own metadata folders `_dlt_loads`, `_dlt_pipeline_state`, and `_dlt_version`. Unlike NiFi which stored the raw CSV, dlt inferred the schema and wrote structured Parquet because `loader_file_format="parquet"` is passed to `pipeline.run()`.

> **What just happened?** dlt's filesystem destination defaults to JSONL, but passing `loader_file_format="parquet"` to `pipeline.run()` (with `pyarrow` installed) tells it to write Parquet instead. Each run produces a new file with the load ID embedded in its filename, so output from different runs never overwrites each other. The `_dlt_loads` folder records completed load packages and `_dlt_pipeline_state` persists each resource's state so the pipeline can resume correctly even when run from a different machine.

dlt writes data as **Parquet files** (via `loader_file_format="parquet"` in `pipeline.run()`), stored as `raw/<resource_name>/<load_id>.<hash>.parquet`. Alongside the data, dlt stores its own metadata in `_dlt_loads` and `_dlt_pipeline_state`.

You can also browse the bucket in the MinIO Console at <http://dataplatform:9010>.

---

## Incremental Loading — Run Again with New Files

Now copy a flights file into the landing zone:

```bash
cp $DATAPLATFORM_HOME/data-transfer/flight-data/flights-small/flights_2008_4_1.csv \
   $DATAPLATFORM_HOME/data-transfer/landing-zone/flights_2008_4_1.csv
```

Run the pipeline again:

```bash
python flight_ingestion.py
```

You should see that `airports.csv` is **skipped** (already ingested) and only the new flights file is processed:

```
Skipping already-ingested file: airports.csv
Ingesting file: flights_2008_4_1.csv
Pipeline flight_ingestion load step completed in 0.43 seconds
1 load package(s) were loaded to destination filesystem and into dataset raw
The filesystem destination used s3://flight-dlt-bucket location to store data
Load package 1779735402.780479 is LOADED and contains no failed jobs
```

> **What you should see:** `airports.csv` is skipped and only the new flights file is processed. The pipeline completes faster because it has fewer rows.

> **What just happened?** Each resource has its own independent state. For `landing_zone_airports`, the persisted `last_file` from the previous run was `airports.csv`, so `airports.csv <= airports.csv` was true and the file was skipped. For `landing_zone_flights`, `last_file` was still `""` (no flights had been ingested yet), so `flights_2008_4_1.csv > ""` was true and the file was processed — `state["last_file"]` was then updated to `flights_2008_4_1.csv`. dlt persists each resource's state inside the destination bucket so it survives restarts and runs from different machines, providing the same "only new files" guarantee as NiFi's `GetFile` processor without any additional configuration.

Copy a second flights file:

```bash
cp $DATAPLATFORM_HOME/data-transfer/flight-data/flights-small/flights_2008_4_2.csv \
   $DATAPLATFORM_HOME/data-transfer/landing-zone/flights_2008_4_2.csv
```

Run once more — only `flights_2008_4_2.csv` will be processed:

```bash
python flight_ingestion.py
```

This is the **delta loading** behaviour: dlt persists the high-water mark in `state["last_file"]` via `dlt.current.resource_state()`, so repeated runs never re-process already-loaded files — equivalent to NiFi's `GetFile` processor which deletes or moves files after pickup.

---

## Inspect the dlt State and Metadata

### View the pipeline state locally

```bash
python - <<'EOF'
import dlt
pipeline = dlt.attach(pipeline_name="flight_ingestion")
print(pipeline.state)
EOF
```

This shows the resource state dlt has persisted for each resource, including the `last_file` high-water mark.

### View load history

```bash
python - <<'EOF'
import dlt
pipeline = dlt.attach(pipeline_name="flight_ingestion")
for load in pipeline.list_completed_load_packages():
    print(load)
EOF
```

### Inspect the state stored in MinIO

dlt also persists its state inside the destination bucket so the pipeline can resume correctly even if run from a different machine:

```bash
docker exec -ti awscli s3cmd ls --recursive s3://flight-dlt-bucket/raw/_dlt_pipeline_state/
```

### Read a loaded Parquet file with Spark

Since the data is stored as Parquet in Object Storage, it can immediately be queried from any workshop that uses Spark:

```python
airportsDF = spark.read.parquet("s3a://flight-dlt-bucket/raw/airports/")
airportsDF.show(5)
```

---

## Integrating dlt with Airflow

Running `flight_ingestion.py` manually works fine for ad-hoc loads, but in production you want the pipeline to execute on a fixed schedule — picking up new files automatically, skipping already-processed ones, and retrying on failure. This section shows how to wrap the dlt pipeline in an Airflow DAG so that the data platform orchestrates it.

dlt ships with a first-class Airflow integration via `PipelineTasksGroup`, a helper that creates the Airflow task graph from a dlt source automatically and wires up the pipeline state so retries and reruns never re-process already-ingested files.

### Install the Airflow provider

The required packages are already installed by the data platform when Airflow starts. The `docker-compose.yml` passes the following to `pip` via `_PIP_ADDITIONAL_REQUIREMENTS` for every Airflow service:

```
dlt[airflow] pyarrow
```

No manual installation step is needed — the packages are available as soon as the containers are running.

### Create the Airflow DAG

Create the DAG file in the Airflow DAGs folder:

```bash
nano $DATAPLATFORM_HOME/scripts/airflow/dags/dlt_flight_ingestion.py
```

Paste the following:

```python
from datetime import datetime
from airflow import DAG
from dlt.helpers.airflow_helper import PipelineTasksGroup
import dlt

from flight_ingestion import landing_zone

default_args = {
    "owner": "airflow",
    "start_date": datetime(2025, 1, 1),
    "retries": 1,
}

with DAG(
    dag_id="dlt_flight_ingestion",
    default_args=default_args,
    schedule="@daily",
    catchup=False,
    tags=["dlt", "flights"],
) as dag:

    # PipelineTasksGroup MUST be created before dlt.pipeline().
    # It redirects dlt's pipelines directory to a temporary path in /tmp/;
    # if the pipeline is created first it locks onto ~/.dlt/pipelines and raises a ValueError.
    tasks = PipelineTasksGroup(
        pipeline_name="flight_ingestion",
        use_data_folder=False,
        wipe_local_data=True,
    )

    pipeline = dlt.pipeline(
        pipeline_name="flight_ingestion",
        destination="filesystem",
        dataset_name="raw",
    )

    tasks.add_run(
        pipeline,
        landing_zone(),
        decompose="none",
        trigger_rule="all_done",
        retries=0,
        loader_file_format="parquet",
    )
```

Save with `Ctrl-O` and exit with `Ctrl-X`.

### How it works

| Concept | Detail |
|---|---|
| `PipelineTasksGroup` | dlt helper that builds the Airflow task graph from a dlt source — **must be created before `dlt.pipeline()`**, otherwise dlt uses the wrong pipelines directory and raises a `ValueError` |
| `decompose="none"` | Runs the entire source as a single Airflow task rather than one task per resource |
| `wipe_local_data=True` | Cleans up dlt's local staging folder after each run to avoid stale data accumulating inside the container |
| `loader_file_format="parquet"` | Same Parquet output setting as in the standalone script |
| `catchup=False` | Prevents Airflow from running back-fills for past daily intervals |
| Delta state | dlt's `resource_state()` is persisted in the destination bucket — Airflow retries and reruns never re-process already-ingested files |

### Make Python dlt script available

The DAG imports `landing_zone` directly from `flight_ingestion`, so that module must be on the Python path of the Airflow worker. The simplest approach is to copy it into the same DAGs folder:

```bash
cp ~/workspace/dlt-ingestion/flight_ingestion.py \
   $DATAPLATFORM_HOME/scripts/airflow/dags/
```

The DAGs folder is mounted into all Airflow containers at `/opt/airflow/dags`, so the file will be visible immediately without restarting any container.

### Make TOML files available

The `.dlt/config.toml` and `.dlt/secrets.toml` files on the host are not visible inside the Airflow worker containers. dlt supports two alternatives:

- **Volume mount:** Add `- ~/workspace/dlt-ingestion/.dlt:/home/airflow/.dlt:ro` to the volumes of each Airflow service in `docker-compose.override.yml`.
- **Environment variables (recommended):** dlt translates every config and secret key into an environment variable using double-underscore separators for nested sections. This avoids mounting files and works cleanly in any containerised deployment.

A ready-made `docker-compose.override.yml` is provided at `$DATAPLATFORM_HOME/docker-compose.override.yml`. Docker Compose merges it automatically with `docker-compose.yml` on every `docker compose up` — no extra flags needed.

The file defines the variables once using a YAML anchor and merges them into all four Airflow services:

```yaml
x-dlt-env: &dlt-env
  DESTINATION__FILESYSTEM__BUCKET_URL: "s3://flight-dlt-bucket"
  RUNTIME__LOG_LEVEL: "INFO"
  DESTINATION__FILESYSTEM__CREDENTIALS__AWS_ACCESS_KEY_ID: "admin"
  DESTINATION__FILESYSTEM__CREDENTIALS__AWS_SECRET_ACCESS_KEY: "abc123abc123!"
  DESTINATION__FILESYSTEM__CREDENTIALS__ENDPOINT_URL: "http://rustfs-1:9000"
  DESTINATION__FILESYSTEM__CREDENTIALS__REGION_NAME: "us-east-1"

services:
  airflow-apiserver:
    environment:
      <<: *dlt-env
  airflow-dag-processor:
    environment:
      <<: *dlt-env
  airflow-scheduler:
    environment:
      <<: *dlt-env
  airflow-init:
    environment:
      <<: *dlt-env
```

Note the endpoint URL uses `rustfs-1:9000` (the internal Docker network address), not `localhost:9005`.

Apply the override by restarting the Airflow services:

```bash
cd $DATAPLATFORM_HOME
docker compose up -d
```

### Run the Airflow DAG

Navigate to the Airflow UI at <http://dataplatform:28139> and log in as `airflow` with password `abc123!`. Click on **DAGs** in the left menu and wait (up to 60 seconds) for `dlt_flight_ingestion` to appear.

Make sure there are CSV files in the landing zone before triggering the DAG:

```bash
cp $DATAPLATFORM_HOME/data-transfer/airport-data/airports.csv \
   $DATAPLATFORM_HOME/data-transfer/landing-zone/airports.csv

cp $DATAPLATFORM_HOME/data-transfer/flight-data/flights-small/flights_2008_4_1.csv \
   $DATAPLATFORM_HOME/data-transfer/landing-zone/flights_2008_4_1.csv
```

Click the **Toggle** button next to `dlt_flight_ingestion` to unpause it, then click the **> Trigger** button in the top right corner and confirm **Single Run** to start a manual run.

> **What you should see:** The DAG run appears in the grid view. The single task `flight_ingestion` turns dark green within a minute or two, indicating a successful run. Click on the task cell and then **Logs** to see the dlt output, including the `Ingesting file:` lines and the final load summary.

> **What just happened?** Airflow executed the `dlt_flight_ingestion` DAG, which called `PipelineTasksGroup.add_run()`. This ran the `landing_zone()` source — both `landing_zone_airports` and `landing_zone_flights` resource generators — exactly as the standalone script does. dlt picked up the CSV files from the landing zone inside the container (the `data-transfer` folder is mounted at `/data-transfer`), applied schema inference, and wrote Parquet files to `s3://flight-dlt-bucket/raw/`. After the run, each resource's `state["last_file"]` high-water mark was persisted in the destination bucket. The next scheduled daily run will skip both files already ingested and only process new ones that appear in the landing zone.

