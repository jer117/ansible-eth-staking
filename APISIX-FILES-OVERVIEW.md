# APISIX Implementation - Files Overview

## Complete List of Created/Modified Files

### Core Ansible Implementation

#### 1. `tasks/apisix.yml` (NEW)
**Purpose**: Main Ansible task file for deploying APISIX  
**Contains**:
- Client credential resolution (from vars, or generated with Ansible's `password` lookup)
- Placeholder check (fails on short or `changeme` / `change-this` credentials)
- Directory creation for APISIX configs
- Config file rendering
- Docker image pull and container deployment
- Health check waits

**Key Tasks**:
- Use `apisix_api_key` / `apisix_bearer_token`, or generate them into `credentials/<inventory_hostname>/apisix/` on the control machine
- Create config directories
- Render `config.yaml` and `apisix.yaml` (`apisix.yaml` holds the credentials: owner root, group 636, mode 0640)
- Remove the `eth-ansible-apisix-etcd` container left by earlier versions
- Deploy APISIX gateway container (ports 9080 and 9443)

---

#### 2. `templates/apisix-config.yaml.j2` (NEW)
**Purpose**: APISIX main configuration template  
**Contains**:
- APISIX node listener configuration
- Standalone mode (`deployment.role: data_plane`, `config_provider: yaml`); no etcd, no Admin API
- Error log settings
- Prometheus metrics configuration (port 9091)

**Variables Used**:
- `{{ apisix_enable_ipv6 }}` (optional, default `true`)

---

#### 3. `templates/apisix-routes.yaml.j2` (NEW)
**Purpose**: APISIX standalone configuration (`conf/apisix.yaml`): routes, consumers and authentication  
**Contains**:
- Consumers `api_key_client` (key-auth key = `apisix_api_key`) and `bearer_token_client` (key = `Bearer ` + `apisix_bearer_token`)
- Plugin config `client-auth`: `multi-auth` with two `key-auth` entries (`X-API-Key` and `Authorization` headers, `hide_credentials: true`)
- Route definitions for /execution/* and /consensus/* (using `client-auth`)
- Proxy-rewrite rules
- Health check endpoints
- `#END` marker, which APISIX requires at the end of the file

**Routes Configured**:
- `execution-rpc`: Nethermind JSON-RPC endpoint
- `consensus-api`: Lighthouse HTTP API endpoint
- `health`: Consensus health check (no auth)
- `execution-health`: Execution health check (no auth)

**Variables Used**:
- `{{ execution_docker_container_name }}`
- `{{ consensus_docker_container_name }}`
- `{{ eth_ansible_execution_1_rpc_port }}`
- `{{ consensus_client_http_api_port }}`
- `{{ apisix_api_key_resolved }}` / `{{ apisix_bearer_token_resolved }}` (set by `tasks/apisix.yml` from `apisix_api_key` / `apisix_bearer_token` or the generated values)

---

### Configuration Files

#### 4. `defaults/main.yml` (MODIFIED)
**Purpose**: Default variables for APISIX  
**Added Variables**:
```yaml
# APISIX API Gateway Vars
apisix_enabled: true
apisix_image: "apache/apisix:3.19.0-debian"
apisix_container_name: "eth-ansible-apisix"
# etcd is no longer used (APISIX runs in standalone mode); the old container is removed on deploy.
apisix_etcd_container_name: "eth-ansible-apisix-etcd"
apisix_config_dir: "/root/.eth-staking/config/apisix"

# APISIX Ports
apisix_gateway_port: 9080
apisix_https_port: 9443
apisix_prometheus_port: 9091
```

`apisix_api_key` and `apisix_bearer_token` are deliberately not defined here: `defaults/main.yml` is loaded with `include_vars`, which would override host_vars. Set them in host_vars/secrets, or leave them unset to have them generated.

---

#### 5. `main.yml` (MODIFIED)
**Purpose**: Main playbook orchestration  
**Changes**:
- Added APISIX task import
- Added "Restart APISIX" handler

**New Task**:
```yaml
- name: Import APISIX API Gateway
  ansible.builtin.import_tasks: tasks/apisix.yml
  when: apisix_enabled | default(false)
  tags: [apisix]
```

**New Handler**:
```yaml
- name: Restart APISIX
  become: true
  community.docker.docker_container:
    name: "{{ apisix_container_name }}"
    state: started
    restart: true
```

---

#### 6. `example.apisix-secrets.yml` (NEW)
**Purpose**: Example secrets file template  
**Contains**: Commented-out, optional entries for:
- `apisix_api_key`
- `apisix_bearer_token`

**Usage**: Copy the entries to secrets.yml and set real values, or leave them unset to have Ansible generate them

---

#### 7. `example.env.apisix` (NEW)
**Purpose**: Environment variables example  
**Contains**: Example environment configuration for APISIX deployment

---

### Playbooks

#### 8. `playbooks/apisix-only.yml` (NEW)
**Purpose**: Standalone playbook for deploying only APISIX  
**Use Case**: Deploy/update APISIX without touching other components  
**Features**:
- Load default, main and host variables
- Deploy APISIX
- Display post-deployment information, including where the generated credentials are stored

**Usage**:
```bash
ansible-playbook -i inventory playbooks/apisix-only.yml
```

---

### Documentation

#### 9. `README-APISIX.md` (NEW)
**Purpose**: Complete APISIX implementation guide  
**Sections**:
- Overview and architecture
- Endpoints documentation
- Configuration guide
- Security configuration
- Authentication methods
- Deployment instructions
- Monitoring setup
- Troubleshooting
- Advanced configuration

**Size**: ~500 lines, comprehensive reference

---

#### 10. `QUICKSTART-APISIX.md` (NEW)
**Purpose**: Quick start deployment guide  
**Sections**:
- 12-step quick deployment process
- Common endpoints reference
- Network diagram
- Security best practices
- Quick troubleshooting

**Size**: ~300 lines, focused on rapid deployment

---

#### 11. `docs/APISIX-ARCHITECTURE.md` (NEW)
**Purpose**: Detailed architecture documentation  
**Sections**:
- System architecture diagrams
- Authentication flow diagrams
- Component details
- Request processing flow
- Security layers
- Data flow examples
- Monitoring and observability
- High availability considerations

**Size**: ~600 lines, deep technical documentation

---

#### 12. `APISIX-DEPLOYMENT-SUMMARY.md` (NEW)
**Purpose**: Comprehensive deployment summary  
**Sections**:
- Complete file listing
- Architecture overview
- Configuration variables
- Deployment steps
- Usage examples
- Security best practices
- Monitoring integration
- Troubleshooting guide
- Advanced configuration
- Resources and next steps

**Size**: ~700 lines, complete reference

---

#### 13. `APISIX-QUICK-REFERENCE.md` (NEW)
**Purpose**: Quick reference card for operations  
**Sections**:
- Command quick reference
- curl examples
- Docker commands
- Metrics access
- Ports reference
- Troubleshooting checks
- Emergency commands

**Size**: ~250 lines, quick lookup

---

#### 14. `README.md` (MODIFIED)
**Purpose**: Main project README  
**Changes**:
- Added APISIX to key features
- Added APISIX firewall rules
- Added APISIX API Gateway section with setup and usage
- Added links to APISIX documentation

---

### Scripts and Examples

#### 15. `examples/apisix-usage.sh` (NEW)
**Purpose**: Collection of working curl examples  
**Contains**: 15 example API calls demonstrating:
- Health checks (no auth)
- Consensus API calls (with auth)
- Execution API calls (with auth)
- Metrics access
- Error scenarios

**Usage**:
```bash
./examples/apisix-usage.sh <SERVER_IP> <API_KEY> <BEARER_TOKEN>
```

---

#### 16. `examples/verify-apisix.sh` (NEW)
**Purpose**: Automated deployment verification  
**Contains**: 8 automated tests:
1. APISIX container running check
2. Health endpoint test (no auth)
3. Execution health test (no auth)
4. Authentication protection test (expects 401)
5. Authenticated access test (if key provided)
6. Wrong API key rejected test (if key provided)
7. Execution client access test (if key provided)
8. Prometheus metrics test (inside the container; port 9091 is not published)

**Usage**:
```bash
./examples/verify-apisix.sh <SERVER_IP> [API_KEY]
```

**Output**: Colored pass/fail results with summary

---

## File Relationships

### Template → Configuration Flow
```
templates/apisix-config.yaml.j2
    ↓ (rendered with vars from defaults/main.yml)
→ /root/.eth-staking/config/apisix/apisix/config.yaml
    ↓ (mounted to container)
→ APISIX container: /usr/local/apisix/conf/config.yaml
```

```
templates/apisix-routes.yaml.j2
    ↓ (rendered with vars and the resolved credentials)
→ /root/.eth-staking/config/apisix/apisix/apisix.yaml   (root:636, mode 0640)
    ↓ (mounted to container)
→ APISIX container: /usr/local/apisix/conf/apisix.yaml
```

```
apisix_api_key / apisix_bearer_token (host_vars or secrets.yml)
    or, if unset, credentials/<inventory_hostname>/apisix/{api_key,bearer_token}
    (generated on the control machine, gitignored)
    ↓ (tasks/apisix.yml)
→ consumers in apisix.yaml
```

### Deployment Flow
```
main.yml
    ↓ (includes when apisix_enabled)
tasks/apisix.yml
    ↓ (uses templates)
templates/apisix-*.j2
    ↓ (reads variables)
defaults/main.yml + vars/main.yml + host_vars/secrets.yml
```

### Documentation Hierarchy
```
README.md (overview + quick setup)
    ├── QUICKSTART-APISIX.md (step-by-step deployment)
    ├── README-APISIX.md (complete implementation guide)
    ├── APISIX-DEPLOYMENT-SUMMARY.md (comprehensive summary)
    ├── APISIX-QUICK-REFERENCE.md (operations reference)
    └── docs/APISIX-ARCHITECTURE.md (technical deep dive)
```

## Variable Dependencies

### Credential Variables (optional; generated if unset)
```yaml
apisix_api_key          # Used in: templates/apisix-routes.yaml.j2 (via apisix_api_key_resolved)
apisix_bearer_token     # Used in: templates/apisix-routes.yaml.j2 (via apisix_bearer_token_resolved)
```

### Container Name Variables (Used across templates)
```yaml
execution_docker_container_name    # From: defaults/main.yml
consensus_docker_container_name    # From: defaults/main.yml
apisix_container_name              # From: defaults/main.yml
apisix_etcd_container_name         # From: defaults/main.yml (only used to remove the old etcd container)
```

### Port Variables (Used in routing)
```yaml
eth_ansible_execution_1_rpc_port   # From: vars/main.yml
consensus_client_http_api_port     # From: vars/main.yml
apisix_gateway_port                # From: defaults/main.yml
apisix_https_port                  # From: defaults/main.yml
```

## Integration Points

### With Existing Ansible Role
- **Docker Network**: Uses existing `eth-staking-network-net`
- **Monitoring**: Exposes metrics that the existing Prometheus can scrape (same Docker network)
- **Container Naming**: Follows existing `eth-ansible-*` convention
- **Directory Structure**: Uses existing `.eth-staking/config` pattern

### With Upstream Services
- **Nethermind**: Forwards to `eth-ansible-execution-1:8544`
- **Lighthouse**: Forwards to `eth-ansible-consensus-1:5062`
- **Network**: All containers communicate via bridge network

### With Monitoring Stack
- **Prometheus**: Metrics on port 9091 (Docker network only; add a scrape job for `eth-ansible-apisix:9091`)
- **Grafana**: Can add APISIX as datasource
- **Alerts**: Can integrate APISIX metrics into alerting

## Maintenance Files

### For Daily Operations
- `APISIX-QUICK-REFERENCE.md` - Quick command lookup
- `examples/verify-apisix.sh` - Health verification
- `examples/apisix-usage.sh` - Usage examples

### For Configuration Changes
- `templates/apisix-routes.yaml.j2` - Route modifications
- `templates/apisix-config.yaml.j2` - APISIX settings
- `defaults/main.yml` - Default values

### For Troubleshooting
- `README-APISIX.md` - Troubleshooting section
- `APISIX-DEPLOYMENT-SUMMARY.md` - Common issues
- `docs/APISIX-ARCHITECTURE.md` - Understanding flow

### For New Deployments
- `QUICKSTART-APISIX.md` - First time setup
- `example.apisix-secrets.yml` - Security template
- `playbooks/apisix-only.yml` - Standalone deployment

## Total Files Summary

| Category | New Files | Modified Files | Total |
|----------|-----------|----------------|-------|
| Ansible Tasks | 1 | 0 | 1 |
| Templates | 2 | 0 | 2 |
| Configuration | 2 | 2 | 4 |
| Playbooks | 1 | 0 | 1 |
| Documentation | 5 | 1 | 6 |
| Scripts | 2 | 0 | 2 |
| **TOTAL** | **13** | **3** | **16** |

---

**Created**: 2025-11-29  
**Purpose**: APISIX gateway with key-auth for Ethereum staking infrastructure  
**Status**: Complete and ready for deployment

