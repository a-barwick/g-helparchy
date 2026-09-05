const assert = require("node:assert")
const loadModule = require("./load-module")
const FanCurves = loadModule("logic/FanCurves.js")


// ---------------------------------------------------------------- fan curves
const pts = FanCurves.parseFanPoints("30c:1%,49c:2%,60c:40%")
assert.deepEqual(pts, [{ temp: 30, speed: 1 }, { temp: 49, speed: 2 }, { temp: 60, speed: 40 }])
assert.equal(FanCurves.serializeFanPoints(pts), "30c:1%,49c:2%,60c:40%")
// Dragging past a neighbour reorders instead of crossing, and stays in bounds.
const moved = FanCurves.moveFanPoint(pts, 0, 200, -5)
assert.deepEqual(moved[moved.length - 1], { temp: 100, speed: 0 })
console.log("ok - fan checks passed")
