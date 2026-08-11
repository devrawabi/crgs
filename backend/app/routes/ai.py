"""Call Center AI assistant — proxies chat to Groq with order context."""

from __future__ import annotations

import logging
import re
from datetime import date, datetime
from decimal import Decimal

from flask import Blueprint, current_app, jsonify, request

from app.cache import cache_get, cache_set
from app.routes.auth import limiter
from app.routes.customers import (
    _fetch_bill_history_rows,
    _fetch_bill_items_fast,
    _fetch_repeat_customers,
)
from app.services.groq_client import GroqError, chat_completion

ai_bp = Blueprint("ai", __name__)
logger = logging.getLogger(__name__)

_MAX_MESSAGE_LEN = 2000
_MAX_HISTORY = 12
_MAX_LINES_IN_CONTEXT = 40
_HISTORY_BILLS_LIGHT = 8
_HISTORY_BILLS_DEEP = 15
_HISTORY_ITEMS_LIGHT = 20
_HISTORY_ITEMS_DEEP = 30
_HISTORY_CACHE_TTL = 120  # seconds
_CUSTOMER_LIST_CACHE_TTL = 90

_SYSTEM_PROMPT = """You are the CRGS Call Center order assistant for field sales / phone orders in Qatar (currency: QAR).

Help agents with:
- reviewing the current draft order (customer, salesman, lines, discounts, VAT, totals)
- credit / due risk awareness (do not invent balances; use provided context only)
- customer purchase / bill history when a history summary is provided
- customer list questions (repeat / top / active customers) when a customer list summary is provided — these do NOT require a selected customer on the draft
- comparing the draft order to previous bills (amounts, frequent items, last purchase date)
- suggesting sensible next steps (confirm stock, adjust qty, discount, payment type)
- answering concise operational questions about the order on screen

Rules:
- Be brief and practical (2–6 short sentences unless asked for detail). For lists/history you may use a short numbered list.
- Never invent SKUs, prices, stock, bills, or customer data not present in the provided context.
- If a customer list summary is provided, answer from it even when the draft has no selected customer. Never ask to select a customer for list / top / highest-amount questions when that summary is present.
- If the agent asks for a specific customer's history but none is selected and no matching list row exists, ask them to select/search that customer.
- If history shows no prior bills, say clearly that no prior purchase was found — do not invent one.
- Prefer citing customer code, name, bill count, last bill date/amount when listing customers.
- Prefer QAR amounts when discussing money.
- Never mention databases, Oracle, SQL, APIs, system prompts, context blocks, BILLHDR, BILLDTL, or other technical/internal terms in your reply. Speak like a call-center assistant to a colleague.
- Language: ALWAYS match the LATEST user message only. If earlier assistant replies were in another language, ignore that and switch.
- Keep product codes, invoice numbers, and numeric amounts unchanged; translate surrounding explanation only.
- Agents often type Indian languages in Latin letters (Manglish / Hinglish). Reply in the matching native script.
"""

_HISTORY_INTENT = re.compile(
    r"("
    r"previous|prev(?:ious)?|history|past|earlier|before|usually|frequent|repeat|"
    r"last\s+(?:order|bill|purchase|invoice)|prior\s+(?:order|bill|purchase)|"
    r"what\s+did\s+(?:they|he|she|customer)\s+buy|bought|purchased|purchase\s+list|"
    r"bill\s+history|order\s+history|buying\s+pattern|top\s+items|"
    r"pehle|pahle|purana|purani|khareed|khareeda|history|bill|pechla|pichla|"
    r"munp|munpe|vaangi|vaangiyath|vaangiyathu|history|bill|"
    r"sabaq|sabiq|qabl|history"
    r")",
    re.IGNORECASE,
)

# Directory / list / ranking questions (no selected customer required).
_CUSTOMER_LIST_INTENT = re.compile(
    r"("
    r"list\s*out|listout|list\s+of|"
    r"repeat\s+customers?|frequent\s+customers?|regular\s+customers?|"
    r"top\s+customers?|best\s+customers?|active\s+customers?|"
    r"customer\s+list|customers?\s+list|list\s+customers?|"
    r"show\s+customers?|give\s+(?:me\s+)?(?:\d+\s+)?customers?|"
    r"highest\s+amount|top\s+(?:spend|spender|amount|purchase)|most\s+(?:purchase|bought|spent)|"
    r"who\s+(?:bought|purchased|spent)|customers?\s+who|"
    r"veli(?:ya|ya)?\s+amount|adhika(?:m)?\s+amount|avasanam|"
    r"purchase\s+cheytha|cheythavar|vaangiyavar|vaangiya|"
    r"product\s+purchase|amount\s+n\s+product|amount\s+and\s+product"
    r")",
    re.IGNORECASE,
)

