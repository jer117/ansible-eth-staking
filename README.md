# ansible-eth-staking
Ansible role for eth home stakers.

## Key Features

- **Multi-client support**: Nethermind and Lighthouse, plus Obol Charon
- **Validator client options**: Lighthouse or Lodestar for distributed validation
- **Specialized images**: Optimized Docker images
- **Web UI**: Semaphore UI for easy Ansible playbook execution
- **Monitoring**: Grafana, Prometheus, Node Exporter, and cAdvisor
- **Security**: Firewall, JWT secrets, secure defaults
- **API Gateway**: Apache APISIX with API key / bearer token authentication for RPC endpoints
- **Automation**: Backups, health checks, resource management, automatic resets
- **Resource-efficient**: Configurable memory allocation

## Prerequisites

- ansible-core 2.17+ on the control machine (required by community.docker 5.x; `pip install -r requirements.txt` installs a recent version)
- Target hosts with Docker, SSH access, and sufficient resources (4+ CPU cores, 8+ GB RAM)
- Python 3.9+ on target hosts when using ansible-core 2.20 or newer. Ubuntu 20.04 ships Python 3.8, so for those hosts use ansible-core 2.17–2.19.

## Firewall Configuration

### Required inbound ports

These are the peer-to-peer ports. Allow them on the host firewall, and forward them on your router if the node is behind NAT. Without the UDP ports, the clients can't be discovered by other peers and end up with fewer peers.

| Port  | Protocol | Client                        | Purpose                          | Variable in `roles/ethereum_home_staking/vars/main.yml` |
|-------|----------|-------------------------------|----------------------------------|------------------------------------|
| 30304 | TCP      | Nethermind                    | Peer connections (devp2p)        | `eth_ansible_execution_1_p2p_port` |
| 30304 | UDP      | Nethermind                    | Peer discovery (discv4/discv5)   | `eth_ansible_execution_1_p2p_port` |
| 9000  | TCP      | Lighthouse, Teku              | Peer connections (libp2p)        | `consensus_client_p2p_port`        |
| 9000  | UDP      | Lighthouse, Teku              | Peer discovery (discv5)          | `consensus_client_p2p_port`        |
| 9001  | UDP      | Lighthouse (and Teku 26.7+)   | Peer connections over QUIC       | `consensus_client_quic_port`       |
| 3610  | TCP      | Charon (if `charon_enabled`)  | Connections to other cluster nodes | `charon_p2p_tcp_port`            |

These were checked against Nethermind 1.35.3, Lighthouse v8.0.1, Teku 25.11 and Charon v1.7.1. The role now pins newer versions (see `roles/ethereum_home_staking/defaults/main.yml`):

- Teku 25.11 did not use QUIC. Teku 26.7 and later, which includes the pinned version, enable QUIC on UDP 9001 by default, so 9001/udp matters for both consensus clients.
- Charon only needs TCP. Its QUIC transport is an alpha feature that is off by default, and it only listens on UDP if `--p2p-udp-address` is set.

