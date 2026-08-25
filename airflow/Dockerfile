FROM apache/airflow:3.1.8

USER root

# Install R
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        r-base \
        r-base-dev \
        libpq-dev \
        libcurl4-openssl-dev \
        libssl-dev \
        libxml2-dev \
        libfontconfig1-dev \
        libfreetype6-dev \
        libharfbuzz-dev \
        libfribidi-dev \
        libpng-dev \
        libtiff5-dev \
        libjpeg-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "install.packages(c( \
    'DBI', \
    'RPostgres', \
    'jsonlite', \
    'dplyr', \
    'tidyr', \
    'lubridate', \
    'ggplot2', \
    'readr', \
    'slider' \
    ), repos='https://cloud.r-project.org')"

USER airflow