# vgtpbx-switch

**Production-ready FreeSWITCH + ESL Server deployment for multi-tenant VoIP PBX**

Per-tenant FreeSWITCH instances with integrated ESL event processing, optimized for GCP e2-small (1GB RAM) VMs.

## Quick Start

### Local Development

```bash
# 1. Clone vgtpbx-switch
git clone https://github.com/vogatpbx/vgtpbx-switch.git
cd vgtpbx-switch

# 2. Build FreeSWITCH image
export FS_TOKEN="your-signalwire-token"
docker build -t vgtpbx-switch:latest .

# 3. Clone vogat-eslserver (separate repo)
git clone https://github.com/vogatpbx/vogat-eslserver.git
cd vogat-eslserver
docker build -t vgtpbx-eslserver:latest .
cd ..

# 4. Run both containers (for local testing)
docker run -d --name vgtpbx-switch --network host vgtpbx-switch:latest
docker run -d --name vgtpbx-eslserver --network host vgtpbx-eslserver:latest

# 5. Verify
docker ps
curl http://127.0.0.1:8081/health
```

### Production Deployment (GCP)

```bash
# 1. Build and push both images to GCP Artifact Registry
See docs/GCP_ARTIFACT-DOCKER.md for detailed instructions

# 2. Deploy using docker-compose.prod.yml
VERSION=v1.0.0 docker-compose -f docker-compose.prod.yml up -d

# 3. Or use Cloud Function for automated VM provisioning
# Cloud function provisions both containers automatically
```

For complete deployment guide, see [DEPLOYMENT.md](docs/DEPLOYMENT.md).

## Architecture

Each tenant gets a dedicated VM with two containers:
- **vgtpbx-switch** (FreeSWITCH) - 650MB limit
- **vgtpbx-eslserver** (TypeScript ESL client) - 200MB limit - [separate repo](https://github.com/vogatpbx/vogat-eslserver)

Both containers communicate via localhost ESL socket. ESL server forwards events to PBX API and provides HTTP API for commands.

```
┌──────────────────────────────────────┐
│      GCP VM (e2-small, 1GB)         │
│                                      │
│  FreeSWITCH ←→ vogat-eslserver      │
│    (:8021)        (:8081)           │
│       │              │               │
└───────┼──────────────┼───────────────┘
        │              │
        └──────┬───────┘
               ↓
       PBX API (Next.js)
```

**Note:** vogat-eslserver runs independently (no depends_on) to maintain monitoring capability even when FreeSWITCH is down.

## Documentation

- **[ARCHITECTURE_DIAGRAM.md](docs/ARCHITECTURE_DIAGRAM.md)** - Visual 
- **[DEPLOYMENT.md](docs/DEPLOYMENT.md)** - Production deployment guide

## Features

### FreeSWITCH (vgtpbx-switch)
- Full-featured SIP server
- WebRTC support (WebSocket, WSS)
- xml_curl for directory/dialplan
- httapi for call flows
- Optimized for low memory usage

### vogat-eslserver
- TypeScript-based ESL client
- Event forwarding to PBX API
- HTTP API for commands (:8081)
  - `/health` - Health check
  - `/registrations/sofia-contact` - Check SIP registrations
  - `/commands/log` - Execute FS commands
- Auto-reconnect on connection loss
- Structured logging (Pino/JSON)

## Resource Usage

**e2-small (1GB RAM):**
- FreeSWITCH: 400-650MB
- vogat-eslserver: 50-200MB
- System: ~150MB
- **Concurrent calls:** 10-20

**Upgrade path:** e2-medium (4GB) → 50-80 calls

## Configuration

Key environment variables in [docker-compose.yml](docker-compose.yml):

```yaml
vgtpbx-switch:
  - POSTGRES_HOST=vgtpbx-postgres
  - FREESWITCH_LOG_LEVEL=debug

vgtpbx-eslserver:
  - FREESWITCH_HOST=127.0.0.1
  - FREESWITCH_ESL_PORT=8021
  - FREESWITCH_ESL_PASSWORD=ClueCon  # ⚠️ Change this!
  - NEXTJS_INTERNAL_API_URL=http://10.162.0.53:3000/api/httpapihandler
  - API_PORT=8081
```

## Security

**Before production:**
1. Change ESL password (docker-compose.yml + event_socket.conf.xml)
2. Configure GCP firewall (allow 5060, 5066, 7443; block 8021, 8081)
3. Update PBX API URL if needed

## Monitoring

```bash
# Health checks
curl http://127.0.0.1:8081/health
docker exec vgtpbx-switch fs_cli -x "status"

# Logs
docker logs vgtpbx-switch -f
docker logs vgtpbx-eslserver -f

# Resources
docker stats vgtpbx-switch vgtpbx-eslserver
```

## Contributing

For development and deployment setup, see [DEPLOYMENT.md](DEPLOYMENT.md). This includes build instructions, configuration guidelines, and testing procedures.

## License

MIT License - See LICENSE file for details.

## Support

For issues and troubleshooting, see [SCALING_ARCHITECTURE.md](SCALING_ARCHITECTURE.md#troubleshooting).

For complete architecture documentation and deployment guides, see the docs directory.

---
