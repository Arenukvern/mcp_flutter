#!/usr/bin/env python3
"""Normalize the timestamps in an MCPB (zip) archive to a fixed epoch.

`mcpb pack` stamps every entry with the wall clock at pack time, so two runs
over identical inputs produce different bytes and different SHA-256 digests.
A release rerun after a partially published release would then mismatch the
published checksums.txt and block recovery.

This tool patches ONLY the modification time fields (DOS time/date) in each
local file header and central directory entry. Compressed payloads, CRCs,
entry order, permissions, and every other header field are preserved
byte-for-byte, so the output is deterministic for identical inputs and stays
a valid zip readable by every MCPB host.

Usage: normalize_mcpb_timestamps.py <archive.mcpb>
"""
from __future__ import annotations

import struct
import sys
from pathlib import Path

# 1980-01-01 00:00:00 — the earliest DOS timestamp.
FIXED_DOS_TIME = 0x0000  # hour<<11 | minute<<5 | second/2
FIXED_DOS_DATE = 0x0021  # (year-1980)<<9 | month<<5 | day

# Local file header: mod time at byte 10, mod date at byte 12.
LOCAL_HEADER_MTIME_OFFSET = 10
# Central directory record: mod time at byte 12, mod date at byte 14.
CENTRAL_HEADER_MTIME_OFFSET = 12

EOCD_SIGNATURE = b"PK\x05\x06"
CENTRAL_SIGNATURE = b"PK\x01\x02"
LOCAL_SIGNATURE = b"PK\x03\x04"
ZIP64_EOCD_SIGNATURE = b"PK\x06\x06"


def fail(message: str) -> "NoReturn":  # type: ignore[name-defined]
    print(f"normalize_mcpb_timestamps: {message}", file=sys.stderr)
    raise SystemExit(1)


def find_eocd_offset(data: bytes) -> int:
    # EOCD is at most 64 KiB + 22 bytes from the end.
    window_start = max(0, len(data) - (0xFFFF + 22))
    offset = data.rfind(EOCD_SIGNATURE, window_start)
    if offset < 0:
        fail("no End of Central Directory record found")
    return offset


def normalize(path: Path) -> None:
    data = bytearray(path.read_bytes())

    eocd = find_eocd_offset(data)
    (
        _sig,
        _disk,
        _cd_disk,
        _disk_entries,
        total_entries,
        _cd_size,
        cd_offset,
        _comment_len,
    ) = struct.unpack_from("<IHHHHIIH", data, eocd)

    if data.find(ZIP64_EOCD_SIGNATURE) >= 0:
        fail("ZIP64 archives are not supported (bundle is far below the limits)")

    patched = 0
    cursor = cd_offset
    for _ in range(total_entries):
        if bytes(data[cursor : cursor + 4]) != CENTRAL_SIGNATURE:
            fail(f"bad central directory entry at offset {cursor}")
        (
            _sig,
            _ver_made,
            _ver_need,
            _flags,
            _method,
            _mtime,
            _mdate,
            _crc,
            _csize,
            _usize,
            _name_len,
            _extra_len,
            _comment_len,
            _disk_start,
            _int_attrs,
            _ext_attrs,
            local_offset,
        ) = struct.unpack_from("<IHHHHHHIIIHHHHHII", data, cursor)

        # Central directory entry mtime (bytes 12..16 of the record).
        struct.pack_into(
            "<HH", data, cursor + CENTRAL_HEADER_MTIME_OFFSET, FIXED_DOS_TIME, FIXED_DOS_DATE
        )

        # Local file header mtime (bytes 10..14 of the record).
        if bytes(data[local_offset : local_offset + 4]) != LOCAL_SIGNATURE:
            fail(f"bad local header at offset {local_offset}")
        struct.pack_into(
            "<HH",
            data,
            local_offset + LOCAL_HEADER_MTIME_OFFSET,
            FIXED_DOS_TIME,
            FIXED_DOS_DATE,
        )

        patched += 1
        cursor += 46 + _name_len + _extra_len + _comment_len

    if cursor != eocd:
        fail("central directory does not end at the EOCD record")

    path.write_bytes(bytes(data))
    print(f"normalize_mcpb_timestamps: normalized {patched} entries in {path}")


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: normalize_mcpb_timestamps.py <archive.mcpb>")
    target = Path(sys.argv[1])
    if not target.is_file():
        fail(f"not a file: {target}")
    normalize(target)


if __name__ == "__main__":
    main()