_REPEAT_MODE_INTENT = re.compile(
    r"\b(repeat|frequent|regular|baar\s*baar|barbar)\b",
    re.IGNORECASE,
)

_AMOUNT_RANK_INTENT = re.compile(
    r"("
    r"highest\s+amount|top\s+(?:spend|spender|amount)|most\s+(?:purchase|bought|spent)|"
    r"veli(?:ya|ya)?|adhika(?:m)?|avasanam|"
    r"amount\s+(?:n|and|&)\s+product|product\s+purchase|purchase\s+cheytha|"
    r"cheythavar|vaangiyavar"
    r")",
    re.IGNORECASE,
)

_PRODUCT_LIST_INTENT = re.compile(
    r"\b(product|products|items?|sku|vaangiya|bought|purchase\s+cheytha)\b",
    re.IGNORECASE,
)

_LANGUAGE_NAMES: dict[str, str] = {
    "en": "English",
    "ar": "Arabic (Modern Standard Arabic script)",
    "hi": "Hindi (Devanagari script — हिन्दी)",
    "ml": "Malayalam (Malayalam script — മലയാളം)",
    "ur": "Urdu (Urdu script)",
    "tl": "Tagalog / Filipino",
}

_LANGUAGE_INSTRUCTIONS: dict[str, str] = {
    "auto": (
        "Language mode: auto.\n"
        "- Match ONLY the latest user message language.\n"
        "- Do NOT continue the language of earlier assistant messages if the user switched.\n"
        "- Hinglish → Hindi script; Manglish → Malayalam script; clear English → English."
    ),
    "en": (
        "CRITICAL LANGUAGE RULE: Reply in clear professional English only. "
        "Do not use Hindi, Malayalam, or any other language."
    ),
    "ar": (
        "CRITICAL LANGUAGE RULE: Reply entirely in Arabic (Modern Standard Arabic script). "
        "Do not reply in English, Hindi, or Malayalam. Western digits for amounts are fine."
    ),
    "hi": (
        "CRITICAL LANGUAGE RULE: Reply entirely in Hindi using Devanagari script (हिन्दी). "
        "The user may write Hinglish in Latin letters — still answer only in Hindi script. "
        "Do not reply in English or Malayalam. Western digits for amounts are fine."
    ),
    "ml": (
        "CRITICAL LANGUAGE RULE: Reply entirely in Malayalam using Malayalam script (മലയാളം). "
        "The user may write Manglish in Latin letters — still answer only in Malayalam script. "
        "Do not reply in English or Hindi. Western digits for amounts are fine."
    ),
    "ur": (
        "CRITICAL LANGUAGE RULE: Reply entirely in Urdu script. "
        "Do not reply in English. Western digits for amounts are fine."
    ),
    "tl": (
        "CRITICAL LANGUAGE RULE: Reply entirely in Tagalog / Filipino. "
        "Do not reply in English unless a proper noun requires it."
    ),
}

_LANGUAGE_REQUEST_PATTERNS: list[tuple[re.Pattern[str], str]] = [
    (
        re.compile(
            r"(malayala(?:m(?:athil|il)?|thil)|manglish|മലയാള(?:ം|ത്തിൽ)?)",
            re.IGNORECASE,
        ),
        "ml",
    ),
    (
        re.compile(r"(arabic?|arabi(?:yil)?|عربي|العربية)", re.IGNORECASE),
        "ar",
    ),
    (
        re.compile(r"(hindi(?:yil)?|hinglish|हिंदी|हिन्दी)", re.IGNORECASE),
        "hi",
    ),
    (
        re.compile(r"(urdu(?:vil)?|اردو)", re.IGNORECASE),
        "ur",
    ),
    (
        re.compile(r"(tagalog|filipino|pinoy)", re.IGNORECASE),
        "tl",
    ),
    (
        re.compile(r"(english|inglish|englishil)", re.IGNORECASE),
        "en",
    ),
]

