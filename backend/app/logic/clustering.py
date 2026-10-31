"""
app/logic/clustering.py: Spatial-temporal incident clustering and data aggregation engine.

Core responsibilities:
  1. Geospatial & Time Clustering: Reports within 500 meters and 15 minutes are merged
     into a single Incident entity.
  2. Maximum Hazard Principle: Merges report attributes to reflect the highest severity
     (e.g., maximum vehicles involved, any fire flag, any trapped victim flag).
  3. Consensus & Cross-Verification Logic: Tracks independent witnesses, sensor triggers,
     and confirms human-in-the-loop validation.
  4. Dynamic Re-Scoring: Recalculates total score (0-100) and intervention tier upon each report.
"""
import math
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy.orm import Session

from ..config import CLUSTER_RADIUS_METERS, CLUSTER_TIME_WINDOW_MINUTES
from ..models import Blackspot, Incident, Report, User
from .scoring import calculate_incident_score


def haversine_distance_meters(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculates great-circle distance between two GPS coordinates in meters.
    """
    R = 6371000.0  # Earth radius in meters
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = (
        math.sin(delta_phi / 2.0) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0) ** 2
    )
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return R * c


def check_blackspot_proximity(db: Session, lat: float, lon: float) -> tuple[bool, Optional[int]]:
    """
    Checks if coordinates fall inside any geofenced accident blackspot (point noir).
    Returns (in_blackspot, blackspot_id).
    """
    blackspots = db.query(Blackspot).all()
    for spot in blackspots:
        dist = haversine_distance_meters(lat, lon, spot.latitude, spot.longitude)
        if dist <= spot.radius_m:
            return True, spot.id
    return False, None


def check_user_medical_risk(db: Session, user_id: Optional[int]) -> bool:
    """
    Checks if the user has an Emergency Health Passport with high-risk conditions
    (e.g., diabetes, heart disease, severe allergies, pacemaker).
    """
    if not user_id:
        return False
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        return False

    conditions = (user.chronic_conditions or "").lower()
    devices = (user.implanted_devices or "").lower()
    high_risk_keywords = [
        "diabetes",
        "diabète",
        "heart",
        "cardiaque",
        "hypertension",
        "asthma",
        "asthme",
        "epilepsy",
        "épilepsie",
        "pacemaker",
    ]

    return any(k in conditions or k in devices for k in high_risk_keywords)


def find_matching_incident(
    db: Session, lat: float, lon: float, timestamp: datetime
) -> Optional[Incident]:
    """
    Searches for an active incident within 500m and 15 minutes.
    """
    cutoff_time = timestamp - timedelta(minutes=CLUSTER_TIME_WINDOW_MINUTES)
    active_incidents = (
        db.query(Incident)
        .filter(Incident.status.in_(["open", "verified"]))
        .filter(Incident.created_at >= cutoff_time)
        .all()
    )

    for inc in active_incidents:
        dist = haversine_distance_meters(lat, lon, inc.latitude, inc.longitude)
        if dist <= CLUSTER_RADIUS_METERS:
            return inc
    return None


def ingest_report(db: Session, report_data: dict) -> tuple[Incident, Report]:
    """
    Ingests an incoming report, merges it with an existing cluster or creates a new Incident,
    applies the Maximum Hazard Principle, updates consensus, re-scores, and persists to DB.
    """
    now = datetime.utcnow()
    lat = report_data["latitude"]
    lon = report_data["longitude"]
    source = report_data.get("source", "witness")
    user_id = report_data.get("user_id")

    # 1. Search for existing spatial-temporal cluster
    incident = find_matching_incident(db, lat, lon, now)

    is_new_incident = incident is None
    if is_new_incident:
        in_blackspot, blackspot_id = check_blackspot_proximity(db, lat, lon)
        incident = Incident(
            latitude=lat,
            longitude=lon,
            created_at=now,
            updated_at=now,
            status="open",
            vehicle_count=report_data.get("vehicle_count", 1),
            victim_count=report_data.get("victim_count", 0),
            fire=report_data.get("fire", False),
            trapped_victims=report_data.get("trapped_victims", False),
            in_blackspot=in_blackspot,
            blackspot_id=blackspot_id,
        )
        db.add(incident)
        db.flush()
    else:
        # Maximum Hazard Principle: adopt highest reported metrics
        incident.vehicle_count = max(
            incident.vehicle_count, report_data.get("vehicle_count", 1)
        )
        incident.victim_count = max(
            incident.victim_count, report_data.get("victim_count", 0)
        )
        incident.fire = incident.fire or report_data.get("fire", False)
        incident.trapped_victims = (
            incident.trapped_victims or report_data.get("trapped_victims", False)
        )
        incident.updated_at = now

    # 2. Consensus & witness accounting
    if source in ["witness", "dispatcher"]:
        incident.witness_count += 1
        if incident.sensor_triggered:
            incident.human_confirmed = True
    elif source == "sensor":
        incident.sensor_triggered = True
        if incident.witness_count > 0:
            incident.human_confirmed = True

    # 3. Medical risk flag evaluation
    if check_user_medical_risk(db, user_id):
        incident.high_risk_health = True

    # 4. Environmental context heuristic: nighttime between 20:00 and 06:00
    current_hour = now.hour
    incident.is_night = current_hour >= 20 or current_hour < 6

    # 5. Dynamic re-scoring
    score, level = calculate_incident_score(incident)
    incident.score = score
    incident.level = level

    # 6. Save report record
    report = Report(
        incident_id=incident.id,
        user_id=user_id,
        latitude=lat,
        longitude=lon,
        timestamp=now,
        source=source,
        detection_method=report_data.get("detection_method"),
        vehicle_count=report_data.get("vehicle_count", 1),
        victim_count=report_data.get("victim_count", 0),
        fire=report_data.get("fire", False),
        trapped_victims=report_data.get("trapped_victims", False),
        audio_note_path=report_data.get("audio_note_path"),
        received_via_sms=report_data.get("received_via_sms", False),
    )
    db.add(report)
    db.commit()
    db.refresh(incident)
    db.refresh(report)

    return incident, report

