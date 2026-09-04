# Research: App Schemas for calendar availability in iOS 26.5

## Summary

**Apple now documents a `.calendar` App Schema domain, but it isn't present in the installed iOS 26.5 SDK interface.** The documented domain currently exposes `createEvent`, `deleteEvent`, and `updateEvent`, plus calendar, event, and attendee entity schemas. None computes free/busy or availability, so no documented calendar action is a semantically valid annotation for Daymark’s read-only question “When am I free?” Daymark should keep that capability as an ordinary custom `AppIntent` unless Apple adds a read/search/availability action.

## Method and authority

The primary availability check was the installed public Swift interface:

`/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk/System/Library/Frameworks/AppIntents.framework/Modules/AppIntents.swiftmodule/arm64e-apple-ios.swiftinterface`

Its header identifies target `arm64e-apple-ios26.5`, AppIntents framework version `300.5.12`, and Swift `6.3.2` (lines 1–4). The inventory below was mechanically defined by the interface’s `AssistantSchemas.Intent` domain accessors and each corresponding `<Domain>Intent` action extension (principally lines 5,000–7,523, plus `assistant` around lines 9,717–9,758). The framework declares the schema model (`Intent`, `Entity`, and `Enum`) near lines 45–68.

Apple’s public material confirms the intended adoption mechanism: an Assistant intent is adopted through the schema macro, for example `@AppIntent(schema: .journal.updateEntry)`, rather than by merely using a similarly named value type. [AssistantIntent](https://developer.apple.com/documentation/appintents/assistantintent) · [Journal `updateEntry`](https://developer.apple.com/documentation/appintents/assistantschemas/journalintent/updateentry) · [WWDC26: Build intelligent Siri experiences with App Schemas](https://developer.apple.com/videos/play/wwdc2026/240/)

## Complete installed intent-domain/action inventory

The names below are the exact Swift schema accessor names in the iOS 26.5 interface. Parentheses give the number of actions.

1. **`journal` (5):** `createEntry`, `createAudioEntry`, `search`, `updateEntry`, `deleteEntry`.
2. **`photos` (27):** `createAlbum`, `openAlbum`, `updateAlbum`, `deleteAlbum`, `createAssets`, `openAsset`, `updateAsset`, `deleteAssets`, `duplicateAssets`, `postToSharedAlbum`, `addAssetsToAlbum`, `removeAssetsFromAlbum`, `search`, `updateRecognizedPerson`, `copyEdits`, `pasteEdits`, `cleanupPhoto`, `setExposure`, `setSaturation`, `setWarmth`, `toggleSuggestedEdits`, `setFilter`, `setDepth`, `toggleDepth`, `crop`, `straighten`, `setRotation`.
3. **`visualIntelligence` (1; iOS 26.0+ only):** `semanticContentSearch`.
4. **`reader` (9):** `rotateDocuments`, `resizeDocuments`, `openPage`, `enhanceDocuments`, `searchDocuments`, `openDocument`, `rotatePages`, `deletePages`, `insertPages`.
5. **`system` (1):** `search` (backing identifier `ShowInAppSearchResultsIntent`).
6. **`wordProcessor` (9):** `create`, `open`, `createPage`, `openPage`, `addTextBoxToPage`, `addVideoToPage`, `addImageToPage`, `addAudioToPage`, `addWebVideoToPage`.
7. **`presentation` (15):** `create`, `open`, `startPlayback`, `stopPlayback`, `update`, `createSlide`, `openSlide`, `setSlideTitle`, `addTextBoxToSlide`, `addVideoToSlide`, `addImageToSlide`, `addAudioToSlide`, `addWebVideoToSlide`, `addCommentToSlide`, `deleteSlide`.
8. **`spreadsheet` (14):** `create`, `open`, `update`, `delete`, `createSheet`, `openSheet`, `updateSheet`, `addImageToSheet`, `addTextBoxToSheet`, `addVideoToSheet`, `addAudioToSheet`, `addWebVideoToSheet`, `addCommentToSheet`, `deleteSheet`.
9. **`browser` (13):** `bookmarkTab`, `bookmarkURL`, `openBookmark`, `deleteBookmarks`, `clearHistory`, `closeTabs`, `createTab`, `openURLInTab`, `switchTab`, `createWindow`, `closeWindows`, `findOnPage`, `search`.
10. **`files` (5):** `createFolder`, `openFile`, `deleteFiles`, `renameFile`, `moveFiles`.
11. **`camera` (5):** `openInCaptureMode`, `switchDevice`, `setDevice`, `startCapture`, `stopCapture`.
12. **`mail` (10):** `createDraft`, `updateDraft`, `saveDraft`, `deleteDraft`, `sendDraft`, `forwardMail`, `replyMail`, `archiveMail`, `deleteMail`, `updateMail`.
13. **`whiteboard` (7):** `createBoard`, `openBoard`, `updateBoard`, `deleteBoard`, `createItem`, `updateItem`, `deleteItem`.
14. **`books` (9):** `openBook`, `playAudiobook`, `navigatePage`, `updateFontSize`, `updateLineSpacing`, `updateCharacterSpacing`, `updateWordSpacing`, `updateSettings`, `search`.
15. **`assistant` (1; iOS 26.2+ only):** `activate`.

**Installed-SDK result:** zero matching domains and actions for `calendar`, `event`, scheduling, free/busy, or availability. There is no `CalendarIntent` marker protocol or `.calendar` accessor in the installed iOS 26.5 interface. **Current Apple documentation differs:** it documents `.calendar.createEvent`, `.calendar.deleteEvent`, and `.calendar.updateEvent`. This indicates the website describes a newer API surface than this Xcode installation provides.

## Semantic assessment for Daymark

1. **No direct action fit.** The documented calendar domain owns event-related entities, but only exposes create, delete, and update actions. Daymark reads events, derives gaps across a requested interval, and returns an answer; no documented action performs event lookup or availability calculation.
2. **`system.search` is not a substitute.** Its backing schema identifier is `ShowInAppSearchResultsIntent`: it represents showing search results in an app, not querying calendar occupancy or returning computed free/busy intervals (installed interface around lines 5,569–5,581).
3. **Other `search` actions are domain-bound.** `journal.search`, `photos.search`, `reader.searchDocuments`, `books.search`, and `browser.search` describe their respective content domains. Annotating a calendar-availability operation with one would misstate its semantics.
4. **Read-only does not itself imply a schema.** Ordinary `AppIntent` parameters and result dialogs remain available independently of schemas. Apple’s `AppIntent` API defines the general intent protocol, while Assistant schema conformance is an additional macro-based semantic contract. [AppIntent](https://developer.apple.com/documentation/appintents/appintent)
5. **Recommended implementation posture.** Keep/use a custom `AppIntent` such as “Find Availability,” accept explicit date/range constraints, perform EventKit-backed computation in Daymark, and return a concise dialog. Do not attach an unrelated schema merely to seek broader Siri language coverage. Recheck future SDK interfaces for an actual calendar/availability domain.

## Schema vs. ordinary calendar-shaped types

The interface contains general parameter/value support for dates and durations, and SDK APIs may expose `Foundation.Calendar.RecurrenceRule`. Those are **ordinary data types usable by an `AppIntent`**; they are not evidence of an Assistant Schema. A schema exists here only where the `AssistantSchemas` domain/action API supplies a value accepted by the schema macro (for example `.journal.updateEntry`). Thus “Calendar” in a Foundation type name must not be counted as a `calendar` schema.

## Documentation-access limitation

The initial live documentation search stalled and caused the first pass to miss Apple’s separately supplied Markdown page for the Calendar domain. A subsequent direct fetch confirmed the documented calendar API. The installed iOS 26.5 public Swift interface remains authoritative for what this Xcode installation can compile, while Apple’s current website describes a newer surface that includes calendar create/delete/update schemas.

## Sources

- **Kept:** Installed iOS 26.5 `AppIntents.swiftinterface` — authoritative local compile-time declarations and exact accessor inventory.
- **Kept:** [Apple AppIntent documentation](https://developer.apple.com/documentation/appintents/appintent) — distinguishes the general app-intent protocol from schema adoption.
- **Kept:** [Apple AssistantIntent documentation](https://developer.apple.com/documentation/appintents/assistantintent) — official schema-macro adoption guidance.
- **Kept:** [Apple `AssistantSchemas.JournalIntent.updateEntry`](https://developer.apple.com/documentation/appintents/assistantschemas/journalintent/updateentry) — concrete official schema accessor example.
- **Kept:** [WWDC26: Build intelligent Siri experiences with App Schemas](https://developer.apple.com/videos/play/wwdc2026/240/) — Apple’s overview of the schema feature.
- **Dropped:** Non-Apple sources — excluded by scope.
- **Dropped:** Search-result snippets and failed live-documentation queries — not reliable primary evidence.

## Gaps

The installed interface proves what can be compiled against this SDK, but it does not document unpublished Siri routing heuristics or promise future domains. Validate the custom intent’s actual phrasing on target iOS/Siri builds, and repeat the interface inventory when adopting a newer Xcode SDK.

```acceptance-report
{
  "criteriaSatisfied": [
    {
      "criterion": "Inspect the exact installed iOS 26.5 AppIntents Swift interface",
      "status": "satisfied",
      "evidence": "Header and AssistantSchemas declarations were inspected at the required path; target arm64e-apple-ios26.5, framework 300.5.12."
    },
    {
      "criterion": "Provide the complete Assistant intent schema domain/action inventory",
      "status": "satisfied",
      "evidence": "15 domains and 131 action accessors are enumerated from the installed interface."
    },
    {
      "criterion": "Determine calendar/event/scheduling/free-busy/availability schema support and semantic fit",
      "status": "satisfied",
      "evidence": "No matching domain or action exists; unrelated search schemas are explicitly assessed and rejected."
    },
    {
      "criterion": "Distinguish schemas from ordinary AppIntent parameter/value types",
      "status": "satisfied",
      "evidence": "The report separates Foundation dates/durations/Calendar.RecurrenceRule from macro-accepted AssistantSchemas accessors."
    },
    {
      "criterion": "Use primary Apple sources and disclose access limitations",
      "status": "satisfied",
      "evidence": "Only the installed Apple SDK, Apple documentation, and an Apple WWDC video are cited; failed live documentation access is disclosed."
    }
  ],
  "changedFiles": [
    "/Users/user/.pi/agent/sessions/--Users-user-vibes-SeptTalk--/subagent-artifacts/outputs/376b4516-e1bc-4180-b509-56bc9d8ad2fe/Docs/Research/App-Schemas-Calendar.md"
  ],
  "testsAdded": [],
  "commandsRun": [
    {
      "command": "Read installed iOS 26.5 AppIntents.swiftinterface in targeted line ranges",
      "result": "passed"
    },
    {
      "command": "Inventory AssistantSchemas.Intent domain accessors and <Domain>Intent action accessors",
      "result": "passed"
    },
    {
      "command": "Targeted live Apple documentation web searches",
      "result": "failed",
      "details": "Tool became stuck/returned a null-map error; work continued from the installed SDK and already retrieved official Apple sources."
    },
    {
      "command": "Runtime/build tests",
      "result": "not-run",
      "details": "Research-only Markdown change; no executable code changed."
    }
  ],
  "residualRisks": [
    "Unpublished or server-side Siri behavior cannot be inferred from the public Swift interface.",
    "Future SDKs may add a calendar or availability schema.",
    "Live Apple documentation could not be comprehensively re-crawled during this run."
  ],
  "noStagedFiles": true,
  "manualNotes": [
    "Only the required artifact file was written.",
    "No repository source file, test, git index, or Beads state was modified.",
    "The schema inventory is based on exact Swift accessor declarations, not keyword matches against ordinary Foundation types."
  ]
}
```
