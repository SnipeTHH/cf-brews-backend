# Antigravity Rules & Reminders

## ColdFusion Variable Scoping (disallowed var outside functions)
* **CRITICAL RULE**: In ColdFusion/CFML, the `var` keyword is strictly used for function-local variable declaration inside `function` or `cffunction` blocks.
* Do NOT declare variables with `var` at the top-level or outside of functions (e.g. inside `if` statements, loop blocks, or direct page scope). Instead, declare them by simply assigning to their names directly (e.g. `myVar = value` instead of `var myVar = value`).
