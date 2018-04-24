FROM ubuntu:16.04

LABEL Description="ETH miner" Author="Jason Niemczyk"

RUN apt-get update  && \
    apt-get install -y software-properties-common && \
    add-apt-repository -y ppa:ethereum/ethereum && \
    add-apt-repository -y ppa:ethereum/ethereum-dev && \
    add-apt-repository -y ppa:ethereum/ethereum-qt && \
    apt-get update && \
    apt-get -y install cpp-ethereum && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY start-eth-cpu-miner.sh /

RUN chmod 755 /start-eth-cpu-miner.sh

ENTRYPOINT ["/start-eth-cpu-miner.sh"]
