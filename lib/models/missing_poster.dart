import 'dart:typed_data';

import 'cat.dart';
import '../config/api_config.dart';

/// The same public details are used in the poster, feed draft and external share.
class MissingPoster {
  MissingPoster({required this.cat, required this.report, String? locationName})
    : photoBytes = null,
      address = _text(report['last_seen_address']) ?? _text(locationName);
  MissingPoster.publicReport({required this.report, required this.photoBytes})
    : cat = null,
      address = _text(report['last_seen_address']);
  final Cat? cat;
  final Uint8List? photoBytes;
  String get displayName =>
      cat?.displayName ?? _text(report['name']) ?? 'Gato desaparecido';
  String get photoPath => cat?.photoPath ?? '';
  Map<String, dynamic> get options =>
      Map<String, dynamic>.from(report['poster_options'] as Map? ?? {});
  bool get isActive => report['status'] != 'resolved';
  bool includes(String field) =>
      options[field] != false && (field != 'qr_code' || isActive);
  final Map<String, dynamic> report;
  final String? address;

  static String? _text(Object? value) {
    final text = value?.toString().trim();
    if (text == null ||
        text.isEmpty ||
        text.toLowerCase() == 'região monitorada') {
      return null;
    }
    return text;
  }

  Map<String, String> get characteristics => {
    if (includes('collar'))
      if ((_text(report['collar']) ?? _text(cat?.collar))
          case final String value)
        'Coleira': value,
    if (includes('distinguishing_marks'))
      if ((_text(report['distinguishing_marks']) ??
              _text(cat?.distinguishingMarks))
          case final String value)
        'Marcas características': value,
    if (includes('microchip'))
      if ((_text(report['microchip']) ?? _text(cat?.microchip))
          case final String value)
        'Microchip': value,
  };

  List<Map<String, dynamic>> get contacts => [
    for (final value
        in (report['poster_contacts'] ?? report['contacts']) as List? ?? [])
      if (value is Map &&
          value['included'] != false &&
          _text(value['phone']) != null)
        {
          'phone': _text(value['phone'])!,
          'whatsapp': value['whatsapp'] == true,
        },
  ];

  String? get disappearedDate {
    if (!includes('date')) return null;
    final parsed = DateTime.tryParse(
      report['disappeared_at']?.toString() ??
          report['created_at']?.toString() ??
          '',
    );
    if (parsed == null) return null;
    final date = parsed.toLocal();
    return '${date.day.toString().padLeft(2, "0")}/${date.month.toString().padLeft(2, "0")}/${date.year}';
  }

  String? get dateLabel => disappearedDate == null
      ? null
      : '${report['disappeared_at'] == null ? 'Alerta aberto em' : 'Desaparecido desde'} $disappearedDate';

  String get qrPayload {
    final id = _text(report['id']);
    if (id != null) {
      return Uri.parse(ApiConfig.baseUrl)
          .replace(path: '/public/busca/$id', query: null, fragment: null)
          .toString();
    }
    // A draft without a report ID still encodes real public contact information.
    return text;
  }

  String get text {
    final lines = <String>[
      if (!isActive)
        'BUSCA ENCERRADA — GATÁLOGO'
      else
        'ALERTA DE DESAPARECIMENTO — GATÁLOGO',
      'PROCURA-SE: $displayName',
      ?dateLabel,
      if (includes('address') && address != null)
        'Último local visto: $address',
      for (final detail in characteristics.entries)
        '${detail.key}: ${detail.value}',
      for (final contact in contacts)
        '${contact['whatsapp'] == true ? 'Telefone / WhatsApp' : 'Telefone'}: ${contact['phone']}',
      if (contacts.isEmpty) 'Contato pelo chat do Gatálogo.',
      '',
      'Se você viu este gato na região, fotografe pelo aplicativo Gatálogo para alertar o tutor.',
      if (includes('qr_code') && _text(report['id']) != null) qrPayload,
    ];
    return lines.join('\n');
  }
}
