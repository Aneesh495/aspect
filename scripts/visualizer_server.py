#!/usr/bin/env python3
"""
Aspect: Real-Time Telemetry Bridge & Static Web Server.
Standards: RFC 6455 (WebSocket) / Zero external Python dependencies.

Bridges the Ada Aspect CBI kernel's TCP telemetry stream (port 9002)
to browser WebSockets (port 9003) and serves the cockpit web UI (port 8080).
"""

import asyncio
import base64
import hashlib
import os
import struct
import sys
from http.server import SimpleHTTPRequestHandler
import socketserver
import threading

TCP_HOST = "127.0.0.1"
TCP_PORT = 9002
WS_PORT = 9003
HTTP_PORT = 8080

WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

connected_clients = set()
ada_writer = None


def create_ws_accept(key: str) -> str:
    combined = key.strip() + WS_GUID
    hashed = hashlib.sha1(combined.encode("utf-8")).digest()
    return base64.b64encode(hashed).decode("utf-8")


def encode_ws_frame(message: str) -> bytes:
    payload = message.encode("utf-8")
    length = len(payload)
    frame = bytearray([0x81])  # FIN=1, Opcode=1 (Text)

    if length <= 125:
        frame.append(length)
    elif length <= 65535:
        frame.append(126)
        frame.extend(struct.pack("!H", length))
    else:
        frame.append(127)
        frame.extend(struct.pack("!Q", length))

    frame.extend(payload)
    return bytes(frame)


def decode_ws_frame(data: bytes):
    if len(data) < 2:
        return None, 0
    second = data[1]
    masked = bool(second & 0x80)
    payload_len = second & 0x7F
    offset = 2

    if payload_len == 126:
        if len(data) < 4:
            return None, 0
        payload_len = struct.unpack("!H", data[2:4])[0]
        offset = 4
    elif payload_len == 127:
        if len(data) < 10:
            return None, 0
        payload_len = struct.unpack("!Q", data[2:10])[0]
        offset = 10

    if masked:
        if len(data) < offset + 4 + payload_len:
            return None, 0
        mask = data[offset:offset + 4]
        offset += 4
        raw = data[offset:offset + payload_len]
        unmasked = bytes(b ^ mask[i % 4] for i, b in enumerate(raw))
        return unmasked.decode("utf-8", errors="ignore"), offset + payload_len
    else:
        if len(data) < offset + payload_len:
            return None, 0
        raw = data[offset:offset + payload_len]
        return raw.decode("utf-8", errors="ignore"), offset + payload_len


async def handle_ws_client(reader, writer):
    global ada_writer
    client_addr = writer.get_extra_info("peername")
    headers = {}

    try:
        # Handshake
        while True:
            line = await reader.readline()
            if not line or line == b"\r\n":
                break
            parts = line.decode("utf-8", errors="ignore").split(":", 1)
            if len(parts) == 2:
                headers[parts[0].strip().lower()] = parts[1].strip()

        sec_key = headers.get("sec-websocket-key")
        if not sec_key:
            writer.close()
            return

        accept_val = create_ws_accept(sec_key)
        response = (
            "HTTP/1.1 101 Switching Protocols\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Accept: {accept_val}\r\n\r\n"
        )
        writer.write(response.encode("utf-8"))
        await writer.drain()

        connected_clients.add(writer)
        print(f"[WS] Browser connected from {client_addr}. Total clients: {len(connected_clients)}")

        # Client frame loop
        buffer = bytearray()
        while True:
            chunk = await reader.read(4096)
            if not chunk:
                break
            buffer.extend(chunk)
            msg, consumed = decode_ws_frame(buffer)
            if consumed > 0:
                del buffer[:consumed]
                if msg:
                    # Forward command to Ada TCP socket
                    if ada_writer and not ada_writer.is_closing():
                        ada_writer.write((msg.strip() + "\n").encode("utf-8"))
                        await ada_writer.drain()
                        print(f"[FORWARD &rarr; ADA] {msg.strip()}")

    except Exception as e:
        pass
    finally:
        connected_clients.discard(writer)
        writer.close()
        print(f"[WS] Browser disconnected: {client_addr}. Remaining: {len(connected_clients)}")


async def connect_to_ada():
    global ada_writer
    while True:
        try:
            reader, writer = await asyncio.open_connection(TCP_HOST, TCP_PORT)
            ada_writer = writer
            print(f"[BRIDGE] Connected to Aspect Ada kernel at {TCP_HOST}:{TCP_PORT}")

            while True:
                line = await reader.readline()
                if not line:
                    break
                line_str = line.decode("utf-8", errors="ignore").strip()
                if line_str and connected_clients:
                    frame = encode_ws_frame(line_str)
                    dead_clients = []
                    for client in list(connected_clients):
                        try:
                            client.write(frame)
                            await client.drain()
                        except Exception:
                            dead_clients.append(client)
                    for dead in dead_clients:
                        connected_clients.discard(dead)

        except (ConnectionRefusedError, OSError):
            ada_writer = None
            await asyncio.sleep(1.0)
        except Exception as e:
            ada_writer = None
            await asyncio.sleep(1.0)


def run_http_server(web_dir):
    os.chdir(web_dir)
    handler = SimpleHTTPRequestHandler
    with socketserver.TCPServer(("", HTTP_PORT), handler) as httpd:
        print(f"[HTTP] Cockpit web server serving at http://localhost:{HTTP_PORT}")
        httpd.serve_forever()


async def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    web_dir = os.path.join(os.path.dirname(script_dir), "web")

    # Start static HTTP server in background thread
    http_thread = threading.Thread(target=run_http_server, args=(web_dir,), daemon=True)
    http_thread.start()

    # Start WebSocket server
    ws_server = await asyncio.start_server(handle_ws_client, "0.0.0.0", WS_PORT)
    print(f"[WS] WebSocket streaming server listening on ws://0.0.0.0:{WS_PORT}")

    # Start Ada TCP connector task
    ada_task = asyncio.create_task(connect_to_ada())

    async with ws_server:
        await asyncio.gather(ws_server.serve_forever(), ada_task)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n[ASPECT] Visualizer bridge terminated.")
