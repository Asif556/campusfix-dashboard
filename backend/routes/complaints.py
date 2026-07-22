import os
import uuid
from flask import Blueprint, request, jsonify, current_app, g
from bson import ObjectId
from datetime import datetime, timezone
from werkzeug.utils import secure_filename

from db import (
    complaints_collection,
    authorities_collection,
    notification_emails_collection,
)
from models.complaint_model import create_complaint_doc
from utils.auth import require_auth, require_admin, require_authority
from utils.assignment import effective_order, next_authority, is_auto_assign
from utils.helpers import serialize_complaint, is_valid_object_id, _fmt_ts
from utils.email_queue import (
    send_complaint_raised_to_student,
    send_complaint_raised_to_admins,
    send_assignment_to_authority,
    send_accepted_to_student,
    send_authority_rejected_to_notifications,
    send_pending_acceptance,
    send_fix_accepted_to_admins,
    send_reopened_to_admins,
    send_sms_assignment,
)

ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "gif", "webp"}


def _allowed_file(filename: str) -> bool:
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS


complaints_bp = Blueprint("complaints", __name__)

ALLOWED_STATUSES = {"Submitted", "Assigned", "In Progress", "Completed", "Pending Acceptance", "Reopened"}

# Permitted admin-driven status transitions. Assignment (-> Assigned), student
# acceptance (-> Completed) and reopening (-> Reopened) have their own endpoints,
# so "Completed" is intentionally never a valid target here.
ALLOWED_TRANSITIONS = {
    "Submitted":          {"Assigned", "In Progress"},
    "Assigned":           {"In Progress", "Pending Acceptance"},
    "In Progress":        {"Pending Acceptance"},
    "Pending Acceptance": {"In Progress"},
    "Reopened":           {"Assigned", "In Progress", "Pending Acceptance"},
    "Completed":          set(),
}

# Statuses from which an admin may (re)assign an authority. Deliberately excludes
# "Pending Acceptance" and "Completed" — a fix that's awaiting the student or already
# closed must not be silently re-routed to a new authority.
ASSIGNABLE_STATUSES = {"Submitted", "Reopened", "Rejected", "Assigned", "In Progress"}


# ── Assignment helpers ────────────────────────────────────────────────────────

def _build_assignment(authority: dict, assigned_by: str, now) -> dict:
    """The `assigned_to` sub-document stored on a complaint for its current assignee."""
    return {
        "authority_id": str(authority["_id"]),
        "name":         authority.get("name", ""),
        "email":        authority.get("email", ""),
        "phone":        authority.get("phone", ""),
        "category":     authority.get("category", ""),
        "assigned_at":  now,
        "assigned_by":  assigned_by,
    }


def _assignment_history_entry(authority: dict, assigned_by: str, now) -> dict:
    """A status_history entry recording an assignment hop.

    `assigned_by` is an admin's name for manual assigns, or "Auto-assign" for the
    auto-assign-on-create and reject-cascade paths.
    """
    return {
        "status":         "Assigned",
        "timestamp":      now,
        "authority_name": authority.get("name", ""),
        "admin_name":     assigned_by,
    }


def _notify_assignment(complaint_id) -> None:
    """Email + SMS the complaint's current assignee that they have a task to action."""
    doc = complaints_collection.find_one({"_id": ObjectId(complaint_id)})
    if not doc:
        return
    c = serialize_complaint(doc)
    send_assignment_to_authority(c)
    assigned = doc.get("assigned_to") or {}
    send_sms_assignment(
        authority_phone=assigned.get("phone", ""),
        authority_name=assigned.get("name", ""),
        ticket_number=c["ticket_number"],
        category=c["category"],
        location=c["location"],
        assigned_by=assigned.get("assigned_by", "Admin"),
    )


def _assign_to_authority(complaint_id, authority, assigned_by, reset_reject_round, expected_statuses=None):
    """Assign `complaint_id` to `authority` (fresh assignment path: manual + auto-create).

    Atomic and optionally guarded by `expected_statuses`. Returns the stored
    `assigned_to` sub-document on success, or None if the guard didn't match.
    The reject cascade does NOT use this — it needs the rejection and the reassign
    in a single update (see authority_reject).
    """
    now = datetime.now(timezone.utc)
    assigned_to = _build_assignment(authority, assigned_by, now)
    set_fields = {"status": "Assigned", "assigned_to": assigned_to, "updated_at": now}
    if reset_reject_round:
        set_fields["rejected_authority_ids"] = []

    filt = {"_id": ObjectId(complaint_id)}
    if expected_statuses is not None:
        filt["status"] = {"$in": list(expected_statuses)}

    result = complaints_collection.update_one(filt, {
        "$set": set_fields,
        "$push": {"status_history": _assignment_history_entry(authority, assigned_by, now)},
    })
    if result.matched_count == 0:
        return None
    _notify_assignment(complaint_id)
    return assigned_to


