#!/usr/bin/python3
"""Small, provider-neutral helpers for subscription collectors."""

from __future__ import annotations

import base64
import json
import os
import subprocess
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


PACKAGED_COLLECTOR_DIR = Path("/usr/share/omarchy/bin")


def read_json(path: Path) -> dict[str, Any]:
  try:
    value = json.loads(path.read_text(encoding="utf-8"))
    return value if isinstance(value, dict) else {}
  except (OSError, json.JSONDecodeError):
    return {}


def cache_path(name: str) -> Path:
  root = Path(os.environ.get("XDG_CACHE_HOME") or (Path.home() / ".cache"))
  return root / "omarchy" / "agent-usage" / name


def read_cache(path: Path, max_age_seconds: float | None = None) -> dict[str, Any]:
  payload = read_json(path)
  if not payload:
    return {}
  if max_age_seconds is not None:
    fetched_at = float(payload.get("fetchedAt") or 0)
    if fetched_at <= 0 or time.time() - fetched_at > max_age_seconds:
      return {}
  return payload


def write_cache(path: Path, payload: dict[str, Any]) -> None:
  path.parent.mkdir(parents=True, exist_ok=True)
  handle = tempfile.NamedTemporaryFile(
    mode="w",
    encoding="utf-8",
    dir=path.parent,
    prefix=f".{path.name}.",
    delete=False,
  )
  temporary = Path(handle.name)
  try:
    os.chmod(temporary, 0o600)
    with handle:
      json.dump(payload, handle, separators=(",", ":"), sort_keys=True)
      handle.write("\n")
    os.replace(temporary, path)
  finally:
    try:
      temporary.unlink()
    except FileNotFoundError:
      pass


def run_packaged_collector(agent: str, args: list[str]) -> dict[str, Any]:
  command = PACKAGED_COLLECTOR_DIR / f"omarchy-agent-usage-{agent}"
  completed = subprocess.run(
    [str(command), *args],
    check=False,
    capture_output=True,
    text=True,
    timeout=90,
  )
  if completed.returncode != 0:
    message = completed.stderr.strip() or f"packaged {agent} collector exited {completed.returncode}"
    raise RuntimeError(message)
  try:
    record = json.loads(completed.stdout)
  except json.JSONDecodeError as error:
    raise RuntimeError(f"packaged {agent} collector returned invalid JSON") from error
  if not isinstance(record, dict):
    raise RuntimeError(f"packaged {agent} collector returned a non-object record")
  return record


def parse_timestamp(value: Any) -> datetime | None:
  text = str(value or "").strip()
  if not text:
    return None
  try:
    parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
  except ValueError:
    return None
  if parsed.tzinfo is None:
    parsed = parsed.replace(tzinfo=timezone.utc)
  return parsed


def decode_jwt_payload(token: Any) -> dict[str, Any]:
  try:
    encoded = str(token).split(".")[1]
    encoded += "=" * (-len(encoded) % 4)
    value = json.loads(base64.urlsafe_b64decode(encoded).decode("utf-8"))
    return value if isinstance(value, dict) else {}
  except (IndexError, ValueError, UnicodeDecodeError, json.JSONDecodeError):
    return {}


def subscription(
  status: str,
  *,
  renews_at: Any = "",
  ends_at: Any = "",
  cancel_at_period_end: bool = False,
  estimated: bool = False,
  non_renewing: bool = False,
  source: str = "",
) -> dict[str, Any]:
  normalized = status if status in {"active", "inactive", "unknown"} else "unknown"
  return {
    "status": normalized,
    "renewsAt": str(renews_at or "") if normalized == "active" and not cancel_at_period_end else "",
    "endsAt": str(ends_at or "") if normalized == "active" and cancel_at_period_end else "",
    "cancelAtPeriodEnd": bool(cancel_at_period_end),
    "estimated": bool(estimated),
    "nonRenewing": bool(non_renewing),
    "source": str(source or ""),
  }
