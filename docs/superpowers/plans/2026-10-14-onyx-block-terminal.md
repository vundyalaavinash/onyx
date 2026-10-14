# Onyx Block Terminal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every Onyx terminal gets a Warp-style input pinned at the bottom and one block per command above it, delivered as the single core patch Onyx allows.

**Architecture:** A new terminal contribution directory `onyxBlocks/` inside upstream's `terminalContrib/`, registered through `registerTerminalContribution`, plus one import line in `terminal.all.ts`. Output stays in xterm; blocks come from shell integration markers; the input is a Monaco `CodeEditorWidget`; the xterm area shrinks via `padding-bottom` on `.xterm`, which upstream already subtracts when computing rows. The whole thing is captured as `patches/onyx-block-terminal.patch`.

**Tech Stack:** VS Code 1.140 (upstream pinned at 07f806f), TypeScript, xterm.js, Monaco editor widget, upstream mocha/tdd unit tests run in Electron via `scripts/test.sh`, VSCodium patch pipeline (`git apply --ignore-whitespace`).

**Spec:** `docs/superpowers/specs/2026-10-14-onyx-block-terminal-design.md`

## Global Constraints

- Only two upstream paths may appear in the patch: new files under `src/vs/workbench/contrib/terminalContrib/onyxBlocks/` and one added import line in `src/vs/workbench/contrib/terminal/terminal.all.ts`. `test/blocks.sh` enforces this.
- All feature code, CSS and tests live in `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/`. The patch file `patches/onyx-block-terminal.patch` is the committed artifact; regenerate it with `just blocks-patch` and commit it with every task.
- Upstream's eslint import rules for `terminalContrib/*` allow `vs/base`, `vs/platform/*`, `vs/editor`, `vs/editor/contrib/*`, `vs/workbench`, `vs/workbench/services/*`, `vs/workbench/contrib/*`, other `terminalContrib/*`, and `@xterm/xterm` in browser files. Nothing else.
- Setting id is exactly `onyx.terminal.blocks.enabled`, boolean, default `true`, window scope. No other settings.
- Context key id is exactly `onyxBlocks.inputFocused`. Command ids are prefixed `onyx.blocks.`.
- Colours are constants: bands alternate `rgba(255,255,255,0.025)` / transparent, edge `#1a1a1a`, selected `#00c2ff`, failed `rgba(255,130,114,0.4)`, header text `#8e8e8e`, prompt glyph `❯` in `#00c2ff`, input background `#000`, border `#1a1a1a`.
- Input grows from one to eight lines. Constant `MaxInputLines = 8`.
- History cap 500. Constant `HistoryCap = 500`.
- Agent handoff command id is `onyx.agent.sendBlock` with payload `{ command, output, exitCode, cwd, shellType }`; missing command shows notification "Agent API not installed yet".
- Every commit message ends with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Work happens in the Onyx repo worktree. `vscode/` there is an upstream checkout with VSCodium's patches applied as uncommitted changes; never commit inside `vscode/`, never run `git stash` or `git checkout .` there.
- Compile check: `cd vscode && npm run compile` (3 to 8 minutes) or keep `npm run watch-client` running. Unit tests: `cd vscode && ./scripts/test.sh --run <test file path relative to vscode/>`. Lint: `cd vscode && npx eslint src/vs/workbench/contrib/terminalContrib/onyxBlocks`.

## Review Focus

1. A shell with no shell integration (for example `/bin/sh`, or `terminal.integrated.shellIntegration.enabled` off): the terminal must behave exactly like stock VS Code, with no input widget and no errors. Pinned by `onyxBlocksEnablement.test.ts` (Task 1).
2. `clear`, scrollback trimming or a disposed marker: blocks disappear quietly, nothing throws, selection is cleared if it pointed at a removed block. Pinned by `onyxBlockModel.test.ts` (Task 2).
3. Empty or whitespace-only input on Enter: nothing is sent to the shell and the history does not record it. Pinned by `onyxInputState.test.ts` and `onyxInputHistory.test.ts` (Task 3).
4. A terminal restored with a full-screen program already running (alt buffer active at attach): the input must start hidden. Pinned by `onyxInputState.test.ts` (Task 3).
5. Multi-line input: it must reach the shell as one command (bracketed paste), not as several Enter presses. Pinned by `onyxInputState.test.ts` (Task 3).

---

### Task 1: Scaffold the contribution, the setting, the patch pipeline

**Files:**
- Create: `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/common/onyxBlocksConfiguration.ts`
- Create: `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/browser/onyxBlocksEnablement.ts`
- Create: `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/browser/onyxBlocksContribution.ts`
- Create: `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/browser/terminal.onyxBlocks.contribution.ts`
- Create: `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/browser/media/onyxBlocks.css`
- Create: `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/test/browser/onyxBlocksEnablement.test.ts`
- Modify: `vscode/src/vs/workbench/contrib/terminal/terminal.all.ts` (one import line after the `voice` import)
- Create: `patches/onyx-block-terminal.patch` (generated)
- Create: `test/blocks.sh`
- Modify: `justfile` (add `blocks-patch` recipe, add `./test/blocks.sh` to `test`)

**Interfaces:**
- Produces: `OnyxBlocksSettingId.Enabled = 'onyx.terminal.blocks.enabled'`; `shouldEnableBlocks(input: IEnablementInput): boolean`; class `OnyxBlocksContribution` with `static ID = 'terminal.onyxBlocks'`, `static get(instance)`, hooks `xtermReady`, `xtermOpen`, `layout`; the `just blocks-patch` recipe; `test/blocks.sh`.

- [ ] **Step 1: Write the failing enablement test**

`vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/test/browser/onyxBlocksEnablement.test.ts`:

```ts
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Onyx contributors. Licensed under the MIT License.
 *--------------------------------------------------------------------------------------------*/

import { strictEqual } from 'assert';
import { ensureNoDisposablesAreLeakedInTestSuite } from '../../../../../../base/test/common/utils.js';
import { shouldEnableBlocks } from '../../browser/onyxBlocksEnablement.js';

suite('Onyx blocks enablement', () => {
	ensureNoDisposablesAreLeakedInTestSuite();

	test('enabled when setting on, command detection present and xterm open', () => {
		strictEqual(shouldEnableBlocks({ settingEnabled: true, hasCommandDetection: true, xtermOpened: true }), true);
	});

	test('disabled when the setting is off', () => {
		strictEqual(shouldEnableBlocks({ settingEnabled: false, hasCommandDetection: true, xtermOpened: true }), false);
	});

	test('disabled without shell integration (no command detection)', () => {
		strictEqual(shouldEnableBlocks({ settingEnabled: true, hasCommandDetection: false, xtermOpened: true }), false);
	});

	test('disabled before xterm is in the DOM', () => {
		strictEqual(shouldEnableBlocks({ settingEnabled: true, hasCommandDetection: true, xtermOpened: false }), false);
	});
});
```

- [ ] **Step 2: Run it to see it fail**

Run: `cd vscode && ./scripts/test.sh --run src/vs/workbench/contrib/terminalContrib/onyxBlocks/test/browser/onyxBlocksEnablement.test.ts`
Expected: fails, module `onyxBlocksEnablement.js` not found (compile first with `npm run compile` if `out/` is stale; the compile itself will fail on the missing module, which also counts).

- [ ] **Step 3: Write the setting, the enablement function, the contribution shell, the CSS**

`common/onyxBlocksConfiguration.ts`:

```ts
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Onyx contributors. Licensed under the MIT License.
 *--------------------------------------------------------------------------------------------*/

import type { IStringDictionary } from '../../../../../base/common/collections.js';
import { localize } from '../../../../../nls.js';
import { ConfigurationScope, type IConfigurationPropertySchema } from '../../../../../platform/configuration/common/configurationRegistry.js';

export const enum OnyxBlocksSettingId {
	Enabled = 'onyx.terminal.blocks.enabled',
}

export const onyxBlocksConfiguration: IStringDictionary<IConfigurationPropertySchema> = {
	[OnyxBlocksSettingId.Enabled]: {
		markdownDescription: localize('onyx.blocks.enabled', "Show a command input pinned at the bottom of the terminal and one block per command above it. Requires shell integration; terminals without it behave like a stock terminal. Applies to new terminals."),
		type: 'boolean',
		default: true,
		scope: ConfigurationScope.WINDOW,
	},
};
```

`browser/onyxBlocksEnablement.ts`:

```ts
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Onyx contributors. Licensed under the MIT License.
 *--------------------------------------------------------------------------------------------*/

export interface IEnablementInput {
	settingEnabled: boolean;
	hasCommandDetection: boolean;
	xtermOpened: boolean;
}

/** Blocks exist only with the setting on, shell integration detected, and xterm in the DOM. */
export function shouldEnableBlocks(input: IEnablementInput): boolean {
	return input.settingEnabled && input.hasCommandDetection && input.xtermOpened;
}
```

`browser/onyxBlocksContribution.ts` (shell only; later tasks fill `_enable` / `_disable`):

```ts
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Onyx contributors. Licensed under the MIT License.
 *--------------------------------------------------------------------------------------------*/

import type { Terminal as RawXtermTerminal } from '@xterm/xterm';
import type { IDimension } from '../../../../../base/browser/dom.js';
import { Event } from '../../../../../base/common/event.js';
import { Disposable, DisposableStore } from '../../../../../base/common/lifecycle.js';
import { IConfigurationService } from '../../../../../platform/configuration/common/configuration.js';
import { TerminalCapability } from '../../../../../platform/terminal/common/capabilities/capabilities.js';
import type { ITerminalContribution, ITerminalInstance, IXtermTerminal } from '../../../terminal/browser/terminal.js';
import type { ITerminalContributionContext } from '../../../terminal/browser/terminalExtensions.js';
import { OnyxBlocksSettingId } from '../common/onyxBlocksConfiguration.js';
import { shouldEnableBlocks } from './onyxBlocksEnablement.js';

export class OnyxBlocksContribution extends Disposable implements ITerminalContribution {
	static readonly ID = 'terminal.onyxBlocks';

	static get(instance: ITerminalInstance): OnyxBlocksContribution | null {
		return instance.getContribution<OnyxBlocksContribution>(OnyxBlocksContribution.ID);
	}

	private _xterm?: IXtermTerminal & { raw: RawXtermTerminal };
	private _xtermOpened = false;
	private _lastDimension?: IDimension;
	private readonly _enabledParts = this._register(new DisposableStore());
	private _isEnabled = false;

	constructor(
		private readonly _ctx: ITerminalContributionContext,
		@IConfigurationService private readonly _configurationService: IConfigurationService,
	) {
		super();
		this._register(Event.runAndSubscribe(this._configurationService.onDidChangeConfiguration, e => {
			if (!e || e.affectsConfiguration(OnyxBlocksSettingId.Enabled)) {
				this._refreshState();
			}
		}));
		this._register(this._ctx.instance.capabilities.onDidAddCapability(e => {
			if (e.id === TerminalCapability.CommandDetection) {
				this._refreshState();
			}
		}));
		this._register(this._ctx.instance.capabilities.onDidRemoveCapability(e => {
			if (e.id === TerminalCapability.CommandDetection) {
				this._refreshState();
			}
		}));
	}

	xtermReady(xterm: IXtermTerminal & { raw: RawXtermTerminal }): void {
		this._xterm = xterm;
		this._refreshState();
	}

	xtermOpen(xterm: IXtermTerminal & { raw: RawXtermTerminal }): void {
		this._xterm = xterm;
		this._xtermOpened = true;
		this._refreshState();
	}

	layout(_xterm: IXtermTerminal & { raw: RawXtermTerminal }, dimension: IDimension): void {
		this._lastDimension = dimension;
	}

	private _refreshState(): void {
		const wanted = shouldEnableBlocks({
			settingEnabled: this._configurationService.getValue<boolean>(OnyxBlocksSettingId.Enabled) === true,
			hasCommandDetection: this._ctx.instance.capabilities.has(TerminalCapability.CommandDetection),
			xtermOpened: this._xtermOpened && !!this._xterm?.raw.element,
		});
		if (wanted && !this._isEnabled) {
			this._enable();
		} else if (!wanted && this._isEnabled) {
			this._disable();
		}
	}

	private _enable(): void {
		this._isEnabled = true;
		// Filled in by later tasks: model, input, overlay.
	}

	private _disable(): void {
		this._isEnabled = false;
		this._enabledParts.clear();
	}
}
```

