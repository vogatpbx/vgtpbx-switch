# Production Deployment Guide

## Prerequisites

- GCP VM: e2-small (1GB RAM) or larger
- Docker & Docker Compose installed
- FreeSWITCH SignalWire token (FS_TOKEN)
- Both images pushed to GCP Artifact Registry (see [GCP_ARTIFACT-DOCKER.md](GCP_ARTIFACT-DOCKER.md))

## Production Deployment

### 1. Deploy with docker-compose.prod.yml

```bash
# Set registry and version
export REGISTRY="northamerica-northeast1-docker.pkg.dev/dev-vgtpbx/vgtpbx-switch-docker"
export VERSION="v1.0.0"

# Deploy both containers
docker-compose -f docker-compose.prod.yml up -d

# Verify
docker-compose -f docker-compose.prod.yml ps
curl http://127.0.0.1:8081/health
docker exec vgtpbx-switch fs_cli -x "status"
```

### 2. Or Deploy via Cloud Function

The Cloud Function automatically provisions VMs with both containers. See [GCP_ARTIFACT-DOCKER.md](GCP_ARTIFACT-DOCKER.md) for setup.

## Security Configuration

**Before production:**

1. Change ESL password:
```bash
# In docker-compose.prod.yml and templates/conf/autoload_configs/event_socket.conf.xml
# Replace: ClueCon
# With: YourSecurePassword123
```

2. Configure firewall:
```bash
# Allow SIP and WebRTC
gcloud compute firewall-rules create vgtpbx-allow \
  --allow udp:5060,tcp:5060,tcp:5061,tcp:5066,tcp:7443
```

3. Update PBX API URL if needed (docker-compose.prod.yml)


## Monitoring

```bash
# Health check
curl http://127.0.0.1:8081/health

# FreeSWITCH status
docker exec vgtpbx-switch fs_cli -x "status"

# Resource usage
docker stats --no-stream vgtpbx-switch vgtpbx-eslserver
```

Expected usage (e2-small):
- vgtpbx-switch: 400-650MB RAM, 5-15% CPU
- vgtpbx-eslserver: 50-200MB RAM, 1-3% CPU

## Troubleshooting

### FreeSWITCH won't start
```bash
# Check logs
docker logs vgtpbx-switch

# Common issues: missing FS_TOKEN, config syntax errors
docker exec vgtpbx-switch fs_cli -x "reloadxml"
```

### ESL connection issues
```bash
# Verify ESL password matches in both:
# - docker-compose.prod.yml (FREESWITCH_ESL_PASSWORD)
# - templates/conf/autoload_configs/event_socket.conf.xml (password)

# Check ESL status
docker exec vgtpbx-switch fs_cli -x "event_socket status"
```

### Out of memory
```bash
# Check usage
docker stats --no-stream

# Solutions:
# - Upgrade to e2-medium (4GB RAM)
# - Reduce loaded modules in modules.conf.xml
# - Increase swap space
```

## Production Checklist

- [ ] Both images pushed to GCP Artifact Registry
- [ ] ESL password changed from default "ClueCon"
- [ ] PBX API URL configured correctly
- [ ] Firewall rules applied
- [ ] Tested health endpoints
- [ ] Verified call flow end-to-end
- [ ] Monitoring/alerting configured
- [ ] Backup strategy in place

## Additional Resources

- [README.md](../README.md) - Features, configuration, monitoring
- [GCP_ARTIFACT-DOCKER.md](GCP_ARTIFACT-DOCKER.md) - Image registry setup
- [PRE_PRODUCTION_CHECKLIST.md](PRE_PRODUCTION_CHECKLIST.md) - Detailed checklist
