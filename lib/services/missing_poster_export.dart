import 'dart:io';

import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/missing_poster.dart';

class MissingPosterExport {
  const MissingPosterExport._();
  static Future<Uint8List> pdf(MissingPoster poster) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Nunito-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Nunito-Bold.ttf'),
    );
    final title = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Fredoka-Bold.ttf'),
    );
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    final file = File(poster.photoPath);
    final photo = poster.photoBytes != null
        ? pw.MemoryImage(poster.photoBytes!)
        : await file.exists()
        ? pw.MemoryImage(await file.readAsBytes())
        : null;
    const red = PdfColor.fromInt(0xFFD4543C),
        ink = PdfColor.fromInt(0xFF4B281B);
    pw.Widget field(
      String label,
      String value,
      String shape, {
      bool contact = false,
    }) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SvgImage(
            svg:
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#80654E" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">$shape</svg>',
            width: 18,
            height: 18,
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  label,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColor.fromInt(0xFF80654E),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  value,
                  style: pw.TextStyle(
                    fontSize: contact ? 18 : 13,
                    fontWeight: pw.FontWeight.bold,
                    color: ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    const pin =
        '<path d="M20 10c0 6-8 11-8 11S4 16 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/>';
    const tag =
        '<path d="M20 13l-7 7L3 10V3h7Z"/><circle cx="7" cy="7" r="1"/>';
    const phone =
        '<path d="M5 3h4l2 5-3 2c2 3 3 4 6 6l2-3 5 2v4c-1 4-8 1-12-3S1 4 5 3Z"/>';
    const chat = '<path d="M3 3h18v14H9l-6 4Z"/>';
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => pw.Center(
          child: pw.FittedBox(
            child: pw.Container(
              width: 480,
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFFFF9EC),
                border: pw.Border.all(color: red, width: 2),
                borderRadius: pw.BorderRadius.circular(14),
              ),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 10),
                    decoration: pw.BoxDecoration(
                      color: red,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.SvgImage(
                          svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="white"><ellipse cx="5" cy="8" rx="2.5" ry="3.5"/><ellipse cx="10" cy="4" rx="2.5" ry="3.5"/><ellipse cx="16" cy="4" rx="2.5" ry="3.5"/><ellipse cx="21" cy="8" rx="2.5" ry="3.5"/><path d="M12 10C8 10 3 17 5 20c2 3 5 0 7 0s5 3 7 0c2-3-3-10-7-10Z"/></svg>',
                          width: 28,
                          height: 28,
                        ),
                        pw.SizedBox(width: 12),
                        pw.Text(
                          poster.isActive ? 'PROCURA-SE' : 'BUSCA ENCERRADA',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            font: title,
                            fontSize: 34,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 14),
                  if (photo != null)
                    pw.ClipRRect(
                      horizontalRadius: 8,
                      verticalRadius: 8,
                      child: pw.Image(
                        photo,
                        height: 235,
                        width: 444,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    poster.displayName,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: title, fontSize: 28, color: ink),
                  ),
                  if (poster.dateLabel != null)
                    pw.Text(
                      poster.dateLabel!,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: red,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  pw.SizedBox(height: 16),
                  if (poster.includes('address') && poster.address != null)
                    field(
                      'Último local visto',
                      poster.address ?? 'Endereço não informado',
                      pin,
                    ),
                  for (final entry in poster.characteristics.entries)
                    field(entry.key, entry.value, tag),
                  pw.Container(
                    padding: const pw.EdgeInsets.fromLTRB(12, 12, 12, 2),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFFFCEBE8),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      children: [
                        if (poster.contacts.isEmpty)
                          field(
                            'Fale com o tutor',
                            'Pelo chat do Gatálogo',
                            chat,
                          ),
                        for (final contact in poster.contacts)
                          field(
                            contact['whatsapp'] == true
                                ? 'Telefone / WhatsApp'
                                : 'Telefone',
                            contact['phone'] as String,
                            phone,
                            contact: true,
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 14),
                  pw.Divider(color: const PdfColor.fromInt(0xFFE2D4B7)),
                  pw.SizedBox(height: 8),
                  if (poster.includes('qr_code'))
                    pw.Row(
                      children: [
                        pw.Container(
                          color: PdfColors.white,
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: poster.qrPayload,
                            width: 78,
                            height: 78,
                            drawText: false,
                          ),
                        ),
                        pw.SizedBox(width: 16),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Viu este gatinho?',
                                style: pw.TextStyle(
                                  font: title,
                                  fontSize: 21,
                                  color: ink,
                                ),
                              ),
                              pw.SizedBox(height: 5),
                              pw.Text(
                                'Fotografe pelo Gatálogo e ajude na busca.',
                                style: const pw.TextStyle(
                                  fontSize: 13,
                                  color: ink,
                                ),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text(
                                'Escaneie para ver os detalhes.',
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return document.save();
  }

  static Future<Uint8List> png(MissingPoster poster) async {
    final page = await Printing.raster(
      await pdf(poster),
      pages: [0],
      dpi: 180,
    ).first;
    return page.toPng();
  }

  static Future<bool> save(
    MissingPoster poster, {
    bool printable = false,
  }) async {
    if (!poster.isActive) return false;
    final bytes = printable ? await pdf(poster) : await png(poster);
    return await FilePicker.saveFile(
          fileName: 'cartaz-gatalogo.${printable ? 'pdf' : 'png'}',
          bytes: bytes,
          mimeType: printable ? 'application/pdf' : 'image/png',
        ) !=
        null;
  }

  static Future<bool> printPoster(MissingPoster poster) async {
    if (!poster.isActive) return false;
    final bytes = await pdf(poster);
    return Printing.layoutPdf(
      name: 'Cartaz Gatálogo',
      onLayout: (_) async => bytes,
    );
  }

  static Future<bool> share(MissingPoster poster, {Rect? origin}) async {
    if (!poster.isActive) return false;
    final folder = await Directory(
      '${(await getTemporaryDirectory()).path}/poster-${DateTime.now().microsecondsSinceEpoch}',
    ).create();
    try {
      final file = await File('${folder.path}/cartaz-gatalogo.png')
          .writeAsBytes(await png(poster));
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: poster.text,
          subject: 'PROCURA-SE: ${poster.displayName}',
          sharePositionOrigin: origin,
        ),
      );
      return result.status == ShareResultStatus.success;
    } finally {
      await folder.delete(recursive: true);
    }
  }
}
