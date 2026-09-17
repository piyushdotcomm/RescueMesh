<!-- prettier-ignore -->
<div align="center">

# RescueMesh

**Decentralized Offline Disaster Response Network Powered by On-Device Gemma 4 AI**

[![Flutter](https://img.shields.io/badge/Flutter-3.6+-02569B.svg?style=flat-square&logo=flutter)](https://flutter.dev)
[![Gemma 4](https://img.shields.io/badge/Model-Gemma%204%20E2B%20%2F%20E4B-4285F4.svg?style=flat-square&logo=google)](https://huggingface.co/litert-community)
[![LiteRT-LM](https://img.shields.io/badge/Runtime-LiteRT--LM-FF6F00.svg?style=flat-square)](https://ai.google.dev/edge/litert)
[![ObjectBox](https://img.shields.io/badge/Vector_DB-ObjectBox_HNSW-27ae60.svg?style=flat-square)](https://objectbox.io/)
[![Connectivity](https://img.shields.io/badge/Connectivity-100%25_Offline-success.svg?style=flat-square)]()
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg?style=flat-square)](LICENSE)

<br />

[Overview](#overview) • [Key Features](#key-features) • [Application Preview](#application-preview) • [Architecture](#architecture) • [Emergency Knowledge Base](#emergency-knowledge-base) • [Tech Stack](#tech-stack) • [Getting Started](#getting-started)

<br />

<table align="center">
  <tr>
    <td align="center" width="25%"><b>Emergency AI Chat</b></td>
    <td align="center" width="25%"><b>P2P Mesh Network</b></td>
    <td align="center" width="25%"><b>56 Knowledge Packs</b></td>
    <td align="center" width="25%"><b>On-Device Models</b></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/Screenshot_20260730-222731.png" alt="Emergency AI Chat" width="100%" /></td>
    <td><img src="docs/screenshots/Screenshot_20260730-222723.png" alt="P2P Mesh Network" width="100%" /></td>
    <td><img src="docs/screenshots/Screenshot_20260730-222736.png" alt="Knowledge Library" width="100%" /></td>
    <td><img src="docs/screenshots/Screenshot_20260730-222741.png" alt="Model Manager" width="100%" /></td>
  </tr>
</table>

</div>

---

## Overview

When major natural disasters, severe grid failures, or extreme emergencies strike, traditional communications infrastructure collapses: cell towers lose power, fiber backhauls sever, and internet access goes dark. In these critical hours, ordinary smartphones become disconnected from emergency services and medical knowledge.

**RescueMesh** transforms consumer smartphones into autonomous, resilient, and interconnected emergency response nodes. By uniting **Google's Gemma 4 on-device multimodal models**, **sub-second embedded vector retrieval (RAG)**, and a **self-healing peer-to-peer ad-hoc mesh network**, RescueMesh provides verified medical guidance, multimodal triage, emergency beaconing, and decentralized field coordination.

> [!TIP]
> **Zero Cloud Dependency**: RescueMesh functions entirely in **Airplane Mode**. It requires no external servers, no cloud APIs, and no SIM card connectivity once installed.

---

## Key Features

### On-Device Gemma 4 AI & Adaptive RAG
- **Quantized Edge Inference**: Executes Gemma 4 (E2B and E4B variants) directly on device hardware via Google AI Edge's **LiteRT-LM** engine with GPU acceleration and speculative decoding.
- **Embedded Vector Search**: Leverages an on-device **MiniLM-L6-v2** embedding model (384-dimensional space via ONNX Runtime) coupled with **ObjectBox HNSW** vector index for instant semantic retrieval.
- **Two-Pass Grounded Synthesis**: Dynamically retrieves matching segments from 56 verified emergency packs, injects verified guidance into the context window, and displays clickable citation badges that deep-link into the full source protocols.

### Ad-Hoc Peer-to-Peer Mesh Network
- **Zero-Infrastructure Discovery**: Communicates over local UDP subnet broadcast and direct Wi-Fi/mesh channels, creating a local decentralized network spanning 100+ meters per node.
- **Ghost Protocol**: Automatically logs and caches peer beacons. If a connected survivor or responder device drops offline or goes silent, its last-known triage status, battery state, and coordinates remain preserved and visible to peers across the mesh.
- **Gossip Relay & Deduplication**: Multi-hop packet propagation ensures critical alerts reach beyond line-of-sight while preventing duplicate broadcasts and memory bloat.

### Multimodal Triage & Live Voice
- **Vision-Enabled Assessment**: Captures and analyzes injury photos, hazardous condition signs, or medication packaging locally through Gemma 4's native multimodal vision encoder.
- **Hands-Free Live Voice Mode**: Integrates on-device Speech-to-Text (ASR) and streaming Text-to-Speech (TTS) with an animated state orb, enabling hands-free operation for responders attending to casualties.

### Tactical Mapping & Emergency Signaling
- **Offline Situational Awareness**: Displays local mesh nodes, their assigned roles (Survivor, First Responder, Medic), and triage levels (Safe, Need Help, Critical) on an offline map.
- **Hardware Optical SOS**: Features a millisecond-accurate optical Morse code flasher using the device's camera LED torch (`... --- ...`) to signal search teams at night or across line-of-sight distances.

---

## Application Preview

| Module | Capability |
|---|---|
| **Emergency AI Assistant** | Grounded question-answering with one-tap situational starters (*Cuts & Bleeding*, *Build Fire in Rain*, *Water Purification*, *Hypothermia Signs*). |
| **Mesh Operations Dashboard** | Real-time active node count, community triage overview (Safe / Need Help / Critical), one-touch SOS beacon broadcast, and Ghost Protocol activity log. |
| **Emergency Knowledge Library** | 56 pre-indexed, searchable offline knowledge packs with step-by-step triage actions, precautions, and equipment checklists. |
| **Model Engine Manager** | Download, configure, and swap on-device model weights locally between Gemma 4 E2B (high-speed balanced) and E4B (deep reasoning). |

---

## Architecture

RescueMesh is built with a modular, layered architecture that isolates hardware communication, local machine learning runtimes, and application state.

<div align="center">
  <img src="docs/architecture.png" alt="RescueMesh System Architecture" width="850px" />
</div>

### Subsystems Breakdown

1. **User Interface & Interaction**: Built with Flutter, utilizing reactive state management for real-time mesh updates, chat message streaming, audio waveform visualizers, and interactive Markdown citations.
2. **On-Device Inference Pipeline (`GemmaInferenceService`)**: Manages model lifecycle, KV-cache projection, EOS token buffering, prompt formatting, and multi-turn context replay.
3. **Semantic Retrieval Engine**: Employs WordPiece tokenization and MiniLM-L6-v2 ONNX embeddings against an on-device ObjectBox vector database using HNSW cosine distance indexing.
4. **Mesh Networking Engine (`MeshService`)**: Manages UDP broadcast sockets, peer heartbeats, SOS payload serialization, relay pruning, and persistent device identification.
5. **Hardware Abstraction Layer**: Interfaces directly with device camera, audio microphone streams, speech synthesizers, torch flashlight channels, and GPS sensors.

---

## Emergency Knowledge Base

RescueMesh bundles **56 curated emergency knowledge packs** pre-processed into propositional chunks and indexed for immediate RAG retrieval. Sourced from public safety protocols published by the **American Red Cross**, **CDC**, **NOLS Wilderness Medicine**, and **DOT Emergency Response Guides**:

```
assets/rag/packs/
├── Trauma & First Aid         # Bleeding, CPR, Burns, Choking, Shock, Head & Eye Injuries, Gunshot Wounds
├── Natural Disasters          # Earthquakes, Floods, Wildfires, Hurricanes, Tornadoes, Tsunamis, Avalanches
├── Environmental Survival     # Extreme Cold, Extreme Heat, Water Purification, Food Poisoning, Power Outage
├── CBRN & Industrial Hazards  # Hazardous Materials Release, Gas Leaks, Radiation/Nuclear Hazards, Pipeline Leaks
└── Community Crisis           # Building Collapse, Civil Unrest, Crowd Crushes, Search & Rescue Procedures
```

---

## Tech Stack

| Layer | Component | Implementation |
|---|---|---|
| **Application UI** | Flutter 3.6+ / Dart | Cross-platform Material 3 responsive interface |
| **On-Device LLM** | Gemma 4 (E2B / E4B) | LiteRT-LM (Google AI Edge) runtime with GPU acceleration |
| **Vector Database** | ObjectBox 5.3+ | Embedded on-device HNSW vector index (cosine distance) |
| **Embedding Model** | all-MiniLM-L6-v2 | 384-dimensional ONNX runtime with custom BERT tokenizer |
| **P2P Mesh** | UDP Broadcast & Gossip | Ad-hoc subnet discovery, persistent device ID, Ghost Protocol |
| **Voice & Speech** | Native ASR & TTS | Cross-platform speech-to-text and streaming speech synthesis |
| **Offline Mapping** | flutter_map & latlong2 | Offline-cached OpenStreetMap tile rendering & peer markers |
| **Hardware Control** | Camera, GPS & Flashlight | Low-level method channels for camera vision & timed Morse strobe |

---

## Getting Started

### Prerequisites

- **Flutter SDK**: `>= 3.6.0` ([Install Flutter](https://docs.flutter.dev/get-started/install))
- **Android**: Android Studio with SDK API 26+ (Android 8.0 or newer)
- **iOS**: macOS with Xcode 15+ and CocoaPods (iOS 17+ recommended for on-device Gemma inference)
- **Hardware**: Modern device with at least 4 GB RAM (6 GB+ recommended for Gemma 4 E2B/E4B inference)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/piyushdotcomm/RescueMesh.git
   cd RescueMesh
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Verify code analysis:**
   ```bash
   flutter analyze
   ```

4. **Run on a connected device:**
   ```bash
   flutter run --release
   ```

> [!IMPORTANT]
> **Release Mode Required:** Always run the application with `--release`. Debug mode disables compiler optimizations and LiteRT-LM GPU delegate acceleration, making on-device model inference too slow for interactive conversation and speech streaming.

### First-Time Model Setup

On the first launch of RescueMesh:
1. Ensure your device is connected to Wi-Fi to download the quantized Gemma model weights.
2. Navigate to the **Models** tab.
3. Select **Gemma 4 E2B** (~1.4 GB, recommended for standard devices) or **Gemma 4 E4B** (~3.7 GB, recommended for high-RAM devices).
4. Once the download completes, you can turn off Wi-Fi, enable **Airplane Mode**, and operate entirely offline.
