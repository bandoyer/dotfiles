from __future__ import annotations

import base64
import importlib.machinery
import importlib.util
import json
import os
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path
from unittest import mock


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
MUSE = load_script("omarchy-agent-usage-muse")


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

  def test_profile_signed_in_to_another_account_is_skipped(self):
    import os
    import tempfile
    import urllib.error
    from unittest import mock

    calls = []

    def fetch(organization, cookie_name, cookie_value):
      calls.append(cookie_value)
      if cookie_value == "sk-ant-other-account":
        raise urllib.error.HTTPError("url", 404, "Not Found", {}, None)
      return {"status": "active", "next_charge_at": "2026-10-04T15:56:55Z"}

    with tempfile.TemporaryDirectory() as cache, \
        mock.patch.dict(os.environ, {"XDG_CACHE_HOME": cache}), \
        mock.patch.object(CLAUDE, "organization_uuid", return_value="org-main"), \
        mock.patch.object(CLAUDE, "claude_session_cookies", return_value=[
          ("sessionKey", "sk-ant-other-account"),
          ("sessionKey", "sk-ant-this-account"),
        ]), \
        mock.patch.object(CLAUDE, "fetch_subscription_details", side_effect=fetch):
      value = CLAUDE.claude_subscription({}, {}, force=True)
      cached = CLAUDE.cached_subscriptions()

    self.assertEqual(["sk-ant-other-account", "sk-ant-this-account"], calls)
    self.assertEqual("2026-10-04T15:56:55Z", value["renewsAt"])
    self.assertEqual("anthropic-subscription-details", value["source"])
    self.assertEqual([value], [entry["subscription"] for entry in cached.values()])

  def test_live_tier_replaces_stale_login_tier(self):
    # The token said 5x at login; the account has since moved to 20x.
    self.assertEqual("Max 20x", CLAUDE.current_tier_label(
      "Max 5x", {"rateLimitTier": "default_claude_max_20x"}, {}))
    self.assertEqual("Max 20x", CLAUDE.current_tier_label(
      "Max 5x", {}, {"organizationRateLimitTier": "default_claude_max_20x"}))
    self.assertEqual("Max 5x", CLAUDE.current_tier_label("Max 5x", {}, {}))
    self.assertEqual("Pro", CLAUDE.current_tier_label(
      "Pro", {"rateLimitTier": "default_claude_pro"}, {}))
    self.assertEqual("", CLAUDE.current_tier_label(
      "", {"rateLimitTier": "default_claude_max_20x"}, {}))

  def test_profile_cache_is_not_shared_between_accounts(self):
    import os
    import tempfile
    from unittest import mock

    with tempfile.TemporaryDirectory() as cache, \
        mock.patch.dict(os.environ, {"XDG_CACHE_HOME": cache}), \
        mock.patch.object(CLAUDE, "fetch_profile", return_value={"rateLimitTier": "default_claude_max_5x"}):
      with mock.patch.object(CLAUDE, "organization_uuid", return_value="org-alt"):
        CLAUDE.cached_profile({"accessToken": "token"}, force=True)
      with mock.patch.object(CLAUDE, "organization_uuid", return_value="org-main"), \
          mock.patch.object(CLAUDE, "fetch_profile", side_effect=OSError("offline")):
        self.assertEqual({}, CLAUDE.cached_profile({"accessToken": "token"}, force=False))

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


class MuseUsageTests(unittest.TestCase):
  TODAY = "2026-10-19"

  def stamp(self, hour: int) -> int:
    return int(datetime(2026, 10, 19, hour).timestamp() * 1_000_000)

  def line(self, record_id: str, hour: int, event: dict) -> str:
    return json.dumps({
      "id": record_id,
      "recorded_at": self.stamp(hour),
      "payload_type": "runtime.session",
      "payload": {"kind": "run", "event": event},
    })

  def prompt(self, record_id: str, hour: int) -> str:
    return json.dumps({
      "id": record_id,
      "recorded_at": self.stamp(hour),
      "payload_type": "runtime.user_intent.accepted",
      "payload": {},
    })

  def call(self, input_tokens: int, output_tokens: int, cached: int) -> dict:
    return {
      "kind": "model_completed",
      "model": "muse-wonder-full-1.0",
      "usage": {
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "cached_tokens": cached,
        "cache_read_tokens": cached,
        "cache_write_tokens": 0,
        "reasoning_tokens": 3,
      },
    }

  def scan(self, logs: dict[str, list[str]]) -> dict:
    with tempfile.TemporaryDirectory() as data:
      root = Path(data) / "muse" / "sessions" / "2026" / "10" / "19"
      for relative, lines in logs.items():
        path = root / relative / "session.jsonl"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("\n".join(lines) + "\n")
      with mock.patch.dict(os.environ, {"XDG_DATA_HOME": data}):
        usage = MUSE.SessionUsage(today=self.TODAY)
        MUSE.scan_sessions(usage)
        return usage.stats()

  def test_cached_tokens_are_split_out_of_input(self):
    stats = self.scan({"root-a": [
      self.prompt("p1", 9),
      self.line("c1", 9, self.call(56776, 340, 55284)),
    ]})
    model = stats["modelUsage"]["muse-wonder-full-1.0"]
    self.assertEqual(1492, model["inputTokens"])
    self.assertEqual(340, model["outputTokens"])
    self.assertEqual(55284, model["cacheReadInputTokens"])
    self.assertEqual(56776 + 340, stats["todayTotalTokens"])
    self.assertEqual(1, stats["todayPrompts"])

  def test_subagent_calls_count_toward_the_root_session_but_not_as_prompts(self):
    stats = self.scan({
      "root-a": [
        self.prompt("p1", 9),
        self.line("c1", 9, self.call(100, 10, 0)),
      ],
      "root-a/subagent/sub-1": [
        self.prompt("p2", 9),
        self.line("c2", 9, self.call(200, 20, 0)),
      ],
    })
    self.assertEqual(1, stats["totalPrompts"])
    self.assertEqual(1, stats["totalSessions"])
    self.assertEqual(330, stats["todayTotalTokens"])

  def test_attribution_records_and_repeated_ids_are_not_counted_twice(self):
    attribution = {"kind": "goal_usage_attribution", "usage_family": "provider",
                   "usage": {"input_tokens": 100, "output_tokens": 10}}
    stats = self.scan({
      "root-a": [
        self.line("c1", 9, self.call(100, 10, 0)),
        self.line("g1", 9, attribution),
      ],
      "root-b": [self.line("c1", 9, self.call(100, 10, 0))],
    })
    self.assertEqual(110, stats["todayTotalTokens"])

  def test_record_for_an_empty_home_is_not_ready(self):
    with tempfile.TemporaryDirectory() as data, mock.patch.dict(os.environ, {"XDG_DATA_HOME": data}):
      record = MUSE.scan()
    self.assertEqual("muse", record["id"])
    self.assertFalse(record["ready"])
    self.assertEqual([], record["limits"])
    self.assertEqual("unknown", record["subscription"]["status"])


if __name__ == "__main__":
  unittest.main()