`browser/terminal.onyxBlocks.contribution.ts`:

```ts
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Onyx contributors. Licensed under the MIT License.
 *--------------------------------------------------------------------------------------------*/

import './media/onyxBlocks.css';
import { localize } from '../../../../../nls.js';
import { Extensions as ConfigurationExtensions, type IConfigurationRegistry } from '../../../../../platform/configuration/common/configurationRegistry.js';
import { Registry } from '../../../../../platform/registry/common/platform.js';
import { registerTerminalContribution } from '../../../terminal/browser/terminalExtensions.js';
import { onyxBlocksConfiguration } from '../common/onyxBlocksConfiguration.js';
import { OnyxBlocksContribution } from './onyxBlocksContribution.js';

// #region Configuration

Registry.as<IConfigurationRegistry>(ConfigurationExtensions.Configuration).registerConfiguration({
	id: 'onyx',
	order: 100,
	title: localize('onyxConfigurationTitle', "Onyx"),
	type: 'object',
	properties: onyxBlocksConfiguration,
});

// #endregion

// #region Terminal Contributions

registerTerminalContribution(OnyxBlocksContribution.ID, OnyxBlocksContribution);

// #endregion
```

`browser/media/onyxBlocks.css` (full file; later tasks only append):

```css
/* Onyx block terminal */

.monaco-workbench .terminal-wrapper.onyx-blocks {
	position: relative;
}

/* The input's height is reserved as xterm padding so rows shrink instead of being covered. */
.monaco-workbench .terminal-wrapper.onyx-blocks .xterm {
	padding-bottom: var(--onyx-block-input-height, 0px);
}
```

Add to `vscode/src/vs/workbench/contrib/terminal/terminal.all.ts`, directly after the `voice` import line:

```ts
import '../terminalContrib/onyxBlocks/browser/terminal.onyxBlocks.contribution.js';
```

- [ ] **Step 4: Compile, lint, run the test**

Run: `cd vscode && npm run compile && npx eslint src/vs/workbench/contrib/terminalContrib/onyxBlocks && ./scripts/test.sh --run src/vs/workbench/contrib/terminalContrib/onyxBlocks/test/browser/onyxBlocksEnablement.test.ts`
Expected: compile clean, eslint clean, 4 passing.

- [ ] **Step 5: Add the patch recipe and the patch test**

Append to `justfile`:

```make
# Regenerate the one core patch from the vscode/ working tree.
blocks-patch:
    cd vscode && git add -N src/vs/workbench/contrib/terminalContrib/onyxBlocks && git diff --no-color -- src/vs/workbench/contrib/terminalContrib/onyxBlocks src/vs/workbench/contrib/terminal/terminal.all.ts > ../patches/onyx-block-terminal.patch
```

Change the `test` recipe line to:

```make
    ./test/syntax.sh && ./test/brand.sh && ./test/product.sh && ./test/icons.sh && ./test/blocks.sh
```

`test/blocks.sh`:

```bash
#!/usr/bin/env bash
# The block terminal patch must exist, touch only its own directory plus the
# single import line, and match the prepared checkout when one is present.
set -euo pipefail
cd "$(dirname "$0")/.."

P=patches/onyx-block-terminal.patch
if [[ ! -s "$P" ]]; then
  echo "blocks.sh: $P missing or empty" >&2
  exit 1
fi

if grep '^+++ b/' "$P" \
  | grep -v '^+++ b/src/vs/workbench/contrib/terminalContrib/onyxBlocks/' \
  | grep -v '^+++ b/src/vs/workbench/contrib/terminal/terminal.all.ts$'; then
  echo "blocks.sh: patch touches files outside the allowed set" >&2
  exit 1
fi

if [[ "$(grep -c '^+import' "$P" | head -1)" -lt 1 ]]; then
  echo "blocks.sh: patch has no added import line" >&2
  exit 1
fi

if [[ -d vscode/.git ]]; then
  ( cd vscode && git apply --reverse --check --ignore-whitespace "../$P" )
fi

echo "blocks.sh ok"
```

Run: `chmod +x test/blocks.sh && just blocks-patch && just test`
Expected: patch written, all five test scripts print ok.

- [ ] **Step 6: Commit**

```bash
git add justfile test/blocks.sh patches/onyx-block-terminal.patch
git commit -m "Block terminal: scaffold contribution, setting, patch pipeline

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: Block model

**Files:**
- Create: `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/browser/onyxBlockModel.ts`
- Create: `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/test/browser/onyxBlockModel.test.ts`
- Modify: `patches/onyx-block-terminal.patch` (regenerated)

**Interfaces:**
- Consumes: upstream `ICommandDetectionCapability` (`commands`, `currentCommand`, `onCommandStarted`, `onCommandExecuted`, `onCommandFinished`, `onCommandInvalidated`, `onCurrentCommandInvalidated`), `ITerminalCommand` markers, `ICurrentPartialCommand`.
- Produces: `interface IBlock { id: number; command: ITerminalCommand | undefined; partial: ICurrentPartialCommand | undefined; commandLine: string; startLine: number | undefined; endLine: number | undefined; exitCode: number | undefined; isRunning: boolean }`; `class BlockModel { blocks; selectedId; selectedBlock; onDidChange; attach(capability); select(id | undefined); selectPrevious(); selectNext(); refresh() }`.

- [ ] **Step 1: Write the failing tests**

`test/browser/onyxBlockModel.test.ts`:

```ts
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Onyx contributors. Licensed under the MIT License.
 *--------------------------------------------------------------------------------------------*/

import { deepStrictEqual, strictEqual } from 'assert';
import type { IMarker } from '@xterm/xterm';
import { Emitter } from '../../../../../../base/common/event.js';
import { DisposableStore } from '../../../../../../base/common/lifecycle.js';
import { ensureNoDisposablesAreLeakedInTestSuite } from '../../../../../../base/test/common/utils.js';
import type { ICommandDetectionCapability, ICommandInvalidationRequest, ITerminalCommand } from '../../../../../../platform/terminal/common/capabilities/capabilities.js';
import type { ICurrentPartialCommand } from '../../../../../../platform/terminal/common/capabilities/commandDetection/terminalCommand.js';
import { BlockModel } from '../../browser/onyxBlockModel.js';

function marker(line: number): IMarker & { dispose(): void } {
	const onDispose = new Emitter<void>();
	const m = {
		id: line, line, isDisposed: false,
		onDispose: onDispose.event,
		dispose() { m.isDisposed = true; onDispose.fire(); onDispose.dispose(); },
	};
	return m as unknown as IMarker & { dispose(): void };
}

function command(text: string, start: number, end: number, exitCode: number | undefined = 0): ITerminalCommand {
	return {
		command: text, exitCode, promptStartMarker: marker(start), marker: marker(start + 1), endMarker: marker(end),
		getOutput: () => `${text} output`,
	} as unknown as ITerminalCommand;
}

class FakeCapability {
	readonly commands: ITerminalCommand[] = [];
	currentCommand: ICurrentPartialCommand | undefined;
	readonly onCommandStarted = new Emitter<ITerminalCommand>();
	readonly onCommandExecuted = new Emitter<ITerminalCommand>();
	readonly onCommandFinished = new Emitter<ITerminalCommand>();
	readonly onCommandInvalidated = new Emitter<ITerminalCommand[]>();
	readonly onCurrentCommandInvalidated = new Emitter<ICommandInvalidationRequest>();
	asCapability(): ICommandDetectionCapability {
		// Getters so the model always sees the fake's current state, not a snapshot.
		const self = this;
		return {
			get commands() { return self.commands; },
			get currentCommand() { return self.currentCommand; },
			onCommandStarted: this.onCommandStarted.event,
			onCommandExecuted: this.onCommandExecuted.event,
			onCommandFinished: this.onCommandFinished.event,
			onCommandInvalidated: this.onCommandInvalidated.event,
			onCurrentCommandInvalidated: this.onCurrentCommandInvalidated.event,
		} as unknown as ICommandDetectionCapability;
	}
	dispose() {
		this.onCommandStarted.dispose(); this.onCommandExecuted.dispose(); this.onCommandFinished.dispose();
		this.onCommandInvalidated.dispose(); this.onCurrentCommandInvalidated.dispose();
	}
}

suite('Onyx BlockModel', () => {
	const store = ensureNoDisposablesAreLeakedInTestSuite();
	let cap: FakeCapability;
	let model: BlockModel;

	setup(() => {
		cap = new FakeCapability();
		store.add({ dispose: () => cap.dispose() });
		model = store.add(new BlockModel());
	});

	test('replays existing commands on attach with marker ranges', () => {
		cap.commands.push(command('ls', 0, 3), command('pwd', 4, 5, 1));
		model.attach(cap.asCapability());
		deepStrictEqual(model.blocks.map(b => [b.commandLine, b.startLine, b.endLine, b.exitCode, b.isRunning]), [
			['ls', 0, 3, 0, false],
			['pwd', 4, 5, 1, false],
		]);
	});

	test('a running partial command is the last block with no end line', () => {
		cap.commands.push(command('ls', 0, 3));
		model.attach(cap.asCapability());
		cap.currentCommand = { promptStartMarker: marker(4), commandStartMarker: marker(5), command: 'sleep 5' } as unknown as ICurrentPartialCommand;
		cap.onCommandStarted.fire({ marker: marker(5) } as unknown as ITerminalCommand);
		const last = model.blocks[model.blocks.length - 1];
		strictEqual(last.commandLine, 'sleep 5');
		strictEqual(last.startLine, 4);
		strictEqual(last.endLine, undefined);
		strictEqual(last.isRunning, true);
	});

	test('finished command replaces the running block and keeps a stable id', () => {
		model.attach(cap.asCapability());
		cap.currentCommand = { promptStartMarker: marker(0), commandStartMarker: marker(1), command: 'ls' } as unknown as ICurrentPartialCommand;
		cap.onCommandStarted.fire({ marker: marker(1) } as unknown as ITerminalCommand);
		const runningId = model.blocks[0].id;
		const finished = command('ls', 0, 3);
		cap.commands.push(finished);
		cap.currentCommand = undefined;
		cap.onCommandFinished.fire(finished);
		strictEqual(model.blocks.length, 1);
		strictEqual(model.blocks[0].isRunning, false);
		strictEqual(model.blocks[0].id, runningId);
	});

	test('commands with no markers are skipped', () => {
		cap.commands.push({ command: 'ghost', exitCode: 0 } as unknown as ITerminalCommand, command('ls', 0, 1));
		model.attach(cap.asCapability());
		deepStrictEqual(model.blocks.map(b => b.commandLine), ['ls']);
	});

	test('disposing a block marker removes the block and clears a selection on it', () => {
		const c = command('ls', 0, 3);
		cap.commands.push(c);
		model.attach(cap.asCapability());
		model.select(model.blocks[0].id);
		(c.marker as IMarker & { dispose(): void }).dispose();
		(c.promptStartMarker as IMarker & { dispose(): void }).dispose();
		strictEqual(model.blocks.length, 0);
		strictEqual(model.selectedId, undefined);
	});

	test('invalidated commands are removed', () => {
		const a = command('a', 0, 1);
		const b = command('b', 2, 3);
		cap.commands.push(a, b);
		model.attach(cap.asCapability());
		cap.commands.splice(0, 1);
		cap.onCommandInvalidated.fire([a]);
		deepStrictEqual(model.blocks.map(x => x.commandLine), ['b']);
	});

	test('selection navigation walks newest to oldest and clamps', () => {
		cap.commands.push(command('a', 0, 1), command('b', 2, 3), command('c', 4, 5));
		model.attach(cap.asCapability());
		strictEqual(model.selectedId, undefined);
		model.selectPrevious();
		strictEqual(model.selectedBlock?.commandLine, 'c');
		model.selectPrevious();
		model.selectPrevious();
		model.selectPrevious();
		strictEqual(model.selectedBlock?.commandLine, 'a');
		model.selectNext();
		strictEqual(model.selectedBlock?.commandLine, 'b');
		model.selectNext();
		model.selectNext();
		strictEqual(model.selectedId, undefined, 'moving past the newest block clears the selection');
	});

	test('onDidChange fires once per attach and once per event', () => {
		let fired = 0;
		store.add(model.onDidChange(() => fired++));
		cap.commands.push(command('a', 0, 1));
		model.attach(cap.asCapability());
		strictEqual(fired, 1);
		cap.onCommandExecuted.fire(cap.commands[0]);
		strictEqual(fired, 2);
	});
});
```

- [ ] **Step 2: Run to see it fail**

Run: `cd vscode && npm run compile; ./scripts/test.sh --run src/vs/workbench/contrib/terminalContrib/onyxBlocks/test/browser/onyxBlockModel.test.ts`
Expected: compile error, `onyxBlockModel.js` missing.

- [ ] **Step 3: Implement the model**

`browser/onyxBlockModel.ts`:

```ts
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Onyx contributors. Licensed under the MIT License.
 *--------------------------------------------------------------------------------------------*/

