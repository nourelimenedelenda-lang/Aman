# SolveX 3.0 — Front-End Build Guide

Mobile Emergency Response & Intelligent Accident Ingestion Platform

This guide covers the **style, fonts, stack and screen-by-screen wiring** for the front end. It has two clients that talk to the same FastAPI backend:

| Client | Users | Purpose |
| --- | --- | --- |
| **Mobile app** | Witnesses, drivers, victims | Report an accident, "Are you safe?" countdown, first aid, Emergency Health Passport |
| **Dispatcher dashboard** (web) | Protection Civile, SAMU, Gendarmerie operators | Ranked incident list, map, verify, dispatch, resolve |

---

## 1. Design Concept

**Idea:** a calm, high-trust emergency tool. In a crisis the user is stressed, so the UI must be fast, high-contrast, and readable at a glance. The visual language is a **dark "control room" theme** (the dashboard and the emergency screens) with **one strong alert color system** that maps directly to the backend severity levels.

Principles:
- **Color = meaning.** Red / Yellow / Blue always mean Code Red / Yellow / Blue. Never use these colors decoratively.
- **Big touch targets** (min 56 px, primary emergency buttons 72 px+). Usable with shaking hands, gloves, one thumb.
- **3 taps maximum** to send a report. No typing in the emergency flow.
- **Icons first, text second.** Pictograms work for any literacy level and any language.
- **Offline is a first-class state**, always visible, never hidden.
- **Bilingual:** French (default) and English, with Arabic (RTL) ready.

---

## 2. Tech Stack

### Mobile app
| Need | Choice |
| --- | --- |
| Framework | **React Native + Expo (TypeScript)** |
| Navigation | `expo-router` |
| Styling | **NativeWind** (Tailwind for React Native) |
| Location / GPS | `expo-location` (background updates for speed-drop detection) |
| Motion sensors | `expo-sensors` (Accelerometer, Gyroscope, Barometer) |
| Audio buffer (acoustic trigger) | `expo-av` |
| Vibration / haptics | `expo-haptics` |
| Offline queue + cache | `@react-native-async-storage/async-storage` + `expo-sqlite` |
| Network state | `@react-native-community/netinfo` |
| SMS fallback | `expo-sms` |
| Server state | **TanStack Query** |
| Local state | **Zustand** |
| Forms | `react-hook-form` + `zod` |
| Maps | `react-native-maps` (or MapLibre with OSM tiles) |
| i18n | `i18next` + `react-i18next` |
| Icons | `lucide-react-native` + custom first-aid pictograms (SVG) |
| Animations | `react-native-reanimated` |

### Dispatcher dashboard
| Need | Choice |
| --- | --- |
| Framework | **React + Vite + TypeScript** |
| Styling | **Tailwind CSS + shadcn/ui** |
| Map | **MapLibre GL** or **Leaflet** with OpenStreetMap tiles (matches the OSM data in the report) |
| Server state | **TanStack Query** (polling every 5 s, or WebSocket later) |
| Tables | TanStack Table |
| Charts | Recharts |
| Icons | `lucide-react` |
| i18n | `i18next` |
| HTTP client | `axios` or `fetch` wrapper (shared with mobile) |

### Shared
- A single `api/` module and a single `design-tokens` file used by both clients.
- API types generated from the FastAPI OpenAPI schema (`/docs` → `openapi-typescript`) so the front end never drifts from `schemas.py`.

### Suggested structure
```
frontend/
├── packages/
│   ├── tokens/            # colors, spacing, fonts (shared)
│   └── api/               # typed client + hooks (shared)
├── mobile/                # Expo app
│   └── app/
│       ├── (tabs)/
│       │   ├── index.tsx        # Home / big SOS
│       │   ├── passport.tsx     # Emergency Health Passport
│       │   └── services.tsx     # Nearby services directory
│       ├── report.tsx           # 3-tap triage form
│       ├── safe-check.tsx       # "Are you safe?" 45 s countdown
│       ├── first-aid.tsx        # Offline pictogram guidance
│       └── status.tsx           # Report sent / queued / SMS fallback
└── dashboard/             # Vite app
    └── src/
        ├── pages/ (Incidents, IncidentDetail, Services, Blackspots)
        ├── components/ (IncidentCard, SeverityBadge, MapView, PassportCard, DispatchPanel)
        └── lib/
```

---

## 3. Design Tokens

### 3.1 Colors

Dark base (dashboard and all emergency screens):

