import { Controller } from "@hotwired/stimulus"

// Shows and hides form fields from the rules stored on each field.
// Mirrors Form::Rule (Ruby) exactly; spec/fixtures/files/form_rules.json runs through both.
// The server re-evaluates everything on submit, so this is only for a nicer experience.

// Plain decimal numbers only, matching Form::Rule::NUMBER.
const NUMBER = /^[+-]?(\d+(\.\d*)?|\.\d+)$/
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/

const isFilled = (answer) => Array.isArray(answer) ? answer.length > 0 : String(answer ?? "") !== ""

const equals = (answer, expected) => {
  const target = String(expected).toLowerCase()
  return Array.isArray(answer)
    ? answer.some(item => String(item).toLowerCase() === target)
    : String(answer ?? "").toLowerCase() === target
}

const compare = (answer, expected) => {
  if (Array.isArray(answer) || String(answer ?? "") === "") return null
  const a = String(answer).trim(), b = String(expected).trim()
  if (NUMBER.test(a) && NUMBER.test(b)) return Math.sign(Number(a) - Number(b))
  if (ISO_DATE.test(a) && ISO_DATE.test(b)) return a < b ? -1 : a > b ? 1 : 0
  return null
}

const holds = (condition, answer) => {
  const expected = String(condition.value ?? "")
  switch (condition.operator) {
    case "filled": return isFilled(answer)
    case "empty": return !isFilled(answer)
    case "equals": return equals(answer, expected)
    case "not_equals": return !equals(answer, expected)
    case "contains": return Array.isArray(answer) ? equals(answer, expected) : String(answer ?? "").toLowerCase().includes(expected.toLowerCase())
    case "greater_than": return compare(answer, expected) === 1
    case "less_than": return compare(answer, expected) === -1
    default: return false
  }
}

export function evaluateRule(rule, answers) {
  const conditions = rule?.conditions ?? []
  if (conditions.length === 0) return true
  const results = conditions.map(condition => holds(condition, answers[condition.field]))
  return rule.match === "any" ? results.some(Boolean) : results.every(Boolean)
}

export default class extends Controller {
  static values = { rules: Object }

  connect() {
    this.update()
  }

  // Top to bottom: a field is visible when its rule holds for the visible answers above it.
  update() {
    const answers = {}
    this.element.querySelectorAll("[data-field-key]").forEach(wrapper => {
      const key = wrapper.dataset.fieldKey
      const visible = evaluateRule(this.rulesValue[key], answers)
      wrapper.hidden = !visible
      wrapper.querySelectorAll("input, select, textarea").forEach(input => { input.disabled = !visible })
      if (visible) answers[key] = this.ruleValue(wrapper)
    })
  }

  // Same shapes as FormField#rule_value.
  ruleValue(wrapper) {
    const inputs = [...wrapper.querySelectorAll("input:not([type=hidden]), select, textarea")]
    switch (wrapper.dataset.fieldType) {
      case "multi_select": return inputs.filter(input => input.checked).map(input => input.value.trim()).filter(Boolean)
      case "checkbox": return inputs[0]?.checked ? "true" : ""
      case "file": return inputs[0]?.files?.length ? inputs[0].files[0].name : ""
      case "address": return inputs.some(input => input.value.trim() !== "") ? "filled" : ""
      default: return (inputs[0]?.value ?? "").trim()
    }
  }
}
