import os
from dotenv import load_dotenv

load_dotenv()

from flask import Flask, send_from_directory, jsonify
from flask_cors import CORS

import utils.email_queue  # noqa: F401 — starts background email worker thread
from extensions import limiter
from routes.complaints import complaints_bp
from routes.admin import admin_bp
from routes.dashboard import dashboard_bp
from routes.auth import auth_bp
from routes.authorities import authorities_bp

UPLOAD_FOLDER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "uploads")
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

app = Flask(__name__)
app.config["UPLOAD_FOLDER"] = UPLOAD_FOLDER
# Cap request bodies (incl. uploads) at 5 MB to prevent memory-exhaustion DoS.
app.config["MAX_CONTENT_LENGTH"] = 5 * 1024 * 1024
# Restrict browser access to the configured frontend origin(s). Override in prod
# via CORS_ORIGINS (comma-separated). Defaults to the local Vite dev server.
_default_origins = "http://localhost:8080,http://127.0.0.1:8080"
CORS_ORIGINS = [o.strip() for o in os.getenv("CORS_ORIGINS", _default_origins).split(",") if o.strip()]
CORS(app, resources={r"/campusfix/api/*": {"origins": CORS_ORIGINS}})
limiter.init_app(app)


@app.errorhandler(413)
def payload_too_large(_e):
    return jsonify({"error": "File too large. Maximum upload size is 5 MB."}), 413

# Register blueprints under /campusfix/api prefix
app.register_blueprint(complaints_bp, url_prefix="/campusfix/api")
app.register_blueprint(admin_bp, url_prefix="/campusfix/api")
app.register_blueprint(dashboard_bp, url_prefix="/campusfix/api")
app.register_blueprint(auth_bp, url_prefix="/campusfix/api")
app.register_blueprint(authorities_bp, url_prefix="/campusfix/api")


@app.route("/")
def index():
    return {"message": "CampusFix API is running"}


@app.route("/campusfix/uploads/<path:filename>")
def uploaded_file(filename):
    return send_from_directory(app.config["UPLOAD_FOLDER"], filename)


if __name__ == "__main__":
    # Bind to all interfaces by default so a phone/emulator on the same Wi-Fi can
    # reach the API over the LAN (e.g. http://192.168.0.5:5000). Set HOST=127.0.0.1
    # to restrict back to localhost-only.
    host = os.environ.get("HOST", "0.0.0.0")
    port = int(os.environ.get("PORT", 5000))
    # Never default the Werkzeug debugger on — it allows RCE via the console.
    debug = os.getenv("FLASK_DEBUG", "").lower() in ("1", "true", "yes", "on")
    app.run(host=host, debug=debug, port=port)
