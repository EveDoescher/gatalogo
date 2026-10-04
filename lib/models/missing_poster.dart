import 'cat.dart';

/// The same public details are used in the poster, feed draft and external share.
class MissingPoster {
  MissingPoster({required this.cat, required this.report, String? locationName})
    : address = _text(report['last_seen_address']) ?? _text(locationName);
  final Cat cat;
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
    if ((_text(report['collar']) ?? _text(cat.collar)) case final String value)
      'Coleira': value,
    if ((_text(report['distinguishing_marks']) ??
            _text(cat.distinguishingMarks))
        case final String value)
      'Marcas características': value,
    if ((_text(report['microchip']) ?? _text(cat.microchip))
        case final String value)
      'Microchip': value,
  };

  List<Map<String, dynamic>> get contacts => [
    for (final value in report['contacts'] as List? ?? [])
      if (value is Map && _text(value['phone']) != null)
        {
          'phone': _text(value['phone'])!,
          'whatsapp': value['whatsapp'] == true,
        },
  ];

  String get text {
    final lines = <String>[
      'ALERTA DE DESAPARECIMENTO — GATÁLOGO',
      'PROCURA-SE: ${cat.displayName}',
      if (address != null) 'Último local visto: $address',
      for (final detail in characteristics.entries)
        '${detail.key}: ${detail.value}',
      for (final contact in contacts)
        '${contact['whatsapp'] == true ? 'Telefone / WhatsApp' : 'Telefone'}: ${contact['phone']}',
      if (contacts.isEmpty) 'Contato pelo chat do Gatálogo.',
      '',
      'Se você viu este gato na região, fotografe pelo aplicativo Gatálogo para alertar o tutor imediatamente.',
    ];
    return lines.join('\n');
  }
}
