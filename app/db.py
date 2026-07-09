"""
db.py - MySQL connection helper for the AutoForge app.

Uses PyMySQL (pure Python, no compiled dependencies needed in the slim
Docker image) with a small connection-per-request pattern via a context
manager. Configuration comes entirely from environment variables so it
works cleanly with Kubernetes ConfigMaps (host/port/name/user) and
Secrets (password).
"""
import os
import time
from contextlib import contextmanager

import pymysql
import pymysql.cursors

DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_PORT = int(os.environ.get("DB_PORT", "3306"))
DB_NAME = os.environ.get("DB_NAME", "autoforge")
DB_USER = os.environ.get("DB_USER", "autoforge_admin")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "")
DB_CONNECT_TIMEOUT = int(os.environ.get("DB_CONNECT_TIMEOUT", "5"))


def get_connection():
    return pymysql.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        connect_timeout=DB_CONNECT_TIMEOUT,
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True,
    )


@contextmanager
def get_cursor():
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            yield cursor
    finally:
        conn.close()


def wait_for_db(max_attempts=10, delay_seconds=3):
    """Used by the seed Job / app startup to wait for RDS to accept connections."""
    for attempt in range(1, max_attempts + 1):
        try:
            conn = get_connection()
            conn.close()
            return True
        except Exception as exc:  # noqa: BLE001
            print(f"[db] attempt {attempt}/{max_attempts} failed: {exc}")
            time.sleep(delay_seconds)
    return False


def db_health_check():
    """Lightweight check used by /readyz - returns True/False, never raises."""
    try:
        with get_cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
        return True
    except Exception:  # noqa: BLE001
        return False
