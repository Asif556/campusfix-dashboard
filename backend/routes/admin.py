from flask import Blueprint, jsonify, request
from bson import ObjectId
from datetime import datetime, timezone
from pymongo.errors import DuplicateKeyError

from utils.auth import require_admin
from utils.helpers import is_valid_object_id

admin_bp = Blueprint("admin", __name__)


@admin_bp.route("/admin/complaints", methods=["GET"])
@require_admin
def admin_complaints():
    """Return all complaints for the admin dashboard."""
    from db import complaints_collection
    from utils.helpers import serialize_complaint

    docs = complaints_collection.find().sort("created_at", -1)
    return jsonify([serialize_complaint(d) for d in docs]), 200


# ── Notification-email recipients ─────────────────────────────────────────────
# These addresses are alerted ONLY when an authority rejects an assignment. They
# are separate from the ADMIN_* login accounts in .env (which keep receiving the
# complaint-raised / fix-accepted / reopened mails).

@admin_bp.route("/admin/notification-emails", methods=["GET"])
@require_admin
def get_notification_emails():
    from db import notification_emails_collection
    docs = list(notification_emails_collection.find().sort("created_at", 1))
    return jsonify([{"_id": str(d["_id"]), "email": d.get("email", "")} for d in docs]), 200


@admin_bp.route("/admin/notification-emails", methods=["POST"])
@require_admin
def add_notification_email():
    from db import notification_emails_collection
    data = request.get_json(silent=True) or {}
    email = (data.get("email") or "").strip().lower()
    if not email or "@" not in email or "." not in email.rsplit("@", 1)[-1]:
        return jsonify({"error": "A valid email is required"}), 400

    if notification_emails_collection.find_one({"email": email}):
        return jsonify({"error": "This email is already on the notification list"}), 409
    try:
        result = notification_emails_collection.insert_one(
            {"email": email, "created_at": datetime.now(timezone.utc)}
        )
    except DuplicateKeyError:
        return jsonify({"error": "This email is already on the notification list"}), 409
    return jsonify({"success": True, "_id": str(result.inserted_id), "email": email}), 201


@admin_bp.route("/admin/notification-emails/<email_id>", methods=["DELETE"])
@require_admin
def delete_notification_email(email_id):
    from db import notification_emails_collection
    if not is_valid_object_id(email_id):
        return jsonify({"error": "Invalid ID"}), 400
    result = notification_emails_collection.delete_one({"_id": ObjectId(email_id)})
    if result.deleted_count == 0:
        return jsonify({"error": "Notification email not found"}), 404
    return jsonify({"success": True}), 200
