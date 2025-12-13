# Stats Remote Daemon

HTTP daemon for exposing Linux system metrics to the macOS Stats app.

## Quick Start

```bash
# On your Linux machine (Box):
python3 stats-remote-daemon.py

# Test it:
curl http://localhost:9090/cpu
```

## Installation as Service

```bash
# Copy daemon script
sudo cp stats-remote-daemon.py /usr/local/bin/
sudo chmod +x /usr/local/bin/stats-remote-daemon.py

# Install systemd service
sudo cp stats-remote.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now stats-remote

# Check status
systemctl status stats-remote
```

## Endpoints

- `GET /cpu` - Returns JSON with CPU metrics
- `GET /health` - Health check (returns "OK")

## Response Format

```json
{
  "cpu": {
    "totalUsage": 0.25,
    "usagePerCore": [0.30, 0.20, 0.25, 0.25],
    "systemLoad": 0.10,
    "userLoad": 0.15,
    "idleLoad": 0.75
  },
  "loadAvg": {
    "load1": 1.5,
    "load5": 1.2,
    "load15": 0.9
  },
  "processes": [
    {"pid": 1234, "name": "process1", "usage": 15.5},
    {"pid": 5678, "name": "process2", "usage": 8.2}
  ],
  "hostname": "box",
  "timestamp": 1702500000.0
}
```

## Firewall

Make sure port 9090 is accessible:

```bash
# UFW
sudo ufw allow 9090/tcp

# firewalld
sudo firewall-cmd --add-port=9090/tcp --permanent
sudo firewall-cmd --reload
```

## Options

```
--port, -p    Port to listen on (default: 9090)
--bind, -b    Address to bind to (default: 0.0.0.0)
```
