// lib/utils/pdf_generator.dart
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:time_tracker/database/database.dart';
import 'package:time_tracker/models/line_item.dart';
import 'package:intl/intl.dart';

Future<void> generateAndShowInvoice({
  required Invoice invoice,
  required Client client,
  required CompanySetting settings,
  required List<LineItem> items,
}) async {
  final pdf = pw.Document();

  // Load assets
  final logoImage = settings.companyLogoPath != null
      ? pw.MemoryImage(File(settings.companyLogoPath!).readAsBytesSync())
      : null;
  final letterheadImage = settings.invoiceLetterheadImagePath != null
      ? pw.MemoryImage(File(settings.invoiceLetterheadImagePath!).readAsBytesSync())
      : null;

  final currencyFormat = NumberFormat.simpleCurrency(name: client.currency);

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Stack(
          children: [
            // Letterhead background image
            if (letterheadImage != null)
              pw.Positioned.fill(
                child: pw.Image(letterheadImage, fit: pw.BoxFit.cover),
              ),
            
            // Main content
            pw.Padding(
              padding: const pw.EdgeInsets.all(40),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildHeader(settings, logoImage, invoice),
                  pw.SizedBox(height: 40),
                  _buildBillTo(client),
                  pw.SizedBox(height: 40),
                  _buildLineItemTable(items, currencyFormat),
                  pw.Spacer(),
                  _buildTotals(items, currencyFormat),
                  pw.Divider(),
                  pw.SizedBox(height: 20),
                  if (invoice.notes != null && invoice.notes!.isNotEmpty)
                    _buildNotes(invoice.notes!),
                  if (settings.invoiceLetterhead != null && settings.invoiceLetterhead!.isNotEmpty)
                    _buildFooter(settings.invoiceLetterhead!),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  // Save and open the file
  final output = await getTemporaryDirectory();
  final file = File("${output.path}/${invoice.invoiceIdString}.pdf");
  await file.writeAsBytes(await pdf.save());
  OpenFile.open(file.path);
}

pw.Widget _buildHeader(CompanySetting settings, pw.MemoryImage? logo, Invoice invoice) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (settings.companyName != null)
            pw.Text(settings.companyName!, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
          if (settings.companyAddress != null)
            pw.Text(settings.companyAddress!),
          if (settings.cnpj != null)
            pw.Text(settings.cnpj!),
        ],
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          if (logo != null) pw.Image(logo, height: 60),
          pw.SizedBox(height: 10),
          pw.Text('INVOICE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 24)),
          pw.Text(invoice.invoiceIdString),
        ],
      ),
    ],
  );
}

pw.Widget _buildBillTo(Client client) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('BILL TO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Text(client.name),
      if (client.address != null) pw.Text(client.address!),
      if (client.email != null) pw.Text(client.email!),
    ],
  );
}

pw.Widget _buildLineItemTable(List<LineItem> items, NumberFormat currencyFormat) {
  final headers = ['Description', 'Hours', 'Rate', 'Total'];
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
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
    cellAlignment: pw.Alignment.centerLeft,
    cellAlignments: {
      1: pw.Alignment.centerRight,
      2: pw.Alignment.centerRight,
      3: pw.Alignment.centerRight,
    },
  );
}

pw.Widget _buildTotals(List<LineItem> items, NumberFormat currencyFormat) {
  final double total = items.fold(0, (sum, item) => sum + item.total);
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.Text('Total: ', style: pw.TextStyle(fontSize: 14)),
      pw.Text(currencyFormat.format(total), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
    ],
  );
}

pw.Widget _buildNotes(String notes) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Notes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.Text(notes),
    ],
  );
}

pw.Widget _buildFooter(String footerText) {
  return pw.Center(
    child: pw.Text(footerText, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
  );
}