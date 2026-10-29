# APISIX Architecture for Ethereum Staking

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          External Clients                           │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐               │
│  │  Web3 Wallet │  │  RPC Client  │  │  Monitoring  │               │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘               │
│         │                 │                 │                       │
└─────────┼─────────────────┼─────────────────┼───────────────────────┘
          │                 │                 │
          │   API Key or Bearer Token         │
          │                 │                 │
          ▼                 ▼                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         APISIX API Gateway                          │
│                  (Port 9080/9443, standalone mode)                  │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                      Route Configuration                      │  │
│  │                                                               │  │
│  │  /execution/*      → Nethermind (8544)       auth             │  │
│  │  /consensus/*      → Lighthouse (5062)       auth             │  │
│  │  /health           → Lighthouse health       no auth          │  │
│  │  /execution-health → Nethermind health       no auth          │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │            Authentication (multi-auth + key-auth)             │  │
│  │                                                               │  │
│  │  1. Read the X-API-Key or Authorization header                │  │
│  │  2. Match it exactly against the consumers in apisix.yaml     │  │
│  │  3. No match → 401 Unauthorized, request not forwarded        │  │
│  │  4. Remove the credential, add X-Consumer-Username            │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                         Other Plugins                         │  │
│  │                                                               │  │
│  │  • proxy-rewrite: Strip /execution, /consensus prefixes;      │  │
│  │    set Content-Type on /execution-health                      │  │
│  │  • prometheus: Export metrics on port 9091 (Docker network)   │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  Config: conf/config.yaml + conf/apisix.yaml, rendered by Ansible   │
│  and mounted read-only (no etcd, no Admin API)                      │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │  Authenticated request (credential removed)
                              │
          ┌───────────────────┴───────────────────┐
          │                                       │
          ▼                                       ▼
┌──────────────────────┐              ┌──────────────────────┐
│  Nethermind (8544)   │              │ Lighthouse (5062)    │
│  Execution Client    │              │ Consensus Client     │
│                      │              │                      │
│  • eth_blockNumber   │              │ • /eth/v1/node/*     │
│  • eth_syncing       │              │ • /eth/v1/beacon/*   │
│  • eth_getBalance    │              │ • /eth/v1/validator/*│
│  • net_peerCount     │              │                      │
└──────────────────────┘              └──────────────────────┘
          │                                       │
          │                                       │
          ▼                                       ▼
┌──────────────────────────────────────────────────────────┐
│                    Ethereum Network                      │
│                 (Mainnet/Holesky/Sepolia)                │
└──────────────────────────────────────────────────────────┘
```

## Authentication Flow

```
┌──────────┐                      ┌────────────────┐             ┌──────────────┐
│  Client  │                      │ APISIX Gateway │             │  Lighthouse  │
│          │                      │   (key-auth)   │             │    :5062     │
└────┬─────┘                      └───────┬────────┘             └──────┬───────┘
     │                                    │                             │
     │ GET /consensus/eth/v1/node/version │                             │
     │ X-API-Key: abc123                  │                             │
     ├───────────────────────────────────►│                             │
     │                                    │                             │
     │                                    │ key-auth: key matches       │
     │                                    │ consumer api_key_client     │
     │                                    │ remove X-API-Key,           │
     │                                    │ add X-Consumer-Username,    │
     │                                    │ strip /consensus prefix     │
     │                                    │                             │
     │                                    │  GET /eth/v1/node/version   │
     │                                    ├────────────────────────────►│
     │                                    │                             │
     │                                    │  200 OK + Data              │
     │                                    │◄────────────────────────────┤
     │                                    │                             │
     │ 200 OK + Data                      │                             │
     │◄───────────────────────────────────┤                             │
     │                                    │                             │
```

With `Authorization: Bearer <token>` the flow is the same; the key matched is the whole header value (`Bearer <token>`) and the consumer is `bearer_token_client`.

### Failed Authentication Flow

```
┌──────────┐                      ┌────────────────┐
│  Client  │                      │ APISIX Gateway │
│          │                      │   (key-auth)   │
└────┬─────┘                      └───────┬────────┘
     │                                    │
     │ GET /consensus/eth/v1/node/version │
     │ (no or wrong credentials)          │
     ├───────────────────────────────────►│
     │                                    │
     │                                    │ no matching consumer:
     │                                    │ request is not forwarded
     │                                    │
     │ 401 Unauthorized                   │
     │◄───────────────────────────────────┤
     │                                    │
```

## Component Details

### APISIX Gateway
- **Image**: apache/apisix:3.19.0-debian
- **Mode**: file-driven standalone (`deployment.role: data_plane`, `config_provider: yaml`)
- **Ports**:
  - 9080: HTTP Gateway (published)
  - 9443: HTTPS Gateway (published)
  - 9091: Prometheus Metrics (Docker network only, not published)
- **Configuration**: `config.yaml` and `apisix.yaml` in `/root/.eth-staking/config/apisix/apisix/`, rendered by Ansible and mounted read-only. There is no etcd and no Admin API; changes are made by editing vars/templates and re-running Ansible.
- **Purpose**: Route requests, enforce authentication, collect metrics

### Authentication (key-auth)
- **Implementation**: APISIX's built-in `key-auth` plugin, wrapped in `multi-auth` so that either of two headers is accepted
- **Attached to**: `/execution/*` and `/consensus/*`, through the shared plugin config `client-auth`
- **Consumers** (defined in `apisix.yaml`):
  - `api_key_client`: key = `apisix_api_key`, sent as `X-API-Key: <key>`
  - `bearer_token_client`: key = `Bearer ` + `apisix_bearer_token`, sent as `Authorization: Bearer <token>`
- **Credentials**: from host_vars/secrets, or generated by Ansible into `credentials/<inventory_hostname>/apisix/` on the control machine. The rendered `apisix.yaml` is owned by root, group 636 (the container's `apisix` user), mode 0640.
- **Behaviour**: unauthenticated requests get 401; with `hide_credentials: true` the credential is removed before proxying; the upstream receives `X-Consumer-Username`. `key-auth` also accepts the API key in an `apikey` query parameter, but headers are preferred because URLs get logged.

### Upstream Services

#### Nethermind (Execution Client)
- **Container**: eth-ansible-execution-1
- **Port**: 8544 (JSON-RPC)
- **Accessible via**: http://server:9080/execution/*

#### Lighthouse (Consensus Client)
- **Container**: eth-ansible-consensus-1
- **Port**: 5062 (HTTP API)
- **Accessible via**: http://server:9080/consensus/*

## Request Processing Flow

1. **Client Request**: Client sends request with authentication header
2. **Route Matching**: APISIX matches request to configured route
3. **Authentication**: `multi-auth` runs `key-auth` on the `X-API-Key` header, then on the `Authorization` header; the value must exactly match a consumer's key
4. **Rejection**: If no consumer matches, APISIX returns 401 and the request goes no further
5. **Header Changes**: The credential header is removed and `X-Consumer-Username` is added
6. **Proxy Rewrite**: APISIX strips route prefix (/execution or /consensus)
7. **Upstream Forward**: Request sent to Nethermind or Lighthouse
8. **Response**: Upstream response returned to client
9. **Metrics**: Prometheus plugin records request metrics

## Security Layers

```
┌────────────────────────────────────────┐
│  Layer 1: Docker port bindings         │
│  • Only expose ports 9080/9443         │
│  • Docker port 5062 bound to 127.0.0.1 │
│  • 8544 still public (see note below)  │
└────────────────────────────────────────┘
                  │
┌────────────────────────────────────────┐
│  Layer 2: APISIX key-auth              │
│  • API Key validation                  │
│  • Bearer token validation             │
│  • Reject unauthorized requests (401)  │
└────────────────────────────────────────┘
                  │
┌────────────────────────────────────────┐
│  Layer 3: Docker Network Isolation     │
│  • Containers in eth-staking-network   │
│  • Internal communication only         │
└────────────────────────────────────────┘
                  │
┌────────────────────────────────────────┐
│  Layer 4: Upstream Services            │
│  • Nethermind and Lighthouse           │
│  • Not directly accessible externally  │
└────────────────────────────────────────┘
```

Layer 1 comes from the Docker port mappings in `vars/main.yml`, not from ufw. Docker publishes container ports with its own iptables rules, which run before ufw's, so `ufw deny` does not block a published port. The beacon API (5062) can't be reached from other machines because `beacon_published_ports` binds it to `127.0.0.1`.

Nethermind's JSON-RPC (8544) is still published on all interfaces by `eth_ansible_execution_1_docker_ports`, so it can be reached from outside the host whatever ufw is set to. To close it, prefix that mapping with `127.0.0.1:`. APISIX reaches Nethermind by container name over the Docker network, so the gateway keeps working.

## Data Flow Examples

### Example 1: Get Block Number (Execution Client)

```bash
# Client request
curl -H "X-API-Key: abc123" \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://server:9080/execution/

# APISIX processes:
1. Receives request to /execution/
2. key-auth matches X-API-Key: abc123 to consumer api_key_client
3. Removes X-API-Key, adds X-Consumer-Username: api_key_client
4. Rewrites path from /execution/ to /
5. Forwards to eth-ansible-execution-1:8544/
6. Nethermind returns: {"jsonrpc":"2.0","result":"0x123456","id":1}
7. APISIX returns response to client
```

### Example 2: Get Node Version (Consensus Client)

```bash
# Client request
curl -H "Authorization: Bearer xyz789" \
  http://server:9080/consensus/eth/v1/node/version

# APISIX processes:
1. Receives request to /consensus/eth/v1/node/version
2. key-auth matches "Bearer xyz789" to consumer bearer_token_client
3. Removes Authorization, adds X-Consumer-Username: bearer_token_client
4. Rewrites path from /consensus/... to /eth/v1/node/version
5. Forwards to eth-ansible-consensus-1:5062/eth/v1/node/version
6. Lighthouse returns version info
7. APISIX returns response to client
```

## Monitoring and Observability

### Prometheus Metrics

Available at `http://eth-ansible-apisix:9091/apisix/prometheus/metrics` from containers on `eth-staking-network-net` (for example the Prometheus container); port 9091 is not published on the host.

Key metrics:
- `apisix_http_requests_total`: Total HTTP requests
- `apisix_http_latency_*`: Request latency histograms
- `apisix_http_status`: HTTP status code counts
- `apisix_bandwidth`: Ingress/egress bandwidth
- `apisix_upstream_status`: Upstream service health

### Logs

```bash
# APISIX logs
docker logs -f eth-ansible-apisix

# Errors loading apisix.yaml (every route returns 404 when it is not loaded)
docker logs eth-ansible-apisix 2>&1 | grep config_yaml
```

## High Availability Considerations

For production deployments, consider:

1. **Multiple APISIX Instances**: Run behind a load balancer. In standalone mode each instance reads its own `apisix.yaml`, so Ansible keeps them in sync; no etcd cluster is needed
2. **Rate Limiting**: Add rate limiting plugin to prevent abuse
3. **Circuit Breaker**: Add circuit breaker for upstream failures
4. **SSL/TLS**: Enable HTTPS with proper certificates
5. **IP Whitelisting**: Restrict access to known IPs

## References

- [APISIX Documentation](https://apisix.apache.org/docs/apisix/)
- [Standalone Mode](https://apisix.apache.org/docs/apisix/deployment-modes/#standalone)
- [Key-Auth Plugin](https://apisix.apache.org/docs/apisix/plugins/key-auth/)
- [Multi-Auth Plugin](https://apisix.apache.org/docs/apisix/plugins/multi-auth/)
- [Prometheus Plugin](https://apisix.apache.org/docs/apisix/plugins/prometheus/)
- [Proxy-Rewrite Plugin](https://apisix.apache.org/docs/apisix/plugins/proxy-rewrite/)

