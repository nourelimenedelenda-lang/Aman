"""
app/config.py: Global configuration parameters for SolveX.
Centralizes tunable constants so they do not require hunting through logic files.
"""
import os
from dotenv import load_dotenv

load_dotenv()

PROJECT_NAME: str = os.getenv("PROJECT_NAME", "SolveX Emergency Backend")
DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./solvex.db")
DEBUG: bool = os.getenv("DEBUG", "True").lower() == "true"

# Geospatial and Clustering Constants
CLUSTER_RADIUS_METERS: float = float(os.getenv("CLUSTER_RADIUS_METERS", 500.0))
CLUSTER_TIME_WINDOW_MINUTES: float = float(os.getenv("CLUSTER_TIME_WINDOW_MINUTES", 15.0))
ARE_YOU_SAFE_TIMEOUT_SECONDS: int = int(os.getenv("ARE_YOU_SAFE_TIMEOUT_SECONDS", 45))

# Scoring Level Cutoffs
SCORE_THRESHOLD_RED: int = 70      # 70-100: Critical / Immediate auto-dispatch
SCORE_THRESHOLD_YELLOW: int = 35   # 35-69: Warning / Queued for operator verification
# 0-34: Blue (Info / Monitoring / Towing)

SMS_GATEWAY_API_KEY: str = os.getenv("SMS_GATEWAY_API_KEY", "solvex_demo_mock_key_2026")

