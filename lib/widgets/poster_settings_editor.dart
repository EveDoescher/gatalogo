import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'botanical_scene.dart';

class PosterContactDraft {
  PosterContactDraft(Map value)
    : phone = TextEditingController(text: value['phone']?.toString() ?? ''),
      whatsapp = value['whatsapp'] == true,
      included = value['included'] != false;
  final TextEditingController phone;
  bool whatsapp, included;
  Map<String, dynamic> get json => {
    'phone': phone.text.trim(),
    'whatsapp': whatsapp,
    'included': included,
  };
}

/// Draft choices stay separate from the last server-confirmed public report.
class PosterEditorController extends ChangeNotifier {
  PosterEditorController(Map report) {
    options.addAll(
      Map<String, bool>.from(report['poster_options'] as Map? ?? {}),
    );
    for (final value
        in (report['poster_contacts'] ?? report['contacts']) as List? ?? []) {
      _add(PosterContactDraft(value as Map));
    }
  }
  static const fields = {
    'address': 'Último local visto',
    'date': 'Data da busca',
    'collar': 'Coleira',
    'distinguishing_marks': 'Marcas características',
    'microchip': 'Microchip',
    'qr_code': 'QR code da busca',
  };
  final Map<String, bool> options = {for (final key in fields.keys) key: true};
  final List<PosterContactDraft> contacts = [];
  bool dirty = false;
  void changed() {
    dirty = true;
    notifyListeners();
  }

  void _add(PosterContactDraft contact) {
    contacts.add(contact);
    contact.phone.addListener(changed);
  }

  void addContact(Map<String, dynamic> value) {
    if (contacts.length >= 5) return;
    _add(PosterContactDraft(value));
    changed();
  }

  void updateContact(PosterContactDraft contact, Map<String, dynamic> value) {
    contact.phone.removeListener(changed);
    contact.phone.text = value['phone'] as String;
    contact.whatsapp = value['whatsapp'] == true;
    contact.included = value['included'] != false;
    contact.phone.addListener(changed);
    changed();
  }

  void removeContact(PosterContactDraft contact) {
    contacts.remove(contact);
    contact.phone.removeListener(changed);
    // The field is unmounted before its controller is disposed.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => contact.phone.dispose(),
    );
    changed();
  }

  String? get error {
    for (final contact in contacts) {
      final message = validatePosterPhone(contact.phone.text);
      if (message != null) return message;
    }
    return null;
  }

  Map<String, dynamic> get payload => {
    'contacts': contacts.map((c) => c.json).toList(),
    'options': Map.of(options),
  };
  Map<String, dynamic> apply(Map<String, dynamic> report) => {
    ...report,
    'poster_contacts': contacts.map((c) => c.json).toList(),
    'poster_options': Map.of(options),
  };
  @override
  void dispose() {
    for (final c in contacts) {
      c.phone.dispose();
    }
    super.dispose();
  }
}

class PosterSettingsEditor extends StatelessWidget {
  const PosterSettingsEditor({
    super.key,
    required this.controller,
    this.enabled = true,
  });
  final PosterEditorController controller;
  final bool enabled;
  Future<void> _editContact(
    BuildContext context, [
    PosterContactDraft? contact,
  ]) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PosterContactEditor(initialValue: contact?.json),
    );
    if (result == null || !context.mounted) return;
    if (contact == null) {
      controller.addContact(result);
    } else {
      controller.updateContact(contact, result);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      BotanicalPaper(
        foliage: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'O que aparece no cartaz',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Estas escolhas valem para o cartaz, os arquivos e os detalhes públicos da busca.',
            ),
            const SizedBox(height: 8),
            for (final field in PosterEditorController.fields.entries)
              SwitchListTile.adaptive(
                key: ValueKey('poster_option_${field.key}'),
                contentPadding: EdgeInsets.zero,
                title: Text(field.value),
                value: controller.options[field.key]!,
                onChanged: enabled
                    ? (value) {
                        controller.options[field.key] = value;
                        controller.changed();
                      }
                    : null,
              ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      BotanicalPaper(
        foliage: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Contatos públicos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Adicione até 5 telefones. Marque quais divulgar e quais atendem pelo WhatsApp.',
            ),
            for (final contact in controller.contacts) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              PosterContactTile(
                contact: contact,
                index: controller.contacts.indexOf(contact) + 1,
                onEdit: enabled ? () => _editContact(context, contact) : null,
                onRemove: enabled
                    ? () => controller.removeContact(contact)
                    : null,
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: enabled && controller.contacts.length < 5
                  ? () => _editContact(context)
                  : null,
              icon: const Icon(Icons.add),
              label: Text(
                controller.contacts.isEmpty
                    ? 'Adicionar telefone'
                    : 'Adicionar outro telefone',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Os números desmarcados ficam guardados apenas para você. Sem telefone público, a busca continua disponível no Gatálogo.',
              style: TextStyle(color: AppColors.textMedium, fontSize: 12),
            ),
          ],
        ),
      ),
    ],
  );
}

