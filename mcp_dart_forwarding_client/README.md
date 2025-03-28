# Dart Forwarding Client

This package is a part of the [Flutter MCP](https://github.com/Arenukvern/mcp_flutter).

A Dart client for connecting to the forwarding server. This client implements the same functionality as the TypeScript BrowserForwardingClient and provides a WebSocket-based bi-directional communication layer between Flutter applications and Inspector clients.

## Features

- WebSocket-based communication
- JSON-RPC 2.0 protocol support
- Event-based architecture
- Automatic reconnection
- Method registration and handling
- Compatible with Flutter and Dart web applications

## Installation

Add this dependency to your pubspec.yaml:

```yaml
dependencies:
  mcp_dart_forwarding_client: ^0.1.0
```

## Usage

```dart
import 'package:mcp_dart_forwarding_client/mcp_dart_forwarding_client.dart';

void main() async {
  // Create a client
  final client = ForwardingClient('flutter');

  // Connect to the forwarding server
  await client.connect('localhost', 8080);

  // Register a method handler
  client.registerMethod('ping', (params) async {
    return 'pong';
  });

  // Call a method on the other side
  final result = await client.callMethod<String>('hello', params: {'name': 'world'});
  print('Result: $result');

  // Listen for events
  client.on('connected', () {
    print('Connected!');
  });

  client.on('disconnected', () {
    print('Disconnected!');
  });

  // Disconnect when done
  client.disconnect();
}
```

## Examples

The package includes several examples to help you get started:

### Console Example

A simple command-line application that demonstrates basic functionality.

```bash
cd example
dart run main.dart
```

### Web Example

A plain HTML/Dart web application that demonstrates browser usage.

```bash
cd example/web_example
dart pub get
webdev serve
```

### Jaspr Example

A modern web application using the Jaspr framework for a more structured approach.

```bash
cd example/jaspr_example
dart pub get
dart run build_runner serve
```

## API Reference

### Constructor

```dart
ForwardingClient(String clientType, {String? clientId})
```

- `clientType`: The type of client ('inspector' or 'flutter')
- `clientId`: Optional client ID (will be generated if not provided)

### Methods

#### connect

```dart
Future<void> connect(String host, int port, {String path = '/forward'})
```

Connects to the forwarding server.

#### callMethod

```dart
Future<T> callMethod<T>(String method, {Map<String, dynamic> params = const {}})
```

Calls a method via the forwarding server.

#### registerMethod

```dart
void registerMethod(String method, Future<dynamic> Function(dynamic) handler)
```

Registers a method handler.

#### disconnect

```dart
void disconnect()
```

Disconnects from the forwarding server.

#### on/off

```dart
void on(String event, Function callback)
void off(String event, Function callback)
```

Adds/removes an event listener.

#### sendMessage

```dart
void sendMessage(dynamic message)
```

Sends a raw message through the forwarding server.

#### isConnected

```dart
bool isConnected()
```

Checks if connected to the forwarding server.

#### getClientId/getClientType

```dart
String getClientId()
String getClientType()
```

Gets the client ID/type.

## License

This project is licensed under the MIT License.
