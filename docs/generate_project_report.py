"""
CRGS / REX APP — Project Presentation Report PDF generator.
"""

from __future__ import annotations

from datetime import datetime
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT, TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    KeepTogether,
    ListFlowable,
    ListItem,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
    HRFlowable,
)

OUTPUT = Path(__file__).resolve().parent / "CRGS_Project_Report.pdf"

# Brand palette (teal — matches app/web)
TEAL = colors.HexColor("#0F766E")
TEAL_DARK = colors.HexColor("#0A4F4A")
TEAL_LIGHT = colors.HexColor("#E6F4F2")
ORANGE = colors.HexColor("#EA580C")
SLATE = colors.HexColor("#334155")
MUTED = colors.HexColor("#64748B")
LINE = colors.HexColor("#CBD5E1")
WHITE = colors.white
BG_ROW = colors.HexColor("#F8FAFC")


def build_styles():
    base = getSampleStyleSheet()

    styles = {
        "cover_title": ParagraphStyle(
            "cover_title",
            parent=base["Title"],
            fontName="Helvetica-Bold",
            fontSize=28,
            leading=34,
            textColor=WHITE,
            alignment=TA_CENTER,
            spaceAfter=8,
        ),
        "cover_sub": ParagraphStyle(
            "cover_sub",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=13,
            leading=18,
            textColor=colors.HexColor("#D1FAE5"),
            alignment=TA_CENTER,
            spaceAfter=6,
        ),
        "cover_meta": ParagraphStyle(
            "cover_meta",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=10,
            leading=14,
            textColor=colors.HexColor("#A7F3D0"),
            alignment=TA_CENTER,
        ),
        "h1": ParagraphStyle(
            "h1",
            parent=base["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=16,
            leading=20,
            textColor=TEAL_DARK,
            spaceBefore=4,
            spaceAfter=10,
        ),
        "h2": ParagraphStyle(
            "h2",
            parent=base["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=12.5,
            leading=16,
            textColor=TEAL,
            spaceBefore=12,
            spaceAfter=6,
        ),
        "h3": ParagraphStyle(
            "h3",
            parent=base["Heading3"],
            fontName="Helvetica-Bold",
            fontSize=11,
            leading=14,
            textColor=SLATE,
            spaceBefore=8,
            spaceAfter=4,
        ),
        "body": ParagraphStyle(
            "body",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=9.5,
            leading=13.5,
            textColor=SLATE,
            alignment=TA_JUSTIFY,
            spaceAfter=6,
        ),
        "body_left": ParagraphStyle(
            "body_left",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=9.5,
            leading=13.5,
            textColor=SLATE,
            alignment=TA_LEFT,
            spaceAfter=4,
        ),
        "bullet": ParagraphStyle(
            "bullet",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=9.2,
            leading=12.5,
            textColor=SLATE,
            leftIndent=4,
        ),
        "toc": ParagraphStyle(
            "toc",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=10.5,
            leading=18,
            textColor=SLATE,
        ),
        "caption": ParagraphStyle(
            "caption",
            parent=base["Normal"],
            fontName="Helvetica-Oblique",
            fontSize=8,
            leading=10,
            textColor=MUTED,
            alignment=TA_CENTER,
            spaceBefore=2,
            spaceAfter=8,
        ),
        "footer": ParagraphStyle(
            "footer",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=8,
            textColor=MUTED,
        ),
        "table_cell": ParagraphStyle(
            "table_cell",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=8.5,
            leading=11,
            textColor=SLATE,
        ),
        "table_header": ParagraphStyle(
            "table_header",
            parent=base["Normal"],
            fontName="Helvetica-Bold",
            fontSize=8.5,
            leading=11,
            textColor=WHITE,
        ),
        "callout": ParagraphStyle(
            "callout",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=9.5,
            leading=13,
            textColor=TEAL_DARK,
            alignment=TA_LEFT,
        ),
        "section_num": ParagraphStyle(
            "section_num",
            parent=base["Normal"],
            fontName="Helvetica-Bold",
            fontSize=9,
            textColor=ORANGE,
            spaceAfter=2,
        ),
    }
    return styles


def p(text: str, style) -> Paragraph:
    return Paragraph(text, style)


def bullets(items: list[str], styles) -> ListFlowable:
    return ListFlowable(
        [ListItem(Paragraph(i, styles["bullet"]), leftIndent=12, bulletColor=TEAL) for i in items],
        bulletType="bullet",
        start="•",
        leftIndent=15,
        bulletFontSize=8,
        spaceBefore=2,
        spaceAfter=8,
    )


def make_table(headers: list[str], rows: list[list[str]], styles, col_widths=None) -> Table:
    header_row = [Paragraph(h, styles["table_header"]) for h in headers]
    data = [header_row]
    for row in rows:
        data.append([Paragraph(str(c), styles["table_cell"]) for c in row])

    t = Table(data, colWidths=col_widths, repeatRows=1)
    style_cmds = [
        ("BACKGROUND", (0, 0), (-1, 0), TEAL),
        ("TEXTCOLOR", (0, 0), (-1, 0), WHITE),
        ("ALIGN", (0, 0), (-1, 0), "LEFT"),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("GRID", (0, 0), (-1, -1), 0.4, LINE),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [WHITE, BG_ROW]),
    ]
    t.setStyle(TableStyle(style_cmds))
    return t


def hr():
    return HRFlowable(width="100%", thickness=1, color=LINE, spaceBefore=2, spaceAfter=10)


def add_header_footer(canvas, doc):
    canvas.saveState()
    page = doc.page
    if page > 1:
        # Header bar
        canvas.setFillColor(TEAL)
        canvas.rect(0, A4[1] - 14 * mm, A4[0], 14 * mm, fill=1, stroke=0)
        canvas.setFillColor(WHITE)
        canvas.setFont("Helvetica-Bold", 8)
        canvas.drawString(18 * mm, A4[1] - 8.5 * mm, "CRGS — Customer Recovery & Growth System")
        canvas.setFont("Helvetica", 8)
        canvas.drawRightString(A4[0] - 18 * mm, A4[1] - 8.5 * mm, "Project Presentation Report")

        # Footer
        canvas.setStrokeColor(LINE)
        canvas.setLineWidth(0.5)
        canvas.line(18 * mm, 14 * mm, A4[0] - 18 * mm, 14 * mm)
        canvas.setFillColor(MUTED)
        canvas.setFont("Helvetica", 8)
        canvas.drawString(18 * mm, 8 * mm, "Web Portal + REX Mobile App  |  Confidential")
        canvas.drawRightString(A4[0] - 18 * mm, 8 * mm, f"Page {page}")
    canvas.restoreState()


def cover_page(styles, story):
    # Full-bleed feel via spacer + colored table
    cover_data = [[
        Paragraph("<br/><br/>", styles["cover_title"]),
    ]]
    # Use a tall colored block
    block = Table(
        [[
            Paragraph("CRGS", styles["cover_title"]),
        ], [
            Paragraph("Customer Recovery &amp; Growth System", styles["cover_sub"]),
        ], [
            Paragraph("Project Presentation Report", styles["cover_title"]),
        ], [
            Paragraph(
                "Web Admin Portal  •  REX Field Sales Mobile App  •  Flask / Oracle API",
                styles["cover_sub"],
            ),
        ], [
            Spacer(1, 18),
        ], [
            Paragraph(
                f"Prepared for stakeholder presentation<br/>{datetime.now().strftime('%B %Y')}<br/>Version 1.0",
                styles["cover_meta"],
            ),
        ]],
        colWidths=[170 * mm],
    )
    block.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), TEAL_DARK),
                ("ALIGN", (0, 0), (-1, -1), "CENTER"),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("TOPPADDING", (0, 0), (-1, -1), 10),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
                ("LEFTPADDING", (0, 0), (-1, -1), 20),
                ("RIGHTPADDING", (0, 0), (-1, -1), 20),
                ("BOX", (0, 0), (-1, -1), 0, TEAL_DARK),
            ]
        )
    )
    story.append(Spacer(1, 35 * mm))
    story.append(block)
    story.append(Spacer(1, 20 * mm))

    summary = Table(
        [[
            Paragraph(
                "<b>Platform summary</b><br/>"
                "CRGS connects sales managers (web) and field executives (mobile) "
                "through a shared Flask API on Oracle ERP data — enabling route execution, "
                "customer recovery, target tracking, visit capture, and growth campaigns.",
                styles["callout"],
            )
        ]],
        colWidths=[170 * mm],
    )
    summary.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), TEAL_LIGHT),
                ("BOX", (0, 0), (-1, -1), 1, TEAL),
                ("LEFTPADDING", (0, 0), (-1, -1), 12),
                ("RIGHTPADDING", (0, 0), (-1, -1), 12),
                ("TOPPADDING", (0, 0), (-1, -1), 10),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
            ]
        )
    )
    story.append(summary)
    story.append(PageBreak())


