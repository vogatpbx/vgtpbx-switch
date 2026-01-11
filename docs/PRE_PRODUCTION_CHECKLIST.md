# Pre-Production Checklist

Use this checklist before deploying to production VMs.

## Security ✅ CRITICAL

- [ ] Change ESL password from default "ClueCon"
  - [ ] Update `docker-compose.yml`: `FREESWITCH_ESL_PASSWORD`
  - [ ] Update `templates/conf/autoload_configs/event_socket.conf.xml`
  - [ ] Verify passwords match in both files
  
- [ ] Configure GCP Firewall Rules
  - [ ] Allow: TCP/UDP 5060 (SIP)
  - [ ] Allow: TCP 5061 (SIP TLS)
  - [ ] Allow: TCP/UDP 5080 (SIP Alt)
  - [ ] Allow: TCP 5066 (WebSocket)
  - [ ] Allow: TCP 7443 (WebSocket TLS)
  - [ ] Block: TCP 8021 (ESL - internal only)
  - [ ] Block: TCP 8081 (vogat-eslserver API - internal only)
  - [ ] Optional: UDP 16384-32768 (RTP range)

- [ ] Update PBX API URL if not using 10.162.0.53:3000
  - [ ] `docker-compose.yml`: `NEXTJS_INTERNAL_API_URL`
  - [ ] `templates/conf/autoload_configs/httapi.conf.xml`
  - [ ] `templates/conf/autoload_configs/xml_curl.conf.xml`

## Configuration

- [ ] Set FreeSWITCH SignalWire token
  - [ ] Export `FS_TOKEN` environment variable
  - [ ] Or create secret file

- [ ] Review enabled events in `vogat-eslserver/src/index.ts`
  - [ ] Enable `CHANNEL_ANSWER` for CDR
  - [ ] Enable `CHANNEL_HANGUP` for CDR
  - [ ] Enable others as needed
  - [ ] Rebuild after changes: `docker-compose build vgtpbx-eslserver`

- [ ] Verify resource limits in `docker-compose.yml`
  - [ ] FreeSWITCH: 650M limit (increase for e2-medium)
  - [ ] vogat-eslserver: 200M limit

- [ ] Review FreeSWITCH modules in `templates/conf/autoload_configs/modules.conf.xml`
  - [ ] Load only required modules
  - [ ] Disable unused modules to save memory

## PBX Integration

- [ ] Implement PBX API endpoint
  - [ ] Create/update `/api/httpapihandler` route
  - [ ] Handle event types: CHANNEL_ANSWER, CHANNEL_HANGUP, etc.
  - [ ] Test with curl/Postman

- [ ] Test xml_curl endpoints
  - [ ] `/api/xmlhandler/directory/` (user auth)
  - [ ] `/api/xmlhandler/dialplan/` (call routing)
  - [ ] `/api/xmlhandler/configuration/` (optional)

- [ ] Test httapi endpoint
  - [ ] `/api/httpapihandler/` (call flow control)
  - [ ] Verify XML response format

## Testing

- [ ] Build images locally
  ```bash
  docker-compose build
  ```

- [ ] Deploy to staging VM
  ```bash
  docker-compose up -d
  ```

- [ ] Verify both services are running
  ```bash
  docker-compose ps
  # Both should show "Up" and "healthy"
  ```

- [ ] Check FreeSWITCH status
  ```bash
  docker exec vgtpbx-switch fs_cli -x "status"
  # Should show "UP 0 years, 0 days, 0 hours..."
  ```

- [ ] Check vogat-eslserver health
  ```bash
  curl http://127.0.0.1:8081/health
  # Should return: {"status":"ok","eslConnected":<object>}
  ```

- [ ] Verify ESL connection
  ```bash
  docker logs vgtpbx-eslserver | grep "Connected to FreeSWITCH"
  # Should see connection success message
  ```

- [ ] Test SIP registration
  - [ ] Register a SIP phone/softphone
  - [ ] Check via vogat-eslserver API:
    ```bash
    curl -X POST http://127.0.0.1:8081/registrations/sofia-contact \
      -H "Content-Type: application/json" \
      -d '{"extension":"1001","profile":"internal","domain":"yourdomain.com"}'
    ```

