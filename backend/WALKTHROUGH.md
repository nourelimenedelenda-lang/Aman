# SolveX Backend — Implementation Plan & Walkthrough

This document establishes the step-by-step implementation plan for the SolveX backend based on [Guide.md](file:///c:/Users/HP/Documents/backend/app/Guide.md) and the SolveX 3.0 emergency ingestion specifications.

---

## 1. High-Level Architecture & Workflow

1. **Ingestion:** Reports arrive from witness 3-tap forms, smartphone sensor triggers (high-G deceleration, rollover), or 2G GSM SMS.
2. **Clustering:** Reports within **500 m** and **15 minutes** merge into an active Incident Entity under the **Maximum Hazard Principle**.
3. **Scoring:** The consolidated incident is evaluated against the 0–100 point Severity Matrix and categorized as **RED**, **YELLOW**, or **BLUE**.
4. **Dispatch:** Code RED triggers automated routing to the nearest Protection Civile (14), SAMU (16), and trauma-equipped CHU with attached victim Emergency Health Passports.
5. **Dashboard:** Dispatchers monitor live incidents sorted by urgency (highest score first).

---

## 2. Phase-by-Phase Build Order

### Phase 1: Environment & Database Foundations
- [ ] **`.env`**: Configure database URL, clustering thresholds (500m, 15min), countdown timeout (45s), and SMS mock key.
- [ ] **`requirements.txt`**: Define lightweight dependencies (`fastapi`, `uvicorn`, `sqlalchemy`, `pydantic`, `python-dotenv`).
- [ ] **`app/config.py`**: Centralize all environment variables and threshold constants into typed settings.
- [ ] **`app/database.py`**: Configure SQLAlchemy engine, `SessionLocal`, base declarative model, and the `get_db` session dependency.
- [ ] **`app/models.py` & `app/schemas.py`**: Review existing ORM models (`User`, `Incident`, `Report`, `Service`, `Blackspot`) and Pydantic schemas to ensure full field compatibility.

---

### Phase 2: Core Intelligence & Domain Logic (`app/logic/`)

#### 1. `scoring.py` — Dynamic Severity Matrix
- [ ] Implement the point allocation rules (0–100 scale):
  - Hazards: Fire / fuel leak / trapped victims (+25)
  - Casualties: More than 3 victims (+20)
  - Health: High-risk condition in user passport (+15)
  - Vehicles: Multiple vehicle collision (+10)
  - Road Context: Inside geofenced blackspot (+20), national corridor (+10)
  - Environmental: Severe weather (+15), nighttime (+10)
  - Verification: 3+ independent witnesses (+15), sensor + human confirmation (+15)
  - Traffic: Multi-user speed drop perimeter anomaly (+10)
- [ ] Map score to action tiers:
  - **RED (70–100 pts):** Critical, automatic multi-agency dispatch.
  - **YELLOW (35–69 pts):** Warning, queued for operator validation.
  - **BLUE (0–34 pts):** Info, low-speed anomaly or towing notification.

#### 2. `clustering.py` — Spatial-Temporal Engine
- [ ] Implement Haversine distance formula to calculate distance in meters between GPS coordinates.
- [ ] Query open incidents within the 500-meter radius and 15-minute time window.
- [ ] Apply **Maximum Hazard Principle** on merge:
  - Keep highest vehicle and casualty counts.
  - Set fire or trapped flags if reported by any witness.
- [ ] Update consensus counters (witness count, sensor-triggered flag, human-confirmed flag).
- [ ] Re-run scoring on every merged report and update DB.

#### 3. `dispatch.py` — Multi-Agency Routing & Medical Passport
- [ ] Implement geospatial nearest-neighbor lookup for:
  - Protection Civile units (14)
  - CHU/EPH hospitals (prioritizing trauma center capability)
  - Gendarmerie Nationale / Police brigades (1055 / 1548)
  - Towing / recovery fleets
- [ ] Assemble the victim’s Emergency Health Passport payload (blood type, chronic illnesses, allergies, emergency contacts).
- [ ] Execute dispatch rules: auto-dispatch on Code RED; generate action payload for dashboard operators on Yellow/Blue.

#### 4. `sms.py` — 2G GSM Resiliency Protocol
- [ ] Define compact delimiter format (e.g. `SVX1#lat,lon#veh#fire#trapped#victims#source#method#userId`).
- [ ] Implement encoder (client-side simulation for dead zones).
- [ ] Implement decoder (parses SMS into standard report payload for clustering).

---

### Phase 3: HTTP API & Endpoints (`app/routers/` & `main.py`)

#### 1. `app/routers/incidents.py`
- [ ] `POST /incidents/report`: Ingest witness/sensor report, cluster, score, and evaluate dispatch.
- [ ] `POST /incidents/sms-inbound`: Endpoint for incoming 2G GSM SMS messages.
- [ ] `GET /incidents`: Central dispatcher view, filtered by status/level, sorted by `score DESC`.
- [ ] `GET /incidents/{id}`: Detailed view with all attached witness reports and telemetry.
- [ ] `PATCH /incidents/{id}/status`: Lifecycle transitions (`open` -> `verified` -> `resolved`).
- [ ] `POST /incidents/{id}/dispatch`: Manual operator override to dispatch units.

#### 2. `app/routers/users.py`
- [ ] `POST /users`: Register user and Emergency Health Passport.
- [ ] `GET /users/{id}`: Retrieve medical profile.
- [ ] `PUT /users/{id}`: Update chronic illnesses, allergies, blood type, and emergency contacts.

#### 3. `app/routers/services.py`
- [ ] `GET /services`: Directory of hospitals, Protection Civile, Gendarmerie, and towing units.
- [ ] `GET /services/blackspots`: List active geofenced blackspots (Points Noirs).
- [ ] `GET /services/nearest`: Quick lookup for closest responder from arbitrary coordinates.

#### 4. `app/main.py`
- [ ] Initialize FastAPI application with metadata.
- [ ] Configure CORS middleware for mobile app and web dashboard access.
- [ ] Register routers (`incidents`, `users`, `services`).
- [ ] Auto-create database tables on startup.
- [ ] Provide basic health check endpoint (`GET /`).

---

### Phase 4: Algerian Infrastructure Seed Data & Verification

#### 1. `seed.py`
- [ ] Populate known Algerian accident blackspots (Gorges de Chiffa RN1, Gorges de Lakhdaria AEO/RN5, Descente de Djebahia, Col des 2 Bassins).
- [ ] Populate regional emergency services (CHU Mustapha Pacha, CHU Franz Fanon, EPH Lakhdaria, Protection Civile Blida/Bouira, Gendarmerie brigades, towing fleets).
- [ ] Populate demo users with chronic conditions (diabetes, heart condition) and blood types for passport demonstration.

#### 2. Verification Scenarios
- [ ] **Scenario 1:** Register high-risk user profile with Emergency Health Passport.
- [ ] **Scenario 2:** Submit single witness report (verifies initial scoring & blackspot detection).
- [ ] **Scenario 3:** Submit second report within 500m / 15m (verifies clustering, Maximum Hazard merge, score escalation to Code RED, and auto-dispatch).
- [ ] **Scenario 4:** Ingest 2G SMS report from dead zone (verifies decoder and pipeline integration).
- [ ] **Scenario 5:** Fetch dispatcher feed (verifies sorting by priority score).

---

## 3. Progress Tracking

| Component | Target File | Status |
|---|---|---|
| Configuration | `.env`, `requirements.txt`, `app/config.py` | Completed |
| Database Engine | `app/database.py` | Completed |
| Severity Scoring | `app/logic/scoring.py` | Completed |
| Clustering Engine | `app/logic/clustering.py` | Completed |
| Multi-Agency Dispatch | `app/logic/dispatch.py` | Completed |
| SMS Resiliency | `app/logic/sms.py` | Completed |
| Incidents Router | `app/routers/incidents.py` | Completed |
| Users Router | `app/routers/users.py` | Completed |
| Services Router | `app/routers/services.py` | Completed |
| Application Main | `app/main.py` | Completed |
| Algerian Seed Data | `seed.py` | Completed |

