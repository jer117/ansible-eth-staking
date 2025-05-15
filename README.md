# ansible-eth-staking
Ansible role for eth home stakers.

## Key Features

- **Multi-client support**: Nethermind and Lighthouse, plus Obol Charon
- **Specialized images**: Optimized Docker images.
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

# Monitoring
sudo ufw allow 3001/tcp  # Grafana
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

# Install requirements on server in question
ansible-galaxy collection install -r requirements.yaml
pip install -r requirements.txt

# Configure inventory
cp example-inventory.yaml inventory.yaml
cp example-secrets.yaml secrets.yaml
# Edit inventory.yaml with your target hosts

# Run playbook
ansible-playbook -i inventory main.yaml
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
```