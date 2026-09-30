/**
 * pi-cd — a literal `/cd <directory>` slash command.
 *
 * WHY THIS EXISTS
 * Pi has no cwd setter in its extension API (`ExtensionContext.cwd` is
 * read-only), so a running session cannot change directory in place. The
 * sanctioned mechanism is session replacement, and it is legitimate because
 * cwd is persisted in the session header:
 *
 *   SessionManager.create(cwd, sessionDir?, { id })
 *
 * This command rebuilds the current conversation against a new cwd, switches
 * Pi to that session, and removes the old file — same conversation, same
 * session id, new working directory. It is the explicit-command equivalent of
 * what the `pi-agent-teleport` extension does from a model tool call, minus
 * the agent round-trip: Pi hands command handlers the ExtensionCommandContext
 * directly, so this calls switchSession itself.
 *
 * USAGE
 *   /cd ~/rig        move to a directory (absolute, relative, or ~)
 *   /cd              print the current directory
 *
 * CAVEATS
 *   - Requires a persisted session. Does nothing under `--no-session`,
 *     because there is no session file to rebuild.
 *   - Does not start an agent turn. You stay in control: run /cd, then type
 *     whatever you want next. The model picks up the new cwd in its system
 *     prompt on the next request.
 *   - Pi refuses to switch while a turn is running, so /cd queues rather than
 *     interrupting — same as every other session-switching command.
 *
 * NOTE ON `parentSession`
 * SessionManager.create() also accepts `parentSession`. It was tried and
 * removed: with it set, a two-hop /cd sequence produced a destination session
 * with a *new* id and no lineage recorded, i.e. the `id` option appeared not
 * to take effect. Without it, the id is preserved across hops every time
 * (verified). Do not re-add it without re-testing a multi-hop sequence.
 */

import { existsSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, isAbsolute, join, resolve } from "node:path";
import {
	SessionManager,
	type AutocompleteItem,
	type ExtensionAPI,
	type ExtensionCommandContext,
} from "@earendil-works/pi-coding-agent";

/** Expand a leading `~` to the user's home directory. */
export function expandHome(input: string): string {
	if (input === "~") return homedir();
	if (input.startsWith("~/")) return join(homedir(), input.slice(2));
	return input;
}

/** Resolve a user-supplied path against the current working directory. */
export function resolveTarget(cwd: string, raw: string): string {
	const expanded = expandHome(raw.trim());
	return isAbsolute(expanded) ? resolve(expanded) : resolve(cwd, expanded);
}

/** True when the path exists and is a directory. */
export function isDirectory(path: string): boolean {
	try {
		return existsSync(path) && statSync(path).isDirectory();
	} catch {
		return false;
	}
}

/** Strip one layer of matching surrounding quotes, if present. */
function unquote(raw: string): string {
	const trimmed = raw.trim();
	if (trimmed.length >= 2) {
		const first = trimmed[0];
		const last = trimmed[trimmed.length - 1];
		if ((first === '"' && last === '"') || (first === "'" && last === "'")) {
			return trimmed.slice(1, -1);
		}
	}
	return trimmed;
}

/**
 * Complete one trailing path segment. Read-only filesystem access; any failure
 * degrades to "no completions" rather than breaking the command.
 */
export function completePath(prefix: string): AutocompleteItem[] | null {
	try {
		const trailingSlash = prefix.endsWith("/");
		const expanded = expandHome(prefix);
		const base = trailingSlash ? expanded : dirname(expanded || ".");
		const partial = trailingSlash ? "" : expanded.slice(base.length + 1);
		if (!isDirectory(base)) return null;
		const entries = readdirSync(base, { withFileTypes: true })
			.filter((entry) => entry.isDirectory() && !entry.name.startsWith("."))
			.filter((entry) => entry.name.toLowerCase().startsWith(partial.toLowerCase()))
			.slice(0, 25);
		if (entries.length === 0) return null;
		// Preserve whatever path spelling the user started typing.
		const shown = prefix.slice(0, expanded.length - partial.length);
		return entries.map((entry) => ({
			value: `${shown}${entry.name}/`,
			label: `${entry.name}/`,
		}));
	} catch {
		return null;
	}
}

async function changeDirectory(ctx: ExtensionCommandContext, rawArgs: string): Promise<void> {
	const arg = unquote(rawArgs);

	if (!arg) {
		ctx.ui.notify(`Current directory: ${ctx.cwd}\nUsage: /cd <directory>`, "info");
		return;
	}

	const sourceCwd = ctx.cwd;
	const target = resolveTarget(sourceCwd, arg);

	if (!isDirectory(target)) {
		ctx.ui.notify(`Not a directory: ${target}`, "error");
		return;
	}

	const source = ctx.sessionManager.getSessionFile();
	const header = ctx.sessionManager.getHeader();
	if (!source || !header) {
		ctx.ui.notify(
			"/cd requires a persisted session. It cannot move a session started with --no-session.",
			"error",
		);
		return;
	}

	// Build the destination session: same conversation, same id, new cwd.
	let destination: string | undefined;
	try {
		const manager = SessionManager.create(target, undefined, { id: header.id });
		destination = manager.getSessionFile();
		if (!destination) throw new Error("Pi did not create a destination session.");
		const nextHeader = { ...structuredClone(header), cwd: target };
		const entries = [nextHeader, ...structuredClone(ctx.sessionManager.getEntries())];
		writeFileSync(destination, `${entries.map((entry) => JSON.stringify(entry)).join("\n")}\n`, {
			flag: "wx",
		});
	} catch (error) {
		const message = error instanceof Error ? error.message : String(error);
		if (destination && existsSync(destination)) rmSync(destination, { force: true });
		ctx.ui.notify(`/cd failed to prepare ${target}: ${message}`, "error");
		return;
	}

	let switched = false;
	try {
		const result = await ctx.switchSession(destination, {
			withSession: async (next) => {
				switched = true;
				// The switch has happened, so the old file is now stale. Removing it
				// keeps one session per directory instead of orphaning the previous
				// one, and mirrors how Pi treats a replaced session.
				rmSync(source, { force: true });
				next.ui.notify(`✦ /cd  ${sourceCwd} → ${target}`, "info");
			},
		});
		if (result?.cancelled || !switched) {
			if (existsSync(destination)) rmSync(destination, { force: true });
			ctx.ui.notify("/cd was cancelled; staying in the current directory.", "warning");
		}
	} catch (error) {
		if (switched) return; // The switch landed; surface nothing and keep the new session.
		const message = error instanceof Error ? error.message : String(error);
		if (destination && existsSync(destination)) rmSync(destination, { force: true });
		ctx.ui.notify(`/cd failed: ${message}`, "error");
	}
}

export default function cdExtension(pi: ExtensionAPI): void {
	pi.registerCommand("cd", {
		description: "Change the working directory without restarting Pi (/cd <dir>).",
		getArgumentCompletions: (prefix) => completePath(prefix ?? ""),
		handler: async (args, ctx) => {
			await changeDirectory(ctx, args ?? "");
		},
	});
}
