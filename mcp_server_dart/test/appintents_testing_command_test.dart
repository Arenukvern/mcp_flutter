import 'dart:io';

import 'package:flutter_mcp_toolkit_server/src/cli/appintents_testing_command.dart';
import 'package:test/test.dart';

void main() {
  test('emits AppIntentsTesting scaffold from manifest and fixtures', () {
    final temp = Directory.systemTemp.createTempSync('appintents_testing_');
    addTearDown(() => temp.deleteSync(recursive: true));

    final manifest = File('${temp.path}/agent_manifest.json')
      ..writeAsStringSync('''
{
  "version": 1,
  "platform": "web",
  "entityTypes": [
    {
      "qualifiedName": "app_screen",
      "namespace": "app",
      "name": "screen",
      "displayName": "Screen",
      "pluralDisplayName": "Screens",
      "description": "Open a screen",
      "titleKey": "title"
    }
  ],
  "tools": [
    {
      "qualifiedName": "app_set_greeting",
      "namespace": "app",
      "name": "set_greeting",
      "description": "Set greeting",
      "kind": "tool",
      "inputSchema": {
        "type": "object",
        "properties": {
          "text": {"type": "string"}
        },
        "required": ["text"]
      }
    }
  ]
}
''');
    final samples = File('${temp.path}/samples.json')
      ..writeAsStringSync('''
{
  "app_set_greeting": {"text": "hello"}
}
''');
    final entities = File('${temp.path}/entities.json')
      ..writeAsStringSync('''
{
  "app_screen": {
    "identifier": "home",
    "search": "Home",
    "expectedTitle": "Home"
  }
}
''');
    final swift = emitAppIntentsTestingScaffold(
      manifestFile: manifest,
      bundleIdentifier: 'com.example.App',
      testClassName: 'GeneratedIntentTests',
      sampleArgumentsFile: samples,
      entityFixturesFile: entities,
    );

    expect(swift, contains('import AppIntentsTesting'));
    expect(
      swift,
      contains('IntentDefinitions(bundleIdentifier: "com.example.App")'),
    );
    expect(swift, contains('final class GeneratedIntentTests: XCTestCase'));
    expect(swift, contains('testAppSetGreetingIntentLiveInvocation'));
    expect(swift, contains('makeIntent(text: "hello")'));
    expect(swift, contains('definitions.entities["AppScreenEntity"]'));
    expect(swift, contains('entities(identifiers: ["home"])'));
    expect(swift, contains('spotlightQuery("Home")'));
  });

  test('committed AppIntentsTesting entity fixture matches showcase seed', () {
    final fixture = File(
      '../flutter_test_app/tool/intentcall/appintents_testing_entities.json',
    );
    final seedSource = File('../flutter_test_app/lib/main.dart');

    final fixtures = readAppIntentsTestingEntityFixtures(fixture);
    final appScreen = fixtures['app_screen']!;
    final source = seedSource.readAsStringSync();

    expect(appScreen.identifier, 'greeting_form');
    expect(appScreen.search, 'Greeting Form');
    expect(appScreen.expectedTitle, 'Greeting Form');
    expect(source, contains("identifier: '${appScreen.identifier}'"));
    expect(source, contains("title: '${appScreen.expectedTitle}'"));
  });

  test('rejects malformed sample argument fixtures', () {
    final temp = Directory.systemTemp.createTempSync('appintents_fixture_');
    addTearDown(() => temp.deleteSync(recursive: true));

    final samples = File('${temp.path}/samples.json')
      ..writeAsStringSync('''
{
  "app_set_greeting": "hello"
}
''');

    expect(
      () => readAppIntentsTestingSampleArguments(samples),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects malformed entity fixtures', () {
    final temp = Directory.systemTemp.createTempSync('appintents_entity_');
    addTearDown(() => temp.deleteSync(recursive: true));

    final entities = File('${temp.path}/entities.json')
      ..writeAsStringSync('''
{
  "app_screen": {"identifier": "home"}
}
''');

    expect(
      () => readAppIntentsTestingEntityFixtures(entities),
      throwsA(isA<FormatException>()),
    );
  });
}
