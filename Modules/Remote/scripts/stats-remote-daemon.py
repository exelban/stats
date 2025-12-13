#!/usr/bin/env python3
"""
Stats Remote Daemon - Exposes CPU metrics via HTTP for macOS Stats app.

Usage:
    python3 stats-remote-daemon.py [--port PORT]

Deploy to Linux machine and run as a service. See stats-remote.service for systemd setup.
"""

import argparse
import json
import socket
import subprocess
import time
from http.server import HTTPServer, BaseHTTPRequestHandler

DEFAULT_PORT = 9090


def get_cpu_usage():
    """Read /proc/stat for CPU usage (delta-based for accuracy)."""
    def read_stat():
        with open('/proc/stat', 'r') as f:
            lines = f.readlines()
        result = {'total': None, 'cores': []}
        for line in lines:
            if line.startswith('cpu'):
                parts = line.split()
                name = parts[0]
                user = int(parts[1])
                nice = int(parts[2])
                system = int(parts[3])
                idle = int(parts[4])
                iowait = int(parts[5]) if len(parts) > 5 else 0
                irq = int(parts[6]) if len(parts) > 6 else 0
                softirq = int(parts[7]) if len(parts) > 7 else 0

                total = user + nice + system + idle + iowait + irq + softirq
                busy = user + nice + system + irq + softirq

                if name == 'cpu':
                    result['total'] = {'user': user, 'nice': nice, 'system': system, 'idle': idle, 'total': total, 'busy': busy}
                else:
                    result['cores'].append({'total': total, 'busy': busy, 'idle': idle})
            elif result['total'] is not None:
                break
        return result

    # First reading
    stat1 = read_stat()
    time.sleep(0.1)  # 100ms sample
    stat2 = read_stat()

    # Calculate deltas
    t = stat2['total']
    t1 = stat1['total']
    total_delta = t['total'] - t1['total']

    if total_delta == 0:
        return {
            'totalUsage': 0,
            'usagePerCore': [0] * len(stat2['cores']),
            'systemLoad': 0,
            'userLoad': 0,
            'idleLoad': 1
        }

    total_usage = (t['busy'] - t1['busy']) / total_delta
    system_load = (t['system'] - t1['system']) / total_delta
    user_load = ((t['user'] + t['nice']) - (t1['user'] + t1['nice'])) / total_delta
    idle_load = (t['idle'] - t1['idle']) / total_delta

    # Per-core usage
    cores = []
    for i, c in enumerate(stat2['cores']):
        c1 = stat1['cores'][i] if i < len(stat1['cores']) else {'total': 0, 'busy': 0}
        delta = c['total'] - c1['total']
        if delta > 0:
            cores.append(round((c['busy'] - c1['busy']) / delta, 4))
        else:
            cores.append(0)

    return {
        'totalUsage': round(total_usage, 4),
        'usagePerCore': cores,
        'systemLoad': round(system_load, 4),
        'userLoad': round(user_load, 4),
        'idleLoad': round(idle_load, 4)
    }


def get_load_average():
    """Read /proc/loadavg for 1/5/15 minute load averages."""
    with open('/proc/loadavg', 'r') as f:
        parts = f.read().split()
    return {
        'load1': float(parts[0]),
        'load5': float(parts[1]),
        'load15': float(parts[2])
    }


def get_top_processes(n=8):
    """Get top N CPU-consuming processes using ps."""
    try:
        result = subprocess.run(
            ['ps', '-eo', 'pid,pcpu,comm', '--sort=-pcpu', '--no-headers'],
            capture_output=True,
            text=True,
            timeout=5
        )
        processes = []
        for line in result.stdout.strip().split('\n')[:n]:
            if not line.strip():
                continue
            parts = line.split(None, 2)
            if len(parts) >= 3:
                processes.append({
                    'pid': int(parts[0]),
                    'usage': float(parts[1]),
                    'name': parts[2]
                })
        return processes
    except Exception:
        return []


class MetricsHandler(BaseHTTPRequestHandler):
    """HTTP request handler for metrics endpoint."""

    def do_GET(self):
        if self.path in ('/', '/cpu'):
            metrics = {
                'cpu': get_cpu_usage(),
                'loadAvg': get_load_average(),
                'processes': get_top_processes(8),
                'hostname': socket.gethostname(),
                'timestamp': time.time()
            }

            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps(metrics).encode())
        elif self.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'OK')
        else:
            self.send_response(404)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'Not Found')

    def log_message(self, format, *args):
        """Suppress default logging."""
        pass


def main():
    parser = argparse.ArgumentParser(description='Stats Remote Daemon')
    parser.add_argument('--port', '-p', type=int, default=DEFAULT_PORT, help=f'Port to listen on (default: {DEFAULT_PORT})')
    parser.add_argument('--bind', '-b', type=str, default='0.0.0.0', help='Address to bind to (default: 0.0.0.0)')
    args = parser.parse_args()

    server = HTTPServer((args.bind, args.port), MetricsHandler)
    print(f'Stats Remote Daemon running on {args.bind}:{args.port}')
    print(f'Endpoints: /cpu (metrics), /health (health check)')

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\nShutting down...')
        server.shutdown()


if __name__ == '__main__':
    main()
