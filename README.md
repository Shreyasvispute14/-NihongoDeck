# ⛩️ NihongoDeck

**NihongoDeck** is a feature-rich, offline-first Japanese vocabulary and kanji learning mobile application built with Flutter. It combines lightning-fast local performance via SQLite with automated background cloud synchronization, interactive home screen widgets, and a Spaced Repetition System (SRS).

---

## ✨ Key Features

*   **⚡ Offline-First Architecture:** Powered by local SQLite storage to guarantee instant flashcard loading, smooth drawing performance, and full usability without an internet connection.
*   **☁️ Automated Cloud Sync & Backup:** Seamlessly backs up custom decks and review progress to Firebase Firestore in the background whenever the app is minimized or closed. Restores data automatically on startup.
*   **🧠 Spaced Repetition System (SRS):** Built-in algorithmic scheduling to optimize long-term memory retention for kanji and vocabulary.
*   **✍️ Kanji Drawing & Practice:** Interactive canvas support for practicing stroke orders and character formations.
*   **📱 Home Screen Widgets:** Dynamic home screen widgets that automatically rotate vocabulary words to keep learning effortless throughout your day.

---

## 🛠️ Tech Stack & Architecture

*   **Frontend Framework:** [Flutter](https://flutter.dev/) (Dart)
*   **Local Database:** SQLite (`sqflite`) for high-performance local reads/writes
*   **Cloud Backend:** Firebase Auth (Anonymous Secure Sessions) & Cloud Firestore
*   **Platform Integrations:** `home_widget` for interactive native home screen widgets, `flutter_tts` for text-to-speech pronunciation.

---

## 🚀 Getting Started

Follow these instructions to get a local copy up and running on your machine for development and testing purposes.

### Prerequisites
*   Make sure you have the [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
*   An active Android emulator or a physical Android device.

### Installation

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/your-username/nihongodeck.git](https://github.com/your-username/nihongodeck.git)
   cd nihongodeck
