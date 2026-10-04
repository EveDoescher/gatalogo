import 'package:flutter/material.dart';

import 'illustrated_home_components.dart';

class AvatarChoiceSheet extends StatelessWidget {
  const AvatarChoiceSheet({super.key, this.currentUrl});
  final String? currentUrl;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Como você quer aparecer?', style: HomeArt.title(24)),
          const SizedBox(height: 8),
          const Text(
            'Escolha Bapinho, Bapinha ou use uma foto sua. Você pode trocar quando quiser.',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              for (final preset in FramedUserAvatar.presets)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Semantics(
                      selected:
                          FramedUserAvatar.presetFor(currentUrl) == preset,
                      button: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.pop(context, preset),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              FramedUserAvatar(
                                url: '/app/account/avatar/preset/$preset',
                                size: 104,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                preset == 'bapinho' ? 'Bapinho' : 'Bapinha',
                                style: HomeArt.title(20),
                              ),
                              if (FramedUserAvatar.presetFor(currentUrl) ==
                                  preset)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: HomeArt.green,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Tirar uma foto'),
            onTap: () => Navigator.pop(context, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Escolher da galeria'),
            onTap: () => Navigator.pop(context, 'gallery'),
          ),
        ],
      ),
    ),
  );
}
