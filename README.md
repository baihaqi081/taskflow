# TaskFlow — Daily Task Manager

TaskFlow is a Flutter-based daily task management application developed for the Multiplatform Programming course.

## Features

- **Task Management:** Add, edit, and delete tasks.
- **Task Completion:** Mark tasks as completed or active.
- **Task Filtering:** Filter tasks based on their status.
- **Dashboard:** View task information in one place.
- **User Settings:** Change the user name and application theme.
- **Local Data Storage:** Store task data using SQLite.
- **Preference Storage:** Save user settings using Shared Preferences.
- **JSON Export:** Export task data as a JSON file.
- **Asynchronous Programming:** Use `Future`, `async`, and `await` for asynchronous operations.

## Technologies and Packages

- Flutter
- Dart
- SQLite through `sqflite`
- `sqflite_common_ffi_web` for SQLite support in the web environment
- `shared_preferences`
- `path`
- `path_provider`

## Requirements

Install Flutter and Dart, and make sure Flutter is available in your terminal.

## How to Run

Clone this repository:

```bash
git clone YOUR_GITHUB_REPOSITORY_URL
cd taskflow
```

Install dependencies:

```bash
flutter pub get
```

Prepare SQLite support for the web:

```bash
dart run sqflite_common_ffi_web:setup
```

Run the application in Chrome:

```bash
flutter run -d chrome
```

## Data Storage

TaskFlow uses SQLite to manage task records and Shared Preferences to store user settings, including the user name and theme preference.

The JSON export feature allows users to export task data for use outside the application.

## Testing

The following features have been manually tested:

- Add a task
- Edit an existing task
- Delete a task
- Mark tasks as completed and filter tasks
- Change the user name and theme
- Export task data to JSON
- Verify that task data remains available after refreshing Chrome

## Academic Purpose

This application was developed as a course assignment for Multiplatform Programming.

