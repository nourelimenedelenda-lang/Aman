"""
app/routers/users.py: Emergency Health Passport CRUD endpoints.

Allows drivers and citizens to register and maintain their personal medical profile:
  - Blood type
  - Chronic conditions (e.g. diabetes, hypertension, asthma, epilepsy)
  - Severe allergies (e.g. penicillin)
  - Implanted medical devices (e.g. pacemakers)
  - Emergency contact numbers
  - Insurance policy numbers for rapid post-accident claim processing
"""
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import User
from ..schemas import UserCreate, UserRead, UserUpdate

router = APIRouter(prefix="/users", tags=["Users & Health Passports"])


@router.post("", response_model=UserRead)
def create_user(payload: UserCreate, db: Session = Depends(get_db)):
    """
    Registers a new user and creates their Emergency Health Passport.
    """
    user = User(**payload.model_dump())
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.get("/{user_id}", response_model=UserRead)
def get_user(user_id: int, db: Session = Depends(get_db)):
    """
    Retrieves the Emergency Health Passport of a user by ID.
    """
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User profile not found")
    return user


@router.put("/{user_id}", response_model=UserRead)
def update_user(user_id: int, payload: UserUpdate, db: Session = Depends(get_db)):
    """
    Updates medical attributes, emergency contact, or insurance policy information.
    """
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User profile not found")

    update_fields = payload.model_dump(exclude_unset=True)
    for field, val in update_fields.items():
        setattr(user, field, val)

    db.commit()
    db.refresh(user)
    return user


@router.get("", response_model=List[UserRead])
def list_users(limit: int = 50, db: Session = Depends(get_db)):
    """
    Lists registered users (helpful for testing and administration).
    """
    return db.query(User).limit(limit).all()