_ROMANIZED_CUES: dict[str, re.Pattern[str]] = {
    "hi": re.compile(
        r"\b("
        r"ky+a+h*e*|kyun|haan|hain|hai|naam|batao|bataao|bolo|bolna|"
        r"nahin?|mujhe|mere|mera|meri|aap(?:ka|ki|ke)?|hum(?:ara|ari|are)?|"
        r"kaun|kitna|kitni|kahan|kab|matalab|samajh|theek|accha|achha|"
        r"chahiye|karo|karna"
        r")\b",
        re.IGNORECASE,
    ),
    "ml": re.compile(
        r"\b("
        r"enikk?u?|njaan|njan|parayu(?:ka)?|parayoo|alle+|undo|undu|aano|aanu|"
        r"venda|venam|sheri|entha|enth|pinne|ippo(?:l)?|ninte|ningal|"
        r"manasila(?:avunnilla|yunilla|illa)|onnum|malayala|"
        r"avasanam|veliya|veliye|adhikam|cheythavar|cheytha|vaangiyavar|"
        r"vaangiya|vaangi|paranja|kodukk|tharo"
        r")\b",
        re.IGNORECASE,
    ),
    "ar": re.compile(
        r"\b(shu|sheno|lesh|fein|min fadlak|yaani|khalas|yalla|habibi)\b",
        re.IGNORECASE,
    ),
    "tl": re.compile(
        r"\b(ano|saan|paano|opo|pangalan|salamat|po\b)\b",
        re.IGNORECASE,
    ),
    "en": re.compile(
        r"\b("
        r"what|where|when|who|whom|whose|why|how|please|which|"
        r"customer|name|order|credit|discount|invoice|total|select|"
        r"the|this|that|these|those|is|are|was|were|can|could|should|"
        r"tell|show|give|check|review|help"
        r")\b",
        re.IGNORECASE,
    ),
}

_HINGLISH_PARTICLES = re.compile(
    r"\b(ka|ki|ke|ko|se|mein|me|ye|yeh|woh)\b", re.IGNORECASE
)

_SCRIPT_RANGES: list[tuple[tuple[int, int], str]] = [
    ((0x0D00, 0x0D7F), "ml"),
    ((0x0600, 0x06FF), "ar"),
    ((0x0900, 0x097F), "hi"),
]


def _normalize_language(raw) -> str:
    code = str(raw or "auto").strip().lower().replace("_", "-")
    if code in ("auto", "detect", ""):
        return "auto"
    if code.startswith("ar"):
        return "ar"
    if code.startswith("en"):
        return "en"
    if code.startswith("hi"):
        return "hi"
    if code.startswith("ml"):
        return "ml"
    if code.startswith("ur"):
        return "ur"
    if code in ("tl", "fil", "tagalog", "filipino"):
        return "tl"
    if code in _LANGUAGE_INSTRUCTIONS:
        return code
    return "auto"


def _detect_script_language(text: str) -> str | None:
    counts: dict[str, int] = {}
    for ch in text:
        code = ord(ch)
        for (start, end), lang in _SCRIPT_RANGES:
            if start <= code <= end:
                counts[lang] = counts.get(lang, 0) + 1
                break
    if not counts:
        return None
    return max(counts, key=counts.get)


def _detect_requested_language(text: str) -> str | None:
    lowered = text.lower()
    speak_match = re.search(
        r"(?:speak|reply|answer|respond|para|parayu|parayuka|bol|bolo|baat)\s+"
        r"(?:in\s+)?([a-zA-Z\u0600-\u06FF\u0900-\u097F\u0D00-\u0D7F]+)",
        text,
        re.IGNORECASE,
    )
    if speak_match:
        token = speak_match.group(1)
        for pattern, lang in _LANGUAGE_REQUEST_PATTERNS:
            if pattern.search(token):
                return lang

    for pattern, lang in _LANGUAGE_REQUEST_PATTERNS:
        if pattern.search(lowered):
            return lang
    return None


