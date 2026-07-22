"""
Background sweeper that auto-accepts a fix the student never responded to.

When a complaint is marked "Pending Acceptance", the student is asked to accept the
fix or reopen it. If they do neither within AUTO_ACCEPT_AFTER_HOURS, this daemon
closes the ticket on their behalf — status -> "Completed", flagged auto_accepted —
mirroring the manual accept path. The student and admins are notified.

The completing update is atomically guarded on status == "Pending Acceptance", so
running this in several gunicorn workers is safe: only one update wins per complaint
and only that worker sends the notifications.
"""
import threading
import time
from datetime import datetime, timezone, timedelta

from config import AUTO_ACCEPT_AFTER_HOURS, AUTO_ACCEPT_SWEEP_INTERVAL_SECONDS
from db import complaints_collection
from utils.helpers import serialize_complaint
from utils.email_queue import (
    send_fix_auto_accepted_to_admins,
    send_fix_auto_accepted_to_student,
)

_AUTO_ACCEPT_NOTE = f"Auto-accepted — no student response within {AUTO_ACCEPT_AFTER_HOURS}h"


def _expiry_query(cutoff):
    """Pending-acceptance complaints whose deadline has passed.

    New complaints carry `pending_since`; complaints that entered pending before that
    field existed fall back to `updated_at` (which, while pending, equals the entry time).
    """
    return {
        "status": "Pending Acceptance",
        "$or": [
            {"pending_since": {"$lte": cutoff}},
            {"pending_since": {"$exists": False}, "updated_at": {"$lte": cutoff}},
        ],
    }


def sweep_once() -> int:
    """Auto-accept every pending-acceptance complaint past its deadline.

    Returns the number of complaints closed this pass.
    """
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(hours=AUTO_ACCEPT_AFTER_HOURS)
    closed = 0
    for doc in complaints_collection.find(_expiry_query(cutoff)):
        # Atomic + status-guarded: if the student accepts/reopens in this instant,
        # their update wins and this one no-ops (modified_count == 0).
        result = complaints_collection.update_one(
            {"_id": doc["_id"], "status": "Pending Acceptance"},
            {
                "$set": {
                    "status": "Completed",
                    "student_feedback": doc.get("student_feedback", ""),
                    "auto_accepted": True,
                    "updated_at": now,
                },
                "$push": {"status_history": {
                    "status": "Completed",
                    "timestamp": now,
                    "auto_accepted": True,
                    "note": _AUTO_ACCEPT_NOTE,
                }},
            },
        )
        if result.modified_count:
            closed += 1
            fresh = complaints_collection.find_one({"_id": doc["_id"]})
            if fresh:
                c = serialize_complaint(fresh)
                send_fix_auto_accepted_to_student(c)
                send_fix_auto_accepted_to_admins(c)
    return closed


def _worker() -> None:
    # Sweep once on startup (catches anything that expired while the server was down),
    # then on a fixed interval.
    while True:
        try:
            n = sweep_once()
            if n:
                print(f"[auto-accept] Closed {n} unresponded complaint(s).")
        except Exception as exc:  # pragma: no cover
            print(f"[auto-accept] Sweep failed: {exc}")
        time.sleep(max(60, AUTO_ACCEPT_SWEEP_INTERVAL_SECONDS))


_thread: threading.Thread | None = None


def start_auto_accept_worker() -> None:
    """Start the daemon sweeper thread once (idempotent)."""
    global _thread
    if _thread is None or not _thread.is_alive():
        _thread = threading.Thread(target=_worker, daemon=True, name="auto-accept-sweeper")
        _thread.start()
