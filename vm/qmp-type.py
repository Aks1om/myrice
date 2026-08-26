#!/usr/bin/env python3
"""Type ASCII text into a QEMU guest through QMP send-key commands."""
import argparse
import json
import socket

BASE = {" ": "spc", "-": "minus", "=": "equal", "[": "bracket_left", "]": "bracket_right", "\\": "backslash", ";": "semicolon", "'": "apostrophe", "`": "grave_accent", ",": "comma", ".": "dot", "/": "slash"}
SHIFTED = {"!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7", "*": "8", "(": "9", ")": "0", "_": "minus", "+": "equal", "{": "bracket_left", "}": "bracket_right", "|": "backslash", ":": "semicolon", '"': "apostrophe", "~": "grave_accent", "<": "comma", ">": "dot", "?": "slash"}


def key_events(text):
    """Return QMP key chords for printable ASCII text followed by Enter."""
    events = []
    for char in text:
        if "a" <= char <= "z" or "0" <= char <= "9":
            events.append([char])
        elif "A" <= char <= "Z":
            events.append(["shift", char.lower()])
        elif char in BASE:
            events.append([BASE[char]])
        elif char in SHIFTED:
            events.append(["shift", SHIFTED[char]])
        else:
            raise ValueError("unsupported character: {!r}".format(char))
    return events + [["ret"]]


class QmpClient:
    def __init__(self, path, timeout):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(timeout)
        self.sock.connect(path)
        self.stream = self.sock.makefile("rwb")
        self.sequence = 0
        if "QMP" not in self.receive():
            raise RuntimeError("invalid QMP greeting")
        self.execute("qmp_capabilities")

    def receive(self):
        while True:
            line = self.stream.readline()
            if not line:
                raise RuntimeError("QMP connection closed")
            message = json.loads(line.decode("utf-8"))
            if "event" not in message:
                return message

    def execute(self, command, arguments=None):
        self.sequence += 1
        request = {"execute": command, "id": self.sequence}
        if arguments is not None:
            request["arguments"] = arguments
        self.stream.write(json.dumps(request, separators=(",", ":")).encode() + b"\r\n")
        self.stream.flush()
        response = self.receive()
        if response.get("id") != self.sequence or "error" in response:
            raise RuntimeError("QMP {} failed: {}".format(command, response))

    def close(self):
        self.stream.close()
        self.sock.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--socket", required=True, help="QMP UNIX socket path")
    parser.add_argument("--timeout", type=float, default=10)
    parser.add_argument("--dry-run", action="store_true", help="print requests without connecting")
    parser.add_argument("command", help="printable ASCII command to type")
    args = parser.parse_args()
    try:
        chords = key_events(args.command)
    except ValueError as error:
        parser.error(str(error))
    requests = [{"execute": "send-key", "arguments": {"keys": [{"type": "qcode", "data": key} for key in chord]}} for chord in chords]
    if args.dry_run:
        for request in requests:
            print(json.dumps(request, separators=(",", ":")))
        return
    client = QmpClient(args.socket, args.timeout)
    try:
        for request in requests:
            client.execute(request["execute"], request["arguments"])
    finally:
        client.close()


if __name__ == "__main__":
    main()
