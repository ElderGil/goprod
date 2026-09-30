#!/usr/bin/env python3
"""Validate the plugin: manifests parse, every skill has valid frontmatter,
bundled scripts are syntactically valid bash. Exit 1 on any failure."""
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
errors = []
# Resolve bash through PATH order. On Windows, subprocess would otherwise find
# C:\Windows\System32\bash.exe (the WSL launcher) before Git Bash.
BASH = shutil.which("bash")


def fail(msg):
    errors.append(msg)


for manifest in (".claude-plugin/plugin.json", ".claude-plugin/marketplace.json"):
    try:
        json.loads((ROOT / manifest).read_text(encoding="utf-8"))
    except Exception as e:  # noqa: BLE001 - report any parse failure
        fail(f"{manifest}: invalid JSON ({e})")

plugin_version = json.loads((ROOT / ".claude-plugin/plugin.json").read_text(encoding="utf-8")).get("version")
changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
if plugin_version and f"## [{plugin_version}]" not in changelog:
    fail(f"CHANGELOG.md has no section for plugin version {plugin_version}")

skills = sorted(p for p in (ROOT / "skills").iterdir() if p.is_dir())
if not skills:
    fail("no skills found under skills/")

for skill in skills:
    md = skill / "SKILL.md"
    if not md.is_file():
        fail(f"{skill.name}: missing SKILL.md")
        continue
    text = md.read_text(encoding="utf-8")
    m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not m:
        fail(f"{skill.name}: missing YAML frontmatter")
        continue
    try:
        front = yaml.safe_load(m.group(1))
    except yaml.YAMLError as e:
        fail(f"{skill.name}: invalid YAML frontmatter ({e})")
        continue
    name, desc = front.get("name"), front.get("description")
    if name != skill.name:
        fail(f"{skill.name}: frontmatter name '{name}' does not match directory")
    if not isinstance(desc, str) or not desc.strip():
        fail(f"{skill.name}: empty description")
    elif len(desc) > 1024:
        fail(f"{skill.name}: description has {len(desc)} chars (max 1024)")
    lines = text.count("\n")
    if lines > 500:
        fail(f"{skill.name}: SKILL.md has {lines} lines (keep under 500)")
    for script in skill.rglob("*.sh"):
        rel = script.relative_to(ROOT).as_posix()
        if BASH is None:
            fail(f"{rel}: bash not found on PATH, cannot syntax-check")
            continue
        r = subprocess.run([BASH, "-n", rel], cwd=ROOT, capture_output=True, text=True)
        if r.returncode != 0:
            fail(f"{rel}: bash syntax error (exit {r.returncode}, bash={BASH}): {r.stderr.strip()}")

for e in errors:
    print(f"FAIL {e}")
print(f"{len(skills)} skills checked, {len(errors)} problem(s)")
sys.exit(1 if errors else 0)
