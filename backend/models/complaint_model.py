import uuid
from datetime import datetime, timezone


def generate_ticket_number() -> str:
    now = datetime.now(timezone.utc)
    suffix = uuid.uuid4().hex[:5].upper()
    return f"CF-{now.strftime('%Y%m')}-{suffix}"


def create_complaint_doc(data):
    """Build a complaint document for MongoDB insertion."""
    now = datetime.now(timezone.utc)
    return {
        "ticket_number": generate_ticket_number(),
        "student_email": data.get("student_email", ""),
        "category": data.get("category", ""),
        "building": data.get("building", ""),
        "floor": data.get("floor", ""),
        "room": data.get("room", ""),
        "description": data.get("description", ""),
        "photo_url": data.get("photo_url", ""),
        "status": "Submitted",
        "status_history": [{"status": "Submitted", "timestamp": now}],
        # Authorities who have rejected this complaint in the current round; the
        # reject cascade skips them. Reset to [] on any manual (re)assignment.
        "rejected_authority_ids": [],
        "created_at": now,
        "updated_at": now,
    }
