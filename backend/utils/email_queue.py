"""
Async email + SMS notifications via a daemon worker thread.

Usage:
    from utils.email_queue import (
        send_complaint_raised_to_student,
        send_complaint_raised_to_admins,
        send_authority_assigned,
        send_pending_acceptance,
        send_fix_accepted_to_admins,
        send_reopened_to_admins,
        send_sms_assignment,
    )
"""
import os
import queue
import smtplib
import threading
import requests as http_requests
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

# ── Textbee config ────────────────────────────────────────────────────────────
_TEXTBEE_API_KEY  = os.getenv("TEXTBEE_API_KEY", "")
_TEXTBEE_DEVICE_ID = os.getenv("TEXTBEE_DEVICE_ID", "")

# ── SMTP config (same env vars as auth.py) ────────────────────────────────────
_HOST = os.getenv("OUTLOOK_HOST", "smtp.office365.com")
_PORT = int(os.getenv("OUTLOOK_PORT", 587))
_USER = os.getenv("OUTLOOK_EMAIL", "")
_PASS = os.getenv("OUTLOOK_PASSWORD", "")


def _load_admin_emails() -> list[str]:
    emails, i = [], 1
    while True:
        e = os.getenv(f"ADMIN_{i}_EMAIL")
        if not e:
            break
        emails.append(e.strip().lower())
        i += 1
    return emails


# ── Queue + worker ────────────────────────────────────────────────────────────
_q: queue.Queue = queue.Queue()


def _worker() -> None:
    while True:
        task = _q.get()
        if task is None:
            break
        try:
            if task.get("_sms"):
                _send_sms(task["phone"], task["message"])
            else:
                _send_email(task["to"], task["subject"], task["html"])
        except Exception as exc:
            print(f"[Notification] Failed: {exc}")
        finally:
            _q.task_done()


_thread: threading.Thread | None = None


def _ensure_worker_started() -> None:
    global _thread
    if _thread is None or not _thread.is_alive():
        _thread = threading.Thread(target=_worker, daemon=True, name="email-worker")
        _thread.start()


def enqueue_email(to: str, subject: str, html: str) -> None:
    """Non-blocking — push email job onto the queue."""
    _ensure_worker_started()
    user = os.getenv("OUTLOOK_EMAIL", "")
    password = os.getenv("OUTLOOK_PASSWORD", "")
    if not user or not password:
        print("[EmailQueue] SMTP not configured — skipping email.")
        return
    _q.put({"to": to, "subject": subject, "html": html})


# ── Low-level send ────────────────────────────────────────────────────────────
def _send_email(to: str, subject: str, html: str) -> None:
    host = os.getenv("OUTLOOK_HOST", "smtp.office365.com")
    port = int(os.getenv("OUTLOOK_PORT", 587))
    user = os.getenv("OUTLOOK_EMAIL", "")
    password = os.getenv("OUTLOOK_PASSWORD", "")
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = user
    msg["To"] = to
    msg.attach(MIMEText(html, "html"))
    with smtplib.SMTP(host, port) as server:
        server.ehlo()
        server.starttls()
        server.login(user, password)
        server.sendmail(user, to, msg.as_string())


# ── SMS ──────────────────────────────────────────────────────────────────────
def _clean_phone(phone: str) -> str:
    """Strip formatting and country code, return 10-digit Indian mobile number."""
    digits = "".join(c for c in phone if c.isdigit())
    # Remove leading 91 (country code) if present and number is 12 digits
    if len(digits) == 12 and digits.startswith("91"):
        digits = digits[2:]
    return digits[-10:] if len(digits) >= 10 else ""


