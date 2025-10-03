Here is a more detailed and extensive `README.md` for your project, with enhanced formatting and additional sections based on the new files you provided.

-----

# Time Tracker

A comprehensive, cross-platform time tracking application built with Flutter. Manage clients, projects, and tasks, track your time, handle expenses, and generate professional invoices with ease.

-----

## 📖 About The Project

This project is a robust time tracking and invoicing solution designed for freelancers, consultants, and small teams. It provides an all-in-one platform to manage your work, track every billable minute, record project-related expenses, and generate professional PDF invoices.

### ✨ Features

  * **Client & Project Management:** Create and manage clients and projects, setting hourly rates and monthly time limits.
  * **Real-time & Manual Time Tracking:** Track your time with a live timer or add manual time entries for past work.
  * **Task Management (To-Do List):** Create and manage a to-do list with priorities, deadlines, and project associations.
  * **Expense Tracking:** Record project-related expenses, including mileage with automatic cost calculation.
  * **Invoice Generation:** Generate professional PDF invoices from your time entries and expenses.
  * **Reporting & Analytics:** Visualize your tracked time and revenue with detailed reports and charts.
  * **Company Settings:** Customize your company details, logo, and invoice letterhead for a professional touch.
  * **Cross-Platform:** A single codebase that runs on Android, iOS, Windows, macOS, and Linux.

-----

## 🛠️ Built With

This project is built with a modern and robust tech stack:

  * [**Flutter**](https://flutter.dev/) - The UI toolkit for building natively compiled applications for mobile, web, and desktop from a single codebase.
  * [**Drift (formerly Moor)**](https://drift.simonbinder.eu/) - A reactive persistence library for Flutter and Dart, built on top of SQLite.
  * [**Provider**](https://pub.dev/packages/provider) - A wrapper around `InheritedWidget` to make it easier to use and more reusable.
  * [**PDF**](https://pub.dev/packages/pdf) & [**Printing**](https://pub.dev/packages/printing) - For creating and displaying PDF invoices.
  * [**file\_picker**](https://pub.dev/packages/file_picker) - To allow users to pick a company logo.
  * [**fl\_chart**](https://pub.dev/packages/fl_chart) - A library to draw fantastic charts in Flutter.

-----

## 🚀 Getting Started

To get a local copy up and running, follow these simple steps.

### Prerequisites

  * **Flutter SDK:** Make sure you have the Flutter SDK installed. For instructions, see the [**official Flutter documentation**](https://flutter.dev/docs/get-started/install).
  * **An IDE:** Such as Android Studio or VS Code with the Flutter and Dart plugins.

### Installation

1.  **Clone the repo**
    ```sh
    git clone https://github.com/NicolasLobosDEV/time_tracker.git
    ```
2.  **Navigate to the project directory**
    ```sh
    cd time_tracker
    ```
3.  **Install dependencies**
    ```sh
    flutter pub get
    ```
4.  **Run the code generator**
    ```sh
    dart run build_runner build
    ```
5.  **Run the app**
    ```sh
    flutter run
    ```

-----

## 📱 Screens

The application is organized into several main screens, each handling a specific functionality:

  * **Home Screen (`home_screen.dart`):** Displays the main to-do list, allowing you to track tasks and start timers.
  * **Time Tracker Screen (`time_tracker_screen.dart`):** Shows the active timer and a list of recent time entries.
  * **Clients Screen (`clients_screen.dart`):** A list of all your clients, with options to add, edit, or delete them.
  * **Projects Screen (`projects_screen.dart`):** A list of your projects, grouped by client, with hourly rates and time limits.
  * **Expenses Screen (`expenses_screen.dart`):** A list of all recorded expenses, with options to add, edit, or delete.
  * **Invoices Screen (`invoices_screen.dart`):** A list of all generated invoices, with options to create new ones.
  * **Reports Screen (`reports_screen.dart`):** Visual reports and charts to analyze your time and revenue.
  * **Settings Screen (`settings_screen.dart`):** A dedicated screen to manage your company's information and app settings.

-----

## 🗃️ Database Schema

The application uses a local SQLite database managed by the **Drift** library. The schema is defined in `lib/database/database.dart` and consists of the following tables:

  * **Clients:** Stores client information, including name, address, email, and currency.
  * **Projects:** Manages projects, each linked to a client, with details like name, hourly rate, and time limits.
  * **TimeEntries:** Records individual time entries with descriptions, project associations, start/end times, and billable status.
  * **Expenses:** Keeps track of project-related expenses, including a description, amount, date, and associated project or client.
  * **Invoices:** Stores generated invoices with details like invoice ID, client, issue/due dates, total amount, and line items.
  * **Todos:** A to-do list to manage tasks, with priorities, deadlines, and project links.
  * **CompanySettings:** A singleton table to store company-wide settings like name, address, logo, and invoice preferences.

-----

## 📦 Dependencies

This project relies on a set of powerful packages from the Dart and Flutter ecosystem to deliver its features. Here are the key dependencies as defined in the `pubspec.yaml` file:

### Main Dependencies

  * **`flutter`**: The core Flutter framework.
  * **`drift`**: A reactive persistence library for Flutter and Dart.
  * **`sqlite3_flutter_libs`**: Bundles a version of `sqlite3` for Flutter apps.
  * **`path_provider`**: For finding commonly used locations on the filesystem.
  * **`path`**: A comprehensive library for path manipulation.
  * **`provider`**: For state management.
  * **`pdf`**: A library to create and print PDF documents.
  * **`printing`**: A plugin that allows you to print PDF documents.
  * **`open_file`**: A plugin for calling the native platform's file opener.
  * **`fl_chart`**: For creating beautiful charts.
  * **`intl`**: Provides internationalization and localization facilities, including date and number formatting.
  * **`file_picker`**: A package that allows you to use the native file explorer to pick files.
  * **`uuid`**: For generating unique IDs.
  * **`cupertino_icons`**: Provides the Cupertino (iOS-style) icons.

### Development Dependencies

  * **`flutter_test`**: For testing Flutter widgets.
  * **`drift_dev`**: The code generator for the Drift persistence library.
  * **`build_runner`**: A build package for Dart code generation.
  * **`flutter_lints`**: A set of recommended lints to encourage good coding practices.

-----

## 🤝 Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".

1.  **Fork the Project**
2.  **Create your Feature Branch** (`git checkout -b feature/AmazingFeature`)
3.  **Commit your Changes** (`git commit -m 'Add some AmazingFeature'`)
4.  **Push to the Branch** (`git push origin feature/AmazingFeature`)
5.  **Open a Pull Request**

-----

## 📝 License

Distributed under the MIT License. See `LICENSE` for more information.

-----

## 📬 Contact

Nicolas Lobos - [nicolasrlobos@gmail.com](mailto:nicolasrlobos@gmail.com)

Buy me a Coffee (if you would like to!)☕: [buymeacoffee.com/nicolasrlobos](buymeacoffee.com/nicolasrlobos)

Project Link: [https://github.com/NicolasLobosDEV/time\_tracker](https://github.com/NicolasLobosDEV/time_tracker)
