# Yapster

A Flutter application built with GetX architecture.

## Project Structure

This project follows a modular architecture using GetX for state management, dependency injection, and routing.

```
lib/
├── app/
│   ├── core/
│   │   ├── theme/       # Theme configuration
│   │   ├── utils/       # Utility functions
│   │   └── values/      # Constants (colors, fonts, etc.)
│   ├── data/
│   │   ├── models/      # Data models
│   │   └── providers/   # API and data providers
│   ├── global_widgets/  # Reusable widgets
│   ├── modules/         # Feature modules
│   │   └── home/        # Home module
│   │       ├── bindings/
│   │       ├── controllers/
│   │       └── views/
│   └── routes/          # App routes
└── main.dart            # Entry point
```

## Features

- **GetX State Management**: Reactive state management with Obx and GetX controllers
- **Dependency Injection**: Efficient dependency management with GetX bindings
- **Routing**: Named routes with GetX navigation
- **Theme Support**: Light and dark theme with easy switching
- **Modular Architecture**: Organized code structure for scalability

## Getting Started

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Run `flutter run` to start the application

## Dependencies

- get: ^4.6.6 - GetX package for state management, routing, and dependency injection
- shared_preferences: ^2.2.2 - For local storage
- http: ^1.1.0 - For API calls
- cached_network_image: ^3.3.0 - For image caching
- flutter_svg: ^2.0.7 - For SVG support
- intl: ^0.18.1 - For internationalization