def _send_sms(phone: str, message: str) -> None:
    """Send SMS via Textbee API (uses your Android phone as the gateway)."""
    if not _TEXTBEE_API_KEY or not _TEXTBEE_DEVICE_ID:
        print("[SMS] TEXTBEE_API_KEY or TEXTBEE_DEVICE_ID not set — skipping SMS.")
        return
    number = _clean_phone(phone)
    if not number or len(number) != 10:
        print(f"[SMS] Invalid phone number '{phone}' — skipping.")
        return
    try:
        resp = http_requests.post(
            f"https://api.textbee.dev/api/v1/gateway/devices/{_TEXTBEE_DEVICE_ID}/send-sms",
            headers={"x-api-key": _TEXTBEE_API_KEY, "Content-Type": "application/json"},
            json={"recipients": [f"+91{number}"], "message": message},
            timeout=15,
        )
        data = resp.json()
        if resp.status_code == 200 or data.get("success"):
            print(f"[SMS] Sent to +91{number} via Textbee.")
        else:
            print(f"[SMS] Textbee failed for +91{number}: {data}")
    except Exception as exc:
        print(f"[SMS] Error sending to +91{number}: {exc}")


def send_sms_assignment(
    authority_phone: str,
    authority_name: str,
    ticket_number: str,
    category: str,
    location: dict,
    assigned_by: str,
) -> None:
    """Queue an SMS to the authority when they are assigned a complaint."""
    if not authority_phone:
        return
    _ensure_worker_started()
    location_str = f"{location.get('building', '')}, Room {location.get('room', '')}"
    message = (
        f"CampusFix Alert: Hi {authority_name}, you have been assigned a new task.\n"
        f"Ticket: {ticket_number} | {category} at {location_str}.\n"
        f"Assigned by Admin - {assigned_by}. Please resolve at the earliest."
    )
    # Push onto the same worker queue so it doesn't block the request
    _q.put({"_sms": True, "phone": authority_phone, "message": message})


