#!/usr/bin/env bash
# Checks that every playbook parses, that nothing reintroduces variable loading
# that outranks host_vars, that host_vars and group_vars override the role
# defaults, and that fixed role vars ignore host_vars but yield to -e.
# Needs ansible-core plus the collections from requirements.yml.
set -euo pipefail
cd "$(dirname "$0")"
export ANSIBLE_BECOME=false
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false

echo "== Syntax check"
for playbook in ../../main.yml ../../playbooks/*.yml; do
  ansible-playbook -i inventory.ini --syntax-check "$playbook"
done

echo "== Static checks"
# Use the Python that runs Ansible, which has PyYAML.
python="$(head -1 "$(command -v ansible-playbook)" | sed -n 's/^#! *//p')"
(cd ../.. && ${python:-python3} tests/precedence/static_checks.py)

echo "== Precedence"
ansible-playbook -i inventory.ini probe.yml

echo "== Precedence with -e"
ansible-playbook -i inventory.ini probe.yml -e @extra_vars.yml

echo "All precedence checks passed."
