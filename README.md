<div align="center">

# 🧠 NeuroCalm AI
**Your Private, Offline-First Cognitive Behavioral Companion**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Riverpod](https://img.shields.io/badge/Riverpod-State_Management-000000?style=for-the-badge&logo=dart&logoColor=white)](https://riverpod.dev)
[![SQLite](https://img.shields.io/badge/SQLite-Offline_First-003B57?style=for-the-badge&logo=sqlite&logoColor=white)](https://sqlite.org/)
[![RevenueCat](https://img.shields.io/badge/RevenueCat-Monetization-F55F44?style=for-the-badge&logo=revenuecat&logoColor=white)](https://www.revenuecat.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

> A cutting-edge mental wellness application that fuses on-device Small Language Models (SLM), biometric health correlations, and Nir Eyal's "Hooked" behavioral model to deliver instant, privacy-secured therapeutic insights.

**Tags:** `flutter`, `mental-health`, `ai`, `cbt`, `offline-first`, `riverpod`, `sqlite`, `revenuecat`, `biometric-tracking`, `habit-building`

</div>

<br>

## 📑 Table of Contents
- [Philosophy & The "Defensible Moat"](#-philosophy--the-defensible-moat)
- [Core Features](#-core-features)
- [Architecture & Tech Stack](#-architecture--tech-stack)
- [Security & Legal Compliance](#-security--legal-compliance)
- [Installation & Setup](#-installation--setup)
- [Project Structure](#-project-structure)

<br>

## 🛡 Philosophy & The "Defensible Moat"
Unlike standard API-wrapper AI apps, NeuroCalm AI is built on a strict **Offline-First Architecture**. 
We protect user privacy by ensuring sensitive emotional journals and biometric data never leave the device without explicit, anonymized consent. Our defensible moat lies in our **Biometric Correlation Engine**, which mathematically translates physical exhaustion (via Apple Health/Google Fit) into a localized Cognitive Behavioral context before the AI generates an insight.

<br>

## ✨ Core Features

### 🧩 1. The "Hooked" Habit Loop
- **Somatic Triggers:** Evaluates sleep and step deviations to trigger bio-empathic local push notifications.
- **Frictionless Action:** Multi-modal journaling (Text, Voice, Facial Scan).
- **Variable Reward:** Interactive 3D card-flipping mechanics revealing CBT reframes.
- **Synaptic Investment:** Users rate insights, training a local SQLite vector weight matrix to personalize future AI responses.

### 🧬 2. Biometric Correlation Engine
- Integrates with **Apple Health** & **Google Fit** via the `health` package.
- Calculates a rolling 7-day physical baseline (O(1) localized caching).
- Generates a legally compliant `SomaticStressIndex` to contextualize emotional reactivity.

### 🔀 3. Hybrid AI Routing 
- **Free Tier:** Routes securely to an On-Device Small Language Model (SLM) for $0 compute cost.
- **Premium Tier:** Routes to Cloud LLMs (Gemini/OpenAI) using strict, prompt-injected JSON delimiters to prevent hallucination, token bloat, and prompt-injection attacks.
- **Semantic Caching:** Hashes journal strings (MD5) to serve instant `SharedPreferences` cache hits.

### 💸 4. Enterprise Monetization & Growth
- **RevenueCat Integration:** Dynamic localized pricing with Firebase Authentication cross-device syncing.
- **Failsafe AdMob Fallback:** If premium bypass fails or ad-blockers are detected, gracefully degrades to a premium upsell dialog.
- **Viral Growth Engine:** Generates unique referral shortcodes. Uses SHA-256 immutable hardware fingerprinting and atomic Firebase Transactions to issue instant premium credits while strictly preventing self-referral fraud.

<br>

## 🏗 Architecture & Tech Stack

The application strictly adheres to the **Single Responsibility Principle** and unidirectional data flow using Riverpod.

* **Frontend Framework:** Flutter (Dart)
* **State Management:** Riverpod (`AsyncNotifier`, `Provider`, `ConsumerWidget`)
* **Local Database:** SQLite (`sqflite`) for immutable history & AI bias matrices.
* **Key-Value Store:** `shared_preferences` for O(1) semantic caching and offline credit balances.
* **Authentication:** Firebase Auth
* **Remote Database (Referrals):** Cloud Firestore
* **Monetization:** RevenueCat (`purchases_flutter`), Google AdMob
* **Hardware/Sensors:** `health`, `device_info_plus`, `share_plus`
* **Animations:** Flutter native implicit animations, `TweenAnimationBuilder`, `TickerProviderStateMixin`.

<br>

## ⚖️ Security & Legal Compliance

NeuroCalm AI is engineered to avoid strict classification as a *Software as a Medical Device (SaMD)*, protecting developers and stakeholders from heavy FDA/CE regulatory liabilities:
* **Cryptographic Consent Ledger:** Logs the exact UTC timestamp, policy version (`v1.0.0`), and SHA-256 hardware hash of the user's explicit consent to our "General Wellness" terms.
* **Data Wiping:** Full GDPR "Right to be Forgotten" implementation via the `UserProfileScreen` that permanently drops local SQLite tables and cached matrices.
* **Prompt Firewalls:** Hardcoded system prompts explicitly forbid the cloud LLM from outputting medical diagnoses (e.g., outputs "Somatic Overload" instead of "Clinical Depression").

<br>

## 🚀 Installation & Setup

### Prerequisites
* Flutter SDK (3.19.0 or higher)
* CocoaPods (for iOS)
* A `.env` file for your API keys.

### 1. Clone & Install
```bash
git clone [https://github.com/your-org/neurocalm-ai.git](https://github.com/your-org/neurocalm-ai.git)
cd neurocalm-ai
flutter pub get
