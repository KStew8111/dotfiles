/**
 * pi-review-report-shim — decode `workflowReturn` for the pi_review_report
 * tool before it executes.
 *
 * Why: some harnesses advertise `Type.Any()` tool params as string schemas,
 * so `workflowReturn` arrives at the tool as a JSON-encoded string (even when
 * the model emitted a real object) and unpatched pi-review (< 0.8.4) rejects
 * every call with "workflowReturn must be an object". pi's `tool_call` hook
 * hands us the parsed arguments by reference and applies in-place mutations
 * before execution with no re-validation, so decoding the string here is the
 * one place a fix can live WITHOUT modifying the pi-review package itself —
 * it survives extension reinstalls/updates untouched.
 *
 * Idempotent and version-tolerant: only mutates when the value is a string
 * that decodes to an object; passes objects (or undecodable garbage, letting
 * the tool produce its own error) through untouched. Safe to keep installed
 * alongside a fixed pi-review. Delete this file once upstream ships a
 * release that accepts string-encoded workflowReturn values natively.
 *
 * Status: this shim is the ACTIVE mitigation (2026-09-01). A fuller
 * in-package fix (typed schema + decode + directive hardening) is preserved
 * as a local patch at ~/.pi/agent/pi-review-0.8.4-local.patch — a candidate
 * for an upstream PR to GeorgeDong32/pi-review.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const TARGET_TOOL = "pi_review_report";

export default function piReviewReportShim(pi: ExtensionAPI): void {
	pi.on("tool_call", (event) => {
		if (event.toolName !== TARGET_TOOL) return;
		const input = event.input as Record<string, unknown>;
		let current: unknown = input.workflowReturn;
		// Up to two decode rounds: handles plain JSON strings and
		// double-encoded strings from models that stringify twice.
		for (let depth = 0; depth < 2 && typeof current === "string"; depth++) {
			try {
				current = JSON.parse(current);
			} catch {
				break; // not JSON — leave as-is; the tool's own error explains
			}
		}
		if (current && typeof current === "object") {
			input.workflowReturn = current;
		}
	});
}