- [ ] Test inbound call
  - [ ] Make test call to DID
  - [ ] Verify dialplan lookup works
  - [ ] Check events reach PBX API
  - [ ] Review logs: `docker logs vgtpbx-eslserver -f`

- [ ] Test outbound call
  - [ ] Originate call via PBX
  - [ ] Verify call completes
  - [ ] Check CDR created

## Monitoring Setup

- [ ] Create health check script
  - [ ] Copy from DEPLOYMENT.md: `check-health.sh`
  - [ ] Test script execution
  - [ ] Add to cron if needed

- [ ] Set up log aggregation (optional)
  - [ ] Configure log forwarding
  - [ ] Set up log rotation

- [ ] Configure alerting (optional)
  - [ ] CPU/Memory alerts
  - [ ] Service down alerts
  - [ ] High call volume alerts

## Performance

- [ ] Load test with expected concurrent calls
  - [ ] Use SIPp or similar tool
  - [ ] Monitor resource usage: `docker stats`
  - [ ] Verify within e2-small limits (<1GB RAM)

- [ ] Measure baseline metrics
  - [ ] Idle CPU/Memory usage
  - [ ] Per-call CPU/Memory increase
  - [ ] Max concurrent calls before degradation

- [ ] Optimize if needed
  - [ ] Disable unnecessary FreeSWITCH modules
  - [ ] Adjust log levels (reduce "debug" to "info")
  - [ ] Tune codec preferences

## Documentation

- [ ] Document tenant-specific configuration
  - [ ] Domain/extension scheme
  - [ ] DID routing
  - [ ] SIP trunk credentials

- [ ] Create runbook for common issues
  - [ ] Service restart procedure
  - [ ] Log analysis
  - [ ] Escalation contacts

- [ ] Document backup/restore procedure
  - [ ] Configuration backup
  - [ ] Recording backup
  - [ ] Restore testing

## Deployment

- [ ] Tag Docker images
  ```bash
  docker tag vgtpbx-switch:latest vgtpbx-switch:v1.0.0
  docker tag vgtpbx-eslserver:latest vgtpbx-eslserver:v1.0.0
  ```

- [ ] Push to container registry (if using)
  ```bash
  docker push your-registry/vgtpbx-switch:v1.0.0
  docker push your-registry/vgtpbx-eslserver:v1.0.0
  ```

- [ ] Update VM provisioning scripts
  - [ ] Include docker-compose.yml
  - [ ] Set environment variables
  - [ ] Configure firewall rules
  - [ ] Start services on boot

- [ ] Deploy to first production VM
  - [ ] Monitor closely for 24-48 hours
  - [ ] Check logs regularly
  - [ ] Verify call quality

- [ ] Gradual rollout
  - [ ] Deploy to 10% of tenants
  - [ ] Monitor for issues
  - [ ] Scale to 100% if stable

## Post-Deployment

- [ ] Monitor for 1 week
  - [ ] Check daily logs
  - [ ] Review resource trends
  - [ ] Collect user feedback

- [ ] Performance tuning
  - [ ] Adjust resource limits if needed
  - [ ] Optimize event subscriptions
  - [ ] Fine-tune logging

- [ ] Update documentation
  - [ ] Document any issues found
  - [ ] Update troubleshooting guide
  - [ ] Share lessons learned

## Emergency Rollback Plan

If issues arise:

1. **Quick rollback:**
   ```bash
   docker-compose down
   # Deploy previous version
   docker-compose up -d
   ```

2. **Isolate issue:**
   - Check logs: `docker logs vgtpbx-switch vgtpbx-eslserver`
   - Test ESL connection
   - Verify PBX API reachable

3. **Contact:**
   - Development team
   - On-call engineer
   - Document incident

---

## Sign-off

- [ ] Security review completed by: _________________ Date: _______
- [ ] Configuration verified by: _________________ Date: _______
- [ ] Testing completed by: _________________ Date: _______
- [ ] Documentation reviewed by: _________________ Date: _______
- [ ] Approved for production by: _________________ Date: _______

---

**Status**: [ ] Ready for Production | [ ] Issues Found (see notes)

**Notes:**
___________________________________________________________________
___________________________________________________________________
___________________________________________________________________
