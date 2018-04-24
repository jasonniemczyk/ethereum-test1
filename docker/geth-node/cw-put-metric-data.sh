#!/bin/bash

aws --region $AwsRegion cloudwatch put-metric-data --metric-name HashRate --value `geth --exec "eth.hashrate" attach rpc:$GETH_ENDPOINT` --namespace ethminer --dimensions StackName=$StackName
aws --region $AwsRegion cloudwatch put-metric-data --metric-name ETHBalance --value `geth --exec "web3.fromWei(eth.getBalance(eth.coinbase), 'ether')" attach rpc:$GETH_ENDPOINT` --namespace ethminer --dimensions StackName=$StackName
