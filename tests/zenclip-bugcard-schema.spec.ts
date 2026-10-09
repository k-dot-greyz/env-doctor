/**
 * Contract tests for the schema and example introduced with the zenClip blueprint.
 * These inspect schema keywords and exercise its regexes; they do not implement
 * a JSON Schema validator or test the planned (not yet implemented) compiler.
 * Run: npm run test:pw -- tests/zenclip-bugcard-schema.spec.ts --reporter=line
 */
import { expect, test } from "@playwright/test";

import card from "../agents_ram/zenclip-bug-forensics/examples/sample-bugcard.json";
import schema from "../agents_ram/zenclip-bug-forensics/schemas/zenclip-bugcard-1.schema.json";

const fields = schema.properties;
const triage = fields.triage.properties;
const repro = fields.repro.properties;
const hydration = fields.hydration.properties;
const escalation = fields.cursor_escalation.properties;
const exportFields = fields.exports.properties;
const redaction = fields.redaction.properties;
const record = schema.$defs.hydration_record;
const artifact = schema.$defs.artifact;

test("pins the schema dialect and bug card version", () => {
  expect(schema.$schema).toBe("https://json-schema.org/draft/2020-12/schema");
  expect(fields.schema).toEqual({ const: "zenclip-bugcard/1" });
  expect(card.schema).toBe(fields.schema.const);
});

// Explicit expectations keep a removed required field from silently reducing
// coverage. Optional escalation/export data must remain optional for P0 cards.
const objects = [
  { name: "card", rule: schema, samples: [card], required: [
    "schema", "report_id", "identity_fingerprint", "created_at", "revision",
    "triage", "repro", "hydration", "artifacts", "redaction",
  ] },
  { name: "triage", rule: fields.triage, samples: [card.triage], required: [
    "title_suggested", "severity_user", "bug_class", "product_surface",
  ] },
  { name: "repro", rule: fields.repro, samples: [card.repro], required: [
    "steps", "expected", "actual", "frequency",
  ] },
  { name: "hydration", rule: fields.hydration, samples: [card.hydration], required: [
    "vectors_run", "vectors_failed", "records",
  ] },
  { name: "failed vector", rule: hydration.vectors_failed.items,
    samples: card.hydration.vectors_failed, required: ["vector", "reason"] },
  { name: "hydration record", rule: record, samples: card.hydration.records,
    required: ["type", "key", "value"] },
  { name: "artifact", rule: artifact, samples: card.artifacts,
    required: ["role", "media_type", "sha256", "path"] },
  { name: "redaction", rule: fields.redaction, samples: [card.redaction],
    required: ["rules_applied", "secrets_detected"] },
  { name: "escalation", rule: fields.cursor_escalation,
    samples: [card.cursor_escalation], required: [] },
  { name: "exports", rule: fields.exports, samples: [card.exports], required: [] },
];

for (const { name, rule, samples, required } of objects) {
  test(`${name}: closes unknown fields and preserves required fields`, () => {
    expect(rule.type).toBe("object");
    expect(rule.additionalProperties).toBe(false);
    const declared = "required" in rule ? rule.required : [];
    expect([...declared].sort()).toEqual([...required].sort());
    for (const key of required) {
      expect(Object.keys(rule.properties)).toContain(key);
    }
  });

  test(`${name}: sample has required fields and no undeclared fields`, () => {
    expect(samples.length).toBeGreaterThan(0);
    for (const sample of samples) {
      expect(sample).not.toBeNull();
      expect(Array.isArray(sample)).toBe(false);
      expect(typeof sample).toBe("object");
      for (const key of required) expect(Object.keys(sample)).toContain(key);
      for (const key of Object.keys(sample)) {
        expect(Object.keys(rule.properties)).toContain(key);
      }
    }
  });
}

