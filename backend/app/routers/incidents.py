"""
app/routers/incidents.py: Incident intake and dispatcher triage endpoints for SolveX.

Endpoints:
  POST  /incidents/report         - Ingest witness form or sensor trigger
  POST  /incidents/sms-inbound    - Ingest offline 2G GSM SMS payload
  GET   /incidents                - Ranked dispatcher feed (score DESC)
  GET   /incidents/{incident_id}  - Full incident entity with all consolidated reports
  PATCH /incidents/{incident_id}/status - Status update (open -> verified -> resolved)
  POST  /incidents/{incident_id}/dispatch - Manual dispatcher force-dispatch
"""
import os
from typing import Any, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from ..database import get_db
from ..logic.clustering import ingest_report
from ..logic.dispatch import evaluate_dispatch
from ..logic.sms import decode_sms
from ..models import Incident
from ..schemas import IncidentRead, IncidentStatusUpdate, ReportCreate

router = APIRouter(prefix="/incidents", tags=["Incidents"])


@router.post("/report", response_model=dict)
def submit_report(payload: ReportCreate, db: Session = Depends(get_db)):
    """
    Ingests a witness triage form or an automated sensor trigger (speed drop, high-G).
    Clusters with existing incidents within 500m / 15min, recalculates the priority score,
    and executes auto-dispatch if Code RED.
    """
    incident, report = ingest_report(db, payload.model_dump())
    dispatch_info = evaluate_dispatch(db, incident)

    return {
        "status": "success",
        "incident_id": incident.id,
        "score": incident.score,
        "level": incident.level,
        "cluster_witness_count": incident.witness_count,
        "report_id": report.id,
        "dispatch_summary": dispatch_info,
    }


@router.post("/sms-inbound", response_model=dict)
def receive_sms_report(
    sms_text: str = Query(..., description="Raw SMS string in SVX1# format"),
    db: Session = Depends(get_db),
):
    """
    Receives an offline 2G GSM SMS message from remote dead zones.
    Decodes the compact string and feeds it directly into the clustering pipeline.
    """
    try:
        report_data = decode_sms(sms_text)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    incident, report = ingest_report(db, report_data)
    dispatch_info = evaluate_dispatch(db, incident)

    return {
        "status": "success",
        "message": "2G SMS report ingested and clustered successfully.",
        "incident_id": incident.id,
        "score": incident.score,
        "level": incident.level,
        "report_id": report.id,
        "dispatch_summary": dispatch_info,
    }


@router.get("", response_model=List[IncidentRead])
def list_incidents(
    status: Optional[str] = Query(None, description="Filter: open, verified, resolved"),
    level: Optional[str] = Query(None, description="Filter: RED, YELLOW, BLUE"),
    db: Session = Depends(get_db),
):
    """
    Returns incidents for the central emergency dispatcher dashboard.
    Ranked strictly by Priority Score descending (Code RED at top), then created_at descending.
    """
    query = db.query(Incident)
    if status:
        query = query.filter(Incident.status == status)
    if level:
        query = query.filter(Incident.level == level)

    return query.order_by(Incident.score.desc(), Incident.created_at.desc()).all()


@router.get("/{incident_id}", response_model=IncidentRead)
def get_incident(incident_id: int, db: Session = Depends(get_db)):
    """
    Retrieves a single incident by ID with all merged witness and sensor reports.
    """
    incident = db.query(Incident).filter(Incident.id == incident_id).first()
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")
    return incident


@router.patch("/{incident_id}/status", response_model=IncidentRead)
def update_incident_status(
    incident_id: int,
    payload: IncidentStatusUpdate,
    db: Session = Depends(get_db),
):
    """
    Updates the lifecycle status of an incident (open -> verified -> resolved).
    """
    incident = db.query(Incident).filter(Incident.id == incident_id).first()
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")

    incident.status = payload.status
    db.commit()
    db.refresh(incident)
    return incident


@router.post("/{incident_id}/dispatch", response_model=dict)
def trigger_manual_dispatch(incident_id: int, db: Session = Depends(get_db)):
    """
    Allows a human dispatcher to force dispatch units for Warning / Code Yellow incidents.
    """
    incident = db.query(Incident).filter(Incident.id == incident_id).first()
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")

    return evaluate_dispatch(db, incident, force=True)
