import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../features/invoices/domain/invoice_model.dart';
import '../features/customers/domain/customer_model.dart';
import '../features/settings/domain/business_model.dart';

/// Defines the available PDF invoice template styles.
enum InvoiceTemplateStyle {
  eInvoiceStatutory,
  modernExecutive,
  classicBrown,
}

/// Service responsible for generating and sharing styled PDF invoices.
class InvoicePdfService {
  InvoicePdfService._();

  // Modern Executive Design Palette
  static const _navyDark = PdfColor.fromInt(0xFF0F172A);      // Slate 900
  static const _navyPrimary = PdfColor.fromInt(0xFF1E293B);   // Slate 800
  static const _accentBlue = PdfColor.fromInt(0xFF2563EB);    // Vibrant Blue
  static const _bgLight = PdfColor.fromInt(0xFFF8FAFC);       // Slate 50
  static const _bgCard = PdfColor.fromInt(0xFFF1F5F9);        // Slate 100
  static const _textPrimary = PdfColor.fromInt(0xFF0F172A);   // High-contrast dark
  static const _textSecondary = PdfColor.fromInt(0xFF64748B); // Slate 500
  static const _textMuted = PdfColor.fromInt(0xFF94A3B8);     // Slate 400
  static const _border = PdfColor.fromInt(0xFFCBD5E1);        // Slate 300
  static const _borderLight = PdfColor.fromInt(0xFFE2E8F0);   // Slate 200
  static const _white = PdfColors.white;

  // Status & semantic colors
  static const _successGreen = PdfColor.fromInt(0xFF16A34A);  // Green 600
  static const _successBg = PdfColor.fromInt(0xFFDCFCE7);     // Green 100
  static const _errorRed = PdfColor.fromInt(0xFFDC2626);      // Red 600
  static const _errorBg = PdfColor.fromInt(0xFFFEE2E2);       // Red 100
  static const _warningAmber = PdfColor.fromInt(0xFFD97706);  // Amber 600
  static const _warningBg = PdfColor.fromInt(0xFFFEF3C7);     // Amber 100

  // Classic Brown Palette (preserved for backwards compatibility)
  static const _classicPrimary = PdfColor.fromInt(0xFF4E342E);
  static const _classicAccent = PdfColor.fromInt(0xFFD7CCC8);
  static const _classicBgLight = PdfColor.fromInt(0xFFFAFAFA);
  static const _classicDivider = PdfColor.fromInt(0xFFE0E0E0);

