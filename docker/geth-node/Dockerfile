FROM ubuntu:16.04

LABEL Description="Geth node" Author="Jason Niemczyk"

RUN apt-get update && \
    apt-get -y install software-properties-common && \
    add-apt-repository -y ppa:ethereum/ethereum && \
    apt-get update && \
    apt-get -y install ethereum awscli && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY cw-put-metric-data.sh /

RUN chmod 755 /cw-put-metric-data.sh

EXPOSE 8545
