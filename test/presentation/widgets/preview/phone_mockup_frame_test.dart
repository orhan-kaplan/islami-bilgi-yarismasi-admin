import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/preview/phone_mockup_frame.dart';

void main() {
  /// Wraps [PhoneMockupFrame] in a minimal [MaterialApp] for testing.
  Widget createTestWidget({Widget? child}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: PhoneMockupFrame(
            child: child ?? const ColoredBox(color: Colors.blue),
          ),
        ),
      ),
    );
  }

  group('PhoneMockupFrame', () {
    testWidgets('renders with correct 9:19.5 aspect ratio dimensions',
        (tester) async {
      // Use a larger surface to avoid constraints clamping the height
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());

      // The frame should have 320x693 size constants
      expect(PhoneMockupFrame.frameWidth, 320);
      expect(PhoneMockupFrame.frameHeight, 693);

      // Verify the aspect ratio is approximately 9:19.5
      const expectedRatio = 9.0 / 19.5;
      const actualRatio =
          PhoneMockupFrame.frameWidth / PhoneMockupFrame.frameHeight;
      expect(actualRatio, closeTo(expectedRatio, 0.01));

      // Verify the rendered size matches
      final renderBox = tester.renderObject<RenderBox>(
        find.byType(PhoneMockupFrame),
      );
      expect(renderBox.size.width, PhoneMockupFrame.frameWidth);
      expect(renderBox.size.height, PhoneMockupFrame.frameHeight);
    });

    testWidgets('has correct border radius of 40px', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration! as BoxDecoration;

      expect(
        decoration.borderRadius,
        BorderRadius.circular(40),
      );
    });

    testWidgets('has 3px grey border', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration! as BoxDecoration;
      final border = decoration.border! as Border;

      expect(border.top.width, 3);
      expect(border.top.color, Colors.grey.shade700);
    });

    testWidgets('has box shadow with 20px blur', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration! as BoxDecoration;

      expect(decoration.boxShadow!.length, 1);

      final shadow = decoration.boxShadow!.first;
      expect(shadow.blurRadius, 20);
      expect(shadow.offset, const Offset(0, 10));
      expect(shadow.color, Colors.black.withValues(alpha: 0.5));
    });

    testWidgets('clips content with ClipRRect at 37px radius', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(
        clipRRect.borderRadius,
        BorderRadius.circular(PhoneMockupFrame.contentBorderRadius),
      );
      expect(PhoneMockupFrame.contentBorderRadius, 37);
    });

    testWidgets('renders child widget inside the frame', (tester) async {
      await tester.pumpWidget(createTestWidget(
        child: const Text('Preview Content'),
      ));

      expect(find.text('Preview Content'), findsOneWidget);
    });

    testWidgets('has black background color', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration! as BoxDecoration;

      expect(decoration.color, Colors.black);
    });
  });
}