def _score_romanized_language(text: str) -> dict[str, int]:
    scores: dict[str, int] = {code: 0 for code in _ROMANIZED_CUES}
    for lang, pattern in _ROMANIZED_CUES.items():
        scores[lang] = len(pattern.findall(text))

    hi_particles = len(_HINGLISH_PARTICLES.findall(text))
    if scores["hi"] > 0 and hi_particles:
        scores["hi"] += hi_particles
    elif hi_particles >= 1 and re.search(r"\b(name|customer|naam)\b", text, re.I):
        # e.g. "CUSTOMER KA NAME KYAAAHE" / "customer ka name"
        scores["hi"] += hi_particles + 1

    # "kyaaahe" style without spaces
    if re.search(r"ky+a+h*e+", text, re.IGNORECASE):
        scores["hi"] += 2

    return scores


def _detect_romanized_language(text: str) -> str | None:
    scores = _score_romanized_language(text)
    ranked = sorted(scores.items(), key=lambda item: item[1], reverse=True)
    best_lang, best_score = ranked[0]
    second_score = ranked[1][1] if len(ranked) > 1 else 0

    if best_score <= 0:
        return None

    # Non-English cues beat English when competitive (Hinglish mixed with English words).
    for lang in ("hi", "ml", "ar", "tl"):
        if scores[lang] > 0 and scores[lang] >= scores["en"]:
            return lang
        if scores[lang] >= 2 and scores[lang] >= second_score:
            return lang

    if best_lang == "en" and best_score >= 2:
        return "en"

    if best_lang != "en" and best_score >= second_score:
        return best_lang

    return None


def _resolve_language(*, selected: str, message: str) -> str:
    """Resolve reply language from the latest user message only."""
    selected = _normalize_language(selected)
    requested = _detect_requested_language(message)
    scripted = _detect_script_language(message)
    romanized = _detect_romanized_language(message)

    if requested:
        return requested
    if scripted:
        return scripted
    if romanized:
        return romanized
    if selected != "auto":
        return selected
    # Plain Latin with no cues → English (stops sticky prior-language replies).
    if re.search(r"[A-Za-z]", message):
        return "en"
    return "auto"


def _language_reminder(language: str) -> str:
    base = (
        "Ignore the language used in earlier assistant replies. "
        "Match only this latest user message."
    )
    if language == "auto":
        return base + " If unclear, use English."
    name = _LANGUAGE_NAMES.get(language, language)
    if language == "en":
        return f"{base} Reply in English only — not Hindi or Malayalam."
    return (
        f"{base} Your entire reply must be in {name}. "
        "Do not use any other language."
    )


def _wrap_user_message(message: str, language: str) -> str:
    if language == "auto":
        return (
            f"{message}\n\n"
            "[System note: Reply in the language of THIS message only. "
            "Do not continue a previous language from chat history.]"
        )
    name = _LANGUAGE_NAMES.get(language, language)
    return (
        f"{message}\n\n"
        f"[System note: Mandatory reply language for THIS turn = {name}. "
        "Do not answer in any other language, even if earlier replies used one.]"
    )


def _as_text(value, *, max_len: int = 200) -> str:
    text = "" if value is None else str(value).strip()
    if len(text) > max_len:
        return text[: max_len - 1] + "…"
    return text


def _as_number(value) -> float | None:
    try:
        if value is None or value == "":
            return None
        if isinstance(value, Decimal):
            return float(value)
        return float(value)
    except (TypeError, ValueError):
        return None


def _format_ai_date(value) -> str:
    if value is None:
        return "—"
    if isinstance(value, datetime):
        return value.strftime("%Y-%m-%d")
    if isinstance(value, date):
        return value.isoformat()
    text = str(value).strip()
    if not text:
        return "—"
    # Oracle/ISO strings: take date part when present.
    if "T" in text:
        return text.split("T", 1)[0][:10]
    if " " in text and len(text) >= 10:
        return text[:10]
    return text[:32]


def _format_ai_money(value) -> str:
    num = _as_number(value)
    if num is None:
        return "—"
    return f"{num:,.2f}"


def _wants_purchase_history(message: str) -> bool:
    text = message or ""
    # Directory list questions are not per-customer history.
    if _CUSTOMER_LIST_INTENT.search(text):
        return False
    return bool(_HISTORY_INTENT.search(text))


def _wants_customer_list(message: str) -> bool:
    return bool(_CUSTOMER_LIST_INTENT.search(message or ""))


