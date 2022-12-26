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


# DOCKER_NETWORK=rvlan
# HOST_IP=`hostname -I | cut -d ' ' -f 1`
# LINK_DEV_IP="192.168.9.3"
# LINK_DEV_NAME=enplink
# CONTAINER_NET="10.1.2.0/24"
# CONTAINER_SERVER_IP="10.1.2.48"
# CONTAINER_CLIENT_IP="10.1.2.64"
# CONTAINER_IP="192.168.9.4"
# GRPC_PORT="9000"

cargo b

pkill sanity || true
sudo docker kill `sudo docker ps -q -f name=python_side` || true # Clean all pending containers to release IP
sed -i "s/SIDE_2_IP/${CONTAINER_IP}/g" .vscode/lcase.yaml
sed -i "s/SIDE_1_IP/${LINK_DEV_IP}/g" .vscode/lcase.yaml
sed -i "s/SIDE_1_PORT/${GRPC_PORT}/g" .vscode/lcase.yaml
sed -i "s/SIDE_2_PORT/${GRPC_PORT}/g" .vscode/lcase.yaml

# Start Rust Side
./target/debug/sanity_side ${GRPC_PORT} 2>&1 > ./rust_side.log &
# RUST_LOG=debug ./target/debug/sanity_side ${GRPC_PORT} &

# Start Python Side
cd ./src
sudo docker run --rm -d -v `pwd`:`pwd` -w `pwd` --net=${DOCKER_NETWORK} --ip=${CONTAINER_IP} --name python_side grpc-python3 python3 sanity_side.py ${CONTAINER_IP} ${GRPC_PORT}
sudo docker logs -f python_side &

# sudo docker logs -f python_side > ../python_side.log &

# Wait a while to Start Manager Python
sleep 2
python3 ./sanity_manager.py ../.vscode/lcase.yaml

