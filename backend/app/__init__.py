from dotenv import load_dotenv
from flask import Flask, jsonify
from flask_cors import CORS
import oracledb

from app.config import Config
from app.db import init_oracle_pool, oracle_cursor
from app.routes.auth import auth_bp
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


def create_app(config_class=Config):
    load_dotenv()

    app = Flask(__name__)
    app.config.from_object(config_class)

    if app.config.get("CORS_ALLOW_ALL") or app.config.get("FLASK_ENV") == "development":
        CORS(
            app,
            resources={r"/api/*": {"origins": "*"}},
            supports_credentials=False,
        )
    else:
        CORS(app, origins=app.config["CORS_ORIGINS"])

    init_oracle_pool(app)

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
        return jsonify({"error": str(error)}), 500

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
        except Exception as exc:
            return jsonify({"status": "error", "database": str(exc)}), 503

    return app