const enums = [
  { name: "severity", rule: triage.severity_user, values: ["unusable", "sometimes", "minor"],
    samples: [card.triage.severity_user] },
  { name: "surface", rule: triage.product_surface,
    values: ["cursor_ide", "cursor_cli", "background_agent", "bugbot", "other"],
    samples: [card.triage.product_surface] },
  { name: "frequency", rule: repro.frequency, values: ["always", "often", "sometimes", "once"],
    samples: [card.repro.frequency] },
  { name: "record type", rule: record.properties.type,
    values: ["section", "pass", "warn", "fail", "info", "status"],
    samples: card.hydration.records.map((row) => row.type) },
  { name: "artifact role", rule: artifact.properties.role,
    values: ["screenshot_primary", "screenshot_crop", "infograph", "bundle_json", "log_tail", "overflow_blob"],
    samples: card.artifacts.map((item) => item.role) },
];

for (const { name, rule, values, samples } of enums) {
  test(`${name}: preserves supported values and sample compatibility`, () => {
    expect([...rule.enum].sort()).toEqual([...values].sort());
    for (const value of samples) expect(rule.enum).toContain(value);
  });
}

test("bug classes remain extensible beyond the documented examples", () => {
  expect(triage.bug_class).toMatchObject({ type: "string" });
  expect(triage.bug_class).not.toHaveProperty("enum");
  expect(triage.bug_class).not.toHaveProperty("const");
  expect(typeof card.triage.bug_class).toBe("string");
});

test("array items use the shared record and artifact definitions", () => {
  expect(hydration.records).toEqual({ type: "array", items: { $ref: "#/$defs/hydration_record" } });
  expect(fields.artifacts).toEqual({ type: "array", items: { $ref: "#/$defs/artifact" } });
  expect(hydration.vectors_failed.type).toBe("array");
  expect(Array.isArray(card.hydration.records)).toBe(true);
  expect(Array.isArray(card.hydration.vectors_failed)).toBe(true);
  expect(Array.isArray(card.artifacts)).toBe(true);
});

const reportIds: [string, string, boolean][] = [
  ["minimum length", `zc_${"a".repeat(16)}`, true],
  ["maximum length", `zc_${"Z".repeat(24)}`, true],
  ["mixed URL-safe characters", "zc_Az09_-Az09_-Az09_-", true],
  ["too short", `zc_${"a".repeat(15)}`, false],
  ["too long", `zc_${"a".repeat(25)}`, false],
  ["missing prefix", "a".repeat(20), false],
  ["wrong prefix case", `ZC_${"a".repeat(20)}`, false],
  ["leading junk", `xzc_${"a".repeat(20)}`, false],
  ["trailing junk", `zc_${"a".repeat(20)}!`, false],
  ["whitespace", `zc_${"a".repeat(16)} `, false],
  ["slash", `zc_${"a".repeat(15)}/`, false],
  ["non-ASCII", `zc_${"a".repeat(15)}é`, false],
  ["empty", "", false],
];

for (const [name, value, accepted] of reportIds) {
  test(`report ID pattern: ${name}`, () => {
    expect(fields.report_id.type).toBe("string");
    expect(new RegExp(fields.report_id.pattern).test(value)).toBe(accepted);
  });
}

for (const { name, rule, prefix, samples } of [
  { name: "fingerprint", rule: fields.identity_fingerprint, prefix: "sha256:",
    samples: [card.identity_fingerprint] },
  { name: "artifact digest", rule: artifact.properties.sha256, prefix: "",
    samples: card.artifacts.map((item) => item.sha256) },
]) {
  test(`${name}: accepts lowercase SHA-256 and rejects malformed digests`, () => {
    expect(rule.type).toBe("string");
    const pattern = new RegExp(rule.pattern);
    for (const digest of ["0".repeat(64), "0123456789abcdef".repeat(4)]) {
      expect(pattern.test(prefix + digest), digest).toBe(true);
    }
    for (const digest of ["", "a".repeat(63), "a".repeat(65), "A".repeat(64),
      "g".repeat(64), `${"a".repeat(63)} `, `${"a".repeat(63)}/`]) {
      expect(pattern.test(prefix + digest), JSON.stringify(digest)).toBe(false);
    }
    // A fingerprint is algorithm-qualified; an artifact stores the bare digest.
    const wrongPrefix = prefix === "" ? "sha256:" : "";
    expect(pattern.test(wrongPrefix + "a".repeat(64))).toBe(false);
    for (const value of samples) expect(value).toMatch(pattern);
  });
}

test("sample report ID matches the schema pattern", () => {
  expect(card.report_id).toMatch(new RegExp(fields.report_id.pattern));
});

