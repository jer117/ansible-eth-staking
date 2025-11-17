# Teku Consensus Client Configuration

This guide explains how to use Teku as your consensus client with archive mode enabled.

## Overview

Teku is a Java-based Ethereum consensus client developed by Consensys. This configuration runs Teku in **archive mode**, which stores all historical states and is ideal for:

- Full historical state queries
- Block explorers and analytics
- Resolving validator state issues
- Complete blockchain data availability

## Quick Start

### 1. Enable Teku in Host Variables

In your `host_vars/<IP>.yml` or `secrets.yml`, add:

```yaml
consensus_client: "teku"
```

If not specified, it defaults to `lighthouse`.

### 2. Optional: Configure Teku Settings

In your host_vars file, you can override these defaults:

```yaml
# Teku JVM heap size - adjust based on your server's memory
teku_heap_size: "8g"  # Default: 4g, recommended 8g+ for archive nodes

# Teku logging level
teku_log_level: "INFO"  # Options: TRACE, DEBUG, INFO, WARN, ERROR
```

### 3. Run the Playbook

```bash
ansible-playbook -i inventory main.yml --tags consensus
```

Or run the full playbook:

```bash
ansible-playbook -i inventory main.yml
```

## Docker Image

- **AMD64**: `consensys/teku:25.11`
- **ARM64**: `consensys/teku:25.11-arm64`

The appropriate image is automatically selected based on your server's architecture.

## Teku Archive Mode Features

### Enabled Features:

1. **Archive Storage Mode** (`--data-storage-mode=archive`)
   - Stores all historical states
   - Required for full state queries at any slot

2. **Archive Frequency** (`--data-storage-archive-frequency=1024`)
   - Stores a state snapshot every 1024 slots (~3.4 hours)

3. **Historic State Reconstruction** (`--reconstruct-historic-states=true`)
   - Rebuilds historical states when needed
   - Helps with missing state data

4. **Checkpoint Sync**
   - Automatically configured based on network:
     - Mainnet: `https://mainnet.checkpoint.sigp.io`
     - Hoodi: `https://hoodi-checkpoint-sync.stakely.io`
     - Sepolia: `https://sepolia.checkpoint.sigp.io`
     - Gnosis: `https://checkpoint.gnosischain.com`

## Resource Requirements

### Archive Node Recommendations:

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM      | 16 GB   | 32 GB+      |
| Disk     | 1 TB    | 2 TB+ SSD   |
| CPU      | 4 cores | 8+ cores    |
| Heap     | 4 GB    | 8 GB        |

### Disk Space Growth:

- Archive nodes require significantly more disk space
- Gnosis: ~500 GB and growing
- Mainnet: ~2 TB and growing
- Monitor disk usage regularly

## Switching Between Lighthouse and Teku

### From Lighthouse to Teku:

1. Update your host_vars:
   ```yaml
   consensus_client: "teku"
   ```

2. Run the playbook:
   ```bash
   ansible-playbook -i inventory main.yml --tags consensus
   ```

3. The old Lighthouse container will be replaced with Teku

### From Teku to Lighthouse:

1. Update your host_vars:
   ```yaml
   consensus_client: "lighthouse"
   ```

2. Run the playbook:
   ```bash
   ansible-playbook -i inventory main.yml --tags consensus
   ```

## Monitoring

Teku exposes metrics on port `8081` (default consensus_monitoring_port):

- Metrics endpoint: `http://<server-ip>:8081/metrics`
- Compatible with Prometheus
- Grafana dashboards available

## API Endpoints

Teku REST API is available on port `5062` (default consensus_client_http_api_port):

- Base URL: `http://localhost:5062`
- Beacon API: `http://localhost:5062/eth/v1/beacon/...`
- Config API: `http://localhost:5062/eth/v1/config/...`

Full API documentation: https://consensys.github.io/teku/

## Troubleshooting

### Issue: High Memory Usage

**Solution**: Increase Java heap size in host_vars:
```yaml
teku_heap_size: "12g"  # Or higher based on available RAM
```

### Issue: State Not Found Errors (404)

This is normal during initial sync. Teku needs time to:
1. Download the initial checkpoint state
2. Reconstruct historical states
3. Build the archive

**Monitor logs**:
```bash
docker logs -f eth-ansible-consensus-1
```

Look for:
- "State reconstruction in progress"
- Progress updates on slot processing

### Issue: Slow Sync

Archive mode is slower than pruned mode because:
- All states must be stored
- More disk I/O required
- More CPU for state reconstruction

**Solutions**:
- Ensure SSD storage
- Increase heap size
- Monitor disk I/O (`iostat -x 1`)

### Issue: Validator Can't Access State

If your validator shows:
```
WARN Error processing HTTP API request status: 404 Not Found, path: /eth/v1/beacon/states/...
```

**This is expected** during initial sync. Wait for:
- State reconstruction to complete
- Beacon node to sync to current slot
- Historical states to be rebuilt

## Networks Supported

- `mainnet` - Ethereum Mainnet
- `gnosis` - Gnosis Chain
- `hoodi` - Hoodi Testnet
- `sepolia` - Sepolia Testnet

Checkpoint sync URLs are automatically configured per network.

## Logs and Debugging

### View Teku logs:
```bash
docker logs -f eth-ansible-consensus-1
```

### Increase verbosity:
```yaml
teku_log_level: "DEBUG"  # In host_vars
```

### Check Teku version:
```bash
docker exec eth-ansible-consensus-1 teku --version
```

## Performance Tuning

### For Better Performance:

1. **Increase heap size** (more RAM):
   ```yaml
   teku_heap_size: "16g"
   ```

2. **Use NVMe SSD** for data directory:
   - Fast random reads/writes critical for archive mode

3. **Increase peer count**:
   ```yaml
   consensus_target_peers: 150
   ```

4. **Monitor Java GC**:
   - Add to JVM options if needed:
   ```yaml
   teku_java_opts: "-Xmx8g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
   ```

## Additional Resources

- Teku Documentation: https://docs.teku.consensys.net/
- Teku GitHub: https://github.com/ConsenSys/teku
- Ethereum Beacon Chain: https://beaconcha.in/

## Example Configuration

### Full host_vars example with Teku:

```yaml
# Server Info
server_name: "my-archive-node"
IP: 192.168.1.100
network: "gnosis"

# Consensus Client
consensus_client: "teku"
teku_heap_size: "12g"
teku_log_level: "INFO"

# Execution Client
# (your existing nethermind config)

# Validator
withdrawal_account_address: "0xYourWithdrawalAddress"
validator_client: "lodestar"

# Monitoring
cadvisor_enabled: true
```

## Notes

- Teku archive mode stores **all historical states**, requiring significant disk space
- Initial sync can take several days depending on network
- Archive nodes are heavier but provide complete historical data
- Switching between Lighthouse and Teku is seamless - just change the variable

