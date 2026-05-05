---
description: always use for creating or modifing models, dto or data in .dart files
globs:
alwaysApply: false
---

# Dart Extension Type Const Models Guide

## Principle Overview

Extension type const models provide type-safe wrappers around primitive types (String, int, Map) while maintaining zero runtime overhead. They're ideal for creating strongly-typed identifiers, value objects, and data containers that need compile-time safety without performance penalties.

## Required Dependency

Always use the `from_json_to_json` package for type-safe JSON handling:

```yaml
dependencies:
  from_json_to_json: ^0.3.0
```

Import in your Dart files:

```dart
import 'package:from_json_to_json/from_json_to_json.dart';
```

## Core Pattern Structure

### Basic String-based ID Pattern

```dart
/// Extension type that represents a [specific domain concept].
///
/// [Brief description of purpose and usage context]
///
/// Provides functionality to handle JSON serialization/deserialization
/// and [specific domain operations].
extension type const EntityId(String value) {
  factory EntityId.fromJson(final value) => EntityId(jsonDecodeString(value));

  String toJson() => value;

  bool get isEmpty => value.isEmpty;
  bool get isNotEmpty => value.isNotEmpty;

  EntityId whenEmptyUse(final EntityId other) => isEmpty ? other : this;

  static const empty = EntityId('');
}
```

### Numeric ID Pattern

```dart
extension type const NumericId(int value) {
  factory NumericId.fromJson(final value) => NumericId(jsonDecodeInt(value));

  int toJson() => value;

  bool get isZero => value == 0;
  bool get isPositive => value > 0;

  NumericId whenZeroUse(final NumericId other) => isZero ? other : this;

  static const zero = NumericId(0);
}
```

### Complex Data Structure Pattern

```dart
/// Extension type that wraps [Map/List/other complex type].
///
/// [Description of the data structure purpose]
extension type const DataModel._(Map<String, dynamic> value) {

  factory DataModel({
    required final String specificField,
    required final int numericField,
    required final List<String> listField,
    required final Map<String, int> mapField,
    required final DateTime dateField,
  }) => DataModel._({
    'field_name': specificField,
    'numeric_field': numericField,
    'list_field': listField,
    'map_field': mapField,
    'date_field': dateField,
  });
  factory DataModel.fromJson(final dynamic json) =>
      DataModel._(jsonDecodeMapAs(json));

  // Provide domain-specific getters using from_json_to_json functions
  String get specificField => jsonDecodeString(value['field_name']);
  int get numericField => jsonDecodeInt(value['numeric_field']);
  List<String> get listField => jsonDecodeListAs<String>(value['list_field']);
  Map<String, int> get mapField => jsonDecodeMapAs<String, int>(value['map_field']);
  DateTime? get dateField => dateTimeFromIso8601String(jsonDecodeString(value['date_field']));
  Duration get durationField => jsonDecodeDurationInSeconds(value['duration_seconds']);

  Map<String, dynamic> toJson() => value;

  static const empty = DataModel({});
}
```

### List-based Model Pattern

```dart
extension type const ItemsList(List<dynamic> value) {
  factory ItemsList.fromJson(final dynamic jsonData) {
    final list = jsonDecodeList(jsonData);
    return ItemsList(list);
  }

  // Type-safe getters
  List<String> get asStrings => jsonDecodeListAs<String>(value);
  List<int> get asInts => jsonDecodeListAs<int>(value);

  bool get isEmpty => value.isEmpty;
  bool get isNotEmpty => value.isNotEmpty;
  int get length => value.length;

  List<dynamic> toJson() => value;

  static const empty = ItemsList([]);
}
```

## Implementation Guidelines

### 1. **Naming Convention**

- Use descriptive names ending with `Id` for identifiers: `BookId`, `ActorId`, `VideoSeriesId`
- Use descriptive names ending with `Model` for complex data: `PricesOverridesModel`
- Use domain-specific names for specialized types: `SessionNumber`, `QuizResults`

### 2. **Required Methods**

- **`fromJson` factory**: Handle JSON deserialization using `from_json_to_json` functions
- **`toJson` method**: Return the underlying value for serialization
- **`empty`/`zero` static const**: Provide a default empty instance

### 3. **JSON Handling with from_json_to_json**

Use the appropriate decode functions from the package:

