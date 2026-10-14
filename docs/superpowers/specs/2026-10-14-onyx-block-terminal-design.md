# Onyx block terminal: design

Status: implemented, pending release
Sub-project: 4 of 4 (moved ahead of the agent API and review panel on 2026-10-14)
Depends on: sub-project 1 (build and brand), shipped as 1.140.06892

## Goal

Give every Onyx terminal the Warp feel: a command input pinned at the bottom
of the terminal, and every command with its output shown above it as a
separate block with actions. The input is where you type; the area above is
where you read.

## Non-goals for v1

- Replacing xterm. Output rendering, scrollback, selection, search, links and
  full-screen programs stay upstream's.
- Block collapse, bookmarks, sharing, AI command search, a git branch in the
  prompt header.
- Any change to terminals in the web build or to the terminal extension API.

## One core patch

This sub-project owns the single core patch Onyx allows. The patch adds one
new directory and one import line:

- New: `src/vs/workbench/contrib/terminalContrib/onyxBlocks/` (all code, CSS
  and tests for this feature).
- Modified: `src/vs/workbench/contrib/terminal/terminal.all.ts`, one added
  import of `onyxBlocks/browser/terminal.onyxBlocks.contribution.js`.

It ships as `patches/onyx-block-terminal.patch`, applied by the existing
`prepare_vscode.sh` loop like every other patch. No other upstream file
changes. If a later task needs another upstream edit, the spec must be
amended first.

## Architecture

A terminal contribution, registered with upstream's
`registerTerminalContribution`, is created per terminal instance. It owns
three parts:

1. **Block input**: a Monaco `CodeEditorWidget` pinned below the xterm host
   inside `.terminal-wrapper`.
2. **Block overlay**: a DOM layer over the xterm host that draws one band per
   command using shell integration markers, like upstream's sticky scroll.
3. **Block model**: a plain object that turns upstream's
   `ICommandDetectionCapability` events into a list of blocks and a selection.

The contribution activates only when `onyx.terminal.blocks.enabled` is true
and the instance gains the command detection capability
(`capabilities.onDidAddCommandDetectionCapability`). Until then, and if the
capability never arrives within upstream's shell integration timeout, the
terminal is stock VS Code.

## Block input

