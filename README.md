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

## Quick Start

```bash
# Clone repository
git clone https://github.com/hydepwns/ansible-ephemery.git && cd ansible-ephemery

# Install requirements
ansible-galaxy collection install -r requirements.yaml
pip install -r requirements.txt

# Configure inventory
cp example-inventory.yaml inventory.yaml
# Edit inventory.yaml with your target hosts

# Run playbook
ansible-playbook -i inventory.yaml ephemery.yaml
```