import type { IMarker } from '@xterm/xterm';
import { Emitter } from '../../../../../base/common/event.js';
import { Disposable, DisposableStore } from '../../../../../base/common/lifecycle.js';
import type { ICommandDetectionCapability, ITerminalCommand } from '../../../../../platform/terminal/common/capabilities/capabilities.js';
import type { ICurrentPartialCommand } from '../../../../../platform/terminal/common/capabilities/commandDetection/terminalCommand.js';

export interface IBlock {
	readonly id: number;
	/** Set for finished commands. */
	readonly command: ITerminalCommand | undefined;
	/** Set for the running command. */
	readonly partial: ICurrentPartialCommand | undefined;
	readonly commandLine: string;
	/** Absolute buffer line of the prompt (or command start). Undefined once the marker is gone. */
	readonly startLine: number | undefined;
	/** Absolute buffer line of the command end. Undefined while running or once the marker is gone. */
	readonly endLine: number | undefined;
	readonly exitCode: number | undefined;
	readonly isRunning: boolean;
}

function liveLine(m: IMarker | undefined): number | undefined {
	return m && !m.isDisposed ? m.line : undefined;
}

class Block implements IBlock {
	constructor(
		readonly id: number,
		readonly command: ITerminalCommand | undefined,
		readonly partial: ICurrentPartialCommand | undefined,
	) { }
	get commandLine(): string { return this.command?.command ?? this.partial?.command ?? ''; }
	get startLine(): number | undefined {
		return liveLine(this.command?.promptStartMarker ?? this.partial?.promptStartMarker)
			?? liveLine(this.command?.marker ?? this.partial?.commandStartMarker);
	}
	get endLine(): number | undefined { return liveLine(this.command?.endMarker); }
	get exitCode(): number | undefined { return this.command?.exitCode; }
	get isRunning(): boolean { return this.command === undefined; }
	get startMarker(): IMarker | undefined {
		return this.command?.promptStartMarker ?? this.command?.marker ?? this.partial?.promptStartMarker ?? this.partial?.commandStartMarker;
	}
}

/**
 * Turns command detection into a list of blocks. The list is rebuilt from the capability on every
 * event; ids are kept stable per command object, and the running block keeps its id when the
 * command finishes. ponytail: O(n) rebuild per event, fine for a few thousand commands.
 */
export class BlockModel extends Disposable {
	private _capability: ICommandDetectionCapability | undefined;
	private _blocks: Block[] = [];
	private _selectedId: number | undefined;
	private _nextId = 1;
	private _runningId: number | undefined;
	private readonly _ids = new WeakMap<ITerminalCommand, number>();
	private readonly _listeners = this._register(new DisposableStore());
	private readonly _markerListeners = this._register(new DisposableStore());
	private readonly _onDidChange = this._register(new Emitter<void>());
	readonly onDidChange = this._onDidChange.event;

	get blocks(): readonly IBlock[] { return this._blocks; }
	get selectedId(): number | undefined { return this._selectedId; }
	get selectedBlock(): IBlock | undefined { return this._blocks.find(b => b.id === this._selectedId); }

	attach(capability: ICommandDetectionCapability): void {
		this._capability = capability;
		this._listeners.clear();
		this._listeners.add(capability.onCommandStarted(() => this.refresh()));
		this._listeners.add(capability.onCommandExecuted(() => this.refresh()));
		this._listeners.add(capability.onCommandFinished(() => this.refresh()));
		this._listeners.add(capability.onCommandInvalidated(() => this.refresh()));
		this._listeners.add(capability.onCurrentCommandInvalidated(() => this.refresh()));
		this.refresh();
	}

	refresh(): void {
		const cap = this._capability;
		if (!cap) {
			return;
		}
		const next: Block[] = [];
		for (const c of cap.commands) {
			let id = this._ids.get(c);
			if (id === undefined) {
				// A command that just finished inherits the running block's id.
				id = this._runningId ?? this._nextId++;
				this._runningId = undefined;
				this._ids.set(c, id);
			}
			const b = new Block(id, c, undefined);
			if (b.startLine !== undefined) {
				next.push(b);
			}
		}
		const partial = cap.currentCommand;
		if (partial && (partial.promptStartMarker || partial.commandStartMarker) && !partial.isInvalid && partial.command !== undefined) {
			if (this._runningId === undefined) {
				this._runningId = this._nextId++;
			}
			const b = new Block(this._runningId, undefined, partial);
			if (b.startLine !== undefined) {
				next.push(b);
			}
		} else {
			// No running command: a finished command above may already have taken the id.
			this._runningId = undefined;
		}
		this._blocks = next;
		this._watchMarkers();
		if (this._selectedId !== undefined && !this._blocks.some(b => b.id === this._selectedId)) {
			this._selectedId = undefined;
		}
		this._onDidChange.fire();
	}

	private _watchMarkers(): void {
		this._markerListeners.clear();
		for (const b of this._blocks) {
			const m = b.startMarker;
			if (m && !m.isDisposed) {
				this._markerListeners.add(m.onDispose(() => this.refresh()));
			}
		}
	}

	select(id: number | undefined): void {
		if (id !== undefined && !this._blocks.some(b => b.id === id)) {
			return;
		}
		if (this._selectedId !== id) {
			this._selectedId = id;
			this._onDidChange.fire();
		}
	}

	/** Older block (towards the top). From no selection, selects the newest block. */
	selectPrevious(): void {
		if (this._blocks.length === 0) {
			return;
		}
		const i = this._blocks.findIndex(b => b.id === this._selectedId);
		const target = i === -1 ? this._blocks.length - 1 : Math.max(0, i - 1);
		this.select(this._blocks[target].id);
	}

	/** Newer block (towards the input). Past the newest block the selection clears. */
	selectNext(): void {
		const i = this._blocks.findIndex(b => b.id === this._selectedId);
		if (i === -1) {
			return;
		}
		if (i + 1 >= this._blocks.length) {
			this.select(undefined);
		} else {
			this.select(this._blocks[i + 1].id);
		}
	}
}
```

- [ ] **Step 4: Compile, lint, test**

Run: `cd vscode && npm run compile && npx eslint src/vs/workbench/contrib/terminalContrib/onyxBlocks && ./scripts/test.sh --run src/vs/workbench/contrib/terminalContrib/onyxBlocks/test/browser/onyxBlockModel.test.ts`
Expected: 8 passing. If the marker test fails because a marker was created through `marker()` without a line for `endMarker`, check `liveLine`.

- [ ] **Step 5: Regenerate the patch and commit**

```bash
just blocks-patch && ./test/blocks.sh
git add patches/onyx-block-terminal.patch
git commit -m "Block terminal: block model from command detection

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: Input state and history (pure logic)

**Files:**
- Create: `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/browser/onyxInputState.ts`
- Create: `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/browser/onyxInputHistory.ts`
- Create: `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/test/browser/onyxInputState.test.ts`
- Create: `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/test/browser/onyxInputHistory.test.ts`
- Modify: `patches/onyx-block-terminal.patch` (regenerated)

**Interfaces:**
- Produces: `enum InputState { Prompt, Executing, AltBuffer }`; `deriveInputState({ altBufferActive, commandExecuting }): InputState`; `type SendPath = { kind: 'runCommand'; text: string; bracketed: boolean } | { kind: 'sendText'; text: string } | { kind: 'none' }`; `sendPathFor(state, rawText): SendPath`; `class InputHistory { constructor(cap = 500); load(session: readonly string[], persisted: readonly string[]); push(cmd); previous(current): string | undefined; next(): string | undefined; reset(); readonly entries: readonly string[] }`; `HistoryCap = 500`.

- [ ] **Step 1: Write the failing tests**

`test/browser/onyxInputState.test.ts`:

```ts
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Onyx contributors. Licensed under the MIT License.
 *--------------------------------------------------------------------------------------------*/

import { deepStrictEqual, strictEqual } from 'assert';
import { ensureNoDisposablesAreLeakedInTestSuite } from '../../../../../../base/test/common/utils.js';
import { deriveInputState, InputState, sendPathFor } from '../../browser/onyxInputState.js';

suite('Onyx input state', () => {
	ensureNoDisposablesAreLeakedInTestSuite();

	test('alt buffer wins over everything', () => {
		strictEqual(deriveInputState({ altBufferActive: true, commandExecuting: true }), InputState.AltBuffer);
		strictEqual(deriveInputState({ altBufferActive: true, commandExecuting: false }), InputState.AltBuffer);
	});

	test('executing when a command is running', () => {
		strictEqual(deriveInputState({ altBufferActive: false, commandExecuting: true }), InputState.Executing);
	});

	test('prompt otherwise', () => {
		strictEqual(deriveInputState({ altBufferActive: false, commandExecuting: false }), InputState.Prompt);
	});

	test('prompt: single line runs as a command, not bracketed', () => {
		deepStrictEqual(sendPathFor(InputState.Prompt, 'ls -la'), { kind: 'runCommand', text: 'ls -la', bracketed: false });
	});

	test('prompt: multi-line runs as one bracketed command', () => {
		deepStrictEqual(sendPathFor(InputState.Prompt, 'cat <<EOF\nhi\nEOF'), { kind: 'runCommand', text: 'cat <<EOF\nhi\nEOF', bracketed: true });
	});

	test('prompt: trailing whitespace and newlines are trimmed', () => {
		deepStrictEqual(sendPathFor(InputState.Prompt, 'ls  \n\n'), { kind: 'runCommand', text: 'ls', bracketed: false });
	});

	test('empty or whitespace input sends nothing in any state', () => {
		deepStrictEqual(sendPathFor(InputState.Prompt, '   \n'), { kind: 'none' });
		deepStrictEqual(sendPathFor(InputState.Executing, ''), { kind: 'none' });
	});

	test('executing: text is forwarded raw to the program', () => {
		deepStrictEqual(sendPathFor(InputState.Executing, 'yes'), { kind: 'sendText', text: 'yes' });
	});

	test('alt buffer: never sends', () => {
		deepStrictEqual(sendPathFor(InputState.AltBuffer, ':q'), { kind: 'none' });
	});
});
```

`test/browser/onyxInputHistory.test.ts`:

```ts
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Onyx contributors. Licensed under the MIT License.
 *--------------------------------------------------------------------------------------------*/

import { deepStrictEqual, strictEqual } from 'assert';
import { ensureNoDisposablesAreLeakedInTestSuite } from '../../../../../../base/test/common/utils.js';
import { InputHistory } from '../../browser/onyxInputHistory.js';

suite('Onyx input history', () => {
	ensureNoDisposablesAreLeakedInTestSuite();

	test('session commands come first, newest first, then persisted', () => {
		const h = new InputHistory();
		h.load(['git status', 'ls'], ['make', 'ls', 'pwd']);
		deepStrictEqual(h.entries, ['ls', 'git status', 'make', 'pwd']);
	});

	test('duplicates keep the first occurrence; blank entries are dropped', () => {
		const h = new InputHistory();
		h.load(['ls', '  ', 'ls'], ['', 'ls', 'pwd']);
		deepStrictEqual(h.entries, ['ls', 'pwd']);
	});

	test('cap applies', () => {
		const h = new InputHistory(3);
		h.load(['a', 'b', 'c', 'd'], ['e']);
		deepStrictEqual(h.entries, ['d', 'c', 'b']);
	});

	test('previous walks older, next walks newer and restores the draft', () => {
		const h = new InputHistory();
		h.load(['first', 'second'], []);
		strictEqual(h.previous('draft'), 'second');
		strictEqual(h.previous('second'), 'first');
		strictEqual(h.previous('first'), undefined, 'at the oldest entry previous returns undefined');
		strictEqual(h.next(), 'second');
		strictEqual(h.next(), 'draft');
		strictEqual(h.next(), undefined, 'past the draft next returns undefined');
	});

	test('push adds to the front and resets the cursor', () => {
		const h = new InputHistory();
		h.load(['a'], []);
		h.previous('');
		h.push('b');
		deepStrictEqual(h.entries, ['b', 'a']);
		strictEqual(h.previous('x'), 'b');
	});

	test('push ignores blanks and moves an existing entry to the front', () => {
		const h = new InputHistory();
		h.load(['a', 'b'], []);
		h.push('   ');
		h.push('a');
		deepStrictEqual(h.entries, ['a', 'b']);
	});

	test('reset returns to the live draft', () => {
		const h = new InputHistory();
		h.load(['a'], []);
		h.previous('draft');
		h.reset();
		strictEqual(h.previous('new draft'), 'a');
		strictEqual(h.next(), 'new draft');
	});
});
```

- [ ] **Step 2: Run to see them fail**

Run: `cd vscode && npm run compile; ./scripts/test.sh --glob '**/onyxInput*.test.js'`
Expected: compile errors for the two missing modules.

- [ ] **Step 3: Implement**

`browser/onyxInputState.ts`:

```ts
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Onyx contributors. Licensed under the MIT License.
 *--------------------------------------------------------------------------------------------*/

export const enum InputState {
	/** Shell is at a prompt: Enter runs the text as one command. */
	Prompt = 'prompt',
	/** A foreground command is running: Enter forwards the text to it. */
	Executing = 'executing',
	/** A full-screen program owns the terminal: the input is hidden. */
	AltBuffer = 'altBuffer',
}

export interface IInputSignals {
	altBufferActive: boolean;
	commandExecuting: boolean;
}

export function deriveInputState(s: IInputSignals): InputState {
	if (s.altBufferActive) {
		return InputState.AltBuffer;
	}
	if (s.commandExecuting) {
		return InputState.Executing;
	}
	return InputState.Prompt;
}

export type SendPath =
	| { kind: 'runCommand'; text: string; bracketed: boolean }
	| { kind: 'sendText'; text: string }
	| { kind: 'none' };

export function sendPathFor(state: InputState, rawText: string): SendPath {
	const text = rawText.replace(/\s+$/, '');
	if (text.length === 0) {
		return { kind: 'none' };
	}
	switch (state) {
		case InputState.Prompt:
			return { kind: 'runCommand', text, bracketed: text.includes('\n') };
		case InputState.Executing:
			return { kind: 'sendText', text };
		default:
			return { kind: 'none' };
	}
}
```

`browser/onyxInputHistory.ts`:

```ts
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Onyx contributors. Licensed under the MIT License.
 *--------------------------------------------------------------------------------------------*/

export const HistoryCap = 500;

/**
 * Up/Down history for the block input. Index 0 is the newest entry. The cursor is -1 while the
 * user is on their live draft.
 */
export class InputHistory {
	private _entries: string[] = [];
	private _cursor = -1;
	private _draft = '';

	constructor(private readonly _cap: number = HistoryCap) { }

	get entries(): readonly string[] { return this._entries; }

	/** @param session commands from this terminal, oldest first. @param persisted older commands, newest first. */
	load(session: readonly string[], persisted: readonly string[]): void {
		const seen = new Set<string>();
		const out: string[] = [];
		for (const raw of [...[...session].reverse(), ...persisted]) {
			const cmd = raw.trim();
			if (cmd.length === 0 || seen.has(cmd)) {
				continue;
			}
			seen.add(cmd);
			out.push(cmd);
			if (out.length >= this._cap) {
				break;
			}
		}
		this._entries = out;
		this.reset();
	}

	push(raw: string): void {
		const cmd = raw.trim();
		if (cmd.length === 0) {
			return;
		}
		this._entries = [cmd, ...this._entries.filter(e => e !== cmd)].slice(0, this._cap);
		this.reset();
	}

	previous(current: string): string | undefined {
		if (this._cursor + 1 >= this._entries.length) {
			return undefined;
		}
		if (this._cursor === -1) {
			this._draft = current;
		}
		this._cursor++;
		return this._entries[this._cursor];
	}

	next(): string | undefined {
		if (this._cursor === -1) {
			return undefined;
		}
		this._cursor--;
		return this._cursor === -1 ? this._draft : this._entries[this._cursor];
	}

	reset(): void {
		this._cursor = -1;
		this._draft = '';
	}
}
```

- [ ] **Step 4: Compile, lint, test**

Run: `cd vscode && npm run compile && npx eslint src/vs/workbench/contrib/terminalContrib/onyxBlocks && ./scripts/test.sh --glob '**/onyxInput*.test.js'`
Expected: 16 passing.

- [ ] **Step 5: Regenerate the patch and commit**

```bash
just blocks-patch && ./test/blocks.sh
git add patches/onyx-block-terminal.patch
git commit -m "Block terminal: input state machine and history

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: Bottom input widget and contribution wiring

**Files:**
- Create: `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/browser/onyxBlockInput.ts`
- Modify: `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/browser/onyxBlocksContribution.ts` (fill `_enable`, `_disable`, `layout`, add state, run, focus redirect)
- Modify: `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/browser/media/onyxBlocks.css` (append input styles)
- Modify: `patches/onyx-block-terminal.patch` (regenerated)

**Interfaces:**
- Consumes: `BlockModel` (Task 2), `InputHistory`, `deriveInputState`, `sendPathFor`, `InputState` (Task 3), upstream `CodeEditorWidget`, `getSimpleEditorOptions`, `getSimpleCodeEditorWidgetOptions`, `IModelService`, `ILanguageService`, `ITerminalInstance.runCommand/sendText/getCwdResource`, `ICwdDetectionCapability`, `ICommandDetectionCapability.executingCommand`, `promptInputModel.state`.
- Produces: `interface IOnyxBlockController { run(text: string): void; interrupt(): void; clearTerminal(): void; selectBlock(direction: 'previous' | 'next' | 'clear'): void; copyTerminalSelection(): void; focusFind(): void; readonly model: BlockModel }`; `class OnyxBlockInput { static readonly SCHEME = 'onyx-block-input'; static getFocused(codeEditorService): OnyxBlockInput | undefined; readonly editor: ICodeEditor; readonly controller: IOnyxBlockController; readonly history: InputHistory; value; setValue(text); clear(); focus(); setVisible(visible); setHeader(cwd); layout(width); onDidChangeHeight: Event<number>; height }`; context key `OnyxBlocksContextKeys.inputFocused`.

- [ ] **Step 1: Write the input widget**

`browser/onyxBlockInput.ts`:

```ts
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Onyx contributors. Licensed under the MIT License.
 *--------------------------------------------------------------------------------------------*/

import * as dom from '../../../../../base/browser/dom.js';
import { Emitter, Event } from '../../../../../base/common/event.js';
import { Disposable } from '../../../../../base/common/lifecycle.js';
import { URI } from '../../../../../base/common/uri.js';
import type { ICodeEditor } from '../../../../../editor/browser/editorBrowser.js';
import { ICodeEditorService } from '../../../../../editor/browser/services/codeEditorService.js';
import { CodeEditorWidget } from '../../../../../editor/browser/widget/codeEditor/codeEditorWidget.js';
import type { ITextModel } from '../../../../../editor/common/model.js';
import { ILanguageService } from '../../../../../editor/common/languages/language.js';
import { IModelService } from '../../../../../editor/common/services/model.js';
import { IConfigurationService } from '../../../../../platform/configuration/common/configuration.js';
import { IContextKeyService, RawContextKey, type IContextKey } from '../../../../../platform/contextkey/common/contextkey.js';
import { IInstantiationService } from '../../../../../platform/instantiation/common/instantiation.js';
import { ServiceCollection } from '../../../../../platform/instantiation/common/serviceCollection.js';
import type { ITerminalFont } from '../../../../../platform/terminal/common/terminal.js';
import { GeneralShellType, type TerminalShellType } from '../../../../../platform/terminal/common/terminal.js';
import { getSimpleCodeEditorWidgetOptions, getSimpleEditorOptions } from '../../../codeEditor/browser/simpleEditorOptions.js';
import type { BlockModel } from './onyxBlockModel.js';
import { InputHistory } from './onyxInputHistory.js';

export const MaxInputLines = 8;
const HeaderHeight = 18;

export namespace OnyxBlocksContextKeys {
	export const inputFocused = new RawContextKey<boolean>('onyxBlocks.inputFocused', false, 'Whether the Onyx block terminal input is focused.');
}

export interface IOnyxBlockController {
	readonly model: BlockModel;
	run(text: string): void;
	interrupt(): void;
	clearTerminal(): void;
	selectBlock(direction: 'previous' | 'next' | 'clear'): void;
	copyTerminalSelection(): void;
	focusFind(): void;
}

const inputsByEditor = new Map<ICodeEditor, OnyxBlockInput>();
let nextInputId = 1;

export class OnyxBlockInput extends Disposable {
	static readonly SCHEME = 'onyx-block-input';

	static getFocused(codeEditorService: ICodeEditorService): OnyxBlockInput | undefined {
		const editor = codeEditorService.getFocusedCodeEditor();
		return editor ? inputsByEditor.get(editor) : undefined;
	}

	readonly domNode: HTMLElement;
	readonly editor: CodeEditorWidget;
	readonly history = new InputHistory();
	/** The input model's URI; the completion provider answers only for this model. */
	readonly uri: URI;

	private readonly _header: HTMLElement;
	private readonly _editorHost: HTMLElement;
	private readonly _model: ITextModel;
	private readonly _focusedKey: IContextKey<boolean>;
	private _lineHeight: number;
	private _width = 0;
	private _height = 0;
	private _visible = true;

	private readonly _onDidChangeHeight = this._register(new Emitter<number>());
	readonly onDidChangeHeight: Event<number> = this._onDidChangeHeight.event;

	get height(): number { return this._visible ? this._height : 0; }
	get value(): string { return this._model.getValue(); }

