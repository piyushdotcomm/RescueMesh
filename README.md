# RescueMesh

**Offline disaster response mesh network.** Gemma 4 runs fully on-device — text, image, and voice — and phones form a self-healing P2P mesh when cell towers go down. Built for the **BUILD WITH GEMMA AI Buildathon 2026**.

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Gemma 4](https://img.shields.io/badge/Model-Gemma%204%20E2B%20%2F%20E4B-4285F4.svg)](https://huggingface.co/litert-community)
[![Flutter](https://img.shields.io/badge/Flutter-3.6+-02569B.svg?logo=flutter)](https://flutter.dev)

## Problem

When disaster strikes, three things fail simultaneously: cell towers, power grid, and communication. People are isolated. Emergency services work blind. Smartphones become useless bricks.

## Solution

RescueMesh turns every phone into an offline AI survival node. Gemma 4 provides emergency medical guidance, P2P mesh networking enables device-to-device communication without internet, and an on-device RAG knowledge base of 56 emergency packs covers everything from CPR to nuclear fallout.

## Features

- **Offline Survival AI** — 56 emergency knowledge packs with cited answers via Gemma 4 RAG
- **P2P Emergency Mesh** — WiFi Direct device discovery, SOS beacons with GPS, status sharing
- **Multimodal Input** — text, voice, and camera (injury assessment, medication label scanning)
- **Live Voice Mode** — hands-free speech-to-text and text-to-speech with on-device AI
- **Community Dashboard** — mesh map with device status, resource coordination, role assignment
- **100% On-Device** — no API keys, no cloud, no data leaving your device. Airplane-mode safe.

## Hackathon Tracks

**Intelligence with Purpose** — disaster response, healthcare, accessibility
**AI off the Grid** — fully on-device Gemma 4 + offline mesh networking

## Tech Stack

| Layer | Technology |
|-------|-----------|
| AI Engine | Gemma 4 E2B/E4B via LiteRT-LM |
| App Framework | Flutter |
| RAG | ObjectBox HNSW + Embedding models |
| Mesh | WiFi Direct / Nearby Connections |
| Speech | On-device ASR + TTS |
| Vision | Gemma 4 multimodal image processing |

## Build & Run

```bash
git clone https://github.com/piyushdotcomm/RescueMesh.git
cd RescueMesh
flutter pub get
flutter run
```

## Architecture

Gemma 4 E2B/E4B runs via LiteRT-LM (Google AI Edge's mobile runtime) with GPU acceleration. RAG uses ObjectBox HNSW vector search over 56 pre-embedded emergency knowledge packs. The UI is built with Flutter.

## Credits

- **Gemma 4** — Google DeepMind
- **LiteRT-LM** — Google AI Edge team
- **flutter_gemma** — community Flutter wrapper
- **ObjectBox** — embedded vector database
- Knowledge content from American Red Cross, CDC, NOLS, and DOT public guides

## Attribution

This project uses Google's Gemma 4 models for inference. **Gemma is a trademark of Google LLC.** Gemma 4 is released under the [Gemma Terms of Use](https://ai.google.dev/gemma/terms).

## License

Apache License 2.0. Built for BUILD WITH GEMMA AI Buildathon 2026.
