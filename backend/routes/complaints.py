import os
import uuid
from flask import Blueprint, request, jsonify, current_app
from bson import ObjectId
from datetime import datetime, timezone
from werkzeug.utils import secure_filename

from db import complaints_collection
from models.complaint_model import create_complaint_doc
from utils.helpers import serialize_complaint, is_valid_object_id, _fmt_ts
from utils.email_queue import (
    send_complaint_raised_to_student,
    send_complaint_raised_to_admins,
    send_authority_assigned,
    send_pending_acceptance,
    send_fix_accepted_to_admins,
    send_reopened_to_admins,
    send_sms_assignment,
)

ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "gif", "webp"}


def _allowed_file(filename: str) -> bool:
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS


def _is_admin_email(email: str) -> bool:
    """Return True if the email matches any configured admin."""
    if not email:
        return False
    email = email.strip().lower()
    i = 1
    while True:
        admin_email = os.getenv(f"ADMIN_{i}_EMAIL")
        if not admin_email:
            break
        if email == admin_email.strip().lower():
            return True
        i += 1
    return False


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


@complaints_bp.route("/complaints", methods=["POST"])
def create_complaint():
    """Create a new complaint."""
    try:
        if request.content_type and "multipart/form-data" in request.content_type:
            data = request.form.to_dict()
        else:
            data = request.get_json(silent=True) or {}

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

        return jsonify({
            "success": True,
            "message": "Complaint submitted successfully",
            "_id": str(result.inserted_id),
        }), 201
    except Exception as e:
        print(f"Error creating complaint: {e}")
        return jsonify({"error": "Internal server error", "details": str(e)}), 500


@complaints_bp.route("/complaints", methods=["GET"])
def get_complaints():
    """Return all complaints with optional filters."""
    query = {}
    if request.args.get("student_email"):
        query["student_email"] = request.args["student_email"].strip().lower()
    if request.args.get("status"):
        query["status"] = request.args["status"]
    if request.args.get("category"):
        query["category"] = request.args["category"]
    if request.args.get("building"):
        query["building"] = request.args["building"]

    docs = complaints_collection.find(query).sort("created_at", -1)
    return jsonify([serialize_complaint(d) for d in docs]), 200


@complaints_bp.route("/complaints/<complaint_id>", methods=["GET"])
def get_complaint(complaint_id):
    """Return a single complaint by ID."""
    if not is_valid_object_id(complaint_id):
        return jsonify({"error": "Invalid complaint ID"}), 400

    doc = complaints_collection.find_one({"_id": ObjectId(complaint_id)})
    if not doc:
        return jsonify({"error": "Complaint not found"}), 404

    return jsonify(serialize_complaint(doc)), 200


@complaints_bp.route("/complaints/<complaint_id>/status", methods=["PUT"])
def update_status(complaint_id):
    """Update the status of a complaint."""
    if not is_valid_object_id(complaint_id):
        return jsonify({"error": "Invalid complaint ID"}), 400

    data = request.get_json(silent=True) or {}
    new_status = data.get("status")
    admin_name = data.get("admin_name", "")
    admin_email = data.get("admin_email", "").strip().lower()

    if not _is_admin_email(admin_email):
        return jsonify({"error": "Forbidden"}), 403

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

    complaints_collection.update_one(
        {"_id": ObjectId(complaint_id)},
        {
            "$set": {"status": new_status, "updated_at": now},
            "$push": {"status_history": history_entry},
        },
    )

    # Send student email when admin marks pending acceptance
    if new_status == "Pending Acceptance":
        doc = complaints_collection.find_one({"_id": ObjectId(complaint_id)})
        if doc:
            send_pending_acceptance(serialize_complaint(doc))

    return jsonify({"success": True, "message": f"Status updated to {new_status}"}), 200