	constructor(
		parent: HTMLElement,
		font: ITerminalFont,
		shellType: TerminalShellType | undefined,
		readonly controller: IOnyxBlockController,
		@IInstantiationService instantiationService: IInstantiationService,
		@IContextKeyService contextKeyService: IContextKeyService,
		@IModelService modelService: IModelService,
		@ILanguageService languageService: ILanguageService,
		@IConfigurationService configurationService: IConfigurationService,
	) {
		super();
		this.domNode = dom.append(parent, dom.$('.onyx-block-input'));
		this._header = dom.append(this.domNode, dom.$('.onyx-block-input-header'));
		const row = dom.append(this.domNode, dom.$('.onyx-block-input-row'));
		const glyph = dom.append(row, dom.$('.onyx-block-input-prompt'));
		glyph.textContent = '❯';
		this._editorHost = dom.append(row, dom.$('.onyx-block-input-editor'));

		this._lineHeight = Math.max(font.charHeight ?? Math.round(font.fontSize * font.lineHeight), 12);
		const fontFamily = font.fontFamily;
		glyph.style.fontFamily = fontFamily;
		glyph.style.fontSize = `${font.fontSize}px`;
		glyph.style.lineHeight = `${this._lineHeight}px`;
		this._header.style.fontFamily = fontFamily;

		const languageId = shellType === GeneralShellType.PowerShell ? 'powershell' : 'shellscript';
		this.uri = URI.from({ scheme: OnyxBlockInput.SCHEME, path: `/input-${nextInputId++}` });
		this._model = this._register(modelService.createModel('', languageService.createById(languageId), this.uri));

		const scopedContextKeyService = this._register(contextKeyService.createScoped(this.domNode));
		this._focusedKey = OnyxBlocksContextKeys.inputFocused.bindTo(scopedContextKeyService);
		const scopedInstantiation = this._register(instantiationService.createChild(new ServiceCollection([IContextKeyService, scopedContextKeyService])));

		this.editor = this._register(scopedInstantiation.createInstance(CodeEditorWidget, this._editorHost, {
			...getSimpleEditorOptions(configurationService),
			fontFamily,
			fontSize: font.fontSize,
			lineHeight: this._lineHeight,
			wordWrap: 'on',
			quickSuggestions: false,
			suggestOnTriggerCharacters: false,
			padding: { top: 0, bottom: 0 },
			ariaLabel: 'Onyx terminal input',
		}, getSimpleCodeEditorWidgetOptions()));
		this.editor.setModel(this._model);
		inputsByEditor.set(this.editor, this);
		this._register({ dispose: () => inputsByEditor.delete(this.editor) });

		this._register(this.editor.onDidFocusEditorText(() => this._focusedKey.set(true)));
		this._register(this.editor.onDidBlurEditorText(() => this._focusedKey.set(false)));
		this._register(this.editor.onDidChangeModelContent(e => {
			if (!e.isFlush) {
				this.history.reset();
			}
			this._relayout();
		}));
		this._relayout();
	}

	setHeader(text: string): void {
		this._header.textContent = text;
		this._header.title = text;
	}

	setValue(text: string): void {
		this._model.setValue(text);
		const last = this._model.getLineCount();
		this.editor.setPosition({ lineNumber: last, column: this._model.getLineMaxColumn(last) });
	}

	clear(): void {
		this.setValue('');
	}

	focus(): void {
		this.editor.focus();
	}

	setVisible(visible: boolean): void {
		if (this._visible === visible) {
			return;
		}
		this._visible = visible;
		this.domNode.style.display = visible ? '' : 'none';
		this._onDidChangeHeight.fire(this.height);
	}

	layout(width: number): void {
		this._width = width;
		this._relayout();
	}

	/** True when the cursor sits on the first line (for Up history). */
	cursorOnFirstLine(): boolean {
		return (this.editor.getPosition()?.lineNumber ?? 1) === 1;
	}

	/** True when the cursor sits on the last line (for Down history). */
	cursorOnLastLine(): boolean {
		return (this.editor.getPosition()?.lineNumber ?? 1) === this._model.getLineCount();
	}

	private _relayout(): void {
		const lines = Math.min(Math.max(this._model.getLineCount(), 1), MaxInputLines);
		const editorHeight = lines * this._lineHeight;
		const editorWidth = Math.max(this._width - this._editorHost.offsetLeft, 0);
		this.editor.layout({ width: editorWidth, height: editorHeight });
		const total = HeaderHeight + editorHeight + 1 /* top border */;
		if (total !== this._height) {
			this._height = total;
			this._onDidChangeHeight.fire(this.height);
		}
	}
}
```

- [ ] **Step 2: Fill in the contribution**

Replace the body of `browser/onyxBlocksContribution.ts` with this (keep the header comment):

```ts
import type { Terminal as RawXtermTerminal } from '@xterm/xterm';
import type { IDimension } from '../../../../../base/browser/dom.js';
import { Event } from '../../../../../base/common/event.js';
import { Disposable, DisposableStore, MutableDisposable } from '../../../../../base/common/lifecycle.js';
import { IClipboardService } from '../../../../../platform/clipboard/common/clipboardService.js';
import { CommandsRegistry, ICommandService } from '../../../../../platform/commands/common/commands.js';
import { IConfigurationService } from '../../../../../platform/configuration/common/configuration.js';
import { IInstantiationService } from '../../../../../platform/instantiation/common/instantiation.js';
import { INotificationService } from '../../../../../platform/notification/common/notification.js';
import { TerminalCapability, type ICommandDetectionCapability } from '../../../../../platform/terminal/common/capabilities/capabilities.js';
import { localize } from '../../../../../nls.js';
import type { ITerminalContribution, ITerminalInstance, IXtermTerminal } from '../../../terminal/browser/terminal.js';
import type { ITerminalContributionContext } from '../../../terminal/browser/terminalExtensions.js';
import { getCommandHistory } from '../../history/common/history.js';
import { OnyxBlocksSettingId } from '../common/onyxBlocksConfiguration.js';
import { OnyxBlockInput, type IOnyxBlockController } from './onyxBlockInput.js';
import { BlockModel, type IBlock } from './onyxBlockModel.js';
import { shouldEnableBlocks } from './onyxBlocksEnablement.js';
import { deriveInputState, InputState, sendPathFor } from './onyxInputState.js';

export const AgentSendBlockCommandId = 'onyx.agent.sendBlock';

export class OnyxBlocksContribution extends Disposable implements ITerminalContribution, IOnyxBlockController {
	static readonly ID = 'terminal.onyxBlocks';

	static get(instance: ITerminalInstance): OnyxBlocksContribution | null {
		return instance.getContribution<OnyxBlocksContribution>(OnyxBlocksContribution.ID);
	}

	readonly model = this._register(new BlockModel());

	private _xterm?: IXtermTerminal & { raw: RawXtermTerminal };
	private _xtermOpened = false;
	private _lastDimension?: IDimension;
	private _isEnabled = false;
	private _state = InputState.Prompt;
	private _relayoutQueued = false;
	private readonly _enabledParts = this._register(new DisposableStore());
	private readonly _input = this._register(new MutableDisposable<OnyxBlockInput>());

	constructor(
		private readonly _ctx: ITerminalContributionContext,
		@IConfigurationService private readonly _configurationService: IConfigurationService,
		@IInstantiationService private readonly _instantiationService: IInstantiationService,
		@IClipboardService private readonly _clipboardService: IClipboardService,
		@ICommandService private readonly _commandService: ICommandService,
		@INotificationService private readonly _notificationService: INotificationService,
	) {
		super();
		this._register(Event.runAndSubscribe(this._configurationService.onDidChangeConfiguration, e => {
			if (!e || e.affectsConfiguration(OnyxBlocksSettingId.Enabled)) {
				this._refreshState();
			}
		}));
		this._register(this._ctx.instance.capabilities.onDidAddCapability(e => {
			if (e.id === TerminalCapability.CommandDetection) {
				this._refreshState();
			}
		}));
		this._register(this._ctx.instance.capabilities.onDidRemoveCapability(e => {
			if (e.id === TerminalCapability.CommandDetection) {
				this._refreshState();
			}
		}));
	}

	get input(): OnyxBlockInput | undefined { return this._input.value; }
	get state(): InputState { return this._state; }

	xtermReady(xterm: IXtermTerminal & { raw: RawXtermTerminal }): void {
		this._xterm = xterm;
		this._refreshState();
	}

	xtermOpen(xterm: IXtermTerminal & { raw: RawXtermTerminal }): void {
		this._xterm = xterm;
		this._xtermOpened = true;
		this._refreshState();
	}

	layout(_xterm: IXtermTerminal & { raw: RawXtermTerminal }, dimension: IDimension): void {
		this._lastDimension = dimension;
		this._input.value?.layout(dimension.width);
	}

	// #region enable / disable

	private _refreshState(): void {
		const wanted = shouldEnableBlocks({
			settingEnabled: this._configurationService.getValue<boolean>(OnyxBlocksSettingId.Enabled) === true,
			hasCommandDetection: this._ctx.instance.capabilities.has(TerminalCapability.CommandDetection),
			xtermOpened: this._xtermOpened && !!this._xterm?.raw.element,
		});
		if (wanted && !this._isEnabled) {
			this._enable();
		} else if (!wanted && this._isEnabled) {
			this._disable();
		}
	}

	private _enable(): void {
		const xterm = this._xterm;
		const capability = this._ctx.instance.capabilities.get(TerminalCapability.CommandDetection);
		const wrapper = this._ctx.instance.domElement;
		if (!xterm?.raw.element || !capability || !wrapper) {
			return;
		}
		this._isEnabled = true;
		wrapper.classList.add('onyx-blocks');

		this.model.attach(capability);

		const input = this._instantiationService.createInstance(OnyxBlockInput, wrapper, xterm.getFont(), this._ctx.instance.shellType, this);
		this._input.value = input;
		this._enabledParts.add(input.onDidChangeHeight(h => this._applyInputHeight(h)));
		this._applyInputHeight(input.height);
		if (this._lastDimension) {
			input.layout(this._lastDimension.width);
		}

		// History: this session's commands first, then the persisted per-shell history.
		this._loadHistory(input, capability);
		this._enabledParts.add(capability.onCommandFinished(c => { if (c.command) { input.history.push(c.command); } }));

		// Working directory header.
		this._updateHeader(input, capability);
		const cwdCap = this._ctx.instance.capabilities.get(TerminalCapability.CwdDetection);
		if (cwdCap) {
			this._enabledParts.add(cwdCap.onDidChangeCwd(() => this._updateHeader(input, capability)));
		}
		this._enabledParts.add(capability.onCommandFinished(() => this._updateHeader(input, capability)));

		// State: prompt / executing / alt buffer.
		const update = () => this._updateInputState(capability);
		this._enabledParts.add(capability.onCommandStarted(update));
		this._enabledParts.add(capability.onCommandExecuted(update));
		this._enabledParts.add(capability.onCommandFinished(update));
		this._enabledParts.add(capability.onCurrentCommandInvalidated(update));
		this._enabledParts.add(capability.promptInputModel.onDidChangeInput(update));
		this._enabledParts.add(xterm.raw.buffer.onBufferChange(update));
		update();

		// Typing anywhere in the terminal lands in the input unless a full-screen program owns it.
		const textarea = xterm.raw.textarea;
		if (textarea) {
			const onFocus = () => {
				if (this._state !== InputState.AltBuffer) {
					input.focus();
				}
			};
			textarea.addEventListener('focus', onFocus);
			this._enabledParts.add({ dispose: () => textarea.removeEventListener('focus', onFocus) });
		}
		this._enabledParts.add(this._ctx.instance.onDidFocus(() => {
			if (this._state !== InputState.AltBuffer) {
				input.focus();
			}
		}));
		if (this._ctx.instance.hasFocus) {
			input.focus();
		}
	}

	private _disable(): void {
		this._isEnabled = false;
		this._enabledParts.clear();
		this._input.clear();
		const wrapper = this._ctx.instance.domElement;
		if (wrapper) {
			wrapper.classList.remove('onyx-blocks');
			wrapper.style.removeProperty('--onyx-block-input-height');
		}
		this._relayoutTerminal();
	}

	// #endregion

	// #region layout

	private _applyInputHeight(height: number): void {
		const wrapper = this._ctx.instance.domElement;
		if (!wrapper) {
			return;
		}
		wrapper.style.setProperty('--onyx-block-input-height', `${height}px`);
		this._relayoutTerminal();
	}

	/** Re-run the instance layout so xterm picks up the new padding. Guarded against re-entry. */
	private _relayoutTerminal(): void {
		if (!this._lastDimension || this._relayoutQueued) {
			return;
		}
		this._relayoutQueued = true;
		queueMicrotask(() => {
			this._relayoutQueued = false;
			if (this._lastDimension) {
				this._ctx.instance.layout(this._lastDimension);
			}
		});
	}

	// #endregion

	// #region state

