# Teku Consensus Client Implementation Summary

## What Was Added

This implementation adds Teku as an alternative consensus client alongside Lighthouse, with full archive node support.

## Files Created

1. **`tasks/teku.yml`** - Ansible tasks to deploy Teku beacon node
2. **`TEKU-CONSENSUS.md`** - Complete documentation for using Teku
3. **`TEKU-IMPLEMENTATION-SUMMARY.md`** - This file

## Files Modified

1. **`defaults/main.yml`**
   - Added Teku image variables for AMD64 and ARM64
   - Added `consensus_client` variable (lighthouse/teku)
   - Added `teku_heap_size` and `teku_log_level` variables

2. **`main.yml`**
   - Added Teku image to architecture detection
   - Added conditional import for Lighthouse vs Teku tasks
   - Updated debug output to show consensus client selection

3. **`vars/main.yml`**
   - Added Teku-specific configuration variables

4. **`example.secrets.yml`**
   - Added `consensus_client` option with documentation

5. **`host_vars/103.214.23.21.yml`**
   - Added commented consensus_client example

## How to Use

### Enable Teku on a Host

Add to your `host_vars/<IP>.yml` or `secrets.yml`:

```yaml
consensus_client: "teku"
```

### Optional Configuration

```yaml
# Override defaults if needed
teku_heap_size: "8g"        # JVM heap size (default: 4g)
teku_log_level: "INFO"      # Log level (default: INFO)
```

### Deploy

```bash
# Deploy only consensus client
ansible-playbook -i inventory main.yml --tags consensus

# Or deploy full stack
ansible-playbook -i inventory main.yml
```

## Key Features

### Archive Node Configuration

Teku is configured as an **archive node** with:

- `--data-storage-mode=archive` - Store all historical states
- `--data-storage-archive-frequency=1024` - Archive every 1024 slots
- `--reconstruct-historic-states=true` - Rebuild missing states
- Network-specific checkpoint sync URLs

### Automatic Configuration

- **Architecture Detection**: Automatically selects ARM64 or AMD64 image
- **Network Detection**: Auto-configures checkpoint sync for:
  - mainnet
  - gnosis
  - hoodi
  - sepolia
- **JWT Token**: Shared with execution client for authentication
- **Metrics & API**: Prometheus metrics and REST API enabled

### Resource Allocation

- JVM heap size configurable (default 4GB, recommended 8GB+)
- Archive mode requires significant disk space:
  - Gnosis: ~500 GB+
  - Mainnet: ~2 TB+

## Technical Details

### Docker Container

- **Name**: `eth-ansible-consensus-1` (same as Lighthouse for easy switching)
- **Network**: `eth-staking-network-net` (bridge mode)
- **Image**: `consensys/teku:25.11-arm64` (or amd64)

### Exposed Ports

- `5062` - REST API (Beacon API)
- `8081` - Prometheus metrics
- `9000` - P2P TCP
- `9001` - P2P QUIC (if configured)

### Volumes Mounted

- `/data` - Blockchain data (archive storage)
- `/config` - Configuration files
- `/exec_token` - JWT token for execution client auth

### Environment Variables

- `JAVA_OPTS`: Set to `-Xmx<heap_size>` for JVM memory

## Switching Between Clients

### Lighthouse → Teku

```yaml
# In host_vars/<IP>.yml
consensus_client: "teku"
```

```bash
ansible-playbook -i inventory main.yml --tags consensus
```

### Teku → Lighthouse

```yaml
# In host_vars/<IP>.yml
consensus_client: "lighthouse"
```

```bash
ansible-playbook -i inventory main.yml --tags consensus
```

The container name remains the same, so the switch is seamless.

## Default Behavior

If `consensus_client` is not specified, **Lighthouse** is used (maintains backward compatibility).

## Docker Images Used

| Architecture | Image |
|--------------|-------|
| AMD64 | `consensys/teku:25.11` |
| ARM64 | `consensys/teku:25.11-arm64` |

Images are automatically selected based on detected architecture.

## Monitoring

Both clients expose metrics on the same port (8081), making monitoring consistent:

- Prometheus scrapes: `http://<host>:8081/metrics`
- Existing Grafana dashboards should work with both clients

## Archive Mode Benefits

1. **Complete State History** - Query any historical state
2. **Validator State Recovery** - Resolve missed attestations/proposals
3. **Block Explorer Support** - Serve historical block/state data
4. **Debugging** - Full visibility into chain history

## Considerations

### Disk Space

- Archive mode requires significantly more disk space
- Plan for 2-3x growth over time
- Use SSD/NVMe for performance

### Sync Time

- Initial sync takes longer than pruned nodes
- State reconstruction can take hours to days
- Checkpoint sync helps but archive build-out still needed

### Memory

- Java-based client requires more RAM
- Heap size should be tuned based on workload
- Recommended: 16-32 GB total RAM for archive node

## Validation

After deployment, verify Teku is running:

```bash
# Check container
docker ps | grep eth-ansible-consensus-1

# Check logs
docker logs -f eth-ansible-consensus-1

# Check API
curl http://localhost:5062/eth/v1/node/version

# Check metrics
curl http://localhost:8081/metrics
```

## Support

- Full documentation: `TEKU-CONSENSUS.md`
- Teku docs: https://docs.teku.consensys.net/
- Consensus client selection is per-host via host_vars

## Examples

### Gnosis Archive Node

```yaml
# host_vars/192.168.1.100.yml
consensus_client: "teku"
network: "gnosis"
teku_heap_size: "12g"
withdrawal_account_address: "0xYourAddress"
```

### Hoodi Testnet with Teku

```yaml
# host_vars/192.168.1.101.yml
consensus_client: "teku"
network: "hoodi"
teku_heap_size: "8g"
teku_log_level: "DEBUG"
```

### Mainnet with Lighthouse (default)

```yaml
# host_vars/192.168.1.102.yml
# consensus_client: "lighthouse"  # Default, can be omitted
network: "mainnet"
```

## Migration Path

1. **Test on testnet first** (hoodi/sepolia)
2. **Ensure sufficient disk space** (2x current usage minimum)
3. **Update host_vars** with `consensus_client: "teku"`
4. **Run playbook** with `--tags consensus`
5. **Monitor sync progress** via logs
6. **Wait for full sync** before enabling validators

## Next Steps

- Test on a testnet environment
- Monitor resource usage (RAM, disk, CPU)
- Tune `teku_heap_size` based on workload
- Configure monitoring/alerting for archive node

