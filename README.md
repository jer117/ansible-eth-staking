# ansible-eth-staking
Ansible role for eth home stakers.

## Key Features

- **Multi-client support**: Nethermind and Lighthouse, plus Obol Charon
- **Validator client options**: Lighthouse or Lodestar for distributed validation
- **Specialized images**: Optimized Docker images
- **Web UI**: Semaphore UI for easy Ansible playbook execution
- **Monitoring**: Grafana, Prometheus, Node Exporter, and cAdvisor
- **Security**: Firewall, JWT secrets, secure defaults
- **Automation**: Backups, health checks, resource management, automatic resets
- **Resource-efficient**: Configurable memory allocation

## Prerequisites

- Ansible 2.10+ on control machine
- Target hosts with Docker, SSH access, and sufficient resources (4+ CPU cores, 8+ GB RAM)

## Firewall Configuration

Configure UFW (Uncomplicated Firewall) to secure your staking node:

```bash
# Reset UFW to default
sudo ufw reset

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH
sudo ufw allow 22/tcp

# Ethereum execution client
sudo ufw allow 8547/tcp  # JSON-RPC API
sudo ufw allow 8552/tcp  # Engine API
sudo ufw allow 30304/tcp # P2P communication

# Monitoring and Management
sudo ufw allow 3000/tcp  # Grafana and Semaphore UI
sudo ufw allow 9090/tcp  # Prometheus
sudo ufw allow 24165/tcp # cAdvisor
sudo ufw allow 9093/tcp  # AlertManager

# Enable UFW
sudo ufw enable

# Verify rules
sudo ufw status verbose
```

## Quick Start

```bash
# Clone repository
git clone https://github.com/hydepwns/ansible-eth-staking.git && cd ansible-eth-staking

# Install requirements
pip install -r requirements.txt
ansible-galaxy collection install -r requirements.yml

# Run the interactive setup script
python3 setup.py

# The setup script will guide you through three deployment options:
# 1. Ethereum Node Only (No validator)
# 2. Single Validator Node with Lighthouse
# 3. Distributed Validator Node with Charon and Lodestar
#
# Features:
# - Interactive MEV-Boost relay selection for each network
# - Support for multiple networks (mainnet, holesky, sepolia, hoodi)
# - Pre-configured checkpoint sync URLs
# - Automated configuration generation
#
# The script will create:
# - secrets.yml with your configuration
# - inventory file with your server information

# Follow the next steps provided by the setup script
# For validator setups, make sure to add your validator keys before running the playbook

# Run the playbook
ansible-playbook -i inventory main.yml
```

# How to generate validator keys.
- https://hoodi.launchpad.ethereum.org/en/generate-keys
- https://wagyu.gg/

# Make sure you have SSH access to the node you want to use.
```bash
scp -r keystore-m_12381_3600_0_0_0-1742121896.json root@server_ip:/root/.lighthouse/validators/keys
```

# Put this in your secret file.
```bash
validators:
  - public_key: "0x123...abc"
    keystore_file: "keystore-m_12381_3600_0_0_0-1742121896.json"
    keystore_password: "password1"
  - public_key: "0x456...def"
    keystore_file: "keystore-m_12381_3600_0_0_1-1742121897.json"
    keystore_password: "password2"
  - public_key: "0x789...ghi"
    keystore_file: "keystore-m_12381_3600_0_0_2-1742121898.json"
    keystore_password: "password3"
```

# Create an Obol Cluster
```bash
# Clone the repo
git clone https://github.com/ObolNetwork/charon-distributed-validator-node.git
# Create the .charon repo at the root directory or home directory
mkdir .charon
chmod 777 .charon/
# Change directory
cd charon-distributed-validator-node/
# Use docker to create an ENR. Backup the file `.charon/charon-enr-private-key`.
# This must be ran on each node.
docker run --rm -v "$(pwd):/opt/charon" obolnetwork/charon:v1.4.0 create enr

#Go to this website
https://hoodi.launchpad.obol.org/

# After creating the splitter contract, this should be ran on every server in the Obol cluster.
docker run -u $(id -u):$(id -g) --rm -v "$(pwd)/:/opt/charon" obolnetwork/charon:v1.4.0 dkg --definition-file="https://api.obol.tech/v1/definition/0xc2539e3df1179d103140b54520f096498be0b96ba1811857fde0576a0c831b2f" --publish

# Cluster Dashboard
https://api.obol.tech/lock/0xC806E59C8D7CB721F4231582C57CC1EFDC7C43613B0F22A9BE1BFE50FD443EBD/launchpad

## Validator Client Options

When using Obol Charon (distributed validator), you can choose between two validator clients:

### Lighthouse (Default)
- **Image**: `sigp/lighthouse:v7.0.0`
- **Configuration**: Set `validator_client: "lighthouse"` in your secrets file
- **Features**: Full MEV boost support, distributed validator mode

### Lodestar
- **Image**: `chainsafe/lodestar:v1.29.0`
- **Configuration**: Set `validator_client: "lodestar"` in your secrets file
- **Features**: TypeScript-based client, distributed validator mode, MEV boost support

### Configuration Example
```yaml
# In your secrets.yml file
charon_enabled: "true"
mev_boost_enabled: "true"
validator_client: "lodestar"  # Options: "lighthouse" or "lodestar"
```

**Note**: The validator client selection only applies when Charon is enabled. When Charon is disabled, Lighthouse is used as the default validator client.

## Debugging Commands

### Check Execution Client Sync Status
```bash
# Check if execution client is syncing
curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' http://localhost:8544

# Check current block number
curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8544

# Check chain ID
curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' http://localhost:8544
```

### Check Consensus Client Status
```bash
# Check beacon node sync status
curl http://localhost:5052/eth/v1/node/syncing

# Check beacon node health
curl http://localhost:5052/eth/v1/node/health

# Get current slot
curl http://localhost:5052/eth/v1/beacon/headers/head

# Check if beacon node is ready for validator duties
curl http://localhost:5052/eth/v1/node/readiness
```

### Check Charon Status
```bash
# Check Charon health
curl http://localhost:3620/health

# Check Charon metrics
curl http://localhost:3620/metrics
```

### Check Validator Client Status
```bash
# Check Lodestar validator client health (if using Charon)
curl http://localhost:5062/health

# Check Lighthouse validator client health
curl http://localhost:5062/health
```

### Debugging exec token issues or no space left on machine.
```bash
# Check that you are on root or home.
cd

# Clean up db and tokens then re run the role.
docker stop eth-ansible-consensus-1 eth-ansible-execution-1 && docker rm eth-ansible-execution-1 eth-ansible-consensus-1 && sudo rm -rf .lighthouse/ .nethermind/

```