// functions/src/sav-return-pdf-generator.ts

import PDFDocument from "pdfkit";
import axios from "axios";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

// --- 1. ASSETS ---
const LOGO_URL = "https://f003.backblazeb2.com/file/BoitexInfo/boitex_logo.png";
const STAMP_URL = "https://f003.backblazeb2.com/file/BoitexInfo/Boitex+logo/cache+technique.png";

// --- 2. PREMIUM DESIGN TOKENS ---
const COLORS = {
primary: "#0F172A",     // Deep Space Dark
secondary: "#64748B",   // Slate Gray
accent: "#2563EB",      // Vibrant Apple Blue
border: "#E2E8F0",      // Light Border
bgLight: "#F8FAFC",     // Frost White
success: "#10B981",     // Emerald
warning: "#F59E0B",     // Sunset Amber
white: "#FFFFFF"
};

const FONTS = {
regular: "Helvetica",
bold: "Helvetica-Bold",
italic: "Helvetica-Oblique"
};

const LAYOUT = {
margin: 50,
pageWidth: 595.28,
pageHeight: 841.89,
contentWidth: 495.28
};

/**
* 🚀 Helper: Fetch Image Buffer safely
*/
async function fetchImage(url: string): Promise<Buffer | null> {
  if (!url || typeof url !== 'string' || !url.startsWith("http")) return null;
  try {
    const response = await axios.get(url, { responseType: "arraybuffer", timeout: 10000 });
    const buffer = Buffer.from(response.data);

    if (buffer.length > 2.5 * 1024 * 1024) {
      logger.warn(`Skipping image ${url} - Size is too large.`);
      return null;
    }
    return buffer;
  } catch (error) {
    logger.warn(`Could not load image at ${url}`);
    return null;
  }
}

/**
 * Helper: Format Date
 */
function formatDate(dateObj: any, includeTime = false): string {
  if (!dateObj) return "N/A";
  let d: Date;
  if (dateObj._seconds) d = new Date(dateObj._seconds * 1000);
  else if (dateObj.seconds) d = new Date(dateObj.seconds * 1000);
  else d = new Date(dateObj);

  if (isNaN(d.getTime())) return "N/A";

  const opts: Intl.DateTimeFormatOptions = {
    day: "2-digit", month: "short", year: "numeric",
    ...(includeTime && { hour: "2-digit", minute: "2-digit" })
  };
  return d.toLocaleDateString("fr-FR", opts);
}

/**
 * 🚀 SMART PAGE BREAK HANDLER
 */
function _checkPageBreak(doc: PDFKit.PDFDocument, requiredSpace: number) {
  if (doc.y + requiredSpace > LAYOUT.pageHeight - 80) {
    doc.addPage();
    doc.x = LAYOUT.margin;
    doc.y = LAYOUT.margin;
  }
}

/**
 * 🚀 MAIN GENERATOR FUNCTION
 */
