#!/bin/bash

docker build --tag eadp/dbt-demo-pipeline:1.7.0  --target dbt-spark --build-arg dbt_project=demo_pipeline .

docker build --tag eadp/dbt-slv-pipeline:1.7.0  --target dbt-spark --build-arg dbt_project=slv_pipeline .

docker build --tag eadp/dbt-misc-pipeline:1.7.0  --target dbt-spark --build-arg dbt_project=misc_pipeline .

docker build --tag eadp/dbt-diff-pipeline:1.7.0  --target dbt-trino --build-arg dbt_project=diff_pipeline_trino .

docker image tag eadp/dbt-demo-pipeline:1.7.0 dataplatform-registry:5020/eadp/dbt-demo-pipeline:1.7.0
docker image push dataplatform-registry:5020/eadp/dbt-demo-pipeline:1.7.0

docker image tag eadp/dbt-slv-pipeline:1.7.0 dataplatform-registry:5020/eadp/dbt-slv-pipeline:1.7.0
docker image push dataplatform-registry:5020/eadp/dbt-slv-pipeline:1.7.0

docker image tag eadp/dbt-misc-pipeline:1.7.0 dataplatform-registry:5020/eadp/dbt-misc-pipeline:1.7.0
docker image push dataplatform-registry:5020/eadp/dbt-misc-pipeline:1.7.0

docker image tag eadp/dbt-diff-pipeline:1.7.0 dataplatform-registry:5020/eadp/dbt-diff-pipeline:1.7.0
docker image push dataplatform-registry:5020/eadp/dbt-diff-pipeline:1.7.0