def toc_page(styles, story):
    story.append(p("01  CONTENTS", styles["section_num"]))
    story.append(p("Table of Contents", styles["h1"]))
    story.append(hr())
    items = [
        "1. Executive Summary",
        "2. Problem Statement &amp; Business Objectives",
        "3. Solution Overview — CRGS &amp; REX APP",
        "4. System Architecture",
        "5. Technology Stack",
        "6. Web Admin Portal — Modules &amp; Features",
        "7. REX Mobile App — Modules &amp; Features",
        "8. Backend API &amp; Data Layer",
        "9. Domain Model &amp; User Roles",
        "10. End-to-End Operational Flow",
        "11. UX / UI Design Principles",
        "12. Integration Map (Web ↔ Mobile ↔ Oracle)",
        "13. Current Maturity &amp; Roadmap Notes",
        "14. Demo Script for Presentation",
        "15. Conclusion",
    ]
    for item in items:
        story.append(p(item, styles["toc"]))
    story.append(PageBreak())


def section_exec_summary(styles, story):
    story.append(p("01  EXECUTIVE SUMMARY", styles["section_num"]))
    story.append(p("1. Executive Summary", styles["h1"]))
    story.append(hr())
    story.append(
        p(
            "The <b>Customer Recovery &amp; Growth System (CRGS)</b> is a field-force operations "
            "platform designed for sales organizations that sell through named routes and customer accounts. "
            "It addresses three persistent operational gaps: loss of inactive (“missing”) customers, "
            "weak visibility of field execution against targets, and fragmented coordination between "
            "office managers and executives on the road.",
            styles["body"],
        )
    )
    story.append(
        p(
            "The platform ships as two tightly coupled client applications over one shared backend:",
            styles["body"],
        )
    )
    story.append(
        bullets(
            [
                "<b>CRGS Admin Web Portal</b> — for sales managers: user management, route assignment, "
                "multi-dimensional targets, task campaigns, dashboards, and reports.",
                "<b>REX APP (Mobile)</b> — for sales executives: route execution, customer triage "
                "(missing / outstanding), GPS-backed visits, product introduction, expected orders, "
                "tasks, and personal performance views.",
                "<b>Flask REST API + Oracle DB</b> — authenticates users, exposes ERP-backed customers "
                "and items, and persists CRGS operational tables (targets, tasks, visits, orders).",
            ],
            styles,
        )
    )
    story.append(
        p(
            "Together, these components close the loop from <b>plan → assign → execute → measure</b>, "
            "giving managers control from the office and executives a guided workflow in the field.",
            styles["body"],
        )
    )
    story.append(PageBreak())


