# APISIX Deployment Summary

## What Has Been Created

An Ansible role for deploying Apache APISIX as an API Gateway with forward authentication for your Ethereum staking infrastructure.

### Files Created

#### Ansible Tasks & Templates
- **`tasks/apisix.yml`**: Main Ansible task file for deploying APISIX and etcd containers
- **`templates/apisix-config.yaml.j2`**: APISIX main configuration template
- **`templates/apisix-routes.yaml.j2`**: APISIX routes and forward-auth plugin configuration

#### Configuration Files
- **`defaults/main.yml`**: Updated with APISIX variables and defaults
- **`main.yml`**: Updated to include APISIX deployment task
- **`example.apisix-secrets.yml`**: Example secure credentials file
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
Client → APISIX Gateway (Port 9080) → Forward Auth → Upstream Services
                                                      ├─ Nethermind (8544)
                                                      └─ Lighthouse (5062)
```

### Components

1. **APISIX Gateway** (apache/apisix:3.14.1-debian)
   - Routes and authenticates requests
   - Enforces forward-auth plugin
   - Exports Prometheus metrics

2. **etcd** (bitnami/etcd:3.5.11)
   - Stores APISIX configuration
   - Maintains routing rules

3. **Auth Service** (Inline Lua)
   - Validates API keys and bearer tokens
   - Returns user metadata headers

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
| Admin API | Route management | 9180 |
| Metrics | Prometheus metrics | 9091 |

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

## Configuration Variables

### Required Variables (Set in secrets.yml or host_vars)

```yaml
# Security - MUST BE CHANGED!
apisix_admin_key: "your-secure-admin-key"
apisix_api_key: "your-secure-api-key"
apisix_bearer_token: "your-secure-bearer-token"

# Enable APISIX
apisix_enabled: true
```

### Optional Variables (defaults/main.yml)

```yaml
# Docker Images
apisix_image: "apache/apisix:3.14.1-debian"
apisix_etcd_image: "bitnami/etcd:3.5.11"

# Container Names
apisix_container_name: "eth-ansible-apisix"
apisix_etcd_container_name: "eth-ansible-apisix-etcd"

# Directories
apisix_config_dir: "/root/.eth-staking/config/apisix"
apisix_data_dir: "/data/apisix"

# Ports
apisix_gateway_port: 9080
apisix_admin_port: 9180
apisix_https_port: 9443
apisix_prometheus_port: 9091

# Auth Service
apisix_enable_auth_service: true
apisix_allow_degradation: false
```

## Deployment Steps

### 1. Generate Secure Keys

```bash
# Generate API Key
openssl rand -hex 32

# Generate Bearer Token
openssl rand -base64 32

# Generate Admin Key
openssl rand -hex 32

# How to generate all the keys quickly
echo "Generate these keys and add to host_vars/{{server_ip}}.yml:"; echo ""; echo "apisix_admin_key: \"$(openssl rand -hex 32)\""; echo "apisix_api_key: \"$(openssl rand -hex 32)\""; echo "apisix_bearer_token: \"$(openssl rand -base64 32)\""
```

### 2. Configure Secrets

Add to `secrets.yml` or `host_vars/<server>.yml`:

```yaml
apisix_enabled: true
apisix_admin_key: "<generated-admin-key>"
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
# Run verification script
./examples/verify-apisix.sh <server-ip> <api-key>

# Manual verification
curl http://<server>:9080/health
curl -H "X-API-Key: your-api-key" \
  http://<server>:9080/consensus/eth/v1/node/version
```

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

# Block direct access to upstream services
sudo ufw deny 5062/tcp  # Lighthouse
sudo ufw deny 8544/tcp  # Nethermind
```

### 2. Key Management

- ✅ Use strong, randomly generated keys
- ✅ Store keys in encrypted vault (ansible-vault)
- ✅ Rotate keys regularly
- ✅ Never commit keys to version control
- ✅ Use different keys per environment

### 3. Network Security

- ✅ Run containers in isolated Docker network
- ✅ Only expose APISIX gateway externally
- ✅ Keep Admin API (9180) internal only
- ✅ Use HTTPS in production with valid certificates

### 4. Monitoring

- ✅ Monitor APISIX metrics in Prometheus
- ✅ Set up alerts for authentication failures
- ✅ Track API usage patterns
- ✅ Review logs regularly

## Monitoring Integration

### Prometheus Metrics

APISIX exports metrics on port 9091:

```bash
curl http://server:9091/apisix/prometheus/metrics
```

### Key Metrics to Monitor

- `apisix_http_requests_total`: Total requests
- `apisix_http_latency_*`: Request latencies
- `apisix_http_status`: Status code distribution
- `apisix_upstream_status`: Upstream health
- `apisix_bandwidth`: Network traffic

### Grafana Integration

Add APISIX datasource to your existing Grafana:

```yaml
- name: APISIX
  type: prometheus
  url: http://eth-ansible-apisix:9091
  access: proxy
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
# Test auth service directly
curl -i -H "X-API-Key: your-key" http://server:9080/auth/validate
```

#### 3. Connection Refused
**Cause**: APISIX container not running  
**Solution**: Check container status

```bash
docker logs eth-ansible-apisix
docker restart eth-ansible-apisix
```

#### 4. etcd Connection Issues
**Cause**: etcd not ready or network issues  
**Solution**: Check etcd logs and restart

```bash
docker logs eth-ansible-apisix-etcd
docker restart eth-ansible-apisix-etcd
```

### Debugging Commands

```bash
# Check all APISIX containers
docker ps -a | grep apisix

# View APISIX logs
docker logs -f eth-ansible-apisix

# View etcd logs
docker logs -f eth-ansible-apisix-etcd

# Test network connectivity
docker exec eth-ansible-apisix ping eth-ansible-consensus-1
docker exec eth-ansible-apisix ping eth-ansible-execution-1

# List routes via Admin API
curl -H "X-API-KEY: your-admin-key" \
  http://server:9180/apisix/admin/routes
```

## Advanced Configuration

### Enable HTTPS

1. Generate SSL certificates
2. Mount certificates to APISIX container
3. Update `templates/apisix-config.yaml.j2`:

```yaml
apisix:
  ssl:
    enable: true
    ssl_protocols: "TLSv1.2 TLSv1.3"
```

### Add Rate Limiting

Update `templates/apisix-routes.yaml.j2`:

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

### etcd Optimization

- Increase memory limits for large deployments
- Configure snapshot policies
- Use etcd cluster for HA

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
- [Forward-Auth Plugin](https://apisix.apache.org/docs/apisix/plugins/forward-auth/)
- [APISIX Admin API](https://apisix.apache.org/docs/apisix/admin-api/)

## Next Steps

1. ✅ Review and understand the architecture
2. ✅ Generate secure authentication keys
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
**Version**: 1.0.0  
**Ansible Role**: ethereum-home-staking with APISIX integration

