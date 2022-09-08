FROM postgres:latest

RUN apt-get update
RUN apt-get install -y postgresql-14-wal2json


# Install the packages which will be required to get everything to compile
RUN apt-get update \
    && apt-get install -f -y --no-install-recommends \
        software-properties-common \
        build-essential \
        pkg-config \
        git \
     postgresql-server-dev-14

# Install wal2json
RUN git clone https://github.com/eulerto/wal2json -b master --single-branch \
    && cd /wal2json \
    && make && make install
