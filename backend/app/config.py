import os
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")


class Config:
    SECRET_KEY = os.getenv("SECRET_KEY", "").strip()
    CORS_ORIGINS = [
        origin.strip()
        for origin in os.getenv(
            "CORS_ORIGINS",
            "https://crgs.rfoodinternational.com,http://127.0.0.1:5317,http://localhost:5317",
        ).split(",")
        if origin.strip()
    ]

    ORACLE_USER = os.getenv("ORACLE_USER", "").strip()
    ORACLE_PASSWORD = os.getenv("ORACLE_PASSWORD", "")
    ORACLE_DSN = os.getenv("ORACLE_DSN", "").strip()
    ORACLE_CUSTOMERS_VIEW = os.getenv("ORACLE_CUSTOMERS_VIEW", "CUSTOMERS")
    ORACLE_CUSTOMER_AGE_VIEW = os.getenv("ORACLE_CUSTOMER_AGE_VIEW", "CUSTOMERAGEVIEW")
    # Cash-customer dues (CUSTOMERCODE, OUTSTANDING, CREDITLIMIT) — joined for Outstanding.
    ORACLE_CASH_CUSTOMER_BALANCE_VIEW = os.getenv(
        "ORACLE_CASH_CUSTOMER_BALANCE_VIEW", "CASHCUSTOMERBALANCE"
    )
    MISSING_DAYS = int(os.getenv("MISSING_DAYS", "30"))
    ORACLE_BILLHDR_TABLE = os.getenv("ORACLE_BILLHDR_TABLE", "BILLHDR")
    ORACLE_BILLDTL_TABLE = os.getenv("ORACLE_BILLDTL_TABLE", "BILLDTL")
    ORACLE_ITEMMASTER_TABLE = os.getenv("ORACLE_ITEMMASTER_TABLE", "ITEMMASTER")
    ORACLE_ITEMMASTER_RATE_COLUMN = os.getenv("ORACLE_ITEMMASTER_RATE_COLUMN", "RATE")
    # Timestamp column for delta product sync (e.g. LAST_UPDATED).
    # Empty = auto-detect common column names; set explicitly after DBA DDL.
    ORACLE_ITEMMASTER_UPDATED_COLUMN = os.getenv(
        "ORACLE_ITEMMASTER_UPDATED_COLUMN", "LAST_UPDATED"
    ).strip()
    # Alternate UOMs (CTN / DZN / SET …) keyed by ITEMCODE.
    ORACLE_ITEM_ALTERNATE_UOM_TABLE = os.getenv(
        "ORACLE_ITEM_ALTERNATE_UOM_TABLE", "ITEMALTERNATEUOMMAP"
    ).strip()
    ORACLE_POOL_MIN = int(os.getenv("ORACLE_POOL_MIN", "4"))
    ORACLE_POOL_MAX = int(os.getenv("ORACLE_POOL_MAX", "16"))
    ORACLE_POOL_INCREMENT = int(os.getenv("ORACLE_POOL_INCREMENT", "2"))
    ORACLE_POOL_TIMEOUT = int(os.getenv("ORACLE_POOL_TIMEOUT", "15"))
    ORACLE_POOL_PING_INTERVAL = int(os.getenv("ORACLE_POOL_PING_INTERVAL", "60"))
    # Recycle pooled sessions after N seconds (0 disables). Avoids stale listeners.
    ORACLE_POOL_MAX_LIFETIME = int(os.getenv("ORACLE_POOL_MAX_LIFETIME", "3600"))
    ORACLE_STMT_CACHE_SIZE = int(os.getenv("ORACLE_STMT_CACHE_SIZE", "30"))
    ORACLE_CURSOR_ARRAYSIZE = int(os.getenv("ORACLE_CURSOR_ARRAYSIZE", "500"))
    # Abort individual Oracle calls after N ms (0 = disabled). Prevents API hangs.
    ORACLE_CALL_TIMEOUT_MS = int(os.getenv("ORACLE_CALL_TIMEOUT_MS", "25000"))
    ORACLE_ROUTES_TABLE = os.getenv("ORACLE_ROUTES_TABLE", "TBLROUTES")
    ORACLE_LOGIN_USERS_TABLE = os.getenv("ORACLE_LOGIN_USERS_TABLE", "CRGS_USER")
    ORACLE_DESIGNATION_TABLE = os.getenv(
        "ORACLE_DESIGNATION_TABLE", "CRGS_DESIGNATION"
    )
    ORACLE_SALE_TARGETS_TABLE = os.getenv("ORACLE_SALE_TARGETS_TABLE", "CRGS_SALETARGET")
    ORACLE_PRODUCT_TARGETS_TABLE = os.getenv(
        "ORACLE_PRODUCT_TARGETS_TABLE", "CRGS_PRODUCTTARGET"
    )
    ORACLE_CUSTOMER_TARGETS_TABLE = os.getenv(
        "ORACLE_CUSTOMER_TARGETS_TABLE", "CRGS_CUSTOMERTARGET"
    )
    ORACLE_TASKS_TABLE = os.getenv("ORACLE_TASKS_TABLE", "CRGS_TASK")
    ORACLE_VISITDETAILS_TABLE = os.getenv(
        "ORACLE_VISITDETAILS_TABLE", "CRGS_VISITDETAILS"
    )
    ORACLE_ORDERHDR_TABLE = os.getenv("ORACLE_ORDERHDR_TABLE", "CRGS_ORDERHDR")
    ORACLE_ORDERDTL_TABLE = os.getenv("ORACLE_ORDERDTL_TABLE", "CRGS_ORDERDTL")
    ORACLE_CONTACTINFO_TABLE = os.getenv(
        "ORACLE_CONTACTINFO_TABLE", "CRGS_CONTACTINFO"
    )
    ORACLE_PRODUCT_REVIEW_TABLE = os.getenv(
        "ORACLE_PRODUCT_REVIEW_TABLE", "CRGS_PRODUCTREVIEW"
    )
    PRODUCT_REVIEW_UPLOAD_DIR = os.getenv(
        "PRODUCT_REVIEW_UPLOAD_DIR",
        str(BASE_DIR / "uploads" / "product_reviews"),
    )
    ORACLE_MARKETRESEARCH_TABLE = os.getenv(
        "ORACLE_MARKETRESEARCH_TABLE", "CRGS_MARKETRESEARCH"
    )
    ORACLE_WORKREPORT_TABLE = os.getenv(
        "ORACLE_WORKREPORT_TABLE", "CRGS_WORKREPORT"
    )
    ORACLE_CLIENT_LIB_DIR = os.getenv("ORACLE_CLIENT_LIB_DIR", "")

    FLASK_ENV = os.getenv("FLASK_ENV", "production")
    CORS_ALLOW_ALL = os.getenv("CORS_ALLOW_ALL", "false").lower() in (
        "1",
        "true",
        "yes",
    )
    # When true (Cloudflare tunnel), rate limits use CF-Connecting-IP only.
    TRUST_PROXY = os.getenv("TRUST_PROXY", "true").lower() in ("1", "true", "yes")
    JWT_EXPIRE_HOURS = int(os.getenv("JWT_EXPIRE_HOURS", "4"))
    JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
    JWT_ISSUER = os.getenv("JWT_ISSUER", "crgs-admin")
    # Full admin portal (all tabs including Dashboard + User Management).
    ADMIN_ROLE_CODES = [
        code.strip()
        for code in os.getenv("ADMIN_ROLE_CODES", "1,3,4,6,8").split(",")
        if code.strip()
    ]
    # Manager portal: all tabs except Dashboard + User Management.
    MANAGER_ROLE_CODES = [
        code.strip()
        for code in os.getenv("MANAGER_ROLE_CODES", "2,5").split(",")
        if code.strip()
    ]
    # Call Center only (single tab).
    CALL_CENTER_ROLE_CODES = [
        code.strip()
        for code in os.getenv("CALL_CENTER_ROLE_CODES", "9").split(",")
        if code.strip()
    ]
    # Require configured admin roles outside development.
    REQUIRE_ADMIN_ROLES = os.getenv("REQUIRE_ADMIN_ROLES", "true").lower() in (
        "1",
        "true",
        "yes",
    )
    PASSWORD_MIN_LENGTH = int(os.getenv("PASSWORD_MIN_LENGTH", "8"))
    ALLOW_LEGACY_PLAINTEXT_PASSWORDS = os.getenv(
        "ALLOW_LEGACY_PLAINTEXT_PASSWORDS", "false"
    ).lower() in ("1", "true", "yes")
    MAX_CONTENT_LENGTH = int(os.getenv("MAX_CONTENT_LENGTH", str(10 * 1024 * 1024)))
    SECRET_KEY_MIN_LENGTH = int(os.getenv("SECRET_KEY_MIN_LENGTH", "32"))

    # Call Center AI assistant (Groq OpenAI-compatible chat API).
    GROQ_API_KEY = os.getenv("GROQ_API_KEY", "").strip()
    GROQ_MODEL = os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile").strip()
    GROQ_TIMEOUT_SECONDS = float(os.getenv("GROQ_TIMEOUT_SECONDS", "45"))
