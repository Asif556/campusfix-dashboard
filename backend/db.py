import certifi
from pymongo import MongoClient
from config import MONGO_URI, DB_NAME

client = MongoClient(MONGO_URI, tls=True, tlsCAFile=certifi.where())
db = client[DB_NAME]

complaints_collection = db["complaints"]
admins_collection = db["admins"]
authorities_collection = db["authorities"]

# Indexes for the most common query patterns. create_index is idempotent, so
# this is safe to run on every startup; failures shouldn't block the app.
try:
    complaints_collection.create_index("student_email")
    complaints_collection.create_index("status")
    complaints_collection.create_index([("created_at", -1)])
except Exception as exc:  # pragma: no cover
    print(f"[db] index creation skipped: {exc}")
