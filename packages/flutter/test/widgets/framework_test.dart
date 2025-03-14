// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

typedef ElementRebuildCallback = void Function(StatefulElement element);

class TestState extends State<StatefulWidget> {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

@optionalTypeArgs
class _MyGlobalObjectKey<T extends State<StatefulWidget>> extends GlobalObjectKey<T> {
  const _MyGlobalObjectKey(Object value) : super(value);
}

void main() {
  testWidgets('UniqueKey control test', (WidgetTester tester) async {
    final Key key = UniqueKey();
    expect(key, hasOneLineDescription);
    expect(key, isNot(equals(UniqueKey())));
  });

  testWidgets('ObjectKey control test', (WidgetTester tester) async {
    final Object a = Object();
    final Object b = Object();
    final Key keyA = ObjectKey(a);
    final Key keyA2 = ObjectKey(a);
    final Key keyB = ObjectKey(b);

    expect(keyA, hasOneLineDescription);
    expect(keyA, equals(keyA2));
    expect(keyA.hashCode, equals(keyA2.hashCode));
    expect(keyA, isNot(equals(keyB)));
  });

  testWidgets('GlobalObjectKey toString test', (WidgetTester tester) async {
    const GlobalObjectKey one = GlobalObjectKey(1);
    const GlobalObjectKey<TestState> two = GlobalObjectKey<TestState>(2);
    const GlobalObjectKey three = _MyGlobalObjectKey(3);
    const GlobalObjectKey<TestState> four = _MyGlobalObjectKey<TestState>(4);

    expect(one.toString(), equals('[GlobalObjectKey ${describeIdentity(1)}]'));
    expect(two.toString(), equals('[GlobalObjectKey<TestState> ${describeIdentity(2)}]'));
    expect(three.toString(), equals('[_MyGlobalObjectKey ${describeIdentity(3)}]'));
    expect(four.toString(), equals('[_MyGlobalObjectKey<TestState> ${describeIdentity(4)}]'));
  });

  testWidgets('GlobalObjectKey control test', (WidgetTester tester) async {
    final Object a = Object();
    final Object b = Object();
    final Key keyA = GlobalObjectKey(a);
    final Key keyA2 = GlobalObjectKey(a);
    final Key keyB = GlobalObjectKey(b);

    expect(keyA, hasOneLineDescription);
    expect(keyA, equals(keyA2));
    expect(keyA.hashCode, equals(keyA2.hashCode));
    expect(keyA, isNot(equals(keyB)));
  });

  testWidgets('GlobalKey correct case 1 - can move global key from container widget to layoutbuilder', (WidgetTester tester) async {
    final Key key = GlobalKey(debugLabel: 'correct');
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(
          key: const ValueKey<int>(1),
          child: SizedBox(key: key),
        ),
        LayoutBuilder(
          key: const ValueKey<int>(2),
          builder: (BuildContext context, BoxConstraints constraints) {
            return const Placeholder();
          },
        ),
      ],
    ));

    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(
          key: const ValueKey<int>(1),
          child: const Placeholder(),
        ),
        LayoutBuilder(
          key: const ValueKey<int>(2),
          builder: (BuildContext context, BoxConstraints constraints) {
            return SizedBox(key: key);
          },
        ),
      ],
    ));
  });

  testWidgets('GlobalKey correct case 2 - can move global key from layoutbuilder to container widget', (WidgetTester tester) async {
    final Key key = GlobalKey(debugLabel: 'correct');
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(
          key: const ValueKey<int>(1),
          child: const Placeholder(),
        ),
        LayoutBuilder(
          key: const ValueKey<int>(2),
          builder: (BuildContext context, BoxConstraints constraints) {
            return SizedBox(key: key);
          },
        ),
      ],
    ));
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(
          key: const ValueKey<int>(1),
          child: SizedBox(key: key),
        ),
        LayoutBuilder(
          key: const ValueKey<int>(2),
          builder: (BuildContext context, BoxConstraints constraints) {
            return const Placeholder();
          },
        ),
      ],
    ));
  });

  testWidgets('GlobalKey correct case 3 - can deal with early rebuild in layoutbuilder - move backward', (WidgetTester tester) async {
    const Key key1 = GlobalObjectKey('Text1');
    const Key key2 = GlobalObjectKey('Text2');
    Key? rebuiltKeyOfSecondChildBeforeLayout;
    Key? rebuiltKeyOfFirstChildAfterLayout;
    Key? rebuiltKeyOfSecondChildAfterLayout;
    await tester.pumpWidget(
      LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Column(
            children: <Widget>[
              const _Stateful(
                child: Text(
                  'Text1',
                  textDirection: TextDirection.ltr,
                  key: key1,
                ),
              ),
              _Stateful(
                child: const Text(
                  'Text2',
                  textDirection: TextDirection.ltr,
                  key: key2,
                ),
                onElementRebuild: (StatefulElement element) {
                  // We don't want noise to override the result;
                  expect(rebuiltKeyOfSecondChildBeforeLayout, isNull);
                  final _Stateful statefulWidget = element.widget as _Stateful;
                  rebuiltKeyOfSecondChildBeforeLayout =
                    statefulWidget.child.key;
                },
              ),
            ],
          );
        },
      ),
    );
    // Result will be written during first build and need to clear it to remove
    // noise.
    rebuiltKeyOfSecondChildBeforeLayout = null;

    final _StatefulState state = tester.firstState(find.byType(_Stateful).at(1));
    state.rebuild();
    // Reorders the items
    await tester.pumpWidget(
      LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Column(
            children: <Widget>[
              _Stateful(
                child: const Text(
                  'Text2',
                  textDirection: TextDirection.ltr,
                  key: key2,
                ),
                onElementRebuild: (StatefulElement element) {
                  // Verifies the early rebuild happens before layout.
                  expect(rebuiltKeyOfSecondChildBeforeLayout, key2);
                  // We don't want noise to override the result;
                  expect(rebuiltKeyOfFirstChildAfterLayout, isNull);
                  final _Stateful statefulWidget = element.widget as _Stateful;
                  rebuiltKeyOfFirstChildAfterLayout = statefulWidget.child.key;
                },
              ),
              _Stateful(
                child: const Text(
                  'Text1',
                  textDirection: TextDirection.ltr,
                  key: key1,
                ),
                onElementRebuild: (StatefulElement element) {
                  // Verifies the early rebuild happens before layout.
                  expect(rebuiltKeyOfSecondChildBeforeLayout, key2);
                  // We don't want noise to override the result;
                  expect(rebuiltKeyOfSecondChildAfterLayout, isNull);
                  final _Stateful statefulWidget = element.widget as _Stateful;
                  rebuiltKeyOfSecondChildAfterLayout = statefulWidget.child.key;
                },
              ),
            ],
          );
        },
      ),
    );
    expect(rebuiltKeyOfSecondChildBeforeLayout, key2);
    expect(rebuiltKeyOfFirstChildAfterLayout, key2);
    expect(rebuiltKeyOfSecondChildAfterLayout, key1);
  });

  testWidgets('GlobalKey correct case 4 - can deal with early rebuild in layoutbuilder - move forward', (WidgetTester tester) async {
    const Key key1 = GlobalObjectKey('Text1');
    const Key key2 = GlobalObjectKey('Text2');
    const Key key3 = GlobalObjectKey('Text3');
    Key? rebuiltKeyOfSecondChildBeforeLayout;
    Key? rebuiltKeyOfSecondChildAfterLayout;
    Key? rebuiltKeyOfThirdChildAfterLayout;
    await tester.pumpWidget(
      LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Column(
            children: <Widget>[
              const _Stateful(
                child: Text(
                  'Text1',
                  textDirection: TextDirection.ltr,
                  key: key1,
                ),
              ),
              _Stateful(
                child: const Text(
                  'Text2',
                  textDirection: TextDirection.ltr,
                  key: key2,
                ),
                onElementRebuild: (StatefulElement element) {
                  // We don't want noise to override the result;
                  expect(rebuiltKeyOfSecondChildBeforeLayout, isNull);
                  final _Stateful statefulWidget = element.widget as _Stateful;
                  rebuiltKeyOfSecondChildBeforeLayout = statefulWidget.child.key;
                },
              ),
              const _Stateful(
                child: Text(
                  'Text3',
                  textDirection: TextDirection.ltr,
                  key: key3,
                ),
              ),
            ],
          );
        },
      ),
    );
    // Result will be written during first build and need to clear it to remove
    // noise.
    rebuiltKeyOfSecondChildBeforeLayout = null;

    final _StatefulState state = tester.firstState(find.byType(_Stateful).at(1));
    state.rebuild();
    // Reorders the items
    await tester.pumpWidget(
      LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Column(
            children: <Widget>[
              const _Stateful(
                child: Text(
                  'Text1',
                  textDirection: TextDirection.ltr,
                  key: key1,
                ),
              ),
              _Stateful(
                child: const Text(
                  'Text3',
                  textDirection: TextDirection.ltr,
                  key: key3,
                ),
                onElementRebuild: (StatefulElement element) {
                  // Verifies the early rebuild happens before layout.
                  expect(rebuiltKeyOfSecondChildBeforeLayout, key2);
                  // We don't want noise to override the result;
                  expect(rebuiltKeyOfSecondChildAfterLayout, isNull);
                  final _Stateful statefulWidget = element.widget as _Stateful;
                  rebuiltKeyOfSecondChildAfterLayout = statefulWidget.child.key;
                },
              ),
              _Stateful(
                child: const Text(
                  'Text2',
                  textDirection: TextDirection.ltr,
                  key: key2,
                ),
                onElementRebuild: (StatefulElement element) {
                  // Verifies the early rebuild happens before layout.
                  expect(rebuiltKeyOfSecondChildBeforeLayout, key2);
                  // We don't want noise to override the result;
                  expect(rebuiltKeyOfThirdChildAfterLayout, isNull);
                  final _Stateful statefulWidget = element.widget as _Stateful;
                  rebuiltKeyOfThirdChildAfterLayout = statefulWidget.child.key;
                },
              ),
            ],
          );
        },
      ),
    );
    expect(rebuiltKeyOfSecondChildBeforeLayout, key2);
    expect(rebuiltKeyOfSecondChildAfterLayout, key3);
    expect(rebuiltKeyOfThirdChildAfterLayout, key2);
  });

  testWidgets('GlobalKey correct case 5 - can deal with early rebuild in layoutbuilder - only one global key', (WidgetTester tester) async {
    const Key key1 = GlobalObjectKey('Text1');
    Key? rebuiltKeyOfSecondChildBeforeLayout;
    Key? rebuiltKeyOfThirdChildAfterLayout;
    await tester.pumpWidget(
      LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Column(
            children: <Widget>[
              const _Stateful(
                child: Text(
                  'Text1',
                  textDirection: TextDirection.ltr,
                ),
              ),
              _Stateful(
                child: const Text(
                  'Text2',
                  textDirection: TextDirection.ltr,
                  key: key1,
                ),
                onElementRebuild: (StatefulElement element) {
                  // We don't want noise to override the result;
                  expect(rebuiltKeyOfSecondChildBeforeLayout, isNull);
                  final _Stateful statefulWidget = element.widget as _Stateful;
                  rebuiltKeyOfSecondChildBeforeLayout = statefulWidget.child.key;
                },
              ),
              const _Stateful(
                child: Text(
                  'Text3',
                  textDirection: TextDirection.ltr,
                ),
              ),
            ],
          );
        },
      ),
    );
    // Result will be written during first build and need to clear it to remove
    // noise.
    rebuiltKeyOfSecondChildBeforeLayout = null;

    final _StatefulState state = tester.firstState(find.byType(_Stateful).at(1));
    state.rebuild();
    // Reorders the items
    await tester.pumpWidget(
      LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Column(
            children: <Widget>[
              const _Stateful(
                child: Text(
                  'Text1',
                  textDirection: TextDirection.ltr,
                ),
              ),
              _Stateful(
                child: const Text(
                  'Text3',
                  textDirection: TextDirection.ltr,
                ),
                onElementRebuild: (StatefulElement element) {
                  // Verifies the early rebuild happens before layout.
                  expect(rebuiltKeyOfSecondChildBeforeLayout, key1);
                },
              ),
              _Stateful(
                child: const Text(
                  'Text2',
                  textDirection: TextDirection.ltr,
                  key: key1,
                ),
                onElementRebuild: (StatefulElement element) {
                  // Verifies the early rebuild happens before layout.
                  expect(rebuiltKeyOfSecondChildBeforeLayout, key1);
                  // We don't want noise to override the result;
                  expect(rebuiltKeyOfThirdChildAfterLayout, isNull);
                  final _Stateful statefulWidget = element.widget as _Stateful;
                  rebuiltKeyOfThirdChildAfterLayout = statefulWidget.child.key;
                },
              ),
            ],
          );
        },
      ),
    );
    expect(rebuiltKeyOfSecondChildBeforeLayout, key1);
    expect(rebuiltKeyOfThirdChildAfterLayout, key1);
  });

  testWidgets('GlobalKey duplication 1 - double appearance', (WidgetTester tester) async {
    final Key key = GlobalKey(debugLabel: 'problematic');
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(
          key: const ValueKey<int>(1),
          child: SizedBox(key: key),
        ),
        Container(
          key: const ValueKey<int>(2),
          child: Placeholder(key: key),
        ),
      ],
    ));
    final dynamic exception = tester.takeException();
    expect(exception, isFlutterError);
    expect(
      exception.toString(),
      equalsIgnoringHashCodes(
        'Multiple widgets used the same GlobalKey.\n'
        'The key [GlobalKey#00000 problematic] was used by multiple widgets. The parents of those widgets were:\n'
        '- Container-[<1>]\n'
        '- Container-[<2>]\n'
        'A GlobalKey can only be specified on one widget at a time in the widget tree.',
      ),
    );
  });

  testWidgets('GlobalKey duplication 2 - splitting and changing type', (WidgetTester tester) async {
    final Key key = GlobalKey(debugLabel: 'problematic');

    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(
          key: const ValueKey<int>(1),
        ),
        Container(
          key: const ValueKey<int>(2),
        ),
        Container(
          key: key,
        ),
      ],
    ));

    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(
          key: const ValueKey<int>(1),
          child: SizedBox(key: key),
        ),
        Container(
          key: const ValueKey<int>(2),
          child: Placeholder(key: key),
        ),
      ],
    ));

    final dynamic exception = tester.takeException();
    expect(exception, isFlutterError);
    expect(
      exception.toString(),
      equalsIgnoringHashCodes(
        'Multiple widgets used the same GlobalKey.\n'
        'The key [GlobalKey#00000 problematic] was used by multiple widgets. The parents of those widgets were:\n'
        '- Container-[<1>]\n'
        '- Container-[<2>]\n'
        'A GlobalKey can only be specified on one widget at a time in the widget tree.',
      ),
    );
  });

  testWidgets('GlobalKey duplication 3 - splitting and changing type', (WidgetTester tester) async {
    final Key key = GlobalKey(debugLabel: 'problematic');
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: key),
      ],
    ));
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        SizedBox(key: key),
        Placeholder(key: key),
      ],
    ));
    final dynamic exception = tester.takeException();
    expect(exception, isFlutterError);
    expect(
      exception.toString(),
      equalsIgnoringHashCodes(
        'Duplicate keys found.\n'
        'If multiple keyed nodes exist as children of another node, they must have unique keys.\n'
        'Stack(alignment: AlignmentDirectional.topStart, textDirection: ltr, fit: loose) has multiple children with key [GlobalKey#00000 problematic].'
      ),
    );
  });

  testWidgets('GlobalKey duplication 4 - splitting and half changing type', (WidgetTester tester) async {
    final Key key = GlobalKey(debugLabel: 'problematic');
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: key),
      ],
    ));
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: key),
        Placeholder(key: key),
      ],
    ));
    final dynamic exception = tester.takeException();
    expect(exception, isFlutterError);
    expect(
      exception.toString(),
      equalsIgnoringHashCodes(
        'Duplicate keys found.\n'
        'If multiple keyed nodes exist as children of another node, they must have unique keys.\n'
        'Stack(alignment: AlignmentDirectional.topStart, textDirection: ltr, fit: loose) has multiple children with key [GlobalKey#00000 problematic].'
      ),
    );
  });

  testWidgets('GlobalKey duplication 5 - splitting and half changing type', (WidgetTester tester) async {
    final Key key = GlobalKey(debugLabel: 'problematic');
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: key),
      ],
    ));
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Placeholder(key: key),
        Container(key: key),
      ],
    ));
    expect(tester.takeException(), isFlutterError);
  });

  testWidgets('GlobalKey duplication 6 - splitting and not changing type', (WidgetTester tester) async {
    final Key key = GlobalKey(debugLabel: 'problematic');
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: key),
      ],
    ));
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: key),
        Container(key: key),
      ],
    ));
    expect(tester.takeException(), isFlutterError);
  });

  testWidgets('GlobalKey duplication 7 - appearing later', (WidgetTester tester) async {
    final Key key = GlobalKey(debugLabel: 'problematic');
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: const ValueKey<int>(1), child: Container(key: key)),
        Container(key: const ValueKey<int>(2)),
      ],
    ));
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: const ValueKey<int>(1), child: Container(key: key)),
        Container(key: const ValueKey<int>(2), child: Container(key: key)),
      ],
    ));
    expect(tester.takeException(), isFlutterError);
  });

  testWidgets('GlobalKey duplication 8 - appearing earlier', (WidgetTester tester) async {
    final Key key = GlobalKey(debugLabel: 'problematic');
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: const ValueKey<int>(1)),
        Container(key: const ValueKey<int>(2), child: Container(key: key)),
      ],
    ));
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: const ValueKey<int>(1), child: Container(key: key)),
        Container(key: const ValueKey<int>(2), child: Container(key: key)),
      ],
    ));
    expect(tester.takeException(), isFlutterError);
  });

  testWidgets('GlobalKey duplication 9 - moving and appearing later', (WidgetTester tester) async {
    final Key key = GlobalKey(debugLabel: 'problematic');
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: const ValueKey<int>(0), child: Container(key: key)),
        Container(key: const ValueKey<int>(1)),
        Container(key: const ValueKey<int>(2)),
      ],
    ));
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: const ValueKey<int>(0)),
        Container(key: const ValueKey<int>(1), child: Container(key: key)),
        Container(key: const ValueKey<int>(2), child: Container(key: key)),
      ],
    ));
    expect(tester.takeException(), isFlutterError);
  });

  testWidgets('GlobalKey duplication 10 - moving and appearing earlier', (WidgetTester tester) async {
    final Key key = GlobalKey(debugLabel: 'problematic');
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: const ValueKey<int>(1)),
        Container(key: const ValueKey<int>(2)),
        Container(key: const ValueKey<int>(3), child: Container(key: key)),
      ],
    ));
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: const ValueKey<int>(1), child: Container(key: key)),
        Container(key: const ValueKey<int>(2), child: Container(key: key)),
        Container(key: const ValueKey<int>(3)),
      ],
    ));
    expect(tester.takeException(), isFlutterError);
  });

  testWidgets('GlobalKey duplication 11 - double sibling appearance', (WidgetTester tester) async {
    final Key key = GlobalKey(debugLabel: 'problematic');
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: key),
        Container(key: key),
      ],
    ));
    expect(tester.takeException(), isFlutterError);
  });

  testWidgets('GlobalKey duplication 12 - all kinds of badness at once', (WidgetTester tester) async {
    final Key key1 = GlobalKey(debugLabel: 'problematic');
    final Key key2 = GlobalKey(debugLabel: 'problematic'); // intentionally the same label
    final Key key3 = GlobalKey(debugLabel: 'also problematic');
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: key1),
        Container(key: key1),
        Container(key: key2),
        Container(key: key1),
        Container(key: key1),
        Container(key: key2),
        Container(key: key1),
        Container(key: key1),
        Row(
          children: <Widget>[
            Container(key: key1),
            Container(key: key1),
            Container(key: key2),
            Container(key: key2),
            Container(key: key2),
            Container(key: key3),
            Container(key: key2),
          ],
        ),
        Row(
          children: <Widget>[
            Container(key: key1),
            Container(key: key1),
            Container(key: key3),
          ],
        ),
        Container(key: key3),
      ],
    ));
    final dynamic exception = tester.takeException();
    expect(exception, isFlutterError);
    expect(
      exception.toString(),
      equalsIgnoringHashCodes(
        'Duplicate keys found.\n'
        'If multiple keyed nodes exist as children of another node, they must have unique keys.\n'
        'Stack(alignment: AlignmentDirectional.topStart, textDirection: ltr, fit: loose) has multiple children with key [GlobalKey#00000 problematic].',
      ),
    );
  });

  testWidgets('GlobalKey duplication 13 - all kinds of badness at once', (WidgetTester tester) async {
    final Key key1 = GlobalKey(debugLabel: 'problematic');
    final Key key2 = GlobalKey(debugLabel: 'problematic'); // intentionally the same label
    final Key key3 = GlobalKey(debugLabel: 'also problematic');
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: key1),
        Container(key: key2),
        Container(key: key3),
      ],
    ));
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: key1),
        Container(key: key1),
        Container(key: key2),
        Container(key: key1),
        Container(key: key1),
        Container(key: key2),
        Container(key: key1),
        Container(key: key1),
        Row(
          children: <Widget>[
            Container(key: key1),
            Container(key: key1),
            Container(key: key2),
            Container(key: key2),
            Container(key: key2),
            Container(key: key3),
            Container(key: key2),
          ],
        ),
        Row(
          children: <Widget>[
            Container(key: key1),
            Container(key: key1),
            Container(key: key3),
          ],
        ),
        Container(key: key3),
      ],
    ));
    expect(tester.takeException(), isFlutterError);
  });

  testWidgets('GlobalKey duplication 14 - moving during build - before', (WidgetTester tester) async {
    final Key key = GlobalKey(debugLabel: 'problematic');
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: key),
        Container(key: const ValueKey<int>(0)),
        Container(key: const ValueKey<int>(1)),
      ],
    ));
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: const ValueKey<int>(0)),
        Container(key: const ValueKey<int>(1), child: Container(key: key)),
      ],
    ));
  });

  testWidgets('GlobalKey duplication 15 - duplicating during build - before', (WidgetTester tester) async {
    final Key key = GlobalKey(debugLabel: 'problematic');
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: key),
        Container(key: const ValueKey<int>(0)),
        Container(key: const ValueKey<int>(1)),
      ],
    ));
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: key),
        Container(key: const ValueKey<int>(0)),
        Container(key: const ValueKey<int>(1), child: Container(key: key)),
      ],
    ));
    expect(tester.takeException(), isFlutterError);
  });

  testWidgets('GlobalKey duplication 16 - moving during build - after', (WidgetTester tester) async {
    final Key key = GlobalKey(debugLabel: 'problematic');
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: const ValueKey<int>(0)),
        Container(key: const ValueKey<int>(1)),
        Container(key: key),
      ],
    ));
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: const ValueKey<int>(0)),
        Container(key: const ValueKey<int>(1), child: Container(key: key)),
      ],
    ));
  });

  testWidgets('GlobalKey duplication 17 - duplicating during build - after', (WidgetTester tester) async {
    final Key key = GlobalKey(debugLabel: 'problematic');
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: const ValueKey<int>(0)),
        Container(key: const ValueKey<int>(1)),
        Container(key: key),
      ],
    ));
    int count = 0;
    final FlutterExceptionHandler? oldHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      expect(details.exception, isFlutterError);
      count += 1;
    };
    await tester.pumpWidget(Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Container(key: const ValueKey<int>(0)),
        Container(key: const ValueKey<int>(1), child: Container(key: key)),
        Container(key: key),
      ],
    ));
    FlutterError.onError = oldHandler;
    expect(count, 1);
  });

  testWidgets('GlobalKey duplication 18 - subtree build duplicate key with same type', (WidgetTester tester) async {
    final Key key = GlobalKey(debugLabel: 'problematic');
    final Stack stack = Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        const SwapKeyWidget(childKey: ValueKey<int>(0)),
        Container(key: const ValueKey<int>(1)),
        Container(key: key),
      ],
    );
    await tester.pumpWidget(stack);
    final SwapKeyWidgetState state = tester.state(find.byType(SwapKeyWidget));
    state.swapKey(key);
    await tester.pump();
    final dynamic exception = tester.takeException();
    expect(exception, isFlutterError);
    expect(
      exception.toString(),
      equalsIgnoringHashCodes(
        'Duplicate GlobalKey detected in widget tree.\n'
        'The following GlobalKey was specified multiple times in the widget tree. This will lead '
        'to parts of the widget tree being truncated unexpectedly, because the second time a key is seen, the '
        'previous instance is moved to the new location. The key was:\n'
        '- [GlobalKey#00000 problematic]\n'
        'This was determined by noticing that after the widget with the above global key was '
        'moved out of its previous parent, that previous parent never updated during this frame, meaning that '
        'it either did not update at all or updated before the widget was moved, in either case implying that '
        'it still thinks that it should have a child with that global key.\n'
        'The specific parent that did not update after having one or more children forcibly '
        'removed due to GlobalKey reparenting is:\n'
        '- Stack(alignment: AlignmentDirectional.topStart, textDirection: ltr, fit: loose, '
        'renderObject: RenderStack#00000)\n'
        'A GlobalKey can only be specified on one widget at a time in the widget tree.',
      ),
    );
  });

  testWidgets('GlobalKey duplication 19 - subtree build duplicate key with different types', (WidgetTester tester) async {
    final Key key = GlobalKey(debugLabel: 'problematic');
    final Stack stack = Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        const SwapKeyWidget(childKey: ValueKey<int>(0)),
        Container(key: const ValueKey<int>(1)),
        Container(color: Colors.green, child: SizedBox(key: key)),
      ],
    );
    await tester.pumpWidget(stack);
    final SwapKeyWidgetState state = tester.state(find.byType(SwapKeyWidget));
    state.swapKey(key);
    await tester.pump();
    final dynamic exception = tester.takeException();
    expect(exception, isFlutterError);
    expect(
      exception.toString(),
      equalsIgnoringHashCodes(
        'Multiple widgets used the same GlobalKey.\n'
        'The key [GlobalKey#95367 problematic] was used by 2 widgets:\n'
        '  SizedBox-[GlobalKey#00000 problematic]\n'
        '  Container-[GlobalKey#00000 problematic]\n'
        'A GlobalKey can only be specified on one widget at a time in the widget tree.',
      ),
    );
  });

  testWidgets('GlobalKey duplication 20 - real duplication with early rebuild in layoutbuilder will throw', (WidgetTester tester) async {
    const Key key1 = GlobalObjectKey('Text1');
    const Key key2 = GlobalObjectKey('Text2');
    Key? rebuiltKeyOfSecondChildBeforeLayout;
    Key? rebuiltKeyOfFirstChildAfterLayout;
    Key? rebuiltKeyOfSecondChildAfterLayout;
    await tester.pumpWidget(
      LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Column(
            children: <Widget>[
              const _Stateful(
                child: Text(
                  'Text1',
                  textDirection: TextDirection.ltr,
                  key: key1,
                ),
              ),
              _Stateful(
                child: const Text(
                  'Text2',
                  textDirection: TextDirection.ltr,
                  key: key2,
                ),
                onElementRebuild: (StatefulElement element) {
                  // We don't want noise to override the result;
                  expect(rebuiltKeyOfSecondChildBeforeLayout, isNull);
                  final _Stateful statefulWidget = element.widget as _Stateful;
                  rebuiltKeyOfSecondChildBeforeLayout = statefulWidget.child.key;
                },
              ),
            ],
          );
        },
      ),
    );
    // Result will be written during first build and need to clear it to remove
    // noise.
    rebuiltKeyOfSecondChildBeforeLayout = null;

    final _StatefulState state = tester.firstState(find.byType(_Stateful).at(1));
    state.rebuild();

    await tester.pumpWidget(
      LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Column(
            children: <Widget>[
              _Stateful(
                child: const Text(
                  'Text2',
                  textDirection: TextDirection.ltr,
                  key: key2,
                ),
                onElementRebuild: (StatefulElement element) {
                  // Verifies the early rebuild happens before layout.
                  expect(rebuiltKeyOfSecondChildBeforeLayout, key2);
                  // We don't want noise to override the result;
                  expect(rebuiltKeyOfFirstChildAfterLayout, isNull);
                  final _Stateful statefulWidget = element.widget as _Stateful;
                  rebuiltKeyOfFirstChildAfterLayout = statefulWidget.child.key;
                },
              ),
              _Stateful(
                child: const Text(
                  'Text1',
                  textDirection: TextDirection.ltr,
                  key: key2,
                ),
                onElementRebuild: (StatefulElement element) {
                  // Verifies the early rebuild happens before layout.
                  expect(rebuiltKeyOfSecondChildBeforeLayout, key2);
                  // We don't want noise to override the result;
                  expect(rebuiltKeyOfSecondChildAfterLayout, isNull);
                  final _Stateful statefulWidget = element.widget as _Stateful;
                  rebuiltKeyOfSecondChildAfterLayout = statefulWidget.child.key;
                },
              ),
            ],
          );
        },
      ),
    );
    expect(rebuiltKeyOfSecondChildBeforeLayout, key2);
    expect(rebuiltKeyOfFirstChildAfterLayout, key2);
    expect(rebuiltKeyOfSecondChildAfterLayout, key2);
    final dynamic exception = tester.takeException();
    expect(exception, isFlutterError);
    expect(
      exception.toString(),
      equalsIgnoringHashCodes(
        'Multiple widgets used the same GlobalKey.\n'
        'The key [GlobalObjectKey String#00000] was used by multiple widgets. The '
        'parents of those widgets were:\n'
        '- _Stateful(state: _StatefulState#00000)\n'
        '- _Stateful(state: _StatefulState#00000)\n'
        'A GlobalKey can only be specified on one widget at a time in the widget tree.',
      ),
    );
  });

  testWidgets('GlobalKey - detach and re-attach child to different parents', (WidgetTester tester) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          height: 100,
          child: CustomScrollView(
            controller: ScrollController(),
            slivers: <Widget>[
              SliverList(
                delegate: SliverChildListDelegate(<Widget>[
                  Text('child', key: GlobalKey()),
                ]),
              ),
            ],
          ),
        ),
      ),
    ));
    final SliverMultiBoxAdaptorElement element = tester.element(find.byType(SliverList));
    late Element childElement;
    // Removing and recreating child with same Global Key should not trigger
    // duplicate key error.
    element.visitChildren((Element e) {
      childElement = e;
    });
    element.removeChild(childElement.renderObject! as RenderBox);
    element.createChild(0, after: null);
    element.visitChildren((Element e) {
      childElement = e;
    });
    element.removeChild(childElement.renderObject! as RenderBox);
    element.createChild(0, after: null);
  });

  testWidgets('GlobalKey - re-attach child to new parents, and the old parent is deactivated(unmounted)', (WidgetTester tester) async {
    // This is a regression test for https://github.com/flutter/flutter/issues/62055
    const Key key1 = GlobalObjectKey('key1');
    const Key key2 = GlobalObjectKey('key2');
    late StateSetter setState;
    int tabBarViewCnt = 2;
    TabController tabController = TabController(length: tabBarViewCnt, vsync: const TestVSync());

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setter) {
          setState = setter;
          return TabBarView(
            controller: tabController,
            children: <Widget>[
              if (tabBarViewCnt > 0) const Text('key1', key: key1),
              if (tabBarViewCnt > 1) const Text('key2', key: key2),
            ],
          );
        },
      ),
    ));

    expect(tabController.index, 0);

    // switch tabs 0 -> 1
    setState(() {
      tabController.index = 1;
    });

    await tester.pump(const Duration(seconds: 1)); // finish the animation

    expect(tabController.index, 1);

    // rebuild TabBarView that only have the 1st page with GlobalKey 'key1'
    setState(() {
      tabBarViewCnt = 1;
      tabController = TabController(length: tabBarViewCnt, vsync: const TestVSync());
    });

    await tester.pump(const Duration(seconds: 1)); // finish the animation

    expect(tabController.index, 0);
  });

  testWidgets('Defunct setState throws exception', (WidgetTester tester) async {
    late StateSetter setState;

    await tester.pumpWidget(StatefulBuilder(
      builder: (BuildContext context, StateSetter setter) {
        setState = setter;
        return Container();
      },
    ));

    // Control check that setState doesn't throw an exception.
    setState(() { });

    await tester.pumpWidget(Container());

    expect(() { setState(() { }); }, throwsFlutterError);
  });

  testWidgets('State toString', (WidgetTester tester) async {
    final TestState state = TestState();
    expect(state.toString(), contains('no widget'));
  });

  testWidgets('debugPrintGlobalKeyedWidgetLifecycle control test', (WidgetTester tester) async {
    expect(debugPrintGlobalKeyedWidgetLifecycle, isFalse);

    final DebugPrintCallback oldCallback = debugPrint;
    debugPrintGlobalKeyedWidgetLifecycle = true;

    final List<String> log = <String>[];
    debugPrint = (String? message, { int? wrapWidth }) {
      log.add(message!);
    };

    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(Container(key: key));
    expect(log, isEmpty);
    await tester.pumpWidget(const Placeholder());
    debugPrint = oldCallback;
    debugPrintGlobalKeyedWidgetLifecycle = false;

    expect(log.length, equals(2));
    expect(log[0], matches('Deactivated'));
    expect(log[1], matches('Discarding .+ from inactive elements list.'));
  });

  testWidgets('MultiChildRenderObjectElement.children', (WidgetTester tester) async {
    GlobalKey key0, key1, key2;
    await tester.pumpWidget(Column(
      key: key0 = GlobalKey(),
      children: <Widget>[
        Container(),
        Container(key: key1 = GlobalKey()),
        Container(),
        Container(key: key2 = GlobalKey()),
        Container(),
      ],
    ));
    final MultiChildRenderObjectElement element = key0.currentContext! as MultiChildRenderObjectElement;
    expect(
      element.children.map((Element element) => element.widget.key),
      <Key?>[null, key1, null, key2, null],
    );
  });

  testWidgets('Can not attach a non-RenderObjectElement to the MultiChildRenderObjectElement - mount', (WidgetTester tester) async {
    await tester.pumpWidget(
      Column(
        children: <Widget>[
          Container(),
          const _EmptyWidget(),
        ],
      ),
    );

    final dynamic exception = tester.takeException();
    expect(exception, isFlutterError);
    expect(
      exception.toString(),
      equalsIgnoringHashCodes(
        'The children of `MultiChildRenderObjectElement` must each has an associated render object.\n'
        'This typically means that the `_EmptyWidget` or its children\n'
        'are not a subtype of `RenderObjectWidget`.\n'
        'The following element does not have an associated render object:\n'
        '  _EmptyWidget\n'
        'debugCreator: _EmptyWidget ← Column ← [root]',
      ),
    );
  });

  testWidgets('Can not attach a non-RenderObjectElement to the MultiChildRenderObjectElement - update', (WidgetTester tester) async {
    await tester.pumpWidget(
      Column(
        children: <Widget>[
          Container(),
        ],
      ),
    );

    await tester.pumpWidget(
      Column(
        children: <Widget>[
          Container(),
          const _EmptyWidget(),
        ],
      ),
    );

    final dynamic exception = tester.takeException();
    expect(exception, isFlutterError);
    expect(
      exception.toString(),
      equalsIgnoringHashCodes(
        'The children of `MultiChildRenderObjectElement` must each has an associated render object.\n'
        'This typically means that the `_EmptyWidget` or its children\n'
        'are not a subtype of `RenderObjectWidget`.\n'
        'The following element does not have an associated render object:\n'
        '  _EmptyWidget\n'
        'debugCreator: _EmptyWidget ← Column ← [root]',
      ),
    );
  });

  testWidgets('Element diagnostics', (WidgetTester tester) async {
    GlobalKey key0;
    await tester.pumpWidget(Column(
      key: key0 = GlobalKey(),
      children: <Widget>[
        Container(),
        Container(key: GlobalKey()),
        Container(color: Colors.green, child: Container()),
        Container(key: GlobalKey()),
        Container(),
      ],
    ));
    final MultiChildRenderObjectElement element = key0.currentContext! as MultiChildRenderObjectElement;

    expect(element, hasAGoodToStringDeep);
    expect(
      element.toStringDeep(),
      equalsIgnoringHashCodes(
        'Column-[GlobalKey#00000](direction: vertical, mainAxisAlignment: start, crossAxisAlignment: center, renderObject: RenderFlex#00000)\n'
        '├Container\n'
        '│└LimitedBox(maxWidth: 0.0, maxHeight: 0.0, renderObject: RenderLimitedBox#00000 relayoutBoundary=up1)\n'
        '│ └ConstrainedBox(BoxConstraints(biggest), renderObject: RenderConstrainedBox#00000 relayoutBoundary=up2)\n'
        '├Container-[GlobalKey#00000]\n'
        '│└LimitedBox(maxWidth: 0.0, maxHeight: 0.0, renderObject: RenderLimitedBox#00000 relayoutBoundary=up1)\n'
        '│ └ConstrainedBox(BoxConstraints(biggest), renderObject: RenderConstrainedBox#00000 relayoutBoundary=up2)\n'
        '├Container(bg: MaterialColor(primary value: Color(0xff4caf50)))\n'
        '│└ColoredBox(color: MaterialColor(primary value: Color(0xff4caf50)), renderObject: _RenderColoredBox#00000 relayoutBoundary=up1)\n'
        '│ └Container\n'
        '│  └LimitedBox(maxWidth: 0.0, maxHeight: 0.0, renderObject: RenderLimitedBox#00000 relayoutBoundary=up2)\n'
        '│   └ConstrainedBox(BoxConstraints(biggest), renderObject: RenderConstrainedBox#00000 relayoutBoundary=up3)\n'
        '├Container-[GlobalKey#00000]\n'
        '│└LimitedBox(maxWidth: 0.0, maxHeight: 0.0, renderObject: RenderLimitedBox#00000 relayoutBoundary=up1)\n'
        '│ └ConstrainedBox(BoxConstraints(biggest), renderObject: RenderConstrainedBox#00000 relayoutBoundary=up2)\n'
        '└Container\n'
        ' └LimitedBox(maxWidth: 0.0, maxHeight: 0.0, renderObject: RenderLimitedBox#00000 relayoutBoundary=up1)\n'
        '  └ConstrainedBox(BoxConstraints(biggest), renderObject: RenderConstrainedBox#00000 relayoutBoundary=up2)\n',
      ),
    );
  });

  testWidgets('scheduleBuild while debugBuildingDirtyElements is true', (WidgetTester tester) async {
    /// ignore here is required for testing purpose because changing the flag properly is hard
    // ignore: invalid_use_of_protected_member
    tester.binding.debugBuildingDirtyElements = true;
    late FlutterError error;
    try {
      tester.binding.buildOwner!.scheduleBuildFor(
        DirtyElementWithCustomBuildOwner(tester.binding.buildOwner!, Container()),
      );
    } on FlutterError catch (e) {
      error = e;
    } finally {
      expect(error.diagnostics.length, 3);
      expect(error.diagnostics.last.level, DiagnosticLevel.hint);
      expect(
        error.diagnostics.last.toStringDeep(),
        equalsIgnoringHashCodes(
          'This might be because setState() was called from a layout or\n'
          'paint callback. If a change is needed to the widget tree, it\n'
          'should be applied as the tree is being built. Scheduling a change\n'
          'for the subsequent frame instead results in an interface that\n'
          'lags behind by one frame. If this was done to make your build\n'
          'dependent on a size measured at layout time, consider using a\n'
          'LayoutBuilder, CustomSingleChildLayout, or\n'
          'CustomMultiChildLayout. If, on the other hand, the one frame\n'
          'delay is the desired effect, for example because this is an\n'
          'animation, consider scheduling the frame in a post-frame callback\n'
          'using SchedulerBinding.addPostFrameCallback or using an\n'
          'AnimationController to trigger the animation.\n',
        ),
      );
      expect(
        error.toStringDeep(),
        'FlutterError\n'
        '   Build scheduled during frame.\n'
        '   While the widget tree was being built, laid out, and painted, a\n'
        '   new frame was scheduled to rebuild the widget tree.\n'
        '   This might be because setState() was called from a layout or\n'
        '   paint callback. If a change is needed to the widget tree, it\n'
        '   should be applied as the tree is being built. Scheduling a change\n'
        '   for the subsequent frame instead results in an interface that\n'
        '   lags behind by one frame. If this was done to make your build\n'
        '   dependent on a size measured at layout time, consider using a\n'
        '   LayoutBuilder, CustomSingleChildLayout, or\n'
        '   CustomMultiChildLayout. If, on the other hand, the one frame\n'
        '   delay is the desired effect, for example because this is an\n'
        '   animation, consider scheduling the frame in a post-frame callback\n'
        '   using SchedulerBinding.addPostFrameCallback or using an\n'
        '   AnimationController to trigger the animation.\n',
      );
    }
  });

  testWidgets('didUpdateDependencies is not called on a State that never rebuilds', (WidgetTester tester) async {
    final GlobalKey<DependentState> key = GlobalKey<DependentState>();

    /// Initial build - should call didChangeDependencies, not deactivate
    await tester.pumpWidget(Inherited(1, child: DependentStatefulWidget(key: key)));
    final DependentState state = key.currentState!;
    expect(key.currentState, isNotNull);
    expect(state.didChangeDependenciesCount, 1);
    expect(state.deactivatedCount, 0);

    /// Rebuild with updated value - should call didChangeDependencies
    await tester.pumpWidget(Inherited(2, child: DependentStatefulWidget(key: key)));
    expect(key.currentState, isNotNull);
    expect(state.didChangeDependenciesCount, 2);
    expect(state.deactivatedCount, 0);

    // reparent it - should call deactivate and didChangeDependencies
    await tester.pumpWidget(Inherited(3, child: SizedBox(child: DependentStatefulWidget(key: key))));
    expect(key.currentState, isNotNull);
    expect(state.didChangeDependenciesCount, 3);
    expect(state.deactivatedCount, 1);

    // Remove it - should call deactivate, but not didChangeDependencies
    await tester.pumpWidget(const Inherited(4, child: SizedBox()));
    expect(key.currentState, isNull);
    expect(state.didChangeDependenciesCount, 3);
    expect(state.deactivatedCount, 2);
  });

  testWidgets('StatefulElement subclass can decorate State.build', (WidgetTester tester) async {
    late bool isDidChangeDependenciesDecorated;
    late bool isBuildDecorated;

    final Widget child = Decorate(
      didChangeDependencies: (bool value) {
        isDidChangeDependenciesDecorated = value;
      },
      build: (bool value) {
        isBuildDecorated = value;
      },
    );

    await tester.pumpWidget(Inherited(0, child: child));

    expect(isBuildDecorated, isTrue);
    expect(isDidChangeDependenciesDecorated, isFalse);

    await tester.pumpWidget(Inherited(1, child: child));

    expect(isBuildDecorated, isTrue);
    expect(isDidChangeDependenciesDecorated, isFalse);
  });
  group('BuildContext.debugDoingbuild', () {
    testWidgets('StatelessWidget', (WidgetTester tester) async {
      late bool debugDoingBuildOnBuild;
      await tester.pumpWidget(
        StatelessWidgetSpy(
          onBuild: (BuildContext context) {
            debugDoingBuildOnBuild = context.debugDoingBuild;
          },
        ),
      );

      final Element context = tester.element(find.byType(StatelessWidgetSpy));

      expect(context.debugDoingBuild, isFalse);
      expect(debugDoingBuildOnBuild, isTrue);
    });
    testWidgets('StatefulWidget', (WidgetTester tester) async {
      late bool debugDoingBuildOnBuild;
      late bool debugDoingBuildOnInitState;
      late bool debugDoingBuildOnDidChangeDependencies;
      late bool debugDoingBuildOnDidUpdateWidget;
      bool? debugDoingBuildOnDispose;
      bool? debugDoingBuildOnDeactivate;

      await tester.pumpWidget(
        Inherited(
          0,
          child: StatefulWidgetSpy(
            onInitState: (BuildContext context) {
              debugDoingBuildOnInitState = context.debugDoingBuild;
            },
            onDidChangeDependencies: (BuildContext context) {
              context.dependOnInheritedWidgetOfExactType<Inherited>();
              debugDoingBuildOnDidChangeDependencies = context.debugDoingBuild;
            },
            onBuild: (BuildContext context) {
              debugDoingBuildOnBuild = context.debugDoingBuild;
            },
          ),
        ),
      );

      final Element context = tester.element(find.byType(StatefulWidgetSpy));

      expect(context.debugDoingBuild, isFalse);
      expect(debugDoingBuildOnBuild, isTrue);
      expect(debugDoingBuildOnInitState, isFalse);
      expect(debugDoingBuildOnDidChangeDependencies, isFalse);

      await tester.pumpWidget(
        Inherited(
          1,
          child: StatefulWidgetSpy(
            onDidUpdateWidget: (BuildContext context) {
              debugDoingBuildOnDidUpdateWidget = context.debugDoingBuild;
            },
            onDidChangeDependencies: (BuildContext context) {
              debugDoingBuildOnDidChangeDependencies = context.debugDoingBuild;
            },
            onBuild: (BuildContext context) {
              debugDoingBuildOnBuild = context.debugDoingBuild;
            },
            onDispose: (BuildContext context) {
              debugDoingBuildOnDispose = context.debugDoingBuild;
            },
            onDeactivate: (BuildContext context) {
              debugDoingBuildOnDeactivate = context.debugDoingBuild;
            },
          ),
        ),
      );

      expect(context.debugDoingBuild, isFalse);
      expect(debugDoingBuildOnBuild, isTrue);
      expect(debugDoingBuildOnDidUpdateWidget, isFalse);
      expect(debugDoingBuildOnDidChangeDependencies, isFalse);
      expect(debugDoingBuildOnDeactivate, isNull);
      expect(debugDoingBuildOnDispose, isNull);

      await tester.pumpWidget(Container());

      expect(context.debugDoingBuild, isFalse);
      expect(debugDoingBuildOnDispose, isFalse);
      expect(debugDoingBuildOnDeactivate, isFalse);
    });
    testWidgets('RenderObjectWidget', (WidgetTester tester) async {
      late bool debugDoingBuildOnCreateRenderObject;
      bool? debugDoingBuildOnUpdateRenderObject;
      bool? debugDoingBuildOnDidUnmountRenderObject;
      final ValueNotifier<int> notifier = ValueNotifier<int>(0);

      late BuildContext spyContext;

      Widget build() {
        return ValueListenableBuilder<int>(
          valueListenable: notifier,
          builder: (BuildContext context, int? value, Widget? child) {
            return Inherited(value, child: child!);
          },
          child: RenderObjectWidgetSpy(
            onCreateRenderObject: (BuildContext context) {
              spyContext = context;
              context.dependOnInheritedWidgetOfExactType<Inherited>();
              debugDoingBuildOnCreateRenderObject = context.debugDoingBuild;
            },
            onUpdateRenderObject: (BuildContext context) {
              debugDoingBuildOnUpdateRenderObject = context.debugDoingBuild;
            },
            onDidUnmountRenderObject: () {
              debugDoingBuildOnDidUnmountRenderObject = spyContext.debugDoingBuild;
            },
          ),
        );
      }

      await tester.pumpWidget(build());

      spyContext = tester.element(find.byType(RenderObjectWidgetSpy));

      expect(spyContext.debugDoingBuild, isFalse);
      expect(debugDoingBuildOnCreateRenderObject, isTrue);
      expect(debugDoingBuildOnUpdateRenderObject, isNull);
      expect(debugDoingBuildOnDidUnmountRenderObject, isNull);

      await tester.pumpWidget(build());

      expect(spyContext.debugDoingBuild, isFalse);
      expect(debugDoingBuildOnUpdateRenderObject, isTrue);
      expect(debugDoingBuildOnDidUnmountRenderObject, isNull);

      notifier.value++;
      debugDoingBuildOnUpdateRenderObject = false;
      await tester.pump();

      expect(spyContext.debugDoingBuild, isFalse);
      expect(debugDoingBuildOnUpdateRenderObject, isTrue);
      expect(debugDoingBuildOnDidUnmountRenderObject, isNull);

      await tester.pumpWidget(Container());

      expect(spyContext.debugDoingBuild, isFalse);
      expect(debugDoingBuildOnDidUnmountRenderObject, isFalse);
    });
  });

  testWidgets('A widget whose element has an invalid visitChildren implementation triggers a useful error message', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(_WidgetWithNoVisitChildren(_StatefulLeaf(key: key)));
    (key.currentState! as _StatefulLeafState).markNeedsBuild();
    await tester.pumpWidget(Container());
    final dynamic exception = tester.takeException();
    expect(
      // ignore: avoid_dynamic_calls
      exception.message,
      equalsIgnoringHashCodes(
        'Tried to build dirty widget in the wrong build scope.\n'
        'A widget which was marked as dirty and is still active was scheduled to be built, '
        'but the current build scope unexpectedly does not contain that widget.\n'
        'Sometimes this is detected when an element is removed from the widget tree, but '
        'the element somehow did not get marked as inactive. In that case, it might be '
        'caused by an ancestor element failing to implement visitChildren correctly, thus '
        'preventing some or all of its descendants from being correctly deactivated.\n'
        'The root of the build scope was:\n'
        '  [root]\n'
        'The offending element (which does not appear to be a descendant of the root of '
        'the build scope) was:\n'
        '  _StatefulLeaf-[GlobalKey#00000]',
      ),
    );
  });

  testWidgets('Can create BuildOwner that does not interfere with pointer router or raw key event handler', (WidgetTester tester) async {
    final int pointerRouterCount = GestureBinding.instance!.pointerRouter.debugGlobalRouteCount;
    final RawKeyEventHandler? rawKeyEventHandler = RawKeyboard.instance.keyEventHandler;
    expect(rawKeyEventHandler, isNotNull);
    BuildOwner(focusManager: FocusManager());
    expect(GestureBinding.instance!.pointerRouter.debugGlobalRouteCount, pointerRouterCount);
    expect(RawKeyboard.instance.keyEventHandler, same(rawKeyEventHandler));
  });

  testWidgets('Can access debugFillProperties without _LateInitializationError', (WidgetTester tester) async {
    final DiagnosticPropertiesBuilder builder = DiagnosticPropertiesBuilder();
    TestRenderObjectElement().debugFillProperties(builder);
    expect(builder.properties.any((DiagnosticsNode property) => property.name == 'renderObject' && property.value == null), isTrue);
  });

  testWidgets('BuildOwner.globalKeyCount keeps track of in-use global keys', (WidgetTester tester) async {
    final int initialCount = tester.binding.buildOwner!.globalKeyCount;
    final GlobalKey key1 = GlobalKey();
    final GlobalKey key2 = GlobalKey();
    await tester.pumpWidget(Container(key: key1));
    expect(tester.binding.buildOwner!.globalKeyCount, initialCount + 1);
    await tester.pumpWidget(Container(key: key1, child: Container()));
    expect(tester.binding.buildOwner!.globalKeyCount, initialCount + 1);
    await tester.pumpWidget(Container(key: key1, child: Container(key: key2)));
    expect(tester.binding.buildOwner!.globalKeyCount, initialCount + 2);
    await tester.pumpWidget(Container());
    expect(tester.binding.buildOwner!.globalKeyCount, initialCount + 0);
  });

  testWidgets('Widget and State properties are nulled out when unmounted', (WidgetTester tester) async {
    await tester.pumpWidget(const _StatefulLeaf());
    final StatefulElement element = tester.element<StatefulElement>(find.byType(_StatefulLeaf));
    expect(element.state, isA<State<_StatefulLeaf>>());
    expect(element.widget, isA<_StatefulLeaf>());
    // Replace the widget tree to unmount the element.
    await tester.pumpWidget(Container());
    // Accessing state/widget now throws a CastError because they have been
    // nulled out to reduce severity of memory leaks when an Element (e.g. in
    // the form of a BuildContext) is retained past its useful life. See also
    // https://github.com/flutter/flutter/issues/79605 for examples why this may
    // occur.
    expect(() => element.state, throwsA(isA<TypeError>()));
    expect(() => element.widget, throwsA(isA<TypeError>()));
  });

  testWidgets('LayerLink can be swapped between parent and child container layers', (WidgetTester tester) async {
    // Regression test for https://github.com/flutter/flutter/issues/96959.
    final LayerLink link = LayerLink();
    await tester.pumpWidget(_TestLeaderLayerWidget(
        link: link,
        child: const _TestLeaderLayerWidget(
          child: Placeholder(),
        )
    ));
    expect(tester.takeException(), isNull);

    // Swaps the layer link.
    await tester.pumpWidget(_TestLeaderLayerWidget(
        child: _TestLeaderLayerWidget(
          link: link,
          child: const Placeholder(),
        ),
    ));
    expect(tester.takeException(), isNull);

  });

  testWidgets('Deactivate and activate are called correctly', (WidgetTester tester) async {
    final List<String> states = <String>[];
    Widget build([Key? key]) {
      return StatefulWidgetSpy(
        key: key,
        onInitState: (BuildContext context) { states.add('initState'); },
        onDidUpdateWidget: (BuildContext context) { states.add('didUpdateWidget'); },
        onDeactivate: (BuildContext context) { states.add('deactivate'); },
        onActivate: (BuildContext context) { states.add('activate'); },
        onBuild: (BuildContext context) { states.add('build'); },
        onDispose: (BuildContext context) { states.add('dispose'); },
      );
    }
    Future<void> pumpWidget(Widget widget) {
      states.clear();
      return tester.pumpWidget(widget);
    }

    await pumpWidget(build());
    expect(states, <String>['initState', 'build']);
    await pumpWidget(Container(child: build()));
    expect(states, <String>['deactivate', 'initState', 'build', 'dispose']);
    await pumpWidget(Container());
    expect(states, <String>['deactivate', 'dispose']);

    final GlobalKey key = GlobalKey();
    await pumpWidget(build(key));
    expect(states, <String>['initState', 'build']);
    await pumpWidget(Container(child: build(key)));
    expect(states, <String>['deactivate', 'activate', 'didUpdateWidget', 'build']);
    await pumpWidget(Container());
    expect(states, <String>['deactivate', 'dispose']);
  });

  testWidgets('RenderObjectElement.unmount disposes of its renderObject', (WidgetTester tester) async {
    await tester.pumpWidget(const Placeholder());
    final RenderObjectElement element = tester.allElements.whereType<RenderObjectElement>().first;
    final RenderObject renderObject = element.renderObject;
    expect(renderObject.debugDisposed, false);

    await tester.pumpWidget(Container());

    expect(() => element.renderObject, throwsAssertionError);
    expect(renderObject.debugDisposed, true);
  });

  testWidgets('Getting the render object of an unmounted element throws', (WidgetTester tester) async {
    await tester.pumpWidget(const _StatefulLeaf());
    final StatefulElement element = tester.element<StatefulElement>(find.byType(_StatefulLeaf));
    expect(element.state, isA<State<_StatefulLeaf>>());
    expect(element.widget, isA<_StatefulLeaf>());
    // Replace the widget tree to unmount the element.
    await tester.pumpWidget(Container());

  expect(
    () => element.findRenderObject(),
    throwsA(isA<FlutterError>().having(
      (FlutterError error) => error.message,
      'message',
      equalsIgnoringHashCodes('''
Cannot get renderObject of inactive element.
In order for an element to have a valid renderObject, it must be active, which means it is part of the tree.
Instead, this element is in the _ElementLifecycle.defunct state.
If you called this method from a State object, consider guarding it with State.mounted.
The findRenderObject() method was called for the following element:
  StatefulElement#00000(DEFUNCT)'''),
      )),
    );
  });

  testWidgets('Elements use the identity hashCode', (WidgetTester tester) async {
    final StatefulElement statefulElement = StatefulElement(const _StatefulLeaf());
    expect(statefulElement.hashCode, identityHashCode(statefulElement));

    final StatelessElement statelessElement = StatelessElement(const Placeholder());

    expect(statelessElement.hashCode, identityHashCode(statelessElement));

    final InheritedElement inheritedElement = InheritedElement(
      const Directionality(textDirection: TextDirection.ltr, child: Placeholder()),
    );

    expect(inheritedElement.hashCode, identityHashCode(inheritedElement));
  });
}