for (const { name, rule, values, minimum } of [
  { name: "revision", rule: fields.revision, values: [card.revision], minimum: 1 },
  { name: "secret count", rule: redaction.secrets_detected,
    values: [card.redaction.secrets_detected], minimum: 0 },
  { name: "artifact bytes", rule: artifact.properties.bytes,
    values: card.artifacts.map((item) => item.bytes), minimum: 0 },
]) {
  test(`${name}: requires an integer with the correct lower bound`, () => {
    expect(rule).toEqual({ type: "integer", minimum });
    for (const value of values) {
      expect(Number.isInteger(value)).toBe(true);
      expect(value).toBeGreaterThanOrEqual(minimum);
    }
  });
}

for (const [name, rule, value, limit] of [
  ["title", triage.title_suggested, card.triage.title_suggested, 200],
  ["user note", repro.user_note, card.repro.user_note, 500],
] as const) {
  test(`${name}: caps Unicode character length`, () => {
    expect(rule).toEqual({ type: "string", maxLength: limit });
    expect(typeof value).toBe("string");
    // JSON Schema counts code points, not UTF-16 code units.
    expect([...value].length).toBeLessThanOrEqual(rule.maxLength);
  });
}

for (const { name, rule, values, maxItems } of [
  { name: "repro steps", rule: repro.steps, values: card.repro.steps, maxItems: 20 },
  { name: "vectors run", rule: hydration.vectors_run, values: card.hydration.vectors_run },
  { name: "redaction rules", rule: redaction.rules_applied, values: card.redaction.rules_applied },
  { name: "clipboard MIME types", rule: exportFields.clipboard_mime, values: card.exports.clipboard_mime },
]) {
  test(`${name}: preserves string items, limits, and empty-array support`, () => {
    expect(rule).toEqual({ type: "array", items: { type: "string" },
      ...(maxItems === undefined ? {} : { maxItems }) });
    expect(Array.isArray(values)).toBe(true);
    for (const value of values) expect(typeof value).toBe("string");
    if (maxItems !== undefined) expect(values.length).toBeLessThanOrEqual(maxItems);
  });
}

for (const [name, rule, value] of [
  ["created_at", fields.created_at, card.created_at],
  ["updated_at", fields.updated_at, card.updated_at],
] as const) {
  test(`${name}: declares date-time format and the sample uses valid UTC`, () => {
    expect(rule).toEqual({ type: "string", format: "date-time" });
    expect(typeof value).toBe("string");
    expect(value).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/);
    expect(new Date(value).toISOString()).toBe(value.replace("Z", ".000Z"));
  });
}

test("escalation permits explicit unknown IDs and privacy state", () => {
  expect(escalation.request_id).toEqual({ type: ["string", "null"] });
  expect(escalation.agent_bc_id).toEqual({ type: ["string", "null"] });
  expect(escalation.privacy_mode).toEqual({ type: ["boolean", "null"] });
  for (const key of ["request_id", "agent_bc_id", "privacy_mode"] as const) {
    const value = card.cursor_escalation[key];
    expect(escalation[key].type).toContain(value === null ? "null" : typeof value);
  }
});

test("descriptive fields and sample values remain strings", () => {
  const strings = [
    [triage.forum_template_version, card.triage.forum_template_version],
    [repro.expected, card.repro.expected],
    [repro.actual, card.repro.actual],
    [escalation.share_data_repro_offer, card.cursor_escalation.share_data_repro_offer],
    [exportFields.forum_markdown, card.exports.forum_markdown],
    [exportFields.email_subject, card.exports.email_subject],
    ...card.hydration.vectors_failed.flatMap((failure) => [
      [hydration.vectors_failed.items.properties.vector, failure.vector],
      [hydration.vectors_failed.items.properties.reason, failure.reason],
    ]),
    ...card.hydration.records.flatMap((row) => [
      [record.properties.key, row.key], [record.properties.value, row.value],
    ]),
    ...card.artifacts.flatMap((item) => [
      [artifact.properties.media_type, item.media_type], [artifact.properties.path, item.path],
    ]),
  ];
  for (const [rule, value] of strings) {
    expect(rule).toEqual({ type: "string" });
    expect(typeof value).toBe("string");
  }
});
