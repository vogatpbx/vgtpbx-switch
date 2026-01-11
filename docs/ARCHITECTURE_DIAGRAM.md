# vgtpbx-switch Complete Architecture Diagram

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                     GCP e2-small VM (1GB RAM)                       │
│                          Per Tenant/Domain                          │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────┐    │
│  │                  Docker Compose Stack                      │    │
│  │                                                            │    │
│  │  ┌─────────────────────────┐  ┌──────────────────────┐   │    │
│  │  │   vgtpbx-switch         │  │  vgtpbx-eslserver    │   │    │
│  │  │   (FreeSWITCH)          │  │  (TypeScript/Node)   │   │    │
│  │  │                         │  │                      │   │    │
│  │  │  Memory: 650MB (limit)  │  │  Memory: 200MB       │   │    │
│  │  │  CPU: ~10-20% idle      │  │  CPU: ~1-3% idle     │   │    │
│  │  │                         │  │                      │   │    │
│  │  │  Ports:                 │  │  Ports:              │   │    │
│  │  │  • 5060 (SIP)           │  │  • 8081 (HTTP API)   │   │    │
│  │  │  • 5061 (SIP TLS)       │  │                      │   │    │
│  │  │  • 5066 (WS)            │  │  Features:           │   │    │
│  │  │  • 7443 (WSS)           │  │  • esl-lite          │   │    │
│  │  │  • 8021 (ESL)           │  │  • Express API       │   │    │
│  │  │                         │  │  • Pino logging      │   │    │
│  │  │  Volumes:               │  │  • Auto-reconnect    │   │    │
│  │  │  • /etc/vgtpbx/...      │  │  • bgapi support     │   │    │
│  │  │  • /var/log/freeswitch  │  │                      │   │    │
│  │  │  • tmpfs for DB         │  │                      │   │    │
│  │  └────────┬────────────────┘  └───────┬──────────────┘   │    │
│  │           │                           │                  │    │
│  │           │    ┌──────────────────────┤                  │    │
│  │           │    │ ESL :8021            │                  │    │
│  │           │    │ (localhost only)     │                  │    │
│  │           │    └──────────────────────┘                  │    │
│  │           │                                              │    │
│  └───────────┼──────────────────────────────────────────────┘    │
│              │                    │                               │
│              │ xml_curl           │ Event forwarding              │
│              │ httapi             │ + HTTP commands               │
│              │                    │                               │
└──────────────┼────────────────────┼───────────────────────────────┘
               │                    │
               └────────┬───────────┘
                        │
                        │ HTTP/HTTPS
                        ↓
        ┌───────────────────────────────┐
        │   NextJS PBX (switch-api)     │
        │   IP: 10.162.0.53:3000        │
        │                               │
        │   Endpoints:                  │
        │   • /api/xmlhandler/*         │
        │     - directory               │
        │     - dialplan                │
        │     - languages               │
        │     - configuration           │
        │                               │
        │   • /api/httpapihandler/      │
        │     - call flow control       │
        │     - event notifications     │
        │                               │
        │   • /api/registrations (new)  │
        │   • /api/cdr (new)            │
        └───────────────────────────────┘
```

## Communication Flows

### 1. SIP Registration Flow
```
SIP Phone/Gateway
      │
      │ REGISTER
      ↓
FreeSWITCH (:5060)
      │
      │ xml_curl directory lookup
      ↓
PBX API → /api/xmlhandler/directory/
      │
      │ Return user credentials
      ↓
FreeSWITCH → 200 OK to phone
```

### 2. Inbound Call Flow
```
PSTN/SIP Trunk
      │
      ↓
FreeSWITCH (:5060)
      │
      ├─→ xml_curl dialplan
      │   PBX API → /api/xmlhandler/dialplan/
      │   Returns: dialplan XML
      │
      ├─→ httapi call control
      │   PBX API → /api/httpapihandler/
      │   Returns: httapi XML (play, speak, dial, etc)
      │
      └─→ ESL events
          vogat-eslserver → PBX API
          Events:
          • CHANNEL_CREATE
          • CHANNEL_ANSWER
          • CHANNEL_HANGUP
          • RECORD_START/STOP
          • etc.
```

### 3. Outbound Call Flow
```
PBX Web Interface
      │
      │ Originate request
      ↓
PBX API Backend
      │
      │ HTTP POST to vogat-eslserver
      ↓
vogat-eslserver (:8081)
      │
      │ ESL originate command
      ↓
FreeSWITCH → Makes call
      │
      └─→ Events back to PBX via httpapihandler
```

### 4. Registration Check Flow
```
PBX Dashboard
      │
      │ Check if extension online
      ↓
PBX API Backend
      │
      │ HTTP POST /registrations/sofia-contact
      ↓
vogat-eslserver (:8081)
      │
      │ bgapi: sofia_contact internal/1001@domain
      ↓
FreeSWITCH → Returns registration info
      │
      ↓
vogat-eslserver → Parse response
      │
      ↓
PBX API → Display to user
      (Extension: 1001, IP: 192.168.1.100, Status: Registered)
```

## Data Flow

### Event Processing Pipeline
```
1. Call Event Occurs in FreeSWITCH
          ↓
2. Event published to ESL socket (:8021)
          ↓
3. vogat-eslserver receives via esl-lite
          ↓
4. Event handler processes (eventHandlers.ts)
          ↓
5. eventToVgtPbx() formats payload
          ↓
6. HTTP POST to PBX API /api/httpapihandler/
          ↓
7. PBX processes event (update DB, trigger webhooks, etc)
```

### Example Event Payload
```json
{
  "eventName": "CHANNEL_ANSWER",
  "subClass": null,
  "eventData": {
    "eventName": "CHANNEL_ANSWER",
    "channelData": {
      "uniqueID": "abc123-uuid",
      "callerIDName": "John Doe",
      "callerIDNumber": "+1234567890",
      "destinationNumber": "1001",
      "answerState": "answered",
      "callDirection": "inbound"
    },
    "rawEventData": { /* Full ESL event */ },
    "timestamp": "2026-01-11T15:30:00.123Z"
  },
  "timestamp": "2026-01-11T15:30:00.123Z"
}
```

## Resource Allocation

### e2-small (1GB RAM) - Per Tenant
```
┌─────────────────────────────────────┐
│         Total: 1024 MB              │
├─────────────────────────────────────┤
│  FreeSWITCH:          650 MB (63%) │
│  vogat-eslserver:     200 MB (20%) │
│  Docker overhead:      50 MB (5%)  │
│  System (kernel/etc): 100 MB (10%) │
│  Buffer:               24 MB (2%)  │
└─────────────────────────────────────┘

