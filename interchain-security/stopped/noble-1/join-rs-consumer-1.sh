#!/bin/bash
# Set up a service to join the noble-1 chain.

# Configuration
# You should only have to modify the values in this block
# * Keys
#    The private validator key and node key operations must match those used in the provider-1 chain if you want to run a validator.
# ***
PRIV_VALIDATOR_KEY_FILE=~/priv_validator_key.json
NODE_KEY_FILE=~/node_key.json
NODE_HOME=~/.nobled
NODE_MONIKER=noble-1
SERVICE_NAME=noble-1
# ***

CHAIN_BINARY='nobled'
CHAIN_ID=noble-1
SEEDS="233598946a15427b9541376e7cfc30dab07c4327@35.247.60.27:26656,359d63178736911e3e4c716f2491cafaa687351a@34.168.48.1:26656,3d2516052fd8b134428971d1218a149bba6e44be@35.247.10.56:26656"

# The genesis file that includes the CCV state will not be published until after the spawn time has been reached.
GENESIS_URL=https://github.com/cosmos/testnets/raw/master/interchain-security/noble-1/noble-1-genesis.json

# Install wget and jq
sudo apt-get install curl jq wget -y

# Install go 1.19.4
echo "Installing go..."
rm go*linux-amd64.tar.gz
wget https://go.dev/dl/go1.19.4.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.19.4.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# Install nobled binary
echo "Installing build-essential..."
sudo apt install build-essential -y
echo "Installing nobled..."
cd $HOME
mkdir -p $HOME/go/bin
rm -rf noble
git clone https://github.com/strangelove-ventures/noble.git
cd noble
git checkout v0.2.0
make install
export PATH=$PATH:$HOME/go/bin

# Initialize home directory
echo "Initializing $NODE_HOME..."
rm -rf $NODE_HOME
$CHAIN_BINARY config chain-id $CHAIN_ID --home $NODE_HOME
$CHAIN_BINARY config keyring-backend test --home $NODE_HOME
$CHAIN_BINARY config broadcast-mode block --home $NODE_HOME
$CHAIN_BINARY init $NODE_MONIKER --chain-id $CHAIN_ID --home $NODE_HOME
sed -i -e "/seeds =/ s^= .*^= \"$SEEDS\"^" $NODE_HOME/config/config.toml

# Replace keys
echo "Replacing keys..."
cp $PRIV_VALIDATOR_KEY_FILE $NODE_HOME/config/priv_validator_key.json
cp $NODE_KEY_FILE $NODE_HOME/config/node_key.json

# Replace genesis file: only after the spawn time is reached
echo "Replacing genesis file..."
wget $GENESIS_URL -O genesis.json
mv genesis.json $NODE_HOME/config/genesis.json

echo "Creating $SERVICE_NAME.service..."
sudo rm /etc/systemd/system/$SERVICE_NAME.service
sudo touch /etc/systemd/system/$SERVICE_NAME.service

echo "[Unit]"                               | sudo tee /etc/systemd/system/$SERVICE_NAME.service
echo "Description=noble-1 service"       | sudo tee /etc/systemd/system/$SERVICE_NAME.service -a
echo "After=network-online.target"          | sudo tee /etc/systemd/system/$SERVICE_NAME.service -a
echo ""                                     | sudo tee /etc/systemd/system/$SERVICE_NAME.service -a
echo "[Service]"                            | sudo tee /etc/systemd/system/$SERVICE_NAME.service -a
echo "User=$USER"                            | sudo tee /etc/systemd/system/$SERVICE_NAME.service -a
echo "ExecStart=$HOME/go/bin/$CHAIN_BINARY start --x-crisis-skip-assert-invariants --home $NODE_HOME" | sudo tee /etc/systemd/system/$SERVICE_NAME.service -a
echo "Restart=always"                       | sudo tee /etc/systemd/system/$SERVICE_NAME.service -a
echo "RestartSec=3"                         | sudo tee /etc/systemd/system/$SERVICE_NAME.service -a
echo "LimitNOFILE=4096"                     | sudo tee /etc/systemd/system/$SERVICE_NAME.service -a
echo ""                                     | sudo tee /etc/systemd/system/$SERVICE_NAME.service -a
echo "[Install]"                            | sudo tee /etc/systemd/system/$SERVICE_NAME.service -a
echo "WantedBy=multi-user.target"           | sudo tee /etc/systemd/system/$SERVICE_NAME.service -a

# Start service
sudo systemctl daemon-reload

# Enable and start the service after the genesis that includes the CCV state is in place
sudo systemctl enable $SERVICE_NAME.service
sudo systemctl start $SERVICE_NAME.service
sudo systemctl restart systemd-journald

# Add go and gaiad to the path
echo "Setting up paths for go and nobled bin..."
echo "export PATH=$PATH:/usr/local/go/bin" >> .profile

echo "***********************"
echo "To see the service log enter:"
echo "journalctl -fu $SERVICE_NAME.service"
echo "***********************"
