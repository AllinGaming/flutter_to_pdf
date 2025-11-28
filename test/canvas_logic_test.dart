import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_canvas/main.dart';

void main() {
  test('computeCenteredOffset respects inset and clamps inside page', () {
    final offset = computeCenteredOffset(595, 120, insetPerSide: 16);
    expect(offset, greaterThanOrEqualTo(16));
    expect(offset, lessThan(595 - 120 - 16));
    // Symmetric center math should land at page midpoint adjusted for inset.
    expect(offset, closeTo((595 - 120) / 2, 0.5));
  });

  test('computeCenteredOffset clamps when child is wider than container', () {
    final offset = computeCenteredOffset(100, 180, insetPerSide: 10);
    expect(offset, equals(10));
  });

  test('snapOffset snaps to grid when enabled', () {
    final origin = const Offset(10.2, 10.1);
    final moved = snapOffset(
      const Offset(2.8, 2.8),
      origin,
      enabled: true,
      grid: 4,
    );
    expect(moved.dx % 4, equals(0));
    expect(moved.dy % 4, equals(0));

    final free = snapOffset(
      const Offset(2.8, 2.8),
      origin,
      enabled: false,
      grid: 4,
    );
    expect(free.dx, closeTo(13.0, 0.01));
    expect(free.dy, closeTo(12.9, 0.01));
  });

  test('duplicateElement creates a shifted deep copy', () {
    final original = CanvasElement(
      id: 'a',
      kind: CanvasElementKind.text,
      offset: const Offset(10, 10),
      size: const Size(50, 20),
      text: 'Hello',
      color: Colors.orange,
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      bytes: Uint8List.fromList([1, 2, 3]),
      radius: 12,
    );
    final clone = duplicateElement(original, 'b');

    expect(clone.id, 'b');
    expect(
      clone.offset,
      const Offset(26, 26),
    ); // shifted by 16 px in both directions
    expect(clone.text, original.text);
    expect(clone.color, original.color);
    expect(clone.textStyle?.fontSize, original.textStyle?.fontSize);
    expect(clone.radius, equals(original.radius));
    expect(clone.bytes, isNotNull);
    expect(clone.bytes, isNot(same(original.bytes)));
    expect(clone.bytes, orderedEquals(original.bytes!));
  });

  test('bringForwardById moves element forward by one slot', () {
    final list = [
      CanvasElement(
        id: 'a',
        kind: CanvasElementKind.text,
        offset: Offset.zero,
        size: Size.zero,
      ),
      CanvasElement(
        id: 'b',
        kind: CanvasElementKind.box,
        offset: Offset.zero,
        size: Size.zero,
      ),
      CanvasElement(
        id: 'c',
        kind: CanvasElementKind.box,
        offset: Offset.zero,
        size: Size.zero,
      ),
    ];

    final next = bringForwardById(list, 'b');
    expect(next.map((e) => e.id).toList(), ['a', 'c', 'b']);
    // Edge conditions: last element stays.
    final noChange = bringForwardById(next, 'b');
    expect(noChange, next);
  });

  test('sendBackwardById moves element backward by one slot', () {
    final list = [
      CanvasElement(
        id: 'a',
        kind: CanvasElementKind.text,
        offset: Offset.zero,
        size: Size.zero,
      ),
      CanvasElement(
        id: 'b',
        kind: CanvasElementKind.box,
        offset: Offset.zero,
        size: Size.zero,
      ),
      CanvasElement(
        id: 'c',
        kind: CanvasElementKind.box,
        offset: Offset.zero,
        size: Size.zero,
      ),
    ];

    final next = sendBackwardById(list, 'b');
    expect(next.map((e) => e.id).toList(), ['b', 'a', 'c']);
    // Edge conditions: first element stays.
    final noChange = sendBackwardById(next, 'b');
    expect(noChange, next);
  });

  test('template builders return expected structures', () {
    var i = 0;
    String genId() => 'id${i++}';

    final headerBody = buildHeaderBodyTemplate(genId);
    expect(headerBody.length, 2);
    expect(headerBody.where((e) => e.kind == CanvasElementKind.text).length, 1);

    final twoCol = buildTwoColumnTemplate(genId);
    expect(twoCol.length, 3);
    expect(twoCol.first.offset.dx, greaterThanOrEqualTo(40));

    final hero = buildCoverHeroTemplate(genId);
    expect(hero.length, 3);
    expect(hero.first.kind, CanvasElementKind.box);
    expect(hero[1].text, contains('Cover hero'));

    final callout = buildCalloutTemplate(genId);
    expect(callout.length, 3);
    expect(callout.first.radius, greaterThan(0));
  });

  test('pdfColorFromFlutter keeps ARGB intact', () {
    final color = const Color.fromARGB(128, 10, 20, 30);
    final pdfColor = pdfColorFromFlutter(color);
    expect(pdfColor.toInt(), equals(color.toARGB32()));
  });

  test('contentArea returns drawable size after inset', () {
    final size = contentArea(const Size(200, 300), insetPerSide: 10);
    expect(size.width, 180);
    expect(size.height, 280);
  });

  test('ptsToMm converts 72 points to 25.4 mm (1 inch)', () {
    expect(ptsToMm(72.0), closeTo(25.4, 0.001));
  });
}
