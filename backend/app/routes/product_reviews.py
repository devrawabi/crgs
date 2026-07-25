"""Customer product reviews — inserts into CRGS_PRODUCTREVIEW."""

from __future__ import annotations

import uuid
from pathlib import Path

from flask import Blueprint, current_app, jsonify, request, send_from_directory, url_for
from werkzeug.utils import secure_filename

from app.db import get_connection, oracle_cursor, row_to_dict

product_reviews_bp = Blueprint("product_reviews", __name__)

_ALLOWED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".gif"}
_MAX_IMAGE_BYTES = 8 * 1024 * 1024  # 8 MB


def _table_name() -> str:
    return current_app.config["ORACLE_PRODUCT_REVIEW_TABLE"]


def _uploads_dir() -> Path:
    configured = current_app.config.get("PRODUCT_REVIEW_UPLOAD_DIR")
    if configured:
        path = Path(configured)
    else:
        path = Path(current_app.root_path).resolve().parent / "uploads" / "product_reviews"
    path.mkdir(parents=True, exist_ok=True)
    return path


def _image_url(image_path: str | None) -> str | None:
    filename = str(image_path or "").strip()
    if not filename:
        return None
    return url_for(
        "product_reviews.get_product_review_image",
        filename=filename,
        _external=False,
    )


def _serialize_review(row: dict) -> dict:
    image_path = str(row.get("imagepath") or "").strip()
    return {
        "employeeCode": str(row.get("employeecode") or "").strip(),
        "route": str(row.get("route") or "").strip(),
        "customerCode": str(row.get("customercode") or "").strip(),
        "customerName": str(row.get("customername") or "").strip(),
        "itemCode": str(row.get("itemcode") or "").strip(),
        "itemName": str(row.get("itemname") or "").strip(),
        "reason": str(row.get("reason") or "").strip(),
        "imagePath": image_path or None,
        "imageUrl": _image_url(image_path),
    }


def _read_payload() -> tuple[dict, object | None]:
    content_type = (request.content_type or "").lower()
    if "multipart/form-data" in content_type:
        payload = {key: request.form.get(key) for key in request.form.keys()}
        return payload, request.files.get("image")
    return request.get_json(silent=True) or {}, None


def _save_image(image_file) -> str | None:
    if image_file is None or not getattr(image_file, "filename", None):
        return None

    original = secure_filename(image_file.filename)
    extension = Path(original).suffix.lower()
    if extension not in _ALLOWED_IMAGE_EXTENSIONS:
        raise ValueError("Image must be JPG, PNG, WEBP, or GIF")

    image_file.stream.seek(0, 2)
    size = image_file.stream.tell()
    image_file.stream.seek(0)
    if size <= 0:
        raise ValueError("Image file is empty")
    if size > _MAX_IMAGE_BYTES:
        raise ValueError("Image must be 8 MB or smaller")

    filename = f"{uuid.uuid4().hex}{extension}"
    destination = _uploads_dir() / filename
    image_file.save(destination)
    return filename


@product_reviews_bp.get("")
def list_product_reviews():
    """List product reviews from CRGS_PRODUCTREVIEW (for admin report)."""
    table_name = _table_name()
    search = str(request.args.get("search", "")).strip()
    employee_code = str(request.args.get("employeeCode", "")).strip()
    route = str(request.args.get("route", "")).strip()

    conditions: list[str] = []
    params: dict = {}

    if employee_code:
        conditions.append("TRIM(TO_CHAR(EMPLOYEECODE)) = :employeecode")
        params["employeecode"] = employee_code
    if route:
        conditions.append("TRIM(TO_CHAR(ROUTE)) = :route")
        params["route"] = route
    if search:
        conditions.append(
            "("
            "UPPER(CUSTOMERNAME) LIKE :search OR "
            "UPPER(NVL(CUSTOMERCODE, '')) LIKE :search OR "
            "UPPER(ITEMNAME) LIKE :search OR "
            "UPPER(NVL(ITEMCODE, '')) LIKE :search OR "
            "UPPER(NVL(REASON, '')) LIKE :search OR "
            "UPPER(NVL(TO_CHAR(EMPLOYEECODE), '')) LIKE :search OR "
            "UPPER(NVL(TO_CHAR(ROUTE), '')) LIKE :search"
            ")"
        )
        params["search"] = f"%{search.upper()}%"

    where_sql = f" WHERE {' AND '.join(conditions)}" if conditions else ""

    with oracle_cursor() as cursor:
        cursor.execute(
            f"""
            SELECT
                EMPLOYEECODE,
                ROUTE,
                CUSTOMERCODE,
                CUSTOMERNAME,
                ITEMCODE,
                ITEMNAME,
                REASON,
                IMAGEPATH
            FROM {table_name}
            {where_sql}
            ORDER BY EMPLOYEECODE, ROUTE, CUSTOMERNAME, ITEMNAME
            """,
            params,
        )
        items = [
            _serialize_review(row_to_dict(cursor, row)) for row in cursor.fetchall()
        ]

    return jsonify({"count": len(items), "items": items})


