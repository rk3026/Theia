# Vosk Model Assets

Place a zipped Vosk acoustic model in this directory so the `ModelLoader`
utility can unpack it at runtime. The demo plan assumes the small English
model:

```
assets/models/vosk-model-small-en-us-0.15.zip
```

Download it from https://alphacephei.com/vosk/models and keep the filename
unchanged so the `VoiceService` can locate it. Large models work as well, but
expect increased download size and startup time.