export async function generateSavReturnPdf(data: any, ticketId?: string): Promise<Buffer> {
  return new Promise(async (resolve, reject) => {
    try {
      const doc = new PDFDocument({
        size: "A4",
        margins: { top: LAYOUT.margin, bottom: LAYOUT.margin, left: LAYOUT.margin, right: LAYOUT.margin },
        bufferPages: true,
      });

      const buffers: Buffer[] = [];
      doc.on("data", buffers.push.bind(buffers));

      const signatureUrl = data.returnSignatureUrl || data.storeManagerSignatureUrl;
      const ticketTitle = "BON DE RESTITUTION SAV";

      let targetTicketId = ticketId || data.id || data.ticketId;

      // 🌟 WHATSAPP STYLE QR CODE
      const qrData = encodeURIComponent(`Certifié BOITEX INFO | ${ticketTitle} | SAV: ${data.savCode || 'N/A'} | Client: ${data.clientName || 'N/A'}`);
      const logoUrlEnc = encodeURIComponent(LOGO_URL);
      const QR_URL = `https://quickchart.io/qr?text=${qrData}&dark=0F172A&light=FFFFFF&size=150&centerImageUrl=${logoUrlEnc}`;

      // Fetch Assets
      const [logoBuffer, signatureBuffer, stampBuffer, qrBuffer] = await Promise.all([
        fetchImage(LOGO_URL),
        fetchImage(signatureUrl),
        fetchImage(STAMP_URL),
        fetchImage(QR_URL),
      ]);

      // 🌟 FETCH JOURNAL ENTRIES FOR TIMELINE
      let journalEntries: any[] = [];

      try {
        // 🛠️ BULLETPROOF FIX: If ID is missing, find it via the savCode!
        if (!targetTicketId && data.savCode) {
          const ticketQuery = await admin.firestore()
            .collection('sav_tickets')
            .where('savCode', '==', data.savCode)
            .limit(1)
            .get();

          if (!ticketQuery.empty) {
            targetTicketId = ticketQuery.docs[0].id;
          }
        }

        // Now that we definitely have the ID, fetch the journal!
        if (targetTicketId) {
          const snapshot = await admin.firestore()
            .collection('sav_tickets')
            .doc(targetTicketId)
            .collection('journal_entries')
            .orderBy('timestamp', 'asc')
            .get();

          journalEntries = snapshot.docs.map(doc => doc.data());
        } else {
          logger.warn(`Could not find a valid Ticket ID for SAV Code: ${data.savCode}`);
        }
      } catch (e) {
        logger.error("Error fetching journal entries for timeline", e);
      }

      doc.on('pageAdded', () => {
        _drawWatermark(doc, logoBuffer);
      });

      // --- START DRAWING ---
      _drawWatermark(doc, logoBuffer);
      _drawHeader(doc, data, logoBuffer, ticketTitle);

      doc.moveDown(1);
      _drawInformationGrid(doc, data);

      doc.moveDown(1.5);
      _drawEquipmentDetails(doc, data);

      doc.moveDown(1.5);
      _drawJournalTimeline(doc, journalEntries);

      doc.moveDown(1.5);
      _drawValidationSection(doc, data, signatureBuffer, stampBuffer, qrBuffer);

      _addGlobalFooters(doc, data, ticketTitle);

      doc.end();
      doc.on("end", () => resolve(Buffer.concat(buffers)));

    } catch (error) {
      logger.error("CRITICAL ERROR IN SAV RETURN PDF GENERATION:", error);
      reject(error);
    }
  });
}

// ============================================================================
// 🎨 PREMIUM DRAWING FUNCTIONS
// ============================================================================

function _drawWatermark(doc: PDFKit.PDFDocument, logoBuffer: Buffer | null) {
  if (!logoBuffer) return;
  try {
    doc.save()
       .opacity(0.06)
       .image(logoBuffer, LAYOUT.margin, (LAYOUT.pageHeight - 400) / 2, {
          fit: [LAYOUT.contentWidth, 400],
          align: 'center',
          valign: 'center'
       })
       .restore();
  } catch (e) {
    doc.restore();
  }
}

function _drawHeader(doc: PDFKit.PDFDocument, data: any, logoBuffer: Buffer | null, title: string) {
  doc.x = LAYOUT.margin;
  const startY = doc.y;

  if (logoBuffer) {
    try {
      doc.image(logoBuffer, LAYOUT.margin, startY, { fit: [210, 80] });
    } catch (e) {
      doc.font(FONTS.bold).fontSize(16).fillColor(COLORS.primary).text("BOITEX INFO", LAYOUT.margin, startY);
    }
  } else {
    doc.font(FONTS.bold).fontSize(16).fillColor(COLORS.primary).text("BOITEX INFO", LAYOUT.margin, startY);
  }

  doc.font(FONTS.bold).fontSize(20).fillColor(COLORS.primary)
     .text(title, LAYOUT.margin, startY, { align: "right", width: LAYOUT.contentWidth });

  doc.font(FONTS.regular).fontSize(10).fillColor(COLORS.secondary)
     .text(`RÉF SAV: ${data.savCode || 'N/A'}`, LAYOUT.margin, doc.y + 2, { align: "right", width: LAYOUT.contentWidth });

  const returnDate = formatDate(new Date(), false);
  doc.text(`RESTITUÉ LE : ${returnDate}`, LAYOUT.margin, doc.y + 2, { align: "right", width: LAYOUT.contentWidth });

  // Status Badge
  doc.moveDown(0.5);
  const status = "Restitué";
  const textWidth = doc.widthOfString(status.toUpperCase()) + 20;
  const badgeX = LAYOUT.pageWidth - LAYOUT.margin - textWidth;

  doc.roundedRect(badgeX, doc.y, textWidth, 18, 9).fill(COLORS.accent);
  doc.font(FONTS.bold).fontSize(8).fillColor(COLORS.white)
     .text(status.toUpperCase(), badgeX, doc.y + 5, { width: textWidth, align: "center" });

  doc.y = Math.max(startY + 80, doc.y + 20);
  doc.moveTo(LAYOUT.margin, doc.y).lineTo(LAYOUT.pageWidth - LAYOUT.margin, doc.y)
     .lineWidth(1).strokeColor(COLORS.border).stroke();
  doc.y += 15;
  doc.x = LAYOUT.margin;
}