@complaints_bp.route("/complaints", methods=["POST"])
@require_auth
def create_complaint():
    """Create a new complaint."""
    try:
        if request.content_type and "multipart/form-data" in request.content_type:
            data = request.form.to_dict()
        else:
            data = request.get_json(silent=True) or {}

        # Owner is always the authenticated caller — never trust a body field.
        data["student_email"] = g.user["email"]

        required = ["category", "building", "floor", "room", "description"]
        missing = [f for f in required if not data.get(f)]
        if missing:
            return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400

        # Handle photo upload
        photo_url = ""
        if "photo" in request.files:
            file = request.files["photo"]
            if file and file.filename and _allowed_file(file.filename):
                ext = secure_filename(file.filename).rsplit(".", 1)[1].lower()
                unique_name = f"{uuid.uuid4().hex}.{ext}"
                file.save(os.path.join(current_app.config["UPLOAD_FOLDER"], unique_name))
                photo_url = f"/uploads/{unique_name}"
        data["photo_url"] = photo_url

        doc = create_complaint_doc(data)
        result = complaints_collection.insert_one(doc)

        # Build serialisable version for email (doc doesn't have _id yet)
        doc["_id"] = result.inserted_id
        c = serialize_complaint(doc)
        send_complaint_raised_to_student(c)
        send_complaint_raised_to_admins(c)

        # Auto-assign to the top-priority authority if this category is configured
        # for it. Emails the authority (accept/reject) — the student is NOT notified
        # here; they only hear back once an authority accepts.
        if is_auto_assign(doc["category"]):
            order = effective_order(doc["category"])
            if order:
                _assign_to_authority(
                    result.inserted_id, order[0], "Auto-assign",
                    reset_reject_round=True, expected_statuses={"Submitted"},
                )

        return jsonify({
            "success": True,
            "message": "Complaint submitted successfully",
            "_id": str(result.inserted_id),
        }), 201
    except Exception as e:
        print(f"Error creating complaint: {e}")
        return jsonify({"error": "Internal server error"}), 500


@complaints_bp.route("/complaints", methods=["GET"])
@require_auth
def get_complaints():
    """Return complaints with optional filters. Students are scoped to their own."""
    query = {}
    if g.user["role"] == "admin":
        if request.args.get("student_email"):
            query["student_email"] = request.args["student_email"].strip().lower()
    else:
        # Non-admins may only ever see their own complaints, regardless of params.
        query["student_email"] = g.user["email"]
    if request.args.get("status"):
        query["status"] = request.args["status"]
    if request.args.get("category"):
        query["category"] = request.args["category"]
    if request.args.get("building"):
        query["building"] = request.args["building"]

    docs = complaints_collection.find(query).sort("created_at", -1)
    return jsonify([serialize_complaint(d) for d in docs]), 200


@complaints_bp.route("/complaints/<complaint_id>", methods=["GET"])
@require_auth
def get_complaint(complaint_id):
    """Return a single complaint by ID (own complaint only, unless admin)."""
    if not is_valid_object_id(complaint_id):
        return jsonify({"error": "Invalid complaint ID"}), 400

    doc = complaints_collection.find_one({"_id": ObjectId(complaint_id)})
    if not doc:
        return jsonify({"error": "Complaint not found"}), 404

    role = g.user["role"]
    if role == "admin":
        pass  # admins see everything
    elif role == "authority":
        # An authority may view a ticket currently assigned to them.
        if (doc.get("assigned_to") or {}).get("authority_id") != g.user.get("authority_id"):
            return jsonify({"error": "Forbidden"}), 403
    else:
        if doc.get("student_email", "").lower() != g.user["email"]:
            return jsonify({"error": "Forbidden"}), 403

    return jsonify(serialize_complaint(doc)), 200


