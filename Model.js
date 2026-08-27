function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(maximum, value))
}

function snapPercent(value) {
  var number = Number(value)
  if (!isFinite(number)) number = 50
  return clamp(Math.round(number / 10) * 10, 10, 100)
}

function indexForPercent(value) {
  return snapPercent(value) / 10 - 1
}

function percentForIndex(index) {
  var number = Number(index)
  if (!isFinite(number)) number = 4
  return (clamp(Math.round(number), 0, 9) + 1) * 10
}

function unavailable(reason) {
  return {
    protocolVersion: 1,
    available: false,
    mode: "unknown",
    percent: 0,
    rpm: 0,
    reason: String(reason || "Fan control is unavailable")
  }
}

function parseStatus(text) {
  var value
  try {
    value = JSON.parse(String(text || ""))
  } catch (error) {
    return unavailable("Fan helper returned invalid status")
  }

  if (!value || Number(value.protocolVersion) !== 1)
    return unavailable("Fan helper needs to be reinstalled")

  if (!value.available)
    return unavailable(value.reason || "No compatible cros_ec fan was found")

  var mode = value.mode === "manual" ? "manual" : (value.mode === "auto" ? "auto" : "unknown")
  if (mode === "unknown") return unavailable("Fan helper returned an unknown control mode")

  return {
    protocolVersion: 1,
    available: true,
    mode: mode,
    percent: clamp(Math.round(Number(value.percent) || 0), 0, 100),
    rpm: Math.max(0, Math.round(Number(value.rpm) || 0)),
    reason: ""
  }
}

function tooltip(state) {
  if (!state || !state.available) return state && state.reason ? state.reason : "Framework fan control unavailable"
  var label = state.mode === "manual" ? "Manual " + state.percent + "%" : "Automatic"
  return "Fan: " + label + " · " + state.rpm + " RPM"
}