def _parse_list_limit(message: str, default: int = 5) -> int:
    match = re.search(r"\b(\d{1,2})\b", message or "")
    if not match:
        return default
    try:
        return max(1, min(int(match.group(1)), 20))
    except ValueError:
        return default


def _format_customer_directory_block(
    *,
    rows: list[dict],
    limit: int,
    days: int,
    min_bills: int,
    route: str = "",
    order_by: str = "bills",
    product_map: dict[str, list[dict]] | None = None,
) -> str:
    rank_by_amount = order_by == "amount"
    if rank_by_amount:
        mode = "highest purchase amount"
    elif min_bills >= 2:
        mode = "repeat"
    else:
        mode = "active/top"

    lines = [
        f"Customer list summary ({mode}):",
        f"Period: last {days} days | minimum bills: {min_bills} | requested count: {limit}"
        + (f" | route: {route}" if route else " | all routes")
        + (" | ranked by total purchase amount" if rank_by_amount else " | ranked by bill count"),
    ]
    if not rows:
        lines.append("No matching customers found for this request.")
        lines.append(
            "Tell the agent no matching customers were found for this period. "
            "Do not ask them to select a customer on the draft order for this list question."
        )
        return "\n".join(lines)

    lines.append(f"Customers ({len(rows)}):")
    for idx, row in enumerate(rows, start=1):
        code = _as_text(row.get("cust_code")) or "—"
        name = _as_text(row.get("cust_name")) or "—"
        route_name = _as_text(row.get("routename") or row.get("route")) or "—"
        bills = _as_text(row.get("bill_count")) or "—"
        total_amt = _format_ai_money(row.get("total_amount"))
        last_date = _format_ai_date(row.get("last_bill_date"))
        last_amt = _format_ai_money(row.get("last_bill_amount"))
        mobile = _as_text(row.get("mobile")) or "—"
        lines.append(
            f"  {idx}. {code} — {name} | route {route_name} | "
            f"bills={bills} | total={total_amt} QAR | "
            f"last={last_date} {last_amt} QAR | mobile {mobile}"
        )
        items = (product_map or {}).get(str(row.get("cust_code") or "").strip()) or []
        if items:
            item_bits = []
            for item in items[:8]:
                icode = _as_text(item.get("itemcode")) or ""
                iname = _as_text(item.get("itemname") or item.get("itemdetails")) or ""
                qty = _as_text(item.get("quantity")) or ""
                label = f"{icode} {iname}".strip() or "item"
                item_bits.append(f"{label} x{qty}" if qty else label)
            lines.append(f"     Latest bill products: {'; '.join(item_bits)}")

    lines.append(
        "Answer using this customer list. "
        "Do NOT ask the agent to select a customer on the draft order for this question."
    )
    return "\n".join(lines)


def _load_customer_directory_list(
    message: str,
    *,
    route: str = "",
) -> str:
    limit = _parse_list_limit(message, default=5)
    rank_by_amount = bool(_AMOUNT_RANK_INTENT.search(message or ""))
    include_products = bool(_PRODUCT_LIST_INTENT.search(message or ""))
    # Amount/product ranking questions should include single-bill buyers too.
    if rank_by_amount:
        min_bills = 1
    elif _REPEAT_MODE_INTENT.search(message or ""):
        min_bills = 2
    else:
        min_bills = 1
    days = 90
    route = str(route or "").strip()
    route_bind = route if route.isdigit() else ""
    order_by = "amount" if rank_by_amount else "bills"

    cache_key = (
        f"ai:cust-dir:v2:{days}:{min_bills}:{limit}:{order_by}:"
        f"{'prod' if include_products else 'noprod'}:{route_bind or 'all'}"
    )
    cached = cache_get(cache_key)
    if isinstance(cached, str) and cached:
        return cached

    try:
        customers_view = current_app.config["ORACLE_CUSTOMERS_VIEW"]
        billhdr = current_app.config["ORACLE_BILLHDR_TABLE"]
        billdtl = current_app.config["ORACLE_BILLDTL_TABLE"]
        itemmaster = current_app.config["ORACLE_ITEMMASTER_TABLE"]
        rows = _fetch_repeat_customers(
            customers_view,
            billhdr,
            days=days,
            min_bills=min_bills,
            limit=limit,
            route=route_bind,
            order_by=order_by,
        )

        product_map: dict[str, list[dict]] = {}
        if include_products:
            for row in rows[:5]:
                code = str(row.get("cust_code") or "").strip()
                billno = str(row.get("last_billno") or "").strip()
                location = str(row.get("last_location") or "").strip()
                if not code or not billno:
                    continue
                product_map[code] = _fetch_bill_items_fast(
                    billdtl,
                    itemmaster,
                    billno=billno,
                    location=location,
                    offset=0,
                    limit=8,
                    own_only=False,
                )

        block = _format_customer_directory_block(
            rows=rows,
            limit=limit,
            days=days,
            min_bills=min_bills,
            route=route_bind,
            order_by=order_by,
            product_map=product_map or None,
        )
        cache_set(cache_key, block, ttl_seconds=_CUSTOMER_LIST_CACHE_TTL)
        return block
    except Exception:  # noqa: BLE001
        logger.exception("Failed loading customer directory list for AI")
        return (
            "Customer list is temporarily unavailable. "
            "Ask the agent to try again in a moment."
        )


