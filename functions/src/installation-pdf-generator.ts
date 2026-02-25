// functions/src/installation-pdf-generator.ts

import PDFDocument from "pdfkit";
import axios from "axios";
import * as logger from "firebase-functions/logger";

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
 * Fetch QR Code using an external free API
 */
async function fetchQRCode(text: string): Promise<Buffer | null> {
  try {
    const url = `https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(text)}&margin=0`;
    const response = await axios.get(url, { responseType: "arraybuffer", timeout: 5000 });
    return Buffer.from(response.data);
  } catch (e) {
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
 * ✅ MAIN GENERATOR FUNCTION
 */
export async function generateInstallationPdf(data: any): Promise<Buffer> {
  return new Promise(async (resolve, reject) => {
    try {
      const doc = new PDFDocument({
        size: "A4",
        margin: MARGIN,
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

      y += cardHeight + 25;

      // --- LEGAL DECLARATION ---
      y = checkPageBreak(doc, y, 50);
      doc.rect(MARGIN, y, 3, 30).fill(COLORS.accent);
      doc.font("Helvetica-Oblique").fontSize(9).fillColor(COLORS.secondary)
         .text("Par la presente, le signataire atteste que les equipements detailles ci-dessous ont ete livres, installes, configures et testes avec succes par l'equipe technique de BOITEX INFO, et declare l'installation conforme aux attentes.", MARGIN + 12, y + 2, { width: doc.page.width - MARGIN * 2 - 12, lineGap: 2 });
      y += 45;

      // --- EQUIPMENT TABLE ---
      const systems = data.systems || data.orderedProducts || [];
      if (systems.length > 0) {
        y = checkPageBreak(doc, y, 100);

        doc.font("Helvetica-Bold").fontSize(9).fillColor(COLORS.secondary).text("MATERIEL INSTALLE & CONFIGURATIONS", MARGIN, y, { characterSpacing: 1 });
        y += 20;

        doc.font("Helvetica-Bold").fontSize(8).fillColor(COLORS.secondary);
        doc.text("DESIGNATION", MARGIN, y);
        doc.text("REFERENCE", 250, y);
        doc.text("QTE", doc.page.width - MARGIN - 30, y, { width: 30, align: "right" });

        y += 12;
        doc.moveTo(MARGIN, y).lineTo(doc.page.width - MARGIN, y).lineWidth(0.5).strokeColor(COLORS.border).stroke();
        y += 12;

        for (const item of systems) {
          const qty = parseInt(item.quantity?.toString() || "1", 10);
          const rowHeight = 20 + (qty * 14) + 10;
          y = checkPageBreak(doc, y, rowHeight);

          doc.font("Helvetica-Bold").fontSize(10).fillColor(COLORS.primary).text(item.name || "Produit Inconnu", MARGIN, y, { width: 190 });
          doc.font("Helvetica").fontSize(9).fillColor(COLORS.secondary).text(item.reference || "N/A", 250, y);
          doc.font("Helvetica-Bold").fontSize(11).fillColor(COLORS.primary).text(qty.toString(), doc.page.width - MARGIN - 30, y, { width: 30, align: "right" });

          let currentY = doc.y + 5;

          if (item.serialNumbers || item.ipAddresses || item.macAddresses) {
            for (let i = 0; i < qty; i++) {
              let configLine = `Unite #${i + 1} -> `;
              const sn = item.serialNumbers ? item.serialNumbers[i] : "";
              const ip = item.ipAddresses ? item.ipAddresses[i] : "";
              const mac = item.macAddresses ? item.macAddresses[i] : "";

              if (sn) configLine += `S/N: ${sn}   `;
              if (ip) configLine += `IP: ${ip}   `;
              if (mac) configLine += `MAC: ${mac}   `;

              if (configLine.length > 15) {
                 doc.font("Helvetica").fontSize(8).fillColor(COLORS.secondary).text(configLine, MARGIN + 10, currentY);
                 currentY += 14;
              }
            }
          }

          y = currentY + 8;
          doc.moveTo(MARGIN, y).lineTo(doc.page.width - MARGIN, y).lineWidth(0.5).strokeColor(COLORS.border).stroke();
          y += 12;
        }
      }

      y += 10;

      // --- SIGNATURE BLOCK ---
      y = checkPageBreak(doc, y, 150);
      doc.moveTo(MARGIN, y).lineTo(doc.page.width - MARGIN, y).lineWidth(0.5).strokeColor(COLORS.border).stroke();
      y += 15;

      const halfWidth = doc.page.width / 2;

      doc.font("Helvetica-Bold").fontSize(9).fillColor(COLORS.primary).text("EQUIPE BOITEX INFO", MARGIN, y, { characterSpacing: 1 });
      let techNames = "Service Technique";
      if (data.assignedTechnicianNames && Array.isArray(data.assignedTechnicianNames) && data.assignedTechnicianNames.length > 0) {
          techNames = data.assignedTechnicianNames.join("\n");
      }
      doc.font("Helvetica").fontSize(10).fillColor(COLORS.secondary).text(techNames, MARGIN, y + 15);
      if (cacheBuffer) doc.image(cacheBuffer, MARGIN, y + 40, { width: 90 });

      doc.font("Helvetica-Bold").fontSize(9).fillColor(COLORS.primary).text("SIGNATURE CLIENT", halfWidth, y, { characterSpacing: 1 });
      const signatory = data.signatoryName || data.contactName || "Client";
      doc.font("Helvetica").fontSize(10).fillColor(COLORS.secondary).text(signatory, halfWidth, y + 15);
      if (clientSigBuffer) doc.image(clientSigBuffer, halfWidth, y + 30, { width: 150, height: 70, fit: [150, 70] });


      // =========================================================================
      // 🛡️ PAGE 2: CERTIFICAT DE GARANTIE
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

      certY = doc.y + 35;

      // 📱 SECTION 4: QR CODE & DIGITAL LINKS
      certY = checkPageBreak(doc, certY, 120);
      doc.moveTo(MARGIN, certY).lineTo(doc.page.width - MARGIN, certY).lineWidth(0.5).strokeColor(COLORS.border).stroke();
      certY += 20;

      const verifyUrl = `https://boitexinfo.com`;
      const qrBuffer = await fetchQRCode(verifyUrl);

      if (qrBuffer) {
         doc.image(qrBuffer, MARGIN, certY, { width: 70 });
      } else {
         doc.rect(MARGIN, certY, 70, 70).lineWidth(1).strokeColor(COLORS.border).stroke();
         doc.font("Helvetica").fontSize(8).fillColor(COLORS.secondary).text("QR Code", MARGIN + 15, certY + 30);
      }

      const supportX = MARGIN + 90;
      doc.font("Helvetica-Bold").fontSize(10).fillColor(COLORS.primary).text("SUPPORT TECHNIQUE", supportX, certY);
      doc.font("Helvetica").fontSize(9).fillColor(COLORS.secondary).text("Scannez ce QR Code avec l'appareil photo de votre smartphone pour acceder a notre portail, ou contactez-nous via les liens ci-contre.", supportX, certY + 15, { width: 180, lineGap: 2 });

      const socialX = doc.page.width - MARGIN - 160;
      doc.font("Helvetica-Bold").fontSize(10).fillColor(COLORS.primary).text("RESEAUX & CONTACT", socialX, certY);

      const drawSocial = (prefix: string, text: string, link: string, yPos: number) => {
         doc.font("Helvetica-Bold").fontSize(8).fillColor(COLORS.secondary).text(prefix, socialX, yPos, { continued: true });
         doc.font("Helvetica").fillColor(COLORS.accent).text(text, { link: link, underline: true });
      };

      drawSocial("WEB:  ", "Boitexinfo.com", "https://boitexinfo.com", certY + 15);
      drawSocial("YOUTUBE:  ", "@boitexinfo8469", "https://youtube.com/@boitexinfo8469", certY + 30);
      drawSocial("FACEBOOK:  ", "Boitex Info", "https://Facebook.com/boitexinfo", certY + 45);
      drawSocial("INSTAGRAM:  ", "@boitex_info", "https://instagram.com/boitex_info/", certY + 60);

      // =========================================================================
      // 📸 PAGE 3: ANNEXE VISUELLE (If Photos Exist)
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

        for (let i = 0; i < imageList.length; i++) {
          const imgBuffer = await fetchImage(imageList[i]);

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

      doc.end();
    } catch (error) {
      logger.error("Error generating installation PDF:", error);
      reject(error);
    }
  });
}