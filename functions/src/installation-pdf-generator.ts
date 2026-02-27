// functions/src/installation-pdf-generator.ts

import PDFDocument from "pdfkit";
import axios from "axios";
import * as logger from "firebase-functions/logger";
import * as QRCode from 'qrcode';

// --- 🎨 2026 PREMIUM UI DESIGN SYSTEM ---
const LOGO_URL = "https://f003.backblazeb2.com/file/BoitexInfo/boitex_logo.png";
const CACHE_URL = "https://f003.backblazeb2.com/file/BoitexInfo/Boitex+logo/cache+technique.png";

const COLORS = {
primary: "#0F172A",    // Slate 900
secondary: "#64748B",  // Slate 500
accent: "#2962FF",     // Boitex Blue (Interactive Links)
  success: "#10B981",    // Emerald 500
  danger: "#EF4444",     // Red 500
  warning: "#F59E0B",    // Amber/Gold
  surface: "#F8FAFC",    // Slate 50
  border: "#E2E8F0",     // Slate 200
};

const MARGIN = 50;

/**
 * Fetch Image Buffer safely
 */
async function fetchImage(url: string): Promise<Buffer | null> {
  if (!url || !url.startsWith("http")) return null;
  try {
    const response = await axios.get(url, { responseType: "arraybuffer", timeout: 8000 });
    return Buffer.from(response.data);
  } catch (error: any) {
    logger.warn(`Failed to fetch image: ${url}`, error.message || error);
    return null;
  }
}

/**
 * Generate QR Code Locally (Fast & Reliable)
 */
async function generateLocalQRCode(text: string): Promise<Buffer | null> {
  try {
    return await QRCode.toBuffer(text, { margin: 0, width: 150 });
  } catch (error) {
    logger.error("Failed to generate local QR Code", error);
    return null;
  }
}

/**
 * Smart Date Formatter (String)
 */
function formatDate(timestamp: any, includeTime: boolean = false): string {
  if (!timestamp) return "N/A";
  let date: Date = timestamp._seconds ? new Date(timestamp._seconds * 1000) : (timestamp.toDate ? timestamp.toDate() : new Date(timestamp));
  if (isNaN(date.getTime())) return "Date invalide";

  const isDifferentYear = date.getFullYear() !== new Date().getFullYear();
  const options: Intl.DateTimeFormatOptions = { day: '2-digit', month: 'short', year: isDifferentYear ? 'numeric' : undefined };
  let formatted = date.toLocaleDateString('fr-FR', options);

  if (includeTime) formatted += ` à ${date.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}`;
  return formatted;
}

/**
 * Date Math for Warranty (Returns Date object)
 */
function parseFirebaseDate(timestamp: any): Date {
  if (!timestamp) return new Date();
  if (timestamp._seconds) return new Date(timestamp._seconds * 1000);
  if (timestamp.toDate) return timestamp.toDate();
  return new Date(timestamp);
}

/**
 * Draw Interactive Smart Link
 */
function drawSmartLink(doc: typeof PDFDocument, label: string, val: string | null, linkUrl: string | null, x: number, y: number, width?: number) {
  doc.font("Helvetica-Bold").fontSize(9).fillColor(COLORS.secondary).text(label, x, y, { continued: true });
  if (val && linkUrl) {
      doc.font("Helvetica").fillColor(COLORS.accent).text(val, { link: linkUrl, underline: true, width: width });
  } else {
      doc.font("Helvetica").fillColor(COLORS.primary).text(val || "N/A", { underline: false, width: width });
  }
}

/**
 * Check Page Breaks
 */
function checkPageBreak(doc: typeof PDFDocument, currentY: number, requiredSpace: number): number {
  if (currentY + requiredSpace > doc.page.height - MARGIN - 30) {
    doc.addPage();
    return MARGIN;
  }
  return currentY;
}

/**
 * Draw Premium Timeline Step
 */
function drawTimelineStep(doc: typeof PDFDocument, x: number, y: number, label: string, dateStr: string, isActive: boolean) {
  doc.circle(x, y, 5).lineWidth(1.5).fillAndStroke(isActive ? COLORS.accent : "#FFFFFF", isActive ? COLORS.accent : COLORS.border);
  doc.font("Helvetica-Bold").fontSize(7).fillColor(isActive ? COLORS.primary : COLORS.secondary).text(label, x - 40, y - 18, { width: 80, align: "center", characterSpacing: 0.5 });
  if (dateStr && dateStr !== "N/A") {
    doc.font("Helvetica").fontSize(8).fillColor(COLORS.secondary).text(dateStr, x - 40, y + 10, { width: 80, align: "center" });
  }
}