def _format_purchase_history_block(
    *,
    cust_code: str,
    bills: list[dict],
    latest_items: list[dict],
    prior_items: list[dict] | None = None,
    deep: bool = False,
) -> str:
    lines = [
        f"Purchase history summary for customer code {cust_code}:",
    ]
    if not bills:
        lines.append("No prior bills found for this customer.")
        return "\n".join(lines)

    amounts = [_as_number(b.get("netbillamount")) for b in bills]
    amounts_ok = [a for a in amounts if a is not None]
    total = sum(amounts_ok) if amounts_ok else None
    avg = (total / len(amounts_ok)) if amounts_ok else None

    lines.append(
        f"Recent bills shown: {len(bills)}"
        + (f" | sum={_format_ai_money(total)} QAR" if total is not None else "")
        + (f" | avg={_format_ai_money(avg)} QAR" if avg is not None else "")
        + (" | detailed history" if deep else "")
    )
    lines.append("Bills (newest first):")
    for idx, bill in enumerate(bills, start=1):
        lines.append(
            f"  {idx}. Bill {_as_text(bill.get('billno')) or '—'} "
            f"@ loc {_as_text(bill.get('locationcode')) or '—'} "
            f"on {_format_ai_date(bill.get('billdate'))} — "
            f"{_format_ai_money(bill.get('netbillamount'))} QAR"
        )

    def _append_items(title: str, items: list[dict]) -> None:
        if not items:
            lines.append(f"{title}: none listed")
            return
        lines.append(title + ":")
        for i, item in enumerate(items, start=1):
            code = _as_text(item.get("itemcode")) or "—"
            name = _as_text(item.get("itemname") or item.get("itemdetails")) or ""
            qty = _as_text(item.get("quantity")) or "—"
            rate = _format_ai_money(item.get("rate"))
            own = " OWN" if item.get("ownproduct") else ""
            label = f"{code} {name}".strip()
            lines.append(f"  {i}. {label} | qty={qty} rate={rate}{own}")

    _append_items("Latest bill line items", latest_items)
    if prior_items is not None:
        _append_items("Previous bill line items", prior_items)

    lines.append(
        "Use this purchase history for questions about previous purchases, last bill, "
        "what the customer usually buys, and comparisons to the draft order."
    )
    return "\n".join(lines)


