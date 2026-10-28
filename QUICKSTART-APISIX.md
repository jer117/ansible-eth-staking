# APISIX Quick Start Guide

## 1. Configure Authentication Keys

Clients authenticate with an API key or a bearer token. You don't have to create them: if `apisix_api_key` and `apisix_bearer_token` are not set, the playbook generates random values on the first run and stores them on your control machine (see step 4).

To choose your own instead, generate secure keys:

```bash
# Generate API Key
echo "apisix_api_key: \"$(openssl rand -hex 32)\""

# Generate Bearer Token
echo "apisix_bearer_token: \"$(openssl rand -hex 32)\""
```

Add the two lines to your `secrets.yml` or `host_vars/<your-host>.yml`. The playbook rejects keys shorter than 16 characters and the `changeme` / `change-this` placeholders from the examples.

## 2. Enable APISIX

APISIX is enabled by default (`apisix_enabled: true` in `defaults/main.yml`).

## 3. Deploy APISIX

```bash
# Deploy only APISIX
ansible-playbook -i inventory main.yml --tags apisix --ask-vault-pass

# Or deploy the full stack
ansible-playbook -i inventory main.yml --ask-vault-pass
```

## 4. Verify Deployment

```bash
# Check containers are running
ssh <your-server> 'docker ps | grep apisix'

# Expected output:
# eth-ansible-apisix
```

If Ansible generated the credentials, read them on the control machine (in the directory that holds your inventory file):

```bash
cat credentials/<inventory_hostname>/apisix/api_key
cat credentials/<inventory_hostname>/apisix/bearer_token
```

Run the verification script:

```bash
./examples/verify-apisix.sh <your-server> "$(cat credentials/<inventory_hostname>/apisix/api_key)"
```

## 5. Test the Gateway

### Test Health Endpoint (No Auth)
```bash
curl http://<your-server>:9080/health
```

### Test Consensus API (With Auth)
```bash
# Using API Key
curl -H "X-API-Key: your-api-key" \
  http://<your-server>:9080/consensus/eth/v1/node/version

# Using Bearer Token
curl -H "Authorization: Bearer your-bearer-token" \
  http://<your-server>:9080/consensus/eth/v1/node/version
```

### Test Execution API (With Auth)
```bash
curl -H "X-API-Key: your-api-key" \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://<your-server>:9080/execution/
```

## 6. Common Endpoints

### Consensus Client (Lighthouse) via APISIX

| Endpoint | Description | Auth Required |
|----------|-------------|---------------|
| `/health` | Node health check | No |
| `/consensus/eth/v1/node/version` | Get node version | Yes |
| `/consensus/eth/v1/node/syncing` | Get sync status | Yes |
| `/consensus/eth/v1/node/peers` | Get connected peers | Yes |
| `/consensus/eth/v1/node/identity` | Get node identity | Yes |
| `/consensus/eth/v1/beacon/states/head/validators` | Get validators | Yes |

### Execution Client (Nethermind) via APISIX

| RPC Method | Description | Auth Required |
|------------|-------------|---------------|
| `eth_blockNumber` | Current block number | Yes |
| `eth_syncing` | Sync status | Yes |
| `net_peerCount` | Peer count | Yes |
| `eth_gasPrice` | Current gas price | Yes |
| `eth_getBlockByNumber` | Get block by number | Yes |

All execution client requests go to: `http://<server>:9080/execution/`

## 7. Monitoring

APISIX serves Prometheus metrics on port 9091 inside the Docker network (the port is not published on the host). View them on the server:
```bash
ssh <your-server> 'docker run --rm --network eth-staking-network-net curlimages/curl -s http://eth-ansible-apisix:9091/apisix/prometheus/metrics'
```

## 8. Changing the Configuration

There is no Admin API. Routes, consumers and plugins are defined in `templates/apisix-routes.yaml.j2`; edit it (or your vars) and re-run step 3.

## 9. Troubleshooting

Check logs:
```bash
# APISIX logs
ssh <your-server> 'docker logs eth-ansible-apisix'

# Errors loading apisix.yaml (every route, including /health, returns 404)
ssh <your-server> 'docker logs eth-ansible-apisix 2>&1 | grep config_yaml'
```

Test authentication:
```bash
# Should return 401 Unauthorized
curl -i http://<your-server>:9080/consensus/eth/v1/node/version

# Should return 200 OK
curl -i -H "X-API-Key: your-api-key" \
  http://<your-server>:9080/consensus/eth/v1/node/version
```

Upgrading from the etcd-based setup? See [README-APISIX.md](README-APISIX.md#upgrading-from-the-etcd-based-setup). The old etcd data in `/data/apisix` can be deleted manually.

## 10. Network Diagram

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ HTTP Request
       │ (with API Key or Bearer Token)
       ▼
┌─────────────────────────────────┐
│         APISIX Gateway          │
│         Port: 9080              │
│                                 │
│  key-auth checks credentials    │
│  missing/wrong → 401            │
└──────┬──────────────────────────┘
       │ Authenticated request
       │ (credential header removed)
       ▼
┌─────────────────────────────────┐
│    Upstream Services            │
│                                 │
│  ┌──────────────────────────┐   │
│  │  Lighthouse (Consensus)  │   │
│  │  Port: 5062              │   │
│  └──────────────────────────┘   │
│                                 │
│  ┌──────────────────────────┐   │
│  │  Nethermind (Execution)  │   │
│  │  Port: 8544              │   │
│  └──────────────────────────┘   │
└─────────────────────────────────┘
```

## 11. Security Best Practices

1. **Use Strong Keys**: Let Ansible generate the keys, or use `openssl rand -hex 32`
2. **Use HTTPS**: In production, configure SSL/TLS certificates
3. **IP Whitelisting**: Consider restricting access by IP
4. **Firewall Rules**: Only expose port 9080/9443 externally
5. **Rate Limiting**: Add rate limiting for production use
6. **Rotate Keys**: Regularly rotate API keys and bearer tokens (delete the generated files or change your vars, then re-run the playbook)

## 12. Advanced Features

See `README-APISIX.md` for:
- SSL/TLS configuration
- Rate limiting
- IP whitelisting
- Custom routes
- Plugin configuration

## Need Help?

- APISIX Documentation: https://apisix.apache.org/docs/apisix/
- Key-Auth Plugin: https://apisix.apache.org/docs/apisix/plugins/key-auth/
- Ansible Role: See `tasks/apisix.yml` and `templates/apisix-*.j2`

