"""
Syrah Bridge - mitmproxy addon for Flutter app communication

This addon captures network flows from mitmproxy and sends them to the
Flutter app via WebSocket. It also receives commands from Flutter for
breakpoints, map local/remote, and other manipulation features.

Usage:
    mitmdump -s syrah_bridge.py --set syrah_port=9999
"""

import asyncio
import json
import logging
import threading
import time
from typing import Optional, Any
from dataclasses import dataclass, asdict
from enum import Enum

from mitmproxy import http, ctx, websocket
from mitmproxy.flow import Flow
from mitmproxy.options import Options

# Try to import websockets, provide helpful error if missing
try:
    import websockets
    from websockets.server import serve as ws_serve
    from websockets.exceptions import ConnectionClosed
except ImportError:
    print("Error: websockets package not installed. Run: pip install websockets")
    raise

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("syrah_bridge")


class RuleType(Enum):
    BREAKPOINT = "breakpoint"
    MAP_LOCAL = "mapLocal"
    MAP_REMOTE = "mapRemote"
    BLOCK = "block"


@dataclass
class ProxyRule:
    id: str
    type: str
    url_pattern: str
    enabled: bool = True
    phase: str = "request"  # request or response
    # For map local
    file_path: Optional[str] = None
    # For map remote
    target_url: Optional[str] = None
    # For custom response
    status_code: Optional[int] = None
    headers: Optional[dict] = None
    body: Optional[str] = None


