# Panels: UI over a running world

Status: revised after the first review. Issues: #559, #560, #561, #562, #563, #564,
#565, and in kit #83, #84, #85.

## Problem

A game shows UI over its own running world: a build menu beside a build spot, a unit
panel, a context menu, a tooltip. The world keeps running and keeps taking clicks while
it shows. `StdScreen` is built for the opposite case, a screen that covers what is
below it, and a panel built on the lower primitives today takes five hand steps that
kit's README spells out, holds by tree order, and confines nothing.

The first game on kit, a tower defense prototype, built its build menu that way and
found the gaps this design answers. Its menu's layer won over the map's only because
the map's loader came first in the tree. With the cursor hidden, Down past the last
row could land on a HUD button behind the menu. A button disabled at show and enabled
later never regained focus. The loader is a `Control`, so under a container it covered
the buttons until given `mouse_filter = IGNORE`. The end-of-match dialog copied the
pause menu's layout into the scene because the dialog kit ships needs a screen manager
that GUT and an F6 run lack, and it then delayed its own appearance by hand so a key in
flight could not press its button, and raised `ui_toggle_menu` synthetically so Escape
on it still paused.

Why a panel is not a screen, checked against `screen/`:

- The map screen sets `pause_when_covered`, so a screen pushed above it freezes the
  world through the manager's process modes.
- A screen with `block_input_below = false` joins the map's overlay, and the manager
  then sets the focus root to that shared overlay, so nothing is confined.
- `overlay_click_to_close` never fires under a full-rect map, and when it does the
  overlay accepts the event, so a click on the next build spot would close the menu and
  swallow the selection.
- The stack is linear and its operations are queued behind transitions. A build menu,
  a unit panel and a tooltip coexist, and a close action is dropped while an operation
  is in flight.
- A screen's scene is mounted under the manager, not under the map, so a world tracker
  cannot find its map.
- A screen needs a manager, which a scene run alone does not have.

Godot's `Popup`, `PopupPanel` and `PopupMenu` are `Window`s with their own viewport.
The cursor cannot see their focus owner, and gamepad navigation in them is poor. They
are not a candidate.

## Kinds of in-game UI

Three kinds with different contracts. The web draws the same line between
`dialog.showModal()` and the `popover` attribute's light dismiss, and Unreal's CommonUI
between its Game, GameMenu, Menu and Modal layers.

| Kind | Examples | World behind it | Dismissal | Focus | How many |
| --- | --- | --- | --- | --- | --- |
| HUD | status line, prompts | runs, takes input | never | none | one |
| Panel | build menu, unit panel, context menu, tooltip | runs and takes clicks | click outside, Cancel, subject gone | confined when the panel has a scope; the pointer is free | several |
| Screen | pause, settings, result, confirm | blocked; paused by the game's choice | button, Cancel, scrim click | trapped and restored | one stack |