/**
 * Draw Shield
 */
function drawPremiumShield(doc: typeof PDFDocument, x: number, y: number, scale: number = 1) {
  doc.save().translate(x, y).scale(scale);
  doc.path('M -15 -20 L 0 -25 L 15 -20 L 15 0 C 15 15 0 25 0 25 C 0 25 -15 15 -15 0 Z')
     .lineWidth(1.5).strokeColor(COLORS.warning).fillAndStroke(COLORS.surface, COLORS.warning);
  doc.path('M -4 2 L -1 6 L 6 -3').lineWidth(2).strokeColor(COLORS.warning).stroke();
  doc.restore();
}

/**
 * 🚀 FIXED: Global Footer Function (Mentions Légales)
 */
function drawGlobalFooter(doc: typeof PDFDocument) {
  const originalBottomMargin = doc.page.margins.bottom;
  doc.page.margins.bottom = 0;

  const bottomY = doc.page.height - 35;

  doc.font("Helvetica").fontSize(6).fillColor(COLORS.secondary);

  const legalLine = "SARL BOITEX INFO : RC 01B0017926  •  NIF 000116001792641  •  ART 16124106515";
  doc.text(legalLine, MARGIN, bottomY, { align: "center", width: doc.page.width - MARGIN * 2 });

  const contactLine = "Adresse : 116 Rue des 3 frères Djillali, Birkhadem 16029  •  Téléphone : 023 56 20 85";
  doc.text(contactLine, MARGIN, bottomY + 10, { align: "center", width: doc.page.width - MARGIN * 2 });

  doc.page.margins.bottom = originalBottomMargin;
}

/**
 * ✅ MAIN GENERATOR FUNCTION
 */
