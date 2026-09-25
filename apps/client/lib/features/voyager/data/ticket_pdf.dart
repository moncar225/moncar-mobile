import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../shared/foundation.dart';

const _brand = PdfColor.fromInt(0xFF002060);
const _accent = PdfColor.fromInt(0xFFFF6600);
const _muted = PdfColor.fromInt(0xFF6B7280);

/// La police PDF standard (Helvetica) ne couvre que le Latin-1 : les
/// caractères hors de cette plage (flèches, espaces fines…) sont remplacés.
String _l1(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r <= 0xFF) {
      b.writeCharCode(r);
    } else if (r == 0x2192) {
      b.write('->');
    } else if (r == 0x2019 || r == 0x2018) {
      b.write("'");
    } else if (r == 0x202F || r == 0x2009) {
      b.write(' ');
    } else if (r == 0x2013 || r == 0x2014) {
      b.write('-');
    }
  }
  return b.toString();
}

/// Billet électronique au format PDF (A5) : itinéraire, passager,
/// siège et QR signé scanné à l'embarquement.
Future<Uint8List> buildTicketPdf(Ticket t) async {
  final logo = pw.MemoryImage(
    (await rootBundle.load('assets/moncar-logo.png')).buffer.asUint8List(),
  );
  final doc = pw.Document(title: _l1('Billet ${t.number}'), author: 'MON CAR');

  pw.Widget info(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 110,
          child: pw.Text(
            _l1(label),
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            _l1(value),
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            children: [
              pw.Image(logo, width: 40, height: 40),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'MON CAR',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: _brand,
                      ),
                    ),
                    pw.Text(
                      _l1('Billet électronique'),
                      style: const pw.TextStyle(fontSize: 9, color: _muted),
                    ),
                  ],
                ),
              ),
              pw.Text(
                t.number,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: _accent,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: _brand,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        t.departureTime,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        _l1(t.originCity),
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Text(
                  '->',
                  style: const pw.TextStyle(fontSize: 14, color: _accent),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        t.arrivalTime,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        _l1(t.destinationCity),
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          info('Passager', t.passengerName),
          info('Date', formatDateFull(t.date)),
          info('Compagnie', t.companyName),
          info('Montée', t.boardingStop),
          info('Descente', t.alightingStop),
          info('Siège', t.seatNumber),
          info('Véhicule', t.vehicleModel),
          pw.SizedBox(height: 12),
          pw.Center(
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: t.qrPayload,
              width: 150,
              height: 150,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              _l1('Présentez ce QR code au contrôleur à l’embarquement.'),
              style: const pw.TextStyle(fontSize: 9, color: _muted),
            ),
          ),
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey300),
          pw.Text(
            _l1(
              'Émis le ${formatDateLong(t.issuedAt)} · clé v${t.keyVersion} · '
              'Billet nominatif, pièce d’identité exigée.',
            ),
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}
