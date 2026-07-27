import logging

from dotenv import load_dotenv
from flask import Flask, g, jsonify, request
from flask_cors import CORS
import oracledb

from app.config import Config
from app.db import init_oracle_pool, oracle_cursor
from app.routes.auth import auth_bp, limiter
from app.routes.customers import customers_bp
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
from app.security import is_public_request, load_current_user_from_token

logger = logging.getLogger(__name__)


def create_app(config_class=Config):
    load_dotenv()

    app = Flask(__name__)
    app.config.from_object(config_class)

    if not app.config.get("SECRET_KEY"):
        raise RuntimeError("SECRET_KEY is required")
    if not app.config.get("ORACLE_USER") or not app.config.get("ORACLE_DSN"):
        raise RuntimeError("ORACLE_USER and ORACLE_DSN are required")
    if not app.config.get("ORACLE_PASSWORD"):
        raise RuntimeError("ORACLE_PASSWORD is required")

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
        CORS(
            app,
            resources={
                r"/api/*": {
                    "origins": app.config["CORS_ORIGINS"],
                    "allow_headers": ["Authorization", "Content-Type"],
                    "methods": ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
                }
            },
            supports_credentials=False,
        )

    limiter.init_app(app)
    init_oracle_pool(app)

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
            "Cache-Control", "no-store" if request.path.startswith("/api/") else "no-cache"
        )
        # Remove server fingerprint when possible
        response.headers.pop("Server", None)
        return response

    app.register_blueprint(auth_bp, url_prefix="/api/auth")
    app.register_blueprint(customers_bp, url_prefix="/api/customers")
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
        try:
            with oracle_cursor() as cursor:
                cursor.execute("SELECT 1 FROM DUAL")
                cursor.fetchone()
            return jsonify({"status": "ok", "database": "connected"})
        except Exception:
            logger.exception("Database health check failed")
            return jsonify({"status": "error", "database": "unavailable"}), 503

    return app
