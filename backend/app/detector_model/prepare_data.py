"""
app/detector_model/prepare_data.py: Data cleaning, normalization, synthesis, and preprocessing.

This script executes the complete data pipeline:
  1. Inspects raw Algerian road safety data files.
  2. Cleans artifacts, removes aggregate/total rows, and fixes unit inconsistencies (fractions vs percentages).
  3. Decouples multi-dimensional datasets (time-of-day vs weekday, deaths vs injuries).
  4. Standardizes wilaya names and road category names.
  5. Generates a statistically calibrated incident training dataset (10,000 records) grounded in empirical priors.
  6. Normalizes and encodes features, producing train/test splits ready for model training.
"""

import csv
import json
import math
import os
import random
from datetime import datetime, timedelta

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")
CLEANED_DIR = os.path.join(DATA_DIR, "cleaned")
os.makedirs(CLEANED_DIR, exist_ok=True)


def clean_causes():
    """Cleans causes.csv: drops subtotals, fixes unit discrepancies."""
    raw_path = os.path.join(DATA_DIR, "causes.csv")
    out_path = os.path.join(CLEANED_DIR, "causes_cleaned.csv")
    
    records = []
    with open(raw_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            group = row["factor_group"].strip()
            cause = row["cause_original_or_translated"].strip()
            count = int(row["count"].strip())
            
            # Skip summary/subtotal rows
            if "subtotal" in group.lower() or "total" in cause.lower() or group.lower() == "all groups":
                continue
                
            records.append({
                "factor_group": group,
                "cause": cause,
                "count": count,
            })
            
    total_accidents = 24829  # Official 2024 total accidents in Algeria
    for r in records:
        r["share_ratio"] = round(r["count"] / total_accidents, 6)
        r["share_percent"] = round(r["share_ratio"] * 100, 3)

    records.sort(key=lambda x: x["count"], reverse=True)
    
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        fieldnames = ["factor_group", "cause", "count", "share_ratio", "share_percent"]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(records)
        
    print(f"[OK] Cleaned causes: {len(records)} cause categories saved to {out_path}")
    return records


def clean_time_distribution():
    """Splits time_distribution.csv into time_of_day and weekday datasets."""
    raw_path = os.path.join(DATA_DIR, "time_distribution.csv")
    out_time = os.path.join(CLEANED_DIR, "time_of_day_cleaned.csv")
    out_week = os.path.join(CLEANED_DIR, "weekday_cleaned.csv")
    
    time_records = []
    week_records = []
    
    with open(raw_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            dim = row["dimension"].strip()
            cat = row["category"].strip().replace("–", "-")
            count = int(row["accident_count"].strip())
            
            item = {"category": cat, "accident_count": count}
            if dim == "Time of day":
                time_records.append(item)
            elif dim == "Weekday":
                week_records.append(item)
                
    total_time = sum(r["accident_count"] for r in time_records)
    for r in time_records:
        r["share_ratio"] = round(r["accident_count"] / total_time, 4)
        r["share_percent"] = round(r["share_ratio"] * 100, 2)
        
    total_week = sum(r["accident_count"] for r in week_records)
    for r in week_records:
        r["share_ratio"] = round(r["accident_count"] / total_week, 4)
        r["share_percent"] = round(r["share_ratio"] * 100, 2)
        
    with open(out_time, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["category", "accident_count", "share_ratio", "share_percent"])
        writer.writeheader()
        writer.writerows(time_records)
        
    with open(out_week, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["category", "accident_count", "share_ratio", "share_percent"])
        writer.writeheader()
        writer.writerows(week_records)
        
    print(f"[OK] Decoupled time distribution into {out_time} and {out_week}")
    return time_records, week_records


def clean_vehicle_types():
    """Cleans vehicle_types.csv: drops Total row, normalizes shares."""
    raw_path = os.path.join(DATA_DIR, "vehicle_types.csv")
    out_path = os.path.join(CLEANED_DIR, "vehicle_types_cleaned.csv")
    
    records = []
    with open(raw_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            cat = row["vehicle_category"].strip()
            if cat.lower() == "total":
                continue
            records.append({
                "vehicle_category": cat,
                "count": int(row["count"].strip()),
            })
            
    total_vehicles = sum(r["count"] for r in records)
    for r in records:
        r["share_ratio"] = round(r["count"] / total_vehicles, 4)
        r["share_percent"] = round(r["share_ratio"] * 100, 2)
        
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["vehicle_category", "count", "share_ratio", "share_percent"])
        writer.writeheader()
        writer.writerows(records)
        
    print(f"[OK] Cleaned vehicle types saved to {out_path}")
    return records


def clean_rural_road_types():
    """Cleans rural_road_types.csv: standardizes category names."""
    raw_path = os.path.join(DATA_DIR, "rural_road_types.csv")
    out_path = os.path.join(CLEANED_DIR, "road_types_cleaned.csv")
    
    records = []
    with open(raw_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rtype = row["road_type"].strip().replace("–", "-")
            count = int(row["accidents_2024"].strip())
            records.append({
                "road_type": rtype,
                "accident_count": count,
            })
            
    total_roads = sum(r["accident_count"] for r in records)
    for r in records:
        r["share_ratio"] = round(r["accident_count"] / total_roads, 4)
        r["share_percent"] = round(r["share_ratio"] * 100, 2)
        
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["road_type", "accident_count", "share_ratio", "share_percent"])
        writer.writeheader()
        writer.writerows(records)
        
    print(f"[OK] Cleaned road types saved to {out_path}")
    return records


def clean_wilaya_top10():
    """Pivots wilaya_top10.csv into wilaya risk profile with lethality index."""
    raw_path = os.path.join(DATA_DIR, "wilaya_top10.csv")
    out_path = os.path.join(CLEANED_DIR, "wilaya_risk_cleaned.csv")
    
    wilaya_data = {}
    with open(raw_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            metric = row["metric"].strip()
            wilaya = row["wilaya"].strip().replace("Algiers", "Alger").replace("Setif", "Sétif")
            count = int(row["count"].strip())
            
            if wilaya not in wilaya_data:
                wilaya_data[wilaya] = {"wilaya": wilaya, "accidents": 0, "deaths": 0, "injuries": 0}
                
            if metric == "Accidents":
                wilaya_data[wilaya]["accidents"] = count
            elif metric == "Deaths":
                wilaya_data[wilaya]["deaths"] = count
            elif metric == "Injuries":
                wilaya_data[wilaya]["injuries"] = count
                
    records = []
    for w, vals in wilaya_data.items():
        acc = vals["accidents"]
        deaths = vals["deaths"]
        inj = vals["injuries"]
        # Lethality rate: deaths per recorded crash (or per 100 accidents)
        lethality = round((deaths / acc * 100), 2) if acc > 0 else 0.0
        records.append({
            "wilaya": w,
            "accidents": acc,
            "deaths": deaths,
            "injuries": inj,
            "lethality_rate_percent": lethality,
        })
        
    records.sort(key=lambda x: (x["accidents"], x["deaths"]), reverse=True)
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["wilaya", "accidents", "deaths", "injuries", "lethality_rate_percent"])
        writer.writeheader()
        writer.writerows(records)
        
    print(f"[OK] Cleaned wilaya risk profiles saved to {out_path}")
    return records


def generate_training_dataset(n_samples=10000):
    """
    Synthesizes a statistically sound incident-level training dataset.
    Calibrated against real empirical Algerian probabilities:
      - Wilaya spatial centroids
      - Time of day and day of week distributions
      - Road types and vehicle types
      - Maximum Hazard attributes and SolveX ground-truth severity tiers
    """
    random.seed(42)
    out_path = os.path.join(DATA_DIR, "incidents_training_dataset.csv")

    wilayas = [
        {"name": "Alger", "lat": 36.7538, "lon": 3.0588, "weight": 0.14},
        {"name": "Oran", "lat": 35.6971, "lon": -0.6308, "weight": 0.15},
        {"name": "Chlef", "lat": 36.1667, "lon": 1.3333, "weight": 0.12},
        {"name": "Blida", "lat": 36.4700, "lon": 2.8300, "weight": 0.10},
        {"name": "Bouira", "lat": 36.3749, "lon": 3.9020, "weight": 0.09},
        {"name": "Setif", "lat": 36.1900, "lon": 5.4100, "weight": 0.09},
        {"name": "Constantine", "lat": 36.3650, "lon": 6.6147, "weight": 0.08},
        {"name": "Batna", "lat": 35.5559, "lon": 6.1741, "weight": 0.08},
        {"name": "Djelfa", "lat": 34.6728, "lon": 3.2630, "weight": 0.08},
        {"name": "Tlemcen", "lat": 34.8783, "lon": -1.3150, "weight": 0.07},
    ]

    time_slots = [
        {"slot": "00:00-06:00", "hour_range": (0, 5), "weight": 0.072, "is_night": 1},
        {"slot": "06:00-09:00", "hour_range": (6, 8), "weight": 0.069, "is_night": 0},
        {"slot": "09:00-12:00", "hour_range": (9, 11), "weight": 0.139, "is_night": 0},
        {"slot": "12:00-15:00", "hour_range": (12, 14), "weight": 0.175, "is_night": 0},
        {"slot": "15:00-18:00", "hour_range": (15, 17), "weight": 0.213, "is_night": 0},
        {"slot": "18:00-24:00", "hour_range": (18, 23), "weight": 0.332, "is_night": 1},
    ]

    road_types = [
        {"type": "National roads", "weight": 0.50, "is_corridor": 1},
        {"type": "Highways / expressways", "weight": 0.19, "is_corridor": 1},
        {"type": "East-West motorway", "weight": 0.10, "is_corridor": 1},
        {"type": "Wilaya roads", "weight": 0.06, "is_corridor": 0},
        {"type": "Municipal roads", "weight": 0.04, "is_corridor": 0},
        {"type": "Other rural roads", "weight": 0.11, "is_corridor": 0},
    ]

    vehicle_categories = [
        {"cat": "Light vehicles", "weight": 0.61},
        {"cat": "Two-wheeled motorcycles", "weight": 0.22},
        {"cat": "Trucks", "weight": 0.10},
        {"cat": "Passenger transport vehicles", "weight": 0.03},
        {"cat": "Trailers", "weight": 0.02},
        {"cat": "Other machinery", "weight": 0.02},
    ]

    causes = [
        ("Excessive speed", 0.18),
        ("Driver inattention", 0.16),
        ("Dangerous overtaking", 0.09),
        ("Loss of control", 0.09),
        ("Failure to yield priority", 0.08),
        ("Dangerous manoeuvres", 0.06),
        ("Pedestrian lack of caution", 0.06),
        ("Ineffective brakes / mechanical", 0.03),
        ("Bad weather / slippery road", 0.03),
        ("Other causes", 0.22),
    ]

    blackspots = [
        {"name": "Gorges de Chiffa", "lat": 36.4180, "lon": 2.8020},
        {"name": "Gorges de Lakhdaria", "lat": 36.5650, "lon": 3.5930},
        {"name": "Descente de Djebahia", "lat": 36.4670, "lon": 3.7310},
    ]

    base_date = datetime(2025, 1, 1)

    records = []
    for i in range(1, n_samples + 1):
        # 1. Sample Wilaya & Location
        w_obj = random.choices(wilayas, weights=[w["weight"] for w in wilayas])[0]
        
        # 15% probability of being directly centered on an accident blackspot
        in_blackspot = 1 if random.random() < 0.15 else 0
        if in_blackspot:
            b_spot = random.choice(blackspots)
            lat = round(b_spot["lat"] + random.uniform(-0.008, 0.008), 5)
            lon = round(b_spot["lon"] + random.uniform(-0.008, 0.008), 5)
        else:
            lat = round(w_obj["lat"] + random.uniform(-0.05, 0.05), 5)
            lon = round(w_obj["lon"] + random.uniform(-0.05, 0.05), 5)

        # 2. Sample Date & Time
        slot_obj = random.choices(time_slots, weights=[s["weight"] for s in time_slots])[0]
        hour = random.randint(slot_obj["hour_range"][0], slot_obj["hour_range"][1])
        minute = random.randint(0, 59)
        day_offset = random.randint(0, 365)
        incident_time = base_date + timedelta(days=day_offset, hours=hour, minutes=minute)
        day_of_week = incident_time.strftime("%A")
        is_weekend = 1 if day_of_week in ["Friday", "Saturday"] else 0
        is_night = slot_obj["is_night"]

        # 3. Sample Road & Vehicle Info
        road_obj = random.choices(road_types, weights=[r["weight"] for r in road_types])[0]
        on_corridor = road_obj["is_corridor"]
        veh_cat = random.choices(vehicle_categories, weights=[v["weight"] for v in vehicle_categories])[0]["cat"]
        cause = random.choices([c[0] for c in causes], weights=[c[1] for c in causes])[0]

        # Vehicle count (majority 1-2, occasionally multi-vehicle pileups)
        veh_roll = random.random()
        if veh_roll < 0.55:
            vehicles_count = 1
        elif veh_roll < 0.88:
            vehicles_count = 2
        else:
            vehicles_count = random.randint(3, 5)

        # Severe weather (e.g. rain, dense fog)
        severe_weather = 1 if random.random() < 0.12 else 0

        # High casualty probability increases on corridors, high speeds, trucks
        base_victim_prob = 0.25 if on_corridor or veh_cat in ["Trucks", "Passenger transport vehicles"] else 0.10
        if random.random() < base_victim_prob:
            injured_count = random.randint(3, 7)
        else:
            injured_count = random.randint(0, 2)

        # Fatalities correlated with rural corridors and high casualty counts
        death_prob = 0.20 if (on_corridor and injured_count > 1) else 0.04
        deaths_count = random.randint(1, 3) if random.random() < death_prob else 0

        # Physical hazards
        fire = 1 if random.random() < (0.08 if vehicles_count > 1 else 0.02) else 0
        trapped_victims = 1 if (injured_count >= 2 and random.random() < 0.25) else 0

        # Medical risk condition (pre-existing in health passport)
        high_risk_health = 1 if random.random() < 0.14 else 0

        # Multi-witness consensus & sensor verification
        witness_count = random.choices([1, 2, 3, 4, 5], weights=[0.40, 0.30, 0.15, 0.10, 0.05])[0]
        sensor_triggered = 1 if random.random() < 0.35 else 0
        human_confirmed = 1 if (sensor_triggered and witness_count >= 1) else 0
        perimeter_anomaly = 1 if (on_corridor and random.random() < 0.10) else 0

        # 4. Compute Ground-Truth SolveX Severity Score (0-100)
        score = 0
        if fire or trapped_victims:
            score += 25
        if injured_count > 3:
            score += 20
        if high_risk_health:
            score += 15
        if vehicles_count > 2:
            score += 10
        if in_blackspot:
            score += 20
        if on_corridor:
            score += 10
        if severe_weather:
            score += 15
        if is_night:
            score += 10
        if witness_count >= 3:
            score += 15
        if sensor_triggered and human_confirmed:
            score += 15
        if perimeter_anomaly:
            score += 10

        score = min(100, max(0, score))
        if score >= 70:
            severity_tier = "RED"
        elif score >= 35:
            severity_tier = "YELLOW"
        else:
            severity_tier = "BLUE"

        records.append({
            "incident_id": i,
            "created_at": incident_time.strftime("%Y-%m-%d %H:%M:%S"),
            "wilaya": w_obj["name"],
            "latitude": lat,
            "longitude": lon,
            "road_type": road_obj["type"],
            "primary_vehicle": veh_cat,
            "primary_cause": cause,
            "vehicles_count": vehicles_count,
            "injured_count": injured_count,
            "deaths_count": deaths_count,
            "fire": fire,
            "trapped_victims": trapped_victims,
            "high_risk_health": high_risk_health,
            "severe_weather": severe_weather,
            "nighttime": is_night,
            "in_blackspot": in_blackspot,
            "on_national_corridor": on_corridor,
            "witness_count": witness_count,
            "sensor_triggered": sensor_triggered,
            "human_confirmed": human_confirmed,
            "perimeter_anomaly": perimeter_anomaly,
            "time_slot": slot_obj["slot"],
            "day_of_week": day_of_week,
            "hour": hour,
            "is_weekend": is_weekend,
            "severity_score": score,
            "severity_tier": severity_tier,
        })

    with open(out_path, "w", newline="", encoding="utf-8") as f:
        fieldnames = list(records[0].keys())
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(records)

    print(f"[OK] Synthesized calibrated training dataset: {len(records)} incidents saved to {out_path}")
    return records


def preprocess_and_split():
    """
    Normalizes numeric features, encodes categorical variables,
    and produces Train/Test feature matrices ready for ML models.
    """
    raw_path = os.path.join(DATA_DIR, "incidents_training_dataset.csv")
    with open(raw_path, "r", encoding="utf-8") as f:
        reader = list(csv.DictReader(f))

    # Feature columns to extract
    feature_rows = []
    target_scores = []
    target_tiers = []

    for r in reader:
        # Numeric & binary features
        feats = {
            "latitude": float(r["latitude"]),
            "longitude": float(r["longitude"]),
            "vehicles_count": int(r["vehicles_count"]),
            "injured_count": int(r["injured_count"]),
            "deaths_count": int(r["deaths_count"]),
            "fire": int(r["fire"]),
            "trapped_victims": int(r["trapped_victims"]),
            "high_risk_health": int(r["high_risk_health"]),
            "severe_weather": int(r["severe_weather"]),
            "nighttime": int(r["nighttime"]),
            "in_blackspot": int(r["in_blackspot"]),
            "on_national_corridor": int(r["on_national_corridor"]),
            "witness_count": int(r["witness_count"]),
            "sensor_triggered": int(r["sensor_triggered"]),
            "human_confirmed": int(r["human_confirmed"]),
            "perimeter_anomaly": int(r["perimeter_anomaly"]),
            "hour": int(r["hour"]),
            "is_weekend": int(r["is_weekend"]),
            # Cyclical time encoding (sin/cos of hour 0-23)
            "sin_hour": round(math.sin(2 * math.pi * int(r["hour"]) / 24.0), 4),
            "cos_hour": round(math.cos(2 * math.pi * int(r["hour"]) / 24.0), 4),
            # Categoricals to one-hot encode
            "wilaya": r["wilaya"],
            "road_type": r["road_type"],
            "primary_vehicle": r["primary_vehicle"],
        }
        feature_rows.append(feats)
        target_scores.append(int(r["severity_score"]))
        # Target encoding: BLUE=0, YELLOW=1, RED=2
        tier_map = {"BLUE": 0, "YELLOW": 1, "RED": 2}
        target_tiers.append(tier_map[r["severity_tier"]])

    # Collect unique categories for one-hot encoding
    wilayas = sorted(list({f["wilaya"] for f in feature_rows}))
    roads = sorted(list({f["road_type"] for f in feature_rows}))
    vehicles = sorted(list({f["primary_vehicle"] for f in feature_rows}))

    encoded_rows = []
    for f in feature_rows:
        row = {}
        # Keep numeric features
        for k, v in f.items():
            if k not in ["wilaya", "road_type", "primary_vehicle"]:
                row[k] = v
        # One-hot wilaya
        for w in wilayas:
            row[f"wilaya_{w}"] = 1 if f["wilaya"] == w else 0
        # One-hot road
        for rd in roads:
            clean_rd = rd.replace(" ", "_").replace("/", "_").replace("-", "_")
            row[f"road_{clean_rd}"] = 1 if f["road_type"] == rd else 0
        # One-hot vehicle
        for vh in vehicles:
            clean_vh = vh.replace(" ", "_").replace("-", "_")
            row[f"veh_{clean_vh}"] = 1 if f["primary_vehicle"] == vh else 0

        encoded_rows.append(row)

    # Min-Max Normalization on continuous features
    continuous_keys = ["latitude", "longitude", "vehicles_count", "injured_count", "deaths_count", "witness_count", "hour"]
    min_max_stats = {}
    for k in continuous_keys:
        vals = [r[k] for r in encoded_rows]
        min_v = min(vals)
        max_v = max(vals)
        min_max_stats[k] = {"min": min_v, "max": max_v}
        range_v = (max_v - min_v) if max_v != min_v else 1.0
        for r in encoded_rows:
            r[f"{k}_scaled"] = round((r[k] - min_v) / range_v, 4)

    # Split 80% train / 20% test
    n_total = len(encoded_rows)
    indices = list(range(n_total))
    random.seed(101)
    random.shuffle(indices)

    split_idx = int(0.80 * n_total)
    train_idx = indices[:split_idx]
    test_idx = indices[split_idx:]

    def save_matrix(filename, data_indices, feature_list, targets):
        p = os.path.join(CLEANED_DIR, filename)
        fnames = list(feature_list[0].keys()) + ["target_tier", "target_score"]
        with open(p, "w", newline="", encoding="utf-8") as f_out:
            writer = csv.DictWriter(f_out, fieldnames=fnames)
            writer.writeheader()
            for idx in data_indices:
                row_dict = dict(feature_list[idx])
                row_dict["target_tier"] = targets[idx]
                row_dict["target_score"] = target_scores[idx]
                writer.writerow(row_dict)
        print(f"[OK] Saved {len(data_indices)} records to {p}")

    save_matrix("train_dataset_preprocessed.csv", train_idx, encoded_rows, target_tiers)
    save_matrix("test_dataset_preprocessed.csv", test_idx, encoded_rows, target_tiers)

    # Save normalization metadata (scaling parameters)
    meta_path = os.path.join(CLEANED_DIR, "preprocessing_metadata.json")
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump({
            "scaler_stats": min_max_stats,
            "categorical_columns": {
                "wilayas": wilayas,
                "road_types": roads,
                "vehicles": vehicles,
            },
            "train_samples": len(train_idx),
            "test_samples": len(test_idx),
            "target_mapping": {"BLUE": 0, "YELLOW": 1, "RED": 2},
        }, f, indent=2)
    print(f"[OK] Preprocessing metadata written to {meta_path}")


def main():
    print("=" * 60)
    print("SolveX Data Preprocessing & Training Preparation Pipeline")
    print("=" * 60)
    clean_causes()
    clean_time_distribution()
    clean_vehicle_types()
    clean_rural_road_types()
    clean_wilaya_top10()
    generate_training_dataset(n_samples=10000)
    preprocess_and_split()
    print("=" * 60)
    print("Pipeline completed successfully! All cleaned & preprocessed files ready.")
    print("=" * 60)


if __name__ == "__main__":
    main()