# ── HTML template ─────────────────────────────────────────────────────────────
def _html(heading: str, rows: list[str], highlight: str = "", footer_note: str = "") -> str:
    rows_html = "".join(
        f'<p style="color:#64748b;font-size:14px;margin:0 0 10px;">{r}</p>' for r in rows
    )
    highlight_html = f"""
        <div style="background:#eff6ff;border:2px dashed #3b82f6;border-radius:12px;
                    padding:18px 24px;text-align:center;margin:20px 0;">
          <span style="font-size:18px;font-weight:800;letter-spacing:2px;color:#1e3a8a;">{highlight}</span>
        </div>
    """ if highlight else ""
    footer_html = f'<p style="color:#94a3b8;font-size:12px;text-align:center;margin:16px 0 0;">{footer_note}</p>' if footer_note else ""
    return f"""
    <html><body style="margin:0;padding:0;background:#f1f5f9;font-family:Arial,sans-serif;">
      <table width="100%" cellpadding="0" cellspacing="0">
        <tr><td align="center" style="padding:40px 20px;">
          <table width="480" cellpadding="0" cellspacing="0"
                 style="background:#ffffff;border-radius:16px;overflow:hidden;
                        box-shadow:0 4px 24px rgba(30,58,138,.10);">
            <tr>
              <td style="background:linear-gradient(135deg,#1e3a8a,#3b82f6);padding:28px 32px;">
                <h1 style="margin:0;color:#ffffff;font-size:20px;font-weight:700;">🎓 UEM CampusFix</h1>
                <p style="margin:4px 0 0;color:rgba(255,255,255,.7);font-size:12px;">Smart Campus Complaint System</p>
              </td>
            </tr>
            <tr>
              <td style="padding:32px;">
                <h2 style="color:#1e3a8a;font-size:16px;margin:0 0 16px;">{heading}</h2>
                {rows_html}
                {highlight_html}
                {footer_html}
              </td>
            </tr>
            <tr>
              <td style="background:#f8fafc;padding:14px 32px;text-align:center;border-top:1px solid #e2e8f0;">
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


# ── Per-event helpers ─────────────────────────────────────────────────────────

def send_complaint_raised_to_student(c: dict) -> None:
    """Email the student confirming their complaint was registered."""
    to = c.get("student_email", "")
    if not to:
        return
    enqueue_email(
        to=to,
        subject=f"CampusFix — Complaint Registered ({c['ticket_number']})",
        html=_html(
            "Your complaint has been registered ✅",
            [
                f"Hi {to.split('@')[0].title()},",
                f"Your complaint about <strong>{c['category']}</strong> at "
                f"{c['location']['building']}, Room {c['location']['room']} has been successfully submitted.",
                "Our admin team will review it and assign the concerned department shortly.",
            ],
            highlight=c["ticket_number"],
            footer_note="Keep this ticket number for future reference.",
        ),
    )


def send_complaint_raised_to_admins(c: dict) -> None:
    """Alert all admins about a new complaint."""
    for email in _load_admin_emails():
        enqueue_email(
            to=email,
            subject=f"CampusFix — New Complaint ({c['ticket_number']})",
            html=_html(
                "🔔 A new complaint has been raised",
                [
                    f"<strong>Ticket:</strong> {c['ticket_number']}",
                    f"<strong>Category:</strong> {c['category']}",
                    f"<strong>Location:</strong> {c['location']['building']}, Room {c['location']['room']}",
                    f"<strong>Raised by:</strong> {c.get('student_email', 'unknown')}",
                    f"<strong>Description:</strong> {c.get('description', '')}",
                ],
                footer_note="Log in to the Admin Dashboard to assign an authority.",
            ),
        )


def send_authority_assigned(c: dict) -> None:
    """Notify the student that an authority has been assigned."""
    to = c.get("student_email", "")
    if not to:
        return
    assigned = c.get("assignedTo") or {}
    authority_name = assigned.get("name", "the concerned department")
    enqueue_email(
        to=to,
        subject=f"CampusFix — Authority Assigned ({c['ticket_number']})",
        html=_html(
            "An authority has been assigned to your complaint 👷",
            [
                f"Your complaint <strong>{c['ticket_number']}</strong> has been assigned to "
                f"<strong>{authority_name}</strong>.",
                "They will look into your reported issue and work on resolving it.",
            ],
            highlight=c["ticket_number"],
            footer_note="You will be notified once the issue is resolved.",
        ),
    )


def send_pending_acceptance(c: dict) -> None:
    """Ask the student to accept the fix or reopen the complaint."""
    to = c.get("student_email", "")
    if not to:
        return
    enqueue_email(
        to=to,
        subject=f"CampusFix — Fix Ready, Action Required ({c['ticket_number']})",
        html=_html(
            "Your issue has been marked as resolved — please verify 🔍",
            [
                f"Hi {to.split('@')[0].title()},",
                f"The admin has marked your complaint <strong>{c['ticket_number']}</strong> "
                f"({c['category']} at {c['location']['building']}, Room {c['location']['room']}) as resolved.",
                "Please log in to CampusFix, review the fix, and either:",
                "✅ <strong>Accept the fix</strong> and leave feedback, <em>or</em>",
                "🔁 <strong>Reopen the complaint</strong> if the issue persists (a reason will be required).",
            ],
            highlight=c["ticket_number"],
            footer_note="Your response helps us improve campus infrastructure.",
        ),
    )


def send_fix_accepted_to_admins(c: dict, feedback: str, student_name: str) -> None:
    """Notify admins that the student accepted the fix."""
    for email in _load_admin_emails():
        enqueue_email(
            to=email,
            subject=f"CampusFix — Fix Accepted ({c['ticket_number']})",
            html=_html(
                "✅ Student accepted the fix",
                [
                    f"<strong>Ticket:</strong> {c['ticket_number']}",
                    f"<strong>Accepted by:</strong> {student_name}",
                    f"<strong>Student feedback:</strong> {feedback or 'No feedback provided.'}",
                ],
                footer_note="This complaint is now fully closed.",
            ),
        )


def send_reopened_to_admins(c: dict, reason: str, student_name: str) -> None:
    """Alert admins that the student reopened the complaint."""
    for email in _load_admin_emails():
        enqueue_email(
            to=email,
            subject=f"CampusFix — Complaint Reopened ({c['ticket_number']})",
            html=_html(
                "🔁 A complaint has been reopened",
                [
                    f"<strong>Ticket:</strong> {c['ticket_number']}",
                    f"<strong>Category:</strong> {c['category']}",
                    f"<strong>Reopened by:</strong> {student_name}",
                    f"<strong>Reason:</strong> {reason}",
                ],
                footer_note="Please log in to the Admin Dashboard to re-assign and resolve.",
            ),
        )