Concurrent calls: 10-20 max
Upgrade needed if: >15 calls regularly
```

### e2-medium (4GB RAM) - Upgraded Tenant
```
┌─────────────────────────────────────┐
│         Total: 4096 MB              │
├─────────────────────────────────────┤
│  FreeSWITCH:         2000 MB (49%) │
│  vogat-eslserver:     300 MB (7%)  │
│  Docker overhead:     100 MB (2%)  │
│  System:              200 MB (5%)  │
│  Buffer:             1496 MB (37%) │
└─────────────────────────────────────┘

Concurrent calls: 50-80 max
```

## Deployment Topology

### Multi-Tenant Architecture
```
┌──────────────────────────────────────────────────────────┐
│               Google Cloud Platform                      │
│                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │ Tenant 1 VM │  │ Tenant 2 VM │  │ Tenant N VM │     │
│  │ (e2-small)  │  │ (e2-medium) │  │ (e2-small)  │     │
│  │             │  │             │  │             │     │
│  │ FS + ESL    │  │ FS + ESL    │  │ FS + ESL    │     │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘     │
│         │                │                │             │
└─────────┼────────────────┼────────────────┼─────────────┘
          │                │                │
          └────────────────┴────────────────┘
                           │
                           │ Private network
                           │ (or public with auth)
                           ↓
              ┌────────────────────────┐
              │   PBX API Server       │
              │   (Next.js)            │
              │   Multi-tenant DB      │
              │   Domain routing       │
              └────────────────────────┘
