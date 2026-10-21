import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/product_api_service.dart';
import '../stores/session_store.dart';
import '../widgets/app_widgets.dart';

class PrivateCluePhoto extends StatefulWidget {
  const PrivateCluePhoto({
    super.key,
    required this.path,
    required this.session,
    this.height = 240,
    this.fit = BoxFit.contain,
  });
  final String path;
  final SessionStore session;
  final double height;
  final BoxFit fit;
  @override
  State<PrivateCluePhoto> createState() => _PrivateCluePhotoState();
}

class _PrivateCluePhotoState extends State<PrivateCluePhoto> {
  late Future<Uint8List> _photo;
  @override
  void initState() {
    super.initState();
    _photo = ProductApiService(widget.session).photo(widget.path);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    width: double.infinity,
    child: FutureBuilder<Uint8List>(
      future: _photo,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return GestureDetector(
            onTap: () => showFullscreenMemoryImage(
              context,
              bytes: snapshot.data!,
              title: 'Foto do Avistamento',
            ),
            child: Image.memory(
              snapshot.data!,
              width: double.infinity,
              height: widget.height,
              fit: widget.fit,
            ),
          );
        }
        if (snapshot.hasError) {
          return TextButton.icon(
            onPressed: () => setState(
              () =>
                  _photo = ProductApiService(widget.session).photo(widget.path),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar carregar foto'),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    ),
  );
}