@complaints_bp.route("/complaints/<complaint_id>/assign", methods=["POST"])
def assign_complaint(complaint_id):
    """Assign a complaint to an authority and set status to Assigned."""
    if not is_valid_object_id(complaint_id):
        return jsonify({"error": "Invalid complaint ID"}), 400

    data = request.get_json(silent=True) or {}
    authority_id = data.get("authority_id", "")
    admin_name = data.get("admin_name", "Admin")

    if not is_valid_object_id(authority_id):
        return jsonify({"error": "Valid authority_id required"}), 400

    from db import authorities_collection
    authority = authorities_collection.find_one({"_id": ObjectId(authority_id)})
    if not authority:
        return jsonify({"error": "Authority not found"}), 404

    now = datetime.now(timezone.utc)
    assigned_to = {
        "authority_id": str(authority["_id"]),
        "name": authority.get("name", ""),
        "email": authority.get("email", ""),
        "phone": authority.get("phone", ""),
        "category": authority.get("category", ""),
        "assigned_at": now,
        "assigned_by": admin_name,
    }

    result = complaints_collection.update_one(
        {"_id": ObjectId(complaint_id)},
        {
            "$set": {"status": "Assigned", "assigned_to": assigned_to, "updated_at": now},
            "$push": {"status_history": {
                "status": "Assigned",
                "timestamp": now,
                "authority_name": authority.get("name", ""),
                "admin_name": admin_name,
            }},
        },
    )
    if result.matched_count == 0:
        return jsonify({"error": "Complaint not found"}), 404

    # Email student and SMS authority about assignment
    doc = complaints_collection.find_one({"_id": ObjectId(complaint_id)})
    if doc:
        c = serialize_complaint(doc)
        send_authority_assigned(c)
        send_sms_assignment(
            authority_phone=authority.get("phone", ""),
            authority_name=authority.get("name", ""),
            ticket_number=c["ticket_number"],
            category=c["category"],
            location=c["location"],
            assigned_by=admin_name,
        )

    return jsonify({
        "success": True,
        "assigned_to": {
            **{k: v for k, v in assigned_to.items() if k != "assigned_at"},
            "assigned_at": _fmt_ts(now),
        },
    }), 200


@complaints_bp.route("/complaints/<complaint_id>/accept", methods=["POST"])
def accept_complaint(complaint_id):
    """Student accepts the fix and provides feedback."""
    if not is_valid_object_id(complaint_id):
        return jsonify({"error": "Invalid complaint ID"}), 400

    data = request.get_json(silent=True) or {}
    feedback = data.get("feedback", "").strip()
    student_name = data.get("student_name", "Student")
    student_email = data.get("student_email", "").strip().lower()

    if not student_email:
        return jsonify({"error": "student_email is required"}), 400

    doc = complaints_collection.find_one({"_id": ObjectId(complaint_id)})
    if not doc:
        return jsonify({"error": "Complaint not found"}), 404

    if doc.get("student_email", "").lower() != student_email:
        return jsonify({"error": "Forbidden"}), 403

    if doc.get("status") != "Pending Acceptance":
        return jsonify({"error": "Complaint is not awaiting acceptance"}), 409

    now = datetime.now(timezone.utc)
    result = complaints_collection.update_one(
        {"_id": ObjectId(complaint_id)},
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
        return jsonify({"error": "Complaint not found"}), 404

    doc = complaints_collection.find_one({"_id": ObjectId(complaint_id)})
    if doc:
        send_fix_accepted_to_admins(serialize_complaint(doc), feedback, student_name)

    return jsonify({"success": True, "message": "Fix accepted. Complaint closed."}), 200


@complaints_bp.route("/complaints/<complaint_id>/reopen", methods=["POST"])
def reopen_complaint(complaint_id):
    """Student reopens the complaint with a reason."""
    if not is_valid_object_id(complaint_id):
        return jsonify({"error": "Invalid complaint ID"}), 400

    data = request.get_json(silent=True) or {}
    reason = data.get("reason", "").strip()
    student_name = data.get("student_name", "Student")
    student_email = data.get("student_email", "").strip().lower()

    if not student_email:
        return jsonify({"error": "student_email is required"}), 400

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
    result = complaints_collection.update_one(
        {"_id": ObjectId(complaint_id)},
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
        return jsonify({"error": "Complaint not found"}), 404

    doc = complaints_collection.find_one({"_id": ObjectId(complaint_id)})
    if doc:
        send_reopened_to_admins(serialize_complaint(doc), reason, student_name)

    return jsonify({"success": True, "message": "Complaint reopened."}), 200


@complaints_bp.route("/complaints/recurring", methods=["GET"])
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
