import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent


class Config:
    SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-key")
    CORS_ORIGINS = [
        origin.strip()
        for origin in os.getenv(
            "CORS_ORIGINS", "http://192.168.61.41:5173,http://192.168.61.41:8080"
        ).split(",")
        if origin.strip()
    ]

    ORACLE_USER = os.getenv("ORACLE_USER", "RFSS")
    ORACLE_PASSWORD = os.getenv("ORACLE_PASSWORD", "rfss")
    ORACLE_DSN = os.getenv("ORACLE_DSN", "192.168.1.225:1521/rgc")
    ORACLE_CUSTOMERS_VIEW = os.getenv("ORACLE_CUSTOMERS_VIEW", "CUSTOMERS")
    ORACLE_CUSTOMER_AGE_VIEW = os.getenv("ORACLE_CUSTOMER_AGE_VIEW", "CUSTOMERAGEVIEW")
    # Default "missing" window (days). A customer is missing when never billed,
    # or last bill age >= this many days (0 = not billed today).
    MISSING_DAYS = int(os.getenv("MISSING_DAYS", "30"))
    ORACLE_BILLHDR_TABLE = os.getenv("ORACLE_BILLHDR_TABLE", "BILLHDR")
    ORACLE_BILLDTL_TABLE = os.getenv("ORACLE_BILLDTL_TABLE", "BILLDTL")
    ORACLE_ITEMMASTER_TABLE = os.getenv("ORACLE_ITEMMASTER_TABLE", "ITEMMASTER")
    ORACLE_ITEMMASTER_RATE_COLUMN = os.getenv("ORACLE_ITEMMASTER_RATE_COLUMN", "RATE")
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
    ORACLE_CLIENT_LIB_DIR = os.getenv("ORACLE_CLIENT_LIB_DIR", "")

    FLASK_ENV = os.getenv("FLASK_ENV", "development")
    CORS_ALLOW_ALL = os.getenv("CORS_ALLOW_ALL", "").lower() in ("1", "true", "yes")
