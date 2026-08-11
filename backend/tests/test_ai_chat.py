"""Unit tests for Call Center AI helpers (no Groq network)."""

from app.routes.ai import (
    _LANGUAGE_INSTRUCTIONS,
    _build_context_block,
    _detect_requested_language,
    _normalize_history,
    _normalize_language,
    _resolve_language,
)


def test_normalize_history_keeps_roles_and_trims():
    history = _normalize_history(
        [
            {"role": "user", "content": "hello"},
            {"role": "system", "content": "ignore"},
            {"role": "assistant", "text": "hi"},
            {"role": "user", "content": ""},
        ]
    )
    assert history == [
        {"role": "user", "content": "hello"},
        {"role": "assistant", "content": "hi"},
    ]


def test_build_context_includes_customer_and_lines():
    block = _build_context_block(
        {
            "invoiceNo": "INV-1",
            "invoiceType": "CREDIT",
            "customer": {"name": "ACME", "code": "100", "creditAmount": 50},
            "salesman": {"name": "Ali", "code": "9"},
            "lines": [
                {
                    "itemCode": "A1",
                    "description": "Spice",
                    "qty": 2,
                    "uom": "EA",
                    "rate": 10,
                    "discount": 0,
                    "amount": 20,
                }
            ],
            "totals": {"netTotal": 20, "vatAmount": 1, "grandTotal": 21},
        }
    )
    assert "INV-1" in block
    assert "ACME" in block
    assert "A1" in block
    assert "Grand total" in block


def test_normalize_language_aliases():
    assert _normalize_language(None) == "auto"
    assert _normalize_language("EN") == "en"
    assert _normalize_language("ar-QA") == "ar"
    assert _normalize_language("fil") == "tl"
    assert _normalize_language("unknown") == "auto"
    assert "ar" in _LANGUAGE_INSTRUCTIONS
    assert "auto" in _LANGUAGE_INSTRUCTIONS


def test_detect_manglish_malayalam_request():
    msg = "ENIKK ONNUM MANASILAAVUNNILLA, MALAYALATHIL PARA"
    assert _detect_requested_language(msg) == "ml"
    assert _resolve_language(selected="auto", message=msg) == "ml"


def test_hindi_question_not_malayalam():
    msg = "CUSTOMER KA NAME KYAAAHE"
    assert _resolve_language(selected="auto", message=msg) == "hi"


def test_english_question_not_sticky_malayalam():
    msg = "WHAT IS THE CUSTOMER NAME"
    assert _resolve_language(selected="auto", message=msg) == "en"


def test_history_intent_detection():
    from app.routes.ai import _wants_purchase_history

    assert _wants_purchase_history("what did they buy last time")
    assert _wants_purchase_history("pehle ka bill history")
    assert _wants_purchase_history("show previous purchase")
    assert not _wants_purchase_history("apply 5% discount")


def test_format_purchase_history_block():
    from app.routes.ai import _format_purchase_history_block

    block = _format_purchase_history_block(
        cust_code="100",
        bills=[
            {
                "billno": "B1",
                "locationcode": "1",
                "billdate": "2024-05-01",
                "netbillamount": 120.5,
            }
        ],
        latest_items=[
            {
                "itemcode": "A1",
                "itemname": "Spice",
                "quantity": 2,
                "rate": 10,
                "ownproduct": True,
            }
        ],
        deep=False,
    )
    assert "B1" in block
    assert "Spice" in block
    assert "120.50" in block
    assert "OWN" in block


def test_customer_list_intent_and_limit():
    from app.routes.ai import (
        _parse_list_limit,
        _wants_customer_list,
        _wants_purchase_history,
        _format_customer_directory_block,
        _resolve_language,
        _AMOUNT_RANK_INTENT,
    )

    msg = "LISTOUT REPEAT 5 CUSTOMER LIST"
    assert _wants_customer_list(msg)
    assert not _wants_purchase_history(msg)
    assert _parse_list_limit(msg) == 5

    manglish = "AVASANAM VELIYA AMOUNT N PRODUCT PURCHASE CHEYTHAVAR"
    assert _wants_customer_list(manglish)
    assert _AMOUNT_RANK_INTENT.search(manglish)
    assert _resolve_language(selected="auto", message=manglish) == "ml"

    block = _format_customer_directory_block(
        rows=[
            {
                "cust_code": "C1",
                "cust_name": "Alpha Mart",
                "routename": "R1",
                "bill_count": 8,
                "total_amount": 900,
                "last_bill_date": "2024-06-01",
                "last_bill_amount": 250,
                "mobile": "50000000",
            }
        ],
        limit=5,
        days=90,
        min_bills=1,
        order_by="amount",
        product_map={
            "C1": [{"itemcode": "A1", "itemname": "Juice", "quantity": 2}]
        },
    )
    assert "Alpha Mart" in block
    assert "C1" in block
    assert "highest purchase amount" in block
    assert "Juice" in block
    assert "Oracle" not in block
    assert "BILLHDR" not in block
    assert "DB" not in block
    assert "Do NOT ask the agent to select a customer" in block
