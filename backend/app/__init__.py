import logging
import re

from dotenv import load_dotenv
from flask import Flask, g, jsonify, request
from flask_compress import Compress
from flask_cors import CORS
import oracledb

# Flutter web / Vite use random localhost ports; allow any local origin.
_LOCAL_DEV_ORIGIN = re.compile(r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$")

from app.config import Config
from app.db import init_oracle_pool, oracle_cursor, pool_stats
from app.routes.auth import auth_bp, limiter
from app.routes.customers import customers_bp
from app.routes.dashboard import dashboard_bp
from app.routes.designations import designations_bp
from app.routes.routes_data import routes_data_bp
from app.routes.users import users_bp
from app.routes.targets import targets_bp
from app.routes.items import items_bp
from app.routes.tasks import tasks_bp
from app.routes.visits import visits_bp
from app.routes.orders import orders_bp
from app.routes.product_reviews import product_reviews_bp
from app.routes.market_research import market_research_bp
from app.routes.work_reports import work_reports_bp
from app.security import is_public_request, load_current_user_from_token

logger = logging.getLogger(__name__)


def create_app(config_class=Config):
    # Config already loads backend/.env; keep a no-op-safe call for process env.
    load_dotenv()

    app = Flask(__name__)
    app.config.from_object(config_class)

    secret = str(app.config.get("SECRET_KEY") or "")
    if not secret:
        raise RuntimeError("SECRET_KEY is required")
    min_secret = int(app.config.get("SECRET_KEY_MIN_LENGTH", 32))
    if len(secret) < min_secret:
        raise RuntimeError(
            f"SECRET_KEY must be at least {min_secret} characters "
            "(rotate if this key was ever committed to git)"
        )
    if not app.config.get("ORACLE_USER") or not app.config.get("ORACLE_DSN"):
        raise RuntimeError("ORACLE_USER and ORACLE_DSN are required")
    if not app.config.get("ORACLE_PASSWORD"):
        raise RuntimeError("ORACLE_PASSWORD is required")

    flask_env = str(app.config.get("FLASK_ENV", "production")).lower()
    admin_roles = app.config.get("ADMIN_ROLE_CODES") or []
    require_admin = app.config.get("REQUIRE_ADMIN_ROLES", True)
    if require_admin and flask_env != "development" and not admin_roles:
        raise RuntimeError(
            "ADMIN_ROLE_CODES must be set in production "
            "(comma-separated ROLECODE values for user/admin APIs)"
        )

    if app.config.get("CORS_ALLOW_ALL") and flask_env != "development":
        raise RuntimeError(
            "CORS_ALLOW_ALL cannot be enabled outside development"
        )

    app.config["MAX_CONTENT_LENGTH"] = app.config.get(
        "MAX_CONTENT_LENGTH", 10 * 1024 * 1024
    )

    if app.config.get("CORS_ALLOW_ALL"):
        CORS(
            app,
            resources={r"/api/*": {"origins": "*"}},
            supports_credentials=False,
            allow_headers=["Authorization", "Content-Type"],
        )
    else:
        cors_origins = list(app.config["CORS_ORIGINS"]) + [_LOCAL_DEV_ORIGIN]
        CORS(
            app,
            resources={
                r"/api/*": {
                    "origins": cors_origins,
                    "allow_headers": ["Authorization", "Content-Type"],
                    "methods": ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
                }
            },
            supports_credentials=False,
        )

    limiter.init_app(app)
    init_oracle_pool(app)

    # Gzip JSON responses (ITEMMASTER pages compress extremely well over tunnel/mobile).
    app.config.setdefault("COMPRESS_MIMETYPES", [
        "application/json",
        "text/html",
        "text/css",
        "application/javascript",
    ])
    app.config.setdefault("COMPRESS_LEVEL", 6)
    app.config.setdefault("COMPRESS_MIN_SIZE", 500)
    Compress(app)

    @app.before_request
    def enforce_authentication():
        if is_public_request():
            return None
        user, err = load_current_user_from_token()
        if err is not None:
            return err
        g.current_user = user
        return None

    @app.after_request
    def set_security_headers(response):
        response.headers.setdefault("X-Content-Type-Options", "nosniff")
        response.headers.setdefault("X-Frame-Options", "DENY")
        response.headers.setdefault("Referrer-Policy", "no-referrer")
        response.headers.setdefault(
            "Permissions-Policy", "geolocation=(), microphone=(), camera=()"
        )
        response.headers.setdefault(
            "Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'"
        )
        if request.is_secure or request.headers.get("X-Forwarded-Proto") == "https":
            response.headers.setdefault(
                "Strict-Transport-Security", "max-age=31536000; includeSubDomains"
            )
        # Private data defaults to no-store; semi-static catalog routes may
        # override with short private max-age + ETag (see designations/routes).
        if request.path.startswith("/api/") and "Cache-Control" not in response.headers:
            response.headers["Cache-Control"] = "no-store"
        elif not request.path.startswith("/api/"):
            response.headers.setdefault("Cache-Control", "no-cache")
        # Remove server fingerprint when possible
        response.headers.pop("Server", None)
        return response

    app.register_blueprint(auth_bp, url_prefix="/api/auth")
    app.register_blueprint(customers_bp, url_prefix="/api/customers")
    app.register_blueprint(dashboard_bp, url_prefix="/api/dashboard")
    app.register_blueprint(designations_bp, url_prefix="/api/designations")
    app.register_blueprint(routes_data_bp, url_prefix="/api/routes")
    app.register_blueprint(users_bp, url_prefix="/api/users")
    app.register_blueprint(targets_bp, url_prefix="/api/targets")
    app.register_blueprint(items_bp, url_prefix="/api/items")
    app.register_blueprint(tasks_bp, url_prefix="/api/tasks")
    app.register_blueprint(visits_bp, url_prefix="/api/visits")
    app.register_blueprint(orders_bp, url_prefix="/api/orders")
    app.register_blueprint(product_reviews_bp, url_prefix="/api/product-reviews")
    app.register_blueprint(market_research_bp, url_prefix="/api/market-research")
    app.register_blueprint(work_reports_bp, url_prefix="/api/work-reports")

    @app.errorhandler(oracledb.Error)
    def handle_oracle_error(error):
        logger.exception("Oracle error")
        return jsonify({"error": "A database error occurred"}), 500

    @app.errorhandler(429)
    def handle_rate_limit(error):
        return jsonify({"error": "Too many requests. Please try again later."}), 429

    @app.get("/api/health")
    def health():
        return jsonify({"status": "ok", "service": "crgs-admin-api"})

    @app.get("/api/health/db")
    def health_db():
        # Authenticated — avoids unauthenticated pool/recon disclosure.
        user = getattr(g, "current_user", None)
        if not user:
            return jsonify({"error": "Authentication required"}), 401
        try:
            with oracle_cursor() as cursor:
                cursor.execute("SELECT 1 FROM DUAL")
                cursor.fetchone()
            payload = {
                "status": "ok",
                "database": "connected",
            }
            from app.security import is_admin

            if is_admin(user):
                payload["pool"] = pool_stats()
            return jsonify(payload)
        except Exception:
            logger.exception("Database health check failed")
            return jsonify({"status": "error", "database": "unavailable"}), 503

    return app