class _WidgetWithNoVisitChildren extends StatelessWidget {
  const _WidgetWithNoVisitChildren(this.child, { Key? key }) :
    super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) => child;

  @override
  _WidgetWithNoVisitChildrenElement createElement() => _WidgetWithNoVisitChildrenElement(this);
}

class _WidgetWithNoVisitChildrenElement extends StatelessElement {
  _WidgetWithNoVisitChildrenElement(_WidgetWithNoVisitChildren widget): super(widget);

  @override
  void visitChildren(ElementVisitor visitor) {
    // This implementation is intentionally buggy, to test that an error message is
    // shown when this situation occurs.
    // The superclass has the correct implementation (calling `visitor(_child)`), so
    // we don't call it here.
  }
}

class _StatefulLeaf extends StatefulWidget {
  const _StatefulLeaf({ Key? key }) : super(key: key);

  @override
  State<_StatefulLeaf> createState() => _StatefulLeafState();
}

class _StatefulLeafState extends State<_StatefulLeaf> {
  void markNeedsBuild() {
    setState(() { });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class Decorate extends StatefulWidget {
  const Decorate({
    Key? key,
    required this.didChangeDependencies,
    required this.build,
  }) :
    assert(didChangeDependencies != null),
    assert(build != null),
    super(key: key);

  final void Function(bool isInBuild) didChangeDependencies;
  final void Function(bool isInBuild) build;

  @override
  State<Decorate> createState() => _DecorateState();

  @override
  DecorateElement createElement() => DecorateElement(this);
}

class DecorateElement extends StatefulElement {
  DecorateElement(Decorate widget): super(widget);

  bool isDecorated = false;

  @override
  Widget build() {
    try {
      isDecorated = true;
      return super.build();
    } finally {
      isDecorated = false;
    }
  }
}

class _DecorateState extends State<Decorate> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.didChangeDependencies.call((context as DecorateElement).isDecorated);
  }
  @override
  Widget build(covariant DecorateElement context) {
    context.dependOnInheritedWidgetOfExactType<Inherited>();
    widget.build.call(context.isDecorated);
    return Container();
  }
}

