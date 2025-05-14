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
sudo ufw allow 8545/tcp  # JSON-RPC API
sudo ufw allow 8551/tcp  # Engine API
sudo ufw allow 30303/tcp # P2P communication

# Monitoring
sudo ufw allow 3000/tcp  # Grafana
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
ansible-galaxy collection install -r requirements.yaml
pip install -r requirements.txt

# Configure inventory
cp example-inventory.yaml inventory.yaml
# Edit inventory.yaml with your target hosts

# Run playbook
ansible-playbook -i inventory.yaml main.yaml
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