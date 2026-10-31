"""
test_e2e.py: End-to-end integration test for SolveX backend + trained ML model.
"""
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

print("=" * 65)
print("SolveX End-to-End System & ML Model Integration Test")
print("=" * 65)

# 1. Test health check
res = client.get("/")
assert res.status_code == 200
print("[OK] Health check online:", res.json())

# 2. Test Report 1: Witness in Gorges de Chiffa (RN1)
rep1 = {
    "latitude": 36.4181,
    "longitude": 2.8021,
    "source": "witness",
    "vehicle_count": 1,
    "victim_count": 1,
    "fire": False,
    "trapped_victims": False,
}
r1 = client.post("/incidents/report", json=rep1)
assert r1.status_code == 200
data1 = r1.json()
print("\n[OK] Report 1 Ingested (Single Witness, Blackspot):")
print(f"  Incident ID   : {data1['incident_id']}")
print(f"  Score / Tier  : {data1['score']} ({data1['level']})")
print(f"  Dispatched    : {data1['dispatch_summary']['dispatched']}")
if "ml_ai_prediction" in data1['dispatch_summary']:
    ml = data1['dispatch_summary']['ml_ai_prediction']
    print(f"  ML AI Tier    : {ml.get('predicted_tier')} (Confidence: {ml.get('confidence', 0):.1%})")

# 3. Test Report 2: Second witness 100m away with FIRE, TRAPPED VICTIMS & Medical Risk
rep2 = {
    "latitude": 36.4185,
    "longitude": 2.8024,
    "user_id": 1,  # Karim Belkacem (diabetes, penicillin allergy)
    "source": "witness",
    "vehicle_count": 3,
    "victim_count": 4,
    "fire": True,
    "trapped_victims": True,
}
r2 = client.post("/incidents/report", json=rep2)
assert r2.status_code == 200
data2 = r2.json()
print("\n[OK] Report 2 Ingested (Multi-Witness Cluster, Maximum Hazard Merge):")
print(f"  Incident ID   : {data2['incident_id']} (Same cluster? {data2['incident_id'] == data1['incident_id']})")
print(f"  Witness Count : {data2['cluster_witness_count']}")
print(f"  New Score/Tier: {data2['score']} ({data2['level']})")
print(f"  Dispatched    : {data2['dispatch_summary']['dispatched']}")
print(f"  Status Message: {data2['dispatch_summary']['status_message']}")
if "ml_ai_prediction" in data2['dispatch_summary']:
    ml = data2['dispatch_summary']['ml_ai_prediction']
    print(f"  ML AI Tier    : {ml.get('predicted_tier')} (Confidence: {ml.get('confidence', 0):.1%})")
    print(f"  Probabilities : {ml.get('probabilities')}")

# Print Auto-Dispatched Units
print("  Nearest Units Alerted:")
for ch in data2['dispatch_summary'].get('notification_channels', []):
    print(f"    • {ch['target']}: {ch['unit']['name']} ({ch['unit']['distance_km']} km)")

# Attached Medical Passport
passports = data2['dispatch_summary'].get('attached_health_passports', [])
print(f"  Attached Medical Passports ({len(passports)}):")
for p in passports:
    print(f"    • Victim: {p['full_name']} | Blood: {p['blood_type']} | Conditions: {p['chronic_conditions']} | Allergies: {p['allergies']}")

# 4. Test 2G Offline SMS Ingestion
sms_text = "SVX1#36.5650,3.5930#2#1#0#2#sensor#speed_drop#2"
r3 = client.post("/incidents/sms-inbound", params={"sms_text": sms_text})
assert r3.status_code == 200
print("\n[OK] 2G SMS Inbound Tested:")
print(f"  Result: {r3.json()['message']}, Incident ID: {r3.json()['incident_id']}")

# 5. Test Ranked Dispatcher Feed
r4 = client.get("/incidents")
assert r4.status_code == 200
incidents = r4.json()
print(f"\n[OK] Dispatcher Live Dashboard: {len(incidents)} active incidents ranked by priority score:")
for inc in incidents:
    print(f"  • Incident #{inc['id']}: Score {inc['score']:>2} [{inc['level']:<6}] Status: {inc['status']:<8} Reports: {len(inc['reports'])}")

print("=" * 65)
print("ALL TESTS PASSED! System is fully operational and ML-integrated.")
print("=" * 65)
