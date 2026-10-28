#!/usr/bin/env python3
"""Static guards for the role's variable precedence. Run from the repo root.

The probe in probe.yml checks effective values but never runs the role's tasks,
so these checks cover what it can't see:
  1. Nothing loads variables with vars_files or include_vars (both outrank
     host_vars), except playbooks/apisix-only.yml's lookup of an IP-named host_vars file.
  2. No set_fact assigns a key from defaults/main.yml (set_fact also outranks host_vars).
     Re-assigning a key to itself ("{{ key }}") is allowed.
  3. Feature toggles are not compared as strings; use "| bool" so YAML booleans work.
  4. Every template src used by a reachable task file exists under templates/.
     Inside a role Ansible looks in templates/ first, so a file left elsewhere
     (for example in tasks/) can silently be replaced by a same-named template.
"""
import glob
import os
import re
import sys

import yaml

ROLE = "roles/ethereum_home_staking"
TOGGLES = ("charon_enabled", "mev_boost_enabled", "cadvisor_enabled", "apisix_enabled")


class Loader(yaml.SafeLoader):
    pass


Loader.add_multi_constructor("!", lambda loader, suffix, node: None)


def load(path):
    with open(path) as f:
        return yaml.load(f, Loader=Loader)


def tasks_in(items):
    """Yield every task dict, descending into blocks."""
    for task in items or []:
        if not isinstance(task, dict):
            continue
        yield task
        for key in ("block", "rescue", "always"):
            yield from tasks_in(task.get(key))


def module(task, *names):
    for name in names:
        for key in (name, "ansible.builtin." + name):
            if key in task:
                return task[key]
    return None


errors = []
defaults = load(f"{ROLE}/defaults/main.yml")
playbooks = ["main.yml"] + sorted(glob.glob("playbooks/*.yml"))

# Task files reachable from the playbooks: the role's main.yml, any tasks_from,
# and whatever those import.
entry = {"main"}
task_lists = {}
for pb in playbooks:
    plays = load(pb) or []
    task_lists[pb] = []
    for play in plays:
        if play.get("vars_files"):
            errors.append(f"{pb}: play '{play.get('name')}' uses vars_files")
        for section in ("pre_tasks", "tasks", "post_tasks", "handlers"):
            task_lists[pb].extend(tasks_in(play.get(section)))
    for task in task_lists[pb]:
        role = module(task, "import_role", "include_role")
        if isinstance(role, dict) and role.get("tasks_from"):
            entry.add(role["tasks_from"])

reachable, todo = set(), list(entry)
while todo:
    name = todo.pop()
    path = f"{ROLE}/tasks/{name if name.endswith('.yml') else name + '.yml'}"
    if path in reachable or not os.path.exists(path):
        continue
    reachable.add(path)
    task_lists[path] = list(tasks_in(load(path)))
    for task in task_lists[path]:
        imported = module(task, "import_tasks", "include_tasks")
        if isinstance(imported, str) and "{{" not in imported:
            todo.append(imported)
for path in sorted(glob.glob(f"{ROLE}/handlers/*.yml")):
    task_lists[path] = list(tasks_in(load(path)))

for path, tasks in task_lists.items():
    for task in tasks:
        name = task.get("name", "<unnamed>")
        included = module(task, "include_vars")
        if included is not None:
            target = included.get("file", "") if isinstance(included, dict) else str(included)
            if "host_vars/" not in target:
                errors.append(f"{path}: '{name}' loads variables with include_vars ({target})")
        facts = module(task, "set_fact")
        if isinstance(facts, dict):
            for key, value in facts.items():
                self_ref = re.fullmatch(r"\{\{\s*%s\s*\}\}" % re.escape(key), str(value).strip())
                if key in defaults and not self_ref:
                    errors.append(f"{path}: '{name}' set_facts '{key}', which is a role default")
        template = module(task, "template")
        if path.startswith(ROLE) and isinstance(template, dict):
            src = str(template.get("src", ""))
            if src and "{{" not in src:
                rel = src[3:] if src.startswith("../templates/") else src
                rel = rel if rel.startswith("templates/") else "templates/" + rel
                if not os.path.exists(f"{ROLE}/{rel}"):
                    errors.append(f"{path}: '{name}' uses template {src}, which is not in {ROLE}/templates/")

toggle_compare = re.compile(r"\b(%s)\b\s*(\|\s*string\s*)?(==|!=)" % "|".join(TOGGLES))
for path in playbooks + sorted(glob.glob(f"{ROLE}/tasks/*")) + sorted(glob.glob(f"{ROLE}/templates/*")):
    with open(path, errors="ignore") as f:
        for number, line in enumerate(f, 1):
            if toggle_compare.search(line) and not line.lstrip().startswith("#"):
                errors.append(f"{path}:{number}: compares a toggle as a string; use '| bool'")

if errors:
    print("Static checks failed:")
    print("\n".join("  " + e for e in errors))
    sys.exit(1)
print(f"Static checks passed ({len(reachable)} task files, {len(playbooks)} playbooks).")