function _drawSectionTitle(doc: PDFKit.PDFDocument, title: string) {
  _checkPageBreak(doc, 40);
  doc.x = LAYOUT.margin;
  doc.font(FONTS.bold).fontSize(9).fillColor(COLORS.accent)
     .text(title.toUpperCase(), LAYOUT.margin, doc.y, { characterSpacing: 1.5 });
  doc.moveDown(1);
}

function _drawInformationGrid(doc: PDFKit.PDFDocument, data: any) {
  _checkPageBreak(doc, 80);
  doc.x = LAYOUT.margin;

  const startY = doc.y;
  const colWidth = (LAYOUT.contentWidth / 2) - 10;
  const rightColX = LAYOUT.margin + colWidth + 20;

  // Left Column
  doc.font(FONTS.bold).fontSize(9).fillColor(COLORS.secondary).text("INFORMATIONS CLIENT", LAYOUT.margin, startY, { characterSpacing: 1 });
  doc.font(FONTS.bold).fontSize(11).fillColor(COLORS.primary).text(data.clientName || "Client Inconnu", LAYOUT.margin, startY + 15, { width: colWidth });
  doc.font(FONTS.regular).fontSize(10).fillColor(COLORS.primary)
     .text(data.storeName || "Site non spécifié", LAYOUT.margin, startY + 30, { width: colWidth });

  const managerName = data.returnClientName || data.storeManagerName || "N/A";
  const managerPhone = data.returnClientPhone || data.storeManagerEmail || "";

  doc.text(`A la charge de: ${managerName}`, LAYOUT.margin, startY + 45, { width: colWidth })
     .fillColor(COLORS.secondary).text(managerPhone, LAYOUT.margin, startY + 60, { width: colWidth });

  // Right Column
  doc.font(FONTS.bold).fontSize(9).fillColor(COLORS.secondary).text("DÉTAILS INTERVENTION", rightColX, startY, { characterSpacing: 1 });

  let techs = "Non assigné";
  if (Array.isArray(data.pickupTechnicianNames) && data.pickupTechnicianNames.length > 0) {
    techs = data.pickupTechnicianNames.join(", ");
  }

  const row = (label: string, val: string, yPos: number) => {
    doc.font(FONTS.regular).fontSize(10).fillColor(COLORS.secondary).text(label, rightColX, yPos, { width: 90 });
    doc.font(FONTS.bold).fillColor(COLORS.primary).text(val, rightColX + 90, yPos, { width: colWidth - 90 });
  };

  row("Type Ticket:", "Restitution Matériel", startY + 15);
  row("Équipe (Livraison):", techs, startY + 30);

  doc.y = startY + 80;
  doc.x = LAYOUT.margin;
}

