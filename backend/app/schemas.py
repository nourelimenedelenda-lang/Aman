"""Pydantic request and response schemas for the SolveX API."""

from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field


class ORMModel(BaseModel):
	"""Base schema for serializing SQLAlchemy model instances."""

	model_config = ConfigDict(from_attributes=True)


# ---------------------------------------------------------------------------
# Reports and incidents
# ---------------------------------------------------------------------------
class ReportCreate(BaseModel):
	"""A witness, sensor, dispatcher, or SMS incident submission."""

	latitude: float = Field(ge=-90, le=90)
	longitude: float = Field(ge=-180, le=180)
	user_id: Optional[int] = Field(default=None, gt=0)
	source: Literal["witness", "sensor", "dispatcher", "sms"] = "witness"
	detection_method: Optional[str] = Field(default=None, max_length=40)
	vehicle_count: int = Field(default=1, ge=1)
	victim_count: int = Field(default=0, ge=0)
	fire: bool = False
	trapped_victims: bool = False
	audio_note_path: Optional[str] = Field(default=None, max_length=255)
	received_via_sms: bool = False


class ReportRead(ORMModel):
	id: int
	incident_id: Optional[int] = None
	user_id: Optional[int] = None
	latitude: float
	longitude: float
	timestamp: datetime
	source: str
	detection_method: Optional[str] = None
	vehicle_count: int
	victim_count: int
	fire: bool
	trapped_victims: bool
	audio_note_path: Optional[str] = None
	received_via_sms: bool


class IncidentStatusUpdate(BaseModel):
	status: Literal["open", "verified", "resolved"]


class IncidentRead(ORMModel):
	id: int
	latitude: float
	longitude: float
	created_at: datetime
	updated_at: datetime
	status: str
	vehicle_count: int
	victim_count: int
	fire: bool
	trapped_victims: bool
	high_risk_health: bool
	witness_count: int
	sensor_triggered: bool
	human_confirmed: bool
	perimeter_anomaly: bool
	in_blackspot: bool
	on_national_corridor: bool
	severe_weather: bool
	is_night: bool
	blackspot_id: Optional[int] = None
	score: int
	level: str
	dispatched: bool
	dispatched_at: Optional[datetime] = None
	reports: List[ReportRead] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Emergency Health Passport
# ---------------------------------------------------------------------------
class UserCreate(BaseModel):
	full_name: str = Field(min_length=1, max_length=120)
	phone: Optional[str] = Field(default=None, max_length=20)
	blood_type: Optional[str] = Field(default=None, max_length=5)
	chronic_conditions: Optional[str] = None
	allergies: Optional[str] = None
	implanted_devices: Optional[str] = None
	emergency_contact_name: Optional[str] = Field(default=None, max_length=120)
	emergency_contact_phone: Optional[str] = Field(default=None, max_length=20)
	insurance_provider: Optional[str] = Field(default=None, max_length=120)
	policy_number: Optional[str] = Field(default=None, max_length=60)


class UserUpdate(BaseModel):
	full_name: Optional[str] = Field(default=None, min_length=1, max_length=120)
	phone: Optional[str] = Field(default=None, max_length=20)
	blood_type: Optional[str] = Field(default=None, max_length=5)
	chronic_conditions: Optional[str] = None
	allergies: Optional[str] = None
	implanted_devices: Optional[str] = None
	emergency_contact_name: Optional[str] = Field(default=None, max_length=120)
	emergency_contact_phone: Optional[str] = Field(default=None, max_length=20)
	insurance_provider: Optional[str] = Field(default=None, max_length=120)
	policy_number: Optional[str] = Field(default=None, max_length=60)


class UserRead(ORMModel):
	id: int
	full_name: str
	phone: Optional[str] = None
	blood_type: Optional[str] = None
	chronic_conditions: Optional[str] = None
	allergies: Optional[str] = None
	implanted_devices: Optional[str] = None
	emergency_contact_name: Optional[str] = None
	emergency_contact_phone: Optional[str] = None
	insurance_provider: Optional[str] = None
	policy_number: Optional[str] = None
	created_at: datetime


# ---------------------------------------------------------------------------
# Service and blackspot directory
# ---------------------------------------------------------------------------
class ServiceRead(ORMModel):
	id: int
	name: str
	type: str
	latitude: float
	longitude: float
	wilaya: Optional[str] = None
	phone: Optional[str] = None
	is_chu: bool
	has_trauma_center: bool


class BlackspotRead(ORMModel):
	id: int
	name: str
	latitude: float
	longitude: float
	radius_m: int
	wilaya: Optional[str] = None
