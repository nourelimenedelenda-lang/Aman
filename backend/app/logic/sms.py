"""
app/logic/sms.py: 2G GSM compact SMS encoder and decoder.

Provides dead-zone resiliency for locations where 3G/4G cellular data is unavailable.
Serializes key incident fields into a standard GSM SMS string (~70-90 characters):

Format:
  SVX1#<lat>,<lon>#<vehicles>#<fire:0|1>#<trapped:0|1>#<victims>#<source>#<method>#<user_id>

Example:
  SVX1#36.41800,2.80200#2#1#0#2#sensor#speed_drop#3
"""
from typing import Any


def encode_sms(data: dict[str, Any]) -> str:
    """
    Encodes an incident report dictionary into an ultra-compact SMS payload.
    """
    lat = round(float(data["latitude"]), 5)
    lon = round(float(data["longitude"]), 5)
    veh = int(data.get("vehicle_count", 1))
    fire = 1 if data.get("fire") else 0
    trap = 1 if data.get("trapped_victims") else 0
    vic = int(data.get("victim_count", 0))
    src = str(data.get("source", "sms"))
    meth = str(data.get("detection_method", "manual"))
    uid = int(data.get("user_id") or 0)

    return f"SVX1#{lat},{lon}#{veh}#{fire}#{trap}#{vic}#{src}#{meth}#{uid}"


def decode_sms(sms_text: str) -> dict[str, Any]:
    """
    Decodes a compact SolveX SMS payload into a dictionary matching ReportCreate.
    """
    clean = sms_text.strip()
    if not clean.startswith("SVX1#"):
        raise ValueError("Invalid SolveX SMS header. Expected 'SVX1#' prefix.")

    parts = clean.split("#")
    if len(parts) < 9:
        raise ValueError(
            f"Malformed SolveX SMS payload: Expected 9 fields, got {len(parts)}."
        )

    coords = parts[1].split(",")
    if len(coords) != 2:
        raise ValueError(f"Invalid coordinate format in SMS: {parts[1]}")

    lat = float(coords[0])
    lon = float(coords[1])
    veh = int(parts[2])
    fire = bool(int(parts[3]))
    trap = bool(int(parts[4]))
    vic = int(parts[5])
    src = parts[6]
    meth = parts[7]
    uid_raw = int(parts[8])
    uid = uid_raw if uid_raw > 0 else None

    return {
        "latitude": lat,
        "longitude": lon,
        "vehicle_count": veh,
        "fire": fire,
        "trapped_victims": trap,
        "victim_count": vic,
        "source": "sms",
        "detection_method": f"sms_{meth}",
        "user_id": uid,
        "received_via_sms": True,
    }

