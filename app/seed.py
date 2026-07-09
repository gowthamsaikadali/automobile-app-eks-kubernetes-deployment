"""
seed.py - creates the `vehicles` table (if missing) and inserts starter data.

Run this ONCE after RDS is up and the app's Deployment/Pod can reach it -
either as a one-off `kubectl exec`, a Kubernetes Job (see k8s/*/seed-job.yaml
or the Helm post-install hook), or locally via port-forward.

All configuration comes from environment variables (DB_HOST, DB_PORT,
DB_NAME, DB_USER, DB_PASSWORD) - the SAME variables the main app uses, so
there is no separate config to keep in sync. This script intentionally does
NOT read a .env file or hardcode indentation-sensitive shell exports, since
that was the root cause of a real bug hit in an earlier version of this
project (mismatched indentation in a bash heredoc silently broke an env var).
"""
import sys
import time

import db

SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS vehicles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    model VARCHAR(100) NOT NULL,
    assembly_line VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'In Production',
    units_produced INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
"""

SEED_ROWS = [
    ("Falcon EV", "Assembly Line 1", "In Production", 128),
    ("Titan Pickup", "Assembly Line 2", "Quality Check", 76),
    ("Voyager Hybrid", "Assembly Line 3", "In Production", 54),
    ("Comet Compact", "Assembly Line 1", "Painting", 210),
]


def main():
    print(f"[seed] connecting to {db.DB_HOST}:{db.DB_PORT}/{db.DB_NAME} as {db.DB_USER}...")

    if not db.wait_for_db(max_attempts=15, delay_seconds=4):
        print("[seed] ERROR: could not reach the database after multiple attempts.")
        sys.exit(1)

    with db.get_cursor() as cursor:
        print("[seed] creating table `vehicles` if it doesn't exist...")
        cursor.execute(SCHEMA_SQL)

        cursor.execute("SELECT COUNT(*) AS c FROM vehicles")
        count = cursor.fetchone()["c"]

        if count > 0:
            print(f"[seed] table already has {count} row(s) - skipping seed insert.")
        else:
            print(f"[seed] inserting {len(SEED_ROWS)} starter row(s)...")
            cursor.executemany(
                "INSERT INTO vehicles (model, assembly_line, status, units_produced) "
                "VALUES (%s, %s, %s, %s)",
                SEED_ROWS,
            )

    print("[seed] done.")


if __name__ == "__main__":
    main()
