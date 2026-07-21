import os
import random
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timezone, timedelta
from flask import Blueprint, request, jsonify
from werkzeug.security import generate_password_hash, check_password_hash

from db import db, otps_collection
from extensions import limiter
from flask_limiter.util import get_remote_address
from utils.auth import generate_token

auth_bp = Blueprint("auth", __name__)

# ── SMTP config from .env ────────────────────────────────────────────────────
SMTP_HOST = os.getenv("OUTLOOK_HOST", "smtp.office365.com")
SMTP_PORT = int(os.getenv("OUTLOOK_PORT", 587))
SMTP_USER = os.getenv("OUTLOOK_EMAIL", "")
SMTP_PASS = os.getenv("OUTLOOK_PASSWORD", "")

# ── Admin accounts from .env (ADMIN_1_, ADMIN_2_, …) ─────────────────────────
def _load_admins() -> list[dict]:
    admins, i = [], 1
    while True:
        email = os.getenv(f"ADMIN_{i}_EMAIL")
        if not email:
            break
        admins.append({
            "email":         email.strip().lower(),
            "password_hash": generate_password_hash(os.getenv(f"ADMIN_{i}_PASSWORD", "")),
            "name":          os.getenv(f"ADMIN_{i}_NAME", "Admin"),
        })
        i += 1
    return admins

ADMINS = _load_admins()

# ── Collections ──────────────────────────────────────────────────────────────
students_collection = db["students"]

# Wrong-OTP attempts allowed before the code is invalidated (anti-brute-force).
MAX_OTP_ATTEMPTS = 5

# Minimum wait between OTP (re)sends for the same email, in seconds.
OTP_RESEND_COOLDOWN_SECONDS = 30


def _is_allowed_student_email(email: str) -> bool:
    """Allow only official student domains."""
    normalized = email.strip().lower()
    return normalized.endswith("@uem.edu.in") or normalized.endswith("@iem.edu.in")


def _otp_email_key() -> str:
    """Bucket OTP rate limits per email so students on a shared campus IP don't
    consume each other's budget. Falls back to IP when no email is supplied."""
    data = request.get_json(silent=True) or {}
    return (data.get("email") or "").strip().lower() or get_remote_address()


def _send_otp_email(to_email: str, otp: str, account_label: str = "student account") -> None:
    smtp_host = os.getenv("OUTLOOK_HOST", "smtp.office365.com")
    smtp_port = int(os.getenv("OUTLOOK_PORT", 587))
    smtp_user = os.getenv("OUTLOOK_EMAIL", "")
    smtp_pass = os.getenv("OUTLOOK_PASSWORD", "")

    if not smtp_user or not smtp_pass:
        raise ValueError("OUTLOOK_EMAIL or OUTLOOK_PASSWORD is missing in backend .env file")

    msg = MIMEMultipart("alternative")
    msg["Subject"] = "CampusFix – Your OTP Verification Code"
    msg["From"]    = smtp_user
    msg["To"]      = to_email

    html = f"""
    <html><body style="margin:0;padding:0;background:#f1f5f9;font-family:Arial,sans-serif;">
      <table width="100%" cellpadding="0" cellspacing="0">
        <tr><td align="center" style="padding:40px 20px;">
          <table width="480" cellpadding="0" cellspacing="0"
                 style="background:#ffffff;border-radius:16px;overflow:hidden;
                        box-shadow:0 4px 24px rgba(30,58,138,.10);">
            <!-- Header -->
            <tr>
              <td style="background:linear-gradient(135deg,#1e3a8a,#3b82f6);
                         padding:32px;text-align:center;">
                <h1 style="margin:0;color:#ffffff;font-size:22px;font-weight:700;">
                  🎓 UEM CampusFix
                </h1>
                <p style="margin:6px 0 0;color:rgba(255,255,255,.75);font-size:13px;">
                  UEM Complaint Management System
                </p>
              </td>
            </tr>
            <!-- Body -->
            <tr>
              <td style="padding:36px 32px;">
                <p style="color:#334155;font-size:15px;margin:0 0 8px;">Hi there 👋</p>
                <p style="color:#64748b;font-size:14px;margin:0 0 28px;">
                  Use the OTP below to sign in to your {account_label}.
                  It is valid for <strong>10 minutes</strong>.
                </p>
                <!-- OTP Box -->
                <div style="background:#eff6ff;border:2px dashed #3b82f6;border-radius:12px;
                            padding:24px;text-align:center;margin-bottom:28px;">
                  <span style="font-size:40px;font-weight:800;letter-spacing:12px;color:#1e3a8a;">
                    {otp}
                  </span>
                </div>
                <p style="color:#94a3b8;font-size:12px;text-align:center;margin:0;">
                  Do not share this code with anyone.&nbsp; If you didn't request this, ignore this email.
                </p>
              </td>
            </tr>
            <!-- Footer -->
            <tr>
              <td style="background:#f8fafc;padding:16px 32px;text-align:center;
                         border-top:1px solid #e2e8f0;">
                <p style="margin:0;color:#94a3b8;font-size:11px;">
                  © 2026 UEM CampusFix · University of Engineering &amp; Management
                </p>
              </td>
            </tr>
          </table>
        </td></tr>
      </table>
    </body></html>
    """
    msg.attach(MIMEText(html, "html"))

    with smtplib.SMTP(smtp_host, smtp_port) as server:
        server.ehlo()
        server.starttls()
        server.login(smtp_user, smtp_pass)
        server.sendmail(smtp_user, to_email, msg.as_string())


