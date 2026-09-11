import 'dart:io';

import 'package:flutter/material.dart';

import '../models/cat.dart';

String displayDate(dynamic value) {
  final date = value is DateTime
      ? value.toLocal()
      : DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return '';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

void showMessage(BuildContext context, Object message) {
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message.toString())));
  }
}

Future<bool> confirmAction(
  BuildContext context,
  String title,
  String message,
  String action,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

class CatPhotoView extends StatelessWidget {
  const CatPhotoView(
    this.path, {
    super.key,
    this.height,
    this.fit = BoxFit.cover,
  });
  final String path;
  final double? height;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) => Image.file(
    File(path),
    height: height,
    width: double.infinity,
    fit: fit,
    errorBuilder: (_, _, _) => SizedBox(
      height: height ?? 100,
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          semanticLabel: 'Foto não disponível',
        ),
      ),
    ),
  );
}

class CatTile extends StatelessWidget {
  const CatTile(this.cat, {super.key, required this.onTap, this.subtitle});
  final Cat cat;
  final VoidCallback onTap;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
    leading: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 64,
        height: 64,
        child: CatPhotoView(cat.photoPath),
      ),
    ),
    title: Text(cat.displayName),
    subtitle: Text(subtitle ?? displayDate(cat.capturedAt)),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

class EmptyContent extends StatelessWidget {
  const EmptyContent(this.title, this.message, {super.key, this.action});
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.pets_outlined, size: 48),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (action != null)
          Padding(padding: const EdgeInsets.only(top: 16), child: action!),
      ],
    ),
  );
}
