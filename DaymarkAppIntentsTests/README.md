# App Intents system tests

These XCTest tests require Xcode 27 and an iOS 27 simulator or device. Run the `Daymark` scheme's `DaymarkAppIntentsTests` target; Xcode installs Daymark before `AppIntentsTesting` invokes its intents out of process.

The smoke test succeeds for both calendar-access and assistant-unavailable responses because those are valid intent results. Grant calendar access and use an Apple Intelligence-capable device to exercise the answered path manually.

`AppIntentsTesting` currently exposes whether the intent completed and any returned value, but not the rendered dialog or static snippet view. Verify their displayed content manually in Siri or Shortcuts. Deterministic response assertions remain in `DaymarkTests/Shared/Assistant/ScheduleAnswererTests.swift`.
