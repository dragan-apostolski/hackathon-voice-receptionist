"""
Minimal stub of the web HTTP surface the voice agent consumes.

Listens on http://localhost:3000 and serves:
  GET  /api/health
  GET  /api/practice
  GET  /api/services
  GET  /api/staff
  GET  /api/availability?serviceId=&from=&to=&staffId=
  POST /api/calls/<id>/transcript          (no-op, logs)
  POST /api/calls/<id>/end                 (no-op, logs)
  POST /api/appointments                   (echoes a fake appointment id)

Used so the agent can be exercised end-to-end before the real web app
finishes rendering. Run:  python scripts/mock_web.py
"""

from __future__ import annotations

import json
import logging
from datetime import date, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("mock-web")

PRACTICE = {
    "name": "Bright Smile Dental Studio",
    "address": "1250 Maple Avenue, Springfield",
    "phoneDisplay": "(555) 014-2378",
    "greetingStyle": "warm",
    "agentName": "Alex",
    "toneProfile": "friendly",
    "closingStyle": "standard",
    "hoursOfOperation": [
        {"dayOfWeek": "Monday", "openTime": "09:00", "closeTime": "17:00"},
        {"dayOfWeek": "Tuesday", "openTime": "09:00", "closeTime": "17:00"},
        {"dayOfWeek": "Wednesday", "openTime": "09:00", "closeTime": "17:00"},
        {"dayOfWeek": "Thursday", "openTime": "09:00", "closeTime": "17:00"},
        {"dayOfWeek": "Friday", "openTime": "09:00", "closeTime": "17:00"},
    ],
}

SERVICES = [
    {
        "id": "svc-cleaning",
        "name": "Routine Cleaning",
        "description": "A professional teeth cleaning and polish appointment.",
        "durationMinutes": 60,
        "priceCents": 12000,
        "category": "preventive",
    },
    {
        "id": "svc-checkup",
        "name": "Dental Checkup",
        "description": "A general dental examination with X-rays as needed.",
        "durationMinutes": 30,
        "priceCents": 8500,
        "category": "preventive",
    },
    {
        "id": "svc-whitening",
        "name": "Teeth Whitening",
        "description": "An in-office whitening treatment that takes about ninety minutes.",
        "durationMinutes": 90,
        "priceCents": 25000,
        "category": "cosmetic",
    },
]

STAFF = [
    {"id": "stf-chen", "name": "Dr. Maya Chen", "role": "Dentist", "bio": "Maya has been with us for ten years and specializes in general dentistry."},
    {"id": "stf-grant", "name": "Dr. Oliver Grant", "role": "Dentist", "bio": "Oliver focuses on family and cosmetic dentistry."},
    {"id": "stf-ramirez", "name": "Sofia Ramirez", "role": "Hygienist", "bio": "Sofia runs all of our routine cleanings."},
]


def _make_availability(service_id: str, from_d: str, to_d: str) -> list[dict]:
    """Return a couple of plausible slots starting two days from today."""
    start = date.fromisoformat(from_d) if from_d else date.today()
    slots = []
    for offset in (2, 3, 5):
        d = start + timedelta(days=offset)
        slots.append({
            "staffId": "stf-chen",
            "staffName": "Dr. Maya Chen",
            "serviceId": service_id or "svc-cleaning",
            "date": d.isoformat(),
            "dayOfWeek": d.strftime("%A"),
            "startTime": "10:00",
            "endTime": "11:00",
            "startAt": f"{d.isoformat()}T10:00:00",
        })
    return slots


class Handler(BaseHTTPRequestHandler):
    def _send_json(self, status: int, body: object) -> None:
        payload = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, fmt: str, *args) -> None:  # noqa: A003
        log.info("%s - %s", self.address_string(), fmt % args)

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        path = parsed.path
        if path == "/api/health":
            self._send_json(200, {"status": "ok"})
        elif path == "/api/practice":
            self._send_json(200, PRACTICE)
        elif path == "/api/services":
            self._send_json(200, SERVICES)
        elif path == "/api/staff":
            self._send_json(200, STAFF)
        elif path == "/api/availability":
            qs = parse_qs(parsed.query)
            slots = _make_availability(
                qs.get("serviceId", [""])[0],
                qs.get("from", [""])[0],
                qs.get("to", [""])[0],
            )
            self._send_json(200, slots)
        else:
            self._send_json(404, {"error": f"unknown path {path}"})

    def do_POST(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        path = parsed.path
        length = int(self.headers.get("Content-Length", "0") or "0")
        raw = self.rfile.read(length) if length else b""
        try:
            body = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            body = {"_raw": raw.decode("utf-8", errors="replace")}

        if path == "/api/appointments":
            log.info("POST %s body=%s", path, body)
            self._send_json(201, {
                "id": "appt-mock-1",
                "serviceName": "Routine Cleaning",
                "staffName": "Dr. Maya Chen",
                "startAt": body.get("startAt", "2026-05-20T10:00:00"),
                "startAtFormatted": "Wednesday, May 20 at 10:00 AM",
            })
        elif path.startswith("/api/calls/") and path.endswith("/transcript"):
            log.info("transcript %s: %s", path, body)
            self._send_json(200, {"ok": True})
        elif path.startswith("/api/calls/") and path.endswith("/end"):
            log.info("end-call %s: %s", path, body)
            self._send_json(200, {"ok": True})
        else:
            self._send_json(404, {"error": f"unknown path {path}"})


if __name__ == "__main__":
    addr = ("127.0.0.1", 3000)
    srv = ThreadingHTTPServer(addr, Handler)
    log.info("mock_web listening on http://%s:%s — stub of /api endpoints", *addr)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        log.info("shutting down")
        srv.server_close()
