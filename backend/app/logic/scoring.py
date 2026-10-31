"""
app/logic/scoring.py: Dynamic Priority and Severity Index calculation engine.

Implements the official point allocation matrix from Section 3.B of SolveX 3.0:
Evaluates 5 weight layers:
  1. Consolidated On-Scene Attributes (fire, trapped victims, casualty count, high-risk health)
  2. Spatial & Road Context (blackspots, high-speed corridors)
  3. Environmental & Weather Conditions (severe weather, nighttime)
  4. Multi-Witness Density & Sensor Verification (3+ reports, sensor + human consensus)
  5. Perimeter Traffic Anomaly (multi-user speed drop)

Outputs a score clamped between 0 and 100, and assigns intervention tier:
  - RED    (70-100 pts): Critical / Immediate auto-dispatch
  - YELLOW (35-69 pts):  Warning / Queued for operator verification
  - BLUE   (0-34 pts):   Info / Monitoring & towing fleet notification
"""
from ..config import SCORE_THRESHOLD_RED, SCORE_THRESHOLD_YELLOW
from ..models import Incident


def calculate_incident_score(incident: Incident) -> tuple[int, str]:
    """
    Computes the total priority score (0-100) and maps it to the triage tier.

    :param incident: Consolidated incident database entity
    :return: (score, level) where level is "RED", "YELLOW", or "BLUE"
    """
    score = 0

    # -------------------------------------------------------------------------
    # Layer 1: Consolidated On-Scene Attributes (Forms & Audio)
    # -------------------------------------------------------------------------
    # Presence of fire, fuel leaks, or trapped victims (désincarcération needed)
    if incident.fire or incident.trapped_victims:
        score += 25

    # High casualty/victim count (> 3 injured or unconscious persons)
    if incident.victim_count > 3:
        score += 20

    # High-Risk User Health Condition Flag (Medical Risk Boost)
    # e.g., victim with diabetes, heart condition, severe blood loss risk, pacemaker
    if incident.high_risk_health:
        score += 15

    # Multiple vehicle collision (> 2 vehicles involved)
    if incident.vehicle_count > 2:
        score += 10

    # -------------------------------------------------------------------------
    # Layer 2: Spatial & Road Infrastructure Context
    # -------------------------------------------------------------------------
    # Incident located inside a geofenced Accident Blackspot / Point Noir (e.g., Chiffa, Lakhdaria)
    if incident.in_blackspot:
        score += 20

    # Incident on a high-speed national corridor (Autoroute Est-Ouest, RN1, RN3)
    if incident.on_national_corridor:
        score += 10

    # -------------------------------------------------------------------------
    # Layer 3: Real-Time Environmental & Weather Conditions
    # -------------------------------------------------------------------------
    # Severe weather active in area (dense fog, heavy rain, snow/black ice)
    if incident.severe_weather:
        score += 15

    # Nighttime / unlit road segment
    if incident.is_night:
        score += 10

    # -------------------------------------------------------------------------
    # Layer 4: Multi-Witness Density & Report Volume
    # -------------------------------------------------------------------------
    # High-density confirmation: 3 or more independent witness reports
    if incident.witness_count >= 3:
        score += 15

    # Sensor + Human cross-verification: Automated kinetic/speed drop alert confirmed by >= 1 human form
    if incident.sensor_triggered and incident.human_confirmed:
        score += 15

    # -------------------------------------------------------------------------
    # Layer 5: Perimeter Traffic Anomaly
    # -------------------------------------------------------------------------
    # Cluster correlation: Multiple app users within 500m drop speed to 0 km/h simultaneously
    if incident.perimeter_anomaly:
        score += 10

    # Total score is clamped to the 0-100 range
    final_score = min(100, max(0, score))

    # Determine action level
    if final_score >= SCORE_THRESHOLD_RED:
        level = "RED"
    elif final_score >= SCORE_THRESHOLD_YELLOW:
        level = "YELLOW"
    else:
        level = "BLUE"

    return final_score, level