export async function generateInstallationPdf(data: any): Promise<Buffer> {
  return new Promise(async (resolve, reject) => {
    try {
      const doc = new PDFDocument({
        size: "A4",
        margin: MARGIN,
        bufferPages: true,
        info: { Title: `Service Fait - ${data.installationCode || "Draft"}`, Author: "Boitex Info" },
      });

      const chunks: Buffer[] = [];
      doc.on("data", (chunk) => chunks.push(chunk));
      doc.on("end", () => resolve(Buffer.concat(chunks)));

      const [logoBuffer, clientSigBuffer, cacheBuffer] = await Promise.all([
        fetchImage(LOGO_URL), fetchImage(data.signatureUrl), fetchImage(CACHE_URL),
      ]);

      // =========================================================================
      // 📄 PAGE 1: ATTESTATION DE SERVICE FAIT
      // =========================================================================
      let y = MARGIN;

      if (logoBuffer) doc.image(logoBuffer, MARGIN, y - 20, { width: 100 });

      doc.font("Helvetica-Bold").fontSize(10).fillColor(COLORS.secondary)
         .text("ATTESTATION DE SERVICE FAIT", 0, y + 5, { align: "right", characterSpacing: 1.5 });

      const statusText = data.status === "Terminée" ? data.installationCode : "BROUILLON / EN COURS";
      doc.font("Helvetica-Bold").fontSize(18).fillColor(COLORS.primary)
         .text(statusText, 0, y + 20, { align: "right" });

      const serviceType = (data.serviceType || "Service Technique").toUpperCase();
      doc.font("Helvetica-Bold").fontSize(8).fillColor(COLORS.accent)
         .text(serviceType, 0, y + 45, { align: "right", characterSpacing: 1 });

      y += 80;

      // --- SMART VECTOR TIMELINE ---
      const timelineY = y + 15;
      const startX = MARGIN + 30;
      const endX = doc.page.width - MARGIN - 30;
      const midX = doc.page.width / 2;

      const isCompleted = data.status === "Terminée" || !!data.completedAt;
      const isPlanned = !!data.installationDate || isCompleted;

      doc.moveTo(startX, timelineY).lineTo(endX, timelineY).lineWidth(1.5).strokeColor(COLORS.border).stroke();
      if (isCompleted) {
        doc.moveTo(startX, timelineY).lineTo(endX, timelineY).lineWidth(1.5).strokeColor(COLORS.accent).stroke();
      } else if (isPlanned) {
        doc.moveTo(startX, timelineY).lineTo(midX, timelineY).lineWidth(1.5).strokeColor(COLORS.accent).stroke();
      }

      drawTimelineStep(doc, startX, timelineY, "CREATION", formatDate(data.createdAt), true);
      drawTimelineStep(doc, midX, timelineY, "PLANIFICATION", data.installationDate ? formatDate(data.installationDate) : "", isPlanned);
      drawTimelineStep(doc, endX, timelineY, "CLOTURE", isCompleted ? formatDate(data.completedAt, true) : "", isCompleted);

      y = timelineY + 45;

      // --- 🌐 INTERACTIVE CLIENT & SITE CARDS ---
      const cardWidth = (doc.page.width - (MARGIN * 2) - 20) / 2;
      const cardHeight = 85;

      doc.roundedRect(MARGIN, y, cardWidth, cardHeight, 8).fill(COLORS.surface);
      let textY = y + 12;
      doc.font("Helvetica-Bold").fontSize(8).fillColor(COLORS.secondary).text("CLIENT", MARGIN + 12, textY, { characterSpacing: 1 });
      doc.font("Helvetica-Bold").fontSize(12).fillColor(COLORS.primary).text(data.clientName || "Non spécifié", MARGIN + 12, textY + 14);

      doc.font("Helvetica-Bold").fontSize(9).fillColor(COLORS.secondary).text(`Contact: `, MARGIN + 12, textY + 30, { continued: true });
      doc.font("Helvetica").fillColor(COLORS.primary).text(data.contactName || "N/A");

      drawSmartLink(doc, "Tel: ", data.clientPhone, data.clientPhone ? `tel:${data.clientPhone.replace(/\s+/g, '')}` : null, MARGIN + 12, textY + 42);
      drawSmartLink(doc, "Email: ", data.clientEmail, data.clientEmail ? `mailto:${data.clientEmail}` : null, MARGIN + 12, textY + 54);

      const rightCardX = MARGIN + cardWidth + 20;
      doc.roundedRect(rightCardX, y, cardWidth, cardHeight, 8).fill(COLORS.surface);
      doc.font("Helvetica-Bold").fontSize(8).fillColor(COLORS.secondary).text("SITE D'INTERVENTION", rightCardX + 12, textY, { characterSpacing: 1 });
      doc.font("Helvetica-Bold").fontSize(12).fillColor(COLORS.primary).text(data.storeName || "Magasin", rightCardX + 12, textY + 14);
      doc.font("Helvetica-Bold").fontSize(9).fillColor(COLORS.secondary).text(`Adresse: `, rightCardX + 12, textY + 30);

      if (data.storeLocation) {
         const mapUrl = `https://maps.google.com/?q=${encodeURIComponent(data.storeName + ' ' + data.storeLocation)}`;
         doc.font("Helvetica").fontSize(9).fillColor(COLORS.accent).text(data.storeLocation, rightCardX + 12, textY + 42, { width: cardWidth - 24, link: mapUrl, underline: true });
      } else {
         doc.font("Helvetica").fontSize(9).fillColor(COLORS.primary).text("N/A", rightCardX + 12, textY + 42);
      }

      y += cardHeight + 20;

      // =========================================================================
      // 📝 TECHNICIAN NOTES (COMPACT INLINE STYLING) 🔥
      // =========================================================================
      if (data.notes && typeof data.notes === 'string' && data.notes.trim() !== "") {
        const notesText = data.notes.trim();

        // Use inline text to save massive space: "RAPPORT TECHNIQUE: [notes text here...]"
        const inlineText = `RAPPORT TECHNIQUE : ${notesText}`;

        doc.font("Helvetica").fontSize(9);
        const textWidth = doc.page.width - (MARGIN * 2) - 24;

        const textHeight = doc.heightOfString(inlineText, { width: textWidth, lineGap: 2 });
        // Significantly reduced padding
        const boxHeight = textHeight + 20;

        y = checkPageBreak(doc, y, boxHeight + 15);

        doc.roundedRect(MARGIN, y, doc.page.width - (MARGIN * 2), boxHeight, 6).fill(COLORS.surface);

        // Draw title and text on the SAME line using {continued: true}
        doc.font("Helvetica-Bold").fontSize(8).fillColor(COLORS.secondary)
           .text("RAPPORT TECHNIQUE : ", MARGIN + 12, y + 10, { continued: true })
           .font("Helvetica").fontSize(9).fillColor(COLORS.primary)
           .text(notesText, { width: textWidth, lineGap: 2 });

        y += boxHeight + 15;
      }

      // =========================================================================
      // 🧠 SMART LAYOUT CALCULATOR (TABLE VS SIGNATURES)
      // =========================================================================
      const systems = data.systems || data.orderedProducts || [];

      // --- HELPER FUNCTION: Draw Compact Premium Signature Card --- 🔥
      const drawSignatureCard = (currentY: number) => {
        const cardHeight = 135; // Squeezed height down from 170!

        let sy = checkPageBreak(doc, currentY, cardHeight + 10);

        // 1. Draw the Premium Card Background
        doc.roundedRect(MARGIN, sy, doc.page.width - (MARGIN * 2), cardHeight, 8).fill(COLORS.surface);

        let innerY = sy + 10;
        const halfWidth = doc.page.width / 2;

        // 2. Left Side: EQUIPE BOITEX INFO
        doc.font("Helvetica-Bold").fontSize(9).fillColor(COLORS.secondary)
           .text("EQUIPE BOITEX INFO", MARGIN + 15, innerY, { characterSpacing: 1 });

        let techNames = "Service Technique";
        if (data.assignedTechnicianNames && Array.isArray(data.assignedTechnicianNames) && data.assignedTechnicianNames.length > 0) {
            techNames = data.assignedTechnicianNames.join("\n");
        }
        doc.font("Helvetica-Bold").fontSize(11).fillColor(COLORS.primary).text(techNames, MARGIN + 15, innerY + 15);
        if (cacheBuffer) doc.image(cacheBuffer, MARGIN + 15, innerY + 28, { width: 75 }); // Lifted image up

        // 3. Right Side: SIGNATURE CLIENT
        doc.font("Helvetica-Bold").fontSize(9).fillColor(COLORS.secondary)
           .text("SIGNATURE CLIENT", halfWidth, innerY, { characterSpacing: 1 });

        const signatory = data.signatoryName || data.contactName || "Client";
        doc.font("Helvetica-Bold").fontSize(11).fillColor(COLORS.primary).text(signatory, halfWidth, innerY + 15);
        if (clientSigBuffer) doc.image(clientSigBuffer, halfWidth, innerY + 25, { width: 130, height: 50, fit: [130, 50] }); // Squeezed image

        // 4. Legal Text (Tucked tightly at the bottom)
        innerY += 80; // Lifted from 100
        doc.rect(MARGIN + 15, innerY, 3, 30).fill(COLORS.accent);
        doc.font("Helvetica-Oblique").fontSize(8).fillColor(COLORS.secondary) // Made font slightly smaller
           .text("Par la presente, le signataire atteste que les equipements detailles ci-dessous (s'il y a lieu) ont ete livres, installes, configures et testes avec succes par l'equipe technique de BOITEX INFO, et declare l'installation conforme aux attentes.", MARGIN + 25, innerY + 2, { width: doc.page.width - MARGIN * 2 - 45, lineGap: 1 });

        return sy + cardHeight + 15;
      };

      // --- HELPER FUNCTION: Draw Equipment Table ---
      const drawTable = (currentY: number) => {
        let ty = checkPageBreak(doc, currentY, 100);
        doc.font("Helvetica-Bold").fontSize(9).fillColor(COLORS.secondary).text("MATERIEL INSTALLE & CONFIGURATIONS", MARGIN, ty, { characterSpacing: 1 });
        ty += 15;

        // 🛠️ Extracted Header Drawing so we can reuse it on page breaks
        const drawTableHeader = (yPos: number) => {
          doc.font("Helvetica-Bold").fontSize(8).fillColor(COLORS.secondary);
          doc.text("DESIGNATION", MARGIN, yPos);
          doc.text("REFERENCE", 250, yPos);
          doc.text("QTE", doc.page.width - MARGIN - 30, yPos, { width: 30, align: "right" });
          yPos += 10;
          doc.moveTo(MARGIN, yPos).lineTo(doc.page.width - MARGIN, yPos).lineWidth(0.5).strokeColor(COLORS.border).stroke();
          return yPos + 10;
        };

        ty = drawTableHeader(ty);

        for (const item of systems) {
          const qty = parseInt(item.quantity?.toString() || "1", 10);

          // 🚀 SMART FIX: Pre-calculate only lines that ACTUALLY have data!
          // This prevents bulk items (Qty: 1000) from creating a massive empty row height.
          let configLinesToDraw: string[] = [];

          if (item.serialNumbers || item.ipAddresses || item.macAddresses) {
            // Safety limit: Check up to qty, but max 500 to prevent infinite loops on crazy data
            const loopMax = Math.min(qty, 500);

            for (let i = 0; i < loopMax; i++) {
              let configLine = `Unité #${i + 1} -> `;
              let hasConfig = false;

              const sn = item.serialNumbers && item.serialNumbers.length > i ? item.serialNumbers[i] : "";
              const ip = item.ipAddresses && item.ipAddresses.length > i ? item.ipAddresses[i] : "";
              const mac = item.macAddresses && item.macAddresses.length > i ? item.macAddresses[i] : "";

              if (sn && sn.trim() !== "") { configLine += `S/N: ${sn}   `; hasConfig = true; }
              if (ip && ip.trim() !== "") { configLine += `IP: ${ip}   `; hasConfig = true; }
              if (mac && mac.trim() !== "") { configLine += `MAC: ${mac}   `; hasConfig = true; }

              if (hasConfig) {
                 configLinesToDraw.push(configLine);
              }
            }
          }

          // Row height is now strictly based on ACTUAL configurations found, not `qty`!
          const calculatedRowHeight = 20 + (configLinesToDraw.length * 14) + 10;

          // 🛠️ Pagination Check: If this item spills to a new page, redraw the headers!
          if (ty + calculatedRowHeight > doc.page.height - MARGIN - 30) {
             doc.addPage();
             ty = MARGIN + 20;
             doc.font("Helvetica-Bold").fontSize(9).fillColor(COLORS.secondary).text("MATERIEL INSTALLE & CONFIGURATIONS (Suite)", MARGIN, ty, { characterSpacing: 1 });
             ty += 15;
             ty = drawTableHeader(ty);
          }

          doc.font("Helvetica-Bold").fontSize(10).fillColor(COLORS.primary).text(item.name || "Produit Inconnu", MARGIN, ty, { width: 190 });
          doc.font("Helvetica").fontSize(9).fillColor(COLORS.secondary).text(item.reference || "N/A", 250, ty);
          doc.font("Helvetica-Bold").fontSize(11).fillColor(COLORS.primary).text(qty.toString(), doc.page.width - MARGIN - 30, ty, { width: 30, align: "right" });

          let lineY = doc.y + 4;

          // Draw the pre-calculated lines safely
          for (const config of configLinesToDraw) {
             doc.font("Helvetica").fontSize(8).fillColor(COLORS.secondary).text(config, MARGIN + 10, lineY);
             lineY += 14;
          }

          ty = lineY + 6;
          doc.moveTo(MARGIN, ty).lineTo(doc.page.width - MARGIN, ty).lineWidth(0.5).strokeColor(COLORS.border).stroke();
          ty += 10;
        }
        return ty + 10;
      };

      // 🚀 3. EXECUTE THE SMART RENDERER (Strict Linear Flow)
      if (systems.length > 0) {
          y = drawTable(y);
      }

      // Finally, draw the Signature Card! Because of our tighter design, it will fit seamlessly.
      y = drawSignatureCard(y);

      // =========================================================================
      // 🛡️ PAGE 2 (OR 3): CERTIFICAT DE GARANTIE
      // =========================================================================
      doc.addPage();
      let certY = MARGIN + 20;

      drawPremiumShield(doc, doc.page.width / 2, certY, 1.8);
      certY += 45;

      doc.font("Helvetica-Bold").fontSize(18).fillColor(COLORS.primary)
         .text("CERTIFICAT DE GARANTIE", MARGIN, certY, { align: "center", characterSpacing: 2 });

      certY += 25;
      doc.font("Helvetica-Bold").fontSize(11).fillColor(COLORS.warning)
         .text("GARANTIE CONSTRUCTEUR & INSTALLATION : 1 AN", MARGIN, certY, { align: "center", characterSpacing: 1 });

      const startDateObj = parseFirebaseDate(data.completedAt || data.updatedAt);
      const endDateObj = new Date(startDateObj);
      endDateObj.setFullYear(endDateObj.getFullYear() + 1);

      const dateOptions: Intl.DateTimeFormatOptions = { day: '2-digit', month: 'long', year: 'numeric' };
      doc.font("Helvetica").fontSize(10).fillColor(COLORS.secondary)
         .text(`Valable du ${startDateObj.toLocaleDateString('fr-FR', dateOptions)} au ${endDateObj.toLocaleDateString('fr-FR', dateOptions)}`, MARGIN, certY + 15, { align: "center" });

      certY += 60;

      doc.font("Helvetica-Bold").fontSize(12).fillColor(COLORS.primary).text("1. CE QUI EST COUVERT", MARGIN, certY);
      certY += 18;
      doc.font("Helvetica").fontSize(10).fillColor(COLORS.secondary)
         .text("Boitex Info garantit la qualite de son installation et la configuration materielle. En cas de dysfonctionnement lie a notre intervention ou a un defaut materiel d'usine pendant la periode de validite, notre equipe technique interviendra gratuitement pour le diagnostic et la remise en service.", MARGIN, certY, { lineGap: 4, width: doc.page.width - MARGIN * 2 });

      certY = doc.y + 35;

      doc.font("Helvetica-Bold").fontSize(12).fillColor(COLORS.danger).text("2. EXCLUSIONS DE GARANTIE", MARGIN, certY);
      certY += 18;

      const drawExclusion = (title: string, text: string, yPos: number) => {
          doc.circle(MARGIN + 5, yPos + 4, 3).fill(COLORS.danger);
          doc.font("Helvetica-Bold").fontSize(10).fillColor(COLORS.primary).text(title, MARGIN + 15, yPos);
          doc.font("Helvetica").fontSize(9).fillColor(COLORS.secondary)
             .text(text, MARGIN + 15, yPos + 14, { width: doc.page.width - MARGIN * 2 - 15, lineGap: 2 });
          return doc.y + 16;
      };

      certY = drawExclusion("Problemes Electriques", "Dommages causes par des surtensions, la foudre, ou l'absence d'un onduleur (UPS) adequat pour proteger les equipements sensibles.", certY);
      certY = drawExclusion("Degats Environnementaux", "Deterioration due a des degats des eaux, une humidite extreme, de la poussiere excessive, ou une exposition directe a des sources de chaleur.", certY);
      certY = drawExclusion("Mauvaise Utilisation & Casse", "Tout dommage physique (choc, chute, vandalisme, cable arrache) ou negligence causee par le personnel du site ou des clients.", certY);
      certY = drawExclusion("Intervention Tiers", "Toute modification, reinitialisation, deplacement de materiel ou reparation tentee par une personne non agreee par Boitex Info annulera immediatement cette garantie.", certY);

      certY += 20;

      doc.font("Helvetica-Bold").fontSize(12).fillColor(COLORS.accent).text("3. RECOMMANDATIONS D'UTILISATION", MARGIN, certY);
      certY += 18;
      doc.font("Helvetica").fontSize(10).fillColor(COLORS.secondary)
         .text("Pour assurer la longévité de votre matériel (TPV, portiques et compteurs), nous recommandons vivement l'utilisation d'un onduleur (UPS) pour l'ensemble de vos équipements afin de pallier les coupures brusques. Veillez également à ce que l'environnement d'installation reste toujours bien aéré et facilement accessible pour les opérations de maintenance.", MARGIN, certY, { lineGap: 4, width: doc.page.width - MARGIN * 2 });

      certY = doc.y + 15;

      // =========================================================================
      // 📱 SECTION 4: QR CODE & DIGITAL LINKS
      // =========================================================================

      certY = checkPageBreak(doc, certY, 75);

      doc.moveTo(MARGIN, certY).lineTo(doc.page.width - MARGIN, certY).lineWidth(0.5).strokeColor(COLORS.border).stroke();
      certY += 10;

      const verifyUrl = `https://boitexinfo.com`;
      const qrBuffer = await generateLocalQRCode(verifyUrl);

      if (qrBuffer) {
         doc.image(qrBuffer, MARGIN, certY, { width: 55 });
      } else {
         doc.rect(MARGIN, certY, 55, 55).lineWidth(1).strokeColor(COLORS.border).stroke();
         doc.font("Helvetica").fontSize(8).fillColor(COLORS.secondary).text("QR Code", MARGIN + 10, certY + 25);
      }

      const supportX = MARGIN + 70;
      doc.font("Helvetica-Bold").fontSize(9).fillColor(COLORS.primary).text("SUPPORT TECHNIQUE", supportX, certY);
      doc.font("Helvetica").fontSize(8).fillColor(COLORS.secondary)
         .text("Scannez ce QR Code avec l'appareil photo de votre smartphone pour acceder a notre portail, ou contactez-nous via les liens ci-contre.", supportX, certY + 12, { width: 190, lineGap: 1 });

      const socialX = doc.page.width - MARGIN - 150;
      doc.font("Helvetica-Bold").fontSize(9).fillColor(COLORS.primary).text("RESEAUX & CONTACT", socialX, certY);

      const drawSocial = (prefix: string, text: string, link: string, yPos: number) => {
         doc.font("Helvetica-Bold").fontSize(8).fillColor(COLORS.secondary).text(prefix, socialX, yPos, { continued: true });
         doc.font("Helvetica").fillColor(COLORS.accent).text(text, { link: link, underline: true });
      };

      drawSocial("WEB:  ", "Boitexinfo.com", "https://boitexinfo.com", certY + 15);
      drawSocial("YOUTUBE:  ", "@boitexinfo", "https://youtube.com/@boitexinfo8469", certY + 28);
      drawSocial("FACEBOOK:  ", "Boitex Info", "https://Facebook.com/boitexinfo", certY + 41);
      drawSocial("INSTAGRAM:  ", "@boitex_info", "https://instagram.com/boitex_info/", certY + 54);

      // =========================================================================
      // 📸 ANNEXE VISUELLE
      // =========================================================================
      const rawMediaUrls = data.mediaUrls || data.photoUrls || [];
      const imageList = rawMediaUrls.filter((url: string) => typeof url === 'string' && !url.match(/\.(mp4|mov|avi|mkv)(\?.*)?$/i));

      if (imageList.length > 0) {
        doc.addPage();
        let annexY = MARGIN + 20;

        doc.font("Helvetica-Bold").fontSize(18).fillColor(COLORS.primary)
           .text("ANNEXE VISUELLE", MARGIN, annexY, { align: "center", characterSpacing: 2 });
        annexY += 25;
        doc.font("Helvetica").fontSize(10).fillColor(COLORS.secondary)
           .text("Preuves photographiques de l'installation et de l'environnement materiel.", MARGIN, annexY, { align: "center" });

        annexY += 40;

        const maxImgWidth = (doc.page.width - (MARGIN * 2) - 20) / 2;
        const maxImgHeight = maxImgWidth * 0.75;
        let currentX = MARGIN;

        const downloadedImages = await Promise.all(
          imageList.map((url: string) => fetchImage(url))
        );

        for (const imgBuffer of downloadedImages) {
          if (imgBuffer) {
            if (annexY + maxImgHeight > doc.page.height - MARGIN - 40) {
              doc.addPage();
              annexY = MARGIN + 20;
              currentX = MARGIN;
            }

            doc.save();
            doc.roundedRect(currentX, annexY, maxImgWidth, maxImgHeight, 10).lineWidth(1).strokeColor(COLORS.border).stroke();

            try {
              doc.image(imgBuffer, currentX + 5, annexY + 5, {
                fit: [maxImgWidth - 10, maxImgHeight - 10],
                align: 'center',
                valign: 'center'
              });
            } catch(e) {
              logger.warn("Failed to process image buffer for PDF Annex");
            }
            doc.restore();

            if (currentX === MARGIN) {
              currentX = MARGIN + maxImgWidth + 20;
            } else {
              currentX = MARGIN;
              annexY += maxImgHeight + 20;
            }
          }
        }
      }

      // =========================================================================
      // 🏁 ADD GLOBAL FOOTERS ONLY TO PAGE 1 AND PAGE 2
      // =========================================================================

      const pageCount = doc.bufferedPageRange().count;
      const maxPagesToStamp = Math.min(pageCount, 2);

      for (let i = 0; i < maxPagesToStamp; i++) {
        doc.switchToPage(i);
        drawGlobalFooter(doc);
      }

      doc.end();
    } catch (error) {
      logger.error("Error generating installation PDF:", error);
      reject(error);
    }
  });
}