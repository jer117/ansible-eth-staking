# APISIX Deployment Summary

## What Has Been Created

An Ansible role for deploying Apache APISIX as an API Gateway with API key / bearer token authentication (APISIX's built-in `key-auth` plugin) for your Ethereum staking infrastructure.

### Files Created

#### Ansible Tasks & Templates
- **`roles/ethereum_home_staking/tasks/apisix.yml`**: Main Ansible task file: resolves the client credentials and deploys the APISIX container
- **`roles/ethereum_home_staking/templates/apisix-config.yaml.j2`**: APISIX main configuration template (standalone mode)
- **`roles/ethereum_home_staking/templates/apisix-routes.yaml.j2`**: APISIX routes, consumers and key-auth configuration

#### Configuration Files
- **`roles/ethereum_home_staking/defaults/main.yml`**: Updated with APISIX variables and defaults
- **`main.yml`**: Updated to include APISIX deployment task
- **`example.apisix-secrets.yml`**: Example credentials file
- **`example.env.apisix`**: Environment variables example

#### Documentation
- **`README-APISIX.md`**: Complete APISIX implementation guide
- **`QUICKSTART-APISIX.md`**: Quick start deployment guide
- **`docs/APISIX-ARCHITECTURE.md`**: Detailed architecture documentation
- **`README.md`**: Updated with APISIX section

#### Scripts & Examples
- **`examples/apisix-usage.sh`**: Sample API calls and usage examples
- **`examples/verify-apisix.sh`**: Deployment verification script
- **`playbooks/apisix-only.yml`**: Standalone APISIX deployment playbook

## Architecture Overview

```
Client → APISIX Gateway (Port 9080, key-auth) → Upstream Services
                                                 ├─ Nethermind (8544)
                                                 └─ Lighthouse (5062)
```

### Components

**APISIX Gateway** (apache/apisix:3.19.0-debian)
- Runs in file-driven standalone mode: routes and consumers are read from `apisix.yaml`, rendered by Ansible
- Routes and authenticates requests with the `key-auth` plugin
- Exports Prometheus metrics

There is no etcd and no Admin API. Configuration changes are made by editing vars/templates and re-running Ansible.

## Endpoints Configured

### Authenticated Endpoints

| Endpoint | Upstream | Port | Auth Required |
|----------|----------|------|---------------|
| `/execution/*` | Nethermind | 8544 | Yes |
| `/consensus/*` | Lighthouse | 5062 | Yes |

### Unauthenticated Endpoints

| Endpoint | Purpose |
|----------|---------|
| `/health` | Consensus health check |
| `/execution-health` | Execution health check |

### Management Endpoints

| Endpoint | Purpose | Port |
|----------|---------|------|
| Metrics | Prometheus metrics (Docker network only) | 9091 |

## Authentication Methods

### API Key (X-API-Key Header)
```bash
curl -H "X-API-Key: your-api-key" \
  http://server:9080/consensus/eth/v1/node/version
```

### Bearer Token (Authorization Header)
```bash
curl -H "Authorization: Bearer your-bearer-token" \
  http://server:9080/consensus/eth/v1/node/version
```

Requests without valid credentials get `401`. The credential header is removed before the request reaches the clients.

## Configuration Variables

### Client Credentials (optional, set in secrets.yml or host_vars)

```yaml
apisix_api_key: "<random value>"
apisix_bearer_token: "<random value>"
```

If these are not set, the playbook generates random 48-character values and stores them on the control machine in `credentials/<inventory_hostname>/apisix/api_key` and `.../bearer_token` (next to your inventory file, gitignored, mode 0600). Later runs reuse them. The playbook stops if a credential is shorter than 16 characters or contains the `changeme` / `change-this` example placeholders.

### Optional Variables (roles/ethereum_home_staking/defaults/main.yml)

```yaml
# Enable APISIX
apisix_enabled: true

# Docker Image
apisix_image: "apache/apisix:3.19.0-debian"

# Container Name
apisix_container_name: "eth-ansible-apisix"

# Directories
apisix_config_dir: "/root/.eth-staking/config/apisix"

# Ports
apisix_gateway_port: 9080
apisix_https_port: 9443
```

`apisix_enable_ipv6` (default `true`) can be set to `false` in host_vars for hosts without IPv6.

## Deployment Steps

### 1. Generate Secure Keys (optional)

Skip this step to have Ansible generate the keys.

```bash
# Generate API Key
openssl rand -hex 32

# Generate Bearer Token
openssl rand -hex 32

# How to generate both keys quickly
echo "Generate these keys and add to host_vars/{{server_ip}}.yml:"; echo ""; echo "apisix_api_key: \"$(openssl rand -hex 32)\""; echo "apisix_bearer_token: \"$(openssl rand -hex 32)\""
```

### 2. Configure Secrets

Add to `secrets.yml` or `host_vars/<server>.yml` (or leave them out to use generated keys):

```yaml
apisix_api_key: "<generated-api-key>"
apisix_bearer_token: "<generated-bearer-token>"
```

### 3. Deploy APISIX

#### Option A: Deploy with full stack
```bash
ansible-playbook -i inventory main.yml --ask-vault-pass
```

#### Option B: Deploy APISIX only
```bash
ansible-playbook -i inventory main.yml --tags apisix --ask-vault-pass
```

#### Option C: Deploy using standalone playbook
```bash
ansible-playbook -i inventory playbooks/apisix-only.yml --ask-vault-pass
```

### 4. Verify Deployment

```bash
# Generated API key (if you did not set one)
cat credentials/<inventory_hostname>/apisix/api_key

# Run verification script
./examples/verify-apisix.sh <server-ip> <api-key>

# Manual verification
curl http://<server>:9080/health
curl -H "X-API-Key: your-api-key" \
  http://<server>:9080/consensus/eth/v1/node/version
```

### Upgrading from the etcd-based Setup

The playbook removes the old `eth-ansible-apisix-etcd` container and no longer publishes the Admin API port 9180. The old etcd data directory (`/data/apisix`) can be deleted manually. See [README-APISIX.md](README-APISIX.md#upgrading-from-the-etcd-based-setup) for the variables you can remove.

## Usage Examples

### Consensus Client (Lighthouse)

```bash
# Get node version
curl -H "X-API-Key: your-api-key" \
  http://server:9080/consensus/eth/v1/node/version

# Check sync status
curl -H "X-API-Key: your-api-key" \
  http://server:9080/consensus/eth/v1/node/syncing

# Get connected peers
curl -H "X-API-Key: your-api-key" \
  http://server:9080/consensus/eth/v1/node/peers
```

### Execution Client (Nethermind)

```bash
# Get current block number
curl -H "X-API-Key: your-api-key" \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://server:9080/execution/

# Check sync status
curl -H "X-API-Key: your-api-key" \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://server:9080/execution/

# Get peer count
curl -H "X-API-Key: your-api-key" \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
  http://server:9080/execution/
```

## Security Best Practices

### 1. Firewall Configuration

```bash
# Allow APISIX gateway
sudo ufw allow 9080/tcp

# Optionally allow HTTPS
sudo ufw allow 9443/tcp
```

`ufw deny` does not block direct access to the upstream services, because Docker publishes container ports past ufw. That's why the beacon API (5062) and Nethermind's RPC (8544) are bound to `127.0.0.1`: they can't be reached from outside the host, and APISIX still reaches them by container name over the Docker network. See "Docker bypasses ufw" in [README.md](README.md) for the ports that are still published on all interfaces.

### 2. Key Management

- ✅ Use strong, randomly generated keys (or let Ansible generate them)
- ✅ Store keys in encrypted vault (ansible-vault)
- ✅ Rotate keys regularly
- ✅ Never commit keys to version control (`credentials/` is gitignored)
- ✅ Use different keys per environment

### 3. Network Security

- ✅ Run containers in isolated Docker network
- ✅ Only expose APISIX gateway externally
- ✅ No Admin API is exposed; configuration changes go through Ansible
- ✅ Use HTTPS in production with valid certificates

### 4. Monitoring

- ✅ Monitor APISIX metrics in Prometheus
- ✅ Set up alerts for authentication failures
- ✅ Track API usage patterns
- ✅ Review logs regularly

## Monitoring Integration

### Prometheus Metrics

APISIX exports metrics on port 9091 inside the Docker network (not published on the host):

```bash
docker run --rm --network eth-staking-network-net curlimages/curl \
  -s http://eth-ansible-apisix:9091/apisix/prometheus/metrics
```

### Key Metrics to Monitor

- `apisix_http_requests_total`: Total requests
- `apisix_http_latency_*`: Request latencies
- `apisix_http_status`: Status code distribution
- `apisix_upstream_status`: Upstream health
- `apisix_bandwidth`: Network traffic

### Grafana Integration

The Prometheus container is on the same Docker network, so add a scrape job to `roles/ethereum_home_staking/templates/prometheus.yml`; the metrics then show up in Grafana through the existing Prometheus datasource:

```yaml
  - job_name: 'apisix'
    static_configs:
      - targets: ['eth-ansible-apisix:9091']
    metrics_path: '/apisix/prometheus/metrics'
```

## Troubleshooting

### Common Issues

#### 1. 502 Bad Gateway
**Cause**: Upstream service not accessible  
**Solution**: Check if Nethermind/Lighthouse containers are running

```bash
docker ps | grep -E 'execution|consensus'
```

#### 2. 401 Unauthorized
**Cause**: Invalid or missing API key  
**Solution**: Verify API key matches configuration

```bash
# Generated key (if you did not set apisix_api_key)
cat credentials/<inventory_hostname>/apisix/api_key

# Test an authenticated request
curl -i -H "X-API-Key: your-key" http://server:9080/consensus/eth/v1/node/version
```

#### 3. Connection Refused
**Cause**: APISIX container not running  
**Solution**: Check container status

```bash
docker logs eth-ansible-apisix
docker restart eth-ansible-apisix
```

#### 4. 404 Not Found on Every Route (including /health)
**Cause**: APISIX could not load `apisix.yaml`  
**Solution**: Check the logs for `config_yaml.lua` errors, fix the template and re-run the playbook

```bash
docker logs eth-ansible-apisix 2>&1 | grep config_yaml
```

### Debugging Commands

```bash
# Check APISIX container
docker ps -a | grep apisix

# View APISIX logs
docker logs -f eth-ansible-apisix

# Test network connectivity (the APISIX image has no curl or ping)
docker run --rm --network eth-staking-network-net curlimages/curl -s http://eth-ansible-consensus-1:5062/eth/v1/node/health
docker run --rm --network eth-staking-network-net curlimages/curl -s -X POST http://eth-ansible-execution-1:8544

# Show the routes APISIX is running with
sudo cat /root/.eth-staking/config/apisix/apisix/apisix.yaml
```

## Advanced Configuration

### Enable HTTPS

APISIX already listens for HTTPS on port 9443 (published); it needs a certificate:

1. Generate SSL certificates
2. Add them as an `ssls` entry (certificate, key and SNIs) in `roles/ethereum_home_staking/templates/apisix-routes.yaml.j2`
3. Re-run the playbook

### Add Rate Limiting

Update `roles/ethereum_home_staking/templates/apisix-routes.yaml.j2`:

```yaml
plugins:
  limit-req:
    rate: 100
    burst: 50
    key: remote_addr
```

### Add IP Whitelisting

```yaml
plugins:
  ip-restriction:
    whitelist:
      - "192.168.1.0/24"
      - "10.0.0.0/8"
```

## Performance Tuning

### APISIX Configuration

- Adjust worker processes in config.yaml
- Configure connection pool sizes
- Enable caching for frequent requests

## Resources

### Documentation
- [README-APISIX.md](README-APISIX.md) - Complete implementation guide
- [QUICKSTART-APISIX.md](QUICKSTART-APISIX.md) - Quick start guide
- [docs/APISIX-ARCHITECTURE.md](docs/APISIX-ARCHITECTURE.md) - Architecture details

### Scripts
- [examples/apisix-usage.sh](examples/apisix-usage.sh) - Usage examples
- [examples/verify-apisix.sh](examples/verify-apisix.sh) - Verification script

### Configuration
- [example.apisix-secrets.yml](example.apisix-secrets.yml) - Secrets template
- [example.env.apisix](example.env.apisix) - Environment variables

### External Resources
- [Apache APISIX Documentation](https://apisix.apache.org/docs/apisix/)
- [Standalone Mode](https://apisix.apache.org/docs/apisix/deployment-modes/#standalone)
- [Key-Auth Plugin](https://apisix.apache.org/docs/apisix/plugins/key-auth/)
- [Multi-Auth Plugin](https://apisix.apache.org/docs/apisix/plugins/multi-auth/)

## Next Steps

1. ✅ Review and understand the architecture
2. ✅ Set authentication keys, or use the ones Ansible generates
3. ✅ Configure secrets in ansible vault
4. ✅ Deploy APISIX using one of the deployment methods
5. ✅ Verify deployment using verification script
6. ✅ Test API access with curl examples
7. ✅ Configure firewall rules
8. ✅ Set up monitoring in Grafana
9. ✅ Implement rate limiting and IP whitelisting (optional)
10. ✅ Enable HTTPS for production (recommended)

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review APISIX logs
3. Verify configuration in templates
4. Test with verification script
5. Consult Apache APISIX documentation

---

**Created**: 2025-11-29  
**Updated**: 2026-10-28 (standalone mode, key-auth)  
**Version**: 1.0.0  
**Ansible Role**: ethereum-home-staking with APISIX integration

