# Flutter Gemma - LiteRT-LM
-keep class com.google.ai.edge.litert.** { *; }
-dontwarn com.google.ai.edge.litert.**

# MediaPipe (if used for embeddings)
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# Protocol Buffers
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# ObjectBox
-keep class io.objectbox.** { *; }
-dontwarn io.objectbox.**

# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
