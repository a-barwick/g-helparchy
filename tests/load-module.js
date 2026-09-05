const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

// Keep QML imports in separate scopes so tests catch missing dependencies.
module.exports = function loadModule(relativePath) {
    const filename = path.resolve(__dirname, "..", relativePath)
    let source = fs.readFileSync(filename, "utf8")
    const context = {}
    source = source.replace(/^\.pragma library\s*$/gm, "")
    source = source.replace(/^\.import "([^"]+)" as (\w+)\s*$/gm, (_, dependency, alias) => {
        context[alias] = module.exports(path.relative(path.resolve(__dirname, ".."),
            path.resolve(path.dirname(filename), dependency)))
        return ""
    })
    vm.createContext(context)
    vm.runInContext(source, context, { filename })
    return context
}
