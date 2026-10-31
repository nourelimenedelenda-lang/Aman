"""
seed.py: Seeds demo data for Algerian road infrastructure into the SolveX database.

Populates:
  - Accident Blackspots (Points Noirs): Gorges de Chiffa, Gorges de Lakhdaria, Descente de Djebahia.
  - Healthcare Infrastructure: CHU Mustapha Pacha, CHU Franz Fanon, EPH Lakhdaria (Trauma centers).
  - Primary First Responders: Protection Civile (14) and Gendarmerie Nationale (1055).
  - Towing Fleets (Dépannage / Remorquage) for rapid roadway clearance.
  - Driver Profiles with Emergency Health Passports (Blood types, chronic illnesses, allergies, contacts).
"""
import sys
from app.database import Base, SessionLocal, engine
from app.models import Blackspot, Service, User


def seed_data():
    print("Recreating database tables...")
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)

    db = SessionLocal()
    try:
        # 1. Geofenced Accident Blackspots (Points Noirs)
        blackspots = [
            Blackspot(
                name="Gorges de Chiffa (RN1)",
                latitude=36.4180,
                longitude=2.8020,
                radius_m=1500,
                wilaya="Blida",
            ),
            Blackspot(
                name="Gorges de Lakhdaria (AEO / RN5)",
                latitude=36.5650,
                longitude=3.5930,
                radius_m=2000,
                wilaya="Bouira",
            ),
            Blackspot(
                name="Descente de Djebahia (AEO)",
                latitude=36.4670,
                longitude=3.7310,
                radius_m=1500,
                wilaya="Bouira",
            ),
            Blackspot(
                name="Col des 2 Bassins (Tablat)",
                latitude=36.4100,
                longitude=3.3100,
                radius_m=1200,
                wilaya="Medea",
            ),
            Blackspot(
                name="Corniche Oranaise (Kristel)",
                latitude=35.8200,
                longitude=-0.4900,
                radius_m=1000,
                wilaya="Oran",
            ),
        ]
        db.add_all(blackspots)

        # 2. Emergency Services Directory
        services = [
            # Hospitals & Regional Trauma Centers
            Service(
                name="CHU Mustapha Pacha",
                type="hospital",
                latitude=36.7580,
                longitude=3.0530,
                wilaya="Alger",
                phone="021235555",
                is_chu=True,
                has_trauma_center=True,
            ),
            Service(
                name="CHU Franz Fanon",
                type="hospital",
                latitude=36.4710,
                longitude=2.8290,
                wilaya="Blida",
                phone="025301010",
                is_chu=True,
                has_trauma_center=True,
            ),
            Service(
                name="EPH Lakhdaria",
                type="hospital",
                latitude=36.5630,
                longitude=3.5850,
                wilaya="Bouira",
                phone="026902020",
                is_chu=False,
                has_trauma_center=True,
            ),
            Service(
                name="CHU Nedir Mohamed",
                type="hospital",
                latitude=36.7110,
                longitude=4.0450,
                wilaya="Tizi Ouzou",
                phone="026211515",
                is_chu=True,
                has_trauma_center=True,
            ),
            # Protection Civile Units (14)
            Service(
                name="Unité Principale Protection Civile Blida",
                type="protection_civile",
                latitude=36.4800,
                longitude=2.8350,
                wilaya="Blida",
                phone="14",
            ),
            Service(
                name="Unité Secondaire Protection Civile Lakhdaria",
                type="protection_civile",
                latitude=36.5620,
                longitude=3.5900,
                wilaya="Bouira",
                phone="14",
            ),
            Service(
                name="Direction Générale Protection Civile Hydra",
                type="protection_civile",
                latitude=36.7380,
                longitude=3.0380,
                wilaya="Alger",
                phone="14",
            ),
            # Gendarmerie Nationale (1055)
            Service(
                name="Brigade Autoroutière Gendarmerie Lakhdaria",
                type="gendarmerie",
                latitude=36.5670,
                longitude=3.5890,
                wilaya="Bouira",
                phone="1055",
            ),
            Service(
                name="Brigade Gendarmerie Nationale Chiffa",
                type="gendarmerie",
                latitude=36.4250,
                longitude=2.8100,
                wilaya="Blida",
                phone="1055",
            ),
            Service(
                name="Escadron Sécurité Routière Baba Ali",
                type="gendarmerie",
                latitude=36.6500,
                longitude=3.0300,
                wilaya="Alger",
                phone="1055",
            ),
            # Towing & Recovery Fleet (Dépannage / Remorquage)
            Service(
                name="Remorquage Express Chiffa Auto",
                type="towing",
                latitude=36.4300,
                longitude=2.8150,
                wilaya="Blida",
                phone="+213550123456",
            ),
            Service(
                name="Dépannage Rapide Lakhdaria AEO",
                type="towing",
                latitude=36.5680,
                longitude=3.5920,
                wilaya="Bouira",
                phone="+213551987654",
            ),
            Service(
                name="SOS Autoroute Alger Dépannage",
                type="towing",
                latitude=36.6800,
                longitude=3.0600,
                wilaya="Alger",
                phone="+213552345678",
            ),
        ]
        db.add_all(services)

        # 3. Demo User Profiles with Emergency Health Passports
        users = [
            User(
                full_name="Karim Belkacem",
                phone="+213550112233",
                blood_type="O+",
                chronic_conditions="diabetes,hypertension",
                allergies="penicillin",
                implanted_devices="",
                emergency_contact_name="Amina Belkacem",
                emergency_contact_phone="+213550998877",
                insurance_provider="CAAT Assurances",
                policy_number="CAAT-2026-99182",
            ),
            User(
                full_name="Yasmine Dahmani",
                phone="+213661445566",
                blood_type="AB-",
                chronic_conditions="asthma",
                allergies="aspirin",
                implanted_devices="pacemaker",
                emergency_contact_name="Reda Dahmani",
                emergency_contact_phone="+213661778899",
                insurance_provider="SAA Assurances",
                policy_number="SAA-AUTO-44019",
            ),
            User(
                full_name="Omar Haddad",
                phone="+213770112233",
                blood_type="B+",
                chronic_conditions="",
                allergies="",
                implanted_devices="",
                emergency_contact_name="Fatima Haddad",
                emergency_contact_phone="+213770990011",
                insurance_provider="Cash Assurances",
                policy_number="CASH-POL-10822",
            ),
        ]
        db.add_all(users)

        db.commit()
        print("Database successfully seeded with Algerian emergency infrastructure!")
        print(f"  - {len(blackspots)} Blackspots (Points Noirs)")
        print(f"  - {len(services)} Emergency Services (Hospitals, PC 14, GN 1055, Towing)")
        print(f"  - {len(users)} User Health Passports")
    finally:
        db.close()


if __name__ == "__main__":
    seed_data()