@complaints_bp.route("/complaints/<complaint_id>/status", methods=["PUT"])
@require_admin
def update_status(complaint_id):
    """Update the status of a complaint (admin only)."""
    if not is_valid_object_id(complaint_id):
        return jsonify({"error": "Invalid complaint ID"}), 400

    data = request.get_json(silent=True) or {}
    new_status = data.get("status")
    admin_name = g.user.get("name") or "Admin"

    if new_status not in ALLOWED_STATUSES:
        return jsonify({"error": f"Invalid status. Allowed: {', '.join(ALLOWED_STATUSES)}"}), 400

    doc = complaints_collection.find_one({"_id": ObjectId(complaint_id)})
    if not doc:
        return jsonify({"error": "Complaint not found"}), 404

    current_status = doc.get("status", "Submitted")
    if new_status != current_status and new_status not in ALLOWED_TRANSITIONS.get(current_status, set()):
        return jsonify({
            "error": f"Cannot change status from '{current_status}' to '{new_status}'."
        }), 409

    now = datetime.now(timezone.utc)
    history_entry = {"status": new_status, "timestamp": now}
    if admin_name:
        history_entry["admin_name"] = admin_name

    set_fields = {"status": new_status, "updated_at": now}
    # Start the student's auto-accept clock the moment the fix is marked pending.
    if new_status == "Pending Acceptance":
        set_fields["pending_since"] = now

    # Conditional on the status we just read — closes the check-then-write race.
    result = complaints_collection.update_one(
        {"_id": ObjectId(complaint_id), "status": current_status},
        {
            "$set": set_fields,
            "$push": {"status_history": history_entry},
        },
    )
    if result.matched_count == 0:
        return jsonify({"error": "Complaint status changed, please retry."}), 409

    # Send student email when admin marks pending acceptance
    if new_status == "Pending Acceptance":
        doc = complaints_collection.find_one({"_id": ObjectId(complaint_id)})
        if doc:
            send_pending_acceptance(serialize_complaint(doc))

    return jsonify({"success": True, "message": f"Status updated to {new_status}"}), 200


@complaints_bp.route("/complaints/<complaint_id>/assign", methods=["POST"])
@require_admin
def assign_complaint(complaint_id):
    """(Re)assign a complaint to an authority and request their acceptance (admin only).

    Sets status to "Assigned" and emails the authority to Accept/Reject. The student
    is NOT emailed here — they're notified only when an authority accepts. Resets the
    reject round so a fresh admin assignment isn't short-circuited by earlier rejections.
    """
    if not is_valid_object_id(complaint_id):
        return jsonify({"error": "Invalid complaint ID"}), 400

    data = request.get_json(silent=True) or {}
    authority_id = data.get("authority_id", "")
    admin_name = g.user.get("name") or "Admin"

    if not is_valid_object_id(authority_id):
        return jsonify({"error": "Valid authority_id required"}), 400

    authority = authorities_collection.find_one({"_id": ObjectId(authority_id)})
    if not authority:
        return jsonify({"error": "Authority not found"}), 404

    assigned_to = _assign_to_authority(
        complaint_id, authority, admin_name,
        reset_reject_round=True, expected_statuses=ASSIGNABLE_STATUSES,
    )
    if assigned_to is None:
        return jsonify({"error": "This complaint can no longer be assigned in its current state."}), 409

    return jsonify({
        "success": True,
        "assigned_to": {
            **{k: v for k, v in assigned_to.items() if k != "assigned_at"},
            "assigned_at": _fmt_ts(assigned_to["assigned_at"]),
        },
    }), 200


@complaints_bp.route("/authority/complaints", methods=["GET"])
@require_authority
def authority_complaints():
    """Return the calling authority's work queue: complaints currently theirs.

    Scoped to the token's authority_id and to active statuses, so a rejecter's
    exhausted (now "Rejected") ticket doesn't linger in their list.
    """
    docs = complaints_collection.find({
        "assigned_to.authority_id": g.user["authority_id"],
        "status": {"$in": ["Assigned", "In Progress", "Pending Acceptance"]},
    }).sort("updated_at", -1)
    return jsonify([serialize_complaint(d) for d in docs]), 200


@complaints_bp.route("/complaints/<complaint_id>/authority-accept", methods=["POST"])
@require_authority
def authority_accept(complaint_id):
    """Authority accepts an assignment → In Progress. Notifies the student."""
    if not is_valid_object_id(complaint_id):
        return jsonify({"error": "Invalid complaint ID"}), 400

    authority_id   = g.user["authority_id"]
    authority_name = g.user.get("name") or "Authority"
    now = datetime.now(timezone.utc)

    # Guarded on status AND "assigned to me" — only the current assignee can accept.
    result = complaints_collection.update_one(
        {"_id": ObjectId(complaint_id), "status": "Assigned", "assigned_to.authority_id": authority_id},
        {
            "$set": {"status": "In Progress", "updated_at": now},
            "$push": {"status_history": {
                "status": "In Progress",
                "timestamp": now,
                "authority_name": authority_name,
            }},
        },
    )
    if result.matched_count == 0:
        return jsonify({"error": "This task is not awaiting your acceptance."}), 409

    doc = complaints_collection.find_one({"_id": ObjectId(complaint_id)})
    if doc:
        send_accepted_to_student(serialize_complaint(doc))

    return jsonify({"success": True, "message": "Assignment accepted."}), 200


