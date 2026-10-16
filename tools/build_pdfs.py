from __future__ import annotations

import html
import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import letter, landscape, TABLOID
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    PageTemplate,
    Paragraph,
    Preformatted,
    Spacer,
    Table,
    TableStyle,
)
from reportlab.pdfgen import canvas

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "output" / "pdf"


def inline_markup(text: str) -> str:
    escaped = html.escape(text.strip())
    escaped = re.sub(r"`([^`]+)`", r"<font name='Courier'>\1</font>", escaped)
    escaped = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", escaped)
    return escaped


def page_decoration(canvas_obj, doc):
    canvas_obj.saveState()
    canvas_obj.setStrokeColor(colors.HexColor("#D1D5DB"))
    canvas_obj.line(0.65 * inch, 0.55 * inch, 7.85 * inch, 0.55 * inch)
    canvas_obj.setFont("Helvetica", 8)
    canvas_obj.setFillColor(colors.HexColor("#4B5563"))
    canvas_obj.drawString(0.7 * inch, 0.35 * inch, doc.title)
    canvas_obj.drawRightString(7.8 * inch, 0.35 * inch, f"Page {doc.page}")
    canvas_obj.restoreState()


class ProjectDocTemplate(BaseDocTemplate):
    def __init__(self, filename: Path, title: str):
        super().__init__(
            str(filename),
            pagesize=letter,
            rightMargin=0.65 * inch,
            leftMargin=0.65 * inch,
            topMargin=0.65 * inch,
            bottomMargin=0.75 * inch,
            title=title,
            author="Matthew Li and Yash Shashtri",
            subject="KOHA-Lite database project deliverable",
        )
        frame = Frame(self.leftMargin, self.bottomMargin, self.width, self.height, id="body")
        self.addPageTemplates(PageTemplate(id="normal", frames=[frame], onPage=page_decoration))


def build_markdown_pdf(source: Path, target: Path, document_title: str):
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(
        name="ProjectTitle", parent=styles["Title"], fontName="Helvetica-Bold",
        fontSize=22, leading=26, textColor=colors.HexColor("#123B5D"),
        spaceAfter=18, alignment=TA_CENTER,
    ))
    styles.add(ParagraphStyle(
        name="H1Project", parent=styles["Heading1"], fontName="Helvetica-Bold",
        fontSize=15, leading=18, textColor=colors.HexColor("#123B5D"),
        spaceBefore=12, spaceAfter=7,
    ))
    styles.add(ParagraphStyle(
        name="H2Project", parent=styles["Heading2"], fontName="Helvetica-Bold",
        fontSize=12, leading=15, textColor=colors.HexColor("#1F5A7A"),
        spaceBefore=10, spaceAfter=5,
    ))
    body = ParagraphStyle(
        "BodyProject", parent=styles["BodyText"], fontName="Helvetica",
        fontSize=9.2, leading=12.2, textColor=colors.HexColor("#1F2937"),
        spaceAfter=5,
    )
    bullet = ParagraphStyle(
        "BulletProject", parent=body, leftIndent=15, firstLineIndent=-8,
        bulletIndent=5, spaceAfter=3,
    )
    code = ParagraphStyle(
        "CodeProject", parent=styles["Code"], fontName="Courier", fontSize=7.1,
        leading=9, leftIndent=6, rightIndent=6, backColor=colors.HexColor("#F3F4F6"),
        borderColor=colors.HexColor("#D1D5DB"), borderWidth=0.5, borderPadding=6,
        spaceBefore=5, spaceAfter=7,
    )
    table_cell = ParagraphStyle(
        "TableCell", parent=body, fontSize=7.2, leading=9, spaceAfter=0,
    )
    table_head = ParagraphStyle(
        "TableHead", parent=table_cell, fontName="Helvetica-Bold",
        textColor=colors.white,
    )

    lines = source.read_text(encoding="utf-8").splitlines()
    story = []
    i = 0
    in_code = False
    code_lines = []
    while i < len(lines):
        line = lines[i]
        if line.startswith("```"):
            if in_code:
                story.append(Preformatted("\n".join(code_lines), code))
                code_lines = []
                in_code = False
            else:
                in_code = True
            i += 1
            continue
        if in_code:
            code_lines.append(line)
            i += 1
            continue
        if not line.strip():
            i += 1
            continue
        if line.startswith("# "):
            story.append(Paragraph(inline_markup(line[2:]), styles["ProjectTitle"]))
            story.append(Spacer(1, 5))
            i += 1
            continue
        if line.startswith("## "):
            story.append(Paragraph(inline_markup(line[3:]), styles["H1Project"]))
            i += 1
            continue
        if line.startswith("### "):
            story.append(Paragraph(inline_markup(line[4:]), styles["H2Project"]))
            i += 1
            continue
        if line.startswith("|") and i + 1 < len(lines) and lines[i + 1].startswith("|"):
            raw_rows = []
            while i < len(lines) and lines[i].startswith("|"):
                raw_rows.append([cell.strip() for cell in lines[i].strip().strip("|").split("|")])
                i += 1
            if len(raw_rows) >= 2 and all(re.fullmatch(r":?-{3,}:?", c) for c in raw_rows[1]):
                raw_rows.pop(1)
            col_count = max(len(row) for row in raw_rows)
            widths_score = [1] * col_count
            for row in raw_rows:
                for col, cell in enumerate(row):
                    widths_score[col] = max(widths_score[col], min(35, max(6, len(cell))))
            total_score = sum(widths_score)
            col_widths = [7.2 * inch * score / total_score for score in widths_score]
            data = []
            for row_index, row in enumerate(raw_rows):
                padded = row + [""] * (col_count - len(row))
                style = table_head if row_index == 0 else table_cell
                data.append([Paragraph(inline_markup(cell), style) for cell in padded])
            table = Table(data, colWidths=col_widths, repeatRows=1, hAlign="LEFT")
            table.setStyle(TableStyle([
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1F5A7A")),
                ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#9CA3AF")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F8FAFC")]),
            ]))
            story.extend([table, Spacer(1, 7)])
            continue
        if line.startswith("- "):
            story.append(Paragraph(inline_markup(line[2:]), bullet, bulletText="-"))
            i += 1
            continue
        if re.match(r"^\d+\. ", line):
            number, content = line.split(". ", 1)
            story.append(Paragraph(inline_markup(content), bullet, bulletText=number + "."))
            i += 1
            continue

        paragraph_lines = [line.strip()]
        i += 1
        while i < len(lines):
            next_line = lines[i]
            if (not next_line.strip() or next_line.startswith("#") or next_line.startswith("|")
                    or next_line.startswith("- ") or next_line.startswith("```")
                    or re.match(r"^\d+\. ", next_line)):
                break
            paragraph_lines.append(next_line.strip())
            i += 1
        story.append(Paragraph(inline_markup(" ".join(paragraph_lines)), body))

    doc = ProjectDocTemplate(target, document_title)
    doc.build(story)


