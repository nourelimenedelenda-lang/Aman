"""
app/detector_model/train_model.py: Executes model training, evaluation, comparison, and export.
"""
import json
import os
import joblib
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score, f1_score

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CLEANED_DIR = os.path.join(BASE_DIR, "data", "cleaned")
LOGIC_DIR = os.path.join(os.path.dirname(BASE_DIR), "logic")

TARGET_NAMES = ["BLUE (Info)", "YELLOW (Warning)", "RED (Critical)"]


def load_data():
    train_path = os.path.join(CLEANED_DIR, "train_dataset_preprocessed.csv")
    test_path = os.path.join(CLEANED_DIR, "test_dataset_preprocessed.csv")

    train_df = pd.read_csv(train_path)
    test_df = pd.read_csv(test_path)

    target_cols = ["target_tier", "target_score"]
    feature_cols = [c for c in train_df.columns if c not in target_cols]

    X_train = train_df[feature_cols]
    y_train = train_df["target_tier"]

    X_test = test_df[feature_cols]
    y_test = test_df["target_tier"]

    return X_train, y_train, X_test, y_test, feature_cols


def train_and_evaluate():
    print("=" * 65)
    print("SolveX Accident Severity Model Training & Evaluation")
    print("=" * 65)

    X_train, y_train, X_test, y_test, feature_cols = load_data()
    print(f"Loaded {X_train.shape[0]:,} training samples and {X_test.shape[0]:,} test samples.")
    print(f"Total features: {len(feature_cols)}\n")

    # 1. Random Forest
    print("--> Training Model 1: Balanced Random Forest Classifier...")
    rf = RandomForestClassifier(
        n_estimators=150,
        max_depth=12,
        random_state=42,
        class_weight="balanced",
        n_jobs=-1,
    )
    rf.fit(X_train, y_train)
    y_pred_rf = rf.predict(X_test)
    acc_rf = accuracy_score(y_test, y_pred_rf)
    f1_rf = f1_score(y_test, y_pred_rf, average="macro")

    print(f"    Random Forest Accuracy: {acc_rf:.2%} | Macro F1: {f1_rf:.4f}")
    print("\n[Random Forest Classification Report]:")
    print(classification_report(y_test, y_pred_rf, target_names=TARGET_NAMES))
    print("[Random Forest Confusion Matrix]:")
    print(confusion_matrix(y_test, y_pred_rf))
    print("-" * 65)

    # 2. Gradient Boosting
    print("--> Training Model 2: Gradient Boosting Classifier...")
    gb = GradientBoostingClassifier(
        n_estimators=120,
        learning_rate=0.1,
        max_depth=5,
        random_state=42,
    )
    gb.fit(X_train, y_train)
    y_pred_gb = gb.predict(X_test)
    acc_gb = accuracy_score(y_test, y_pred_gb)
    f1_gb = f1_score(y_test, y_pred_gb, average="macro")

    print(f"    Gradient Boosting Accuracy: {acc_gb:.2%} | Macro F1: {f1_gb:.4f}")
    print("\n[Gradient Boosting Classification Report]:")
    print(classification_report(y_test, y_pred_gb, target_names=TARGET_NAMES))
    print("[Gradient Boosting Confusion Matrix]:")
    print(confusion_matrix(y_test, y_pred_gb))
    print("=" * 65)

    # Select best model
    if f1_rf >= f1_gb:
        best_name = "RandomForest"
        best_model = rf
        best_acc = acc_rf
        best_f1 = f1_rf
        importances = rf.feature_importances_
    else:
        best_name = "GradientBoosting"
        best_model = gb
        best_acc = acc_gb
        best_f1 = f1_gb
        importances = gb.feature_importances_

    print(f"Selected Best Model: {best_name} (Acc: {best_acc:.2%}, Macro F1: {best_f1:.4f})")

    # Top Feature Importances
    feat_imp = sorted(zip(feature_cols, importances), key=lambda x: x[1], reverse=True)[:10]
    print("\nTop 10 Most Predictive Features:")
    for rank, (feat, imp) in enumerate(feat_imp, 1):
        print(f"  {rank:>2}. {feat:<28}: {imp:.4f}")

    # Serialize Best Model
    local_model_path = os.path.join(BASE_DIR, "severity_model.joblib")
    logic_model_path = os.path.join(LOGIC_DIR, "severity_model.joblib")

    joblib.dump(best_model, local_model_path)
    joblib.dump(best_model, logic_model_path)
    print(f"\n[OK] Model successfully saved to: {local_model_path}")
    print(f"[OK] Model successfully exported to backend logic: {logic_model_path}")

    # Save Metadata
    metadata = {
        "model_type": best_name,
        "accuracy": round(best_acc, 4),
        "macro_f1": round(best_f1, 4),
        "feature_count": len(feature_cols),
        "feature_names": feature_cols,
        "target_classes": {0: "BLUE", 1: "YELLOW", 2: "RED"},
        "top_features": [{feat: round(imp, 4)} for feat, imp in feat_imp],
    }

    meta_path1 = os.path.join(BASE_DIR, "model_metadata.json")
    meta_path2 = os.path.join(LOGIC_DIR, "model_metadata.json")
    with open(meta_path1, "w", encoding="utf-8") as f:
        json.dump(metadata, f, indent=2)
    with open(meta_path2, "w", encoding="utf-8") as f:
        json.dump(metadata, f, indent=2)
    print(f"[OK] Metadata saved to {meta_path1} and {meta_path2}")

    # Sample Inference Test
    sample = X_test.iloc[[0]]
    pred_idx = best_model.predict(sample)[0]
    probs = best_model.predict_proba(sample)[0]
    print("\n=== Live Sample Inference Validation ===")
    print(f"Ground-Truth Tier : {TARGET_NAMES[y_test.iloc[0]]}")
    print(f"Predicted Tier    : {TARGET_NAMES[pred_idx]}")
    for name, p in zip(TARGET_NAMES, probs):
        print(f"  • {name:<18}: {p:.1%}")
    print("=" * 65)


if __name__ == "__main__":
    train_and_evaluate()

