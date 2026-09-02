# Persistent Notifications

A user-owned clone of Omarchy's notification service. It retains the packaged
notification daemon, popup, do-not-disturb, history, and notification-body
hardening behavior while making completed Omarchy reminder alerts persistent
until explicitly dismissed.

The reminder scheduler sends its final alert with the summary `Reminder`.
Those alerts receive an infinite popup lifetime; the separate confirmation
shown when a reminder is created keeps the normal timeout.

This plugin is managed by the parent Chezmoi repository and selected from its
`shell.json`. Runtime notification history and copied images stay under
`$XDG_STATE_HOME` (or `~/.local/state`) and are not committed.

The implementation is derived from `shell/plugins/notifications` in
[`basecamp/omarchy`](https://github.com/basecamp/omarchy) and retains its MIT
license.
