# APISIX Quick Start Guide

## 1. Configure Authentication Keys

First, generate secure authentication keys:

```bash
# Generate API Key
echo "apisix_api_key: \"$(openssl rand -hex 32)\""

# Generate Bearer Token  
echo "apisix_bearer_token: \"$(openssl rand -base64 32)\""

# Generate Admin Key
echo "apisix_admin_key: \"$(openssl rand -hex 32)\""
```

Add these to your `secrets.yml` or `host_vars/<your-host>.yml`:

```yaml
# Security keys for APISIX
apisix_api_key: "your-generated-api-key-here"
apisix_bearer_token: "your-generated-bearer-token-here"
apisix_admin_key: "your-generated-admin-key-here"
```

## 2. Enable APISIX

In your `host_vars/<your-host>.yml` or `vars/main.yml`:

```yaml
apisix_enabled: true
```

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
# eth-ansible-apisix-etcd
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

View APISIX metrics:
```bash
curl http://<your-server>:9091/apisix/prometheus/metrics
```

## 8. Administration

List all configured routes:
```bash
curl -H "X-API-KEY: your-admin-key" \
  http://<your-server>:9180/apisix/admin/routes
```

## 9. Troubleshooting

Check logs:
```bash
# APISIX logs
ssh <your-server> 'docker logs eth-ansible-apisix'

# etcd logs
ssh <your-server> 'docker logs eth-ansible-apisix-etcd'
```

Test authentication service:
```bash
# Should return 401 Unauthorized
curl -i http://<your-server>:9080/auth/validate

# Should return 200 OK
curl -i -H "X-API-Key: your-api-key" \
  http://<your-server>:9080/auth/validate
```

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
└──────┬──────────────────────────┘
       │
       ├─► Forward Auth Service ──► Validates API Key/Token
       │                             Returns 200/401
       ▼
┌─────────────────────────────────┐
│    Upstream Services            │
│                                 │
│  ┌──────────────────────────┐  │
│  │  Lighthouse (Consensus)  │  │
│  │  Port: 5062              │  │
│  └──────────────────────────┘  │
│                                 │
│  ┌──────────────────────────┐  │
│  │  Nethermind (Execution)  │  │
│  │  Port: 8544              │  │
│  └──────────────────────────┘  │
└─────────────────────────────────┘
```

## 11. Security Best Practices

1. **Change Default Keys**: Always override default authentication keys
2. **Use HTTPS**: In production, configure SSL/TLS certificates
3. **IP Whitelisting**: Consider restricting access by IP
4. **Firewall Rules**: Only expose port 9080/9443 externally, keep 9180 internal
5. **Rate Limiting**: Add rate limiting for production use
6. **Rotate Keys**: Regularly rotate API keys and bearer tokens

## 12. Advanced Features

See `README-APISIX.md` for:
- SSL/TLS configuration
- Rate limiting
- IP whitelisting
- Custom routes
- Plugin configuration

## Need Help?

- APISIX Documentation: https://apisix.apache.org/docs/apisix/
- Forward-Auth Plugin: https://apisix.apache.org/docs/apisix/plugins/forward-auth/
- Ansible Role: See `tasks/apisix.yml` and `templates/apisix-*.j2`

