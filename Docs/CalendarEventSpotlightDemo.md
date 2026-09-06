# Calendar-event entities and Spotlight

Daymark's Spotlight integration is deliberately a workshop demonstration, not a recommendation to index a person's calendar.

## What is indexed

Only events created by **Create Demo Schedule** are eligible. Daymark recognizes them using both the `[Demo]` title prefix and the `schedule-assistant-demo` ownership URL written by `DemoScheduleService`.

Each `CalendarEventEntity` contributes only:

- the demo event title,
- its start date and time,
- its end date and time.

Daymark does **not** index calendar names or identifiers, locations, notes, conferencing URLs, attendees, or unrelated EventKit events.

## Identity and EventKit lifecycle

The entity ID is a versioned value containing the EventKit event identifier and occurrence start time. The start time distinguishes recurring occurrences and lets `CalendarEventEntityQuery` resolve a group of IDs with one bounded EventKit date-range query instead of one lookup per ID.

The ID is stable for ordinary indexing/query round trips and across app launches while EventKit preserves the event identifier. EventKit can replace identifiers after calendar synchronization, event moves, or delete-and-recreate operations. Daymark therefore treats these demo entities as local, short-lived identities rather than cross-device identities. Because this entity type contains demo events only, recreating or removing the demo clears the entire entity type before indexing replacements; stale identifiers cannot survive.

## Indexing and cleanup

- Creating the demo schedule indexes the newly created demo entities with the iOS 18 `indexAppEntities` API.
- Recreating it removes the old demo entities from Spotlight before replacing them.
- **Remove Demo Schedule** uses the persisted generated-day interval, so cleanup still finds the EventKit events after midnight, then clears the demo entity type from Spotlight.
- Calendar creation and removal remain authoritative. Spotlight failures are logged but do not turn successful calendar operations into failures.
- On iOS 27, `CalendarEventEntityQuery` conforms to `IndexedEntityQuery`, supporting system-requested partial and complete reindexing. Partial reindex deletes every requested ID before indexing those that still resolve; complete reindex clears the entity type before rebuilding from the persisted interval.
- The app continues to target iOS 26; only the system-driven query conformance is availability-gated to iOS 27.

To remove the sample data, open Daymark's Calendar tab and choose **Remove Demo Schedule**. This removes only events carrying Daymark's two-part ownership marker and their corresponding Spotlight entities.

## Workshop verification

On an iOS 27 simulator or device with full calendar access:

1. Remove any previous demo schedule.
2. Create the demo schedule.
3. Search Spotlight for `[Demo] Morning Call` and confirm the Daymark result appears.
4. Confirm the result shows only title and time information.
5. Remove the demo schedule.
6. Search again and confirm the demo result is gone.

Authorization denial and Spotlight ingestion are system behaviors, so automated tests cover the app-owned filtering, mapping, batched query, failure propagation, and index/delete orchestration; the visible Spotlight result remains a runtime check.
