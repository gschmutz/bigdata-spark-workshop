# Top level build args
ARG build_for=linux/amd64

# Unlike the official docker image, we use Pyhton 3.10.2 and not 3.11.2 due to the error in dbt-spark with PyHive (Guido)
FROM --platform=$build_for python:3.10.2-slim-bullseye as base

ARG dbt_project=demo_pipeline
ARG dbt_core_ref=dbt-core@v1.7.0
ARG dbt_spark_ref=dbt-spark@v1.7.0
ARG dbt_trino_ref=dbt-trino@v1.7.0
# special case args
ARG dbt_spark_version=all
ARG dbt_third_party

RUN apt-get update \
  && apt-get dist-upgrade -y \
  && apt-get install -y --no-install-recommends \
    git \
    ssh-client \
    software-properties-common \
    make \
    build-essential \
    ca-certificates \
    libpq-dev \
    s3fs \
  && apt-get clean \
  && rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*

# Env vars
ENV PYTHONIOENCODING=utf-8
ENV LANG=C.UTF-8

# Update python
RUN python -m pip install --upgrade pip setuptools wheel --no-cache-dir

# Set docker basics
WORKDIR /usr/app/dbt/
#ENTRYPOINT ["dbt"]

##
# dbt-core
##
FROM base as dbt-core
RUN python -m pip install --no-cache-dir "git+https://github.com/dbt-labs/${dbt_core_ref}#egg=dbt-core&subdirectory=core"

##
# dbt-spark
##
FROM base as dbt-spark
RUN apt-get update \
  && apt-get dist-upgrade -y \
  && apt-get install -y --no-install-recommends \
    python-dev \
    libsasl2-dev \
    libsasl2-modules \
    gcc \
    unixodbc-dev \
  && apt-get clean \
  && rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*
RUN python -m pip install --no-cache-dir "git+https://github.com/dbt-labs/${dbt_spark_ref}#egg=dbt-spark[${dbt_spark_version}]"

COPY ./${dbt_project} /usr/app/dbt
COPY ./profiles.yml /root/.dbt/profiles.yml
RUN dbt deps

##
# dbt-trino
##
FROM base as dbt-trino
RUN python -m pip install --no-cache-dir dbt-trino

COPY ./${dbt_project} /usr/app/dbt
COPY ./profiles.yml /root/.dbt/profiles.yml
RUN dbt deps




