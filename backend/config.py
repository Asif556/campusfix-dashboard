import os
from dotenv import load_dotenv

load_dotenv()

MONGO_URI = os.getenv("MONGO_URI")
DB_NAME = os.getenv("DB_NAME", "campusfix")

# ── Auth token signing ────────────────────────────────────────────────────────
# Signs the stateless session tokens issued at login. MUST be a strong random
# value in production — if it leaks or stays at the dev default, tokens are
# forgeable and anyone can mint an admin session.
SECRET_KEY = os.getenv("SECRET_KEY")
if not SECRET_KEY:
    SECRET_KEY = "dev-insecure-change-me"
    print("[config] WARNING: SECRET_KEY not set in .env — using an insecure dev key. "
          "Set SECRET_KEY before deploying.")

# How long an issued login token stays valid, in seconds (default 24h).
TOKEN_MAX_AGE = int(os.getenv("TOKEN_MAX_AGE", 24 * 60 * 60))

# ── Auto-accept of unresponded fixes ──────────────────────────────────────────
# When an authority/admin marks a complaint "Pending Acceptance", the student is
# asked to accept the fix or reopen it. If they do neither within this many hours,
# a background sweeper closes it on their behalf (status -> Completed, flagged
# auto_accepted). Default: 1 day.
AUTO_ACCEPT_AFTER_HOURS = int(os.getenv("AUTO_ACCEPT_AFTER_HOURS", 24))
# How often the sweeper scans for expired pending-acceptance complaints, in seconds.
AUTO_ACCEPT_SWEEP_INTERVAL_SECONDS = int(os.getenv("AUTO_ACCEPT_SWEEP_INTERVAL_SECONDS", 15 * 60))