class DirtyElementWithCustomBuildOwner extends Element {
  DirtyElementWithCustomBuildOwner(BuildOwner buildOwner, Widget widget)
    : _owner = buildOwner, super(widget);

  final BuildOwner _owner;

  @override
  void performRebuild() {}

  @override
  BuildOwner get owner => _owner;

  @override
  bool get dirty => true;

  @override
  bool get debugDoingBuild => throw UnimplementedError();
}

class Inherited extends InheritedWidget {
  const Inherited(this.value, {Key? key, required Widget child}) : super(key: key, child: child);

  final int? value;

  @override
  bool updateShouldNotify(Inherited oldWidget) => oldWidget.value != value;
}

class DependentStatefulWidget extends StatefulWidget {
  const DependentStatefulWidget({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => DependentState();
}

class DependentState extends State<DependentStatefulWidget> {
  int didChangeDependenciesCount = 0;
  int deactivatedCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    didChangeDependenciesCount += 1;
  }

  @override
  Widget build(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<Inherited>();
    return const SizedBox();
  }

  @override
  void deactivate() {
    super.deactivate();
    deactivatedCount += 1;
  }
}

class SwapKeyWidget extends StatefulWidget {
  const SwapKeyWidget({Key? key, this.childKey}): super(key: key);

  final Key? childKey;
  @override
  SwapKeyWidgetState createState() => SwapKeyWidgetState();
}

class SwapKeyWidgetState extends State<SwapKeyWidget> {
  Key? key;

