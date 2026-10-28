# APISIX Quick Reference Card

## Credentials (First Time Setup)

```bash
# Optional: if apisix_api_key / apisix_bearer_token are unset, Ansible generates
# them and stores them in credentials/<host>/apisix/ next to your inventory file.

# API Key
echo "apisix_api_key: \"$(openssl rand -hex 32)\""

# Bearer Token
echo "apisix_bearer_token: \"$(openssl rand -hex 32)\""

# Read generated credentials (control machine)
cat credentials/<host>/apisix/api_key
cat credentials/<host>/apisix/bearer_token
```

## Deploy Commands

```bash
# Full stack
ansible-playbook -i inventory main.yml --ask-vault-pass

# APISIX only
ansible-playbook -i inventory main.yml --tags apisix --ask-vault-pass

# Standalone playbook
ansible-playbook -i inventory playbooks/apisix-only.yml --ask-vault-pass
```

## Verify Deployment

```bash
./examples/verify-apisix.sh <server-ip> <api-key>
```

## Common curl Commands

### Health Checks (No Auth)
```bash
curl http://server:9080/health
curl http://server:9080/execution-health
```

### Consensus API (With Auth)
```bash
# Node version
curl -H "X-API-Key: KEY" http://server:9080/consensus/eth/v1/node/version

# Same with the bearer token
curl -H "Authorization: Bearer TOKEN" http://server:9080/consensus/eth/v1/node/version

# Sync status
curl -H "X-API-Key: KEY" http://server:9080/consensus/eth/v1/node/syncing

# Peers
curl -H "X-API-Key: KEY" http://server:9080/consensus/eth/v1/node/peers
```

### Execution API (With Auth)
```bash
# Block number
curl -H "X-API-Key: KEY" -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://server:9080/execution/

# Sync status
curl -H "X-API-Key: KEY" -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://server:9080/execution/

# Peer count
curl -H "X-API-Key: KEY" -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
  http://server:9080/execution/
```

## Docker Commands

```bash
# Check containers
docker ps | grep apisix

# View logs
docker logs -f eth-ansible-apisix

# Restart
docker restart eth-ansible-apisix

# Test connectivity (the APISIX image has no curl, so use a throwaway container)
docker run --rm --network eth-staking-network-net curlimages/curl -s http://eth-ansible-consensus-1:5062/eth/v1/node/health
docker run --rm --network eth-staking-network-net curlimages/curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://eth-ansible-execution-1:8544
```

## Metrics & Configuration

```bash
# Prometheus metrics (port 9091 is only reachable on the Docker network)
docker run --rm --network eth-staking-network-net curlimages/curl -s http://eth-ansible-apisix:9091/apisix/prometheus/metrics

# Configuration APISIX is running with (no Admin API; change it via Ansible)
sudo cat /root/.eth-staking/config/apisix/apisix/apisix.yaml
```

## Ports Reference

| Port | Service | Access |
|------|---------|--------|
| 9080 | APISIX Gateway | External |
| 9443 | APISIX HTTPS | External (needs a certificate) |
| 9091 | Prometheus Metrics | Docker network only (not published) |

## Endpoints Reference

| Endpoint | Target | Auth |
|----------|--------|------|
| `/health` | Lighthouse health | No |
| `/execution-health` | Nethermind health | No |
| `/consensus/*` | Lighthouse API (5062) | Yes |
| `/execution/*` | Nethermind RPC (8544) | Yes |

## Troubleshooting Quick Checks

```bash
# 1. Container running?
docker ps | grep apisix

# 2. Can reach upstream?
docker run --rm --network eth-staking-network-net curlimages/curl -s http://eth-ansible-consensus-1:5062/eth/v1/node/health
docker run --rm --network eth-staking-network-net curlimages/curl -s -X POST http://eth-ansible-execution-1:8544

# 3. Auth working? (expect 401 without a key, 200 with it)
curl -i http://server:9080/consensus/eth/v1/node/version
curl -i -H "X-API-Key: KEY" http://server:9080/consensus/eth/v1/node/version

# 4. Check logs (404 on every route = apisix.yaml not loaded, look for config_yaml.lua)
docker logs --tail 50 eth-ansible-apisix 2>&1 | grep -i -E 'error|config_yaml'
```

## Files Reference

| File | Purpose |
|------|---------|
| `roles/ethereum_home_staking/tasks/apisix.yml` | Ansible deployment tasks |
| `roles/ethereum_home_staking/templates/apisix-config.yaml.j2` | APISIX config template (standalone mode) |
| `roles/ethereum_home_staking/templates/apisix-routes.yaml.j2` | Routes, consumers & auth config |
| `roles/ethereum_home_staking/defaults/main.yml` | Default variables |
| `credentials/<host>/apisix/` | Generated client credentials (control machine) |
| `examples/verify-apisix.sh` | Verification script |
| `examples/apisix-usage.sh` | Usage examples |

## Configuration Variables

### Credentials (optional, in secrets.yml or host_vars)
```yaml
# Generated into credentials/<host>/apisix/ if unset
apisix_api_key: "<random value>"
apisix_bearer_token: "<random value>"
```

### Optional Overrides (host_vars or group_vars)
```yaml
apisix_enable_ipv6: false   # default true; for hosts without IPv6

# Defaults from roles/ethereum_home_staking/defaults/main.yml
apisix_enabled: true
apisix_gateway_port: 9080
apisix_https_port: 9443
```

## Emergency Commands

```bash
# Stop APISIX
docker stop eth-ansible-apisix

# Remove container
docker rm eth-ansible-apisix

# Redeploy
ansible-playbook -i inventory main.yml --tags apisix --ask-vault-pass

# Direct access (bypass APISIX)
curl http://localhost:5062/eth/v1/node/version  # Consensus
curl -X POST http://localhost:8544 --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'  # Execution

# Remove etcd data left over from the old etcd-based setup
sudo rm -rf /data/apisix
```

## Documentation Links

- Quick Start: [QUICKSTART-APISIX.md](QUICKSTART-APISIX.md)
- Full Guide: [README-APISIX.md](README-APISIX.md)
- Architecture: [docs/APISIX-ARCHITECTURE.md](docs/APISIX-ARCHITECTURE.md)
- Summary: [APISIX-DEPLOYMENT-SUMMARY.md](APISIX-DEPLOYMENT-SUMMARY.md)

---
**Tip**: Bookmark this page for quick reference during operations!