function _drawEquipmentDetails(doc: PDFKit.PDFDocument, data: any) {
  // 🅰️ MULTI-PRODUCT MODE
  if (data.multiProducts && data.multiProducts.length > 0) {
    _drawSectionTitle(doc, "Liste des Équipements Restitués");

    const startX = LAYOUT.margin;
    doc.rect(startX, doc.y, LAYOUT.contentWidth, 20).fill(COLORS.bgLight);

    const headerY = doc.y + 6;
    doc.font(FONTS.bold).fontSize(8).fillColor(COLORS.secondary);
    doc.text("PRODUIT", startX + 10, headerY, { width: 180 });
    doc.text("N° SÉRIE", startX + 200, headerY, { width: 120 });
    doc.text("ÉTAT / RÉPARATION", startX + 330, headerY, { width: doc.page.width - startX - 350 });

    doc.y = headerY + 14;

    data.multiProducts.forEach((item: any) => {
      _checkPageBreak(doc, 30);
      const rowY = doc.y + 6;

      const name = item.productName || "Inconnu";
      const sns = item.serialNumber || "-";
      const rep = item.technicianReport || data.technicianReport || "Vérifié & Opérationnel";

      doc.font(FONTS.bold).fontSize(9).fillColor(COLORS.primary).text(name, startX + 10, rowY, { width: 180 });
      doc.font(FONTS.regular).fillColor(COLORS.secondary).text(sns, startX + 200, rowY, { width: 120 });
      doc.fillColor(COLORS.primary).text(rep, startX + 330, rowY, { width: doc.page.width - startX - 350 });

      const nameHeight = doc.heightOfString(name, { width: 180 });
      const repHeight = doc.heightOfString(rep, { width: doc.page.width - startX - 350 });
      const maxH = Math.max(nameHeight, repHeight);

      doc.y = rowY + maxH + 6;
      doc.moveTo(startX, doc.y).lineTo(LAYOUT.pageWidth - startX, doc.y)
         .lineWidth(0.5).strokeColor(COLORS.border).stroke();
    });

    doc.y += 15;
    doc.x = LAYOUT.margin;
    return;
  }

  // 🅱️ SINGLE PRODUCT MODE
  _checkPageBreak(doc, 90);
  _drawSectionTitle(doc, "Équipement Concerné");

  const cardX = LAYOUT.margin;
  const cardWidth = LAYOUT.contentWidth;

  doc.font(FONTS.regular).fontSize(10);
  const probHeight = doc.heightOfString(data.problemDescription || "Non spécifié", { width: cardWidth - 40 });
  const cardHeight = 80 + probHeight;

  doc.roundedRect(cardX, doc.y, cardWidth, cardHeight, 10)
     .fillAndStroke(COLORS.bgLight, COLORS.border);

  const innerY = doc.y + 15;

  doc.font(FONTS.bold).fontSize(9).fillColor(COLORS.secondary).text("PRODUIT", cardX + 20, innerY);
  doc.font(FONTS.bold).fontSize(12).fillColor(COLORS.primary).text(data.productName || "Inconnu", cardX + 20, innerY + 12);

  doc.font(FONTS.bold).fontSize(9).fillColor(COLORS.secondary).text("NUMÉRO DE SÉRIE", cardX + 250, innerY);
  doc.font(FONTS.regular).fontSize(11).fillColor(COLORS.primary).text(data.serialNumber || "N/A", cardX + 250, innerY + 12);

  doc.moveTo(cardX + 20, innerY + 35).lineTo(cardX + cardWidth - 20, innerY + 35)
     .lineWidth(0.5).strokeColor(COLORS.border).stroke();

  doc.font(FONTS.bold).fontSize(9).fillColor(COLORS.secondary).text("PROBLÈME INITIAL", cardX + 20, innerY + 45);
  doc.font(FONTS.regular).fontSize(10).fillColor(COLORS.primary)
     .text(data.problemDescription || "Non spécifié", cardX + 20, innerY + 60, { width: cardWidth - 40 });

  doc.y += cardHeight + 20;
}

