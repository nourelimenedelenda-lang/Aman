"""
app/routers/services.py: Emergency services directory and blackspot queries.

Endpoints:
  GET /services            - List emergency responders, hospitals, and towing fleets
  GET /services/blackspots - List geofenced Algerian accident blackspots (points noirs)
  GET /services/nearest    - Find nearest responders to given coordinates
"""
from typing import Any, List, Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from ..database import get_db
from ..logic.dispatch import find_nearest_services
from ..models import Blackspot, Service
from ..schemas import BlackspotRead, ServiceRead

router = APIRouter(prefix="/services", tags=["Services Directory"])


@router.get("", response_model=List[ServiceRead])
def list_services(
    type: Optional[str] = Query(
        None,
        description="Filter by type: hospital, protection_civile, gendarmerie, police, towing",
    ),
    wilaya: Optional[str] = Query(None, description="Filter by Algerian Wilaya (e.g., Alger, Blida, Bouira)"),
    db: Session = Depends(get_db),
):
    """
    Returns the directory of emergency healthcare facilities and first responders.
    """
    query = db.query(Service)
    if type:
        query = query.filter(Service.type == type)
    if wilaya:
        query = query.filter(Service.wilaya == wilaya)
    return query.all()


@router.get("/blackspots", response_model=List[BlackspotRead])
def list_blackspots(db: Session = Depends(get_db)):
    """
    Returns all geofenced accident blackspots (Points Noirs) across the national road network.
    """
    return db.query(Blackspot).all()


@router.get("/nearest")
def get_nearest_services(
    latitude: float = Query(..., ge=-90.0, le=90.0, description="Latitude coordinate"),
    longitude: float = Query(..., ge=-180.0, le=180.0, description="Longitude coordinate"),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    """
    Calculates distance and identifies the nearest hospital, Protection Civile station,
    Gendarmerie brigade, and towing service.
    """
    return find_nearest_services(db, latitude, longitude)

