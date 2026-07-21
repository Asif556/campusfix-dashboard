import certifi
from pymongo import MongoClient
from config import MONGO_URI, DB_NAME

client = MongoClient(MONGO_URI, tls=True, tlsCAFile=certifi.where())
db = client[DB_NAME]

complaints_collection = db["complaints"]
admins_collection = db["admins"]
authorities_collection = db["authorities"]
otps_collection = db["otps"]
# Per-category auto-assign toggle + priority-ordered authority list.
category_settings_collection = db["category_settings"]
# Recipients alerted only when an authority rejects an assignment.
notification_emails_collection = db["notification_emails"]

# Indexes for the most common query patterns. create_index is idempotent, so
# this is safe to run on every startup; failures shouldn't block the app.
try:
    complaints_collection.create_index("student_email")
    complaints_collection.create_index("status")
    complaints_collection.create_index([("created_at", -1)])
    # Authority work-queue lookups scope by the current assignee.
    complaints_collection.create_index("assigned_to.authority_id")
    # One live OTP per email; TTL index lets MongoDB auto-purge expired codes.
    otps_collection.create_index("email", unique=True)
    otps_collection.create_index("expires_at", expireAfterSeconds=0)
    # One settings doc per category; one notification recipient per email.
    category_settings_collection.create_index("category", unique=True)
    notification_emails_collection.create_index("email", unique=True)
except Exception as exc:  # pragma: no cover
    print(f"[db] index creation skipped: {exc}")

# A unique index on authority email can fail if legacy data already holds
# duplicates — isolate it so it never blocks the indexes above.
try:
    authorities_collection.create_index("email", unique=True)
except Exception as exc:  # pragma: no cover
    print(f"[db] authorities.email unique index skipped (duplicate emails?): {exc}")
