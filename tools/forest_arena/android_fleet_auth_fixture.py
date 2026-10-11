"""Ephemeral test-only guest API for isolated Android fleet LAN runs.

Never used by product startup. No PostgreSQL persistence; credentials are random,
held in memory, and never logged. APK still traverses guest and nickname APIs.
"""
import json
import re
import secrets
import threading
import unicodedata
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class GuestFixture:
    def __init__(self, host, port, service_token):
        self.service_token = service_token
        self.players, self.access, self.refresh, self.replayed = {}, {}, {}, {}
        self.lock = threading.Lock()
        fixture = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_args):
                pass

            def handle_request(self):
                try:
                    size = int(self.headers.get('Content-Length', 0))
                    if size > 8192:
                        raise ValueError('oversize')
                    payload = json.loads(self.rfile.read(size)) if size else {}
                    if not isinstance(payload, dict):
                        raise ValueError('object required')
                    with fixture.lock:
                        status, data = fixture.route(self.command, self.path, self.headers, payload)
                except (ValueError, json.JSONDecodeError):
                    status, data = 400, {'error': 'invalid_request'}
                body = json.dumps(data, ensure_ascii=False).encode()
                self.send_response(status)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                try:
                    self.wfile.write(body)
                except BrokenPipeError:
                    pass

            do_POST = handle_request
            do_GET = handle_request
            do_PATCH = handle_request

        self.server = ThreadingHTTPServer((host, port), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)

    def issue(self, player, next_refresh=None):
        access = secrets.token_urlsafe(32)
        refresh = next_refresh or secrets.token_urlsafe(32)
        self.access[access] = player
        self.refresh[refresh] = player
        return {'player_id': player, 'access_token': access, 'refresh_token': refresh, 'expires_in': 900}

    def route(self, method, path, headers, data):
        if method == 'POST' and path == '/v1/auth/guest':
            player = secrets.token_hex(16)
            self.players[player] = {'player_id': player, 'nickname': None}
            return 201, self.issue(player)
        if method == 'POST' and path == '/v1/auth/refresh':
            old = data.get('refresh_token')
            successor = data.get('next_refresh_token')
            if not isinstance(old, str) or not isinstance(successor, str) or not successor:
                return 401, {'error': 'invalid_token'}
            key = (old, successor)
            if key in self.replayed:
                return 200, self.replayed[key]
            player = self.refresh.pop(old, None)
            if not player:
                return 401, {'error': 'invalid_token'}
            result = self.issue(player, successor)
            self.replayed[key] = result
            return 200, result
        if path == '/internal/v1/lan/auth':
            if headers.get('x-forest-arena-service-token') != self.service_token:
                return 401, {'error': 'invalid_service_token'}
            player = self.access.get(data.get('access_token'))
        else:
            player = self.access.get(headers.get('Authorization', '').removeprefix('Bearer '))
        if not player:
            return 401, {'error': 'invalid_token'}
        profile = self.players[player]
        if method == 'PATCH' and path == '/v1/guest/profile':
            nickname = data.get('nickname')
            if not isinstance(nickname, str):
                return 400, {'error': 'invalid_nickname'}
            nickname = unicodedata.normalize('NFC', nickname)
            if not re.fullmatch(r'[가-힣A-Za-z0-9_]{2,12}', nickname):
                return 400, {'error': 'invalid_nickname'}
            if any(p['player_id'] != player and (p['nickname'] or '').casefold() == nickname.casefold() for p in self.players.values()):
                return 409, {'error': 'nickname_taken'}
            profile['nickname'] = nickname
            return 200, profile.copy()
        if method == 'GET' and path == '/v1/guest/profile':
            return 200, profile.copy()
        if method == 'POST' and path == '/internal/v1/lan/auth':
            return (200, profile.copy()) if profile['nickname'] else (409, {'error': 'nickname_required'})
        return 404, {'error': 'not_found'}

    def start(self):
        self.thread.start()
        return self

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