	private _updateInputState(capability: ICommandDetectionCapability): void {
		const xterm = this._xterm;
		const input = this._input.value;
		if (!xterm || !input) {
			return;
		}
		const next = deriveInputState({
			altBufferActive: xterm.raw.buffer.active.type === 'alternate',
			commandExecuting: capability.executingCommand !== undefined,
		});
		if (next === this._state) {
			return;
		}
		const wasAlt = this._state === InputState.AltBuffer;
		this._state = next;
		input.setVisible(next !== InputState.AltBuffer);
		if (next === InputState.AltBuffer) {
			xterm.raw.focus();
		} else if (wasAlt && this._ctx.instance.hasFocus) {
			input.focus();
		}
	}

	private _updateHeader(input: OnyxBlockInput, capability: ICommandDetectionCapability): void {
		const cwdCap = this._ctx.instance.capabilities.get(TerminalCapability.CwdDetection);
		input.setHeader(cwdCap?.getCwd() || capability.cwd || this._ctx.instance.initialCwd || '');
	}

	private _loadHistory(input: OnyxBlockInput, capability: ICommandDetectionCapability): void {
		const session = capability.commands.map(c => c.command).filter(c => c.length > 0);
		const persisted: string[] = [];
		const shellType = this._ctx.instance.shellType;
		this._instantiationService.invokeFunction(accessor => {
			for (const [cmd, info] of getCommandHistory(accessor).entries) {
				if (info.shellType === shellType) {
					persisted.push(cmd);
				}
			}
		});
		input.history.load(session, persisted.reverse());
	}

	// #endregion

	// #region IOnyxBlockController

	run(text: string): void {
		const input = this._input.value;
		const path = sendPathFor(this._state, text);
		switch (path.kind) {
			case 'runCommand':
				void this._ctx.instance.runCommand(path.text, true, undefined, path.bracketed);
				input?.history.push(path.text);
				input?.clear();
				break;
			case 'sendText':
				void this._ctx.instance.sendText(path.text, true);
				input?.clear();
				break;
			case 'none':
				break;
		}
	}

	interrupt(): void {
		if (this._state === InputState.Executing) {
			void this._ctx.instance.sendText('\x03', false);
		} else {
			this._input.value?.clear();
		}
	}

	clearTerminal(): void {
		void this._commandService.executeCommand('workbench.action.terminal.clear');
	}

	selectBlock(direction: 'previous' | 'next' | 'clear'): void {
		switch (direction) {
			case 'previous': this.model.selectPrevious(); break;
			case 'next': this.model.selectNext(); break;
			case 'clear': this.model.select(undefined); break;
		}
	}

	copyTerminalSelection(): void {
		this._ctx.instance.copySelection();
	}

	focusFind(): void {
		void this._commandService.executeCommand('workbench.action.terminal.focusFind');
	}

	// #endregion

	// #region block actions (used by the overlay in Task 6)

	copyCommand(block: IBlock): void {
		void this._clipboardService.writeText(block.commandLine);
	}

	copyOutput(block: IBlock): void {
		void this._clipboardService.writeText(block.command?.getOutput() ?? '');
	}

	rerun(block: IBlock): void {
		const input = this._input.value;
		if (this._state === InputState.Prompt) {
			this.run(block.commandLine);
		} else {
			input?.setValue(block.commandLine);
			input?.focus();
		}
	}

	sendToAgent(block: IBlock): void {
		if (!CommandsRegistry.getCommand(AgentSendBlockCommandId)) {
			this._notificationService.info(localize('onyx.blocks.noAgent', "Agent API not installed yet"));
			return;
		}
		void this._commandService.executeCommand(AgentSendBlockCommandId, {
			command: block.commandLine,
			output: block.command?.getOutput() ?? '',
			exitCode: block.exitCode,
			cwd: block.command?.cwd,
			shellType: this._ctx.instance.shellType,
		});
	}

	// #endregion
}
```

Implementer notes:
- `ITerminalInstance.onDidFocus`, `domElement`, `shellType`, `copySelection`, `runCommand`, `sendText`, `layout` exist on the interface in `terminal/browser/terminal.ts`. Check `hasFocus` and `initialCwd` with grep before use; if either is missing, replace `hasFocus` with `dom.isAncestorOfActiveElement(wrapper)` and drop the `initialCwd` fallback.
- `xterm.getFont()` returns `ITerminalFont` with `charHeight` once xterm is open.
- `xterm.raw.buffer.onBufferChange` is xterm's event; `buffer.active.type` is `'normal' | 'alternate'`.

- [ ] **Step 3: Append the input CSS**

Append to `browser/media/onyxBlocks.css`:

```css
.monaco-workbench .terminal-wrapper.onyx-blocks .onyx-block-input {
	position: absolute;
	left: 0;
	right: 0;
	bottom: 0;
	z-index: 33;
	box-sizing: border-box;
	background: #000;
	border-top: 1px solid #1a1a1a;
	display: flex;
	flex-direction: column;
}

.onyx-block-input-header {
	height: 18px;
	line-height: 18px;
	padding: 0 8px;
	font-size: 11px;
	color: #8e8e8e;
	white-space: nowrap;
	overflow: hidden;
	text-overflow: ellipsis;
}

.onyx-block-input-row {
	display: flex;
	align-items: flex-start;
}

.onyx-block-input-prompt {
	color: #00c2ff;
	padding: 0 6px 0 8px;
	user-select: none;
}

.onyx-block-input-editor {
	flex: 1;
	min-width: 0;
}

.onyx-block-input .monaco-editor,
.onyx-block-input .monaco-editor .monaco-editor-background,
.onyx-block-input .monaco-editor .margin {
	background-color: #000 !important;
}
```

- [ ] **Step 4: Compile, lint, run all contrib tests**

Run: `cd vscode && npm run compile && npx eslint src/vs/workbench/contrib/terminalContrib/onyxBlocks && ./scripts/test.sh --glob '**/onyxBlocks/**/*.test.js'`
Expected: clean compile, eslint clean, 28 passing (4 + 8 + 16).

- [ ] **Step 5: Manual check in the dev build**

Run: `just dev` (from the Onyx repo root; takes a few minutes on first run). Open a terminal (Terminal, New Terminal). Check:
- A black input with a cyan `❯` sits at the bottom with the cwd in a small grey header line; the xterm area ends above it (no overlap).
- Clicking the output area then typing puts the characters in the input, not in xterm.
- Typing in the input and pressing Enter does nothing yet (no keybinding until Task 5); typing a newline is not possible yet either. That is expected.
- Run `vim` from the shell by typing `vim` into xterm directly: the input hides. `:q` brings it back.
- `onyx.terminal.blocks.enabled: false` in settings, open a new terminal: stock terminal.
Record what you saw in the task report. Quit with Cmd+Q.

- [ ] **Step 6: Regenerate the patch and commit**

```bash
just blocks-patch && ./test/blocks.sh
git add patches/onyx-block-terminal.patch
git commit -m "Block terminal: bottom input widget wired into the terminal

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: Keybindings and completions

**Files:**
- Modify: `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/browser/terminal.onyxBlocks.contribution.ts` (append keybinding rules)
- Create: `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/browser/onyxBlockCompletions.ts`
- Modify: `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/browser/onyxBlocksContribution.ts` (register the completion provider in `_enable`)
- Modify: `patches/onyx-block-terminal.patch` (regenerated)

**Interfaces:**
- Consumes: `OnyxBlockInput.getFocused`, `IOnyxBlockController`, `OnyxBlocksContextKeys.inputFocused`, `ITerminalCompletionService.provideCompletions`, `ITerminalCompletion`, `ILanguageFeaturesService.completionProvider.register`.
- Produces: command ids `onyx.blocks.run`, `onyx.blocks.newline`, `onyx.blocks.historyPrevious`, `onyx.blocks.historyNext`, `onyx.blocks.triggerSuggest`, `onyx.blocks.interruptOrClear`, `onyx.blocks.clearInput`, `onyx.blocks.clearTerminal`, `onyx.blocks.selectPreviousBlock`, `onyx.blocks.selectNextBlock`, `onyx.blocks.clearBlockSelection`, `onyx.blocks.copyTerminalSelection`, `onyx.blocks.focusFind`; class `OnyxBlockCompletionProvider`.

- [ ] **Step 1: Register the keybindings**

Append to `browser/terminal.onyxBlocks.contribution.ts`:

```ts
// #region Keybindings

import { KeyCode, KeyMod } from '../../../../../base/common/keyCodes.js';
import { ICodeEditorService } from '../../../../../editor/browser/services/codeEditorService.js';
import { EditorContextKeys } from '../../../../../editor/common/editorContextKeys.js';
import { Context as SuggestContext } from '../../../../../editor/contrib/suggest/browser/suggest.js';
import { ContextKeyExpr } from '../../../../../platform/contextkey/common/contextkey.js';
import type { ServicesAccessor } from '../../../../../platform/instantiation/common/instantiation.js';
import { KeybindingsRegistry, KeybindingWeight } from '../../../../../platform/keybinding/common/keybindingsRegistry.js';
import { TerminalContextKeys } from '../../../terminal/common/terminalContextKey.js';
import { OnyxBlockInput, OnyxBlocksContextKeys } from './onyxBlockInput.js';

const inputFocused = OnyxBlocksContextKeys.inputFocused;
const noSuggest = SuggestContext.Visible.negate();
const weight = KeybindingWeight.WorkbenchContrib + 1;

function withInput(accessor: ServicesAccessor, fn: (input: OnyxBlockInput) => void): void {
	const input = OnyxBlockInput.getFocused(accessor.get(ICodeEditorService));
	if (input) {
		fn(input);
	}
}

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: 'onyx.blocks.run',
	weight,
	when: ContextKeyExpr.and(inputFocused, noSuggest),
	primary: KeyCode.Enter,
	handler: accessor => withInput(accessor, input => input.controller.run(input.value)),
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: 'onyx.blocks.newline',
	weight,
	when: inputFocused,
	primary: KeyMod.Shift | KeyCode.Enter,
	handler: accessor => withInput(accessor, input => input.editor.trigger('keyboard', 'type', { text: '\n' })),
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: 'onyx.blocks.historyPrevious',
	weight,
	when: ContextKeyExpr.and(inputFocused, noSuggest),
	primary: KeyCode.UpArrow,
	handler: accessor => withInput(accessor, input => {
		if (!input.cursorOnFirstLine()) {
			input.editor.trigger('keyboard', 'cursorUp', null);
			return;
		}
		const entry = input.history.previous(input.value);
		if (entry !== undefined) {
			input.setValue(entry);
		}
	}),
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: 'onyx.blocks.historyNext',
	weight,
	when: ContextKeyExpr.and(inputFocused, noSuggest),
	primary: KeyCode.DownArrow,
	handler: accessor => withInput(accessor, input => {
		if (!input.cursorOnLastLine()) {
			input.editor.trigger('keyboard', 'cursorDown', null);
			return;
		}
		const entry = input.history.next();
		if (entry !== undefined) {
			input.setValue(entry);
		}
	}),
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: 'onyx.blocks.triggerSuggest',
	weight,
	when: ContextKeyExpr.and(inputFocused, noSuggest),
	primary: KeyCode.Tab,
	handler: accessor => withInput(accessor, input => input.editor.trigger('keyboard', 'editor.action.triggerSuggest', {})),
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: 'onyx.blocks.interruptOrClear',
	weight,
	when: ContextKeyExpr.and(inputFocused, EditorContextKeys.hasNonEmptySelection.negate()),
	primary: KeyMod.CtrlCmd | KeyCode.KeyC,
	mac: { primary: KeyMod.WinCtrl | KeyCode.KeyC },
	handler: accessor => withInput(accessor, input => input.controller.interrupt()),
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: 'onyx.blocks.clearInput',
	weight,
	when: inputFocused,
	primary: KeyMod.CtrlCmd | KeyCode.KeyU,
	mac: { primary: KeyMod.WinCtrl | KeyCode.KeyU },
	handler: accessor => withInput(accessor, input => input.clear()),
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: 'onyx.blocks.clearTerminal',
	weight,
	when: inputFocused,
	primary: KeyMod.CtrlCmd | KeyCode.KeyL,
	mac: { primary: KeyMod.WinCtrl | KeyCode.KeyL },
	handler: accessor => withInput(accessor, input => input.controller.clearTerminal()),
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: 'onyx.blocks.selectPreviousBlock',
	weight,
	when: ContextKeyExpr.and(inputFocused, noSuggest),
	primary: KeyMod.CtrlCmd | KeyCode.UpArrow,
	handler: accessor => withInput(accessor, input => input.controller.selectBlock('previous')),
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: 'onyx.blocks.selectNextBlock',
	weight,
	when: ContextKeyExpr.and(inputFocused, noSuggest),
	primary: KeyMod.CtrlCmd | KeyCode.DownArrow,
	handler: accessor => withInput(accessor, input => input.controller.selectBlock('next')),
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: 'onyx.blocks.clearBlockSelection',
	weight,
	when: ContextKeyExpr.and(inputFocused, noSuggest),
	primary: KeyCode.Escape,
	handler: accessor => withInput(accessor, input => input.controller.selectBlock('clear')),
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: 'onyx.blocks.copyTerminalSelection',
	weight: weight + 1,
	when: ContextKeyExpr.and(inputFocused, TerminalContextKeys.textSelected),
	primary: KeyMod.CtrlCmd | KeyCode.KeyC,
	handler: accessor => withInput(accessor, input => input.controller.copyTerminalSelection()),
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: 'onyx.blocks.focusFind',
	weight,
	when: inputFocused,
	primary: KeyMod.CtrlCmd | KeyCode.KeyF,
	handler: accessor => withInput(accessor, input => input.controller.focusFind()),
});

// #endregion
```

