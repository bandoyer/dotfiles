const test = require("node:test")
const assert = require("node:assert/strict")
const NotificationLogic = require("../NotificationLogic.js")

test("the reminder scheduler's final alert is a reminder alert", () => {
  assert.equal(NotificationLogic.isReminderAlert("Reminder"), true)
  assert.equal(NotificationLogic.isReminderAlert("  Reminder  "), true)
})

test("the confirmation shown when a reminder is created is not", () => {
  assert.equal(NotificationLogic.isReminderAlert("Reminder set for 5 minutes"), false)
  assert.equal(NotificationLogic.isReminderAlert("Check the oven in 30 minutes"), false)
})

test("missing summaries are not reminder alerts", () => {
  assert.equal(NotificationLogic.isReminderAlert(undefined), false)
  assert.equal(NotificationLogic.isReminderAlert(null), false)
  assert.equal(NotificationLogic.isReminderAlert(""), false)
})
