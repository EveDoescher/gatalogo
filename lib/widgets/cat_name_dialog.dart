import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class CatNameDialog extends StatefulWidget {
  const CatNameDialog({super.key, this.name});
  final String? name;

  @override
  State<CatNameDialog> createState() => _CatNameDialogState();
}

class _CatNameDialogState extends State<CatNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFCFAF7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(
        'Nome do gato',
        style: GoogleFonts.nunito(
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 30,
        textCapitalization: TextCapitalization.words,
        style: GoogleFonts.nunito(
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        decoration: InputDecoration(
          labelText: 'Nome',
          labelStyle: GoogleFonts.nunito(color: AppColors.textMedium),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancelar',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w700,
              color: AppColors.textMedium,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            'Salvar',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