def _load_customer_purchase_history(cust_code: str, *, deep: bool = False) -> str:
    code = str(cust_code or "").strip()
    if not code:
        return "Customer purchase history: no customer selected."

    cache_key = f"ai:cust-history:v1:{code}:{'deep' if deep else 'light'}"
    cached = cache_get(cache_key)
    if isinstance(cached, str) and cached:
        return cached

    bill_limit = _HISTORY_BILLS_DEEP if deep else _HISTORY_BILLS_LIGHT
    item_limit = _HISTORY_ITEMS_DEEP if deep else _HISTORY_ITEMS_LIGHT

    try:
        billhdr = current_app.config["ORACLE_BILLHDR_TABLE"]
        billdtl = current_app.config["ORACLE_BILLDTL_TABLE"]
        itemmaster = current_app.config["ORACLE_ITEMMASTER_TABLE"]

        bills = _fetch_bill_history_rows(billhdr, code, limit=bill_limit)
        latest_items: list[dict] = []
        prior_items: list[dict] | None = None

        if bills:
            latest = bills[0]
            billno = str(latest.get("billno") or "").strip()
            location = str(latest.get("locationcode") or "").strip()
            if billno:
                latest_items = _fetch_bill_items_fast(
                    billdtl,
                    itemmaster,
                    billno=billno,
                    location=location,
                    offset=0,
                    limit=item_limit,
                    own_only=False,
                )
            if deep and len(bills) > 1:
                prior = bills[1]
                prior_no = str(prior.get("billno") or "").strip()
                prior_loc = str(prior.get("locationcode") or "").strip()
                if prior_no:
                    prior_items = _fetch_bill_items_fast(
                        billdtl,
                        itemmaster,
                        billno=prior_no,
                        location=prior_loc,
                        offset=0,
                        limit=min(15, item_limit),
                        own_only=False,
                    )

        block = _format_purchase_history_block(
            cust_code=code,
            bills=bills,
            latest_items=latest_items,
            prior_items=prior_items,
            deep=deep,
        )
        cache_set(cache_key, block, ttl_seconds=_HISTORY_CACHE_TTL)
        return block
    except Exception:  # noqa: BLE001
        logger.exception("Failed loading purchase history for AI (cust=%s)", code)
        return (
            f"Purchase history for customer {code} is temporarily unavailable. "
            "Ask the agent to try again in a moment."
        )


def _build_context_block(context: dict | None) -> str:
    if not isinstance(context, dict) or not context:
        return "No order context provided."

    customer = context.get("customer") if isinstance(context.get("customer"), dict) else {}
    salesman = context.get("salesman") if isinstance(context.get("salesman"), dict) else {}
    totals = context.get("totals") if isinstance(context.get("totals"), dict) else {}
    lines = context.get("lines") if isinstance(context.get("lines"), list) else []

    parts = [
        f"Invoice: {_as_text(context.get('invoiceNo')) or '—'}",
        f"Status: {_as_text(context.get('invoiceStatus')) or 'DRAFT'}",
        f"Type: {_as_text(context.get('invoiceType')) or '—'}",
        f"Channel: {_as_text(context.get('saleChannel')) or '—'}",
        f"Price type: {_as_text(context.get('priceType')) or '—'}",
        f"Customer: {_as_text(customer.get('name')) or 'not selected'}"
        f" (code {_as_text(customer.get('code')) or '—'})",
        f"Route: {_as_text(customer.get('route')) or '—'}",
        f"Mobile: {_as_text(customer.get('mobile')) or '—'}",
        f"Credit limit: {_as_text(customer.get('creditLimit')) or '—'}",
        f"Due / credit amount: {_as_text(customer.get('creditAmount')) or '—'}",
        f"Last purchase: {_as_text(customer.get('lastPurchaseDate')) or '—'}"
        f" / {_as_text(customer.get('lastPurchaseAmount')) or '—'}",
        f"Salesman: {_as_text(salesman.get('name')) or '—'}"
        f" ({_as_text(salesman.get('code')) or '—'})",
    ]

    if lines:
        parts.append(f"Line items ({min(len(lines), _MAX_LINES_IN_CONTEXT)} shown):")
        for idx, line in enumerate(lines[:_MAX_LINES_IN_CONTEXT], start=1):
            if not isinstance(line, dict):
                continue
            parts.append(
                f"  {idx}. {_as_text(line.get('itemCode'))} "
                f"{_as_text(line.get('description'))} | "
                f"qty={_as_text(line.get('qty'))} "
                f"uom={_as_text(line.get('uom'))} "
                f"rate={_as_text(line.get('rate'))} "
                f"disc={_as_text(line.get('discount'))} "
                f"amt={_as_text(line.get('amount'))}"
            )
        if len(lines) > _MAX_LINES_IN_CONTEXT:
            parts.append(f"  … +{len(lines) - _MAX_LINES_IN_CONTEXT} more lines")
    else:
        parts.append("Line items: none yet")

    parts.extend(
        [
            f"Order discount: {_as_text(totals.get('discount')) or '0'}",
            f"Net total: {_as_text(totals.get('netTotal')) or '0'}",
            f"VAT: {_as_text(totals.get('vatAmount')) or '0'}",
            f"Sugar tax: {_as_text(totals.get('sugarTax')) or '0'}",
            f"Grand total (incl. VAT & sugar tax): {_as_text(totals.get('grandTotal')) or '0'} QAR",
        ]
    )
    return "\n".join(parts)


