import 'dart:io';

import 'package:flutter/material.dart';

import '../models/cat.dart';
import 'botanical_scene.dart';

class CatHistoryPhotos extends StatelessWidget {
  const CatHistoryPhotos({
    super.key,
    required this.cat,
    required this.photos,
    required this.onOpenResult,
  });
  final Cat cat;
  final List<Cat> photos;
  final ValueChanged<Cat> onOpenResult;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ListTile(
        leading: GatalogoArt.image('ui/ui_notebook_cat', width: 42, height: 46),
        title: const Text('História e resultado'),
        subtitle: Text('${photos.length} foto(s) deste indivíduo'),
        onTap: () => onOpenResult(cat),
      ),
      if (photos.length > 1)
        SizedBox(
          height: 86,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final photo in photos)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: InkWell(
                    onTap: () => onOpenResult(photo),
                    child: Image.file(
                      File(photo.photoPath),
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.photo_outlined),
                    ),
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}
