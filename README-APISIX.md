# APISIX API Gateway for Ethereum Staking

This Ansible role sets up Apache APISIX as an API Gateway with API key / bearer token authentication for your Ethereum staking infrastructure.

## Overview

APISIX provides:
- **Authentication**: APISIX's built-in `key-auth` plugin checks requests before they are forwarded to consensus/execution clients
- **API Key & Bearer Token Support**: Secure access to your RPC endpoints
- **Prometheus Metrics**: Monitor API gateway performance
- **Request Routing**: Clean routing to execution and consensus clients
- **Health Checks**: Unauthenticated health check endpoints

## Architecture

```
Client Request → APISIX Gateway (key-auth) → Upstream (Nethermind/Lighthouse)
```

APISIX runs in file-driven standalone mode (`deployment.role: data_plane`, `config_provider: yaml`). Ansible renders two files into `{{ apisix_config_dir }}/apisix/` on the server (by default `/root/.eth-staking/config/apisix/apisix/`) and mounts them read-only into the container:

- `config.yaml`, from `roles/ethereum_home_staking/templates/apisix-config.yaml.j2`: node settings
- `apisix.yaml`, from `roles/ethereum_home_staking/templates/apisix-routes.yaml.j2`: routes, consumers (client credentials) and plugins

There is no etcd and no Admin API. To change routes, credentials or plugins, edit the variables or templates and re-run the playbook; APISIX is restarted when either file changes.

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

### Variables (roles/ethereum_home_staking/defaults/main.yml)

```yaml
# Enable/Disable APISIX
apisix_enabled: true

# Docker Image
apisix_image: "apache/apisix:3.19.0-debian"

# Config directory on the server
apisix_config_dir: "/root/.eth-staking/config/apisix"

# Ports published on the host
apisix_gateway_port: 9080       # Main gateway port
apisix_https_port: 9443         # HTTPS port
```