def section_problem(styles, story):
    story.append(p("02  PROBLEM &amp; OBJECTIVES", styles["section_num"]))
    story.append(p("2. Problem Statement &amp; Business Objectives", styles["h1"]))
    story.append(hr())

    story.append(p("2.1 Challenges in traditional route sales", styles["h2"]))
    story.append(
        bullets(
            [
                "Customers stop purchasing without a structured recovery process (product issues, competitor switch, credit holds).",
                "Managers lack a single view of executive load, route coverage, and target achievement.",
                "Field visits and expected orders are captured inconsistently or on paper/spreadsheets.",
                "Outstanding collections and follow-ups are hard to prioritize during a busy route day.",
                "Campaign work (new products, replacements, market research) is assigned verbally and not tracked.",
            ],
            styles,
        )
    )

    story.append(p("2.2 Business objectives", styles["h2"]))
    story.append(
        make_table(
            ["Objective", "How CRGS delivers"],
            [
                ["Recover missing customers", "Missing filters (7–60 days), recovery forms, follow-up tasks"],
                ["Grow revenue", "Sales / product / customer targets + product introduction flows"],
                ["Improve route discipline", "Assigned routes, visit start/end with GPS &amp; duration"],
                ["Manager visibility", "Live dashboard KPIs, task overdue counts, multi-tab reports"],
                ["Field productivity", "Mobile-first triage (All / Missing / Outstanding) + maps"],
                ["Unify office &amp; field", "Shared Oracle data via one API for both clients"],
            ],
            styles,
            col_widths=[55 * mm, 115 * mm],
        )
    )
    story.append(PageBreak())


def section_solution(styles, story):
    story.append(p("03  SOLUTION OVERVIEW", styles["section_num"]))
    story.append(p("3. Solution Overview — CRGS &amp; REX APP", styles["h1"]))
    story.append(hr())

    story.append(
        make_table(
            ["Product", "Audience", "Primary job"],
            [
                [
                    "CRGS Admin Portal",
                    "Sales Manager / Admin",
                    "Plan workforce: create executives, assign routes, set targets &amp; tasks, monitor performance",
                ],
                [
                    "REX APP",
                    "Sales Executive",
                    "Execute routes: visit customers, recover accounts, introduce products, capture orders",
                ],
                [
                    "crgs-admin-api",
                    "Shared service",
                    "Secure REST access to Oracle RFSS/rgc ERP views and CRGS_* operational tables",
                ],
            ],
            styles,
            col_widths=[40 * mm, 40 * mm, 90 * mm],
        )
    )
    story.append(Spacer(1, 8))

    story.append(p("3.1 Naming &amp; branding", styles["h2"]))
    story.append(
        bullets(
            [
                "<b>CRGS</b> = Customer Recovery &amp; Growth System (portal tagline on Login &amp; Layout).",
                "<b>REX APP</b> = mobile companion branded as a Field Sales Platform (pubspec / app constants).",
                "Shared brand color: teal <b>#0F766E</b> with orange accent for primary mobile CTAs.",
            ],
            styles,
        )
    )

    story.append(p("3.2 Core domain themes", styles["h2"]))
    story.append(
        bullets(
            [
                "<b>Customer recovery</b> — identify and act on inactive / missing accounts.",
                "<b>Growth</b> — new acquisition, product introduction, replacement campaigns.",
                "<b>Route execution</b> — day-level discipline with GPS-backed visit records.",
                "<b>Targets vs achievement</b> — sales amount, product volume/qty, customer KPIs.",
                "<b>Field intelligence</b> — market research, follow-ups, outstanding collection.",
            ],
            styles,
        )
    )
    story.append(PageBreak())


def section_architecture(styles, story):
    story.append(p("04  ARCHITECTURE", styles["section_num"]))
    story.append(p("4. System Architecture", styles["h1"]))
    story.append(hr())

    story.append(
        p(
            "CRGS follows a classic three-tier client–API–database architecture. Both the web portal "
            "and the mobile app are thin clients that call the same Flask service. The service reads "
            "and writes Oracle tables used by the wider ERP (customers, bills, items, routes) and "
            "dedicated CRGS operational tables.",
            styles["body"],
        )
    )

    arch = Table(
        [
            [Paragraph("<b>CRGS Admin (Web)</b><br/>React 19 + Vite 8<br/>Port 5173 → /api proxy", styles["table_cell"]),
             Paragraph("<b>REX APP (Mobile)</b><br/>Flutter + Riverpod<br/>Dio → /api", styles["table_cell"])],
            [Paragraph("<b>Flask API — crgs-admin-api</b><br/>:5000  •  /api/*  •  CORS enabled", styles["table_cell"]),
             ""],
            [Paragraph("<b>Oracle Database (RFSS / rgc)</b><br/>ERP views + CRGS_* tables  •  Connection pool min=1 max=4", styles["table_cell"]),
             ""],
        ],
        colWidths=[85 * mm, 85 * mm],
    )
    arch.setStyle(
        TableStyle(
            [
                ("SPAN", (0, 1), (1, 1)),
                ("SPAN", (0, 2), (1, 2)),
                ("BACKGROUND", (0, 0), (0, 0), TEAL_LIGHT),
                ("BACKGROUND", (1, 0), (1, 0), colors.HexColor("#FFF7ED")),
                ("BACKGROUND", (0, 1), (-1, 1), colors.HexColor("#ECFDF5")),
                ("BACKGROUND", (0, 2), (-1, 2), colors.HexColor("#F1F5F9")),
                ("BOX", (0, 0), (-1, -1), 1, TEAL),
                ("INNERGRID", (0, 0), (-1, -1), 0.5, LINE),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("ALIGN", (0, 0), (-1, -1), "CENTER"),
                ("TOPPADDING", (0, 0), (-1, -1), 12),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 12),
                ("LEFTPADDING", (0, 0), (-1, -1), 8),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
            ]
        )
    )
    story.append(arch)
    story.append(p("Figure 1 — High-level system architecture", styles["caption"]))

    story.append(p("4.1 Deployment topology (typical LAN)", styles["h2"]))
    story.append(
        bullets(
            [
                "API host example: <b>http://192.168.61.41:5000</b>",
                "Web Vite proxy: <b>/api → API host</b> (vite.config.ts)",
                "Mobile API base: <b>http://192.168.61.41:5000/api</b> (overridable via --dart-define=API_BASE_URL)",
                "Oracle DSN (config default): host/service for RFSS schema on rgc",
            ],
            styles,
        )
    )
    story.append(PageBreak())