Move the import lines to the top of the file with the others.

- [ ] **Step 2: Write the completion adapter**

`browser/onyxBlockCompletions.ts`:

```ts
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Onyx contributors. Licensed under the MIT License.
 *--------------------------------------------------------------------------------------------*/

import type { CancellationToken } from '../../../../../base/common/cancellation.js';
import type { URI } from '../../../../../base/common/uri.js';
import { Range } from '../../../../../editor/common/core/range.js';
import type { Position } from '../../../../../editor/common/core/position.js';
import { CompletionItemKind, type CompletionContext, type CompletionItem, type CompletionItemProvider, type CompletionList } from '../../../../../editor/common/languages.js';
import type { ITextModel } from '../../../../../editor/common/model.js';
import type { ITerminalInstance } from '../../../terminal/browser/terminal.js';
import { TerminalCompletionItemKind, type ITerminalCompletion } from '../../suggest/browser/terminalCompletionItem.js';
import { ITerminalCompletionService } from '../../suggest/browser/terminalCompletionService.js';

function mapKind(kind: TerminalCompletionItemKind | undefined): CompletionItemKind {
	switch (kind) {
		case TerminalCompletionItemKind.File:
		case TerminalCompletionItemKind.SymbolicLinkFile:
			return CompletionItemKind.File;
		case TerminalCompletionItemKind.Folder:
		case TerminalCompletionItemKind.SymbolicLinkFolder:
			return CompletionItemKind.Folder;
		case TerminalCompletionItemKind.Method:
		case TerminalCompletionItemKind.Alias:
			return CompletionItemKind.Method;
		case TerminalCompletionItemKind.Argument:
		case TerminalCompletionItemKind.OptionValue:
			return CompletionItemKind.Value;
		case TerminalCompletionItemKind.Option:
		case TerminalCompletionItemKind.Flag:
			return CompletionItemKind.Property;
		default:
			return CompletionItemKind.Text;
	}
}

/** Feeds upstream's terminal completion providers into the block input's Monaco suggest widget. */
export class OnyxBlockCompletionProvider implements CompletionItemProvider {
	readonly _debugDisplayName = 'onyxBlocks';

	constructor(
		private readonly _instance: ITerminalInstance,
		private readonly _inputUri: URI,
		@ITerminalCompletionService private readonly _completionService: ITerminalCompletionService,
	) { }

	async provideCompletionItems(model: ITextModel, position: Position, _context: CompletionContext, token: CancellationToken): Promise<CompletionList | undefined> {
		if (model.uri.toString() !== this._inputUri.toString()) {
			return undefined;
		}
		const value = model.getValue();
		const cursorIndex = model.getOffsetAt(position);
		const items = await this._completionService.provideCompletions(
			value, cursorIndex, true, this._instance.shellType, this._instance.capabilities, token, false, false, true,
		);
		if (!items || token.isCancellationRequested) {
			return undefined;
		}
		const suggestions: CompletionItem[] = items.map((c: ITerminalCompletion) => {
			const label = typeof c.label === 'string' ? c.label : c.label.label;
			const [start, end] = c.replacementRange ?? [cursorIndex, cursorIndex];
			return {
				label,
				kind: mapKind(c.kind),
				detail: c.detail,
				documentation: c.documentation,
				insertText: c.inputData ?? label,
				range: Range.fromPositions(model.getPositionAt(start), model.getPositionAt(end)),
			};
		});
		return { suggestions };
	}
}
```

- [ ] **Step 3: Register the provider for the input's scheme**

In `onyxBlocksContribution.ts`, add the imports:

```ts
import { ILanguageFeaturesService } from '../../../../../editor/common/services/languageFeatures.js';
import { OnyxBlockCompletionProvider } from './onyxBlockCompletions.js';
```

Add `@ILanguageFeaturesService private readonly _languageFeaturesService: ILanguageFeaturesService,` to the constructor parameters. In `_enable`, right after `this._input.value = input;`:

```ts
		this._enabledParts.add(this._languageFeaturesService.completionProvider.register(
			{ scheme: OnyxBlockInput.SCHEME },
			this._instantiationService.createInstance(OnyxBlockCompletionProvider, this._ctx.instance, input.uri),
		));
```

Each terminal registers one provider for the shared scheme; the provider answers only for its own input model by comparing URIs, so split terminals do not cross-complete.

- [ ] **Step 4: Compile, lint, tests, manual check**

Run: `cd vscode && npm run compile && npx eslint src/vs/workbench/contrib/terminalContrib/onyxBlocks && ./scripts/test.sh --glob '**/onyxBlocks/**/*.test.js'`
Expected: clean, 28 passing.

Then `just dev`, open a terminal, and check:
- `ls` + Enter runs and the input clears; the output appears in xterm.
- Shift+Enter adds a line; `cat <<EOF`, Shift+Enter, `hi`, Shift+Enter, `EOF`, Enter prints `hi` as one command.
- Up recalls `ls`; Down returns to the empty draft.
- `cd /` then Enter updates the header to `/`.
- Type `ls ./sr` then Tab: a completion popup shows `src/`; Enter accepts it.
- `sleep 30`, Enter, then Ctrl+C interrupts; Ctrl+C with nothing running clears the input.
- `read x`, Enter, type `hello`, Enter: the shell's `echo $x` prints `hello`.
- Select text in the output with the mouse, Cmd+C copies it.
- Cmd+F opens the terminal find widget.
Record results in the report.

- [ ] **Step 5: Regenerate the patch and commit**

```bash
just blocks-patch && ./test/blocks.sh
git add patches/onyx-block-terminal.patch
git commit -m "Block terminal: keybindings and shell completions in the input

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: Block overlay with actions and selection

**Files:**
- Create: `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/browser/onyxBlockOverlay.ts`
- Modify: `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/browser/onyxBlocksContribution.ts` (create the overlay in `_enable`)
- Modify: `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/browser/media/onyxBlocks.css` (append overlay styles)
- Modify: `patches/onyx-block-terminal.patch` (regenerated)

**Interfaces:**
- Consumes: `BlockModel`, `IBlock`, `OnyxBlocksContribution.copyCommand/copyOutput/rerun/sendToAgent`, xterm `raw.element`, `raw.rows`, `raw.buffer.active.viewportY/baseY/cursorY`, `raw.onScroll`, `raw.onResize`, `raw.onWriteParsed`, private `_core._renderService.dimensions.css.cell.height` via upstream's `IXtermCore` typing.
- Produces: `interface IBlockActions { copyCommand(b); copyOutput(b); rerun(b); sendToAgent(b) }`; `class OnyxBlockOverlay { constructor(xterm, model, actions); refresh() }`.

- [ ] **Step 1: Write the overlay**

`browser/onyxBlockOverlay.ts`:

```ts
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Onyx contributors. Licensed under the MIT License.
 *--------------------------------------------------------------------------------------------*/

import type { Terminal as RawXtermTerminal } from '@xterm/xterm';
import * as dom from '../../../../../base/browser/dom.js';
import { Codicon } from '../../../../../base/common/codicons.js';
import { Disposable, DisposableStore, toDisposable } from '../../../../../base/common/lifecycle.js';
import { ThemeIcon } from '../../../../../base/common/themables.js';
import { localize } from '../../../../../nls.js';
import type { IXtermTerminal } from '../../../terminal/browser/terminal.js';
import type { IXtermCore } from '../../../terminal/browser/xterm-private.js';
import type { BlockModel, IBlock } from './onyxBlockModel.js';

export interface IBlockActions {
	copyCommand(block: IBlock): void;
	copyOutput(block: IBlock): void;
	rerun(block: IBlock): void;
	sendToAgent(block: IBlock): void;
}

interface IBlockElement {
	root: HTMLElement;
	toolbar: HTMLElement;
}

/**
 * Draws one translucent band per block over the xterm screen, positioned from the block's
 * marker lines. Pointer events pass through to xterm except on the hover toolbar; hover and
 * click are derived from mouse rows on the xterm element.
 */
export class OnyxBlockOverlay extends Disposable {
	private readonly _element: HTMLElement;
	private readonly _elements = new Map<number, IBlockElement>();
	private _hoveredId: number | undefined;
	private _refreshQueued = false;
	private readonly _listeners = this._register(new DisposableStore());

	constructor(
		private readonly _xterm: IXtermTerminal & { raw: RawXtermTerminal },
		private readonly _model: BlockModel,
		private readonly _actions: IBlockActions,
	) {
		super();
		const host = _xterm.raw.element!;
		this._element = dom.append(host, dom.$('.onyx-blocks-overlay'));
		this._register(toDisposable(() => this._element.remove()));

		this._listeners.add(_xterm.raw.onScroll(() => this.refresh()));
		this._listeners.add(_xterm.raw.onResize(() => this.refresh()));
		this._listeners.add(_xterm.raw.onWriteParsed(() => this.refresh()));
		this._listeners.add(_model.onDidChange(() => this.refresh()));

		this._listeners.add(dom.addDisposableListener(host, 'mousemove', e => this._setHovered(this._blockAtEvent(e)?.id)));
		this._listeners.add(dom.addDisposableListener(host, 'mouseleave', () => this._setHovered(undefined)));
		this._listeners.add(dom.addDisposableListener(host, 'mousedown', e => {
			if (e.button !== 0 || (e.target as HTMLElement).closest('.onyx-block-toolbar')) {
				return;
			}
			const block = this._blockAtEvent(e);
			this._model.select(block?.id);
		}));
		this.refresh();
	}

	refresh(): void {
		if (this._refreshQueued) {
			return;
		}
		this._refreshQueued = true;
		queueMicrotask(() => {
			this._refreshQueued = false;
			this._render();
		});
	}

	private _rowHeight(): number | undefined {
		return (this._xterm.raw as unknown as { _core: IXtermCore })._core._renderService?.dimensions?.css.cell.height;
	}

	private _screen(): HTMLElement | null {
		return this._xterm.raw.element?.querySelector('.xterm-screen') ?? null;
	}

	private _blockAtEvent(e: MouseEvent): IBlock | undefined {
		const rowHeight = this._rowHeight();
		const screen = this._screen();
		if (!rowHeight || !screen) {
			return undefined;
		}
		const rect = screen.getBoundingClientRect();
		const row = Math.floor((e.clientY - rect.top) / rowHeight);
		if (row < 0 || row >= this._xterm.raw.rows) {
			return undefined;
		}
		const line = this._xterm.raw.buffer.active.viewportY + row;
		return this._model.blocks.find(b => {
			const start = b.startLine;
			const end = b.endLine ?? this._runningEndLine();
			return start !== undefined && line >= start && line <= end;
		});
	}

