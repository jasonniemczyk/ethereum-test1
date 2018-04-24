#!/bin/bash
if [ $LEADER -eq 1 ]; then
    ethminer -C -F $GETH_ENDPOINT
    break
else  # Don't generate DAG if not leader
    ethminer --no-precompute -C -F $GETH_ENDPOINT
fi