def section_stack(styles, story):
    story.append(p("05  TECHNOLOGY STACK", styles["section_num"]))
    story.append(p("5. Technology Stack", styles["h1"]))
    story.append(hr())

    story.append(p("5.1 Web Admin Portal", styles["h2"]))
    story.append(
        make_table(
            ["Technology", "Version / note"],
            [
                ["React / React DOM", "^19.2.7"],
                ["TypeScript", "~6.0.2"],
                ["Vite", "^8.1.0"],
                ["React Router DOM", "^7.18.0"],
                ["Tailwind CSS (+ Vite plugin)", "^4.3.1"],
                ["Recharts", "^3.9.0 — dashboards &amp; reports"],
                ["Framer Motion", "^12.42.2"],
                ["Lucide React + Radix Slot / CVA", "Iconography &amp; shadcn-style UI"],
                ["Oxlint", "^1.69.0"],
            ],
            styles,
            col_widths=[70 * mm, 100 * mm],
        )
    )

    story.append(p("5.2 REX Mobile App (Flutter)", styles["h2"]))
    story.append(
        make_table(
            ["Technology", "Version / note"],
            [
                ["Package", "crgs 1.0.0+1 — “REX APP — Mobile app for sales executives”"],
                ["Dart SDK", "^3.12.2"],
                ["flutter_riverpod", "^2.6.1 — state management"],
                ["go_router", "^14.8.1 — navigation"],
                ["dio", "^5.8.0+1 — HTTP client"],
                ["shadcn_ui", "^0.54.0"],
                ["flutter_map / latlong2 / geolocator / geocoding", "Maps &amp; GPS"],
                ["fl_chart", "^0.70.2 — charts"],
                ["connectivity_plus / shared_preferences / lottie", "Offline banner, session, visit timer"],
            ],
            styles,
            col_widths=[70 * mm, 100 * mm],
        )
    )

    story.append(p("5.3 Backend API", styles["h2"]))
    story.append(
        make_table(
            ["Package", "Version"],
            [
                ["Flask", "3.1.0"],
                ["Flask-CORS", "5.0.1"],
                ["oracledb", "4.0.1"],
                ["python-dotenv", "1.0.1"],
            ],
            styles,
            col_widths=[70 * mm, 100 * mm],
        )
    )
    story.append(PageBreak())


