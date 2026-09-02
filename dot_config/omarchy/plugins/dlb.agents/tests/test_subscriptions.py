from __future__ import annotations

import base64
import importlib.machinery
import importlib.util
import json
import sys
import unittest
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
sys.path.insert(0, str(SCRIPTS))

def load_script(name: str):
  path = SCRIPTS / name
  if not path.exists():
    # In the Chezmoi source tree, executable target files carry this prefix.
    path = SCRIPTS / f"executable_{name}"
  loader = importlib.machinery.SourceFileLoader(name.replace("-", "_"), str(path))
  spec = importlib.util.spec_from_loader(loader.name, loader)
  module = importlib.util.module_from_spec(spec)
  loader.exec_module(module)
  return module


CLAUDE = load_script("omarchy-agent-usage-claude")
CODEX = load_script("omarchy-agent-usage-codex")
GROK = load_script("omarchy-agent-usage-grok")


def fake_jwt(payload: dict) -> str:
  def encode(value: dict) -> str:
    raw = json.dumps(value, separators=(",", ":")).encode()
    return base64.urlsafe_b64encode(raw).decode().rstrip("=")

  return encode({"alg": "none"}) + "." + encode(payload) + ".signature"


class ClaudeSubscriptionTests(unittest.TestCase):
  def test_scheduled_cancellation_uses_exact_plan_end(self):
    value = CLAUDE.subscription_from_details({
      "status": "active",
      "next_charge_at": "2026-09-15T21:49:22Z",
      "plan_ending_at": "2026-09-15T21:49:22Z",
    })
    self.assertEqual("active", value["status"])
    self.assertEqual("", value["renewsAt"])
    self.assertEqual("2026-09-15T21:49:22Z", value["endsAt"])
    self.assertTrue(value["cancelAtPeriodEnd"])

  def test_renewing_plan_uses_exact_next_charge(self):
    value = CLAUDE.subscription_from_details({
      "status": "active",
      "next_charge_at": "2026-09-15T21:49:22Z",
      "plan_ending_at": None,
    })
    self.assertEqual("active", value["status"])
    self.assertEqual("2026-09-15T21:49:22Z", value["renewsAt"])
    self.assertFalse(value["cancelAtPeriodEnd"])

  def test_active_max_does_not_treat_plan_creation_as_renewal(self):
    value = CLAUDE.subscription_from_profile(
      {
        "subscriptionStatus": "active",
        "organizationType": "claude_max",
        "subscriptionCreatedAt": "2024-09-12T16:11:44+00:00",
      },
      {"subscriptionType": "max"},
    )
    self.assertEqual("active", value["status"])
    self.assertEqual("", value["renewsAt"])
    self.assertFalse(value["estimated"])

  def test_explicit_inactive_status_beats_saved_credentials(self):
    value = CLAUDE.subscription_from_profile(
      {"subscriptionStatus": "canceled", "organizationType": "claude_max"},
      {"subscriptionType": "max"},
    )
    self.assertEqual("inactive", value["status"])
    self.assertEqual("", value["renewsAt"])