```

### Network Security
```
┌─────────────────────────────────────────┐
│  GCP VM (per tenant)                    │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Container Network (host mode)  │   │
│  │                                 │   │
│  │  127.0.0.1:8021 ← ESL (local)  │   │
│  │  127.0.0.1:8081 ← API (local)  │   │
│  │                                 │   │
│  │  0.0.0.0:5060   ← SIP (public) │   │
│  │  0.0.0.0:5066   ← WS  (public) │   │
│  │  0.0.0.0:7443   ← WSS (public) │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Firewall:                              │
│  ✓ Allow: 5060, 5061, 5066, 7443       │
│  ✓ Allow: RTP range (optional)         │
│  ✗ Block: 8021 (ESL)                    │
│  ✗ Block: 8081 (vogat-eslserver API)   │
│                                         │
└─────────────────────────────────────────┘
```

## Scaling Decision Tree

```
Current calls < 10?
    ├─ YES → e2-small (1GB) ✅
    └─ NO
         │
         Calls 10-50?
         ├─ YES → e2-medium (4GB)
         └─ NO
              │
              Calls 50-100?
              ├─ YES → e2-standard-2 (8GB)
              └─ NO → Consider split architecture
                       (dedicated media servers)
```

## Monitoring Points

```
┌──────────────────────────────────────────────┐
│           Monitoring Dashboard               │
├──────────────────────────────────────────────┤
│  FreeSWITCH                                  │
│  • fs_cli -x "status"                        │
│  • Concurrent calls                          │
│  • CPU/Memory usage                          │
│  • Uptime                                    │
│                                              │
│  vogat-eslserver                             │
│  • GET /health                               │
│  • ESL connection status                     │
│  • Event forwarding success rate             │
│  • API response times                        │
│                                              │
│  Docker                                      │
│  • docker stats (resources)                  │
│  • docker-compose ps (status)                │
│  • Container restarts                        │
│                                              │
│  System                                      │
│  • VM CPU/Memory/Disk                        │
│  • Network I/O                               │
│  • Disk I/O                                  │
└──────────────────────────────────────────────┘
```

## Failure Scenarios & Recovery

### 1. FreeSWITCH Crash
```
FreeSWITCH dies
    ↓
Docker restart policy → Restart container
    ↓
Health check → Wait for FS ready
    ↓
vogat-eslserver → Auto-reconnect ESL
    ↓
Service restored (calls were lost)
```

### 2. vogat-eslserver Crash
```
ESL server dies
    ↓
Docker restart → Container restarts
    ↓
Reconnects to FreeSWITCH ESL
    ↓
Events resume (FS calls unaffected) ✅
```

### 3. Network to PBX API Lost
```
Network down to PBX API
    ↓
vogat-eslserver logs HTTP errors
    ↓
FreeSWITCH continues serving calls ✅
    ↓
Events queued/lost (no queue currently)
    ↓
Network restored → Events resume
```

## Next Phase: Advanced Features

### Phase 1 (Current): Basic ESL
- [x] Event forwarding
- [x] Registration checks
- [x] Basic monitoring

### Phase 2 (Near future): Enhanced
- [ ] Event buffering/queue
- [ ] Metrics endpoint (Prometheus)
- [ ] Call recording upload to S3
- [ ] Real-time dashboards

### Phase 3 (Advanced): Full CDR
- [ ] Local CDR processing
- [ ] Batch event sending
- [ ] WebSocket for real-time PBX updates
- [ ] HA configuration (active-passive)