def section_web(styles, story):
    story.append(p("06  WEB ADMIN PORTAL", styles["section_num"]))
    story.append(p("6. Web Admin Portal — Modules &amp; Features", styles["h1"]))
    story.append(hr())

    story.append(
        p(
            "The portal is a React SPA under <b>frontend/</b>. Routes are protected by "
            "<b>ProtectedRoute</b> + <b>AuthContext</b> (session stored in localStorage as "
            "<b>crgs-admin-session</b>). Navigation: Dashboard, User Management, Route Management, "
            "Target Management, Task Management, Reports.",
            styles["body"],
        )
    )

    story.append(p("6.1 Authentication", styles["h2"]))
    story.append(
        bullets(
            [
                "Login with <b>Employee Code</b> + <b>Password</b> via POST /api/auth/login.",
                "Branding: “CRGS Admin / Sales Manager Portal” and full CRGS expansion.",
                "Portal session role set as <b>admin</b> for manager users.",
            ],
            styles,
        )
    )

    story.append(p("6.2 Dashboard", styles["h2"]))
    story.append(
        bullets(
            [
                "Live KPIs: active executives, assigned routes, monthly sales/product/customer target achievement %.",
                "Overdue task count.",
                "Charts: executive performance (bar), route performance, task-type distribution (pie).",
                "Recent tasks table — fed by /api/users, /api/targets/*, /api/tasks.",
            ],
            styles,
        )
    )

    story.append(p("6.3 User Management", styles["h2"]))
    story.append(
        bullets(
            [
                "Lists sales executives from CRGS_USER where ROLECODE = 3.",
                "Create user (username, employee code, password).",
                "Activate / deactivate (FLAG A/D).",
                "Assign multiple routes (comma-separated ROUTE column) via modal multi-select.",
            ],
            styles,
        )
    )

    story.append(p("6.4 Route Management", styles["h2"]))
    story.append(
        bullets(
            [
                "Loads route master from TBLROUTES (/api/routes).",
                "Select executive → multi-select routes → PATCH /api/users/routes.",
                "Search by route name / number.",
            ],
            styles,
        )
    )

    story.append(p("6.5 Target Management (3 tabs)", styles["h2"]))
    story.append(
        make_table(
            ["Tab", "Table", "What managers configure"],
            [
                [
                    "Sales targets",
                    "CRGS_SALETARGET",
                    "Amount, period (daily/weekly/monthly), routes, due date",
                ],
                [
                    "Product targets",
                    "CRGS_PRODUCTTARGET",
                    "quantity, volume, new_promotion, replacement, own_products — multi-product picker",
                ],
                [
                    "Customer targets",
                    "CRGS_CUSTOMERTARGET",
                    "new_acquisition, missing_recovery, outstanding_collection, purchase_limit",
                ],
            ],
            styles,
            col_widths=[40 * mm, 45 * mm, 85 * mm],
        )
    )

    story.append(p("6.6 Task Management", styles["h2"]))
    story.append(
        p("Campaign-style tasks assigned to executives (CRGS_TASK):", styles["body_left"])
    )
    story.append(
        bullets(
            [
                "Missing Customer Follow-up",
                "Outstanding Collection Follow-up",
                "New Product Introduction",
                "Product Replacement Campaign",
                "Customer Visit Campaign",
                "Own Products",
                "Market Research",
            ],
            styles,
        )
    )
    story.append(p("Filter by type; create and delete via /api/tasks.", styles["body_left"]))

    story.append(p("6.7 Reports (8 tabs)", styles["h2"]))
    story.append(
        bullets(
            [
                "Executive Performance",
                "Route Performance",
                "Customer Recovery",
                "New Customer",
                "Product Sales",
                "Outstanding Collection",
                "Target vs Achievement",
                "Market Trend",
            ],
            styles,
        )
    )
    story.append(
        p(
            "Reports combine live target/user API data with richer analytical views "
            "(some market/recovery panels may use mock enrichment for presentation completeness).",
            styles["body"],
        )
    )

    story.append(p("6.8 Route map (web)", styles["h2"]))
    story.append(
        make_table(
            ["Path", "Page"],
            [
                ["/login", "LoginPage"],
                ["/", "DashboardPage"],
                ["/users", "UsersPage"],
                ["/routes", "RoutesPage"],
                ["/targets", "TargetsPage"],
                ["/tasks", "TasksPage"],
                ["/reports", "ReportsPage"],
            ],
            styles,
            col_widths=[50 * mm, 120 * mm],
        )
    )
    story.append(PageBreak())


def section_mobile(styles, story):
    story.append(p("07  REX MOBILE APP", styles["section_num"]))
    story.append(p("7. REX Mobile App — Modules &amp; Features", styles["h1"]))
    story.append(hr())

    story.append(
        p(
            "REX APP (package <b>crgs</b>) is the executive’s day-to-day tool. Navigation uses "
            "<b>go_router</b> with a soft-rounded sidebar shell. Unauthenticated users go to login; "
            "authenticated users with incomplete onboarding see a 3-slide onboarding flow that sets "
            "ONBOARD_FLAG via the API.",
            styles["body"],
        )
    )

    story.append(p("7.1 Shell navigation", styles["h2"]))
    story.append(
        make_table(
            ["Route", "Screen", "Purpose"],
            [
                ["/routes", "RouteListScreen", "Assigned routes (default home)"],
                ["/routes/:routeId", "CustomerListScreen", "Customers for a route"],
                ["/tasks", "TaskManagementScreen", "Assigned campaign tasks"],
                ["/orders", "OrdersScreen", "Expected orders list"],
                ["/dashboard", "DashboardScreen", "Personal KPIs &amp; today overview"],
                ["/profile", "ProfileScreen", "Identity, routes, theme, logout"],
                ["/reports", "ReportsScreen", "Personal charts summary"],
            ],
            styles,
            col_widths=[40 * mm, 50 * mm, 80 * mm],
        )
    )

    story.append(p("7.2 Field workflows (standalone)", styles["h2"]))
    story.append(
        make_table(
            ["Route", "Screen", "Purpose"],
            [
                ["/visit/:customerId", "VisitTrackingScreen", "GPS visit start/end + products"],
                ["/customers/:id", "CustomerDetailScreen", "Account detail &amp; history"],
                ["/recovery/:customerId", "RecoveryFormScreen", "Missing-customer recovery reasons"],
                ["/products/:customerId", "ProductIntroScreen", "Catalog / cart / expected order"],
                ["/outstanding", "OutstandingCollectionScreen", "Invoice collection workflow"],
                ["/follow-up", "FollowUpScreen", "Calendar + timeline follow-ups"],
                ["/market-research", "MarketResearchScreen", "Field intelligence capture"],
                ["/new-customer", "NewCustomerScreen", "New lead / prospect form"],
                ["/settings", "SettingsScreen", "Sync, GPS, notifications, offline"],
            ],
            styles,
            col_widths=[45 * mm, 50 * mm, 75 * mm],
        )
    )

    story.append(p("7.3 Customer triage", styles["h2"]))
    story.append(
        bullets(
            [
                "Tabs: <b>All / Missing / Outstanding</b> with search debounce and infinite scroll.",
                "Missing windows: 7 / 15 / 30 / 60 days / All (not billed today).",
                "Priority color coding: missing (red), outstanding (orange), follow-up (teal), regular (green).",
                "Detail sheets show purchase age, credit, last bills / line items from Oracle.",
            ],
            styles,
        )
    )

    story.append(p("7.4 Visit tracking (core field feature)", styles["h2"]))
    story.append(
        bullets(
            [
                "Auto start visit → POST /api/visits/start (CRGS_VISITDETAILS).",
                "GPS via LocationService + interactive map picker (flutter_map).",
                "Lottie-powered visit timer for presence/duration.",
                "Visit reason, remarks, follow-up date; ordered products section.",
                "End visit → POST /api/visits/end with duration and location.",
            ],
            styles,
        )
    )

    story.append(p("7.5 Orders &amp; product introduction", styles["h2"]))
    story.append(
        bullets(
            [
                "List expected orders from CRGS_ORDERHDR / ORDERDTL.",
                "Product intro: recommended / alternative products, cart, expected-order capture.",
                "Item master sourced from /api/items (ITEMMASTER).",
            ],
            styles,
        )
    )

    story.append(p("7.6 Dashboard &amp; supporting modules", styles["h2"]))
    story.append(
        bullets(
            [
                "Hero: monthly %, route performance, pending tasks; today’s target overview.",
                "Today’s route map, weekly chart, Up Next, quick actions; FAB for New Lead.",
                "Tasks: All / Route / Additional / Follow-up progress with status badges.",
                "Outstanding, recovery, market research, follow-ups, settings (theme, connectivity banner).",
            ],
            styles,
        )
    )
    story.append(PageBreak())


