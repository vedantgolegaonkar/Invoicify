import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../features/invoices/domain/invoice_model.dart';
import '../features/customers/domain/customer_model.dart';
import '../features/settings/domain/business_model.dart';

/// Defines the available PDF invoice template styles.
enum InvoiceTemplateStyle {
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

  /// Generates and shares a PDF invoice via the system share sheet.
  static Future<void> shareInvoicePdf({
    required InvoiceModel invoice,
    required CustomerModel? customer,
    required BusinessModel? business,
    required double amountPaid,
    InvoiceTemplateStyle style = InvoiceTemplateStyle.modernExecutive,
  }) async {
    final pdf = pw.Document();

    // Load fonts that support the Rupee symbol (₹)
    final ttf = await PdfGoogleFonts.notoSansRegular();
    final ttfBold = await PdfGoogleFonts.notoSansBold();

    final outstanding = (invoice.total - amountPaid).clamp(0.0, double.infinity);

    if (style == InvoiceTemplateStyle.modernExecutive) {
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

    final rawCustomerName = (customer?.name ?? '').trim();
    final customerName = rawCustomerName.isNotEmpty
        ? rawCustomerName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        : 'Customer';
    final shareFilename = 'INV_$customerName-Invoice.pdf';

    final bytes = await pdf.save();
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
}
