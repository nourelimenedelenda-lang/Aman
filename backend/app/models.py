"""
app/models.py: database tables for SolveX.

Tables:
  User       Emergency Health Passport
  Incident   consolidated incident entity (one per real-world accident)
  Report     one witness / sensor / dispatcher submission, attached to an Incident
  Service    hospitals, Protection Civile, Gendarmerie, Police, towing
  Blackspot  geofenced accident blackspots (points noirs)

Assumes app/database.py exposes `Base = declarative_base()`.
"""

from datetime import datetime

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import relationship

from .database import Base


# ---------------------------------------------------------------------------
# User: Emergency Health Passport
# ---------------------------------------------------------------------------
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    full_name = Column(String(120), nullable=False)
    phone = Column(String(20), unique=True, index=True)

    # Emergency Health Passport
    blood_type = Column(String(5))                 # e.g. "O+", "AB-"
    chronic_conditions = Column(Text, default="")  # comma-separated: "diabetes,hypertension"
    allergies = Column(Text, default="")           # comma-separated: "penicillin"
    implanted_devices = Column(Text, default="")   # comma-separated: "pacemaker"
    emergency_contact_name = Column(String(120))
    emergency_contact_phone = Column(String(20))

    # Insurance (rapid claim processing)
    insurance_provider = Column(String(120))
    policy_number = Column(String(60))

    created_at = Column(DateTime, default=datetime.utcnow)

    reports = relationship("Report", back_populates="user")


# ---------------------------------------------------------------------------
# Incident: consolidated entity with score and level
# ---------------------------------------------------------------------------
class Incident(Base):
    __tablename__ = "incidents"

    id = Column(Integer, primary_key=True, index=True)

    # Location (centroid / first report) and timing
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Lifecycle: open -> verified -> resolved
    status = Column(String(20), default="open", index=True)

    # Consolidated on-scene attributes (Maximum Hazard Principle)
    vehicle_count = Column(Integer, default=1)
    victim_count = Column(Integer, default=0)
    fire = Column(Boolean, default=False)            # fire or fuel leak
    trapped_victims = Column(Boolean, default=False)  # désincarcération needed
    high_risk_health = Column(Boolean, default=False)  # victim with high-risk condition

    # Multi-witness density and verification
    witness_count = Column(Integer, default=0)       # independent human reports
    sensor_triggered = Column(Boolean, default=False)
    human_confirmed = Column(Boolean, default=False)  # sensor + at least 1 human form
    perimeter_anomaly = Column(Boolean, default=False)  # several users dropped to 0 km/h

    # Context flags (filled at ingestion time)
    in_blackspot = Column(Boolean, default=False)
    on_national_corridor = Column(Boolean, default=False)  # Autoroute E-O, RN1, RN3
    severe_weather = Column(Boolean, default=False)
    is_night = Column(Boolean, default=False)
    blackspot_id = Column(Integer, ForeignKey("blackspots.id"), nullable=True)

    # Result of scoring.py
    score = Column(Integer, default=0, index=True)    # 0-100
    level = Column(String(10), default="BLUE")        # RED / YELLOW / BLUE

    # Dispatch tracking
    dispatched = Column(Boolean, default=False)
    dispatched_at = Column(DateTime, nullable=True)

    reports = relationship(
        "Report", back_populates="incident", cascade="all, delete-orphan"
    )
    blackspot = relationship("Blackspot", back_populates="incidents")


# ---------------------------------------------------------------------------
# Report: one witness / sensor / dispatcher submission
# ---------------------------------------------------------------------------
class Report(Base):
    __tablename__ = "reports"

    id = Column(Integer, primary_key=True, index=True)
    incident_id = Column(Integer, ForeignKey("incidents.id"), index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)

    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow)

    # "witness" | "sensor" | "dispatcher" | "sms"
    source = Column(String(20), default="witness")
    # e.g. "form", "speed_drop", "off_road", "high_g", "acoustic",
    #      "barometer", "bluetooth_cut", "no_response_timeout"
    detection_method = Column(String(40))

    # 3-tap triage form fields
    vehicle_count = Column(Integer, default=1)
    victim_count = Column(Integer, default=0)
    fire = Column(Boolean, default=False)
    trapped_victims = Column(Boolean, default=False)

    audio_note_path = Column(String(255), nullable=True)
    received_via_sms = Column(Boolean, default=False)

    incident = relationship("Incident", back_populates="reports")
    user = relationship("User", back_populates="reports")


# ---------------------------------------------------------------------------
# Service: hospitals, responders, towing
# ---------------------------------------------------------------------------
class Service(Base):
    __tablename__ = "services"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(150), nullable=False)

    # "hospital" | "protection_civile" | "gendarmerie" | "police" | "towing"
    type = Column(String(30), nullable=False, index=True)

    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    wilaya = Column(String(60))
    phone = Column(String(20))

    # Hospitals only
    is_chu = Column(Boolean, default=False)            # CHU vs EPH
    has_trauma_center = Column(Boolean, default=False)


# ---------------------------------------------------------------------------
# Blackspot: geofenced accident blackspot (point noir)
# ---------------------------------------------------------------------------
class Blackspot(Base):
    __tablename__ = "blackspots"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(120), nullable=False)         # e.g. "Chiffa", "Lakhdaria"
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    radius_m = Column(Integer, default=1000)           # geofence radius
    wilaya = Column(String(60))

    incidents = relationship("Incident", back_populates="blackspot")