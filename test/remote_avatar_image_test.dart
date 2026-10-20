import 'package:catlogue/widgets/remote_avatar_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty avatars retain the caller fallback and centering', (
    tester,
  ) async {
    const fallback = Icon(Icons.person);
    await tester.pumpWidget(
      const MaterialApp(
        home: RemoteAvatarImage(
          url: '',
          fallback: fallback,
          centerFallback: true,
        ),
      ),
    );
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(
      find.ancestor(
        of: find.byIcon(Icons.person),
        matching: find.byType(Center),
      ),
      findsWidgets,
    );
  });
}
