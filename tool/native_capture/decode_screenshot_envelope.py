#!/usr/bin/env python3
"""Decode one get_screenshots CLI JSON envelope; emit one schema-valid summary JSON."""
from __future__ import annotations

import base64
import json
import struct
import sys
import zlib
from pathlib import Path
from typing import Any


REQUIRED_BACKEND = "flutter_layer_vm_extension"
REQUIRED_IMPL = "app_layer_tree"
REQUIRED_MODE = "flutter_layer"


def _fail(message: str, code: int = 2) -> None:
    print(json.dumps({"ok": False, "error": message}), file=sys.stderr)
    raise SystemExit(code)


def _png_crc(chunk_type: bytes, data: bytes) -> int:
    return zlib.crc32(chunk_type + data) & 0xFFFFFFFF


def validate_png(png: bytes) -> dict[str, Any]:
    if len(png) < 33 or png[:8] != b"\x89PNG\r\n\x1a\n":
        return {"pngValid": False, "reason": "bad_signature"}
    # IHDR
    if png[12:16] != b"IHDR":
        return {"pngValid": False, "reason": "missing_ihdr"}
    ihdr_len = struct.unpack(">I", png[8:12])[0]
    if ihdr_len != 13:
        return {"pngValid": False, "reason": "ihdr_len"}
    ihdr_data = png[16 : 16 + 13]
    w, h = struct.unpack(">II", ihdr_data[:8])
    ihdr_crc = struct.unpack(">I", png[16 + 13 : 16 + 17])[0]
    if ihdr_crc != _png_crc(b"IHDR", ihdr_data):
        return {"pngValid": False, "reason": "ihdr_crc"}
    if w < 1 or h < 1:
        return {"pngValid": False, "reason": "dimensions_too_small"}
    # IDAT present + CRC sanity on first IDAT
    pos = 8
    seen_idat = False
    non_white_samples = 0
    while pos + 12 <= len(png):
        length = struct.unpack(">I", png[pos : pos + 4])[0]
        ctype = png[pos + 4 : pos + 8]
        data = png[pos + 8 : pos + 8 + length]
        crc = struct.unpack(">I", png[pos + 8 + length : pos + 12 + length])[0]
        if crc != _png_crc(ctype, data):
            return {"pngValid": False, "reason": f"crc_mismatch_{ctype!r}"}
        if ctype == b"IDAT":
            seen_idat = True
            try:
                raw = zlib.decompress(data)
                if raw and any(b != 0xFF for b in raw[: min(len(raw), 4096)]):
                    non_white_samples += 1
            except zlib.error:
                return {"pngValid": False, "reason": "idat_inflate"}
        if ctype == b"IEND":
            break
        pos += 12 + length
    if not seen_idat:
        return {"pngValid": False, "reason": "no_idat"}
    return {
        "pngValid": True,
        "width": w,
        "height": h,
        "pngBytes": len(png),
        "hasNonTrivialIdatPayload": non_white_samples > 0,
    }


def decode_envelope(path: Path, *, write_png: Path | None = None) -> dict[str, Any]:
    raw = path.read_text()
    try:
        doc = json.loads(raw)
    except json.JSONDecodeError as exc:
        _fail(f"invalid_json: {exc}")
    ok = bool(doc.get("ok"))
    data = doc.get("data") or {}
    meta = {
        k: data.get(k)
        for k in (
            "captureMode",
            "actualMode",
            "captureBackend",
            "captureImplementation",
            "requestedMode",
            "fallbackReason",
            "captureModeUpgraded",
        )
    }
    summary: dict[str, Any] = {"ok": ok, "source": str(path), "meta": meta}

    if not ok:
        summary["error"] = doc.get("error")
        return summary

    if meta.get("captureBackend") != REQUIRED_BACKEND:
        _fail(f"captureBackend must be {REQUIRED_BACKEND!r}, got {meta.get('captureBackend')!r}")
    if meta.get("captureImplementation") != REQUIRED_IMPL:
        _fail(f"captureImplementation must be {REQUIRED_IMPL!r}, got {meta.get('captureImplementation')!r}")
    mode = meta.get("captureMode") or meta.get("actualMode")
    if mode != REQUIRED_MODE:
        _fail(f"capture mode must be {REQUIRED_MODE!r}, got {mode!r}")

    images = data.get("images") or []
    if not images:
        _fail("empty images")

    png = base64.b64decode(images[0])
    probe = validate_png(png)
    if not probe.get("pngValid"):
        _fail(f"png_invalid: {probe.get('reason')}")
    if not probe.get("hasNonTrivialIdatPayload"):
        _fail("png_blank_or_uniform_idat")

    summary["imageCount"] = len(images)
    summary["png"] = probe
    if write_png:
        write_png.write_bytes(png)
    return summary


def main() -> None:
    if len(sys.argv) < 2:
        _fail("usage: decode_screenshot_envelope.py <stdout.json> [--png out.png]")
    path = Path(sys.argv[1])
    png_out = None
    if len(sys.argv) >= 4 and sys.argv[2] == "--png":
        png_out = Path(sys.argv[3])
    summary = decode_envelope(path, write_png=png_out)
    print(json.dumps(summary, indent=2))
    if summary.get("ok") is False and summary.get("error") is not None:
        raise SystemExit(0)
    if not summary.get("ok"):
        raise SystemExit(3)


if __name__ == "__main__":
    main()
