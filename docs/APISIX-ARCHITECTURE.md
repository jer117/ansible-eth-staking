# APISIX Architecture for Ethereum Staking

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          External Clients                           │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │
│  │  Web3 Wallet │  │  RPC Client  │  │  Monitoring  │            │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘            │
│         │                 │                 │                      │
└─────────┼─────────────────┼─────────────────┼──────────────────────┘
          │                 │                 │
          │   API Key or Bearer Token         │
          │                 │                 │
          ▼                 ▼                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         APISIX API Gateway                          │
│                         (Port 9080/9443)                            │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                    Route Configuration                        │ │
│  │                                                               │ │
│  │  /execution/*  → Nethermind (8544)                           │ │
│  │  /consensus/*  → Lighthouse (5062)                           │ │
│  │  /health       → Health Check (no auth)                      │ │
│  │  /auth/validate → Auth Service                               │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                    Forward Auth Plugin                        │ │
│  │                                                               │ │
│  │  1. Extract API Key or Bearer Token                          │ │
│  │  2. Forward to Auth Service                                  │ │
│  │  3. Validate response (200 = OK, 401 = Denied)              │ │
│  │  4. Add user headers to upstream request                     │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                      Other Plugins                            │ │
│  │                                                               │ │
│  │  • proxy-rewrite: Strip /execution, /consensus prefixes      │ │
│  │  • prometheus: Export metrics on port 9091                   │ │
│  │  • serverless: Inline Lua functions for auth logic           │ │
│  └───────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │  Validated Request
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
│                  (Mainnet/Holesky/Sepolia)              │
└──────────────────────────────────────────────────────────┘
```

## Authentication Flow

```
┌──────────┐                 ┌──────────┐                 ┌──────────┐
│  Client  │                 │  APISIX  │                 │   Auth   │
│          │                 │ Gateway  │                 │ Service  │
└────┬─────┘                 └────┬─────┘                 └────┬─────┘
     │                            │                            │
     │  GET /consensus/version    │                            │
     │  X-API-Key: abc123         │                            │
     ├───────────────────────────►│                            │
     │                            │                            │
     │                            │  GET /auth/validate        │
     │                            │  X-API-Key: abc123         │
     │                            ├───────────────────────────►│
     │                            │                            │
     │                            │                            │ Validate
     │                            │                            │ API Key
     │                            │                            │
     │                            │  200 OK                    │
     │                            │  X-User-ID: api-user       │
     │                            │◄───────────────────────────┤
     │                            │                            │
     │                            │                            │
     │      Forward to Upstream   │                            │
     │                            │                            │
     │              ┌─────────────┴─────────────┐              │
     │              │                           │              │
     │              ▼                           ▼              │
     │    ┌──────────────┐            ┌──────────────┐        │
     │    │ Lighthouse   │            │ Nethermind   │        │
     │    │    :5062     │            │    :8544     │        │
     │    └──────┬───────┘            └──────┬───────┘        │
     │           │                           │                │
     │           │  200 OK + Data            │                │
     │           │◄──────────┘               │                │
     │                                       │                │
     │  200 OK + Data                        │                │
     │◄──────────────────────────────────────┘                │
     │                                                         │
```

### Failed Authentication Flow

```
┌──────────┐                 ┌──────────┐                 ┌──────────┐
│  Client  │                 │  APISIX  │                 │   Auth   │
│          │                 │ Gateway  │                 │ Service  │
└────┬─────┘                 └────┬─────┘                 └────┬─────┘
     │                            │                            │
     │  GET /consensus/version    │                            │
     │  (no auth header)          │                            │
     ├───────────────────────────►│                            │
     │                            │                            │
     │                            │  GET /auth/validate        │
     │                            │  (no auth header)          │
     │                            ├───────────────────────────►│
     │                            │                            │
     │                            │                            │ Validate
     │                            │                            │ (Failed)
     │                            │                            │
     │                            │  401 Unauthorized          │
     │                            │  WWW-Authenticate: Bearer  │
     │                            │◄───────────────────────────┤
     │                            │                            │
     │  401 Unauthorized          │                            │
     │  WWW-Authenticate: Bearer  │                            │
     │◄───────────────────────────┤                            │
     │                            │                            │
```

## Component Details

### APISIX Gateway
- **Image**: apache/apisix:3.14.1-debian
- **Ports**:
  - 9080: HTTP Gateway
  - 9443: HTTPS Gateway
  - 9180: Admin API
  - 9091: Prometheus Metrics
- **Purpose**: Route requests, enforce authentication, collect metrics

### etcd
- **Image**: bitnami/etcd:3.5.11
- **Port**: 2379
- **Purpose**: Store APISIX configuration and routing rules

### Auth Service
- **Implementation**: APISIX serverless-pre-function plugin
- **Location**: Inline Lua function in route configuration
- **Purpose**: Validate API keys and bearer tokens

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
3. **Forward Auth**: APISIX calls auth service with credentials
4. **Validation**: Auth service validates API key/bearer token
5. **Header Injection**: Auth service adds user headers (e.g., X-User-ID)
6. **Proxy Rewrite**: APISIX strips route prefix (/execution or /consensus)
7. **Upstream Forward**: Request sent to Nethermind or Lighthouse
8. **Response**: Upstream response returned to client
9. **Metrics**: Prometheus plugin records request metrics

## Security Layers

```
┌────────────────────────────────────────┐
│  Layer 1: Network Firewall (UFW)       │
│  • Only expose ports 9080/9443         │
│  • Block direct access to 5062, 8544   │
└────────────────────────────────────────┘
                  │
┌────────────────────────────────────────┐
│  Layer 2: APISIX Forward Auth          │
│  • API Key validation                  │
│  • Bearer token validation             │
│  • Reject unauthorized requests        │
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
2. Calls auth service with X-API-Key: abc123
3. Auth returns 200 OK
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
2. Calls auth service with Authorization: Bearer xyz789
3. Auth returns 200 OK
4. Rewrites path from /consensus/... to /eth/v1/node/version
5. Forwards to eth-ansible-consensus-1:5062/eth/v1/node/version
6. Lighthouse returns version info
7. APISIX returns response to client
```

## Monitoring and Observability

### Prometheus Metrics

Available at: `http://server:9091/apisix/prometheus/metrics`

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

# etcd logs
docker logs -f eth-ansible-apisix-etcd
```

## High Availability Considerations

For production deployments, consider:

1. **Multiple APISIX Instances**: Run behind a load balancer
2. **etcd Cluster**: Use 3-node etcd cluster for redundancy
3. **Rate Limiting**: Add rate limiting plugin to prevent abuse
4. **Circuit Breaker**: Add circuit breaker for upstream failures
5. **SSL/TLS**: Enable HTTPS with proper certificates
6. **IP Whitelisting**: Restrict access to known IPs

## References

- [APISIX Documentation](https://apisix.apache.org/docs/apisix/)
- [Forward-Auth Plugin](https://apisix.apache.org/docs/apisix/plugins/forward-auth/)
- [Prometheus Plugin](https://apisix.apache.org/docs/apisix/plugins/prometheus/)
- [Proxy-Rewrite Plugin](https://apisix.apache.org/docs/apisix/plugins/proxy-rewrite/)