The documentation keeps one rule. The world runs and takes clicks behind a panel;
anything else is a screen. A result dialog is a screen (kit #85). A tooltip is a panel
without a focus scope.

Confining focus inside a non-modal departs from the web, where a popover never traps
focus and Tab leaves it. The departure is deliberate. Godot's digital navigation
searches geometrically among every focusable control in the viewport, so without a
scope Down leaves the panel for whatever lies below it, and CommonUI's activatable
widgets capture focus for non-modal menus for the same reason.

## Goals

1. **The world runs and takes clicks behind a panel.** A panel never pauses, never
   blocks the pointer outside its own rect, and never marks a click outside handled.
2. **Focus is confined to the open panel; the cursor is free.** Digital navigation
   cannot leave the panel. The pointer can hover and click anything. Hiding the cursor
   returns focus inside the panel, never to the HUD behind it.
3. **A panel's keys mean what the panel says.** Its action layers win over the map's
   whatever the tree order, so Escape is `ui_cancel` while it is open and
   `ui_toggle_menu` once it closes.
4. **Panels are independent.** Several may be open at once, each with its own
   lifecycle and transition. They share one thing: the ordering that decides which
   holds focus and whose layer wins.
5. **Decisions are immediate; visuals follow.** State changes on the call. Transitions
   are small, quick and not interruptible. A call made mid-transition is the latest
   intent, applied at the next stable state, and the getters say so meanwhile.
6. **Dismissing is cheap; confirming is not.** A close is recorded from the first frame
   of opening and takes effect once the entrance completes. The panel's own controls
   take input only once it has opened.
7. **A screen above a panel suspends it.** Covered, a panel yields its focus claim and
   its layers, and takes both back on uncover. Pausing stays the game's choice.
8. **A scene runs without a manager.** A panel needs no screen stack, so a scene with
   panels works in GUT and under F6, and its tests drive it with real input.
9. **One mechanism each.** One owner of focus confinement for screens and panels
   alike, one rule for layer precedence, one transition protocol, and one rule for the
   debounce: nothing shown by a transition takes input until that transition is done.

Requirements behind the goals, with their sources: several exits, among them a click
outside for a panel (modal practice in games and on the web); initial focus inside, on
the least destructive action for a destructive dialog and the most used control for a
continue-only one (WAI-ARIA dialog pattern); focus confined while open and returned to
the invoker on close, or to the next logical element when the invoker is gone
(WAI-ARIA, CommonUI's `auto_restore_focus`); never move focus without the player's
action (Apple HIG); a press held or made just before a dialog appears must not confirm
or dismiss it; input mode restored when a widget deactivates, and the last one standing
leaves a usable state (CommonUI); every UI works with the gameplay's input method and
by digital input alone, and nothing requires a held button (Game Accessibility
Guidelines, Xbox Accessibility Guidelines 107 and 112).

## Elements

Names follow std's rules: `Std` prefix, domain second, the base class shortest. Std
ships the capabilities, each a child node that gives its parent one ability, in the
style of `StdInputCursorFocusHandler`, `StdInputActionSetLoader` and
`StdInputActionTrigger`. Kit ships the widgets built from them.

### `StdTransition`, from `StdScreenTransition`

The screen transition protocol is already right and is only bound to the manager by
its context. It becomes generic, so screens, panels and whatever comes next share one
resource type and a game authors a fade once.

- `StdTransition` is the `Resource`, with `_enter(ctx)`, `_exit(ctx)` and `_swap(ctx)`
  in place of `_push`, `_pop` and `_replace`, each defaulting to the instant change plus
  `done()`, plus `_stop()` for teardown and the `block_input` export.
- `StdTransitionContext` is the base context: `entering` and `exiting` nodes, `mount()`,
  `unmount()`, `swap()`, `create_tween()`, `done()` and the `finished` signal, built
  from a host `Node` that gives it a tree. `StdScreenTransitionContext` extends it,
  asserts a manager, and keeps the scene resolution and the overlay mounting that only
  screens have.
- The manager maps push, pop and replace to enter, exit and swap. A panel maps open to
  enter and close to exit, with its control as `entering` or `exiting`, `mount()`
  setting it visible and `unmount()` hiding it. A panel never swaps and never stops.
- `StdScreenTransitionFade`, the full-screen curtain, stays screen-only by taking the
  screen context, and is renamed `StdScreenTransitionCurtain` to say so. A new
  `StdTransitionFade` tweens the entering or exiting node's `modulate` and serves both.
  A transition that wants a settle holds before `done()`; the hold is part of the
  resource, so a game tunes it once.
- `block_input` keeps its meaning and gains a scope. For a screen the blocker covers the
  viewport, as today. For a panel it covers the panel's rect and nothing else, so the
  world behind keeps taking clicks (goal 1).

### `StdPanel`

A `Node` child of a `Control`, with `control: NodePath = ".."` as the handler has. It
owns a four-phase state machine, closed, opening, open and closing, plus one pending
intent. `StdPanel.for_node(node)` returns the nearest panel owning an ancestor of
`node`, as `KitMap.for_node` and `StdInputSlot.for_player` do, so siblings find it
without wiring.

- API: `open()`, `close()`, `get_phase()`, `get_intent()`, `is_open()`, and the signals
  `opening`, `opened`, `closing`, `closed`, and `close_requested(event, cancel)` with
  `StdScreen.close_requested`'s cancel semantics. `is_open()` is true from `opening`
  through `open`; `get_intent()` reports the call waiting on the current transition.
  Getters pair with signals, so a caller checks the getter before awaiting the signal.
- Exports: `transition`, with `transition_open` and `transition_close` overrides as
  `StdScreen` has; `close_actions`; and `click_outside_closes` as a mouse-button mask
  like `StdScreen.overlay_click_to_close`.
- Visibility belongs to the transition's `mount()` and `unmount()`, as for a screen.
  The panel never touches `process_mode`.
- Nothing inside takes input until `opened`. While opening, the focus claim is
  registered but focus is granted to nothing, so a key in flight lands nowhere, and a
  blocker over the panel's rect stops a click meant for what was under it, when the
  transition's `block_input` holds. At `opened` the scope's anchor takes focus. This is
  the screen manager's transition blocker applied locally, and the whole of the
  debounce. An instant transition has no window; a fade is the window; a dialog that
  wants more holds in its transition, visibly.
- A call during a transition is recorded as the intent. Open during closing opens after
  `closed`. Close during opening closes after `opened`. Nothing interrupts a
  transition; `_force_stop` exists in the manager for teardown alone.
- A game that keeps one panel node and reuses it gets the latest-intent rule. A game
  that wants two panels to overlap in time instantiates one per open. The panel has no
  retarget operation; moving an open panel is content, and content is the game's.
- Click outside observes in `_input`, before the GUI pass, for the cursor's reveal
  buttons: it tests the point against the control's rect and emits `close_requested`
  without marking the event handled, so the world's handler and any UI outside the
  panel still receive the click. A press on another panel or a HUD button closes this
  one too, which is light dismiss as the web defines it. A game that decides itself
  leaves the mask at zero.
- No scrim. A dimmer that does not block says one thing and does another; the moment a
  scrim is wanted, a screen is wanted.

### `StdInputCursorFocusScope`

A `Node` child of a `Control`, optional. While active it registers a focus claim for
its control with the cursor, carrying a `priority`. Active means the control's panel,
found through `for_node`, is opening or open, or else that the control is visible in
the tree when it has no panel, and in both cases not covered by a screen; it handles
`NOTIFICATION_SCREEN_COVERED` and `UNCOVERED` as the loader does. Its anchor takes
focus under a hidden cursor through the handler path that exists today
(`report_focus_handler_visible`), at `opened` for a panel and on activation otherwise.

### `StdInputCursor`

The cursor gains a claimant registry. `set_focus_root` and `focus_root_changed` go, and
kit's `KitInputSystem` wrappers of them go with them, since nothing calls them.

- `claim_focus(control, priority)` and `release_focus(control)` replace the setter. The
  effective root is the top claimant's control. Claimants order structurally: one whose
  control descends from another's wins, then higher `priority`, then the most recent
  registration. The cursor never asks what a screen is. The precedent is the loader's
  shared-layer rule over its group and the handler's anchor list.
- The manager claims each overlay on push and releases it on pop instead of setting the
  root, so screens and panels share one path and screen behaviour is unchanged with
  only screens on the stack. The saved focused control moves from the manager's
  per-scene dictionary to a per-claim record in the cursor, so closing a panel restores
  focus the way a pop does, with the same validation at restore (#565).
- Confinement has a primary and a backstop. The primary stays the handler, which sets
  controls outside the root to `FOCUS_NONE` and keeps them clickable while the cursor
  shows. The backstop moves into the cursor: on `gui_focus_changed`, an owner outside
  the effective root is pulled back to the last focused control inside it, else the
  anchor, so a focusable control without a handler is no longer a landing spot for
  Godot's geometric search. The backstop costs a one-frame `focused` signal on the
  escaped control, which the focus audio handler hears; that is why the handler stays
  primary.
- Re-enabling a disabled anchor re-evaluates focus the way visibility does (#564).

### `StdInputCursorFocusHandler` and `StdInputActionSetLoader` as `Node`s

Both become `Node`s watching their control (#562, widened). The handler uses two things
from being a `Control`, its own visibility notification and `is_visible_in_tree()`,
both proxies for the control that coincide only because it is the control's child; as a
`Node` it reads the control's. The loader does the same, reads a `StdPanel` found by
`for_node` for its predicate, and keeps `active_while` and the first-sync ordering from
#490. Neither then takes a layout slot or covers a sibling.

### `StdInputActionSetLayer`

Precedence lives on the layer as a `priority`, since "navigation beats options" is a
property of the layer, not of where it is placed. The slot sorts enabled layers by it on
every change and after an uncover (#563); Steam's manifest order may need to follow.
The default leaves today's scenes unchanged. Confinement is two mechanisms that switch
together: the scope decides where navigation may land, the layer decides what the keys
mean, and both key off the panel's phase.

### Kit

Kit v3.0.0 folded the shared navigation layer into the `Menu` set, so a panel's layer is
one the game owns today. Kit ships small parentless layers by purpose instead, which fit
any set as std allows since v6.3.0: the four directions with focus next and previous,
accept, cancel, and the existing `menu_options.tres` for toggle. A panel lists the ones
it needs and a tooltip lists none. A game lists them in its action sets so the controls
tabs offer their bindings, saved under the game's set; the `Menu` set's copies of the
same actions stay separate, so a player who rebinds Enter rebinds it twice. That
duplication is accepted and does not reopen kit #82, since the full set-in-a-layer stays
gone.

A layer names actions and carries no bindings. Godot's come from the project's
`InputMap`, where Godot itself defines keyboard and joypad defaults for the `ui_*`
actions, mapped by SDL layout so one default covers every common controller;
`ui_focus_next` and `ui_focus_prev` have keyboard defaults only. Steam's come from the
configuration the game publishes, since the generated manifest lists actions alone.

Widgets (kit #84): a panel container scene, a `PanelContainer` with the `panel_dialog`
variation carrying a `StdPanel`, a scope and a loader; a menu panel of rows for the
action button from kit #83; a world-anchored variant with `KitWorldTracker` and edge
flipping; and no scrim on any of them. A game that wants another shape adds the three
nodes to its own control. The result dialog is a screen (kit #85) and gets its debounce
from its transition like everything else.

### Test fixtures

The input harness from #559 and the manager fixture from #560. Every panel test runs
with transitions off, so calls settle synchronously, and one test per transition awaits
`opened` and `closed`.

## Behaviour

What each phase does with input is the content of the lifecycle.

| Phase | Focus claim | Focused control inside | Layers | Close actions, click outside | Own controls | Visible |
| --- | --- | --- | --- | --- | --- | --- |
| Closed | no | none | off | no | no | no |
| Opening | yes | none | on | yes, recorded as intent | no, blocked | from `mount()` |
| Open | yes | anchor or last focused | on | yes | yes | yes |
| Closing | no | none | off | no | no | until `unmount()` |

Cursor modes:

- **Pointer.** Focus is released, as the cursor already does on reveal. The panel
  stays open. Dismissal is a click outside or a selection change. Hover outside
  highlights what is behind the panel, which is correct for a non-modal.
- **Digital.** Focus is confined to the panel. Dismissal is Cancel. There is no click
  outside.
- **Hide while open.** Focus returns inside the panel, to its last focused control or
  anchor. The cursor's fallback chain already filters by root.
- **Reveal while open.** Only focus release changes, and `_focus_to_restore` remembers
  the panel's control.

Two panels at once: the later or higher-priority one confines focus; when it closes
the earlier one regains the claim. The loader's shared-layer rule keeps a layer enabled
while any active panel lists it. Nothing else about one panel knows another exists.

## Verification

Sequences the implementation passes, each as a test on the fixtures:

- **Escape closes the innermost thing first.** Panel open, Escape closes it and does
  not pause. Panel closed, Escape pauses. Holds in both tree orders.
- **Two panels.** A opens, B opens later, focus is confined to B. B closes, focus
  returns to A's last focused control. A layer both list stays enabled throughout.
- **Screen over a panel, live scene.** Panel open, pause pushed, the panel yields claim
  and layers. The scene hides the panel while covered. Pop restores focus to the map's
  saved control, not to the hidden panel. (#565's sequence.)
- **Saved control gone.** A claim's saved control is hidden, then freed, before the
  claim above it releases; focus falls to the anchor, and nothing asserts.
- **Cursor mode switches.** Panel open under a hidden cursor, the mouse moves, focus
  releases and the panel stays open. A click beside it closes it and selects what was
  clicked. Hide again, focus returns to the panel, never to a HUD button.
- **Intents mid-transition.** Open during closing opens after `closed`. Close during
  opening closes after `opened`. Cancel on the first frame of opening is recorded and
  closes the panel once opened. A key pressed during a fade presses nothing; the same
  key after `opened` presses the anchor. A click on the panel during a fade with
  `block_input` reaches nothing behind it.
- **Freed mid-open.** A panel's control is freed while opening; its claim and its
  layers are released and the next claimant holds focus.
- **Nothing escapes.** A focusable control without a handler behind the panel never
  holds focus while the panel is open.
- **No manager.** The scene with its panels runs in GUT with no `StdScreenManager`,
  and behaves identically when mounted through the fixture.
- **Shared transitions.** One `StdTransitionFade` resource set on a screen and on a
  panel runs both.

The Steam backend's layer order after a sort is checked by hand through the Steam Input
harness, since the headless suite has no Steam client.

## Decisions

- Panels are a node a scene owns, not a resource a stack owns.
- The lifecycle is a child node that gives its parent the ability, as the scope, the
  loader and the handler do; siblings find it through `for_node`. Std ships the
  capabilities and kit ships the widgets.
- Transitions are one generic protocol. The screen context is a subclass of a base the
  panel also builds, and transitions that animate the entering or exiting node serve
  both. The curtain stays a screen transition.
- The debounce is the transition. Nothing shown by a transition takes input until it is
  done, for screens through the viewport blocker and for panels through a blocker over
  their rect and focus withheld until `opened`. No timer, and no held button in std.
- Focus confinement is enforced in the cursor, once, for screens and panels alike, with
  the handler primary and the cursor's pull-back as the backstop.
- Transitions are not interruptible; the latest intent applies at the next stable
  state.
- No scrim and no click catcher on a panel. Click outside is observed in `_input` and
  consumes nothing.
- Kit ships granular parentless `ui_*` layers; the twice-bound Enter is accepted.
- `set_focus_root` leaves std and kit; nothing uses it.
- "Subject gone" closes a panel from the game, which knows what a build spot is.

Open:

- Whether a screen's scene could later use the same lifecycle node, making the overlay
  a modal flavour of one primitive. Not built now; the predicate and the registration
  stay out of the manager so it is not foreclosed.

Follow-ups outside this design:

- A `godot-check` rule in godot-infra: every action a `StdInputActionSet` or layer names
  has an `InputMap` entry in the project, since an action a set lists without a binding
  is more often an omission than a choice. Std's own asserts cover a close action and a
  slot's event check at runtime only.
- Default bindings carried on a set or layer, written into `InputMap` for actions the
  project leaves undefined. Not needed for panels, since Godot defines the `ui_*`
  defaults; worth its own issue if a game wants kit's layers to bind on their own.

## Order of work

1. #559 and #560, since everything above is tested on them.
2. The transition split: `StdTransition`, `StdTransitionContext`, the screen context as
   a subclass, the curtain rename, `StdTransitionFade`. Screens are unchanged in
   behaviour and the existing transition tests hold.
3. The cursor's claimant registry, with the manager moved onto it; #561 and #564 in the
   same change, and the saved-control cases from #565.
4. #562 for the loader and the handler together, then #563.
5. `StdPanel` and `StdInputCursorFocusScope`.
6. Kit: the layers, then #83 and #84, then #85.

## References

- W3C WAI-ARIA Authoring Practices, Dialog (Modal) pattern:
  https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/
- Unreal Engine, Input fundamentals for CommonUI:
  https://dev.epicgames.com/documentation/en-us/unreal-engine/input-fundamentals-for-commonui-in-unreal-engine
- Unreal Engine, `CommonActivatableWidget`:
  https://dev.epicgames.com/documentation/en-us/unreal-engine/python-api/class/CommonActivatableWidget
- Apple Human Interface Guidelines, Focus and selection:
  https://developer.apple.com/design/human-interface-guidelines/focus-and-selection
- Game Accessibility Guidelines, same input method for all of the interface:
  https://gameaccessibilityguidelines.com/ensure-that-all-areas-of-the-user-interface-can-be-accessed-using-the-same-input-method-as-the-gameplay/
- Game Accessibility Guidelines, avoid holds:
  https://gameaccessibilityguidelines.com/avoid-provide-alternatives-to-requiring-buttons-to-be-held-down/
- Xbox Accessibility Guidelines 107 and 112:
  https://devdocs.xbox.com/gaming/accessibility/xbox-accessibility-guidelines/107 and
  https://devdocs.xbox.com/gaming/accessibility/xbox-accessibility-guidelines/112
- Godot, Keyboard/Controller Navigation and Focus:
  https://docs.godotengine.org/en/stable/tutorials/ui/gui_navigation.html