| Token | Hex | Use |
| --- | --- | --- |
| `bg` | `#0B1220` | App background (deep navy) |
| `surface` | `#121B2E` | Cards, panels |
| `surface-2` | `#1A2640` | Raised elements, inputs |
| `border` | `#26344F` | Dividers, outlines |
| `text` | `#F1F5F9` | Primary text |
| `text-muted` | `#94A3B8` | Secondary text |

Severity colors (must match backend levels):

| Token | Hex | Backend level | Score |
| --- | --- | --- | --- |
| `critical` | `#FF3B47` | Code Red | 70–100 |
| `warning` | `#FFB020` | Code Yellow | 35–69 |
| `info` | `#3B82F6` | Code Blue | 0–34 |

Status and brand colors:

| Token | Hex | Use |
| --- | --- | --- |
| `safe` | `#22C55E` | "Je vais bien / I'm Safe", resolved, online |
| `brand` | `#FF3B47` | Primary SOS button only |
| `offline` | `#A78BFA` | Offline / SMS-queued state |
| `verified` | `#2DD4BF` | Verified incident, cross-verification badge |

Light mode is optional. If added, keep the same severity colors unchanged.

### 3.2 Fonts
| Role | Font | Why |
| --- | --- | --- |
| UI and headings | **Inter** (600/700 headings, 400/500 body) | Very legible at small sizes, neutral |
| Numbers, coordinates, scores, timers | **JetBrains Mono** | Fixed width, no ambiguity between digits, "control room" feel |
| Arabic | **Cairo** | Pairs well with Inter, supports RTL |

Type scale: `12 / 14 / 16 / 20 / 24 / 32 / 48`. The countdown number and the severity score use 48+ px mono.

### 3.3 Shape, spacing, motion
- Radius: `12 px` cards, `16 px` big buttons, `999 px` badges.
- Spacing scale: 4 / 8 / 12 / 16 / 24 / 32.
- Shadows: none on dark theme; use `border` + subtle glow on critical items (`box-shadow: 0 0 24px rgba(255,59,71,.35)`).
- Motion: fast (150–200 ms). Only two attention animations allowed: **pulse** on Code Red and the **countdown ring**.
- Haptics: strong on countdown start, success tick when the report is sent.

### 3.4 Tailwind config (shared)
```js
// tailwind.config.js (extend)
colors: {
  bg: '#0B1220', surface: '#121B2E', 'surface-2': '#1A2640', border: '#26344F',
  text: '#F1F5F9', muted: '#94A3B8',
  critical: '#FF3B47', warning: '#FFB020', info: '#3B82F6',
  safe: '#22C55E', offline: '#A78BFA', verified: '#2DD4BF',
},
fontFamily: {
  sans: ['Inter', 'Cairo', 'system-ui'],
  mono: ['JetBrains Mono', 'monospace'],
},
```

---

## 4. Iconography

Use **Lucide** for everything generic, and a small custom SVG set for first aid (simple, thick-stroke, one-color pictograms that work offline).

| Concept | Icon |
| --- | --- |
| SOS / report accident | `siren`, `triangle-alert` |
| Fire hazard | `flame` |
| Fuel leak | `droplet` |
| Trapped victims | `lock` or custom "trapped car" |
| Number of vehicles | `car` (with count badge) |
| Injured / unconscious | `user-round-x`, `heart-pulse` |
| Health passport | `id-card`, `heart-pulse` |
| Blood type | `droplets` |
| Hospital (CHU/EPH) | `hospital` |
| Protection Civile / SAMU | `ambulance` |
| Gendarmerie / Police | `shield` |
| Towing (Dépannage) | `truck` |
| Blackspot (point noir) | `map-pin-off` or `octagon-alert` |
| Weather | `cloud-fog`, `cloud-rain`, `snowflake` |
| Night | `moon` |
| Offline | `wifi-off`, `message-square` (SMS) |
| Verified / confirmed | `badge-check` |
| Sensor trigger | `activity`, `waves` (acoustic), `gauge` (barometer) |
| Language | `languages` |

**Custom first-aid pictograms** (SVG): recovery position (PLS), bleeding control (pressure), fire evacuation, do-not-move-victim, call-for-help. Bundle them in the app assets so they render with no connection.

---

## 5. Backend Wiring (what each screen calls)

> Endpoint names below follow the backend file guide (`routers/incidents.py`, `users.py`, `services.py`). If your final routes differ, only the `api/` package needs updating. Check `/docs` for the real paths.