String? validatePosterPhone(String? value) {
  final text = (value ?? '').trim();
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '').length;
  if (digits < 8 || digits > 15 || !RegExp(r'^\+?[0-9 ()-]+$').hasMatch(text)) {
    return 'Informe um telefone válido com DDD.';
  }
  return null;
}

/// A confirmed contact is distinct from the temporary editor fields.
class PosterContactTile extends StatelessWidget {
  const PosterContactTile({
    super.key,
    required this.contact,
    required this.index,
    this.onEdit,
    this.onRemove,
  });
  final PosterContactDraft contact;
  final int index;
  final VoidCallback? onEdit, onRemove;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F3E4),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFBAC9A1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AppColors.textMedium,
              size: 18,
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Telefone adicionado',
                style: TextStyle(fontSize: 12),
              ),
            ),
            IconButton(
              tooltip: 'Editar contato $index',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
            IconButton(
              tooltip: 'Remover contato $index',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, size: 20),
            ),
          ],
        ),
        Text(
          contact.phone.text,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          contact.whatsapp ? 'Telefone e WhatsApp' : 'Somente telefone',
          style: const TextStyle(color: AppColors.textMedium),
        ),
        const SizedBox(height: 4),
        Text(
          contact.included ? 'Visível no cartaz' : 'Não será divulgado',
          style: const TextStyle(color: AppColors.textMedium, fontSize: 12),
        ),
      ],
    ),
  );
}

/// Canceling or dismissing this sheet never changes the poster draft.
class PosterContactEditor extends StatefulWidget {
  const PosterContactEditor({super.key, this.initialValue});
  final Map<String, dynamic>? initialValue;
  @override
  State<PosterContactEditor> createState() => _PosterContactEditorState();
}

class _PosterContactEditorState extends State<PosterContactEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _phone;
  late bool _whatsapp, _included;
  bool get _editing => widget.initialValue != null;
  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(
      text: widget.initialValue?['phone'] as String? ?? '',
    );
    _whatsapp = widget.initialValue?['whatsapp'] == true;
    _included = widget.initialValue?['included'] != false;
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _editing ? 'Editar telefone' : 'Novo telefone',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('poster_contact_phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            maxLength: 32,
            validator: validatePosterPhone,
            decoration: const InputDecoration(
              labelText: 'Telefone com DDD',
              hintText: '(11) 99999-9999',
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Divulgar este telefone'),
            value: _included,
            onChanged: (value) => setState(() => _included = value ?? false),
          ),
          CheckboxListTile(
            key: const ValueKey('poster_contact_whatsapp'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Também atende pelo WhatsApp'),
            value: _whatsapp,
            onChanged: (value) => setState(() => _whatsapp = value ?? false),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('confirm_poster_contact'),
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              Navigator.of(context).pop(<String, dynamic>{
                'phone': _phone.text.trim(),
                'whatsapp': _whatsapp,
                'included': _included,
              });
            },
            icon: const Icon(Icons.check),
            label: Text(_editing ? 'Salvar alterações' : 'Adicionar telefone'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    ),
  );
}
