# Aman Mobile + FastAPI Backend

This repository contains a **Flutter mobile app** (in `mobile/flutter_app`) that talks to a **FastAPI backend** (in `backend`).

## Project Structure
```
├─ backend/                 # FastAPI server
│   └─ app/                # FastAPI app code
├─ mobile/                  # New folder for the mobile integration
│   └─ flutter_app/        # Copied Flutter project (editable)
│       ├─ lib/            # Dart code
│       │   ├─ config/    # Backend configuration
│       │   └─ services/  # API service wrapper
│       └─ pubspec.yaml   # Flutter dependencies (includes http)
├─ .gitignore               # Standard Flutter/Python ignores
├─ README.md                # This file
└─ ...
```

## Prerequisites
- **Git**
- **Flutter SDK** (>= 3.13) – see https://flutter.dev/docs/get-started/install
- **Python 3.11** and a virtual environment for the backend

## Setup Steps
1. **Create a public GitHub repository** (e.g., `https://github.com/<YOUR_USERNAME>/aman`).
2. **Initialize the local repo and push**:
   ```bash
   cd "c:\\aman - Copy"
   git init
   git add .
   git commit -m "Initial commit – Flutter app + FastAPI backend"
   git remote add origin https://github.com/<YOUR_USERNAME>/aman.git
   git branch -M main
   git push -u origin main
   ```
3. **Backend**
   ```bash
   cd backend
   python -m venv venv
   .\\venv\\Scripts\\activate   # PowerShell
   pip install -r requirements.txt   # fastapi, uvicorn, sqlalchemy, etc.
   uvicorn app.main:app --reload   # runs on http://127.0.0.1:8000
   ```
4. **Mobile app**
   ```bash
   cd ..\\mobile\\flutter_app
   flutter pub get
   flutter run   # launches on attached device/emulator
   ```
   The app will contact the backend at `http://10.0.2.2:8000` (Android emulator) or `http://localhost:8000` for iOS/web.

5. **Running tests** (optional):
   ```bash
   # Backend tests (if any)
   cd ../../backend
   pytest

   # Flutter tests
   cd ../mobile/flutter_app
   flutter test
   ```

## Documentation
- **Backend API** – after starting the server, open `http://127.0.0.1:8000/docs` for the interactive Swagger UI.
- **Mobile code** – main entry point is `lib/main.dart`. API interactions live in `lib/services/api_service.dart`.

## Contributing
Feel free to open issues or submit pull requests. Follow the standard GitHub Flow:
1. Fork the repo
2. Create a feature branch
3. Commit changes
4. Open a PR against `main`

## Screenshots

| Home Dashboard | Sign In |
|---|---|
| ![Home Dashboard](figs/Aman%20-%20Home%20Dashboard.png) | ![Sign In](figs/Aman%20-%20Sign%20In.png) |
| Report - Add helpful evidence | Report - Confirm Location |
| ![Add helpful evidence](figs/Aman%20-%20Report_%20Add%20helpful%20evidence.png) | ![Confirm Location](figs/Aman%20-%20Report_%20Confirm%20Location.png) |
| Report - Review your report | Report - Tell us what happened |
| ![Review your report](figs/Aman%20-%20Report_%20Review%20your%20report.png) | ![Tell us what happened](figs/Aman%20-%20Report_%20Tell%20us%20what%20happened.png) |
| Report - What are you reporting? |
| ![What are you reporting](figs/Aman%20-%20Report_%20What%20are%20you%20reporting_.png) |

---