def _normalize_history(raw) -> list[dict[str, str]]:
    if not isinstance(raw, list):
        return []
    out: list[dict[str, str]] = []
    for item in raw[-_MAX_HISTORY:]:
        if not isinstance(item, dict):
            continue
        role = str(item.get("role") or "").strip().lower()
        content = _as_text(item.get("content") or item.get("text"), max_len=_MAX_MESSAGE_LEN)
        if role not in ("user", "assistant") or not content:
            continue
        out.append({"role": role, "content": content})
    return out


@ai_bp.get("/status")
def ai_status():
    """Public probe — confirms AI blueprint is loaded (no secrets)."""
    configured = bool(str(current_app.config.get("GROQ_API_KEY") or "").strip())
    model = str(
        current_app.config.get("GROQ_MODEL") or "llama-3.3-70b-versatile"
    ).strip()
    return jsonify(
        {
            "status": "ok" if configured else "unconfigured",
            "configured": configured,
            "model": model if configured else None,
        }
    )


@ai_bp.post("/chat")
@limiter.limit("30 per minute")
def ai_chat():
    api_key = str(current_app.config.get("GROQ_API_KEY") or "").strip()
    if not api_key:
        return jsonify({"error": "AI assistant is not configured (GROQ_API_KEY)"}), 503

    payload = request.get_json(silent=True) or {}
    message = _as_text(payload.get("message"), max_len=_MAX_MESSAGE_LEN)
    if not message:
        return jsonify({"error": "message is required"}), 400

    history = _normalize_history(payload.get("messages") or payload.get("history"))
    context = payload.get("context") if isinstance(payload.get("context"), dict) else {}
    selected_language = _normalize_language(
        payload.get("language") or payload.get("locale")
    )
    language = _resolve_language(selected=selected_language, message=message)

    customer = context.get("customer") if isinstance(context.get("customer"), dict) else {}
    cust_code = _as_text(customer.get("code"), max_len=64)
    route_hint = _as_text(customer.get("route"), max_len=64)
    deep_history = _wants_purchase_history(message)
    wants_directory = _wants_customer_list(message)

    purchase_history_block = ""
    if cust_code:
        purchase_history_block = _load_customer_purchase_history(
            cust_code, deep=deep_history
        )

    directory_block = ""
    if wants_directory:
        directory_block = _load_customer_directory_list(
            message, route=route_hint
        )

    model = str(
        current_app.config.get("GROQ_MODEL") or "llama-3.3-70b-versatile"
    ).strip()
    timeout = float(current_app.config.get("GROQ_TIMEOUT_SECONDS") or 45)

    system_messages = [
        {"role": "system", "content": _SYSTEM_PROMPT},
        {
            "role": "system",
            "content": "Current order context:\n" + _build_context_block(context),
        },
    ]
    if purchase_history_block:
        system_messages.append(
            {"role": "system", "content": purchase_history_block}
        )
    if directory_block:
        system_messages.append({"role": "system", "content": directory_block})

    messages = [
        *system_messages,
        *history,
        {"role": "system", "content": _LANGUAGE_INSTRUCTIONS[language]},
        {"role": "system", "content": _language_reminder(language)},
        {"role": "user", "content": _wrap_user_message(message, language)},
    ]

    try:
        reply = chat_completion(
            api_key=api_key,
            model=model,
            messages=messages,
            timeout_seconds=timeout,
            temperature=0.2,
            max_tokens=1000 if (deep_history or wants_directory) else 700,
        )
    except GroqError as exc:
        status = exc.status_code or 502
        return jsonify({"error": str(exc)}), status

    return jsonify(
        {
            "reply": reply,
            "model": model,
            "language": language,
            "languageSelected": selected_language,
            "historyLoaded": bool(purchase_history_block),
            "historyDeep": bool(cust_code and deep_history),
            "directoryLoaded": bool(directory_block),
        }
    )
