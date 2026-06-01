# Working with lakeFS Data Versioning and Apache Iceberg

In this workshop we will work with [lakeFS](https://lakefs.io/), a Git-like data versioning platform, combined with [Apache Iceberg](https://iceberg.apache.org/) and [Apache Spark](https://spark.apache.org/) to demonstrate how to safely manage data transformations using branches, commits, diffs, and merges — applied to data rather than code.

We use the [Airports Open Dataset](https://ourairports.com/data/) (81,193 airports worldwide) as the working dataset throughout the workshop.

> **Note:** This workshop requires the **LakeFS Data Platform** environment described in [00-environment/docker-lakefs](../00-environment/docker-lakefs). This is a different stack than the one used in other workshops.

## Table of Contents

- [What you will learn](#what-you-will-learn)
- [Prerequisites](#prerequisites)
- [Accessing the Tools](#accessing-the-tools)
- [Using the Jupyter Notebook](#using-the-jupyter-notebook)
- [Step 1 — Configuration](#step-1--configuration)
- [Step 2 — Setup: Repository, Branches, and Spark Session](#step-2--setup-repository-branches-and-spark-session)
- [Step 3 — Load Airport Data into an Iceberg Table](#step-3--load-airport-data-into-an-iceberg-table)
- [Step 4 — Commit the Initial Data to Main](#step-4--commit-the-initial-data-to-main)
- [Step 5 — Create a Dev Branch](#step-5--create-a-dev-branch)
- [Step 6 — Demonstrating Branch Isolation and Recovery](#step-6--demonstrating-branch-isolation-and-recovery)
- [Step 7 — Data Transformations on the Dev Branch](#step-7--data-transformations-on-the-dev-branch)
- [Step 8 — Data Diff Between Branches](#step-8--data-diff-between-branches)
- [Step 9 — Create a Partitioned Table on Dev](#step-9--create-a-partitioned-table-on-dev)
- [Step 10 — Commit Dev Changes](#step-10--commit-dev-changes)
- [Step 11 — Merge Dev into Main](#step-11--merge-dev-into-main)
- [Summary](#summary)

## What you will learn

- How to create a lakeFS repository and branches
- How to write data into an Apache Iceberg table managed by lakeFS
- How branch isolation protects production data from accidental changes
- How to recover from accidental deletes using `reset_changes()`
- How to inspect data differences across branches using `refs_data_diff()`
- How to commit and merge branches — applying GitOps principles to data

## Prerequisites

- The **LakeFS Data Platform** is running (`00-environment/docker-lakefs`)
- The airports dataset is available at `/data-transfer/airports-data/airports.json` inside the containers
- Python libraries `lakefs`, `boto3`, and `tabulate` are available in the Jupyter image

## Accessing the Tools

| Tool | URL | Credentials |
|------|-----|-------------|
| Jupyter Notebook | <http://dataplatform:28888> | password: `abc123!` |
| lakeFS UI | <http://dataplatform:28220> | user: `admin`, password: `abc123!abc123!` |
| MinIO Console | <http://dataplatform:9010> | user: `admin`, password: `abc123!abc123!` |

## Using the Jupyter Notebook

A ready-to-use Jupyter notebook is available in the [`jupyter`](./jupyter) folder of this workshop:

```
13-lakefs/jupyter/iceberg-lakefs-airports.ipynb
```

Open Jupyter at <http://dataplatform:28888>, navigate to the `13-lakefs/jupyter/` folder and open the notebook. You can execute all steps interactively.

The sections below mirror the notebook and explain each step in detail.

---

## Step 1 — Configuration

The first step is to configure the lakeFS endpoint and credentials. These match the defaults configured in the `docker-lakefs` stack.

```python
lakefsEndPoint    = 'http://lakefs:8000'
lakefsAccessKey   = 'admin'
lakefsSecretKey   = 'abc123!abc123!'
storageNamespace  = 's3://lakefs-demo-bucket'
```

---

## Step 2 — Setup: Repository, Branches, and Spark Session

### Initialize the lakeFS client and create the repository

```python
import lakefs
import os

os.environ["LAKECTL_SERVER_ENDPOINT_URL"] = lakefsEndPoint
os.environ["LAKECTL_CREDENTIALS_ACCESS_KEY_ID"] = lakefsAccessKey
os.environ["LAKECTL_CREDENTIALS_SECRET_ACCESS_KEY"] = lakefsSecretKey

repo_name  = "demo"
mainBranch = "main"
devBranch  = "dev"

repo = lakefs.Repository(repo_name).create(
    storage_namespace=f"{storageNamespace}/{repo_name}",
    default_branch=mainBranch,
    exist_ok=True
)
branchMain = repo.branch(mainBranch)
```

### Create the Spark Session with Iceberg and lakeFS integration

The Spark session must be configured with the lakeFS Iceberg catalog and the required JAR packages. When using Jupyter, add the following init cell:

```python
import pyspark
from pyspark.sql import SparkSession

conf = pyspark.SparkConf()
conf.setMaster("spark://spark-master:7077")

# S3A pointing to lakeFS (not MinIO directly)
conf.set("spark.hadoop.fs.s3.impl",              "org.apache.hadoop.fs.s3a.S3AFileSystem")
conf.set("spark.hadoop.fs.s3a.impl",             "org.apache.hadoop.fs.s3a.S3AFileSystem")
conf.set("spark.hadoop.fs.s3a.endpoint",         lakefsEndPoint)
conf.set("spark.hadoop.fs.s3a.path.style.access","true")
conf.set("spark.hadoop.fs.s3a.access.key",       lakefsAccessKey)
conf.set("spark.hadoop.fs.s3a.secret.key",       lakefsSecretKey)

# Iceberg + lakeFS packages
conf.set("spark.jars.packages",
    "org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.5.2,"
    "io.lakefs:lakefs-iceberg:0.1.4,"
    "io.lakefs:lakefs-spark-extensions_2.12:0.0.3"
)

# lakeFS Iceberg catalog
conf.set("spark.sql.catalog.lakefs",             "org.apache.iceberg.spark.SparkCatalog")
conf.set("spark.sql.catalog.lakefs.catalog-impl","io.lakefs.iceberg.LakeFSCatalog")
conf.set("spark.sql.catalog.lakefs.warehouse",   f"lakefs://{repo_name}")
conf.set("spark.sql.catalog.lakefs.cache-enabled","false")
conf.set("spark.sql.catalog.lakefs.uri",         lakefsEndPoint)

# SQL extensions for Iceberg and lakeFS
conf.set("spark.sql.extensions",
    "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions,"
    "io.lakefs.iceberg.extension.LakeFSSparkSessionExtensions"
)
conf.set("spark.sql.defaultCatalog", "lakefs")

spark = SparkSession.builder.appName("lakeFS-Iceberg").config(conf=conf).getOrCreate()
spark.sparkContext.setLogLevel("INFO")
sc = spark.sparkContext
```

> **Note:** When using the `docker-lakefs` environment the Spark workers already have these JARs pre-installed. The `spark.jars.packages` line above is only needed when those JARs are not already on the classpath.

Also enable SQL magic in Jupyter for running plain SQL cells:

```python
%load_ext sql
%config SqlMagic.autopandas = True
%config SqlMagic.displaycon = False
%sql spark
```

---

## Step 3 — Load Airport Data into an Iceberg Table

Load the airports JSON file into a Spark DataFrame:

```python
airportsRawDF = spark.read.option("inferSchema", "true").json(
    "/data-transfer/airports-data/airports.json"
)
airportsRawDF.show(5)
```

Write the DataFrame as an Iceberg table in the `flights` namespace on the `main` branch. The table address uses the pattern `lakefs.<branch>.<namespace>.<table>`:

```python
airportsRawDF.writeTo("lakefs.main.flights.airports").createOrReplace()
```

You can query the table using SQL:

```sql
%%sql
SELECT * FROM lakefs.main.flights.airports LIMIT 20
```

You should see 81,193 rows.

> **What you should see:** 81,193 rows — the full airports dataset. The `lakefs.main.flights.airports` table address follows the pattern `<catalog>.<branch>.<namespace>.<table>`, where `lakefs` is the Iceberg catalog backed by lakeFS and `main` is the branch name.

> **What just happened?** `writeTo("lakefs.main.flights.airports").createOrReplace()` wrote the DataFrame as an Iceberg table on the `main` branch. lakeFS intercepts the S3A writes at the storage layer — when Spark writes Parquet files to `s3a://demo/main/...`, lakeFS stores them in MinIO but associates them with the `main` branch ref. At this point the data is uncommitted: it is visible on `main` but not yet part of lakeFS's version history until `branchMain.commit()` is called.

### Inspect the Iceberg metadata in MinIO

After writing, you can browse the raw Iceberg metadata files in the MinIO Console at <http://dataplatform:9010>. Navigate to the `lakefs-demo-bucket` bucket. You will see the typical Iceberg directory layout:

```
lakefs-demo-bucket/demo/
  main/
    flights/
      airports/
        data/        ← parquet data files
        metadata/    ← Iceberg metadata (snapshots, manifests, schema)
```

---

## Step 4 — Commit the Initial Data to Main

Commit the new table and its data to the `main` branch:

```python
branchMain.commit(
    message="Initial load of airports data from ourairports.com",
    metadata={"author": "workshop", "source": "https://ourairports.com/data/"}
)
```

---

## Step 5 — Create a Dev Branch

Create a `dev` branch from `main`. This is a zero-copy operation — no data is duplicated:

```python
branchDev = repo.branch(devBranch).create(source_reference=mainBranch, exist_ok=True)
```

Verify the data is visible on the dev branch (should return 81,193):

```sql
%%sql
SELECT COUNT(*) FROM lakefs.dev.flights.airports
```

---

## Step 6 — Demonstrating Branch Isolation and Recovery

### Accidental delete on dev

Imagine an accidental `DELETE` that removes all data from the dev branch:

```sql
%%sql
DELETE FROM lakefs.dev.flights.airports
```

Verify: dev branch has 0 records, main branch is unaffected.

```sql
%%sql
SELECT COUNT(*) FROM lakefs.dev.flights.airports
```

```sql
%%sql
SELECT COUNT(*) FROM lakefs.main.flights.airports
```

> **What you should see:** `0` on the dev branch, but `81193` on the main branch. The DELETE only affected the `dev` branch — main is completely isolated and unaffected.

> **What just happened?** lakeFS implements branch isolation at the storage layer. When the DELETE ran on `lakefs.dev.flights.airports`, Iceberg wrote a deletion record to the dev branch's metadata path. The main branch's metadata files were never touched. This is the core lakeFS guarantee: changes on one branch are invisible to all other branches until explicitly merged, making it safe to run destructive experiments on dev without risking production data.

### View uncommitted changes

```python
for diff in branchDev.uncommitted():
    print(diff)
```

### Recover by resetting

Reset the dev branch to discard all uncommitted changes:

```python
branchDev.reset_changes(path_type="common_prefix", path="")
```

Confirm recovery (should return 81,193 again):

```sql
%%sql
SELECT COUNT(*) FROM lakefs.dev.flights.airports
```

> **What you should see:** `81193` — the full row count has been restored on the dev branch.

> **What just happened?** `branchDev.reset_changes()` discarded all uncommitted changes on the dev branch by reverting its state pointer back to the most recent commit. Because lakeFS and Iceberg never delete immutable data files until explicitly garbage-collected, "reverting" is an instant metadata operation — no data is copied or restored. The Iceberg snapshot written by the DELETE is simply abandoned (no longer referenced by any branch pointer).

---

## Step 7 — Data Transformations on the Dev Branch

Now let's apply intentional, meaningful changes on `dev`.

### Filter to US airports only

```sql
%%sql
DELETE FROM lakefs.dev.flights.airports
WHERE iso_country != 'US'
```

### Create an aggregation table

```python
spark.sql("""
    CREATE TABLE IF NOT EXISTS lakefs.dev.flights.agg_us_airports_per_region
    USING iceberg
    AS SELECT iso_region, COUNT(*) AS airport_count
       FROM lakefs.dev.flights.airports
       GROUP BY iso_region
""")
```

Preview the result:

```sql
%%sql
SELECT * FROM lakefs.dev.flights.agg_us_airports_per_region
LIMIT 10
```

### Compare branch counts

Dev branch (US airports only):

```sql
%%sql
SELECT COUNT(*) FROM lakefs.dev.flights.airports
```

Main branch (all airports, unchanged):

```sql
%%sql
SELECT COUNT(*) FROM lakefs.main.flights.airports
```

---

## Step 8 — Data Diff Between Branches

The `refs_data_diff()` table-valued function compares an Iceberg table across two lakeFS references. The result includes a `lakefs_change` column:

| Value | Meaning |
|-------|---------|
| `-`   | Row only in the `from` ref (removed) |
| `+`   | Row only in the `to` ref (added) |
| *(absent)* | Row present in both refs |

Show a sample of differences:

```sql
%%sql
SELECT lakefs_change, iso_country, iso_region, name
FROM lakefs.refs_data_diff(
    "main", "dev",
    "flights.airports"
)
LIMIT 10
```

Show a count of removed airports grouped by country:

```sql
%%sql
SELECT iso_country, COUNT(*) AS removed_airports
FROM lakefs.refs_data_diff(
    "main", "dev",
    "flights.airports"
)
WHERE lakefs_change = '-'
GROUP BY iso_country
ORDER BY removed_airports DESC
LIMIT 20
```

> **What you should see:** Rows with `lakefs_change = '-'` representing airports removed from the dev branch (all non-US airports), grouped by country code with their counts. US airports do not appear in the diff because they exist identically on both branches.

> **What just happened?** `refs_data_diff()` is a lakeFS Spark extension that compares the Iceberg snapshot referenced by `main` against the snapshot referenced by `dev`, producing a row-level diff. Under the hood it reads the Iceberg manifest files for both branches, identifies which Parquet data files differ, and reads only those files to produce the row-level delta. The `lakefs_change` column (`+` = added to `dev`, `-` = removed from `dev` relative to `main`) gives you a Git-style diff at the data row level.

---

## Step 9 — Create a Partitioned Table on Dev

For better query performance, create a partitioned version of the airports table on dev:

```python
spark.sql("""
    CREATE TABLE IF NOT EXISTS lakefs.dev.flights.airports_partitioned
    USING iceberg
    PARTITIONED BY (iso_region)
    AS SELECT * FROM lakefs.dev.flights.airports
""")
```

Check airport counts per region:

```sql
%%sql
SELECT iso_region, COUNT(*) AS airport_count
FROM lakefs.dev.flights.airports_partitioned
GROUP BY iso_region
ORDER BY airport_count DESC
LIMIT 10
```

---

## Step 10 — Commit Dev Changes

Commit all changes on the `dev` branch with a descriptive message:

```python
branchDev.commit(
    message="Filter to US airports; add aggregation table; add partitioned table",
    metadata={
        "author": "workshop",
        "changes": "removed non-US airports, created agg_us_airports_per_region, created airports_partitioned"
    }
)
```

At this point, `main` still has the original full dataset.

---

## Step 11 — Merge Dev into Main

Once satisfied with the changes on `dev`, merge them into `main`:

```python
branchDev.merge_into(branchMain)
```

Verify that `main` now reflects the merged state:

```sql
%%sql
SELECT COUNT(*) FROM lakefs.main.flights.airports
```

You can also inspect the commit history and merged objects in the lakeFS UI at <http://dataplatform:28220>.

> **What you should see:** The count on `lakefs.main.flights.airports` now matches the dev branch count — only US airports remain. The lakeFS UI shows the full commit history including the initial load commit on main, the dev branch commits, and the merge commit.

> **What just happened?** `branchDev.merge_into(branchMain)` applied all commits from `dev` onto `main` by updating main's branch pointer to reference the dev branch's latest snapshot. Because Iceberg's snapshot model and lakeFS's ref model are both metadata-only, this merge was an instant operation — no Parquet files were copied. Both branches now point to the same physical data files for their shared content, with lakeFS tracking the ref-to-snapshot mapping that determines what each branch "sees".

---

## Summary

In this workshop you have seen how lakeFS brings Git-like data versioning to Apache Iceberg tables:

| Concept | Git analogy | What we did |
|---------|------------|-------------|
| Repository | Git repo | Created `demo` repo backed by MinIO |
| Branch | Git branch | Created `dev` from `main` |
| Commit | Git commit | Committed initial load; committed dev changes |
| Reset | `git reset` | Recovered from accidental delete on dev |
| Diff | `git diff` | Used `refs_data_diff()` to compare data across branches |
| Merge | `git merge` | Merged dev changes into main |

This pattern — branch, transform, validate, merge — enables safe, auditable data pipelines without the risk of corrupting production data.