| Feature (backend) | Endpoint | Used by |
| --- | --- | --- |
| Receive witness form or sensor trigger | `POST /incidents/report` | Mobile: report form, safe-check auto-send, sensors |
| Ranked dispatcher list | `GET /incidents` | Dashboard: incident list and map |
| Status update (verified, resolved) | `PATCH /incidents/{id}` (status) | Dashboard: Verify / Resolve buttons |
| Create / update Health Passport | `POST /users`, `PUT /users/{id}` | Mobile: passport screen |
| Hospital / responder / towing directory | `GET /services` | Mobile: services tab, Dashboard: map layer |
| Blackspots | via `/services` or `GET /blackspots` if exposed | Dashboard: map zones |
| SMS encode/decode (`logic/sms.py`) | Server decodes incoming SMS through the same pipeline | Mobile: offline fallback |

### 5.1 Report payload (mobile → `POST /incidents/report`)
Send what the schema expects (verify names in `schemas.py`):
```ts
{
  user_id: number | null,
  latitude: number,
  longitude: number,
  timestamp: string,            // ISO 8601
  detection_method: 'manual' | 'speed_drop' | 'high_g' | 'acoustic' | 'barometer' | 'bluetooth' | 'sms',
  vehicles: number,
  hazards: { fire: boolean, fuel_leak: boolean, trapped: boolean },
  victims: { injured: number, unconscious: boolean },
  audio_note_url?: string
}
```
The response contains the consolidated incident (id, score, level, report count). Show it back to the user ("Help is being alerted").

### 5.2 Incident object (dashboard ← `GET /incidents`)
Expect: `id, level (red|yellow|blue), score, vehicles, hazards, report_count, status, latitude, longitude, created_at, passport?, nearest services / dispatch info`.

---

## 6. Mobile App — Screens

### 6.1 Home
- Giant **SOS / Report accident** button (brand red, pulsing slowly).
- Status strip: GPS ok, Online / **Offline (SMS ready)**, sensors active.
- Quick links: Health Passport, Nearby services, Language.
- Toggle: "Crash detection ON" (enables background sensors).

### 6.2 3-Tap Visual Triage Form (`report.tsx`)
Goal: send in under 5 seconds, no keyboard.
1. **Tap 1: vehicles** (1 / 2 / 3+ big car tiles).
2. **Tap 2: hazards** (multi-select tiles: Fire, Fuel leak, Trapped victims).
3. **Tap 3: victims** (None / 1–3 injured / 3+ or unconscious), then auto-submit.

