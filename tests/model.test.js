const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8")
const model = { JSON, Math, Number, String, isFinite }
vm.createContext(model)
vm.runInContext(source, model)

assert.equal(model.snapPercent(4), 10)
assert.equal(model.snapPercent(54), 50)
assert.equal(model.snapPercent(56), 60)
assert.equal(model.snapPercent(120), 100)
assert.equal(model.percentForIndex(0), 10)
assert.equal(model.percentForIndex(9), 100)
assert.equal(model.indexForPercent(50), 4)

assert.deepEqual(
  JSON.parse(JSON.stringify(model.parseStatus('{"protocolVersion":1,"available":true,"mode":"manual","percent":49,"rpm":3210}'))),
  { protocolVersion: 1, available: true, mode: "manual", percent: 49, rpm: 3210, reason: "" }
)
assert.equal(model.parseStatus("not-json").available, false)
assert.match(model.parseStatus('{"protocolVersion":2}').reason, /reinstalled/)
assert.equal(model.tooltip({ available: true, mode: "auto", percent: 0, rpm: 900 }), "Fan: Automatic · 900 RPM")
assert.equal(model.tooltip({ available: true, mode: "manual", percent: 50, rpm: 3000 }), "Fan: Manual 50% · 3000 RPM")

console.log("model tests passed")