def section_backend(styles, story):
    story.append(p("08  BACKEND &amp; DATA", styles["section_num"]))
    story.append(p("8. Backend API &amp; Data Layer", styles["h1"]))
    story.append(hr())

    story.append(
        p(
            "Service id: <b>crgs-admin-api</b>. Factory in backend/app/__init__.py registers blueprints, "
            "CORS, Oracle pool, and health endpoints GET /api/health and GET /api/health/db.",
            styles["body"],
        )
    )

    story.append(p("8.1 API blueprints", styles["h2"]))
    story.append(
        make_table(
            ["Prefix", "Module", "Key endpoints"],
            [
                ["/api/auth", "auth.py", "POST /login, PATCH /onboarding"],
                ["/api/users", "users.py", "GET /, POST /, PATCH /routes, PATCH /status"],
                ["/api/routes", "routes_data.py", "GET / (search, pagination)"],
                ["/api/targets", "targets.py", "/sales, /products, /customers — GET/POST/DELETE"],
                ["/api/items", "items.py", "GET / ITEMMASTER"],
                ["/api/tasks", "tasks.py", "GET /, POST /, DELETE /"],
                ["/api/visits", "visits.py", "POST /start, POST /end"],
                ["/api/orders", "orders.py", "GET /, POST /"],
                ["/api/customers", "customers.py", "list, stats, last-purchase, last-order, bill-items"],
            ],
            styles,
            col_widths=[35 * mm, 35 * mm, 100 * mm],
        )
    )

    story.append(p("8.2 Oracle tables &amp; views", styles["h2"]))
    story.append(
        make_table(
            ["Entity", "Default object", "Use"],
            [
                ["Users / auth", "CRGS_USER", "Login, roles, routes, onboard flag"],
                ["Routes", "TBLROUTES", "Route master"],
                ["Customers", "CUSTOMERS + CUSTOMERAGEVIEW", "List, missing age"],
                ["Billing", "BILLHDR / BILLDTL", "Last purchase, line items"],
                ["Items", "ITEMMASTER", "Product catalog"],
                ["Sales targets", "CRGS_SALETARGET", "Sales KPIs"],
                ["Product targets", "CRGS_PRODUCTTARGET", "Product KPIs"],
                ["Customer targets", "CRGS_CUSTOMERTARGET", "Customer KPIs"],
                ["Tasks", "CRGS_TASK", "Field campaigns"],
                ["Visits", "CRGS_VISITDETAILS", "Visit start/end"],
                ["Orders", "CRGS_ORDERHDR / ORDERDTL", "Expected orders"],
            ],
            styles,
            col_widths=[40 * mm, 55 * mm, 75 * mm],
        )
    )
    story.append(
        p(
            "Missing-customer threshold defaults to <b>MISSING_DAYS = 30</b> (configurable). "
            "Customer API supports priority filters, pagination, and route-level stats.",
            styles["body"],
        )
    )
    story.append(PageBreak())


def section_domain(styles, story):
    story.append(p("09  DOMAIN &amp; ROLES", styles["section_num"]))
    story.append(p("9. Domain Model &amp; User Roles", styles["h1"]))
    story.append(hr())

    story.append(p("9.1 Key entities", styles["h2"]))
    story.append(
        bullets(
            [
                "<b>User / Executive</b> — employee code, routes, FLAG, ONBOARD_FLAG, roleCode.",
                "<b>Route</b> — code, area, assigned executive, customer count.",
                "<b>Customer</b> — GPS, credit, purchase age, priority (missing / outstanding / follow-up / regular).",
                "<b>Targets</b> — SalesTarget, ProductTarget, CustomerTarget with period &amp; achievement.",
                "<b>Task</b> — type, status, priority, assignment to employee/route.",
                "<b>Visit</b> — start/end timestamps, location, reason, ordered products.",
                "<b>Order</b> — header + line items (expected order capture).",
                "<b>Follow-up / Outstanding / Market Intel / Lead</b> — supporting field objects.",
            ],
            styles,
        )
    )

    story.append(p("9.2 User roles", styles["h2"]))
    story.append(
        make_table(
            ["Role", "Where", "Capabilities"],
            [
                [
                    "Admin / Sales Manager",
                    "Web portal (session role admin)",
                    "Manage users, routes, targets, tasks, dashboards, reports",
                ],
                [
                    "Sales Executive",
                    "Oracle ROLECODE = 3; REX APP",
                    "Execute assigned routes, visits, orders, tasks; view personal targets",
                ],
            ],
            styles,
            col_widths=[40 * mm, 50 * mm, 80 * mm],
        )
    )
    story.append(
        bullets(
            [
                "FLAG = <b>A</b> active, <b>D</b> inactive.",
                "ONBOARD_FLAG = <b>Y</b> when mobile onboarding is complete.",
            ],
            styles,
        )
    )
    story.append(PageBreak())


