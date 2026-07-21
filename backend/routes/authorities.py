from flask import Blueprint, request, jsonify
from bson import ObjectId
from datetime import datetime, timezone
from pymongo.errors import DuplicateKeyError

from db import authorities_collection, category_settings_collection
from utils.auth import require_admin
from utils.assignment import effective_order
from utils.helpers import is_valid_object_id

authorities_bp = Blueprint("authorities", __name__)


def _serialize_authority(doc):
    return {
        "_id": str(doc["_id"]),
        "name": doc.get("name", ""),
        "email": doc.get("email", ""),
        "phone": doc.get("phone", ""),
        "category": doc.get("category", ""),
    }


def _serialize_category_settings(doc):
    return {
        "category": doc.get("category", ""),
        "auto_assign": bool(doc.get("auto_assign", False)),
        "priority_order": [str(x) for x in doc.get("priority_order", [])],
    }


@authorities_bp.route("/authorities", methods=["GET"])
@require_admin
def get_authorities():
    category = request.args.get("category")
    # For a single category, return authorities in effective priority order (top of
    # the auto-assign / cascade list first); otherwise a flat, name-sorted directory.
    if category:
        docs = effective_order(category)
    else:
        docs = list(authorities_collection.find().sort("name", 1))
    return jsonify([_serialize_authority(d) for d in docs]), 200


@authorities_bp.route("/authorities", methods=["POST"])
@require_admin
def add_authority():
    data = request.get_json(silent=True) or {}
    required = ["name", "email", "category"]
    missing = [f for f in required if not data.get(f)]
    if missing:
        return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400

    email = data["email"].strip().lower()
    # Authority email is the login identity + assignment key — must be unique.
    if authorities_collection.find_one({"email": email}):
        return jsonify({"error": "An authority with this email already exists"}), 409

    doc = {
        "name": data["name"].strip(),
        "email": email,
        "phone": data.get("phone", "").strip(),
        "category": data["category"].strip(),
        "created_at": datetime.now(timezone.utc),
    }
    try:
        result = authorities_collection.insert_one(doc)
    except DuplicateKeyError:
        return jsonify({"error": "An authority with this email already exists"}), 409
    return jsonify({"success": True, "_id": str(result.inserted_id)}), 201


@authorities_bp.route("/authorities/<authority_id>", methods=["PUT"])
@require_admin
def update_authority(authority_id):
    if not is_valid_object_id(authority_id):
        return jsonify({"error": "Invalid ID"}), 400

    data = request.get_json(silent=True) or {}
    required = ["name", "email", "category"]
    missing = [f for f in required if not data.get(f)]
    if missing:
        return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400

    email = data["email"].strip().lower()
    # Reject a collision with a *different* authority's email.
    clash = authorities_collection.find_one({"email": email, "_id": {"$ne": ObjectId(authority_id)}})
    if clash:
        return jsonify({"error": "Another authority already uses this email"}), 409

    try:
        result = authorities_collection.update_one(
            {"_id": ObjectId(authority_id)},
            {"$set": {
                "name": data["name"].strip(),
                "email": email,
                "phone": data.get("phone", "").strip(),
                "category": data["category"].strip(),
            }},
        )
    except DuplicateKeyError:
        return jsonify({"error": "Another authority already uses this email"}), 409
    if result.matched_count == 0:
        return jsonify({"error": "Authority not found"}), 404
    return jsonify({"success": True}), 200


@authorities_bp.route("/authorities/<authority_id>", methods=["DELETE"])
@require_admin
def delete_authority(authority_id):
    if not is_valid_object_id(authority_id):
        return jsonify({"error": "Invalid ID"}), 400
    result = authorities_collection.delete_one({"_id": ObjectId(authority_id)})
    if result.deleted_count == 0:
        return jsonify({"error": "Authority not found"}), 404
    # No need to prune this id from any category_settings.priority_order —
    # effective_order() skips ids that no longer resolve to an authority.
    return jsonify({"success": True}), 200


# ── Per-category auto-assign + priority order ─────────────────────────────────

@authorities_bp.route("/category-settings", methods=["GET"])
@require_admin
def get_category_settings():
    """Return every stored per-category settings doc (auto_assign + priority_order).

    Categories without a doc simply won't appear; the frontend defaults them to
    auto_assign off / empty order.
    """
    docs = list(category_settings_collection.find())
    return jsonify([_serialize_category_settings(d) for d in docs]), 200


@authorities_bp.route("/category-settings", methods=["PUT"])
@require_admin
def update_category_settings():
    """Upsert one category's settings. Merges: only fields present in the body change,
    so a toggle-only request won't clobber the priority order and vice-versa."""
    data = request.get_json(silent=True) or {}
    category = (data.get("category") or "").strip()
    if not category:
        return jsonify({"error": "category is required"}), 400

    update = {"category": category, "updated_at": datetime.now(timezone.utc)}
    if "auto_assign" in data:
        update["auto_assign"] = bool(data["auto_assign"])
    if "priority_order" in data:
        if not isinstance(data["priority_order"], list):
            return jsonify({"error": "priority_order must be a list of authority ids"}), 400
        update["priority_order"] = [str(x) for x in data["priority_order"] if x]

    category_settings_collection.update_one(
        {"category": category}, {"$set": update}, upsert=True,
    )
    doc = category_settings_collection.find_one({"category": category})
    return jsonify({"success": True, "settings": _serialize_category_settings(doc)}), 200