# ── Shared OTP mechanics (used by both student and authority flows) ──────────

def _enforce_otp_cooldown(email: str):
    """Return a 429 (json, status) response if `email` is still cooling down, else None.

    Enforced server-side so it survives restarts and multiple workers.
    """
    existing = otps_collection.find_one({"email": email})
    if existing and existing.get("sent_at"):
        sent_at = existing["sent_at"]
        if sent_at.tzinfo is None:
            sent_at = sent_at.replace(tzinfo=timezone.utc)
        elapsed = (datetime.now(timezone.utc) - sent_at).total_seconds()
        if elapsed < OTP_RESEND_COOLDOWN_SECONDS:
            retry_after = max(1, int(round(OTP_RESEND_COOLDOWN_SECONDS - elapsed)))
            return jsonify({
                "error": f"Please wait {retry_after}s before requesting another OTP.",
                "retry_after": retry_after,
            }), 429
    return None


def _store_and_send_otp(email: str, account_label: str):
    """Generate, hash-store, and email a fresh OTP. Resets the attempt counter.

    Returns None on success, or a 500 (json, status) tuple if the mail fails.
    """
    now        = datetime.now(timezone.utc)
    otp        = str(random.randint(100000, 999999))
    expires_at = now + timedelta(minutes=10)
    otps_collection.update_one(
        {"email": email},
        {"$set": {
            "email":      email,
            "otp_hash":   generate_password_hash(otp),
            "expires_at": expires_at,
            "sent_at":    now,
            "attempts":   0,
        }},
        upsert=True,
    )
    try:
        _send_otp_email(email, otp, account_label)
        print(f"[OTP] Email sent successfully to {email}")
    except Exception as exc:
        print(f"[OTP] Failed to send email via SMTP ({exc})")
        print(f"[OTP DEV FALLBACK] Code for {email} is: {otp}")
        return jsonify({"error": "Failed to send OTP. Please try again later."}), 500
    return None


def _consume_otp(email: str, otp: str):
    """Validate a submitted OTP against the stored hash.

    Returns None on success (the OTP record is deleted), or an (json, status)
    error tuple. Uses a constant-time hash compare and bounds brute-force via the
    per-record attempt counter.
    """
    rec = otps_collection.find_one({"email": email})
    if not rec:
        return jsonify({"error": "No OTP found. Please request a new one."}), 400

    # PyMongo returns naive datetimes (stored as UTC) — make the comparison explicit.
    expires_at = rec.get("expires_at")
    if expires_at is not None and expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if not expires_at or datetime.now(timezone.utc) > expires_at:
        otps_collection.delete_one({"email": email})
        return jsonify({"error": "OTP expired. Please request a new one."}), 400

    if rec.get("attempts", 0) >= MAX_OTP_ATTEMPTS:
        otps_collection.delete_one({"email": email})
        return jsonify({"error": "Too many incorrect attempts. Please request a new OTP."}), 429

    if not check_password_hash(rec.get("otp_hash", ""), otp):
        otps_collection.update_one({"email": email}, {"$inc": {"attempts": 1}})
        return jsonify({"error": "Invalid OTP. Please try again."}), 400

    otps_collection.delete_one({"email": email})
    return None


