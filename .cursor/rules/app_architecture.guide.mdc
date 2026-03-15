---
description:
globs:
alwaysApply: true
---

# Application Architecture Overview

This document provides a condensed, unified overview of the application's architecture. It is designed to be a primary reference for understanding the core concepts, structure, and development patterns.

## 1. High-Level Architecture & Directory Structure

The application follows a standard layered architecture, separating concerns into distinct layers and directories.

```
lib/
  ├── core/                # Core abstractions & shared utilities
  ├── components/          # Shared UI components in atom design style. See
  ├── data_models/         # Immutable data models based on extension types. See `[dart_extension_type_const_models.mdc](mdc:.cursor/rules/dart_extension_type_const_models.mdc)` for more details.
  ├── data_resources/      # UI state holders (Resources) See `[command_resource_pattern.guide.mdc](mdc:.cursor/rules/command_resource_pattern.guide.mdc)` for more details.
  ├── data_commands/       # Logic to update Resources (Commands) See `[command_resource_pattern.guide.mdc](mdc:.cursor/rules/command_resource_pattern.guide.mdc)` for more details.
  ├── data_api/            # Data access layer (file I/O, parsing)
  ├── data_services/       # Data services (file I/O, parsing)
  ├── mechanics/           # Mechanics (game mechanics)
  ├── di/                  # Dependency injection setup See `[di_usage.guide.mdc](mdc:.cursor/rules/di_usage.guide.mdc)` for more details.
  ├── services/            # Isolated Application-level business logic
  ├── {ui_domain}/         # Domain or Feature-specific screens and widgets, like ui_vitamin_selection, ui_info etc..
  ├── theme/               # Context based Theme
  └── main.dart            # Application entry point
```

- **Data Layer:** `data_models/` & `data_api/` handle the representation of and interaction with the data.
- **State & Service Layer:** `data_resources/` & `data_commands/` & `data_services/` manage application state and orchestrate business logic.
- **UI Layer:** `{ui_domain}/` contains all Flutter widgets, organized by domain and then by feature.

## 2. The Data Layer: Workspace File Structure

A Workspace is composed of several key file types, each serving a distinct purpose. All file contents are parsed into immutable **`extension type`** models located in `lib/data_models/`.
See `[dart_extension_type_const_models.guide.mdc](mdc:.cursor/rules/dart_extension_type_const_models.guide.mdc)` for more details.

## 3. Data Service Layer

Services in `lib/services/` contain isolated, high-level data related business logic that orchestrates data flow and complex operations. They provide reusable **capabilities** (e.g., file writing, data parsing) and are consumed by Commands to perform actions.

They can be used by commands, mechanics.

## 4. Mechanics Layer: Game Mechanics

Mechanics in `lib/mechanics/` contain the game mechanics, they can be consumed by commands, and may modify resources.

Should contain isolated game logic.

## 5. UI & State Management: The Command-Resource Pattern

The application uses the **Command-Resource pattern** for a clear separation between UI state and business logic. Commands are triggered by the UI to execute atomic **transactions** (e.g., "save this character"), using Services to perform the work and updating Resources with the result.

See `[command_resource_pattern.guide.mdc](mdc:.cursor/rules/command_resource_pattern.guide.mdc)` for more details.

## 6. Dependency Injection (DI)

The application uses the `get_it` package for service location. The setup is centralized in `lib/di/dependency_injector.dart`. See `[di_usage.guide.mdc](mdc:.cursor/rules/di_usage.guide.mdc)` for more details.

See `[di_creation.guide.mdc](mdc:.cursor/rules/di_creation.guide.mdc)` for more details.

For how to use DI, see more in `[di_usage.guide.mdc](mdc:.cursor/rules/di_usage.guide.mdc)`

For how to create DI, see more in `[di_creation.guide.mdc](mdc:.cursor/rules/di_creation.guide.mdc)`

## 7. Localization

The application supports dynamic, user-switchable localization for multiple languages. This is achieved by centralizing all user-facing strings and using a reactive architecture to update the UI when the language changes.

Use `useLocale()` and `AppStrings.{key}.getValue(locale)` to get the current locale and strings.

For how to use localization, see more in `[locale_usage.guide.mdc](mdc:.cursor/rules/locale_usage.guide.mdc)`