	private _runningEndLine(): number {
		const buffer = this._xterm.raw.buffer.active;
		return buffer.baseY + buffer.cursorY;
	}

	private _setHovered(id: number | undefined): void {
		if (this._hoveredId === id) {
			return;
		}
		this._hoveredId = id;
		for (const [blockId, el] of this._elements) {
			el.root.classList.toggle('hover', blockId === id);
		}
	}

	private _render(): void {
		const rowHeight = this._rowHeight();
		const screen = this._screen();
		if (!rowHeight || !screen) {
			return;
		}
		this._element.style.top = `${screen.offsetTop}px`;
		this._element.style.left = `${screen.offsetLeft}px`;
		this._element.style.width = `${screen.clientWidth}px`;
		this._element.style.height = `${this._xterm.raw.rows * rowHeight}px`;

		const viewportY = this._xterm.raw.buffer.active.viewportY;
		const rows = this._xterm.raw.rows;
		const seen = new Set<number>();
		this._model.blocks.forEach((block, index) => {
			const start = block.startLine;
			if (start === undefined) {
				return;
			}
			const end = block.endLine ?? this._runningEndLine();
			const topRow = start - viewportY;
			const bottomRow = end - viewportY;
			if (bottomRow < 0 || topRow >= rows) {
				return;
			}
			seen.add(block.id);
			const el = this._elements.get(block.id) ?? this._createElement(block);
			this._elements.set(block.id, el);
			el.root.style.top = `${Math.max(topRow, 0) * rowHeight}px`;
			el.root.style.height = `${(Math.min(bottomRow, rows - 1) - Math.max(topRow, 0) + 1) * rowHeight}px`;
			el.root.classList.toggle('odd', index % 2 === 1);
			el.root.classList.toggle('selected', block.id === this._model.selectedId);
			el.root.classList.toggle('failed', block.exitCode !== undefined && block.exitCode !== 0);
			el.root.classList.toggle('running', block.isRunning);
			el.root.classList.toggle('hover', block.id === this._hoveredId);
			el.toolbar.style.display = block.isRunning ? 'none' : '';
		});
		for (const [id, el] of this._elements) {
			if (!seen.has(id)) {
				el.root.remove();
				this._elements.delete(id);
			}
		}
	}

	private _createElement(block: IBlock): IBlockElement {
		const root = dom.append(this._element, dom.$('.onyx-block'));
		const toolbar = dom.append(root, dom.$('.onyx-block-toolbar'));
		const button = (icon: ThemeIcon, title: string, run: () => void) => {
			const b = dom.append(toolbar, dom.$('button.onyx-block-action'));
			b.title = title;
			b.appendChild(dom.$(ThemeIcon.asCSSSelector(icon)));
			b.addEventListener('mousedown', e => e.preventDefault());
			b.addEventListener('click', e => { e.stopPropagation(); run(); });
		};
		const current = () => this._model.blocks.find(b => b.id === block.id) ?? block;
		button(Codicon.copy, localize('onyx.blocks.copyCommand', "Copy command"), () => this._actions.copyCommand(current()));
		button(Codicon.output, localize('onyx.blocks.copyOutput', "Copy output"), () => this._actions.copyOutput(current()));
		button(Codicon.debugRerun, localize('onyx.blocks.rerun', "Re-run"), () => this._actions.rerun(current()));
		button(Codicon.sparkle, localize('onyx.blocks.sendToAgent', "Send to agent"), () => this._actions.sendToAgent(current()));
		return { root, toolbar };
	}
}
```

- [ ] **Step 2: Create the overlay in the contribution**

In `onyxBlocksContribution.ts` add the import `import { OnyxBlockOverlay } from './onyxBlockOverlay.js';` and in `_enable`, after the history wiring:

```ts
		this._enabledParts.add(new OnyxBlockOverlay(xterm, this.model, this));
		this._enabledParts.add(this.model.onDidChange(() => this._revealSelectedBlock()));
```

And add the method:

```ts
	private _revealSelectedBlock(): void {
		const block = this.model.selectedBlock;
		const xterm = this._xterm;
		if (!block || !xterm || block.startLine === undefined) {
			return;
		}
		const buffer = xterm.raw.buffer.active;
		const rows = xterm.raw.rows;
		if (block.startLine < buffer.viewportY || block.startLine >= buffer.viewportY + rows) {
			xterm.raw.scrollToLine(block.startLine);
		}
	}
```

`OnyxBlocksContribution` already implements the four `IBlockActions` methods from Task 4, so `this` satisfies the overlay's `IBlockActions` parameter; add `IBlockActions` to the class's `implements` list and import the type.

- [ ] **Step 3: Append the overlay CSS**

Append to `browser/media/onyxBlocks.css`:

```css
.monaco-workbench .terminal-wrapper.onyx-blocks .onyx-blocks-overlay {
	position: absolute;
	z-index: 32;
	pointer-events: none;
	overflow: hidden;
}

.onyx-blocks-overlay .onyx-block {
	position: absolute;
	left: 0;
	right: 0;
	box-sizing: border-box;
	border-left: 2px solid #1a1a1a;
	background: transparent;
}

.onyx-blocks-overlay .onyx-block.odd {
	background: rgba(255, 255, 255, 0.025);
}

.onyx-blocks-overlay .onyx-block.failed {
	border-left-color: rgba(255, 130, 114, 0.4);
}

.onyx-blocks-overlay .onyx-block.selected {
	border-left-color: #00c2ff;
	background: rgba(0, 194, 255, 0.06);
}

.onyx-blocks-overlay .onyx-block.running {
	border-left-color: #00c2ff;
	animation: onyx-block-pulse 1.2s ease-in-out infinite;
}

@keyframes onyx-block-pulse {
	0%, 100% { border-left-color: rgba(0, 194, 255, 0.35); }
	50% { border-left-color: #00c2ff; }
}

.onyx-blocks-overlay .onyx-block-toolbar {
	position: absolute;
	top: 2px;
	right: 6px;
	display: none;
	gap: 2px;
	pointer-events: auto;
	background: #0f0f0f;
	border: 1px solid #1a1a1a;
	border-radius: 4px;
	padding: 1px;
}

.onyx-blocks-overlay .onyx-block.hover .onyx-block-toolbar,
.onyx-blocks-overlay .onyx-block.selected .onyx-block-toolbar {
	display: flex;
}

.onyx-blocks-overlay .onyx-block-action {
	all: unset;
	cursor: pointer;
	color: #8e8e8e;
	width: 20px;
	height: 20px;
	display: inline-flex;
	align-items: center;
	justify-content: center;
	border-radius: 3px;
}

.onyx-blocks-overlay .onyx-block-action:hover {
	color: #ffffff;
	background: #1a1a1a;
}
```

- [ ] **Step 4: Compile, lint, tests, manual check**

Run: `cd vscode && npm run compile && npx eslint src/vs/workbench/contrib/terminalContrib/onyxBlocks && ./scripts/test.sh --glob '**/onyxBlocks/**/*.test.js'`
Expected: clean, 28 passing.

Then `just dev`, open a terminal, and check:
- `ls`, `false`, `pwd`: three bands above the input, alternating shade; the `false` band has a red-tinted left edge.
- Hovering a band shows the four-button toolbar at its top right. Copy command puts `ls` on the clipboard; Copy output puts the listing. Re-run runs `ls` again. Send to agent shows the "Agent API not installed yet" notice.
- Cmd+Up from the input selects the newest block (cyan edge); Cmd+Up again moves up; Cmd+Down moves down; Escape clears.
- Clicking a band selects it; dragging across output still selects text.
- `sleep 3` shows a pulsing cyan edge until it finishes.
- `clear` removes the bands without errors in Help, Toggle Developer Tools console.
- Scrolling keeps bands aligned with their output.
Record results in the report.

- [ ] **Step 5: Regenerate the patch and commit**

```bash
just blocks-patch && ./test/blocks.sh
git add patches/onyx-block-terminal.patch
git commit -m "Block terminal: block overlay with hover actions and selection

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: Patch verification on pristine upstream, docs, full build

**Files:**
- Modify: `README.md` (add a "Block terminal" section and the patch regeneration note)
- Modify: `docs/superpowers/specs/2026-10-14-onyx-block-terminal-design.md` (status line, at the very end)
- Modify: `patches/onyx-block-terminal.patch` (final regeneration)

**Interfaces:**
- Consumes: everything above; `just prepare`, `just build`.

- [ ] **Step 1: Prove the patch applies on pristine upstream**

The prepared `vscode/` has every other patch applied too. Check ours against the untouched tag in a scratch worktree:

```bash
cd vscode
git worktree add /private/tmp/claude-501/-Users-avinashvundyala-Documents-github/b16d6531-7641-44c1-bf37-30bafac22074/scratchpad/pristine 07f806f999227108933c2e30515b26eecc1fda74
cd /private/tmp/claude-501/-Users-avinashvundyala-Documents-github/b16d6531-7641-44c1-bf37-30bafac22074/scratchpad/pristine
git apply --check --ignore-whitespace /Users/avinashvundyala/Documents/github/onyx/.claude/worktrees/build-and-brand/patches/onyx-block-terminal.patch && echo "applies on pristine upstream"
cd /Users/avinashvundyala/Documents/github/onyx/.claude/worktrees/build-and-brand/vscode
git worktree remove --force /private/tmp/claude-501/-Users-avinashvundyala-Documents-github/b16d6531-7641-44c1-bf37-30bafac22074/scratchpad/pristine
```

Expected: "applies on pristine upstream". If it fails because `terminal.all.ts` context differs, regenerate with `just blocks-patch` and retry.

- [ ] **Step 2: Full production build with the patch**

Run: `just build` (about 5 minutes). Then:

```bash
grep -c 'onyxBlocks' VSCode-darwin-arm64/Onyx.app/Contents/Resources/app/out/vs/workbench/workbench.desktop.main.js
```

Expected: a number greater than 0 (the contribution is bundled). Then `just run`, open a terminal, type `echo hi`, Enter: a block appears, the input is at the bottom. Quit.

- [ ] **Step 3: README section**

Add to `README.md` after the install section:

```markdown
## Block terminal

Every Onyx terminal has a command input pinned at the bottom and one block per
command above it. Type anywhere in the terminal and the text lands in the input.
Enter runs, Shift+Enter adds a line, Up and Down walk history, Tab completes.
Hover a block for Copy command, Copy output, Re-run and Send to agent. Cmd+Up
and Cmd+Down (Ctrl on Linux and Windows) select blocks; Escape clears the
selection. Full-screen programs such as vim get the classic terminal back
while they run.

Blocks need shell integration, which Onyx injects for zsh, bash, fish and
PowerShell. A shell without it behaves like a stock VS Code terminal. Turn the
feature off with `onyx.terminal.blocks.enabled: false`.

This is Onyx's one core patch: `patches/onyx-block-terminal.patch`. Its source
is `vscode/src/vs/workbench/contrib/terminalContrib/onyxBlocks/` after
`just prepare`; edit there, then run `just blocks-patch` and commit the patch.
`just test` checks the patch stays inside its allowed files.
```

- [ ] **Step 4: Spec status and commit**

Change the spec's `Status: draft for review` to `Status: implemented, pending release`.

```bash
just blocks-patch && just test
git add README.md docs/superpowers/specs/2026-10-14-onyx-block-terminal-design.md patches/onyx-block-terminal.patch
git commit -m "Block terminal: verified on pristine upstream, documented

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Notes for the executor

- Task 1 must run first; Tasks 2 and 3 are independent of each other and of the UI; Tasks 4, 5, 6 are sequential; Task 7 last.
- Manual checks in Tasks 4, 5, 6 are the only coverage for the DOM parts. The implementer must run them and report what happened, not what should happen.
- After this plan ships, a Publish run cuts a release that carries the block terminal; that is a user decision, not part of this plan.
