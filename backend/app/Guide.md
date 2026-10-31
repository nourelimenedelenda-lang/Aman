# SolveX Backend: File Guide

Oct 31, 2026 · @imene

## Overview

The backend is a small FastAPI (Python) project with 18 empty files, split so that HTTP code (`routers/`) and the emergency logic (`logic/`) stay apart. This assumes Python/FastAPI; if your team uses Node/Express, the same structure carries over.

```
backend/
├── .env
├── requirements.txt
├── seed.py
└── app/
    ├── __init__.py
    ├── main.py
    ├── config.py
    ├── database.py
    ├── models.py
    ├── schemas.py
    ├── routers/
    │   ├── __init__.py
    │   ├── incidents.py
    │   ├── users.py
    │   └── services.py
    └── logic/
        ├── __init__.py
        ├── clustering.py
        ├── scoring.py
        ├── dispatch.py
        └── sms.py
```

The `__init__.py` files are empty on purpose: they only tell Python that each folder is a package.

## Root files

| File | Will contain | Why it exists |
| --- | --- | --- |
| `.env` | Database URL, SMS gateway key, optional weather API key | Keeps secrets out of the code and out of git |
| `requirements.txt` | `fastapi`, `uvicorn`, `sqlalchemy`, `pydantic`, plus a weather or SMS client later | Teammates install everything with one command |
| `seed.py` | Demo data: CHU/EPH hospitals with trauma capability, Protection Civile and Gendarmerie units, towing agencies, blackspots such as Chiffa and Lakhdaria | "Nearest hospital" and "inside a blackspot" only work in the demo if this data exists |

## app/ core

| File | Will contain | Why it exists |
| --- | --- | --- |
| `main.py` | Creates the FastAPI app, registers the three routers, enables CORS for the mobile app and dashboard, creates tables on startup | The single entry point you run |
| `config.py` | Loads `.env` and holds tunable constants: 500 m cluster radius, 15 min window, 45 s "Are you safe?" countdown | One place to change settings without hunting through the code |
| `database.py` | Database engine, session factory, and a `get_db` dependency; SQLite is enough | Gives every router the same database connection |
| `models.py` | Tables: `User` (Emergency Health Passport), `Incident` (consolidated entity with score and level), `Report` (one witness or sensor submission), `Service` (hospitals, Protection Civile, Gendarmerie, towing), `Blackspot` | Mirrors the datasets listed in the project report |
| `schemas.py` | Request and response shapes: what the app sends (coordinates, hazard tags, detection method, user ID) and what the dashboard receives | Validates input and generates the API docs at `/docs` |

## app/routers

| File | Will contain | Why it exists |
| --- | --- | --- |
| `__init__.py` | Nothing | Marks the folder as a Python package |
| `incidents.py` | `POST /incidents/report` to receive a witness form or sensor trigger and call the logic layer; `GET /incidents` for the ranked dispatcher list; a status update (verified, resolved) | The core endpoints of the demo: report in, ranked incident out |
| `users.py` | Create and update a user's Emergency Health Passport | The passport is attached to the payload sent to SAMU and the hospital |
| `services.py` | Read-only endpoints for the hospital, responder and towing directory | Feeds the dashboard map and helps debug dispatch |

## app/logic

The intelligence lives here, separate from the HTTP code, so you can test it without running the server.

| File | Will contain | Why it exists |
| --- | --- | --- |
| `__init__.py` | Nothing | Marks the folder as a Python package |
| `clustering.py` | The spatial-temporal engine: a report within 500 m and 15 min of an open incident merges into it, otherwise a new incident starts; the Maximum Hazard Principle (highest vehicle count, any fire flag); the independent-witness count | Stops ten witnesses from creating ten dashboard entries for one crash |
| `scoring.py` | The 0–100 Priority and Severity Index from the report's point table, and the mapping to Code Red (70–100), Yellow (35–69) and Blue (0–34); re-run whenever a report joins a cluster | Gives dispatchers a live ranking of what is most urgent |
| `dispatch.py` | Finds the nearest hospital and responder units by distance (Haversine formula), builds the payload with the health passport, and applies the rules: Red auto-alerts Protection Civile and SAMU, Yellow waits for an operator, Blue is monitor-only | Turns a scored incident into actual alerts |
| `sms.py` | Encodes a compact incident message (coordinates, hazard flags, severity) into a short SMS and decodes it on the server; a mocked sender is fine for the hackathon | Lets reports from dead zones enter the same pipeline |

## Suggested build order

Build the report-to-score-to-dashboard path first, since that is the core of the demo:

1. `models.py`
2. `schemas.py`
3. `scoring.py`
4. `clustering.py`
5. `incidents.py`
6. `seed.py`
7. `dispatch.py`
8. `users.py`, `services.py`, then `sms.py` last
