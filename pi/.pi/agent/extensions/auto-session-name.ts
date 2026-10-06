/**
 * auto-session-name — give each session a readable name derived from its
 * first prompt, the way Copilot-style chat UIs title a conversation.
 *
 * pi has no built-in auto-titling setting, but the extension API is enough:
 * `before_agent_start` carries the raw prompt, `ctx.modelRegistry.complete()`
 * makes a one-shot model call, and `pi.setSessionName()` writes the name that
 * shows up in the session selector, footer, and terminal title.
 *
 * Behaviour:
 *  - Names the session once, on the first prompt of the session, but only
 *    when no name is already set (never clobbers a manual `/name`).
 *  - The title is generated in the background, so the agent run is not
 *    delayed while the naming request is in flight.
 *  - Falls back to a trimmed snippet of the prompt if no model/auth is
 *    available or the request fails.
 *
 * Env knobs:
 *  - PI_AUTO_SESSION_NAME=0            disable entirely
 *  - PI_AUTO_SESSION_NAME_MODEL=prov/id  model used for titling
 *    (defaults to the active session model)
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const DISABLED = process.env.PI_AUTO_SESSION_NAME === "0";
const MODEL_OVERRIDE = process.env.PI_AUTO_SESSION_NAME_MODEL?.trim();

const MAX_TITLE_LENGTH = 60;

/** Only attempt one automatic name per session lifetime. */
let attempted = false;

function sanitizeTitle(raw: string): string | undefined {
	const title = raw
		.replace(/\s+/g, " ")
		.replace(/^["'`#*\s]+|["'`*\s]+$/g, "")
		.trim();
	if (!title) return undefined;

	const clipped = title.length > MAX_TITLE_LENGTH ? `${title.slice(0, MAX_TITLE_LENGTH - 1).trimEnd()}…` : title;
	return clipped || undefined;
}

/** Cheap, dependency-free fallback: the prompt's first line, trimmed. */
function fallbackTitle(prompt: string): string | undefined {
	return sanitizeTitle(prompt.split("\n").find((line) => line.trim()) ?? prompt);
}

function buildNamingPrompt(prompt: string): string {
	const snippet = prompt.trim().slice(0, 2000);
	return [
		"Write a short title for the coding session that begins with the request below.",
		"Rules: 3 to 6 words, no trailing punctuation, no quotes, no markdown, plain text only.",
		"Reply with the title alone and nothing else.",
		"",
		"<request>",
		snippet,
		"</request>",
	].join("\n");
}

function resolveModel(ctx: ExtensionContext) {
	if (MODEL_OVERRIDE) {
		const slash = MODEL_OVERRIDE.indexOf("/");
		if (slash > 0) {
			const found = ctx.modelRegistry.find(MODEL_OVERRIDE.slice(0, slash), MODEL_OVERRIDE.slice(slash + 1));
			if (found) return found;
		}
	}
	return ctx.model ?? undefined;
}

async function generateTitle(prompt: string, ctx: ExtensionContext): Promise<string | undefined> {
	const model = resolveModel(ctx);
	if (!model || !ctx.modelRegistry.hasConfiguredAuth(model)) {
		return fallbackTitle(prompt);
	}

	try {
		const response = await ctx.modelRegistry.complete(model, {
			messages: [
				{
					role: "user" as const,
					content: [{ type: "text" as const, text: buildNamingPrompt(prompt) }],
					timestamp: Date.now(),
				},
			],
		});
		const text = response.content
			.filter((part): part is { type: "text"; text: string } => part.type === "text")
			.map((part) => part.text)
			.join(" ");
		return sanitizeTitle(text) ?? fallbackTitle(prompt);
	} catch {
		return fallbackTitle(prompt);
	}
}

export default function autoSessionName(pi: ExtensionAPI): void {
	if (DISABLED) return;

	// A fresh/resumed session starts a new naming opportunity; a session that
	// already has a name (set previously or passed with `--name`) is left alone.
	pi.on("session_start", () => {
		attempted = pi.getSessionName() !== undefined;
	});

	pi.on("before_agent_start", async (event, ctx) => {
		if (attempted || pi.getSessionName() !== undefined) return;
		attempted = true;

		const prompt = event.prompt?.trim();
		if (!prompt) {
			attempted = false;
			return;
		}

		// Fire-and-forget: name the session when the model responds without
		// blocking the agent run that is about to start.
		void generateTitle(prompt, ctx).then((title) => {
			if (!title) return;
			if (pi.getSessionName() !== undefined) return; // user beat us to it
			pi.setSessionName(title);
		});
	});
}
