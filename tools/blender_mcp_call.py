"""Call the installed Blender MCP add-on on localhost; no scene reset.

python tools/blender_mcp_call.py --file path/to/script.py
python tools/blender_mcp_call.py --code "print(bpy.data.filepath)"
"""
import argparse
import json
import socket
from pathlib import Path


def call(command, params, timeout=180):
    with socket.create_connection(("127.0.0.1", 9876), timeout=5) as conn:
        conn.settimeout(timeout)
        conn.sendall(json.dumps({"type": command, "params": params}).encode())
        data = bytearray()
        while True:
            chunk = conn.recv(65536)
            if not chunk:
                raise RuntimeError("Blender MCP closed before returning a complete response")
            data.extend(chunk)
            try:
                result = json.loads(data)
                break
            except json.JSONDecodeError:
                pass
    if result.get("status") != "success":
        raise RuntimeError(result)
    return result["result"]


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    choice = parser.add_mutually_exclusive_group(required=True)
    choice.add_argument("--code")
    choice.add_argument("--file", type=Path)
    parser.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args()
    code = args.code
    if args.file:
        path = str(args.file.resolve())
        code = f"import runpy; runpy.run_path({path!r}, run_name='__main__')"
    print(json.dumps(call("execute_code", {"code": code}, args.timeout), indent=2))
