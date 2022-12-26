#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o xtrace

DOCKER_NETWORK=mymacvlan
HOST_IP=`hostname -I | cut -d ' ' -f 1`
LINK_DEV_IP="10.1.1.15"
LINK_DEV_NAME=mylink
CONTAINER_NET="10.1.1.0/24"
CONTAINER_SERVER_IP="10.1.1.48"
CONTAINER_CLIENT_IP="10.1.1.64"
CONTAINER_IP="10.1.1.48"
GRPC_PORT="9000"
NET_DEV_NAME="eno2"


# DOCKER_NETWORK=enpmacvlan
# HOST_IP=`hostname -I | cut -d ' ' -f 1`
# LINK_DEV_IP="10.1.2.15"
# LINK_DEV_NAME=enplink
# CONTAINER_NET="10.1.2.0/24"
# CONTAINER_SERVER_IP="10.1.2.48"
# CONTAINER_CLIENT_IP="10.1.2.64"
# CONTAINER_IP="10.1.2.48"
# GRPC_PORT="9000"
# NET_DEV_NAME="enp66s0f0np0"


# Create MacVLAN network for container to assign static IP
sudo docker network create -d macvlan --subnet=$CONTAINER_NET --ip-range=$CONTAINER_NET -o macvlan_mode=bridge -o parent=$NET_DEV_NAME $DOCKER_NETWORK
# Make host and container accessible
# https://rehtt.com/index.php/archives/236/
sudo ip link add $LINK_DEV_NAME link ${NET_DEV_NAME} type macvlan mode bridge
sudo ip addr add $LINK_DEV_IP dev $LINK_DEV_NAME
sudo ip link set $LINK_DEV_NAME up
sudo ip route add ${CONTAINER_NET} dev $LINK_DEV_NAME

cd src

sudo docker kill `sudo docker ps -q -f name=python_side` || true # Clean all pending containers to release IP


# Start Sanity Test
cd ../test
sed -i "s/SIDE_2_IP/${CONTAINER_IP}/g" ./case.yaml
sed -i "s/SIDE_1_IP/${LINK_DEV_IP}/g" ./case.yaml
sed -i "s/SIDE_1_PORT/${GRPC_PORT}/g" ./case.yaml
sed -i "s/SIDE_2_PORT/${GRPC_PORT}/g" ./case.yaml

# Start Rust Side
cd ../

## Remove existing devices if any
RXE_DEV=rxe_0
sudo rdma link delete $RXE_DEV || true

sudo rdma link add $RXE_DEV type rxe netdev ${LINK_DEV_NAME}

./target/debug/sanity_side ${GRPC_PORT} 2>&1 > ./rust_side.log &

# Start Python Side
cd ./src
sudo docker run --rm -d -v `pwd`:`pwd` -w `pwd` --net=${DOCKER_NETWORK} --ip=${CONTAINER_IP} --name python_side grpc-python3 python3 sanity_side.py ${CONTAINER_IP} ${GRPC_PORT}
# sudo docker logs -f python_side > ../python_side.log &

# Wait a while to Start Manager Python
sleep 2
python3 ./sanity_manager.py ../test/case.yaml