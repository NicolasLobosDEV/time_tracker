// lib/utils/pdf_generator.dart
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:time_tracker/database/database.dart';
import 'package:time_tracker/models/line_item.dart';

Future<void> generateAndShowInvoice({
  required Invoice invoice,
  required Client client,
  required CompanySetting settings,
  required List<LineItem> items,
}) async {
  final pdf = pw.Document();
  final font = await PdfGoogleFonts.openSansRegular();
  final boldFont = await PdfGoogleFonts.openSansBold();
  final currencyFormat = NumberFormat.simpleCurrency(name: client.currency);

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        // This is the key change: the header is now conditional
        if (settings.showLetterhead)
          _buildHeader(context, settings, font, boldFont),

        _buildInvoiceDetails(context, invoice, client, font, boldFont),
        pw.SizedBox(height: 20),
        pw.Text('INVOICE', style: pw.TextStyle(font: boldFont, fontSize: 24)),
        pw.SizedBox(height: 20),
        _buildLineItemsTable(context, items, font, boldFont, currencyFormat),
        pw.SizedBox(height: 20),
        _buildTotals(context, invoice, items, font, boldFont, currencyFormat),
        pw.SizedBox(height: 40),
        if (invoice.notes != null && invoice.notes!.isNotEmpty)
          _buildNotes(context, invoice, font),
      ],
      footer: (context) => _buildFooter(context, font),
    ),
  );

  await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save());
}

pw.Widget _buildHeader(pw.Context context, CompanySetting settings, pw.Font font, pw.Font boldFont) {
  pw.ImageProvider? logo;
  if (settings.logoPath != null) {
    logo = pw.MemoryImage(File(settings.logoPath!).readAsBytesSync());
  }

  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(settings.companyName, style: pw.TextStyle(font: boldFont, fontSize: 20)),
          pw.SizedBox(height: 5),
          pw.Text(settings.companyAddress, style: pw.TextStyle(font: font, fontStyle: pw.FontStyle.italic)),
        ],
      ),
      if (logo != null)
        pw.Container(
          width: 100,
          height: 100,
          child: pw.Image(logo),
        ),
    ],
  );
}

pw.Widget _buildInvoiceDetails(pw.Context context, Invoice invoice, Client client, pw.Font font, pw.Font boldFont) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Billed to:', style: pw.TextStyle(font: boldFont)),
          pw.Text(client.name, style: pw.TextStyle(font: font)),
          pw.Text(client.address, style: pw.TextStyle(font: font)),
          pw.Text(client.email, style: pw.TextStyle(font: font)),
        ],
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text('Invoice #: ${invoice.invoiceIdString}', style: pw.TextStyle(font: boldFont)),
          pw.Text('Date Issued: ${DateFormat.yMMMd().format(invoice.issueDate)}', style: pw.TextStyle(font: font)),
          pw.Text('Date Due: ${DateFormat.yMMMd().format(invoice.dueDate)}', style: pw.TextStyle(font: font)),
        ],
      ),
    ],
  );
}

pw.Widget _buildLineItemsTable(pw.Context context, List<LineItem> items, pw.Font font, pw.Font boldFont, NumberFormat currencyFormat) {
  final headers = ['Description', 'Quantity', 'Unit Price', 'Total'];
  final data = items.map((item) {
    return [
      item.description,
      item.quantity.toStringAsFixed(2),
      currencyFormat.format(item.unitPrice),
      currencyFormat.format(item.total),
    ];
  }).toList();

  return pw.Table.fromTextArray(
    headers: headers,
    data: data,
    border: null,
    headerStyle: pw.TextStyle(font: boldFont),
    cellStyle: pw.TextStyle(font: font),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
    cellAlignments: {
      0: pw.Alignment.centerLeft,
      1: pw.Alignment.centerRight,
      2: pw.Alignment.centerRight,
      3: pw.Alignment.centerRight,
    },
  );
}

pw.Widget _buildTotals(pw.Context context, Invoice invoice, List<LineItem> items, pw.Font font, pw.Font boldFont, NumberFormat currencyFormat) {
  final subtotal = items.fold<double>(0, (sum, item) => sum + item.total);
  // Assuming no tax or discounts for now, total is the same as subtotal
  final total = subtotal;

  return pw.Container(
    alignment: pw.Alignment.centerRight,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Divider(),
        pw.SizedBox(height: 5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text('Subtotal: ', style: pw.TextStyle(font: font)),
            pw.Text(currencyFormat.format(subtotal), style: pw.TextStyle(font: boldFont)),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text('Total: ', style: pw.TextStyle(font: boldFont, fontSize: 16)),
            pw.Text(currencyFormat.format(total), style: pw.TextStyle(font: boldFont, fontSize: 16)),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _buildNotes(pw.Context context, Invoice invoice, pw.Font font) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Notes:', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)),
      pw.Text(invoice.notes!, style: pw.TextStyle(font: font)),
    ],
  );
}

pw.Widget _buildFooter(pw.Context context, pw.Font font) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.center,
    children: [
      pw.Text('Thank you for your business!', style: pw.TextStyle(font: font)),
    ],
  );
}