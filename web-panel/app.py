import json
import os
import socket
import struct
import subprocess
from flask import Flask, jsonify, send_file

app = Flask(__name__)

REAPER_HOST = os.getenv("REAPER_HOST", "host.docker.internal")
REAPER_PORT = int(os.getenv("REAPER_PORT", "9000"))
GUIDES_DIR = os.getenv("GUIDES_DIR", "/app/guides")

_guide_proc = None

TRANSPORT = {"play": 1007, "pause": 1008, "stop": 1016}


def _osc_str(s):
    b = s.encode() + b"\x00"
    return b + b"\x00" * ((-len(b)) % 4)


def _osc_send(address, typetag, payload):
    msg = _osc_str(address) + typetag + payload
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.sendto(msg, (REAPER_HOST, REAPER_PORT))


def send_osc_action(action_id):
    _osc_send(f"/action/{action_id}", b",f\x00\x00", struct.pack(">f", 1.0))


@app.route("/")
def index():
    return send_file("index.html")


@app.route("/setlist")
def setlist():
    with open("setlist.json") as f:
        return jsonify(json.load(f))


@app.route("/osc/transport/<cmd>", methods=["POST"])
def osc_transport(cmd):
    action_id = TRANSPORT.get(cmd)
    if not action_id:
        return f"comando desconocido: {cmd}", 400
    send_osc_action(action_id)
    return "", 204


@app.route("/osc/marker/<int:n>", methods=["POST"])
def osc_marker(n):
    if not 1 <= n <= 99:
        return f"marcador {n} fuera de rango (1-99)", 400
    _osc_send("/marker", b",i\x00\x00", struct.pack(">i", n))
    return "", 204


@app.route("/guides")
def list_guides():
    files = sorted(f for f in os.listdir(GUIDES_DIR) if f.endswith(".wav"))
    return jsonify(files)


@app.route("/guide/<filename>", methods=["POST"])
def play_guide(filename):
    global _guide_proc
    path = os.path.join(GUIDES_DIR, os.path.basename(filename))
    if not os.path.isfile(path):
        return "archivo no encontrado", 404
    if _guide_proc and _guide_proc.poll() is None:
        _guide_proc.kill()
    _guide_proc = subprocess.Popen(["paplay", path])
    return "", 204


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