def section_flow(styles, story):
    story.append(p("10  OPERATIONAL FLOW", styles["section_num"]))
    story.append(p("10. End-to-End Operational Flow", styles["h1"]))
    story.append(hr())

    story.append(
        p(
            "For presentation audiences, the platform is best explained as a closed loop:",
            styles["body"],
        )
    )

    steps = [
        ["1. Provision", "Manager creates executive account and activates FLAG = A (Web → Users)."],
        ["2. Assign territory", "Manager assigns one or more routes from TBLROUTES (Web → Routes)."],
        ["3. Set goals", "Manager creates sales, product, and customer targets for the period (Web → Targets)."],
        ["4. Launch campaigns", "Manager assigns tasks (missing follow-up, product intro, etc.) (Web → Tasks)."],
        ["5. Field login", "Executive logs into REX, completes onboarding once, sees assigned routes."],
        ["6. Triage day", "Executive opens a route, filters Missing / Outstanding, prioritizes stops."],
        ["7. Execute visit", "Start GPS visit, capture reason/remarks/products, end visit with duration."],
        ["8. Capture demand", "Introduce products and save expected orders tied to the customer/visit."],
        ["9. Measure", "Manager dashboard &amp; reports reflect achievement; executive sees personal KPIs."],
    ]
    story.append(
        make_table(
            ["Step", "Action"],
            steps,
            styles,
            col_widths=[35 * mm, 135 * mm],
        )
    )
    story.append(Spacer(1, 8))
    story.append(
        p(
            "This loop is the primary story for demos: <b>plan on the web, execute on mobile, "
            "measure from shared Oracle data</b>.",
            styles["body"],
        )
    )
    story.append(PageBreak())


def section_ux(styles, story):
    story.append(p("11  UX / UI", styles["section_num"]))
    story.append(p("11. UX / UI Design Principles", styles["h1"]))
    story.append(hr())

    story.append(p("11.1 Web portal", styles["h2"]))
    story.append(
        bullets(
            [
                "Dark teal sidebar with light content canvas (gray-50).",
                "Primary accent ~ #00766e / #0F766E aligned with mobile brand.",
                "Stat cards, Recharts visualizations, status badges, modal forms.",
                "Responsive sidebar drawer on narrow viewports.",
                "Multi-select pickers for routes and item master products.",
            ],
            styles,
        )
    )

    story.append(p("11.2 REX mobile", styles["h2"]))
    story.append(
        bullets(
            [
                "Teal brand (#0F766E) + orange accent for CTAs / login hero.",
                "shadcn_ui + Material hybrid (ShadApp.router).",
                "Soft rounded sidebar (28px) with staggered entry animations.",
                "Fade page transitions; Lottie visit timer; interactive maps.",
                "Priority color coding for customer cards; offline connectivity banner.",
                "Light / dark theme toggle; infinite-scroll lists; pull-to-refresh dashboard.",
            ],
            styles,
        )
    )
    story.append(PageBreak())


def section_integration(styles, story):
    story.append(p("12  INTEGRATION", styles["section_num"]))
    story.append(p("12. Integration Map (Web ↔ Mobile ↔ Oracle)", styles["h1"]))
    story.append(hr())

    story.append(
        make_table(
            ["Capability", "Web", "Mobile", "Shared API / table"],
            [
                ["Login", "Yes", "Yes", "POST /api/auth/login → CRGS_USER"],
                ["Onboarding", "—", "Yes", "PATCH /api/auth/onboarding"],
                ["Create / activate executives", "Yes", "—", "/api/users"],
                ["Assign routes", "Yes", "Reads assigned", "CRGS_USER.ROUTE + TBLROUTES"],
                ["Set / read targets", "Set", "Read (dashboard)", "/api/targets/*"],
                ["Assign / list tasks", "Assign", "List / execute", "/api/tasks → CRGS_TASK"],
                ["Customers / missing", "Reports", "Core field flow", "/api/customers* + age views"],
                ["Visits", "Monitor via reports", "Start / end", "/api/visits → CRGS_VISITDETAILS"],
                ["Orders", "—", "Capture &amp; list", "/api/orders → ORDERHDR/DTL"],
                ["Product master", "Target picker", "Intro / orders", "/api/items → ITEMMASTER"],
            ],
            styles,
            col_widths=[38 * mm, 28 * mm, 38 * mm, 66 * mm],
        )
    )
    story.append(PageBreak())


