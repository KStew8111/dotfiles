/**
 * plan-model-switch — auto-switch models at the plan-mode boundary.
 *
 * Pairs with the @pandi-coding-agent/plan extension. When a plan is APPROVED,
 * the plan extension persists a `plan-state` session entry with
 * status "approved" and wakes the implementation turn via sendUserMessage.
 * That wake prompt fires pi's `before_agent_start` event before any LLM call,
 * so we hook it there and switch the model — planning stays on e.g. glm-5.3,
 * implementation starts on a different model, with no manual /model needed.
 *
 * Configuration (environment variables, see README/docs):
 *
 *   PI_PLAN_IMPL_MODEL        Model to switch to when a plan is approved.
 *                             "provider/model" or bare "model" (provider
 *                             falls back to the current model's provider).
 *                             Example: PI_PLAN_IMPL_MODEL=ollama-cloud/kimi-k2.7-code:cloud
 *   PI_PLAN_IMPL_THINKING     Optional thinking level for implementation:
 *                             off|minimal|low|medium|high|xhigh|max
 *   PI_PLAN_PLANNER_MODEL     Optional. Switch BACK to this model when a new
 *                             plan starts (status "planning"), so the next
 *                             plan is also researched with the planner model.
 *                             Unset = keep whatever model is active.
 *   PI_PLAN_PLANNER_THINKING  Optional thinking level for planning.
 *
 * `/planswitch` logs the current configuration to the UI.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { Model } from "@earendil-works/pi-ai";

/** Shape of the `plan-state` custom entries appended by @pandi-coding-agent/plan. */
interface PlanStateData {
	planId: string;
	task?: string;
	active?: boolean;
	status?: "planning" | "approved" | "rejected" | "exited" | "planned";
	startedAt?: number;
}

type ThinkingLevel = "off" | "minimal" | "low" | "medium" | "high" | "xhigh" | "max";
const THINKING_LEVELS: ThinkingLevel[] = ["off", "minimal", "low", "medium", "high", "xhigh", "max"];

const PLAN_STATE_TYPE = "plan-state";

interface SwitchTarget {
	spec: string;
	thinking?: ThinkingLevel;
}

function parseThinking(raw: string | undefined, label: string): ThinkingLevel | undefined {
	if (!raw) return undefined;
	const value = raw.trim().toLowerCase() as ThinkingLevel;
	if (!THINKING_LEVELS.includes(value)) {
		console.warn(`[plan-model-switch] ignoring ${label}: unknown thinking level "${raw}"`);
		return undefined;
	}
	return value;
}

function parseTarget(modelSpec: string | undefined, thinkingSpec: string | undefined, label: string): SwitchTarget | undefined {
	if (!modelSpec || !modelSpec.trim()) return undefined;
	const spec = modelSpec.trim();
	const thinking = parseThinking(thinkingSpec, label);
	console.log(`[plan-model-switch] ${label} target: ${spec}${thinking ? ` (thinking: ${thinking})` : ""}`);
	return { spec, thinking };
}

/** Resolved at handler time: model objects come from ctx.modelRegistry. */
const implTarget = parseTarget(process.env.PI_PLAN_IMPL_MODEL, process.env.PI_PLAN_IMPL_THINKING, "implementation");
const plannerTarget = parseTarget(process.env.PI_PLAN_PLANNER_MODEL, process.env.PI_PLAN_PLANNER_THINKING, "planning");

/** No-op unless a switch is configured. */
const enabled = Boolean(implTarget || plannerTarget);

/** planIds already switched to the implementation model this session (switch only once per approved plan). */
const handledPlans = new Set<string>();

/** Latest `plan-state` entry (append-only session log → last write wins). */
function latestPlanState(ctx: ExtensionContext): PlanStateData | undefined {
	let latest: PlanStateData | undefined;
	for (const entry of ctx.sessionManager.getEntries() as Array<{ type: string; customType?: string; data?: unknown }>) {
		if (entry.type === "custom" && entry.customType === PLAN_STATE_TYPE && entry.data) {
			latest = entry.data as PlanStateData;
		}
	}
	return latest;
}

/** Resolve "provider/model" (or bare "model") to a Model from the registry. */
function resolveModel(ctx: ExtensionContext, target: SwitchTarget): Model<any> | undefined {
	const slash = target.spec.indexOf("/");
	if (slash === -1) {
		const provider = ctx.model?.provider;
		if (!provider) return undefined;
		return ctx.modelRegistry.find(provider, target.spec);
	}
	return ctx.modelRegistry.find(target.spec.slice(0, slash), target.spec.slice(slash + 1));
}

function sameModel(a: Model<any> | undefined, b: Model<any>): boolean {
	return Boolean(a && a.provider === b.provider && a.id === b.id);
}

async function switchModel(pi: ExtensionAPI, ctx: ExtensionContext, target: SwitchTarget, label: string): Promise<void> {
	const model = resolveModel(ctx, target);
	if (!model) {
		ctx.ui.notify(`plan-model-switch: model "${target.spec}" not found in registry`, "warning");
		return;
	}
	let switched = false;
	if (!sameModel(ctx.model, model)) {
		const ok = await pi.setModel(model);
		if (!ok) {
			ctx.ui.notify(`plan-model-switch: no API key for ${model.provider}/${model.id}`, "warning");
			return;
		}
		switched = true;
	}
	if (target.thinking && pi.getThinkingLevel() !== target.thinking) {
		pi.setThinkingLevel(target.thinking);
		switched = switched || sameModel(ctx.model, model);
	}
	if (switched) {
		ctx.ui.notify(
			`plan-model-switch: ${label} → ${model.provider}/${model.id}${target.thinking ? ` (thinking: ${target.thinking})` : ""}`,
			"info",
		);
	}
}

export default function planModelSwitchExtension(pi: ExtensionAPI): void {
	pi.on("before_agent_start", async (_event, ctx) => {
		if (!enabled) return;
		const plan = latestPlanState(ctx);
		if (!plan?.planId || !plan.status) return;
		if (plan.status === "approved") {
			if (handledPlans.has(plan.planId)) return; // already switched for this plan
			handledPlans.add(plan.planId);
			if (implTarget) await switchModel(pi, ctx, implTarget, "implementation");
		} else if (plan.status === "planning") {
			// A plan was armed (or a revision was rejected): go back to the planner model if configured.
			if (plannerTarget) await switchModel(pi, ctx, plannerTarget, "planning");
		}
	});

	pi.registerCommand("planswitch", {
		description: "Show plan-mode model-switch configuration and current model",
		handler: async (_args, ctx) => {
			const current = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "(none)";
			const fmt = (t: SwitchTarget | undefined) => (t ? `${t.spec}${t.thinking ? ` (thinking: ${t.thinking})` : ""}` : "(no switch)");
			ctx.ui.notify(
				`Current model: ${current}\n` +
					`On plan approval → ${fmt(implTarget)}${implTarget ? "" : " [set PI_PLAN_IMPL_MODEL]"}\n` +
					`On plan start → ${fmt(plannerTarget)}${plannerTarget ? "" : " [set PI_PLAN_PLANNER_MODEL]"}\n` +
					`Handled plans: ${[...handledPlans].join(", ") || "(none)"}`,
				"info",
			);
		},
	});
}