// ----------------------------------------------------------------------------
// 🌟 THE DYNAMIC REPARATION TIMELINE (UPDATED WITH PARTS & MEDIA)
// ----------------------------------------------------------------------------
function _drawJournalTimeline(doc: PDFKit.PDFDocument, entries: any[]) {
  const relevantEntries = entries.filter(e => {
    const type = (e.type || "").toLowerCase();
    // ✅ Include text, parts, and photos!
    if (['text', 'part_consumed', 'photo'].includes(type)) return true;
    if (type === 'status_change') {
      const ns = e.newStatus || (e.metadata && e.metadata.newStatus) || "";
      return ns === 'En Réparation' || ns === 'Terminé';
    }
    return false;
  });

  if (relevantEntries.length === 0) return;

  doc.x = LAYOUT.margin;
  _drawSectionTitle(doc, "Journal de Réparation & Suivi Technique");

  const timelineX = LAYOUT.margin + 10;
  const contentX = timelineX + 25;
  const contentWidth = LAYOUT.pageWidth - LAYOUT.margin - contentX;

  relevantEntries.forEach((entry, index) => {
    _checkPageBreak(doc, 60);
    const startY = doc.y;

    const dateStr = formatDate(entry.timestamp, true);
    const author = entry.authorName || "Technicien";
    const type = (entry.type || "").toLowerCase();

    let dotColor = COLORS.secondary;
    let titleText = "";
    let contentText = entry.content || "";

    // ✅ Handle different Journal Entry Types
    if (type === 'status_change') {
      const ns = entry.newStatus || (entry.metadata && entry.metadata.newStatus);
      if (ns === 'En Réparation') {
         dotColor = COLORS.warning;
         titleText = `Début de Réparation • ${dateStr}`;
         if (!contentText) contentText = "L'équipement a été pris en charge pour réparation.";
      } else if (ns === 'Terminé') {
         dotColor = COLORS.success;
         titleText = `Réparation Terminée • ${dateStr}`;
         if (!contentText) contentText = "L'intervention technique est officiellement achevée.";
      }
    }
    else if (type === 'part_consumed') { // ✅ Handle Replaced Parts
       dotColor = COLORS.success;
       titleText = `Pièce Remplacée (${author}) • ${dateStr}`;

       const pName = entry.metadata?.productName || "Pièce inconnue";
       const pRef = entry.metadata?.productRef ? `(Réf: ${entry.metadata.productRef})` : "";

       // Combine the technician's note with the part details
       contentText = `🔧 ${pName} ${pRef}\n${contentText}`.trim();
    }
    else if (type === 'photo') { // ✅ Handle Photos/Videos
       dotColor = COLORS.accent; // Blue color for media
       const isVideo = entry.metadata?.isVideo;
       titleText = `${isVideo ? 'Vidéo' : 'Photo'} d'inspection (${author}) • ${dateStr}`;

       // Note the media inclusion
       const mediaNote = isVideo ? "📹 Vidéo jointe au dossier numérique." : "📸 Photo jointe au dossier numérique.";
       contentText = contentText ? `${contentText}\n${mediaNote}` : mediaNote;
    }
    else {
      // Standard Text Note
      dotColor = COLORS.secondary;
      titleText = `Note Technique (${author}) • ${dateStr}`;
    }

    // Draw Title
    doc.font(FONTS.bold).fontSize(9).fillColor(dotColor).text(titleText, contentX, startY);

    // Draw Content
    doc.moveDown(0.3);
    doc.font(FONTS.regular).fontSize(10).fillColor(COLORS.primary)
       .text(contentText, contentX, doc.y, { width: contentWidth, lineGap: 4, align: 'left' });

    const endY = doc.y + 15;

    // Draw Timeline Nodes
    doc.circle(timelineX, startY + 4, 4).lineWidth(1.5).strokeColor(dotColor).stroke();
    doc.circle(timelineX, startY + 4, 2).fill(dotColor);

    if (index < relevantEntries.length - 1) {
      doc.moveTo(timelineX, startY + 14).lineTo(timelineX, endY - 6).lineWidth(1).strokeColor(COLORS.border).stroke();
    }

    doc.y = endY;
    doc.x = LAYOUT.margin;
  });
}