class CodexSubscriptionTests(unittest.TestCase):
  def auth(self, namespace: dict, auth_mode: str = "chatgpt"):
    return {
      "auth_mode": auth_mode,
      "tokens": {"id_token": fake_jwt({CODEX.AUTH_NAMESPACE: namespace})},
    }

  def test_web_subscription_uses_exact_period_end(self):
    value = CODEX.subscription_from_payload({
      "plan_type": "pro",
      "active_until": "2026-09-23T03:47:25Z",
      "will_renew": True,
    }, now=datetime(2026, 8, 31, tzinfo=timezone.utc))
    self.assertEqual("active", value["status"])
    self.assertEqual("2026-09-23T03:47:25Z", value["renewsAt"])
    self.assertFalse(value["estimated"])

  def test_web_subscription_reports_scheduled_cancellation(self):
    value = CODEX.subscription_from_payload({
      "plan_type": "pro",
      "active_until": "2026-09-23T03:47:25Z",
      "will_renew": False,
    }, now=datetime(2026, 8, 31, tzinfo=timezone.utc))
    self.assertEqual("active", value["status"])
    self.assertEqual("", value["renewsAt"])
    self.assertEqual("2026-09-23T03:47:25Z", value["endsAt"])
    self.assertTrue(value["cancelAtPeriodEnd"])

  def test_auth_claim_is_status_only_fallback(self):
    auth = self.auth({
      "chatgpt_plan_type": "pro",
      "chatgpt_subscription_active_start": "2026-04-08T00:31:35+00:00",
      "chatgpt_subscription_active_until": "2026-09-18T15:36:43+00:00",
    })
    value = CODEX.auth_subscription(auth, now=datetime(2026, 8, 31, tzinfo=timezone.utc))
    self.assertEqual("active", value["status"])
    self.assertEqual("", value["renewsAt"])

  def test_expired_or_api_key_accounts_are_inactive(self):
    expired = self.auth({
      "chatgpt_plan_type": "pro",
      "chatgpt_subscription_active_until": "2026-08-01T00:00:00+00:00",
    })
    self.assertEqual(
      "inactive",
      CODEX.auth_subscription(expired, now=datetime(2026, 8, 31, tzinfo=timezone.utc))["status"],
    )
    api_key = self.auth({}, auth_mode="apikey")
    self.assertEqual("inactive", CODEX.auth_subscription(api_key)["status"])


class GrokSubscriptionTests(unittest.TestCase):
  def test_fresh_week_with_omitted_zero_percentage_still_has_a_limit(self):
    value = GROK.limit_from_config({
      "currentPeriod": {
        "type": "USAGE_PERIOD_TYPE_WEEKLY",
        "start": "2026-08-31T00:32:52+00:00",
        "end": "2026-09-07T00:32:52+00:00",
      },
    }, now=datetime(2026, 8, 31, 15, tzinfo=timezone.utc))
    self.assertEqual("Weekly (7-day)", value["label"])
    self.assertEqual(0.0, value["percent"])
    self.assertEqual("2026-09-07T00:32:52+00:00", value["resetsAt"])

  def test_missing_period_is_not_invented_as_a_zero_limit(self):
    self.assertIsNone(GROK.limit_from_config({}, now=datetime(2026, 8, 31, tzinfo=timezone.utc)))

  def test_highest_active_subscription_uses_exact_period_end(self):
    value = GROK.subscription_from_payload({
      "subscriptions": [
        {"tier": "SUBSCRIPTION_TIER_GROK_PRO", "status": "SUBSCRIPTION_STATUS_INACTIVE"},
        {
          "tier": "SUBSCRIPTION_TIER_SUPER_GROK_PRO",
          "status": "SUBSCRIPTION_STATUS_ACTIVE",
          "billingPeriodEnd": "2026-09-20T17:59:10Z",
          "stripe": {"currentPeriodEnd": "2026-09-20T17:59:10Z", "cancelAtPeriodEnd": False},
        },
      ]
    })
    self.assertEqual("active", value["status"])
    self.assertEqual("2026-09-20T17:59:10Z", value["renewsAt"])
    self.assertFalse(value["estimated"])

  def test_canceling_subscription_reports_an_end_not_a_renewal(self):
    value = GROK.subscription_from_payload({
      "subscriptions": [{
        "tier": "SUBSCRIPTION_TIER_SUPER_GROK_PLUS",
        "status": "SUBSCRIPTION_STATUS_ACTIVE",
        "billingPeriodEnd": "2026-09-20T17:59:10Z",
        "cancelAtPeriodEnd": True,
      }]
    })
    self.assertEqual("", value["renewsAt"])
    self.assertEqual("2026-09-20T17:59:10Z", value["endsAt"])
    self.assertTrue(value["cancelAtPeriodEnd"])

  def test_no_active_subscription_is_inactive(self):
    value = GROK.subscription_from_payload({
      "subscriptions": [{"status": "SUBSCRIPTION_STATUS_INACTIVE"}]
    })
    self.assertEqual("inactive", value["status"])


if __name__ == "__main__":
  unittest.main()
