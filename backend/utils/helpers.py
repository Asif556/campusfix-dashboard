from datetime import timedelta

from bson import ObjectId

from config import AUTO_ACCEPT_AFTER_HOURS


def _normalize_photo(url: str | None) -> str | None:
    """Convert absolute localhost upload URLs to relative paths."""
    if not url:
        return None
    # Strip any hardcoded localhost origin so the Vite proxy can serve it
    for prefix in ("http://localhost:5000", "http://localhost:8000", "http://127.0.0.1:5000", "http://127.0.0.1:8000"):
        if url.startswith(prefix):
            return url[len(prefix):]
    return url


def _fmt_ts(dt) -> str:
    """Return ISO-8601 UTC string from a datetime, or empty string.
    PyMongo returns naive datetimes (no tzinfo) even though they are stored
    as UTC.  We always append '+00:00' so the browser parses them correctly
    as UTC before converting to the display timezone (Asia/Calcutta).
    """
    if not dt:
        return ""
    if hasattr(dt, "isoformat"):
        iso = dt.isoformat()
        # Naive datetime → must be UTC (PyMongo convention); make it explicit
        if dt.tzinfo is None:
            iso += "+00:00"
        return iso
    return str(dt)


def _serialize_assigned_to(at):
    if not at:
        return None
    return {
        "authority_id": str(at.get("authority_id", "")),
        "name": at.get("name", ""),
        "email": at.get("email", ""),
        "phone": at.get("phone", ""),
        "category": at.get("category", ""),
        "assigned_at": _fmt_ts(at.get("assigned_at")),
        "assigned_by": at.get("assigned_by", ""),
    }


def serialize_complaint(doc):
    """Convert a MongoDB complaint document to a JSON-safe dict."""
    created_at = doc.get("created_at")

    # Build status_history: list of {status, timestamp, ...actor fields}
    raw_history = doc.get("status_history", [])
    status_history = [
        {
            "status": h.get("status", ""),
            "timestamp": _fmt_ts(h.get("timestamp")),
            "admin_name": h.get("admin_name", ""),
            "authority_name": h.get("authority_name", ""),
            "student_name": h.get("student_name", ""),
            "reason": h.get("reason", ""),
            # True on the Completed entry the sweeper writes when nobody responded.
            "auto_accepted": bool(h.get("auto_accepted", False)),
        }
        for h in raw_history
    ]

    # Fallback ticket number for old records that predate this field
    ticket_number = doc.get("ticket_number") or f"CF-LEGACY-{str(doc['_id'])[-5:].upper()}"

    # Deadline by which an unresponded "Pending Acceptance" fix is auto-accepted.
    # Legacy docs pending before `pending_since` existed fall back to updated_at.
    status = doc.get("status", "Submitted")
    pending_since = doc.get("pending_since")
    if status == "Pending Acceptance" and not pending_since:
        pending_since = doc.get("updated_at")
    auto_accept_at = (
        _fmt_ts(pending_since + timedelta(hours=AUTO_ACCEPT_AFTER_HOURS))
        if status == "Pending Acceptance" and pending_since else ""
    )

    return {
        "_id": str(doc["_id"]),
        "ticket_number": ticket_number,
        "student_email": doc.get("student_email", ""),
        "category": doc.get("category", ""),
        "location": {
            "building": doc.get("building", ""),
            "floor": doc.get("floor", ""),
            "room": doc.get("room", ""),
        },
        "description": doc.get("description", ""),
        "status": doc.get("status", "Submitted"),
        "status_history": status_history,
        # Keep legacy `date` for any code still using it
        "date": created_at.strftime("%Y-%m-%d") if created_at else "",
        "timestamp": _fmt_ts(created_at),
        "photo": _normalize_photo(doc.get("photo_url")),
        "assignedTo": _serialize_assigned_to(doc.get("assigned_to")),
        "student_feedback": doc.get("student_feedback", ""),
        "reopen_reason": doc.get("reopen_reason", ""),
        # ISO deadline for auto-accept (empty unless currently Pending Acceptance).
        "auto_accept_at": auto_accept_at,
        # True once the fix was auto-accepted because the student never responded.
        "auto_accepted": bool(doc.get("auto_accepted", False)),
    }


def is_valid_object_id(id_str):
    """Check whether a string is a valid MongoDB ObjectId."""
    return ObjectId.is_valid(id_str)