// ----------------------------------------------------------------------------
// 🌟 THE ULTIMATE VALIDATION CARD
// ----------------------------------------------------------------------------
function _drawValidationSection(doc: PDFKit.PDFDocument, data: any, signatureBuffer: Buffer | null, stampBuffer: Buffer | null, qrBuffer: Buffer | null) {
  _checkPageBreak(doc, 145);
  doc.x = LAYOUT.margin;

  const cardX = LAYOUT.margin;
  const cardY = doc.y;
  const cardWidth = LAYOUT.contentWidth;
  const cardHeight = 125;

  doc.roundedRect(cardX, cardY, cardWidth, cardHeight, 10)
     .fillAndStroke(COLORS.bgLight, COLORS.border);

  doc.font(FONTS.bold).fontSize(10).fillColor(COLORS.primary)
     .text("VALIDATION & SIGNATURE", cardX + 15, cardY + 12);

  const agreementText = "En signant ce document, le client confirme la récupération du matériel réparé en bon état de fonctionnement de la part de Boitex Info.";

  doc.font(FONTS.regular).fontSize(8).fillColor(COLORS.secondary)
     .text(agreementText, cardX + 15, cardY + 25, { width: cardWidth - 30 });

  const elementsY = cardY + 40;

  if (qrBuffer) {
    try {
      doc.image(qrBuffer, cardX + 15, elementsY, { width: 60, height: 60 });
    } catch (e) {}
  }

  const stampX = cardX + 90;
  if (stampBuffer) {
    try {
      doc.image(stampBuffer, stampX, elementsY - 5, { width: 100, height: 70, fit: [100, 70], align: 'center', valign: 'center' });
    } catch (e) {}
  }

  const sigWidth = 160;
  const sigX = cardX + cardWidth - sigWidth - 15;

  doc.roundedRect(sigX, elementsY, sigWidth, 60, 6).fillAndStroke(COLORS.white, COLORS.border);

  if (signatureBuffer) {
    try {
      doc.image(signatureBuffer, sigX + 5, elementsY + 5, { width: sigWidth - 10, height: 40, fit: [sigWidth - 10, 40], align: 'center', valign: 'center' });
    } catch (e) {
      doc.fillColor(COLORS.secondary).fontSize(8).text("Erreur Signature", sigX, elementsY + 25, { width: sigWidth, align: "center" });
    }
  } else {
    doc.fillColor(COLORS.secondary).fontSize(8).text("Signature non fournie", sigX, elementsY + 25, { width: sigWidth, align: "center" });
  }

  const managerName = data.returnClientName || data.storeManagerName || "Client (Réception)";

  doc.fillColor(COLORS.primary).font(FONTS.bold).fontSize(9)
     .text(managerName, sigX, elementsY + 47, { width: sigWidth, align: "center" });

  doc.moveTo(cardX, cardY + 110).lineTo(cardX + cardWidth, cardY + 110)
     .lineWidth(0.5).strokeColor(COLORS.border).stroke();

  doc.font(FONTS.italic).fontSize(7).fillColor(COLORS.secondary)
     .text("Certifié Numériquement -- Garantie de traçabilité Boitex Info.", cardX, cardY + 115, { align: "center", width: cardWidth });

  doc.y = cardY + cardHeight + 20;
}

function _addGlobalFooters(doc: PDFKit.PDFDocument, data: any, title: string) {
  const pageCount = doc.bufferedPageRange().count;
  const originalBottomMargin = doc.page.margins.bottom;
  doc.page.margins.bottom = 0;

  for (let i = 0; i < pageCount; i++) {
    doc.switchToPage(i);

    try {
      const footerY = LAYOUT.pageHeight - 35;

      doc.moveTo(LAYOUT.margin, footerY - 5).lineTo(LAYOUT.pageWidth - LAYOUT.margin, footerY - 5)
         .lineWidth(0.5).strokeColor(COLORS.border).stroke();

      doc.font(FONTS.bold).fontSize(8).fillColor(COLORS.primary)
         .text("BOITEX INFO", LAYOUT.margin, footerY);

      doc.font(FONTS.regular).fillColor(COLORS.accent)
         .text("www.Boitexinfo.com", LAYOUT.margin, footerY + 12, { link: "https://www.Boitexinfo.com" });

      doc.font(FONTS.regular).fillColor(COLORS.secondary)
         .text(`${title} - SAV: ${data.savCode || "N/A"}`, LAYOUT.margin, footerY, { align: "center", width: LAYOUT.contentWidth });

      doc.text(`Page ${i + 1} / ${pageCount}`, LAYOUT.margin, footerY, { align: "right", width: LAYOUT.contentWidth });
    } finally {
      doc.page.margins.bottom = originalBottomMargin;
    }
  }
}