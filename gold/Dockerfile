FROM rocker/r-ver:4.4.1

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /gold

COPY install_packages.R ./install_packages.R
RUN Rscript install_packages.R

COPY R ./R
COPY sql ./sql
COPY tests ./tests

CMD ["Rscript", "R/run_pipeline.R"]