Prometheus metrics are served on port 9091 inside the Docker network only (see [Monitoring](#monitoring)).

Override any of these in host_vars or group_vars. The container name (`apisix_container_name: "eth-ansible-apisix"`) is fixed in `roles/ethereum_home_staking/vars/main.yml`; change it only with `-e`.

These optional variables have no default; set them in host_vars or `secrets.yml`:

```yaml
apisix_api_key: "..."          # Client API key (generated if unset, see below)
apisix_bearer_token: "..."     # Client bearer token (generated if unset, see below)
apisix_enable_ipv6: false      # Default true; set to false on hosts without IPv6
```

### Client Credentials

Clients authenticate with `apisix_api_key` or `apisix_bearer_token`. You can set them yourself or let Ansible generate them.

**Option 1: let Ansible generate them (default).** If the variables are not set, the playbook generates random 48-character alphanumeric values on the first run and stores them on the control machine, in the directory that holds your inventory file:

```
credentials/<inventory_hostname>/apisix/api_key
credentials/<inventory_hostname>/apisix/bearer_token
```

The files have mode 0600, `credentials/` is in `.gitignore`, and later runs reuse the same values. To read them:

```bash
cat credentials/<inventory_hostname>/apisix/api_key
cat credentials/<inventory_hostname>/apisix/bearer_token
```

To rotate a generated credential, delete its file and re-run the playbook.

**Option 2: set them yourself** in your `secrets.yml` or `host_vars/<host>.yml` (see `example.apisix-secrets.yml`):

```yaml
apisix_api_key: "<random value>"
apisix_bearer_token: "<random value>"
```

Generate secure values with:
```bash
openssl rand -hex 32
```
(`openssl rand -base64 32` works too.)

The playbook stops with an error if a credential is shorter than 16 characters or still contains `changeme` / `change-this` from the examples.

On the server, the rendered `apisix.yaml` contains the credentials. It is owned by root with group 636 (the `apisix` user in the container) and mode 0640.

## Authentication Methods

### Method 1: API Key Header
```bash
curl -H "X-API-Key: your-api-key" http://<server>:9080/consensus/eth/v1/node/version
```

### Method 2: Bearer Token
```bash
curl -H "Authorization: Bearer your-bearer-token" http://<server>:9080/consensus/eth/v1/node/version
```

The header value must match exactly, including the `Bearer ` prefix.

- Requests without valid credentials get `401 Unauthorized` and are not forwarded.
- The credential header is removed before the request is proxied, and the upstream receives an `X-Consumer-Username` header (`api_key_client` or `bearer_token_client`).
- `key-auth` also accepts the API key in an `apikey` query parameter (`?apikey=<key>`). Prefer the headers: URLs end up in logs.

## Deployment

### Enable APISIX:

APISIX is enabled by default (`apisix_enabled: true` in `roles/ethereum_home_staking/defaults/main.yml`).

### Run the playbook:

```bash
# Deploy APISIX only
ansible-playbook -i inventory main.yml --tags apisix

# Or use the standalone APISIX playbook
ansible-playbook -i inventory playbooks/apisix-only.yml

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

# Or run the verification script
./examples/verify-apisix.sh <server> "$(cat credentials/<inventory_hostname>/apisix/api_key)"
```

## Changing the Configuration

There is no Admin API in this setup (port 9180 is not published). Edit `roles/ethereum_home_staking/templates/apisix-routes.yaml.j2` (routes, consumers, plugins) or `roles/ethereum_home_staking/templates/apisix-config.yaml.j2`, then re-run:

```bash
ansible-playbook -i inventory main.yml --tags apisix
```

To see the configuration APISIX is running with, read the rendered file on the server:

```bash
sudo cat /root/.eth-staking/config/apisix/apisix/apisix.yaml
```

## Upgrading from the etcd-based Setup

Earlier versions of this role ran APISIX with etcd and an Admin API on port 9180. When you re-run the playbook:

- The `eth-ansible-apisix-etcd` container is removed.
- Port 9180 is no longer published. If you opened it in your firewall, you can close it.
- `apisix_admin_key`, `apisix_admin_port`, `apisix_enable_auth_service`, `apisix_auth_service_host`, `apisix_auth_service_port` and `apisix_allow_degradation` are no longer used; delete them from your vars.
- Anything you added through the Admin API was stored in etcd and is not carried over. Add it to `roles/ethereum_home_staking/templates/apisix-routes.yaml.j2` instead.
- The old etcd data directory is not used any more and can be deleted manually: `sudo rm -rf /data/apisix`.

If your vars still contain placeholder credentials (`changeme-...`, `...-change-this`), the playbook stops. Remove them to have Ansible generate new ones, or set real values.

## Monitoring

APISIX exposes Prometheus metrics on port 9091 inside the Docker network; the port is not published on the host. The Prometheus container deployed by this role is on the same network (`eth-staking-network-net`), so you can scrape APISIX by adding a job to `roles/ethereum_home_staking/templates/prometheus.yml`:

```yaml
  - job_name: 'apisix'
    static_configs:
      - targets: ['eth-ansible-apisix:9091']
    metrics_path: '/apisix/prometheus/metrics'
```

To look at the metrics by hand, run curl in a throwaway container on the same network (the APISIX image does not include curl):

```bash
docker run --rm --network eth-staking-network-net curlimages/curl \
  -s http://eth-ansible-apisix:9091/apisix/prometheus/metrics
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

If APISIX cannot load `apisix.yaml`, every route (including `/health`) returns 404 and the log shows errors from `config_yaml.lua`:
```bash
docker logs eth-ansible-apisix 2>&1 | grep config_yaml
```

### Verify network connectivity:
```bash
# Check if the upstreams are reachable on the Docker network
docker run --rm --network eth-staking-network-net curlimages/curl \
  -s http://eth-ansible-consensus-1:5062/eth/v1/node/health -o /dev/null -w "%{http_code}\n"
docker run --rm --network eth-staking-network-net curlimages/curl \
  -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://eth-ansible-execution-1:8544
```

### Test authentication:
```bash
# Should return 401
curl -i http://<server>:9080/consensus/eth/v1/node/version

# Should return 200
curl -i -H "X-API-Key: your-api-key" http://<server>:9080/consensus/eth/v1/node/version
```

### Common Issues

1. **401 Unauthorized**: Check your API key/bearer token (if Ansible generated it: `cat credentials/<inventory_hostname>/apisix/api_key`)
2. **404 Not Found on every route**: APISIX did not load `apisix.yaml`; check the logs for `config_yaml.lua` errors
3. **502 Bad Gateway**: Upstream service (Nethermind/Lighthouse) may be down
4. **Connection refused**: Check if APISIX container is running and ports are exposed
5. **APISIX fails to start on a host without IPv6**: set `apisix_enable_ipv6: false`

## Advanced Configuration

### Custom Routes

To add custom routes, modify `roles/ethereum_home_staking/templates/apisix-routes.yaml.j2` and add new route definitions. Add `plugin_config_id: client-auth` to a route to require the same credentials as the client APIs. Keep the `#END` line at the end of the file: APISIX only loads the file when it ends with it.

### SSL/TLS

Port 9443 is published and APISIX listens for HTTPS on it, but no certificate is configured. To enable HTTPS:
1. Generate SSL certificates
2. Add them as an `ssls` entry (certificate, key and SNIs) in `roles/ethereum_home_staking/templates/apisix-routes.yaml.j2`; with no Admin API, certificates are configured in that file like routes
3. Re-run the playbook

### Rate Limiting

Add the `limit-req` plugin to routes in `apisix-routes.yaml.j2` (or to the `client-auth` plugin config to cover both client APIs):

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
- [Standalone Mode](https://apisix.apache.org/docs/apisix/deployment-modes/#standalone)
- [Key-Auth Plugin](https://apisix.apache.org/docs/apisix/plugins/key-auth/)
- [Multi-Auth Plugin](https://apisix.apache.org/docs/apisix/plugins/multi-auth/)

