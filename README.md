Introduction
============
_**This is work in progress. Contributions/comments are welcome.**_

This repository is a result of a few days of testing geth syncing and mining. It contains a solution to deploy Ethereum 
CPU mining nodes on AWS using Cloudformation. It is for testing and demonstration purposes only - it won't get you much 
on mainnet. Use Ropsten for example.

The miner nodes are deployed as Docker containers and are scaled automatically based on the required hashrate. When a 
higher hashrate is requested, miner nodes are added automatically and vice versa: a request for a lower hashrate will 
remove idle compute resources automatically as well. Miners take at most two minutes from cold start to start mining 
depending on the frequency of scaling activities. In certain situations, new nodes can mine within a few seconds.

To achieve quicker scaling capabilities, I have leveraged AWS Elastic File Service (EFS) where both the blockchain and 
DAG files are stored.


Quick Start
============
**TL;DR** - follow these steps:
* Install and configure AWSCLI:
```bash
pip install awscli
aws configure
```
* Create `geth` and `eth-cpu-miner` Docker repositories on ECR
```bash
aws ecr create-repository --repository-name geth-node
aws ecr create-repository --repository-name eth-cpu-miner
```
* Build Docker images and push them to ECR:
```bash
`aws ecr get-login --no-include-email`
docker build --no-cache -t <YOUR_AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/get-node:latest docker/geth-node
docker push <YOUR_AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/geth-node:latest
docker build --no-cache -t <YOUR_AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/eth-cpu-miner:latest docker/eth-miner
docker push <YOUR_AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/eth-cpu-miner:latest
```
* Set the default values for the following parameters in the [geth-node.yaml](cf-templates/geth-node.yaml) template:
    * `AwsRegion` - AWS regions to deploy the cluster in
    * `EtherbaseAddress` - Address to mine ETH to
    * `KeyName` - SSH key name (if console access is needed - discouraged)
    * `SSHLocation` - IP address to permit SSH login from
* Create the geth-node stack:
```bash
aws cloudformation create-stack --template-body file://cf-templates/eth-miner.yaml --capabilities CAPABILITY_IAM --stack-name <YOUR_GETH_NODE_STACK_NAME>
```
* The above will start a geth node
* Set the default values for the following parameters in the [eth-miner.yaml](cf-templates/eth-miner.yaml) template:
    * `GethNodeStackName` - YOUR_GETH_NODE_STACK_NAME stack name.
    * `AwsRegion` - AWS regions to deploy the cluster in
    * `MaxHashrate`
    * `MinHashrate`
* Create the eth-miner stack:
```bash
aws cloudformation create-stack --template-body file://cf-templates/eth-miner.yaml --capabilities CAPABILITY_IAM --stack-name <YOUR_ETH_MINER_STACK_NAME>
```
* Check the stack's status in the AWS console. When completed, the miners will mine to the `EtherbaseAddress` address.
* To adjust the hash rate, modify the values of `MaxHashrate` and `MinHashrate` parameters and update the eth-miner stack:
```bash
aws cloudformation update-stack --template-body file://cf-templates/eth-miner.yaml --capabilities CAPABILITY_IAM --stack-name <YOUR_ETH_MINER_STACK_NAME>
```
* The stack will automatically add or remove ec2 instances and docker containers to reach the required hash rate.
* Remember to delete your test stacks when no longer needed:
```bash
aws cloudformation delete-stack --stack-name <YOUR_ETH_MINER_STACK_NAME>
# When delete is complete, delete the geth node stack
aws cloudformation delete-stack --stack-name <YOUR_GETH_NODE_STACK_NAME>

```


Technical details
============
### Network
* All network resources are created in the geth-node stack. This will be separated later. 
* All traffic is restrained within a VPC.
* All resources are deployed in three availability zones

### EFS
* In order to speed up deployment of geth and ethminer nodes, it is suggested to store the data files on a shared file 
system, such as NFS. This approach can be used to build automatically scalable and self-healing geth nodes. AWS provides 
a managed service called Elastic File Service (EFS) making it easy to deploy scalable NFS storage.
* EFS resources are created in the geth-node stack.

### Docker
* Docker scheduling is managed by AWS Elastic Container Service (ECS).
* Docker host's launch configuration is set to mount the EFS export on start-up.
* All ECS resources are created in the geth-node stack.

### geth
* Its task definition is set to mount the EFS export on ~/.ethereum on start-up. If the container fails, the autoscaling 
group replaces it with a new one, which also mounts the same volume; thus making sure the blockchain doesn't have to be 
downloaded again.
* RPC port 8545 is registered with an application load balancer. 
* All geth resources are created in the geth-node stack

### Mining Cluster
* ethminer is used to mine ether.
* ethminer nodes/containers mount the EFS export on ~/.ethash. They connect to the geth node via the application load 
balancer in mining farm mode. They are deployed in two groups:
    * Leader: exactly 1 (size maintained by application scaling group). This one constantly maintains the DAG files.
    * Slaves: dynamically scalable by application scaling group. They are started with the `--no-precompute` flag. Check 
    [start-eth-cpu-miner.sh](docker/eth-miner/start-eth-cpu-miner.sh) for details.
* An ECS task is scheduled every minute to push the current hashrate and number of ETH in `EtherbaseAddress` to 
CloudWatch.
* Automatic scaling of slaves based on `MaxHashrate` and `MinHashrate` is implemented using CloudWatch alarms.
* Docker hosts are also scaled automatically, but independently from the containers, yet following the same demand curve. 
This results in close to 100% EC2 instance utilisation; thus avoiding over-provisioning of compute resources and 
benefiting from the most important feature of cloud computing: elasticity. The autoscaling group is configured to launch 
spot instances, which results in roughly 70% cost savings compared to on-demand instance prices. The currently 
configured instance type is c5.large, which provides ~70kH/s.

TODO
============
* Work on geth syncing issues. Fast sync doesn't always work and it's still quite slow. A solution might be to schedule
frequent dumps of the blockchain data files on S3 or an EBS volume and take snapshots. This part has given me the most 
headache so far.
* Add an indicator when geth is fully synchronized.
* Fix the `CWPutETHMetricsCron` events rule - currently not working most likely because of insufficient permissions. 
Check [cw-put-metric-data.sh](docker/geth-node/cw-put-metric-data.sh).
* Add Grafana dashboard as an ECS service and expose it via an external application load balancer.
* Add conditions to use SSL if `SSLCertificateArn` is not empty.
* Error handling in scripts