def section_maturity(styles, story):
    story.append(p("13  MATURITY &amp; ROADMAP", styles["section_num"]))
    story.append(p("13. Current Maturity &amp; Roadmap Notes", styles["h1"]))
    story.append(hr())

    story.append(p("13.1 Production-ready core (API-backed)", styles["h2"]))
    story.append(
        bullets(
            [
                "Authentication, users, route assignment, targets, tasks.",
                "Customers (list, stats, last purchase/order, bill items).",
                "Visits start/end, expected orders, item master.",
                "Manager dashboard KPIs and executive mobile route/customer/visit flows.",
            ],
            styles,
        )
    )

    story.append(p("13.2 UI-first areas (presentation-ready; deeper persistence next)", styles["h2"]))
    story.append(
        bullets(
            [
                "Some mobile screens (market research submit, recovery form save, new-lead persistence, "
                "parts of outstanding/follow-up) are UI-complete and ready for full API wiring.",
                "Certain web report tabs may blend live targets with mock enrichment for market/risk storytelling.",
            ],
            styles,
        )
    )

    story.append(p("13.3 Suggested next increments", styles["h2"]))
    story.append(
        bullets(
            [
                "Persist recovery outcomes, market research, and leads to Oracle.",
                "Push notification / reminder for overdue tasks and commitment dates.",
                "Hardened JWT/session auth beyond employee-code login if required by IT policy.",
                "Offline queue for visit/order capture when connectivity drops.",
                "Expand reports with fully live customer-recovery and collection analytics.",
            ],
            styles,
        )
    )
    story.append(PageBreak())


def section_demo(styles, story):
    story.append(p("14  DEMO SCRIPT", styles["section_num"]))
    story.append(p("14. Demo Script for Presentation", styles["h1"]))
    story.append(hr())

    story.append(
        p(
            "Use this sequence for a ~10–12 minute live walkthrough:",
            styles["body"],
        )
    )
    story.append(
        make_table(
            ["#", "Surface", "Talk track"],
            [
                ["1", "Slide / title", "Introduce CRGS vs REX audiences and the recovery + growth mission."],
                ["2", "Web Login", "Show manager portal branding and employee-code login."],
                ["3", "Dashboard", "Point to live KPIs: executives, routes, target %, overdue tasks."],
                ["4", "Users + Routes", "Create/select executive; assign routes; explain ROLECODE 3."],
                ["5", "Targets + Tasks", "Create one sales target and one missing-customer task."],
                ["6", "REX Login", "Log in as that executive; complete/skip onboarding if already done."],
                ["7", "Routes → Customers", "Open route; switch Missing tab; open a customer."],
                ["8", "Visit", "Start visit, show GPS/map/timer, add remarks, end visit."],
                ["9", "Products / Orders", "Introduce a product and capture an expected order."],
                ["10", "Web Reports", "Return to portal; show Target vs Achievement / Executive Performance."],
                ["11", "Close", "Restate plan → execute → measure loop and roadmap items."],
            ],
            styles,
            col_widths=[12 * mm, 35 * mm, 123 * mm],
        )
    )
    story.append(PageBreak())


def section_conclusion(styles, story):
    story.append(p("15  CONCLUSION", styles["section_num"]))
    story.append(p("15. Conclusion", styles["h1"]))
    story.append(hr())

    story.append(
        p(
            "CRGS delivers a practical, ERP-connected platform for sales organizations that need "
            "both <b>office control</b> and <b>field execution</b>. The web portal equips managers "
            "to staff routes, set multi-dimensional targets, and launch recovery/growth campaigns. "
            "REX APP equips executives to prioritize the right customers, prove visits with GPS, "
            "and capture demand in the moment.",
            styles["body"],
        )
    )
    story.append(
        p(
            "Because both clients share one Flask API and one Oracle schema, every assignment on the "
            "portal has a clear field counterpart — and every field action can feed manager visibility. "
            "That shared operational loop is the core value of the Customer Recovery &amp; Growth System.",
            styles["body"],
        )
    )

    story.append(Spacer(1, 10))
    closing = Table(
        [[
            Paragraph(
                "<b>Deliverables covered in this report</b><br/><br/>"
                "• Web Admin Portal feature catalog (6 modules + reports)<br/>"
                "• REX Mobile App feature catalog (shell + field workflows)<br/>"
                "• Architecture, tech stack versions, API &amp; Oracle map<br/>"
                "• Roles, domain model, integration matrix, demo script",
                styles["callout"],
            )
        ]],
        colWidths=[170 * mm],
    )
    closing.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), TEAL_LIGHT),
                ("BOX", (0, 0), (-1, -1), 1, TEAL),
                ("LEFTPADDING", (0, 0), (-1, -1), 14),
                ("RIGHTPADDING", (0, 0), (-1, -1), 14),
                ("TOPPADDING", (0, 0), (-1, -1), 12),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 12),
            ]
        )
    )
    story.append(closing)
    story.append(Spacer(1, 16))
    story.append(
        p(
            f"Document generated {datetime.now().strftime('%d %B %Y')}  •  CRGS-Admin repository",
            styles["caption"],
        )
    )


def build():
    styles = build_styles()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)

    doc = SimpleDocTemplate(
        str(OUTPUT),
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=22 * mm,
        bottomMargin=18 * mm,
        title="CRGS Project Presentation Report",
        author="CRGS-Admin",
        subject="Web Portal and REX Mobile App — complete project details",
    )

    story: list = []
    cover_page(styles, story)
    toc_page(styles, story)
    section_exec_summary(styles, story)
    section_problem(styles, story)
    section_solution(styles, story)
    section_architecture(styles, story)
    section_stack(styles, story)
    section_web(styles, story)
    section_mobile(styles, story)
    section_backend(styles, story)
    section_domain(styles, story)
    section_flow(styles, story)
    section_ux(styles, story)
    section_integration(styles, story)
    section_maturity(styles, story)
    section_demo(styles, story)
    section_conclusion(styles, story)

    doc.build(story, onFirstPage=add_header_footer, onLaterPages=add_header_footer)
    return OUTPUT


if __name__ == "__main__":
    path = build()
    print(f"Generated: {path}")