To change a port, edit `roles/ethereum_home_staking/vars/main.yml` or pass it with `-e` (for example `-e consensus_client_p2p_port=9100`). Setting it in `host_vars` has no effect: ports are fixed role vars, which take precedence over inventory variables (see [Configuration](#configuration)).

```bash
# Reset UFW to default
sudo ufw reset

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH
sudo ufw allow 22/tcp

# Execution client (Nethermind) P2P
sudo ufw allow 30304/tcp  # Peer connections
sudo ufw allow 30304/udp  # Peer discovery

# Consensus client (Lighthouse / Teku) P2P
sudo ufw allow 9000/tcp   # Peer connections
sudo ufw allow 9000/udp   # Peer discovery
sudo ufw allow 9001/udp   # QUIC

# Charon distributed validator (only if charon_enabled)
sudo ufw allow 3610/tcp

# APISIX API Gateway (optional)
sudo ufw allow 9080/tcp  # APISIX Gateway
sudo ufw allow 9443/tcp  # APISIX HTTPS

# Enable UFW
sudo ufw enable

# Verify rules
sudo ufw status verbose
```

After deploying, check that Docker publishes both protocols:

```bash
docker port eth-ansible-execution-1   # expect 30304/tcp and 30304/udp
docker port eth-ansible-consensus-1   # expect 9000/tcp, 9000/udp and 9001/udp
```

### Docker bypasses ufw

Docker publishes container ports with its own iptables rules, which handle the traffic before ufw's rules see it. A port that Docker publishes on all interfaces is reachable from outside even if ufw denies it, and `ufw status` does not show it. The ufw rules above record which ports are meant to be open, but Docker opens the published ports either way. The reverse is also true: `ufw deny` does not close a Docker-published port.

Ports this role publishes on all interfaces:

| Port(s)                                     | Service                                      | Meant to be public? |
|---------------------------------------------|----------------------------------------------|---------------------|
| 30304 tcp/udp, 9000 tcp/udp, 9001 udp, 3610 tcp | P2P (see above)                          | Yes |
| 8544/tcp                                    | Nethermind JSON-RPC (`admin` and `debug` modules enabled) | No |
| 8552/tcp                                    | Nethermind Engine API (JWT-protected; the beacon node reaches it over the Docker network) | No |
| 9080, 9443/tcp                              | APISIX gateway and HTTPS (if `apisix_enabled`) | Yes |
| 3001, 9090, 9093, 8080/tcp                  | Grafana, Prometheus, Alertmanager, cAdvisor (`cadvisor_port`) | No |

The beacon API (5062), validator API (5064) and metrics (8009), Charon monitoring (3620), node exporter (9100) and Grafana Agent (12345) are bound to `127.0.0.1` and are not reachable from outside.

To keep a published port private, either:

1. Bind it to localhost by prefixing the mapping with `127.0.0.1:` in `roles/ethereum_home_staking/vars/main.yml`, as the beacon API mapping already does. Anything that reaches the service over the Docker network (APISIX, Prometheus, the beacon node) keeps working.
2. Or drop outside traffic in the `DOCKER-USER` chain, which Docker evaluates before its own rules. Match on the original destination port, because Docker has already rewritten the destination by the time the packet reaches this chain:

   ```bash
   # Replace eth0 with your internet-facing interface
   sudo iptables -I DOCKER-USER -i eth0 -p tcp -m conntrack --ctorigdstport 8544 --ctdir ORIGINAL -j DROP
   sudo iptables -I DOCKER-USER -i eth0 -p tcp -m conntrack --ctorigdstport 8552 --ctdir ORIGINAL -j DROP
   ```

   These rules do not persist across reboots, so re-apply them at boot.

## Quick Start

```bash
# Clone repository
git clone git@github.com:jer117/ansible-eth-staking.git && cd ansible-eth-staking

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
# - Support for multiple networks (mainnet, sepolia, hoodi)
# - Pre-configured checkpoint sync URLs
# - Automated configuration generation
#
# The script will create:
# - host_vars/<server-name>.yml with your configuration (readable only by you)
# - inventory file with your server information

# Follow the next steps provided by the setup script
# For validator setups, make sure to add your validator keys before running the playbook

# Run the playbook
ansible-playbook -i inventory main.yml
```

## Configuration

`main.yml` and the playbooks in `playbooks/` apply the role in `roles/ethereum_home_staking/`. Its variables come in two layers:

| File | Contents | Override from host_vars / group_vars? |
|------|----------|---------------------------------------|
| `roles/ethereum_home_staking/defaults/main.yml` | Images, feature toggles (`mev_boost_enabled`, `charon_enabled`, `apisix_enabled`, ...), paths, tuning | Yes |
| `roles/ethereum_home_staking/vars/main.yml` | Container names and ports: the ones the containers use to reach each other, and the published P2P/RPC port mappings | No (only with `-e`) |

Put your settings in `host_vars/<host>.yml` or `group_vars/<group>.yml` next to your inventory instead of editing the role. Ansible only loads `host_vars/<host>.yml` when `<host>` is the host's name in the inventory; `setup.py` uses the server name for both. If an older `setup.py` named your file after the server IP, rename it to the inventory name. Keep secrets in that same host_vars file and encrypt it with `ansible-vault` if you like. Don't pass per-host settings with `-e @secrets.yml`: extra vars apply to every host in the run and override everything, including host_vars and the fixed values.

The `*_enabled` toggles accept `"true"`/`"false"` or YAML booleans.

`tests/precedence/run.sh` checks that host_vars and group_vars override the role defaults.

## Upgrading from community.docker 3.x

`requirements.yml` pins community.docker 5.4.0. The 3.x releases fail on hosts with current Python packages (requests 2.32+, urllib3 2.x) with errors such as `Not supported URL scheme http+docker`. Update the collection on the control machine:

```bash
pip install -r requirements.txt
ansible-galaxy collection install -r requirements.yml --force
```

What changes on the first run after upgrading:

- Prometheus, Alertmanager and Grafana keep their data in named Docker volumes (`prometheus-data`, `alertmanager-data`, `grafana-data`). On the first run the playbook stops these containers, copies their existing data into the volumes, and recreates them. The old anonymous volumes are left in place; remove them with `docker volume prune` once your dashboards and history look right.
- Grafana now keeps its database, so `GRAFANA_ADMIN_PASSWORD` only applies when the `grafana-data` volume is first created. To change the password later, use the Grafana UI or `docker exec grafana grafana cli admin reset-admin-password <new-password>`.
- A container is recreated whenever its `image:` value changes, even if the new name points to the same image ID (`image_name_mismatch: recreate`, the default since community.docker 4.0.0). With 3.x such a rename was ignored.

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

# Make sure to load the keys generated above to your server.
scp -r * root@{server_ip}:/root/.charon/
```

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

## APISIX API Gateway (Optional)

Apache APISIX provides secure, authenticated access to your Ethereum node's RPC endpoints using APISIX's built-in `key-auth` plugin. It runs in file-driven standalone mode: routes and credentials come from a file rendered by Ansible, with no etcd and no Admin API.

### Quick Setup

1. **Credentials** (optional): APISIX is enabled by default (`apisix_enabled: true` in `roles/ethereum_home_staking/defaults/main.yml`). Set your own client credentials, or leave them unset and Ansible generates random ones:
```yaml
# In secrets.yml or host_vars/<your-host>.yml - generate with: openssl rand -hex 32
apisix_api_key: "<random value>"
apisix_bearer_token: "<random value>"
```
Generated credentials are stored on the control machine in `credentials/<inventory_hostname>/apisix/api_key` and `.../bearer_token` (next to your inventory file, gitignored).

2. **Deploy APISIX**:
```bash
ansible-playbook -i inventory main.yml --tags apisix
```

3. **Test Access**:
```bash
# Health check (no auth)
curl http://<server>:9080/health

# Consensus API (with auth)
curl -H "X-API-Key: your-api-key" \
  http://<server>:9080/consensus/eth/v1/node/version

# Execution API (with auth)
curl -H "X-API-Key: your-api-key" \
  -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://<server>:9080/execution/
```

### Features
- ✅ **Authentication**: API Key (`X-API-Key`) and Bearer Token (`Authorization: Bearer`) support
- ✅ **Route Protection**: Secure consensus and execution endpoints
- ✅ **Prometheus Metrics**: Built-in metrics export on port 9091 (Docker network only)
- ✅ **Health Checks**: Unauthenticated health endpoints
- ✅ **Config as Code**: Routes and credentials are managed by Ansible; re-run the playbook to change them

### Documentation
- **Quick Start**: [QUICKSTART-APISIX.md](QUICKSTART-APISIX.md)
- **Full Guide**: [README-APISIX.md](README-APISIX.md)
- **Usage Examples**: [examples/apisix-usage.sh](examples/apisix-usage.sh)

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
curl http://localhost:5062/eth/v1/node/syncing

# Check beacon node health
curl http://localhost:5062/eth/v1/node/health

# Get current slot
curl http://localhost:5062/eth/v1/beacon/headers/head

# Check if beacon node is ready for validator duties
curl http://localhost:5062/eth/v1/node/readiness
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

# Common Errors and Solutions

### Charon Lock File Error
```log
08:10:07.227 ERRO cmd        Fatal error: existing private key lock file found, another charon instance may be running on your machine
{"path": "/opt/charon/charon-enr-private-key.lock", "command": "charon run"}
```

**Solution:**
```bash
# Stop Charon, remove lock file, and restart
cd ~/.charon && docker stop charon && sudo rm -rf charon-enr-private-key.lock && docker restart charon
```

## References

### Core Ethereum Documentation
- [Ethereum Developer Documentation](https://ethereum.org/en/developers/docs/)
- [Ethereum Staking Documentation](https://ethereum.org/en/staking/)

### Client Documentation
- [Prysm Client Documentation](https://docs.prylabs.network/docs/getting-started)
- [Lighthouse Client Documentation](https://lighthouse-book.sigmaprime.io/)
- [Teku Client Documentation](https://docs.teku.consensys.net/)
- [Nimbus Client Documentation](https://nimbus.guide/)

### Reference Implementations
- [Eth Docker - Reference Docker Implementation](https://github.com/eth-educators/eth-docker)
- [Nethermind Docker Image](https://github.com/nethermindeth/docker-eth-nethermind)
- [Lighthouse Docker Image](https://github.com/sigp/lighthouse)

### Infrastructure & Tools
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)

### Security & Best Practices
- [Ethereum Security Best Practices](https://ethereum.org/en/security/)
- [Docker Security Documentation](https://docs.docker.com/engine/security/)
