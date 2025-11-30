# APISIX Quick Reference Card

## Generate Keys (First Time Setup)

```bash
# API Key
echo "apisix_api_key: \"$(openssl rand -hex 32)\""

# Bearer Token
echo "apisix_bearer_token: \"$(openssl rand -base64 32)\""

# Admin Key
echo "apisix_admin_key: \"$(openssl rand -hex 32)\""
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
docker logs -f eth-ansible-apisix-etcd

# Restart
docker restart eth-ansible-apisix
docker restart eth-ansible-apisix-etcd

# Test connectivity
docker exec eth-ansible-apisix ping eth-ansible-execution-1
docker exec eth-ansible-apisix ping eth-ansible-consensus-1
```

## Metrics & Monitoring

```bash
# Prometheus metrics
curl http://server:9091/apisix/prometheus/metrics

# Admin API (list routes)
curl -H "X-API-KEY: ADMIN_KEY" http://server:9180/apisix/admin/routes
```

## Ports Reference

| Port | Service | Access |
|------|---------|--------|
| 9080 | APISIX Gateway | External |
| 9180 | Admin API | Internal Only |
| 9443 | APISIX HTTPS | External (if enabled) |
| 9091 | Prometheus Metrics | Internal |
| 2379 | etcd | Internal Only |

## Endpoints Reference

| Endpoint | Target | Auth |
|----------|--------|------|
| `/health` | Lighthouse health | No |
| `/execution-health` | Nethermind health | No |
| `/consensus/*` | Lighthouse API (5062) | Yes |
| `/execution/*` | Nethermind RPC (8544) | Yes |
| `/auth/validate` | Auth service | - |

## Troubleshooting Quick Checks

```bash
# 1. Containers running?
docker ps | grep -E 'apisix|etcd'

# 2. Can reach upstream?
docker exec eth-ansible-apisix curl -s http://eth-ansible-consensus-1:5062/eth/v1/node/health
docker exec eth-ansible-apisix curl -s -X POST http://eth-ansible-execution-1:8544

# 3. Auth working?
curl -i -H "X-API-Key: KEY" http://server:9080/auth/validate

# 4. Check logs
docker logs --tail 50 eth-ansible-apisix | grep -i error
```

## Files Reference

| File | Purpose |
|------|---------|
| `tasks/apisix.yml` | Ansible deployment tasks |
| `templates/apisix-config.yaml.j2` | APISIX config template |
| `templates/apisix-routes.yaml.j2` | Routes & auth config |
| `defaults/main.yml` | Default variables |
| `examples/verify-apisix.sh` | Verification script |
| `examples/apisix-usage.sh` | Usage examples |

## Configuration Variables

### Must Set (in secrets.yml)
```yaml
apisix_enabled: true
apisix_api_key: "secure-key-here"
apisix_bearer_token: "secure-token-here"
apisix_admin_key: "secure-admin-key-here"
```

### Optional Overrides
```yaml
apisix_gateway_port: 9080
apisix_admin_port: 9180
apisix_allow_degradation: false
apisix_enable_auth_service: true
```

## Emergency Commands

```bash
# Stop APISIX
docker stop eth-ansible-apisix eth-ansible-apisix-etcd

# Remove containers
docker rm eth-ansible-apisix eth-ansible-apisix-etcd

# Redeploy
ansible-playbook -i inventory main.yml --tags apisix --ask-vault-pass

# Direct access (bypass APISIX)
curl http://localhost:5062/eth/v1/node/version  # Consensus
curl -X POST http://localhost:8544 --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'  # Execution
```

## Documentation Links

- Quick Start: [QUICKSTART-APISIX.md](QUICKSTART-APISIX.md)
- Full Guide: [README-APISIX.md](README-APISIX.md)
- Architecture: [docs/APISIX-ARCHITECTURE.md](docs/APISIX-ARCHITECTURE.md)
- Summary: [APISIX-DEPLOYMENT-SUMMARY.md](APISIX-DEPLOYMENT-SUMMARY.md)

---
**Tip**: Bookmark this page for quick reference during operations!

