import argparse, json, csv, time
from pathlib import Path
from datetime import datetime

def count_lines(path: Path) -> int:
    if not path.exists():
        return 0
    return sum(1 for _ in path.open("r", errors="ignore"))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--run-id", required=True)
    ap.add_argument("--workload", default="baseline")
    ap.add_argument("--duration-sec", type=int, default=60)
    args = ap.parse_args()

    run_id = args.run_id
    raw_dir = Path("data/raw") / run_id
    processed_dir = Path("data/processed")
    processed_dir.mkdir(parents=True, exist_ok=True)

    audit_path = raw_dir / "auditd_export.log"
    wazuh_path = raw_dir / "wazuh_alerts.json"

    audit_events = count_lines(audit_path)
    wazuh_alerts = count_lines(wazuh_path)

    # Placeholder time-to-first-alert. Replace with real parsing later.
    time_to_first_alert_sec = ""

    metrics_csv = processed_dir / f"run_{run_id}_metrics.csv"
    metadata_json = processed_dir / f"run_{run_id}_metadata.json"

    with metrics_csv.open("w", newline="") as f:
        w = csv.DictWriter(
            f,
            fieldnames=["run_id","workload","audit_events","wazuh_alerts","time_to_first_alert_sec","duration_sec"]
        )
        w.writeheader()
        w.writerow({
            "run_id": run_id,
            "workload": args.workload,
            "audit_events": audit_events,
            "wazuh_alerts": wazuh_alerts,
            "time_to_first_alert_sec": time_to_first_alert_sec,
            "duration_sec": args.duration_sec
        })

    metadata = {
        "run_id": run_id,
        "workload": args.workload,
        "duration_sec": args.duration_sec,
        "collected_utc": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "audit_source_file": str(audit_path),
        "wazuh_source_file": str(wazuh_path)
    }
    metadata_json.write_text(json.dumps(metadata, indent=2))

    print(f"[ok] wrote {metrics_csv}")
    print(f"[ok] wrote {metadata_json}")

if __name__ == "__main__":
    main()

