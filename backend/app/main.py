"""
app/main.py: FastAPI entry point for SolveX backend.

Initializes the FastAPI application, registers routers, sets CORS policies
for mobile and web dashboards, and ensures database tables are initialized.
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import DEBUG, PROJECT_NAME
from .database import Base, engine
from .routers import incidents, services, users

# Auto-create SQLite/Postgres tables on application startup
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=PROJECT_NAME,
    version="3.0.0",
    description=(
        "SolveX 3.0: Mobile Emergency Response & Intelligent Accident Ingestion Platform "
        "tailored for the Algerian road infrastructure."
    ),
    debug=DEBUG,
)

# Enable CORS for Mobile App and Web Dispatcher Dashboard
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(incidents.router)
app.include_router(users.router)
app.include_router(services.router)


@app.get("/", tags=["Health"])
def health_check():
    """
    Root status check endpoint.
    """
    return {
        "status": "online",
        "service": PROJECT_NAME,
        "version": "3.0.0",
        "docs_url": "/docs",
    }