def _find_authority(email: str):
    """Look up a registered authority by email (login gate for the authority flow)."""
    from db import authorities_collection
    return authorities_collection.find_one({"email": email})


# ── Routes ───────────────────────────────────────────────────────────────────

@auth_bp.route("/auth/send-otp", methods=["POST"])
@limiter.limit("5 per 10 minutes", key_func=_otp_email_key)  # per email (primary)
@limiter.limit("40 per 10 minutes")                          # per IP (abuse backstop)
def send_otp():
    """Send a 6-digit OTP to the student's email."""
    data  = request.get_json(silent=True) or {}
    email = data.get("email", "").strip().lower()

    if not email:
        return jsonify({"error": "Email is required"}), 400

    if not _is_allowed_student_email(email):
        return jsonify({"error": "Only @uem.edu.in and @iem.edu.in email addresses are allowed"}), 403

    cooldown = _enforce_otp_cooldown(email)
    if cooldown:
        return cooldown

    failure = _store_and_send_otp(email, "student account")
    if failure:
        return failure

    return jsonify({
        "success": True,
        "message": f"OTP sent to {email}",
        "resend_after": OTP_RESEND_COOLDOWN_SECONDS,
    }), 200


@auth_bp.route("/auth/verify-otp", methods=["POST"])
@limiter.limit("10 per 10 minutes", key_func=_otp_email_key)  # per email (primary)
@limiter.limit("60 per 10 minutes")                           # per IP (abuse backstop)
def verify_otp():
    """Verify the OTP and log the student in (upsert record)."""
    data  = request.get_json(silent=True) or {}
    email = data.get("email", "").strip().lower()
    otp   = data.get("otp",   "").strip()

    if not email or not otp:
        return jsonify({"error": "Email and OTP are required"}), 400

    # Belt-and-braces: a token must never be mintable for a non-campus address,
    # even though an OTP can only exist for one (send-otp already gates the domain).
    if not _is_allowed_student_email(email):
        return jsonify({"error": "Only @uem.edu.in and @iem.edu.in email addresses are allowed"}), 403

    error = _consume_otp(email, otp)
    if error:
        return error

    # Upsert student in DB
    students_collection.update_one(
        {"email": email},
        {"$set": {"email": email, "last_login": datetime.now(timezone.utc)},
         "$setOnInsert": {"created_at": datetime.now(timezone.utc)}},
        upsert=True,
    )

    name = email.split("@")[0].replace(".", " ").title()
    user = {"email": email, "role": "student", "name": name}
    return jsonify({
        "success": True,
        "message": "Login successful",
        "user": user,
        "token": generate_token(user),
    }), 200


@auth_bp.route("/auth/student-register", methods=["POST"])
@limiter.limit("10 per hour")
def student_register():
    """Register a new student with email/password."""
    data     = request.get_json(silent=True) or {}
    name     = data.get("name", "").strip()
    email    = data.get("email", "").strip().lower()
    password = data.get("password", "")

    if not name or not email or not password:
        return jsonify({"error": "Name, email, and password are required"}), 400

    if not _is_allowed_student_email(email):
        return jsonify({"error": "Only @uem.edu.in and @iem.edu.in email addresses are allowed"}), 403

    if len(password) < 6:
        return jsonify({"error": "Password must be at least 6 characters"}), 400

    # Check if already exists
    existing = students_collection.find_one({"email": email})
    if existing and existing.get("password_hash"):
        return jsonify({"error": "An account with this email already exists"}), 409

    # Hash password and upsert
    password_hash = generate_password_hash(password)
    students_collection.update_one(
        {"email": email},
        {
            "$set": {
                "email":         email,
                "name":          name,
                "password_hash": password_hash,
                "provider":      "email",
            },
            "$setOnInsert": {"created_at": datetime.now(timezone.utc)},
        },
        upsert=True,
    )

    return jsonify({"success": True, "message": "Registration successful"}), 201


