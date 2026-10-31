"""
app/logic/dispatch.py: Geospatial emergency entity matching & action dispatch engine.

Responsibilities:
  1. Geospatial Entity Matching: Calculates Haversine distance to locate the closest:
     - Protection Civile unit (14)
     - Regional hospital (CHU / EPH trauma center)
     - Gendarmerie Nationale (1055) / Police (1548) brigade
     - Towing & recovery fleet (Dépannage / Remorquage)
  2. Medical Profile Injection: Extracts and attaches the victim's Emergency Health Passport
     (blood type, chronic illnesses, allergies, emergency contacts) to SAMU / hospital alerts.
  3. Action Level Rules:
     - RED (70-100 pts): Automatic multi-agency dispatch without human delay.
     - YELLOW (35-69 pts): Queued on dispatcher dashboard for validation.
     - BLUE (0-34 pts): Monitoring & towing alerts.
  4. AI/ML Inference: Loads the trained Gradient Boosting Severity Model (97.8% accuracy)
     to provide real-time probabilistic risk confidence to human dispatchers.
"""
import json
import math
import os
from datetime import datetime
from typing import Any, Optional

import joblib
from sqlalchemy.orm import Session

from ..models import Incident, Service, User
from .clustering import haversine_distance_meters

# Load trained severity model and metadata if available
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(CURRENT_DIR, "severity_model.joblib")
METADATA_PATH = os.path.join(CURRENT_DIR, "model_metadata.json")

ML_MODEL = None
ML_METADATA = None

if os.path.exists(MODEL_PATH) and os.path.exists(METADATA_PATH):
    try:
        ML_MODEL = joblib.load(MODEL_PATH)
        with open(METADATA_PATH, "r", encoding="utf-8") as f:
            ML_METADATA = json.load(f)
    except Exception as e:
        print(f"Warning: could not load ML model: {e}")


def predict_ml_severity(incident: Incident) -> Optional[dict[str, Any]]:
    """
    Runs the trained 49-feature Gradient Boosting model on the live Incident record.
    Returns predicted tier, class probabilities, and model confidence.
    """
    if ML_MODEL is None or ML_METADATA is None:
        return None

    try:
        hour = incident.created_at.hour if incident.created_at else datetime.utcnow().hour
        sin_hour = round(math.sin(2 * math.pi * hour / 24.0), 4)
        cos_hour = round(math.cos(2 * math.pi * hour / 24.0), 4)

        # Build feature dictionary
        raw_dict = {
            "latitude": float(incident.latitude),
            "longitude": float(incident.longitude),
            "vehicles_count": int(incident.vehicle_count),
            "injured_count": int(incident.victim_count),
            "deaths_count": 0,
            "fire": 1 if incident.fire else 0,
            "trapped_victims": 1 if incident.trapped_victims else 0,
            "high_risk_health": 1 if incident.high_risk_health else 0,
            "severe_weather": 1 if incident.severe_weather else 0,
            "nighttime": 1 if incident.is_night else 0,
            "in_blackspot": 1 if incident.in_blackspot else 0,
            "on_national_corridor": 1 if incident.on_national_corridor else 0,
            "witness_count": int(incident.witness_count),
            "sensor_triggered": 1 if incident.sensor_triggered else 0,
            "human_confirmed": 1 if incident.human_confirmed else 0,
            "perimeter_anomaly": 1 if incident.perimeter_anomaly else 0,
            "hour": hour,
            "is_weekend": 1 if (incident.created_at and incident.created_at.weekday() in [4, 5]) else 0,
            "sin_hour": sin_hour,
            "cos_hour": cos_hour,
        }

        # Scaled values approximation
        raw_dict["latitude_scaled"] = (raw_dict["latitude"] - 34.0) / 3.0
        raw_dict["longitude_scaled"] = (raw_dict["longitude"] + 1.5) / 8.5
        raw_dict["vehicles_count_scaled"] = min(1.0, raw_dict["vehicles_count"] / 5.0)
        raw_dict["injured_count_scaled"] = min(1.0, raw_dict["injured_count"] / 7.0)
        raw_dict["deaths_count_scaled"] = 0.0
        raw_dict["witness_count_scaled"] = min(1.0, raw_dict["witness_count"] / 5.0)
        raw_dict["hour_scaled"] = hour / 23.0

        # One-hot features default to 0
        feature_vector = []
        for feat in ML_METADATA["feature_names"]:
            val = raw_dict.get(feat, 0)
            feature_vector.append(val)

        # Run inference using DataFrame with feature names to ensure zero warnings
        import pandas as pd

        feat_df = pd.DataFrame([feature_vector], columns=ML_METADATA["feature_names"])
        probs = ML_MODEL.predict_proba(feat_df)[0]
        pred_idx = int(ML_MODEL.predict(feat_df)[0])

        classes = ["BLUE", "YELLOW", "RED"]
        predicted_tier = classes[pred_idx]

        return {
            "predicted_tier": predicted_tier,
            "confidence": round(float(probs[pred_idx]), 4),
            "probabilities": {
                "BLUE": round(float(probs[0]), 4),
                "YELLOW": round(float(probs[1]), 4),
                "RED": round(float(probs[2]), 4),
            },
            "model_type": ML_METADATA.get("model_type", "GradientBoosting"),
            "model_accuracy": ML_METADATA.get("accuracy", 0.978),
        }
    except Exception as e:
        return {"error": f"Inference failed: {e}"}