@product_reviews_bp.get("/images/<path:filename>")
def get_product_review_image(filename: str):
    """Serve a previously uploaded product-review image."""
    safe_name = Path(filename).name
    if not safe_name or "/" in filename or "\\" in filename:
        return jsonify({"error": "Invalid image filename"}), 400
    return send_from_directory(_uploads_dir(), safe_name)


@product_reviews_bp.post("")
def create_product_review():
    """
    Insert a row into CRGS_PRODUCTREVIEW:
    EMPLOYEECODE, ROUTE, CUSTOMERCODE, CUSTOMERNAME, ITEMCODE, ITEMNAME, REASON, IMAGEPATH
    Accepts JSON or multipart/form-data (optional image field).
    """
    payload, image_file = _read_payload()

    employee_code = str(payload.get("employeeCode", "")).strip()
    route = str(payload.get("route", "")).strip()
    customer_code = str(payload.get("customerCode", "")).strip()
    customer_name = str(payload.get("customerName", "")).strip()
    item_code = str(payload.get("itemCode", "")).strip()
    item_name = str(payload.get("itemName", "")).strip()
    # Accept reason or remarks from the client.
    reason = str(payload.get("reason", "") or payload.get("remarks", "")).strip()

    if not employee_code:
        return jsonify({"error": "Employee code is required"}), 400
    if not route:
        return jsonify({"error": "Route is required"}), 400
    if not customer_code:
        return jsonify({"error": "Customer code is required"}), 400
    if not customer_name:
        return jsonify({"error": "Customer name is required"}), 400
    if not item_code:
        return jsonify({"error": "Item code is required"}), 400
    if not item_name:
        return jsonify({"error": "Item name is required"}), 400
    if not reason:
        return jsonify({"error": "Reason is required"}), 400

    if len(employee_code) > 20:
        return jsonify({"error": "Employee code must be 20 characters or fewer"}), 400
    if len(route) > 20:
        return jsonify({"error": "Route must be 20 characters or fewer"}), 400
    if len(customer_code) > 20:
        return jsonify({"error": "Customer code must be 20 characters or fewer"}), 400
    if len(customer_name) > 100:
        customer_name = customer_name[:100]
    if len(item_code) > 30:
        return jsonify({"error": "Item code must be 30 characters or fewer"}), 400
    if len(item_name) > 100:
        item_name = item_name[:100]
    if len(reason) > 500:
        reason = reason[:500]

    try:
        image_path = _save_image(image_file)
    except ValueError as exc:
        return jsonify({"error": str(exc)}), 400

    table_name = _table_name()

    with oracle_cursor() as cursor:
        cursor.execute(
            f"""
            INSERT INTO {table_name}
                (
                    EMPLOYEECODE,
                    ROUTE,
                    CUSTOMERCODE,
                    CUSTOMERNAME,
                    ITEMCODE,
                    ITEMNAME,
                    REASON,
                    IMAGEPATH
                )
            VALUES
                (
                    :employeecode,
                    :route,
                    :customercode,
                    :customername,
                    :itemcode,
                    :itemname,
                    :reason,
                    :imagepath
                )
            """,
            {
                "employeecode": employee_code,
                "route": route,
                "customercode": customer_code,
                "customername": customer_name,
                "itemcode": item_code,
                "itemname": item_name,
                "reason": reason,
                "imagepath": image_path,
            },
        )
        get_connection().commit()

    return (
        jsonify(
            {
                "employeeCode": employee_code,
                "route": route,
                "customerCode": customer_code,
                "customerName": customer_name,
                "itemCode": item_code,
                "itemName": item_name,
                "reason": reason,
                "imagePath": image_path,
                "imageUrl": _image_url(image_path),
            }
        ),
        201,
    )