@auth_bp.route("/auth/student-login", methods=["POST"])
@limiter.limit("10 per minute")
def student_login():
    """Login student with email/password."""
    data     = request.get_json(silent=True) or {}
    email    = data.get("email", "").strip().lower()
    password = data.get("password", "")

    if not email or not password:
        return jsonify({"error": "Email and password are required"}), 400

    if not _is_allowed_student_email(email):
        return jsonify({"error": "Only @uem.edu.in and @iem.edu.in email addresses are allowed"}), 403

    student = students_collection.find_one({"email": email})
    if not student or not student.get("password_hash"):
        return jsonify({"error": "Account not found. Please register first."}), 404

    if not check_password_hash(student["password_hash"], password):
        return jsonify({"error": "Invalid password"}), 401

    # Update last login
    students_collection.update_one(
        {"email": email},
        {"$set": {"last_login": datetime.now(timezone.utc)}},
    )

    user = {
        "email": email,
        "role": "student",
        "name": student.get("name", email.split("@")[0].title()),
    }
    return jsonify({
        "success": True,
        "message": "Login successful",
        "user": user,
        "token": generate_token(user),
    }), 200



@auth_bp.route("/auth/admin-login", methods=["POST"])
@limiter.limit("10 per minute")
def admin_login():
    """Validate admin credentials against all accounts defined in .env."""
    data     = request.get_json(silent=True) or {}
    email    = data.get("email",    "").strip().lower()
    password = data.get("password", "")

    for admin in ADMINS:
        if email == admin["email"] and check_password_hash(admin["password_hash"], password):
            user = {"email": email, "role": "admin", "name": admin["name"]}
            return jsonify({
                "success": True,
                "message": "Login successful",
                "user": user,
                "token": generate_token(user),
            }), 200

    return jsonify({"error": "Invalid admin credentials"}), 401


# ── Authority OTP login ───────────────────────────────────────────────────────
# Authorities log in exactly like students (email OTP), but the gate is
# "email exists in the authorities directory" rather than a campus email domain.

@auth_bp.route("/auth/authority/send-otp", methods=["POST"])
@limiter.limit("5 per 10 minutes", key_func=_otp_email_key)  # per email (primary)
@limiter.limit("40 per 10 minutes")                          # per IP (abuse backstop)
def authority_send_otp():
    """Send a 6-digit OTP to a registered authority's email."""
    data  = request.get_json(silent=True) or {}
    email = data.get("email", "").strip().lower()

    if not email:
        return jsonify({"error": "Email is required"}), 400

    if not _find_authority(email):
        return jsonify({"error": "This email is not registered as an authority. Please contact the admin."}), 403

    cooldown = _enforce_otp_cooldown(email)
    if cooldown:
        return cooldown

    failure = _store_and_send_otp(email, "authority account")
    if failure:
        return failure

    return jsonify({
        "success": True,
        "message": f"OTP sent to {email}",
        "resend_after": OTP_RESEND_COOLDOWN_SECONDS,
    }), 200


@auth_bp.route("/auth/authority/verify-otp", methods=["POST"])
@limiter.limit("10 per 10 minutes", key_func=_otp_email_key)  # per email (primary)
@limiter.limit("60 per 10 minutes")                           # per IP (abuse backstop)
def authority_verify_otp():
    """Verify the OTP and log an authority in, issuing an authority-scoped token."""
    data  = request.get_json(silent=True) or {}
    email = data.get("email", "").strip().lower()
    otp   = data.get("otp",   "").strip()

    if not email or not otp:
        return jsonify({"error": "Email and OTP are required"}), 400

    # Re-check membership here too: a token must never be mintable for an email
    # that isn't a current authority, even though send-otp already gates it.
    authority = _find_authority(email)
    if not authority:
        return jsonify({"error": "This email is not registered as an authority. Please contact the admin."}), 403

    error = _consume_otp(email, otp)
    if error:
        return error

    user = {
        "email":        email,
        "role":         "authority",
        "name":         authority.get("name", email.split("@")[0].title()),
        "authority_id": str(authority["_id"]),
        "category":     authority.get("category", ""),
    }
    return jsonify({
        "success": True,
        "message": "Login successful",
        "user": user,
        "token": generate_token(user),
    }), 200