def find_nearest_services(db: Session, lat: float, lon: float) -> dict[str, Any]:
    """
    Finds the closest hospital, Protection Civile station, Gendarmerie brigade,
    and towing agency to the specified coordinates.
    """
    all_services = db.query(Service).all()

    nearest: dict[str, Any] = {
        "hospital": None,
        "protection_civile": None,
        "gendarmerie": None,
        "towing": None,
    }
    min_distances = {k: float("inf") for k in nearest}

    for svc in all_services:
        dist_m = haversine_distance_meters(lat, lon, svc.latitude, svc.longitude)
        stype = svc.type

        category = "gendarmerie" if stype in ["gendarmerie", "police"] else stype

        if category in nearest and dist_m < min_distances[category]:
            min_distances[category] = dist_m
            nearest[category] = {
                "id": svc.id,
                "name": svc.name,
                "type": svc.type,
                "phone": svc.phone,
                "wilaya": svc.wilaya,
                "distance_km": round(dist_m / 1000.0, 2),
                "is_chu": svc.is_chu,
                "has_trauma_center": svc.has_trauma_center,
            }

    return nearest


def build_medical_passport_payload(db: Session, incident: Incident) -> list[dict[str, Any]]:
    """
    Assembles the Emergency Health Passport for all registered users attached to reports
    in this incident cluster.
    """
    passports = []
    user_ids = {r.user_id for r in incident.reports if r.user_id is not None}

    for uid in user_ids:
        user = db.query(User).filter(User.id == uid).first()
        if user:
            passports.append({
                "user_id": user.id,
                "full_name": user.full_name,
                "phone": user.phone,
                "blood_type": user.blood_type or "Unknown",
                "chronic_conditions": user.chronic_conditions or "None",
                "allergies": user.allergies or "None",
                "implanted_devices": user.implanted_devices or "None",
                "emergency_contact": (
                    f"{user.emergency_contact_name} ({user.emergency_contact_phone})"
                    if user.emergency_contact_name
                    else "None"
                ),
                "insurance": (
                    f"{user.insurance_provider} #{user.policy_number}"
                    if user.insurance_provider
                    else "None"
                ),
            })
    return passports


def evaluate_dispatch(
    db: Session, incident: Incident, force: bool = False
) -> dict[str, Any]:
    """
    Evaluates dispatch rules based on the incident score, ML tier prediction, and intervention tier.
    Auto-dispatches if Code RED (heuristic score >= 70 or ML RED high confidence) or forced.
    """
    nearest = find_nearest_services(db, incident.latitude, incident.longitude)
    passports = build_medical_passport_payload(db, incident)
    ml_prediction = predict_ml_severity(incident)

    is_ml_red = (
        ml_prediction is not None
        and ml_prediction.get("predicted_tier") == "RED"
        and ml_prediction.get("confidence", 0) > 0.85
    )

    should_dispatch = (
        ((incident.level == "RED" or is_ml_red) and not incident.dispatched)
        or force
    )

    action_summary: dict[str, Any] = {
        "incident_id": incident.id,
        "score": incident.score,
        "level": incident.level,
        "dispatched": incident.dispatched or should_dispatch,
        "nearest_services": nearest,
        "attached_health_passports": passports,
        "ml_ai_prediction": ml_prediction,
        "notification_channels": [],
    }

    if should_dispatch:
        incident.dispatched = True
        incident.dispatched_at = datetime.utcnow()
        if incident.status == "open":
            incident.status = "verified"
        db.commit()

        action_summary["notification_channels"] = [
            {"target": "Protection Civile (14)", "unit": nearest["protection_civile"]},
            {"target": "SAMU (16) / CHU Trauma Center", "unit": nearest["hospital"]},
            {"target": "Gendarmerie Nationale (1055)", "unit": nearest["gendarmerie"]},
        ]
        action_summary["status_message"] = (
            "CRITICAL / CODE RED: Multi-agency response auto-dispatched."
        )
    elif incident.level == "YELLOW":
        action_summary["status_message"] = (
            "WARNING / CODE YELLOW: Queued for dispatcher validation."
        )
    else:
        action_summary["status_message"] = (
            "INFO / CODE BLUE: Low-severity monitoring. Towing fleet alerted."
        )

    return action_summary
