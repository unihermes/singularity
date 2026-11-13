# Behavioral and runtime audit

## Scope and evidence

Repository inventory, QML timers and process launch sites, Python subprocess/loop
sites, targeted service review, and the complete automated pre-commit suite.
This is not an exhaustive certification of every desktop interaction or device.

The suite covers JS algorithms, Hyprland geometry/config readers, settings value
repair, queued writes, AI lifecycle/routing, state migration, platform policies,
installer previews, helper syntax and repository tooling. New native offscreen
Quickshell checks exercise reactive app caches, coalesced host status, and actual
`fd` search with an embedded newline in a filename. They use temporary HOME,
runtime and cache directories.

## Fixed

- AI host status: replace permanent 200 ms polling with change-triggered publication.
  Initial state is still published; bursts coalesce into one write.
- App search: normalize and sort the catalog on catalog/usage changes, then filter
  cached rows on keystrokes. Preserve prefix priority, usage ordering, alphabetical
  mode, metadata matches and desktop-entry object identity. Reuse the ID index for
  pins. Class caches use dictionaries without inherited keys.
- File search: serialize process reuse across exit/stdout ordering; reject obsolete
  results after query replacement or clearing. Use NUL-delimited results for newline
  filenames, and compute rank/depth once per result instead of inside each comparison.
- Recent files: read XBEL once, accept reordered attributes and single quotes, reject
  remote file URIs, and decode XML before URI escapes to preserve literal `&amp;`
  filenames. Home abbreviation checks a path boundary.
- Process grouping: cache shared ancestry within each snapshot, including misses;
  retain cycle handling and the heaviest-member kill target. Process names such as
  `constructor` no longer collide with inherited object properties.
- Sensors: use shell built-in reads instead of spawning `cat` for every sensor and
  label. Fixture checks cover missing labels, temperatures and zero-RPM fans with
  no external commands available in PATH.

## Performance evidence

Local Node microbenchmarks, not whole-desktop CPU measurements:

| Workload | Before | After |
|---|---:|---:|
| Search 2,000 apps, 300 queries, cached catalog | 0.997 ms/query | 0.038 ms/query |
| Group a reversed 1,500-process ancestry chain, 5 snapshots | 35.308 ms/snapshot | 0.824 ms/snapshot |

The host removes five idle timer callbacks per second. Sensor sampling removes
one external read per chip plus up to two per sensor on each sweep. Cache rebuild
costs remain when source data changes; the app benchmark measures repeated queries.

## Remaining coverage and follow-ups

- Live focus, drag, multi-monitor layout, suspend/resume, real pairing, VPN changes,
  recording and physical hardware behavior have not been exercised in this pass.
  Offscreen tests cannot establish those behaviors.
- `Network.qml` still retries device discovery every five seconds when no Wi-Fi
  device exists. Gating this needs hotplug/restart tests as well as startup inventory.
- `viz-capture.py` still synchronously runs `pw-dump` every two seconds while
  capturing audio. A slow dump can delay forwarding; changing this needs stream
  switching, reconnect and child-process shutdown coverage.
- The independently running AI host disables file watching. Its status optimization
  takes effect on the next host restart; active conversations were not interrupted.

## RAM follow-up

- Release the notification sidebar's scene after its closing animation. Reopening
  before deferred destruction cancels unloading. History remains in Notifications;
  the sidebar already resets scroll and expansion on each open.
- Prune media stream bindings/start timestamps when streams disappear, and player
  length caches/references when players disappear. Track positions retain only the
  twenty recent tracks plus tracks bound to live streams. A 500-track regression
  checks that cache size stays bounded and live playback metadata survives.
- Existing LazyWindow already destroys settings/system/notes windows on close.
- Spotify/Steam startup uses real close requests after tray registration, not
  permanently hidden mapped windows. Their private UI heaps are outside the shell's
  control. No renderer-killing, forced garbage collection, allocator flags or app
  shutdown policy was introduced. Tray/background memory retention is also reported
  in [Valve's tracker](https://github.com/ValveSoftware/steam-for-linux/issues/6802).
  No safe, verified tray-preserving memory reduction was established for either app.
- These changes release retained objects; they do not establish an RSS/PSS saving
  in MiB. Host processes are outside the command sandbox's PID namespace, and Qt's
  allocator/image caches may retain freed pages for reuse.