@complaints_bp.route("/complaints/<complaint_id>/authority-reject", methods=["POST"])
@require_authority
def authority_reject(complaint_id):
    """Authority rejects an assignment (reason required).

    Cascades to the next authority in the category's priority order if one remains
    (they get the assignment email); otherwise the complaint becomes "Rejected" and
    awaits manual admin re-assignment. The rejection and the reassign are a single
    atomic update. The student is never emailed; the notification list always is.
    """
    if not is_valid_object_id(complaint_id):
        return jsonify({"error": "Invalid complaint ID"}), 400

    data   = request.get_json(silent=True) or {}
    reason = data.get("reason", "").strip()
    if not reason:
        return jsonify({"error": "A reason is required to reject an assignment."}), 400

    authority_id   = g.user["authority_id"]
    authority_name = g.user.get("name") or "Authority"

    doc = complaints_collection.find_one({"_id": ObjectId(complaint_id)})
    if not doc:
        return jsonify({"error": "Complaint not found"}), 404
    if doc.get("status") != "Assigned" or (doc.get("assigned_to") or {}).get("authority_id") != authority_id:
        return jsonify({"error": "This task is not awaiting your acceptance."}), 409

    category = doc.get("category", "")
    exclude  = set(doc.get("rejected_authority_ids", [])) | {authority_id}
    nxt      = next_authority(category, exclude)

    now = datetime.now(timezone.utc)
    reject_entry = {
        "status":         "Rejected",
        "timestamp":      now,
        "authority_name": authority_name,
        "reason":         reason,
    }
    # Filter guards both the status and "still assigned to me" — closes the race
    # against a concurrent admin reassign / another action on this ticket.
    guard = {"_id": ObjectId(complaint_id), "status": "Assigned", "assigned_to.authority_id": authority_id}

    if nxt:
        assign_entry = _assignment_history_entry(nxt, "Auto-assign", now)
        result = complaints_collection.update_one(guard, {
            "$set": {
                "status":      "Assigned",
                "assigned_to": _build_assignment(nxt, "Auto-assign", now),
                "updated_at":  now,
            },
            "$push":     {"status_history": {"$each": [reject_entry, assign_entry]}},
            "$addToSet": {"rejected_authority_ids": authority_id},
        })
    else:
        result = complaints_collection.update_one(guard, {
            "$set":      {"status": "Rejected", "updated_at": now},
            "$push":     {"status_history": reject_entry},
            "$addToSet": {"rejected_authority_ids": authority_id},
        })

    if result.matched_count == 0:
        return jsonify({"error": "This task is not awaiting your acceptance."}), 409

    reassigned_name = ""
    if nxt:
        _notify_assignment(complaint_id)          # email + SMS the next authority
        reassigned_name = nxt.get("name", "")

    fresh = complaints_collection.find_one({"_id": ObjectId(complaint_id)})
    recipients = [d["email"] for d in notification_emails_collection.find() if d.get("email")]
    if fresh and recipients:
        send_authority_rejected_to_notifications(
            serialize_complaint(fresh), reason, authority_name, reassigned_name, recipients,
        )

    msg = (f"Assignment rejected. Re-assigned to {reassigned_name}."
           if reassigned_name else
           "Assignment rejected. Awaiting admin re-assignment.")
    return jsonify({"success": True, "message": msg, "reassigned_to": reassigned_name}), 200


@complaints_bp.route("/complaints/<complaint_id>/authority-mark-done", methods=["POST"])
@require_authority
def authority_mark_done(complaint_id):
    """Authority marks their accepted task as done → Pending Acceptance. Notifies the student."""
    if not is_valid_object_id(complaint_id):
        return jsonify({"error": "Invalid complaint ID"}), 400

    authority_id   = g.user["authority_id"]
    authority_name = g.user.get("name") or "Authority"
    now = datetime.now(timezone.utc)

    result = complaints_collection.update_one(
        {"_id": ObjectId(complaint_id), "status": "In Progress", "assigned_to.authority_id": authority_id},
        {
            # `pending_since` starts the student's auto-accept clock.
            "$set": {"status": "Pending Acceptance", "pending_since": now, "updated_at": now},
            "$push": {"status_history": {
                "status": "Pending Acceptance",
                "timestamp": now,
                "authority_name": authority_name,
            }},
        },
    )
    if result.matched_count == 0:
        return jsonify({"error": "This task is not currently in progress under your account."}), 409

    doc = complaints_collection.find_one({"_id": ObjectId(complaint_id)})
    if doc:
        send_pending_acceptance(serialize_complaint(doc))

    return jsonify({"success": True, "message": "Marked as done. Awaiting student confirmation."}), 200