  /// Generates the raw PDF bytes for an invoice.
  static Future<Uint8List> generateInvoicePdfBytes({
    required InvoiceModel invoice,
    required CustomerModel? customer,
    required BusinessModel? business,
    required double amountPaid,
    InvoiceTemplateStyle style = InvoiceTemplateStyle.eInvoiceStatutory,
  }) async {
    final pdf = pw.Document();

    // Load fonts that support the Rupee symbol (₹)
    final ttf = await PdfGoogleFonts.notoSansRegular();
    final ttfBold = await PdfGoogleFonts.notoSansBold();

    final outstanding = (invoice.total - amountPaid).clamp(0.0, double.infinity);

    if (style == InvoiceTemplateStyle.eInvoiceStatutory) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) => [
            _buildEInvoiceStatutoryPage(
              invoice: invoice,
              customer: customer,
              business: business,
              amountPaid: amountPaid,
              outstanding: outstanding,
              ttf: ttf,
              ttfBold: ttfBold,
            ),
          ],
        ),
      );
    } else if (style == InvoiceTemplateStyle.modernExecutive) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          build: (pw.Context context) => [
            _buildExecutiveHeader(
              invoice: invoice,
              business: business,
              ttf: ttf,
              ttfBold: ttfBold,
            ),
            pw.SizedBox(height: 14),
            _buildExecutiveBillAndSummary(
              invoice: invoice,
              customer: customer,
              outstanding: outstanding,
              ttf: ttf,
              ttfBold: ttfBold,
            ),
            pw.SizedBox(height: 16),
            _buildExecutiveItemsTable(
              invoice: invoice,
              ttf: ttf,
              ttfBold: ttfBold,
            ),
            pw.SizedBox(height: 16),
            _buildExecutiveBottomSection(
              invoice: invoice,
              business: business,
              amountPaid: amountPaid,
              outstanding: outstanding,
              ttf: ttf,
              ttfBold: ttfBold,
            ),
          ],
          footer: (pw.Context context) => _buildExecutiveFooter(
            business: business,
            invoice: invoice,
            ttf: ttf,
            ttfBold: ttfBold,
            pageNumber: context.pageNumber,
            pagesCount: context.pagesCount,
          ),
        ),
      );
    } else {
      // Classic Brown Style
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          build: (pw.Context context) => [
            _buildClassicPage(
              invoice: invoice,
              customer: customer,
              business: business,
              amountPaid: amountPaid,
              outstanding: outstanding,
              ttf: ttf,
              ttfBold: ttfBold,
            ),
          ],
          footer: (pw.Context context) => _classicFooter(
            business: business,
            invoice: invoice,
            ttf: ttf,
            ttfBold: ttfBold,
            pageNumber: context.pageNumber,
            pagesCount: context.pagesCount,
          ),
        ),
      );
    }

    return await pdf.save();
  }

  /// Generates and shares a PDF invoice via the system share sheet.
  static Future<void> shareInvoicePdf({
    required InvoiceModel invoice,
    required CustomerModel? customer,
    required BusinessModel? business,
    required double amountPaid,
    InvoiceTemplateStyle style = InvoiceTemplateStyle.eInvoiceStatutory,
  }) async {
    final bytes = await generateInvoicePdfBytes(
      invoice: invoice,
      customer: customer,
      business: business,
      amountPaid: amountPaid,
      style: style,
    );

    final rawCustomerName = (customer?.name ?? '').trim();
    final customerName = rawCustomerName.isNotEmpty
        ? rawCustomerName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        : 'Customer';
    final shareFilename = 'INV_$customerName-Invoice.pdf';

    await Printing.sharePdf(
      bytes: bytes,
      filename: shareFilename,
    );
  }

  // ===========================================================================
  // 🌟 BRAND NEW: MODERN EXECUTIVE DESIGN TEMPLATE
  // ===========================================================================

  /// Header with top accent bar, business logo/details on left, and invoice badge on right.
  static pw.Widget _buildExecutiveHeader({
    required InvoiceModel invoice,
    required BusinessModel? business,
    required pw.Font ttf,
    required pw.Font ttfBold,
  }) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final timeFormat = DateFormat('hh:mm a');

    // Status badge style
    PdfColor statusBg;
    PdfColor statusText;
    String statusTitle;

    switch (invoice.status) {
      case InvoiceStatus.paid:
        statusBg = _successBg;
        statusText = _successGreen;
        statusTitle = 'PAID IN FULL';
        break;
      case InvoiceStatus.partiallyPaid:
        statusBg = _warningBg;
        statusText = _warningAmber;
        statusTitle = 'PARTIALLY PAID';
        break;
      case InvoiceStatus.unpaid:
        statusBg = _errorBg;
        statusText = _errorRed;
        statusTitle = 'PAYMENT PENDING';
        break;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Top Dual Accent Ribbon
        pw.Row(
          children: [
            pw.Expanded(
              flex: 4,
              child: pw.Container(
                height: 4,
                decoration: const pw.BoxDecoration(
                  color: _navyPrimary,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                ),
              ),
            ),
            pw.SizedBox(width: 4),
            pw.Expanded(
              flex: 1,
              child: pw.Container(
                height: 4,
                decoration: const pw.BoxDecoration(
                  color: _accentBlue,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),

        // Main Header Row
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // Left: Business Identity
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (business?.logoUrl != null &&
                      business!.logoUrl!.isNotEmpty &&
                      !business.logoUrl!.startsWith('http') &&
                      File(business.logoUrl!).existsSync()) ...[
                    pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 8),
                      padding: const pw.EdgeInsets.all(3),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: _borderLight, width: 1),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Image(
                        pw.MemoryImage(File(business.logoUrl!).readAsBytesSync()),
                        height: 46,
                        width: 46,
                      ),
                    ),
                  ],
                  pw.Text(
                    business?.businessName ?? 'Mayuresh Gruh Udyog',
                    style: pw.TextStyle(
                      font: ttfBold,
                      fontSize: 18,
                      color: _navyDark,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  if (business?.address.isNotEmpty == true)
                    pw.Text(
                      business!.address,
                      style: pw.TextStyle(
                        font: ttf,
                        fontSize: 9,
                        color: _textSecondary,
                        lineSpacing: 1.2,
                      ),
                    ),
                  if (business?.phone.isNotEmpty == true) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Contact: ${business!.phone}',
                      style: pw.TextStyle(
                        font: ttf,
                        fontSize: 9,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                  // GST & FSSAI Badges
                  if ((business?.gstNumber?.isNotEmpty == true) ||
                      (business?.fssaiNumber?.isNotEmpty == true)) ...[
                    pw.SizedBox(height: 6),
                    pw.Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (business?.gstNumber?.isNotEmpty == true)
                          _pillTag(
                            'GSTIN: ${business!.gstNumber}',
                            ttf,
                            ttfBold,
                            color: _navyPrimary,
                            bgColor: _bgCard,
                          ),
                        if (business?.fssaiNumber?.isNotEmpty == true)
                          _pillTag(
                            'FSSAI: ${business!.fssaiNumber}',
                            ttf,
                            ttfBold,
                            color: _textSecondary,
                            bgColor: _bgCard,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            pw.SizedBox(width: 20),

            // Right: Invoice Meta & Status
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'TAX INVOICE',
                  style: pw.TextStyle(
                    font: ttfBold,
                    fontSize: 22,
                    color: _navyDark,
                    letterSpacing: 2,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: statusBg,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                    border: pw.Border.all(color: statusText, width: 0.5),
                  ),
                  child: pw.Text(
                    statusTitle,
                    style: pw.TextStyle(
                      font: ttfBold,
                      fontSize: 8.5,
                      color: statusText,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: _bgLight,
                    border: pw.Border.all(color: _borderLight),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _metaRow('Invoice No:', '#${invoice.invoiceNumber}', ttf, ttfBold),
                      pw.SizedBox(height: 3),
                      _metaRow('Date:', dateFormat.format(invoice.invoiceDate), ttf, ttfBold),
                      pw.SizedBox(height: 3),
                      _metaRow('Time:', timeFormat.format(invoice.createdAt), ttf, ttfBold),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _pillTag(
    String text,
    pw.Font ttf,
    pw.Font ttfBold, {
    required PdfColor color,
    required PdfColor bgColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: _border, width: 0.5),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: ttfBold, fontSize: 8, color: color),
      ),
    );
  }

  static pw.Widget _metaRow(String label, String value, pw.Font ttf, pw.Font ttfBold) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          '$label ',
          style: pw.TextStyle(font: ttf, fontSize: 8.5, color: _textSecondary),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: _navyDark),
        ),
      ],
    );
  }

  /// Bill To & Invoice Summary Banner side-by-side
  static pw.Widget _buildExecutiveBillAndSummary({
    required InvoiceModel invoice,
    required CustomerModel? customer,
    required double outstanding,
    required pw.Font ttf,
    required pw.Font ttfBold,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left: Bill To Card
        pw.Expanded(
          flex: 3,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: _bgLight,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: _borderLight),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 4,
                      height: 12,
                      decoration: const pw.BoxDecoration(
                        color: _accentBlue,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Text(
                      'BILLED TO',
                      style: pw.TextStyle(
                        font: ttfBold,
                        fontSize: 8.5,
                        color: _navyPrimary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                if (customer?.businessName?.isNotEmpty == true) ...[
                  pw.Text(
                    customer!.businessName!,
                    style: pw.TextStyle(font: ttfBold, fontSize: 11, color: _navyDark),
                  ),
                  pw.SizedBox(height: 2),
                ],
                pw.Text(
                  customer?.name ?? 'Walk-in Customer',
                  style: pw.TextStyle(
                    font: customer?.businessName?.isNotEmpty == true ? ttf : ttfBold,
                    fontSize: customer?.businessName?.isNotEmpty == true ? 9.5 : 11,
                    color: _navyDark,
                  ),
                ),
                if (customer?.mobile.isNotEmpty == true) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Mobile: ${customer!.mobile}',
                    style: pw.TextStyle(font: ttf, fontSize: 8.5, color: _textSecondary),
                  ),
                ],
                if (customer?.address.isNotEmpty == true) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Address: ${customer!.address}',
                    style: pw.TextStyle(font: ttf, fontSize: 8.5, color: _textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ),

        pw.SizedBox(width: 14),

        // Right: Fast Summary Card
        pw.Expanded(
          flex: 2,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: _bgLight,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: _borderLight),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 4,
                      height: 12,
                      decoration: const pw.BoxDecoration(
                        color: _navyPrimary,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Text(
                      'INVOICE TOTAL',
                      style: pw.TextStyle(
                        font: ttfBold,
                        fontSize: 8.5,
                        color: _navyPrimary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  '₹ ${invoice.total.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    font: ttfBold,
                    fontSize: 16,
                    color: _navyDark,
                  ),
                ),
                pw.SizedBox(height: 4),
                if (outstanding > 0)
                  pw.Text(
                    'Balance Due: ₹ ${outstanding.toStringAsFixed(2)}',
                    style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: _errorRed),
                  )
                else
                  pw.Text(
                    'Status: Fully Paid',
                    style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: _successGreen),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Modern Clean Data Table for Invoice Items
  static pw.Widget _buildExecutiveItemsTable({
    required InvoiceModel invoice,
    required pw.Font ttf,
    required pw.Font ttfBold,
  }) {
    const colWidths = {
      0: pw.FlexColumnWidth(0.5), // #
      1: pw.FlexColumnWidth(3.4), // Description
      2: pw.FlexColumnWidth(1.1), // HSN/SAC
      3: pw.FlexColumnWidth(0.8), // Qty
      4: pw.FlexColumnWidth(1.4), // Unit Price
      5: pw.FlexColumnWidth(1.4), // Amount
    };

    final headers = ['#', 'Item & Description', 'HSN/SAC', 'Qty', 'Unit Price', 'Total'];

    return pw.Table(
      columnWidths: colWidths,
      children: [
        // Header Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: _navyPrimary,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          children: headers.asMap().entries.map((entry) {
            final idx = entry.key;
            final title = entry.value;
            final isCenter = idx == 0 || idx == 2 || idx == 3;
            final isRight = idx == 4 || idx == 5;

            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: pw.Text(
                title,
                style: pw.TextStyle(
                  font: ttfBold,
                  fontSize: 8.5,
                  color: _white,
                  letterSpacing: 0.5,
                ),
                textAlign: isCenter
                    ? pw.TextAlign.center
                    : isRight
                        ? pw.TextAlign.right
                        : pw.TextAlign.left,
              ),
            );
          }).toList(),
        ),

        // Items Rows
        ...invoice.items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final isOdd = idx.isOdd;
          final bg = isOdd ? _bgLight : _white;
          final qtyStr = item.quantity % 1 == 0
              ? item.quantity.toInt().toString()
              : item.quantity.toStringAsFixed(2);

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: bg,
              border: const pw.Border(
                bottom: pw.BorderSide(color: _borderLight, width: 0.5),
              ),
            ),
            children: [
              // SR No
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                child: pw.Text(
                  '${idx + 1}',
                  style: pw.TextStyle(font: ttf, fontSize: 8.5, color: _textSecondary),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              // Item Name
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: pw.Text(
                  item.productName,
                  style: pw.TextStyle(font: ttfBold, fontSize: 9, color: _textPrimary),
                ),
              ),
              // HSN
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                child: pw.Text(
                  (item.hsnCode != null && item.hsnCode!.isNotEmpty) ? item.hsnCode! : '-',
                  style: pw.TextStyle(font: ttf, fontSize: 8.5, color: _textSecondary),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              // Qty
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                child: pw.Text(
                  qtyStr,
                  style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: _textPrimary),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              // Unit Price
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: pw.Text(
                  '₹ ${item.unitPrice.toStringAsFixed(2)}',
                  style: pw.TextStyle(font: ttf, fontSize: 8.5, color: _textPrimary),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              // Total
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: pw.Text(
                  '₹ ${item.total.toStringAsFixed(2)}',
                  style: pw.TextStyle(font: ttfBold, fontSize: 9, color: _navyDark),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  /// Bottom Section: Payment/UPI Details & Summary Card Side-by-side + Signature
  static pw.Widget _buildExecutiveBottomSection({
    required InvoiceModel invoice,
    required BusinessModel? business,
    required double amountPaid,
    required double outstanding,
    required pw.Font ttf,
    required pw.Font ttfBold,
  }) {
    final hasUpi = business?.upiId?.isNotEmpty == true;
    final upiLink = hasUpi
        ? 'upi://pay?pa=${business!.upiId}&pn=${Uri.encodeComponent(business.businessName)}&am=${outstanding.toStringAsFixed(2)}&cu=INR'
        : null;

    final hasBank = business != null &&
        (business.bankAccount?.isNotEmpty == true ||
            business.bankName?.isNotEmpty == true ||
            business.bankIfsc?.isNotEmpty == true);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left Column: Payment QR / Bank Details / Notes
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // UPI Quick Pay Box
                  if (hasUpi && upiLink != null) ...[
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: _bgLight,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: _borderLight),
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            decoration: pw.BoxDecoration(
                              color: _white,
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                              border: pw.Border.all(color: _borderLight),
                            ),
                            child: pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: upiLink,
                              width: 68,
                              height: 68,
                              color: _navyPrimary,
                            ),
                          ),
                          pw.SizedBox(width: 12),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'SCAN & PAY VIA UPI',
                                  style: pw.TextStyle(
                                    font: ttfBold,
                                    fontSize: 8.5,
                                    color: _accentBlue,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                pw.SizedBox(height: 3),
                                pw.Text(
                                  business!.upiId!,
                                  style: pw.TextStyle(
                                    font: ttfBold,
                                    fontSize: 9.5,
                                    color: _navyDark,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'Works with GPay, PhonePe, Paytm, BHIM',
                                  style: pw.TextStyle(
                                    font: ttf,
                                    fontSize: 7.5,
                                    color: _textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 10),
                  ],

                  // Bank Details Card
                  if (hasBank) ...[
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: _bgLight,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: _borderLight),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'BANK TRANSFER DETAILS',
                            style: pw.TextStyle(
                              font: ttfBold,
                              fontSize: 8,
                              color: _navyPrimary,
                              letterSpacing: 1.0,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Wrap(
                            spacing: 16,
                            runSpacing: 4,
                            children: [
                              if (business.bankName?.isNotEmpty == true)
                                _bankInfoPiece('Bank', business.bankName!, ttf, ttfBold),
                              if (business.bankAccount?.isNotEmpty == true)
                                _bankInfoPiece('Account #', business.bankAccount!, ttf, ttfBold),
                              if (business.bankIfsc?.isNotEmpty == true)
                                _bankInfoPiece('IFSC Code', business.bankIfsc!, ttf, ttfBold),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 10),
                  ],

                  // Invoice Notes
                  if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFFEFF6FF), // Blue 50
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        border: pw.Border.all(
                          color: const PdfColor.fromInt(0xFFBFDBFE), // Blue 200
                          width: 0.8,
                        ),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'NOTES',
                            style: pw.TextStyle(
                              font: ttfBold,
                              fontSize: 7.5,
                              color: _accentBlue,
                              letterSpacing: 1.0,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            invoice.notes!,
                            style: pw.TextStyle(font: ttf, fontSize: 8.5, color: _navyDark),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            pw.SizedBox(width: 18),

            // Right Column: Financial Summary Block
            pw.Expanded(
              flex: 4,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: _bgLight,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: _borderLight),
                ),
                child: pw.Column(
                  children: [
                    _summaryLine('Subtotal', '₹ ${invoice.subtotal.toStringAsFixed(2)}', ttf, ttfBold),
                    pw.SizedBox(height: 6),
                    _summaryLine('GST', '₹ ${invoice.gst.toStringAsFixed(2)}', ttf, ttfBold),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 8),
                      child: pw.Divider(color: _borderLight, height: 1),
                    ),
                    _summaryLine(
                      'Grand Total',
                      '₹ ${invoice.total.toStringAsFixed(2)}',
                      ttf,
                      ttfBold,
                      isBold: true,
                      size: 11,
                      color: _navyDark,
                    ),
                    pw.SizedBox(height: 6),
                    _summaryLine(
                      'Amount Paid',
                      '₹ ${amountPaid.toStringAsFixed(2)}',
                      ttf,
                      ttfBold,
                      color: _successGreen,
                    ),
                    pw.SizedBox(height: 8),
                    // Outstanding Badge
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: outstanding > 0 ? _errorBg : _successBg,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        border: pw.Border.all(
                          color: outstanding > 0 ? _errorRed : _successGreen,
                          width: 0.5,
                        ),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Balance Due',
                            style: pw.TextStyle(
                              font: ttfBold,
                              fontSize: 9.5,
                              color: outstanding > 0 ? _errorRed : _successGreen,
                            ),
                          ),
                          pw.Text(
                            '₹ ${outstanding.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              font: ttfBold,
                              fontSize: 11,
                              color: outstanding > 0 ? _errorRed : _successGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 18),

        // Signatory Line
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(
              width: 170,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'For ${business?.businessName ?? "Business"}',
                    style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: _textSecondary),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 4),
                  if (business?.signatureUrl != null &&
                      business!.signatureUrl!.isNotEmpty &&
                      !business.signatureUrl!.startsWith('http') &&
                      File(business.signatureUrl!).existsSync())
                    pw.Container(
                      height: 36,
                      child: pw.Image(
                        pw.MemoryImage(File(business.signatureUrl!).readAsBytesSync()),
                        height: 36,
                      ),
                    )
                  else
                    pw.Container(height: 36),
                  pw.Divider(color: _navyPrimary, thickness: 0.8),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Authorised Signatory',
                    style: pw.TextStyle(font: ttf, fontSize: 8, color: _textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _bankInfoPiece(String label, String value, pw.Font ttf, pw.Font ttfBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(font: ttf, fontSize: 7.5, color: _textSecondary)),
        pw.Text(value, style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: _navyDark)),
      ],
    );
  }

  static pw.Widget _summaryLine(
    String label,
    String value,
    pw.Font ttf,
    pw.Font ttfBold, {
    bool isBold = false,
    double size = 8.5,
    PdfColor color = _textPrimary,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: isBold ? ttfBold : ttf,
            fontSize: size,
            color: isBold ? color : _textSecondary,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: isBold ? ttfBold : ttf,
            fontSize: size,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Clean Modern Footer with Terms & Page numbers
  static pw.Widget _buildExecutiveFooter({
    required BusinessModel? business,
    required InvoiceModel invoice,
    required pw.Font ttf,
    required pw.Font ttfBold,
    required int pageNumber,
    required int pagesCount,
  }) {
    final terms = business?.termsAndConditions;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(color: _borderLight, thickness: 0.8),
        pw.SizedBox(height: 6),
        if (terms != null && terms.isNotEmpty) ...[
          pw.Text(
            'TERMS & CONDITIONS: $terms',
            style: pw.TextStyle(font: ttf, fontSize: 7, color: _textMuted),
          ),
          pw.SizedBox(height: 4),
        ],
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Thank you for your business!',
              style: pw.TextStyle(font: ttfBold, fontSize: 8, color: _navyPrimary),
            ),
            pw.Text(
              'Page $pageNumber of $pagesCount  •  Invoice #${invoice.invoiceNumber}',
              style: pw.TextStyle(font: ttf, fontSize: 7.5, color: _textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // 📜 LEGACY: CLASSIC BROWN TEMPLATE (Preserved for backwards compatibility)
  // ===========================================================================

  static pw.Widget _buildClassicPage({
    required InvoiceModel invoice,
    required CustomerModel? customer,
    required BusinessModel? business,
    required double amountPaid,
    required double outstanding,
    required pw.Font ttf,
    required pw.Font ttfBold,
  }) {
    final statusColor = _classicStatusColor(invoice.status);
    final dateFormat = DateFormat('dd MMM yyyy');

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 0),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Container(
            decoration: const pw.BoxDecoration(
              color: _classicPrimary,
              borderRadius: pw.BorderRadius.only(
                bottomLeft: pw.Radius.circular(16),
                bottomRight: pw.Radius.circular(16),
              ),
            ),
            padding: const pw.EdgeInsets.fromLTRB(32, 32, 32, 28),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (business?.logoUrl != null &&
                        business!.logoUrl!.isNotEmpty &&
                        !business.logoUrl!.startsWith('http') &&
                        File(business.logoUrl!).existsSync())
                      pw.Container(
                        margin: const pw.EdgeInsets.only(bottom: 8),
                        child: pw.Image(
                          pw.MemoryImage(File(business.logoUrl!).readAsBytesSync()),
                          height: 50,
                          width: 50,
                        ),
                      ),
                    pw.Text(
                      business?.businessName ?? 'Your Business',
                      style: pw.TextStyle(font: ttfBold, fontSize: 22, color: _white),
                    ),
                    pw.SizedBox(height: 4),
                    if (business?.address.isNotEmpty == true)
                      pw.Text(
                        business!.address,
                        style: pw.TextStyle(font: ttf, fontSize: 10, color: _classicAccent),
                      ),
                    if (business?.phone.isNotEmpty == true) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Ph: ${business!.phone}',
                        style: pw.TextStyle(font: ttf, fontSize: 10, color: _classicAccent),
                      ),
                    ],
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'INVOICE',
                      style: pw.TextStyle(
                        font: ttfBold,
                        fontSize: 28,
                        color: _white,
                        letterSpacing: 3,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: statusColor,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
                      ),
                      child: pw.Text(
                        invoice.status.name.toUpperCase(),
                        style: pw.TextStyle(font: ttfBold, fontSize: 10, color: _white),
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Invoice #${invoice.invoiceNumber}',
                      style: pw.TextStyle(font: ttfBold, fontSize: 10, color: _white),
                    ),
                    pw.Text(
                      dateFormat.format(invoice.invoiceDate),
                      style: pw.TextStyle(font: ttf, fontSize: 10, color: _classicAccent),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // Bill From / To
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _classicCard('BILL FROM', business?.businessName ?? '-', business?.address ?? '', ttf, ttfBold),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _classicCard('BILL TO', customer?.name ?? 'Customer', customer?.address ?? '', ttf, ttfBold),
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          // Items Table
          pw.Table(
            border: pw.TableBorder.all(color: _classicDivider, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _classicPrimary),
                children: ['#', 'Item', 'Qty', 'Rate', 'Amount']
                    .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(h, style: pw.TextStyle(font: ttfBold, fontSize: 9, color: _white)),
                        ))
                    .toList(),
              ),
              ...invoice.items.map((item) => pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('-', style: pw.TextStyle(font: ttf, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(item.productName, style: pw.TextStyle(font: ttf, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${item.quantity}', style: pw.TextStyle(font: ttf, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('₹${item.unitPrice.toStringAsFixed(2)}', style: pw.TextStyle(font: ttf, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('₹${item.total.toStringAsFixed(2)}', style: pw.TextStyle(font: ttfBold, fontSize: 9))),
                    ],
                  )),
            ],
          ),
          pw.SizedBox(height: 20),

          // Total Block
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 200,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(color: _classicBgLight, border: pw.Border.all(color: _classicDivider)),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total', style: pw.TextStyle(font: ttfBold, fontSize: 12)),
                      pw.Text('₹${invoice.total.toStringAsFixed(2)}', style: pw.TextStyle(font: ttfBold, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _classicCard(String title, String name, String address, pw.Font ttf, pw.Font ttfBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _classicBgLight,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _classicDivider),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: _textSecondary)),
          pw.SizedBox(height: 4),
          pw.Text(name, style: pw.TextStyle(font: ttfBold, fontSize: 11)),
          if (address.isNotEmpty)
            pw.Text(address, style: pw.TextStyle(font: ttf, fontSize: 9, color: _textSecondary)),
        ],
      ),
    );
  }

  static pw.Widget _classicFooter({
    required BusinessModel? business,
    required InvoiceModel invoice,
    required pw.Font ttf,
    required pw.Font ttfBold,
    required int pageNumber,
    required int pagesCount,
  }) {
    return pw.Container(
      color: _classicPrimary,
      padding: const pw.EdgeInsets.all(12),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Thank you for your business!', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: _white)),
          pw.Text('Page $pageNumber of $pagesCount', style: pw.TextStyle(font: ttf, fontSize: 8, color: _classicAccent)),
        ],
      ),
    );
  }

  static PdfColor _classicStatusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return _successGreen;
      case InvoiceStatus.unpaid:
        return _errorRed;
      case InvoiceStatus.partiallyPaid:
        return _warningAmber;
    }
  }

  // ===========================================================================
  // 🇮🇳 STATUTORY INDIAN GST e-INVOICE TEMPLATE (Exact Industry Grid Layout)
  // ===========================================================================

  static const _gstBlack = PdfColors.black;
  static const _gstBorderColor = PdfColor.fromInt(0xFF222222);
  static const _gstBgHeader = PdfColor.fromInt(0xFFEEEEEE);

  static pw.Widget _buildEInvoiceStatutoryPage({
    required InvoiceModel invoice,
    required CustomerModel? customer,
    required BusinessModel? business,
    required double amountPaid,
    required double outstanding,
    required pw.Font ttf,
    required pw.Font ttfBold,
  }) {
    final dateFormat = DateFormat('dd-MMM-yy');
    final ackDateFormat = DateFormat('dd-MMM-yy HH:mm');
    final bizName = business?.businessName.toUpperCase() ?? 'BUSINESS NAME';
    final panNo = business?.panNumber ?? (business?.gstNumber != null && business!.gstNumber!.length >= 12 ? business.gstNumber!.substring(2, 12) : '');
    final arnNo = business?.arnNumber;
    final msmeNo = business?.msmeNumber;
    final jurisdiction = (business?.jurisdictionCity ?? 'PUNE').toUpperCase();

    // Indian State Name / Code extraction
    String supplierState = 'Maharashtra';
    String supplierStateCode = '27';
    if (business?.gstNumber != null && business!.gstNumber!.length >= 2) {
      supplierStateCode = business.gstNumber!.substring(0, 2);
    }

    String? buyerState = customer?.stateName;
    String? buyerStateCode = customer?.stateCode;
    if (buyerStateCode == null && customer?.gstNumber != null && customer!.gstNumber!.length >= 2) {
      buyerStateCode = customer.gstNumber!.substring(0, 2);
    }

    // QR Code data: Official Indian e-Invoice signed format or UPI payload fallback
    final qrData = invoice.irn != null && invoice.irn!.isNotEmpty
        ? 'GST_EINVOICE|${business?.gstNumber ?? ''}|${invoice.invoiceNumber}|${dateFormat.format(invoice.invoiceDate)}|${invoice.total.toStringAsFixed(2)}|${invoice.gst.toStringAsFixed(2)}|${customer?.gstNumber ?? 'URP'}|${invoice.irn}|${invoice.ackNo ?? ''}'
        : (business?.upiId != null && business!.upiId!.isNotEmpty
            ? 'upi://pay?pa=${business.upiId}&pn=${Uri.encodeComponent(business.businessName)}&am=${invoice.total.toStringAsFixed(2)}&cu=INR&tn=Invoice_${invoice.invoiceNumber}'
            : 'INV:${invoice.invoiceNumber}|TOTAL:${invoice.total.toStringAsFixed(2)}');

    final grandTotalQty = invoice.items.fold(0.0, (sum, i) => sum + i.quantity);
    final totalUnitsStr = '${grandTotalQty % 1 == 0 ? grandTotalQty.toInt() : grandTotalQty.toStringAsFixed(1)} Nos.';

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _gstBorderColor, width: 1.0),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // ─── 1. Title Banner ──────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _gstBorderColor, width: 0.8)),
            ),
            child: pw.Center(
              child: pw.Text(
                'TAX INVOICE',
                style: pw.TextStyle(font: ttfBold, fontSize: 13, letterSpacing: 0.5),
              ),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _gstBorderColor, width: 0.8)),
            ),
            child: pw.Center(
              child: pw.Text(
                '( EXTRA COPY / ORIGINAL FOR RECIPIENT )',
                style: pw.TextStyle(font: ttfBold, fontSize: 8.5),
              ),
            ),
          ),

          // ─── 2. IRN & Signed QR Code Bar ──────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _gstBorderColor, width: 0.8)),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(text: 'IRN : ', style: pw.TextStyle(font: ttfBold, fontSize: 8)),
                            pw.TextSpan(
                              text: invoice.irn ?? 'N/A',
                              style: pw.TextStyle(font: ttf, fontSize: 7.5),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Row(
                        children: [
                          pw.Text('Ack No. : ', style: pw.TextStyle(font: ttfBold, fontSize: 8)),
                          pw.Text(invoice.ackNo ?? 'N/A', style: pw.TextStyle(font: ttf, fontSize: 8)),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        children: [
                          pw.Text('Ack Date : ', style: pw.TextStyle(font: ttfBold, fontSize: 8)),
                          pw.Text(
                            invoice.ackDate != null ? ackDateFormat.format(invoice.ackDate!) : dateFormat.format(invoice.invoiceDate),
                            style: pw.TextStyle(font: ttf, fontSize: 8),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  width: 58,
                  height: 58,
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrData,
                    width: 54,
                    height: 54,
                    color: _gstBlack,
                  ),
                ),
              ],
            ),
          ),

          // ─── 3. Bilingual Seller & Buyer Box vs Dispatch Box ──────────
          pw.Table(
            border: pw.TableBorder.symmetric(
              inside: const pw.BorderSide(color: _gstBorderColor, width: 0.8),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.15), // Seller & Buyer Details
              1: pw.FlexColumnWidth(0.85), // Dispatch & Order Grid
            },
            children: [
              pw.TableRow(
                children: [
                  // Left Side: Seller and Buyer Blocks
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Seller Details
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              bizName,
                              style: pw.TextStyle(font: ttfBold, fontSize: 10),
                            ),
                            if (business?.address != null && business!.address.isNotEmpty)
                              pw.Text(
                                business.address,
                                style: pw.TextStyle(font: ttf, fontSize: 8),
                              ),
                            if (arnNo != null && arnNo.isNotEmpty)
                              pw.Text('ARN No. : $arnNo', style: pw.TextStyle(font: ttf, fontSize: 7.5)),
                            if (msmeNo != null && msmeNo.isNotEmpty)
                              pw.Text('MSME No. : $msmeNo', style: pw.TextStyle(font: ttf, fontSize: 7.5)),
                            if (business?.gstNumber != null && business!.gstNumber!.isNotEmpty)
                              pw.Text('GSTIN/UIN : ${business.gstNumber}', style: pw.TextStyle(font: ttfBold, fontSize: 8)),
                            pw.Text('State Name : $supplierState, Code : $supplierStateCode', style: pw.TextStyle(font: ttf, fontSize: 8)),
                            if (business?.email != null && business!.email!.isNotEmpty)
                              pw.Text('E-Mail : ${business.email}', style: pw.TextStyle(font: ttf, fontSize: 7.5)),
                            if (business?.phone != null && business!.phone.isNotEmpty)
                              pw.Text('Contact : ${business.phone}', style: pw.TextStyle(font: ttf, fontSize: 7.5)),
                          ],
                        ),
                      ),
                      pw.Container(
                        width: double.infinity,
                        height: 0.8,
                        color: _gstBorderColor,
                      ),
                      // Buyer Details
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Buyer (Bill to) / Consignee', style: pw.TextStyle(font: ttfBold, fontSize: 8)),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              customer?.businessName != null && customer!.businessName!.isNotEmpty
                                  ? customer.businessName!.toUpperCase()
                                  : (customer?.name ?? 'CASH CUSTOMER').toUpperCase(),
                              style: pw.TextStyle(font: ttfBold, fontSize: 9.5),
                            ),
                            if (customer?.address != null && customer!.address.isNotEmpty)
                              pw.Text(customer.address, style: pw.TextStyle(font: ttf, fontSize: 8)),
                            if (customer?.gstNumber != null && customer!.gstNumber!.isNotEmpty)
                              pw.Text('GSTIN/UIN : ${customer.gstNumber}', style: pw.TextStyle(font: ttfBold, fontSize: 8)),
                            if (buyerState != null || buyerStateCode != null)
                              pw.Text(
                                'State Name : ${buyerState ?? 'State'}, Code : ${buyerStateCode ?? ''}',
                                style: pw.TextStyle(font: ttf, fontSize: 8),
                              ),
                            if (customer?.mobile != null && customer!.mobile.isNotEmpty)
                              pw.Text('Contact : ${customer.mobile}', style: pw.TextStyle(font: ttf, fontSize: 7.5)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Right Side: Dispatch & Order Reference Metadata Grid
                  pw.Column(
                    children: [
                      _buildTwoColMetaRow('Invoice No.', invoice.invoiceNumber, 'Dated', dateFormat.format(invoice.invoiceDate), ttf, ttfBold),
                      _buildTwoColMetaRow('Delivery Note', '-', 'Mode/Terms of Payment', invoice.paymentTerms ?? '30 Days', ttf, ttfBold),
                      _buildTwoColMetaRow('Reference No. & Date.', invoice.referenceNoAndDate ?? '-', 'Other References', '-', ttf, ttfBold),
                      _buildTwoColMetaRow(
                        "Buyer's Order No.",
                        invoice.buyerOrderNo ?? '-',
                        'Dated',
                        invoice.buyerOrderDate != null ? dateFormat.format(invoice.buyerOrderDate!) : '-',
                        ttf,
                        ttfBold,
                      ),
                      _buildTwoColMetaRow('Dispatch Doc No.', '-', 'Delivery Note Date', '-', ttf, ttfBold),
                      _buildTwoColMetaRow('Dispatched through', '-', 'Destination', invoice.destination ?? '-', ttf, ttfBold),
                      _buildFullColMetaRow('Terms of Delivery', invoice.termsOfDelivery ?? '-', ttf, ttfBold, isLast: true),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // ─── 4. Detailed Items Table ───────────────────────────
          pw.Table(
            border: const pw.TableBorder(
              top: pw.BorderSide(color: _gstBorderColor, width: 0.8),
              bottom: pw.BorderSide(color: _gstBorderColor, width: 0.8),
              left: pw.BorderSide.none,
              right: pw.BorderSide.none,
              verticalInside: pw.BorderSide(color: _gstBorderColor, width: 0.8),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.35), // Sl No
              1: pw.FlexColumnWidth(2.5),  // Description
              2: pw.FlexColumnWidth(0.85), // HSN/SAC
              3: pw.FlexColumnWidth(0.75), // Quantity
              4: pw.FlexColumnWidth(0.8),  // Rate
              5: pw.FlexColumnWidth(0.55), // per
              6: pw.FlexColumnWidth(0.5),  // Disc %
              7: pw.FlexColumnWidth(1.0),  // Amount
            },
            children: [
              // Header Row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _gstBgHeader),
                children: [
                  _tableCell('Sl\nNo.', ttfBold, align: pw.TextAlign.center),
                  _tableCell('Description of Goods', ttfBold, align: pw.TextAlign.left),
                  _tableCell('HSN/SAC', ttfBold, align: pw.TextAlign.center),
                  _tableCell('Quantity', ttfBold, align: pw.TextAlign.right),
                  _tableCell('Rate', ttfBold, align: pw.TextAlign.right),
                  _tableCell('per', ttfBold, align: pw.TextAlign.center),
                  _tableCell('Disc.\n%', ttfBold, align: pw.TextAlign.center),
                  _tableCell('Amount', ttfBold, align: pw.TextAlign.right),
                ],
              ),
              // Item Rows
              ...invoice.items.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final item = entry.value;
                final qtyStr = '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity.toStringAsFixed(1)} ${item.unit}';

                return pw.TableRow(
                  children: [
                    _tableCell('$idx', ttf, align: pw.TextAlign.center),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(item.productName, style: pw.TextStyle(font: ttfBold, fontSize: 8.5)),
                          pw.SizedBox(height: 2),
                          // Tax class sub-lines (CGST/SGST Outward)
                          pw.Text('C-GST - Outward @ 9%', style: pw.TextStyle(font: ttf, fontSize: 7, color: PdfColors.grey700)),
                          pw.Text('S-GST - Outward @ 9%', style: pw.TextStyle(font: ttf, fontSize: 7, color: PdfColors.grey700)),
                        ],
                      ),
                    ),
                    _tableCell(item.hsnCode ?? '-', ttf, align: pw.TextAlign.center),
                    _tableCell(qtyStr, ttfBold, align: pw.TextAlign.right),
                    _tableCell(item.unitPrice.toStringAsFixed(2), ttf, align: pw.TextAlign.right),
                    _tableCell(item.unit, ttf, align: pw.TextAlign.center),
                    _tableCell(item.discountPercent > 0 ? '${item.discountPercent.toStringAsFixed(1)}%' : '', ttf, align: pw.TextAlign.center),
                    _tableCell(item.subtotal.toStringAsFixed(2), ttfBold, align: pw.TextAlign.right),
                  ],
                );
              }),
              // Table Total Row
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: _gstBorderColor, width: 0.8)),
                ),
                children: [
                  _tableCell('', ttf),
                  _tableCell('Total', ttfBold, align: pw.TextAlign.right),
                  _tableCell('', ttf),
                  _tableCell(totalUnitsStr, ttfBold, align: pw.TextAlign.right),
                  _tableCell('', ttf),
                  _tableCell('', ttf),
                  _tableCell('', ttf),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('₹ ${invoice.total.toStringAsFixed(2)}', style: pw.TextStyle(font: ttfBold, fontSize: 9.5)),
                        pw.Text('E. & O.E.', style: pw.TextStyle(font: ttf, fontSize: 6.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ─── 5. Amount Chargeable (in words) Banner ─────────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _gstBorderColor, width: 0.8)),
            ),
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(text: 'Amount Chargeable (in words) : ', style: pw.TextStyle(font: ttf, fontSize: 8)),
                  pw.TextSpan(
                    text: 'INR ${_convertNumberToWords(invoice.total.toInt())} Only',
                    style: pw.TextStyle(font: ttfBold, fontSize: 8.5),
                  ),
                ],
              ),
            ),
          ),

          // ─── 6. Separate GST Tax Breakdown Table ─────────────────
          pw.Table(
            border: const pw.TableBorder(
              bottom: pw.BorderSide(color: _gstBorderColor, width: 0.8),
              verticalInside: pw.BorderSide(color: _gstBorderColor, width: 0.8),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.2), // HSN/SAC
              1: pw.FlexColumnWidth(1.2), // Taxable Value
              2: pw.FlexColumnWidth(1.4), // Central Tax
              3: pw.FlexColumnWidth(1.4), // State Tax
              4: pw.FlexColumnWidth(1.2), // Total Tax Amount
            },
            children: [
              // Tax Header Row 1
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _gstBgHeader),
                children: [
                  _taxCell('HSN/SAC', ttfBold, align: pw.TextAlign.center),
                  _taxCell('Taxable\nValue', ttfBold, align: pw.TextAlign.right),
                  pw.Column(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.Text('Central Tax', style: pw.TextStyle(font: ttfBold, fontSize: 7.5)),
                      ),
                      pw.Container(height: 0.5, color: _gstBorderColor),
                      pw.Row(
                        children: [
                          pw.Expanded(child: pw.Center(child: pw.Text('Rate', style: pw.TextStyle(font: ttfBold, fontSize: 7)))),
                          pw.Container(width: 0.5, height: 12, color: _gstBorderColor),
                          pw.Expanded(child: pw.Center(child: pw.Text('Amount', style: pw.TextStyle(font: ttfBold, fontSize: 7)))),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.Text('State Tax', style: pw.TextStyle(font: ttfBold, fontSize: 7.5)),
                      ),
                      pw.Container(height: 0.5, color: _gstBorderColor),
                      pw.Row(
                        children: [
                          pw.Expanded(child: pw.Center(child: pw.Text('Rate', style: pw.TextStyle(font: ttfBold, fontSize: 7)))),
                          pw.Container(width: 0.5, height: 12, color: _gstBorderColor),
                          pw.Expanded(child: pw.Center(child: pw.Text('Amount', style: pw.TextStyle(font: ttfBold, fontSize: 7)))),
                        ],
                      ),
                    ],
                  ),
                  _taxCell('Total\nTax Amount', ttfBold, align: pw.TextAlign.right),
                ],
              ),
              // Tax Data Rows (grouping items by HSN/SAC)
              ..._buildTaxBreakdownRows(invoice, ttf, ttfBold),
              // Tax Total Row
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: _gstBorderColor, width: 0.8)),
                ),
                children: [
                  _taxCell('Total', ttfBold, align: pw.TextAlign.right),
                  _taxCell(invoice.subtotal.toStringAsFixed(2), ttfBold, align: pw.TextAlign.right),
                  pw.Row(
                    children: [
                      pw.Expanded(child: pw.Container()),
                      pw.Expanded(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text((invoice.gst / 2).toStringAsFixed(2), style: pw.TextStyle(font: ttfBold, fontSize: 8), textAlign: pw.TextAlign.right),
                        ),
                      ),
                    ],
                  ),
                  pw.Row(
                    children: [
                      pw.Expanded(child: pw.Container()),
                      pw.Expanded(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text((invoice.gst / 2).toStringAsFixed(2), style: pw.TextStyle(font: ttfBold, fontSize: 8), textAlign: pw.TextAlign.right),
                        ),
                      ),
                    ],
                  ),
                  _taxCell(invoice.gst.toStringAsFixed(2), ttfBold, align: pw.TextAlign.right),
                ],
              ),
            ],
          ),

          // ─── 7. Tax Amount in Words Banner ─────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _gstBorderColor, width: 0.8)),
            ),
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(text: 'Tax Amount (in words) : ', style: pw.TextStyle(font: ttf, fontSize: 8)),
                  pw.TextSpan(
                    text: 'INR ${_convertNumberToWords(invoice.gst.toInt())} Only',
                    style: pw.TextStyle(font: ttfBold, fontSize: 8.5),
                  ),
                ],
              ),
            ),
          ),

          // ─── 8. Company Bank Details & Declarations & Signatures ────
          pw.Table(
            border: const pw.TableBorder(
              bottom: pw.BorderSide(color: _gstBorderColor, width: 0.8),
              verticalInside: pw.BorderSide(color: _gstBorderColor, width: 0.8),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.2), // Bank & Declaration
              1: pw.FlexColumnWidth(0.8), // Signatures
            },
            children: [
              pw.TableRow(
                children: [
                  // Bank Details and Declaration
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (panNo.isNotEmpty)
                          pw.Text('Company\'s PAN : $panNo', style: pw.TextStyle(font: ttfBold, fontSize: 8)),
                        pw.SizedBox(height: 4),
                        pw.Text('Company\'s Bank Details :', style: pw.TextStyle(font: ttfBold, fontSize: 8, decoration: pw.TextDecoration.underline)),
                        pw.Text('Bank Name : ${business?.bankName ?? 'State Bank of India'}', style: pw.TextStyle(font: ttf, fontSize: 8)),
                        pw.Text('A/c No. : ${business?.bankAccount ?? '-'}', style: pw.TextStyle(font: ttfBold, fontSize: 8)),
                        pw.Text('Branch & IFS Code : ${business?.bankIfsc ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 8)),
                        pw.SizedBox(height: 6),
                        pw.Text('Declaration :', style: pw.TextStyle(font: ttfBold, fontSize: 8)),
                        pw.Text(
                          business?.termsAndConditions ??
                              'We declare that this invoice shows the actual price of the goods described and that all particulars are true and correct.',
                          style: pw.TextStyle(font: ttf, fontSize: 7.5, height: 1.2),
                        ),
                      ],
                    ),
                  ),

                  // Signatures Block
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('for $bizName', style: pw.TextStyle(font: ttfBold, fontSize: 8.5)),
                        pw.SizedBox(height: 45),
                        pw.Center(
                          child: pw.Text('Authorized Signatory', style: pw.TextStyle(font: ttfBold, fontSize: 8.5)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ─── 9. Jurisdiction & Prepared / Verified by Footer ────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Prepared by : Admin', style: pw.TextStyle(font: ttf, fontSize: 7.5)),
                pw.Text('Verified by : Accounts', style: pw.TextStyle(font: ttf, fontSize: 7.5)),
                pw.Text('SUBJECT TO $jurisdiction JURISDICTION', style: pw.TextStyle(font: ttfBold, fontSize: 8)),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _gstBorderColor, width: 0.5)),
            ),
            child: pw.Center(
              child: pw.Text(
                'This is a Computer Generated Invoice',
                style: pw.TextStyle(font: ttf, fontSize: 7, color: PdfColors.grey700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sub-grid builders ────────────────────────────────────────────────────

  static pw.Widget _buildTwoColMetaRow(
    String col1Title,
    String col1Val,
    String col2Title,
    String col2Val,
    pw.Font ttf,
    pw.Font ttfBold,
  ) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _gstBorderColor, width: 0.8)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(col1Title, style: pw.TextStyle(font: ttf, fontSize: 7, color: PdfColors.grey700)),
                  pw.Text(col1Val, style: pw.TextStyle(font: ttfBold, fontSize: 8)),
                ],
              ),
            ),
          ),
          pw.Container(width: 0.8, height: 26, color: _gstBorderColor),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(col2Title, style: pw.TextStyle(font: ttf, fontSize: 7, color: PdfColors.grey700)),
                  pw.Text(col2Val, style: pw.TextStyle(font: ttfBold, fontSize: 8)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFullColMetaRow(
    String title,
    String value,
    pw.Font ttf,
    pw.Font ttfBold, {
    bool isLast = false,
  }) {
    return pw.Container(
      width: double.infinity,
      decoration: isLast
          ? const pw.BoxDecoration()
          : const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _gstBorderColor, width: 0.8)),
            ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(font: ttf, fontSize: 7, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(font: ttfBold, fontSize: 8)),
        ],
      ),
    );
  }

  static pw.Widget _tableCell(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 8),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _taxCell(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 7.5),
        textAlign: align,
      ),
    );
  }

  static List<pw.TableRow> _buildTaxBreakdownRows(InvoiceModel invoice, pw.Font ttf, pw.Font ttfBold) {
    // Group items by HSN/SAC
    final Map<String, List<InvoiceItem>> grouped = {};
    for (final item in invoice.items) {
      final hsn = (item.hsnCode != null && item.hsnCode!.isNotEmpty) ? item.hsnCode! : 'N/A';
      grouped.putIfAbsent(hsn, () => []).add(item);
    }

    return grouped.entries.map((entry) {
      final hsn = entry.key;
      final items = entry.value;
      final taxable = items.fold(0.0, (sum, i) => sum + i.subtotal);
      final totalGst = items.fold(0.0, (sum, i) => sum + i.gstAmount);
      final cgst = totalGst / 2;
      final sgst = totalGst / 2;

      return pw.TableRow(
        children: [
          _taxCell(hsn, ttf, align: pw.TextAlign.center),
          _taxCell(taxable.toStringAsFixed(2), ttf, align: pw.TextAlign.right),
          pw.Row(
            children: [
              pw.Expanded(child: pw.Center(child: pw.Text('9%', style: pw.TextStyle(font: ttf, fontSize: 7)))),
              pw.Container(width: 0.5, height: 14, color: _gstBorderColor),
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Text(cgst.toStringAsFixed(2), style: pw.TextStyle(font: ttf, fontSize: 7.5), textAlign: pw.TextAlign.right),
                ),
              ),
            ],
          ),
          pw.Row(
            children: [
              pw.Expanded(child: pw.Center(child: pw.Text('9%', style: pw.TextStyle(font: ttf, fontSize: 7)))),
              pw.Container(width: 0.5, height: 14, color: _gstBorderColor),
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Text(sgst.toStringAsFixed(2), style: pw.TextStyle(font: ttf, fontSize: 7.5), textAlign: pw.TextAlign.right),
                ),
              ),
            ],
          ),
          _taxCell(totalGst.toStringAsFixed(2), ttf, align: pw.TextAlign.right),
        ],
      );
    }).toList();
  }

  /// Converts a positive integer into verbal Indian English representation (Crores, Lakhs, Thousands, Hundreds)
  static String _convertNumberToWords(int n) {
    if (n == 0) return 'Zero';

    const units = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
      'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
      'Seventeen', 'Eighteen', 'Nineteen'
    ];
    const tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
    ];

    String formatUnderThousand(int num) {
      String str = '';
      if (num >= 100) {
        str += '${units[num ~/ 100]} Hundred ';
        num %= 100;
      }
      if (num >= 20) {
        str += '${tens[num ~/ 10]} ';
        num %= 10;
      }
      if (num > 0) {
        str += '${units[num]} ';
      }
      return str.trim();
    }

    String words = '';
    final crore = n ~/ 10000000;
    n %= 10000000;
    final lakh = n ~/ 100000;
    n %= 100000;
    final thousand = n ~/ 1000;
    n %= 1000;
    final remainder = n;

    if (crore > 0) {
      words += '${formatUnderThousand(crore)} Crore ';
    }
    if (lakh > 0) {
      words += '${formatUnderThousand(lakh)} Lakh ';
    }
    if (thousand > 0) {
      words += '${formatUnderThousand(thousand)} Thousand ';
    }
    if (remainder > 0) {
      words += formatUnderThousand(remainder);
    }

    return words.trim();
  }
}

