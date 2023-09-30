# before you change the version, make sure https://github.com/eulerto/wal2json supports it
# also you need to update `postgresql-server-dev-XX` to use the same version.
FROM postgres:14.5

ENV POSTGRES_PASSWORD=postgres1
ENV POSTGRES_USER=postgres1
ENV POSTGRES_DB=postgres1

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

RUN git clone https://github.com/eulerto/wal2json -b master --single-branch 

RUN export PATH=/home/euler/pg14/bin:$PATH
RUN export PATH=/usr/lib/postgresql/14/bin:$PATH

# Install wal2json
RUN cd /wal2json && make && make install

