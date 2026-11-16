# Background app refresh sync

The **Background app refresh sync** setting controls scheduled iOS app refresh syncs. It defaults to on, including for existing installations. Turning it off cancels scheduled refreshes; it does not disable Bluetooth-triggered syncs from Stay connected. The 15-minute minimum and 15-minute retry limit still apply to both. iOS decides when an app refresh runs and may delay or omit it. [CODE] [UNVERIFIED: device behavior]

## Check on an iPhone

With Mi Fitness closed and a band connected, check that an existing installation still schedules background refresh without changing settings. Turn the setting off and verify that Stay connected can still sync after a held session reconnects when the prior completed sync is old enough. Turn it back on and check that refresh is scheduled again. iOS does not guarantee a delivery time. [UNVERIFIED]

In Diagnostics → Share log, `background refresh: request accepted` confirms that iOS accepted a request, not that it will run. `request failed` records the error domain and code; `pending request cancelled` confirms cancellation was requested. `task delivered` means iOS invoked the task; `background sync: background refresh` or `background sync: held session opened` records an actual sync start. The in-memory log is lost when the process ends. [CODE] [UNVERIFIED: device behavior]