  @override
  void initState() {
    super.initState();
    key = widget.childKey;
  }

  void swapKey(Key newKey) {
    setState(() {
      key = newKey;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(key: key);
  }
}

class _Stateful extends StatefulWidget {
  const _Stateful({Key? key, required this.child, this.onElementRebuild}) : super(key: key);
  final Text child;
  final ElementRebuildCallback? onElementRebuild;
  @override
  State<StatefulWidget> createState() => _StatefulState();

  @override
  StatefulElement createElement() => StatefulElementSpy(this);
}

class _StatefulState extends State<_Stateful> {
  void rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class StatefulElementSpy extends StatefulElement {
  StatefulElementSpy(StatefulWidget widget) : super(widget);

  _Stateful get _statefulWidget => widget as _Stateful;

  @override
  void rebuild() {
    _statefulWidget.onElementRebuild?.call(this);
    super.rebuild();
  }
}

class StatelessWidgetSpy extends StatelessWidget {
  const StatelessWidgetSpy({
    Key? key,
    required this.onBuild,
  })  : assert(onBuild != null),
        super(key: key);

  final void Function(BuildContext) onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild(context);
    return Container();
  }
}

class StatefulWidgetSpy extends StatefulWidget {
  const StatefulWidgetSpy({
    Key? key,
    this.onBuild,
    this.onInitState,
    this.onDidChangeDependencies,
    this.onDispose,
    this.onDeactivate,
    this.onActivate,
    this.onDidUpdateWidget,
  })  : super(key: key);

  final void Function(BuildContext)? onBuild;
  final void Function(BuildContext)? onInitState;
  final void Function(BuildContext)? onDidChangeDependencies;
  final void Function(BuildContext)? onDispose;
  final void Function(BuildContext)? onDeactivate;
  final void Function(BuildContext)? onActivate;
  final void Function(BuildContext)? onDidUpdateWidget;

  @override
  State<StatefulWidgetSpy> createState() => _StatefulWidgetSpyState();
}

class _StatefulWidgetSpyState extends State<StatefulWidgetSpy> {
  @override
  void initState() {
    super.initState();
    widget.onInitState?.call(context);
  }

  @override
  void deactivate() {
    super.deactivate();
    widget.onDeactivate?.call(context);
  }

  @override
  void activate() {
    super.activate();
    widget.onActivate?.call(context);
  }

  @override
  void dispose() {
    super.dispose();
    widget.onDispose?.call(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.onDidChangeDependencies?.call(context);
  }

  @override
  void didUpdateWidget(StatefulWidgetSpy oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.onDidUpdateWidget?.call(context);
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuild?.call(context);
    return Container();
  }
}

class RenderObjectWidgetSpy extends LeafRenderObjectWidget {
  const RenderObjectWidgetSpy({
    Key? key,
    this.onCreateRenderObject,
    this.onUpdateRenderObject,
    this.onDidUnmountRenderObject,
  })  : super(key: key);

  final void Function(BuildContext)? onCreateRenderObject;
  final void Function(BuildContext)? onUpdateRenderObject;
  final void Function()? onDidUnmountRenderObject;

  @override
  RenderObject createRenderObject(BuildContext context) {
    onCreateRenderObject?.call(context);
    return FakeLeafRenderObject();
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    onUpdateRenderObject?.call(context);
  }

  @override
  void didUnmountRenderObject(RenderObject renderObject) {
    super.didUnmountRenderObject(renderObject);
    onDidUnmountRenderObject?.call();
  }
}

class FakeLeafRenderObject extends RenderBox {
  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.biggest;
  }

  @override
  void performLayout() {
    size = constraints.biggest;
  }
}

class TestRenderObjectElement extends RenderObjectElement {
  TestRenderObjectElement() : super(Table());
}

class _EmptyWidget extends Widget {
  const _EmptyWidget({Key? key}) : super(key: key);

  @override
  Element createElement() => _EmptyElement(this);
}

class _EmptyElement extends Element {
  _EmptyElement(_EmptyWidget widget) : super(widget);

  @override
  bool get debugDoingBuild => false;

  @override
  void performRebuild() {}
}

class _TestLeaderLayerWidget extends SingleChildRenderObjectWidget {
  const _TestLeaderLayerWidget({
    Key? key,
    this.link,
    Widget? child,
  }) : super(key: key, child: child);
  final LayerLink? link;

  @override
  _RenderTestLeaderLayerWidget createRenderObject(BuildContext context) {
    return _RenderTestLeaderLayerWidget(
      link: link,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderTestLeaderLayerWidget renderObject) {
    renderObject.link = link;
  }
}

class _RenderTestLeaderLayerWidget extends RenderProxyBox {
  _RenderTestLeaderLayerWidget({
    LayerLink? link,
    RenderBox? child,
  }) : _link = link,
        super(child);

  LayerLink? get link => _link;
  LayerLink? _link;
  set link(LayerLink? value) {
    if (_link == value) {
      return;
    }
    _link = value;
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (_link != null) {
      context.pushLayer(LeaderLayer(link: _link!, offset: offset),(_, __){}, Offset.zero);
    }
  }
}
