#!/usr/bin/env python3
"""Reject authored job IDs embedded in shared Godot code."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
JOB_ID = re.compile(r'^job_id\s*=\s*&"([^"]+)"', re.MULTILINE)


def main() -> int:
	job_ids: set[str] = set()
	for resource in (ROOT / "assets").rglob("*.tres"):
		job_ids.update(JOB_ID.findall(resource.read_text(encoding="utf-8")))
	violations: list[str] = []
	for script in (ROOT / "scripts").rglob("*.gd"):
		text = script.read_text(encoding="utf-8")
		for job_id in sorted(job_ids):
			if f'"{job_id}"' in text:
				violations.append(f"{script.relative_to(ROOT)} embeds authored job ID {job_id!r}")
	if violations:
		print("verify-job-id-independence: FAIL")
		for violation in violations:
			print(f"- {violation}")
		return 1
	print(f"verify-job-id-independence: PASS ({len(job_ids)} authored job IDs, no shared-code literals)")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