@complaints_bp.route("/complaints/<complaint_id>/accept", methods=["POST"])
@require_auth
def accept_complaint(complaint_id):
    """Student accepts the fix and provides feedback."""
    if not is_valid_object_id(complaint_id):
        return jsonify({"error": "Invalid complaint ID"}), 400

    data = request.get_json(silent=True) or {}
    feedback = data.get("feedback", "").strip()
    student_email = g.user["email"]
    student_name = g.user.get("name") or "Student"

    doc = complaints_collection.find_one({"_id": ObjectId(complaint_id)})
    if not doc:
        return jsonify({"error": "Complaint not found"}), 404

    if doc.get("student_email", "").lower() != student_email:
        return jsonify({"error": "Forbidden"}), 403

    if doc.get("status") != "Pending Acceptance":
        return jsonify({"error": "Complaint is not awaiting acceptance"}), 409

    now = datetime.now(timezone.utc)
    # Conditional on "Pending Acceptance" — two concurrent accepts can't both win.
    result = complaints_collection.update_one(
        {"_id": ObjectId(complaint_id), "status": "Pending Acceptance"},
        {
            "$set": {
                "status": "Completed",
                "student_feedback": feedback,
                "updated_at": now,
            },
            "$push": {"status_history": {
                "status": "Completed",
                "timestamp": now,
                "student_name": student_name,
            }},
        },
    )
    if result.matched_count == 0:
        return jsonify({"error": "Complaint is not awaiting acceptance"}), 409

    doc = complaints_collection.find_one({"_id": ObjectId(complaint_id)})
    if doc:
        send_fix_accepted_to_admins(serialize_complaint(doc), feedback, student_name)

    return jsonify({"success": True, "message": "Fix accepted. Complaint closed."}), 200


@complaints_bp.route("/complaints/<complaint_id>/reopen", methods=["POST"])
@require_auth
def reopen_complaint(complaint_id):
    """Student reopens the complaint with a reason."""
    if not is_valid_object_id(complaint_id):
        return jsonify({"error": "Invalid complaint ID"}), 400

    data = request.get_json(silent=True) or {}
    reason = data.get("reason", "").strip()
    student_email = g.user["email"]
    student_name = g.user.get("name") or "Student"

    if not reason:
        return jsonify({"error": "A reason is required to reopen the complaint."}), 400

    doc = complaints_collection.find_one({"_id": ObjectId(complaint_id)})
    if not doc:
        return jsonify({"error": "Complaint not found"}), 404

    if doc.get("student_email", "").lower() != student_email:
        return jsonify({"error": "Forbidden"}), 403

    if doc.get("status") != "Pending Acceptance":
        return jsonify({"error": "Complaint is not awaiting acceptance"}), 409

    now = datetime.now(timezone.utc)
    # Conditional on "Pending Acceptance" — closes the check-then-write race.
    result = complaints_collection.update_one(
        {"_id": ObjectId(complaint_id), "status": "Pending Acceptance"},
        {
            "$set": {
                "status": "Reopened",
                "reopen_reason": reason,
                "updated_at": now,
            },
            "$push": {"status_history": {
                "status": "Reopened",
                "timestamp": now,
                "student_name": student_name,
                "reason": reason,
            }},
        },
    )
    if result.matched_count == 0:
        return jsonify({"error": "Complaint is not awaiting acceptance"}), 409

    doc = complaints_collection.find_one({"_id": ObjectId(complaint_id)})
    if doc:
        send_reopened_to_admins(serialize_complaint(doc), reason, student_name)

    return jsonify({"success": True, "message": "Complaint reopened."}), 200


@complaints_bp.route("/complaints/recurring", methods=["GET"])
@require_admin
def recurring_complaints():
    """Return rooms/categories with 3+ complaints (recurring issues)."""
    pipeline = [
        {"$group": {
            "_id": {"building": "$building", "room": "$room", "category": "$category"},
            "count": {"$sum": 1},
            "latest_status": {"$last": "$status"},
        }},
        {"$match": {"count": {"$gte": 3}}},
        {"$sort": {"count": -1}},
    ]
    results = list(complaints_collection.aggregate(pipeline))
    return jsonify([{
        "building": r["_id"]["building"],
        "room": r["_id"]["room"],
        "category": r["_id"]["category"],
        "count": r["count"],
        "latest_status": r["latest_status"],
    } for r in results]), 200