On submit: call `POST /incidents/report` with current GPS, then go straight to **First Aid** (don't wait for the response). If offline, go to the SMS fallback (6.5).

### 6.3 "Are You Safe?" countdown (`safe-check.tsx`)
- Triggered locally by the sensor logic (high-G, sudden speed drop from >70 km/h to 0, optional acoustic > 110 dB, barometer spike, Bluetooth cut).
- Full-screen high-contrast countdown, **45 s** (use the same value as `config.py`), ring animation, loud alarm and vibration.
- Two huge buttons: **"Je vais bien / I'm Safe"** (green, cancels) and **"J'ai besoin d'aide / I need help"** (red, sends now).
- If it reaches 0: auto-call `POST /incidents/report` with `detection_method` set to the trigger and the user's `user_id` so the backend attaches the Health Passport.
- The message is sent in the background even if the screen locks.

### 6.4 First Aid screen (`first-aid.tsx`)
- Appears immediately after any report.
- Context-aware step cards (large pictogram + 1 short line): Recovery position, Bleeding control, Fire evacuation, Don't move the victim.
- Pick cards based on what was ticked in the form (fire → evacuation first).
- **Fully offline**: all pictograms and text bundled locally. AI-generated text, when online, only enhances the content.
- Persistent bottom bar: **Call 14 / 16** buttons (tel: links).

### 6.5 Offline / SMS fallback (`status.tsx`)
- Detect with NetInfo. If a send fails, store the report in the local queue (SQLite) and show the **purple offline banner**.
- Build the compact SMS (coordinates, hazard flags, severity, per the format decided in `logic/sms.py`) and open `expo-sms` to the gateway number, prefilled.
- Retry the queue automatically when connectivity returns. Show states: `Queued → Sending → Sent → Received`.

### 6.6 Emergency Health Passport (`passport.tsx`)
Form with: blood type (chips), chronic conditions (multi-chip: diabetes, hypertension, asthma, epilepsy…), severe allergies (e.g. penicillin), implanted devices (e.g. pacemaker), emergency contacts, insurance provider and policy number.
- Save with `POST/PUT /users`.
- Show a clear note: "Shared automatically with SAMU and the hospital when a crash is reported."
- Also cache locally so it can be shown on the lock screen / offline.

### 6.7 Services directory (`services.tsx`)
- Map + list from `GET /services`, filtered by type (hospital, Protection Civile, Gendarmerie, towing).
- Sorted by distance (compute on the client from the user's GPS).
- One-tap call button on each item.

---

## 7. Dispatcher Dashboard — Screens

### 7.1 Layout
Three columns on desktop: **left** ranked incident list, **center** map, **right** selected incident detail. Top bar: logo, live status (polling OK), language, operator.

### 7.2 Incident list (`GET /incidents`, poll every 5 s)
- Sorted by score, descending. Re-sorts live as scores change.
- **IncidentCard**: severity badge (color + label RED/YELLOW/BLUE), big mono score (e.g. `87`), location name, vehicles, hazard icons, report count ("3 witnesses"), time since first report, verified badge when sensor + human confirmed.
- Filters: level, status (new / verified / resolved), time range.
- Code Red cards pulse; play a short sound on a new Red incident.

### 7.3 Map
- OSM tiles, dark style.
- Markers colored by level. Cluster radius circle (500 m) drawn around each incident.
- Layers (toggles): hospitals, Protection Civile, Gendarmerie, towing, **blackspots** (red translucent geofences, e.g. Chiffa, Lakhdaria).
- Click marker ↔ select in list (synced).

### 7.4 Incident detail panel
- Score + level + **score breakdown** (the 5 weight layers: on-scene attributes, road context, weather/night, witness density, perimeter anomaly), shown as a small stacked bar. This makes the "intelligent scoring" visible in the demo.
- Consolidated info: vehicles (max), hazards, victims, detection methods, individual reports timeline (each witness/sensor submission).
- **PassportCard**: blood type, conditions, allergies, devices, contacts (only when attached).
- **DispatchPanel**: which services were notified (Protection Civile, SAMU, Gendarmerie, nearest hospital + distance, towing) with status per service.
- Actions by level:
  - Red: shows "Auto-dispatched" with timestamps.
  - Yellow: **Verify & Dispatch** button (operator confirms).
  - Blue: **Monitor** / notify towing-insurance if requested.
- Status buttons: **Verified**, **Resolved** → `PATCH` the incident.

### 7.5 Services and blackspots pages
Read-only tables from `GET /services` for debugging and demo (name, type, trauma capability, phone, coordinates).

---

## 8. Cross-Cutting Rules

- **Severity component (single source):** one `SeverityBadge` component maps `level → color + icon + label`. Use it everywhere.
- **Loading / error states:** skeletons on the dashboard; on mobile, never block the emergency flow on a network call.
- **Accessibility:** contrast ratio ≥ 4.5:1 (all token pairs above pass on the dark bg), never rely on color alone (always icon + label), support dynamic font size, screen-reader labels on all buttons.
- **i18n:** all strings via keys, `fr` default, `en`, `ar` (RTL flip via `I18nManager`). Keep emergency strings very short.
- **Permissions:** request location (always), motion, microphone, notifications at onboarding with a one-line reason each.
- **Privacy:** passport data only sent on a crash trigger or a manual report; never logged on the client.
- **Config:** API base URL in `.env` (`EXPO_PUBLIC_API_URL`, `VITE_API_URL`); the countdown (45 s) and cluster radius (500 m) should mirror `config.py`.

---

## 9. Suggested Build Order (hackathon, 48 h)

1. Shared tokens + typed API client.
2. Dashboard: incident list + `SeverityBadge` + detail panel (proves the core path).
3. Mobile: 3-tap triage form → `POST /incidents/report`.
4. Dashboard map + blackspots/services layers.
5. Mobile: Health Passport + First Aid screens.
6. Mobile: "Are you safe?" countdown + at least the high-G / speed-drop trigger.
7. Offline queue + SMS fallback.
8. Polish: sounds, pulse animations, i18n, score-breakdown bar.

**Demo tip:** simulate sensor triggers with a hidden "Simulate crash" button on mobile, and seed the data (`seed.py`) so the nearest hospital and blackspots appear on the map.