class SyrahBridge:
    """
    mitmproxy addon that bridges flows to the Flutter Syrah app via WebSocket.
    """

    def __init__(self):
        self.ws_clients: set = set()
        self.ws_server = None
        self.ws_thread = None
        self.rules: list[ProxyRule] = []
        self.intercepted_flows: dict[str, Flow] = {}
        self.port = 9999
        self._loop: Optional[asyncio.AbstractEventLoop] = None

    def load(self, loader):
        """Register addon options."""
        loader.add_option(
            name="syrah_port",
            typespec=int,
            default=9999,
            help="WebSocket port for Syrah Flutter app communication"
        )

    def configure(self, updated):
        """Handle configuration updates."""
        if "syrah_port" in updated:
            self.port = ctx.options.syrah_port

    def running(self):
        """Called when mitmproxy is fully running."""
        logger.info(f"Starting Syrah WebSocket server on port {self.port}")
        self._start_ws_server()

    def done(self):
        """Cleanup when mitmproxy shuts down."""
        logger.info("Shutting down Syrah WebSocket server")
        self._stop_ws_server()

    def _start_ws_server(self):
        """Start the WebSocket server in a background thread."""
        def run_server():
            self._loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self._loop)
            self._loop.run_until_complete(self._ws_server_main())

        self.ws_thread = threading.Thread(target=run_server, daemon=True)
        self.ws_thread.start()

    def _stop_ws_server(self):
        """Stop the WebSocket server."""
        if self._loop:
            self._loop.call_soon_threadsafe(self._loop.stop)

    async def _ws_server_main(self):
        """Main WebSocket server coroutine."""
        try:
            # Listen on all interfaces so Android devices can connect
            async with ws_serve(self._handle_client, "0.0.0.0", self.port):
                logger.info(f"Syrah WebSocket server listening on ws://0.0.0.0:{self.port}")
                await asyncio.Future()  # Run forever
        except Exception as e:
            logger.error(f"WebSocket server error: {e}")

    async def _handle_client(self, websocket):
        """Handle a WebSocket client connection."""
        self.ws_clients.add(websocket)
        logger.info(f"Flutter client connected. Total clients: {len(self.ws_clients)}")

        try:
            async for message in websocket:
                await self._process_command(websocket, message)
        except ConnectionClosed:
            pass
        finally:
            self.ws_clients.discard(websocket)
            logger.info(f"Flutter client disconnected. Total clients: {len(self.ws_clients)}")

    async def _process_command(self, websocket, message: str):
        """Process a command from the Flutter app."""
        try:
            cmd = json.loads(message)
            command_type = cmd.get("command")

            if command_type == "resume":
                await self._handle_resume(cmd)
            elif command_type == "kill":
                await self._handle_kill(cmd)
            elif command_type == "updateRules":
                await self._handle_update_rules(cmd)
            elif command_type == "ping":
                await websocket.send(json.dumps({"type": "pong"}))
            else:
                logger.warning(f"Unknown command: {command_type}")

        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON command: {e}")
        except Exception as e:
            logger.error(f"Error processing command: {e}")

    async def _handle_resume(self, cmd: dict):
        """Resume an intercepted flow, optionally with modifications."""
        flow_id = cmd.get("flowId")
        modified = cmd.get("modified")

        if flow_id in self.intercepted_flows:
            flow = self.intercepted_flows.pop(flow_id)

            if modified:
                # Apply modifications
                if "request" in modified:
                    req_mod = modified["request"]
                    if "method" in req_mod:
                        flow.request.method = req_mod["method"]
                    if "url" in req_mod:
                        flow.request.url = req_mod["url"]
                    if "headers" in req_mod:
                        flow.request.headers.clear()
                        for k, v in req_mod["headers"].items():
                            flow.request.headers[k] = v
                    if "body" in req_mod:
                        flow.request.set_text(req_mod["body"])

                if "response" in modified and flow.response:
                    resp_mod = modified["response"]
                    if "status_code" in resp_mod:
                        flow.response.status_code = resp_mod["status_code"]
                    if "headers" in resp_mod:
                        flow.response.headers.clear()
                        for k, v in resp_mod["headers"].items():
                            flow.response.headers[k] = v
                    if "body" in resp_mod:
                        flow.response.set_text(resp_mod["body"])

            flow.resume()
            logger.info(f"Resumed flow: {flow_id}")
        else:
            logger.warning(f"Flow not found for resume: {flow_id}")

    async def _handle_kill(self, cmd: dict):
        """Kill an intercepted flow."""
        flow_id = cmd.get("flowId")

        if flow_id in self.intercepted_flows:
            flow = self.intercepted_flows.pop(flow_id)
            flow.kill()
            logger.info(f"Killed flow: {flow_id}")
        else:
            logger.warning(f"Flow not found for kill: {flow_id}")

    async def _handle_update_rules(self, cmd: dict):
        """Update the rules list."""
        rules_data = cmd.get("rules", [])
        self.rules = [
            ProxyRule(
                id=r.get("id", ""),
                type=r.get("type", ""),
                url_pattern=r.get("urlPattern", ""),
                enabled=r.get("enabled", True),
                phase=r.get("phase", "request"),
                file_path=r.get("filePath"),
                target_url=r.get("targetUrl"),
                status_code=r.get("statusCode"),
                headers=r.get("headers"),
                body=r.get("body"),
            )
            for r in rules_data
        ]
        logger.info(f"Updated rules: {len(self.rules)} rules")

    def _matches_pattern(self, url: str, pattern: str) -> bool:
        """Check if a URL matches a pattern (supports wildcards)."""
        import fnmatch
        # Convert URL pattern to glob pattern
        # e.g., "*/api/*" matches "https://example.com/api/users"
        return fnmatch.fnmatch(url, pattern)

    def _find_matching_rule(self, flow: Flow, phase: str, rule_type: Optional[str] = None) -> Optional[ProxyRule]:
        """Find the first matching rule for a flow."""
        url = flow.request.pretty_url

        for rule in self.rules:
            if not rule.enabled:
                continue
            if rule.phase != phase:
                continue
            if rule_type and rule.type != rule_type:
                continue
            if self._matches_pattern(url, rule.url_pattern):
                return rule

        return None

    def _send_flow_to_clients(self, flow: Flow, phase: str):
        """Send a flow event to all connected WebSocket clients."""
        if not self.ws_clients:
            return

        event = self._serialize_flow(flow, phase)
        message = json.dumps(event)

        # Schedule sending on the WebSocket thread's event loop
        if self._loop:
            asyncio.run_coroutine_threadsafe(
                self._broadcast(message),
                self._loop
            )

    async def _broadcast(self, message: str):
        """Broadcast a message to all connected clients."""
        if self.ws_clients:
            await asyncio.gather(
                *[client.send(message) for client in self.ws_clients],
                return_exceptions=True
            )

    def _serialize_flow(self, flow: Flow, phase: str) -> dict:
        """Serialize a flow to JSON for the Flutter app."""
        request_data = {
            "method": flow.request.method,
            "url": flow.request.pretty_url,
            "host": flow.request.host,
            "port": flow.request.port,
            "path": flow.request.path,
            "httpVersion": flow.request.http_version,
            "headers": dict(flow.request.headers),
            "contentLength": len(flow.request.content) if flow.request.content else 0,
            "timestampStart": flow.request.timestamp_start,
            "timestampEnd": flow.request.timestamp_end,
        }

        # Include body for smaller requests
        if flow.request.content and len(flow.request.content) < 1_000_000:
            try:
                request_data["body"] = flow.request.get_text()
            except:
                request_data["body"] = None
                request_data["bodyBase64"] = flow.request.content.hex() if flow.request.content else None

        response_data = None
        if flow.response:
            response_data = {
                "statusCode": flow.response.status_code,
                "reason": flow.response.reason,
                "httpVersion": flow.response.http_version,
                "headers": dict(flow.response.headers),
                "contentLength": len(flow.response.content) if flow.response.content else 0,
                "timestampStart": flow.response.timestamp_start,
                "timestampEnd": flow.response.timestamp_end,
            }

            # Include body for smaller responses
            if flow.response.content and len(flow.response.content) < 1_000_000:
                try:
                    response_data["body"] = flow.response.get_text()
                except:
                    response_data["body"] = None

        return {
            "type": "flow",
            "phase": phase,
            "id": flow.id,
            "intercepted": flow.intercepted,
            "request": request_data,
            "response": response_data,
            "timestamp": time.time(),
            "error": str(flow.error) if flow.error else None,
        }

    # mitmproxy event hooks

    def request(self, flow: http.HTTPFlow):
        """Called when a request is received."""
        # Check for breakpoint
        breakpoint_rule = self._find_matching_rule(flow, "request", RuleType.BREAKPOINT.value)
        if breakpoint_rule:
            flow.intercept()
            self.intercepted_flows[flow.id] = flow
            logger.info(f"Breakpoint hit (request): {flow.request.pretty_url}")

        # Check for map remote
        map_remote_rule = self._find_matching_rule(flow, "request", RuleType.MAP_REMOTE.value)
        if map_remote_rule and map_remote_rule.target_url:
            original_url = flow.request.pretty_url
            flow.request.url = map_remote_rule.target_url
            logger.info(f"Map remote: {original_url} -> {map_remote_rule.target_url}")

        # Check for block
        block_rule = self._find_matching_rule(flow, "request", RuleType.BLOCK.value)
        if block_rule:
            flow.kill()
            logger.info(f"Blocked request: {flow.request.pretty_url}")
            return

        # Send flow to Flutter app
        self._send_flow_to_clients(flow, "request")

    def response(self, flow: http.HTTPFlow):
        """Called when a response is received."""
        # Check for map local
        map_local_rule = self._find_matching_rule(flow, "response", RuleType.MAP_LOCAL.value)
        if map_local_rule and map_local_rule.file_path:
            try:
                with open(map_local_rule.file_path, "rb") as f:
                    content = f.read()
                flow.response = http.Response.make(
                    status_code=map_local_rule.status_code or 200,
                    content=content,
                    headers=map_local_rule.headers or {"Content-Type": "application/octet-stream"}
                )
                logger.info(f"Map local: {flow.request.pretty_url} -> {map_local_rule.file_path}")
            except Exception as e:
                logger.error(f"Map local error: {e}")

        # Check for breakpoint
        breakpoint_rule = self._find_matching_rule(flow, "response", RuleType.BREAKPOINT.value)
        if breakpoint_rule:
            flow.intercept()
            self.intercepted_flows[flow.id] = flow
            logger.info(f"Breakpoint hit (response): {flow.request.pretty_url}")

        # Send flow to Flutter app
        self._send_flow_to_clients(flow, "response")

    def error(self, flow: http.HTTPFlow):
        """Called when an error occurs."""
        self._send_flow_to_clients(flow, "error")

    def websocket_message(self, flow: websocket.WebSocketFlow):
        """Called for WebSocket messages."""
        # TODO: Implement WebSocket message handling
        pass


# Register the addon
addons = [SyrahBridge()]