- Styled like Warp: black background, the terminal font, a 1 px `#1a1a1a`
  top border, a cyan `❯` glyph at the left, and a one-line header above the
  editor showing the current working directory from the
  `CwdDetection` capability (falls back to the instance's initial cwd).
- Language mode `shellscript`, or `powershell` when the instance shell type is
  pwsh. Minimum one line, grows to eight lines, then scrolls.
- The xterm area shrinks to make room: the contribution sets
  `padding-bottom` on the `.xterm` element equal to the widget height, which
  upstream's `_getDimension` already subtracts when computing rows. It
  re-applies this in its `layout(xterm, dimension)` hook and whenever the
  editor's content height changes.
- Keybindings, all gated on the context key `onyxBlocks.inputFocused`:
  - Enter: run (see states). Shift+Enter: newline.
  - Up / Down when the cursor is on the first / last line and no suggest
    widget is open: previous / next history entry. Typing resets the history
    cursor.
  - Tab, Ctrl+Space: trigger suggest.
  - Ctrl+C: interrupt (send `\x03`) if a command is running, else clear the
    input.
  - Ctrl+L: clear the terminal (upstream's `workbench.action.terminal.clear`).
  - Cmd+Up / Cmd+Down (Ctrl on Linux and Windows): select the previous /
    next block. Escape: clear the block selection; if none, no-op.
  - Ctrl+U: clear the input.
- History: session commands from `commandDetection.commands` (most recent
  first), then upstream's persisted history via `getCommandHistory` filtered
  by shell type, de-duplicated, capped at 500.
- Completions: a Monaco `CompletionItemProvider` adapter registered for the
  input editor's model only, which calls
  `ITerminalCompletionService.provideCompletions(value, cursorIndex,
  allowFallback=true, shellType, capabilities, token)` and maps
  `ITerminalCompletion` to `CompletionItem` (label, kind, detail, insert
  text, replacement range). Monaco's own suggest widget renders it.

### Input states

The contribution derives a state from upstream signals and uses it to decide
what Enter does:

| State | Signal | Enter does |
| --- | --- | --- |
| Prompt | `promptInputModel.state === Input` and no alt buffer | `instance.runCommand(text, shouldExecute=true, undefined, forceBracketedPaste=text has newline)` |
| Executing | a command started and not finished, no alt buffer | `instance.sendText(text, shouldExecute=true)` (raw, reaches the program) |
| AltBuffer | xterm `buffer.active.type === 'alternate'` | input hidden; xterm has keyboard |

Transitions re-run on `onCommandStarted`, `onCommandFinished`,
`onCommandInvalidated`, `promptInputModel.onDidChangeInput` and xterm's
`buffer.onBufferChange`. Entering AltBuffer hides the input and removes the
padding; leaving it restores both and refocuses the input.

### Focus

- When the terminal instance gains focus and the state is not AltBuffer, focus
  goes to the input editor, not xterm's helper textarea. Implemented by
  listening to focus on the xterm textarea and redirecting; no upstream edit.
- Mouse selection in the output area works as before. Keyboard shortcuts
  bound to upstream's `terminalFocus` context key do not fire while the input
  is focused because that key is false; the contribution registers the
  equivalents it needs (clear, copy selection, find) on its own key.
- Paste while the input is focused pastes into the input.

## Block overlay

- One absolutely positioned element inside `.terminal-xterm-host`, pointer
  events disabled except on the hover toolbar, right inset equal to the
  scrollbar width.
- One child per block, positioned from `promptStartMarker.line` (or `marker`
  when the prompt marker is missing) to `endMarker.line` (or the current
  cursor line for the running command), converted to pixels with the xterm
  cell height and the viewport scroll offset.
- Visuals: alternating background `#0a0a0a` / transparent; a 2 px left edge
  `#1a1a1a`, cyan `#00c2ff` when selected, `#ff8272` at 40 percent when the
  exit code is non-zero; the running block gets a cyan pulse.
- Hover toolbar at the top right of a block with four actions:
  - Copy command: `command.command` to the clipboard.
  - Copy output: `command.getOutput()` to the clipboard.
  - Re-run: puts `command.command` into the input and runs it when the state
    is Prompt; otherwise just fills the input.
  - Send to agent: runs command `onyx.agent.sendBlock` with
    `{ command, output, exitCode, cwd, shellType }` if that command exists,
    else shows an info notification "Agent API not installed yet".
- Re-render on viewport scroll, xterm resize, `onCommandStarted`,
  `onCommandExecuted`, `onCommandFinished`, `onCommandInvalidated`, each
  block's `marker.onDispose`, and theme changes.
- Selection: click selects; Cmd+Up / Cmd+Down from the input move it; a
  selected block scrolls into view.

## Block model

```ts
interface IBlock {
  readonly id: number;            // command.id or a counter
  readonly command: ITerminalCommand;
  readonly startLine: number;     // promptStartMarker ?? marker
  readonly endLine: number | undefined; // endMarker, undefined while running
  readonly exitCode: number | undefined;
}
class BlockModel {
  readonly blocks: readonly IBlock[];
  readonly selectedId: number | undefined;
  readonly onDidChange: Event<void>;
  attach(capability: ICommandDetectionCapability): void; // replays existing commands
  select(id | undefined): void; selectPrevious(): void; selectNext(): void;
}
```

Pure logic, no DOM, so it is unit-testable with a fake capability.

## Configuration

- `onyx.terminal.blocks.enabled` (boolean, default `true`, scope window),
  registered by the contribution. Off means stock terminal; the input and
  overlay are not created. Changing it applies to new terminals.

No other settings in v1. Input height limit and colours are constants.

## Error handling and fallbacks

- No shell integration (unsupported shell, user-disabled, timeout): stock
  terminal, no notification.
- Marker disposed (scrollback trim, clear): the block is removed.
- `onCommandInvalidated` / `onCurrentCommandInvalidated`: affected blocks are
  removed, selection cleared if it pointed at one.
- Terminal reconnect or restore: `attach` replays `capability.commands`.
- Split terminals and remote terminals: each instance has its own
  contribution; nothing is shared.
- Agent command missing: notification, no throw.

## Testing

- Unit tests (upstream mocha layout, `onyxBlocks/test/browser/`):
  - `blockModel.test.ts`: commands become blocks with correct ranges; running
    block has no end; invalidation and marker dispose remove blocks; replay
    on attach; selection navigation wraps at ends.
  - `inputHistory.test.ts`: merge order session-first, de-dup, cap, cursor
    reset on edit.
  - `inputState.test.ts`: state derivation from the three signals and the
    send path chosen for each.
- `just test` keeps passing. `ci-patches` proves the patch applies on the
  pinned upstream.
- Manual smoke on `just dev` (zsh): input at bottom with cwd header; typing
  anywhere lands in the input; `ls` makes a block; `false` makes a red-edged
  block; `cat <<EOF` multi-line via Shift+Enter runs as one command; `vim`
  hides the input and `:q` restores it; `read x` then typing a value and
  Enter reaches `read`; Ctrl+C interrupts `sleep 30`; Up recalls `ls`; Tab
  completes a path; Cmd+Up selects the last block; hover toolbar copies and
  re-runs; Send to agent shows the notice; setting off gives stock terminal.

## Upstream tracking

On every VS Code bump the patch is re-applied by `prepare_vscode.sh`. Only
the import line in `terminal.all.ts` is likely to conflict. Upstream APIs
this feature depends on, to check on each bump: `ITerminalContribution`
hooks, `ICommandDetectionCapability` events and marker fields,
`ITerminalCompletionService.provideCompletions`, `getCommandHistory`,
`ITerminalInstance.runCommand` and `sendText`.
