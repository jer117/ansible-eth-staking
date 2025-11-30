# APISIX API Gateway for Ethereum Staking

This Ansible role sets up Apache APISIX as an API Gateway with forward authentication for your Ethereum staking infrastructure.

## Overview

APISIX provides:
- **Forward Authentication**: Validates requests before forwarding to consensus/execution clients
- **API Key & Bearer Token Support**: Secure access to your RPC endpoints
- **Prometheus Metrics**: Monitor API gateway performance
- **Request Routing**: Clean routing to execution and consensus clients
- **Health Checks**: Unauthenticated health check endpoints

## Architecture

```
Client Request → APISIX Gateway → Forward Auth Service → Upstream (Nethermind/Lighthouse)
```

## Endpoints

### Authenticated Endpoints

#### Execution Client (Nethermind)
- **URL**: `http://<server>:9080/execution/*`
- **Upstream**: Nethermind JSON-RPC on port 8544
- **Authentication**: Required (API Key or Bearer Token)
- **Example**:
  ```bash
  curl -H "X-API-Key: your-api-key" \
    -X POST \
    -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    http://<server>:9080/execution/
  ```

#### Consensus Client (Lighthouse)
- **URL**: `http://<server>:9080/consensus/*`
- **Upstream**: Lighthouse HTTP API on port 5062
- **Authentication**: Required (API Key or Bearer Token)
- **Example**:
  ```bash
  curl -H "X-API-Key: your-api-key" \
    http://<server>:9080/consensus/eth/v1/node/version
  ```

### Unauthenticated Endpoints

#### Health Checks
- **Consensus Health**: `http://<server>:9080/health`
- **Execution Health**: `http://<server>:9080/execution-health`

## Configuration

### Variables (defaults/main.yml)

```yaml
# Enable/Disable APISIX
apisix_enabled: true

# Docker Images
apisix_image: "apache/apisix:3.14.1-debian"
apisix_etcd_image: "bitnami/etcd:3.5.11"

# Container Names
apisix_container_name: "eth-ansible-apisix"
apisix_etcd_container_name: "eth-ansible-apisix-etcd"

# Ports
apisix_gateway_port: 9080       # Main gateway port
apisix_admin_port: 9180         # Admin API port
apisix_https_port: 9443         # HTTPS port
apisix_prometheus_port: 9091    # Prometheus metrics port

# Authentication (OVERRIDE IN SECRETS!)
apisix_admin_key: "changeme-admin-key-{{ ansible_hostname }}"
apisix_api_key: "changeme-api-key-{{ ansible_hostname }}"
apisix_bearer_token: "changeme-bearer-token-{{ ansible_hostname }}"

# Auth Service
apisix_enable_auth_service: true
apisix_allow_degradation: false  # Set to true to allow requests when auth service is down
```

### Security Configuration

**IMPORTANT**: Override the default authentication keys in your `secrets.yml` or host_vars file:

```yaml
# In your secrets.yml or host_vars/<host>.yml
apisix_admin_key: "your-secure-admin-key-here"
apisix_api_key: "your-secure-api-key-here"
apisix_bearer_token: "your-secure-bearer-token-here"
```

Generate secure keys:
```bash
# Generate API Key
openssl rand -hex 32

# Generate Bearer Token
openssl rand -base64 32
```

## Authentication Methods

### Method 1: API Key Header
```bash
curl -H "X-API-Key: your-api-key" http://<server>:9080/consensus/eth/v1/node/version
```

### Method 2: Bearer Token
```bash
curl -H "Authorization: Bearer your-bearer-token" http://<server>:9080/consensus/eth/v1/node/version
```

## Deployment

### Enable APISIX in your playbook:

```yaml
# main.yml or host_vars
apisix_enabled: true
```

### Run the playbook:

```bash
# Deploy APISIX only
ansible-playbook -i inventory main.yml --tags apisix

# Deploy full stack including APISIX
ansible-playbook -i inventory main.yml
```

### Verify deployment:

```bash
# Check APISIX container
docker ps | grep apisix

# Test health endpoint (no auth)
curl http://<server>:9080/health

# Test authenticated endpoint
curl -H "X-API-Key: your-api-key" http://<server>:9080/consensus/eth/v1/node/version
```

## Admin API

Access the APISIX Admin API on port 9180:

```bash
# List all routes
curl -H "X-API-KEY: your-admin-key" http://<server>:9180/apisix/admin/routes

# Get route details
curl -H "X-API-KEY: your-admin-key" http://<server>:9180/apisix/admin/routes/execution-rpc
```

## Monitoring

APISIX exposes Prometheus metrics on port 9091:

```bash
curl http://<server>:9091/apisix/prometheus/metrics
```

Metrics include:
- Request counts and latencies
- HTTP status codes
- Upstream response times
- Plugin execution metrics

## Troubleshooting

### Check APISIX logs:
```bash
docker logs eth-ansible-apisix
```

### Check etcd logs:
```bash
docker logs eth-ansible-apisix-etcd
```

### Verify network connectivity:
```bash
# Check if containers can communicate
docker exec eth-ansible-apisix ping eth-ansible-execution-1
docker exec eth-ansible-apisix ping eth-ansible-consensus-1
```

### Test auth service directly:
```bash
# Should return 401
curl -i http://<server>:9080/auth/validate

# Should return 200
curl -i -H "X-API-Key: your-api-key" http://<server>:9080/auth/validate
```

### Common Issues

1. **401 Unauthorized**: Check your API key/bearer token
2. **502 Bad Gateway**: Upstream service (Nethermind/Lighthouse) may be down
3. **Connection refused**: Check if APISIX container is running and ports are exposed

## Advanced Configuration

### Custom Routes

To add custom routes, modify `templates/apisix-routes.yaml.j2` and add new route definitions.

### SSL/TLS

To enable HTTPS, you'll need to:
1. Generate SSL certificates
2. Mount them to the APISIX container
3. Configure SSL in `apisix-config.yaml.j2`

### Rate Limiting

Add the `limit-req` plugin to routes in `apisix-routes.yaml.j2`:

```yaml
plugins:
  limit-req:
    rate: 100
    burst: 50
    key: remote_addr
```

### IP Whitelisting

Add the `ip-restriction` plugin:

```yaml
plugins:
  ip-restriction:
    whitelist:
      - "192.168.1.0/24"
      - "10.0.0.0/8"
```

## References

- [APISIX Documentation](https://apisix.apache.org/docs/apisix/getting-started/)
- [Forward-Auth Plugin](https://apisix.apache.org/docs/apisix/plugins/forward-auth/)
- [APISIX Admin API](https://apisix.apache.org/docs/apisix/admin-api/)