| Type     | Function                                    | Usage                                       |
| -------- | ------------------------------------------- | ------------------------------------------- |
| String   | `jsonDecodeString(value)`                   | Safe string conversion, empty if null       |
| int      | `jsonDecodeInt(value)`                      | Safe int conversion, 0 if invalid           |
| double   | `jsonDecodeDouble(value)`                   | Safe double conversion, 0.0 if invalid      |
| bool     | `jsonDecodeBool(value)`                     | Safe bool conversion, false if invalid      |
| List     | `jsonDecodeList(value)`                     | Safe list conversion, empty list if invalid |
| List<T>  | `jsonDecodeListAs<T>(value)`                | Type-safe list conversion                   |
| Map      | `jsonDecodeMap(value)`                      | Safe map conversion, empty map if invalid   |
| Map<K,V> | `jsonDecodeMapAs<K,V>(value)`               | Type-safe map conversion                    |
| DateTime | `dateTimeFromIso8601String(value)`          | ISO8601 string to DateTime                  |
| DateTime | `dateTimeFromMillisecondsSinceEpoch(value)` | Milliseconds to DateTime                    |
| Duration | `jsonDecodeDurationInSeconds(value)`        | Seconds to Duration                         |
| Duration | `jsonDecodeDurationInMinutes(value)`        | Minutes to Duration                         |

### 4. **Nullable Variants**

Avoid using nullable decode functions as much as possible.

For optional fields, use nullable these specific decode functions:

```dart
int? get optionalNumber => jsonDecodeNullableInt(value['optional_field']);
double? get optionalDecimal => jsonDecodeNullableDouble(value['optional_decimal']);
Map<String, dynamic>? get optionalMap => jsonDecodeNullableMap(value['optional_map']);
```

### 5. **Documentation Standards**

```dart
/// Extension type that represents a [specific concept].
///
/// [Detailed description of purpose]
///
/// Uses from_json_to_json for type-safe JSON handling.
///
/// Can be used to [list use cases].
///
/// Provides functionality to handle [list key features].
extension type const TypeName(UnderlyingType value) {
  // Implementation
}
```

### 6. **Error Handling**

The `from_json_to_json` package handles errors gracefully:

- Returns sensible defaults (empty string, 0, false, empty collections)
- Use `jsonDecodeThrowableMap` if you need exceptions on invalid input
- Use verification functions like `verifyListDecodability` and `verifyMapDecodability` for validation

### 7. **Private Constructor Pattern**

For internal-only construction, use private constructor:

```dart
extension type const InternalType._(UnderlyingType value) {
  factory InternalType.fromJson(final dynamic json) =>
    InternalType._(jsonDecodeString(json)); // or appropriate decode function
}
```

## Usage Examples

### Simple ID Type

```dart
extension type const ProductId(String value) {
  factory ProductId.fromJson(final dynamic value) => ProductId(jsonDecodeString(value));
  String toJson() => value;
  bool get isEmpty => value.isEmpty;
  static const empty = ProductId('');
}
```

### Complex Data Type

```dart
extension type const UserProfile(Map<String, dynamic> value) {
  factory UserProfile.fromJson(final dynamic json) {
    final map = jsonDecodeMap(json);
    return UserProfile(map);
  }

  String get name => jsonDecodeString(value['name']);
  int get age => jsonDecodeInt(value['age']);
  List<String> get hobbies => jsonDecodeListAs<String>(value['hobbies']);
  DateTime? get birthDate => dateTimeFromIso8601String(jsonDecodeString(value['birth_date']));

  Map<String, dynamic> toJson() => value;

  static const empty = UserProfile({});
}
```

### Numeric Model

```dart
extension type const Score(int value) {
  factory Score.fromJson(final dynamic json) => Score(jsonDecodeInt(json));

  int toJson() => value;

  bool get isZero => value == 0;
  bool get isPositive => value > 0;

  Score whenZeroUse(final Score other) => isZero ? other : this;

  static const zero = Score(0);
}
```

## Benefits

1. **Type Safety**: Prevents mixing different ID types at compile time
2. **Zero Runtime Cost**: No wrapper object created, direct access to underlying value
3. **Robust JSON Handling**: Never crashes on invalid input, graceful fallbacks
4. **API Clarity**: Makes function signatures more descriptive and self-documenting
5. **Consistent Behavior**: Predictable conversion behavior across all models
6. **Domain Modeling**: Expresses business concepts clearly in code

## When to Use

- **Identifiers**: Any string/int that represents a unique identifier
- **Value Objects**: Simple data containers that need type safety
- **API Boundaries**: When interfacing with external APIs that use primitive types
- **Domain Modeling**: When you need to distinguish between different concepts that share the same underlying type
- **JSON Models**: Any data structure that needs JSON serialization/deserialization

## When NOT to Use

- **Complex Business Logic**: Use regular classes for objects with significant behavior
- **Mutable State**: Extension types are immutable by design
- **Inheritance Hierarchies**: Use regular classes when you need inheritance
- **Runtime Type Checking**: Extension types don't create new runtime types