def build_erd_pdf(target: Path):
    c = canvas.Canvas(str(target), pagesize=landscape(TABLOID))
    width, height = landscape(TABLOID)
    c.setTitle("KOHA-Lite Entity-Relationship Diagram")
    c.setAuthor("Matthew Li and Yash Shashtri")
    c.setFillColor(colors.HexColor("#123B5D"))
    c.setFont("Helvetica-Bold", 20)
    c.drawCentredString(width / 2, height - 32, "KOHA-Lite Entity-Relationship Diagram")
    c.setFont("Helvetica", 8)
    c.drawCentredString(width / 2, height - 45, "PK = primary key | FK = foreign key | UQ = unique | Lines represent the cardinalities documented in the TDD")

    nodes = {
        "BusinessRole": (24, 560, ["PK RoleCode", "UQ RoleName", "RoleDescription"]),
        "UserAccount": (190, 550, ["PK UserID", "UQ Email", "DisplayName", "IsActive", "CreatedAt"]),
        "UserRole": (370, 565, ["PK/FK UserID", "PK/FK RoleCode", "AssignedAt"]),
        "DirectorLibrary": (540, 565, ["PK/FK UserID", "PK/FK LibraryID", "AssignedAt"]),
        "Library": (720, 540, ["PK LibraryID", "UQ LibraryName", "Address fields", "LibraryStatus", "CreatedAt"]),
        "BookCategory": (24, 330, ["PK CategoryID", "UQ CategoryName", "Description"]),
        "BookTitle": (190, 315, ["PK BookTitleID", "UQ ISBN13", "Title", "AuthorName", "FK CategoryID"]),
        "BookCopy": (370, 290, ["PK BookCopyID", "FK BookTitleID", "FK CurrentLibraryID", "CopyStatus", "RegistrationSource", "FK DonationItemID", "FK RegisteredByUserID"]),
        "Loan": (560, 280, ["PK LoanID", "FK BookCopyID", "FK PatronUserID", "FK checkout/return libraries", "FK recording actors", "CheckoutAt / ReturnedAt", "LoanStatus", "UQ ActiveBookCopyID"]),
        "Visit": (750, 315, ["PK VisitID", "FK PatronUserID", "FK LibraryID", "VisitedAt", "FK RecordedByUserID", "RecordingMethod"]),
        "Donation": (24, 95, ["PK DonationID", "FK DonorUserID", "FK ReceivingLibraryID", "DonationStatus", "SubmittedAt / DecidedAt", "FK DecidedByUserID"]),
        "DonationItem": (210, 105, ["PK DonationItemID", "FK DonationID", "FK BookTitleID", "OfferedQuantity", "AcceptedQuantity"]),
        "InventoryAdjustment": (430, 75, ["PK AdjustmentID", "FK BookCopyID", "FK DirectorUserID", "FK prior/new libraries", "Prior/new status", "Reason / AdjustedAt"]),
        "AuditEvent": (690, 70, ["PK AuditEventID", "FK ActorUserID", "EventType", "EntityType / EntityID", "EventTimestamp / Outcome", "FK LibraryID", "ContextData JSON"]),
    }
    box_w = 150
    box_h = 26
    actual = {}
    palette = ["#E8F1FB", "#EEF7EA", "#FFF4D6", "#F8EAF8"]
    for index, (name, (x, y, attrs)) in enumerate(nodes.items()):
        h = box_h + 12 * len(attrs)
        actual[name] = (x, y, box_w, h)
        c.setFillColor(colors.HexColor(palette[index % len(palette)]))
        c.setStrokeColor(colors.HexColor("#52606D"))
        c.roundRect(x, y, box_w, h, 4, fill=1, stroke=1)
        c.setFillColor(colors.HexColor("#123B5D"))
        c.setFont("Helvetica-Bold", 8.5)
        c.drawString(x + 5, y + h - 13, name)
        c.setStrokeColor(colors.HexColor("#A0AEC0"))
        c.line(x, y + h - 19, x + box_w, y + h - 19)
        c.setFillColor(colors.black)
        c.setFont("Helvetica", 6.8)
        ty = y + h - 30
        for attr in attrs:
            c.drawString(x + 5, ty, attr)
            ty -= 11

    edges = [
        ("BusinessRole", "UserRole", "1:M"), ("UserAccount", "UserRole", "1:M"),
        ("UserAccount", "DirectorLibrary", "1:M"), ("Library", "DirectorLibrary", "1:M"),
        ("BookCategory", "BookTitle", "1:M"), ("BookTitle", "BookCopy", "1:M"),
        ("Library", "BookCopy", "1:M"), ("BookCopy", "Loan", "1:M history"),
        ("UserAccount", "Loan", "1:M"), ("UserAccount", "Visit", "1:M"),
        ("Library", "Visit", "1:M"), ("UserAccount", "Donation", "1:M"),
        ("Library", "Donation", "1:M"), ("Donation", "DonationItem", "1:M"),
        ("BookTitle", "DonationItem", "1:M"), ("DonationItem", "BookCopy", "0..1:M"),
        ("BookCopy", "InventoryAdjustment", "1:M"), ("UserAccount", "InventoryAdjustment", "1:M"),
        ("UserAccount", "AuditEvent", "1:M"), ("Library", "AuditEvent", "0..1:M"),
    ]
    c.setStrokeColor(colors.HexColor("#718096"))
    c.setFillColor(colors.HexColor("#4A5568"))
    c.setFont("Helvetica", 5.5)
    for source, target_name, label in edges:
        sx, sy, sw, sh = actual[source]
        tx, ty, tw, th = actual[target_name]
        x1, y1 = sx + sw / 2, sy + sh / 2
        x2, y2 = tx + tw / 2, ty + th / 2
        c.line(x1, y1, x2, y2)
        c.drawString((x1 + x2) / 2 + 2, (y1 + y2) / 2 + 2, label)

    c.setFont("Helvetica", 7)
    c.setFillColor(colors.HexColor("#4B5563"))
    c.drawRightString(width - 24, 20, "Editable source: docs/KOHA-Lite_ERD.drawio")
    c.showPage()
    c.save()


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    build_markdown_pdf(ROOT / "docs" / "FRD.md", OUTPUT / "KOHA-Lite_FRD.pdf", "KOHA-Lite FRD")
    build_markdown_pdf(ROOT / "docs" / "TDD.md", OUTPUT / "KOHA-Lite_TDD.pdf", "KOHA-Lite TDD")
    build_erd_pdf(OUTPUT / "KOHA-Lite_ERD.pdf")


if __name__ == "__main__":
    main()
