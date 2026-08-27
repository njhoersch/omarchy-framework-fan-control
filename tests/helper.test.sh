#!/usr/bin/env bash

set -euo pipefail

readonly PLUGIN_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
readonly HELPER="$PLUGIN_DIR/bin/omarchy-framework-fan-control"
readonly TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT

fail() {
  printf 'helper test failed: %s\n' "$*" >&2
  exit 1
}

assert_equal() {
  [[ $1 == "$2" ]] || fail "expected '$2', got '$1'"
}

mkdir -p "$TEST_ROOT/hwmon4"
printf 'cros_ec\n' > "$TEST_ROOT/hwmon4/name"
printf '0\n' > "$TEST_ROOT/hwmon4/fan1_input"
printf '0\n' > "$TEST_ROOT/hwmon4/pwm1"
printf '2\n' > "$TEST_ROOT/hwmon4/pwm1_enable"

export OMARCHY_FRAMEWORK_FAN_TEST_ROOT="$TEST_ROOT"

status=$($HELPER status)
assert_equal "$(jq -r .mode <<<"$status")" auto
assert_equal "$(jq -r .rpm <<<"$status")" 0

$HELPER manual 10
assert_equal "$(<"$TEST_ROOT/hwmon4/pwm1_enable")" 1
assert_equal "$(<"$TEST_ROOT/hwmon4/pwm1")" 26

$HELPER manual 100
assert_equal "$(<"$TEST_ROOT/hwmon4/pwm1")" 255

printf '3456\n' > "$TEST_ROOT/hwmon4/fan1_input"
status=$($HELPER status)
assert_equal "$(jq -r .mode <<<"$status")" manual
assert_equal "$(jq -r .percent <<<"$status")" 100
assert_equal "$(jq -r .rpm <<<"$status")" 3456

$HELPER auto
assert_equal "$(<"$TEST_ROOT/hwmon4/pwm1_enable")" 2

if $HELPER manual 0 >/dev/null 2>&1; then fail "accepted 0 percent"; fi
if $HELPER manual 55 >/dev/null 2>&1; then fail "accepted a non-step percentage"; fi
if $HELPER manual nope >/dev/null 2>&1; then fail "accepted non-numeric input"; fi

mkdir -p "$TEST_ROOT/hwmon9"
printf 'cros_ec\n' > "$TEST_ROOT/hwmon9/name"
printf '0\n' > "$TEST_ROOT/hwmon9/fan1_input"
printf '0\n' > "$TEST_ROOT/hwmon9/pwm1"
printf '2\n' > "$TEST_ROOT/hwmon9/pwm1_enable"
status=$($HELPER status)
assert_equal "$(jq -r .available <<<"$status")" false
if $HELPER manual 50 >/dev/null 2>&1; then fail "wrote with ambiguous devices"; fi

rm -rf -- "$TEST_ROOT/hwmon9"
chmod 0444 "$TEST_ROOT/hwmon4/pwm1"
if $HELPER manual 50 >/dev/null 2>&1; then fail "reported success when the PWM write failed"; fi
assert_equal "$(<"$TEST_ROOT/hwmon4/pwm1_enable")" 2
chmod 0644 "$TEST_ROOT/hwmon4/pwm1"

printf 'helper tests passed\n'
