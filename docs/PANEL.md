# Panels: UI over a running world

Status: draft for review. Issues: #559, #560, #561, #562, #563, #564, #565, and in kit
#83, #84, #85.

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
| Panel | build menu, unit panel, context menu, tooltip | runs and takes clicks | click outside, Cancel, subject gone | confined; the pointer is free | several |
| Screen | pause, settings, result, confirm | blocked; paused by the game's choice | button, Cancel, scrim click | trapped and restored | one stack |

The documentation keeps one rule. The world runs and takes clicks behind a panel;
anything else is a screen. A result dialog is a screen (kit #85).

## Goals

1. **The world runs and takes clicks behind a panel.** A panel never pauses, never
   blocks the pointer, and never swallows a click it did not receive.
2. **Focus is confined to the open panel; the cursor is free.** Digital navigation
   cannot leave the panel. The pointer can hover and click anything. Hiding the cursor
   returns focus inside the panel, never to the HUD behind it.
3. **A panel's keys mean what the panel says.** Its action layer wins over the map's
   whatever the tree order, so Escape is `ui_cancel` while it is open and
   `ui_toggle_menu` once it closes.
4. **Panels are independent.** Several may be open at once, each with its own
   lifecycle and transition. They share one thing: the ordering that decides which
   holds focus and whose layer wins.
5. **Decisions are immediate; visuals follow.** State changes on the call. Transitions
   are small, quick and not interruptible. A call made mid-transition is the latest
   intent, applied at the next stable state.
6. **Dismissing is cheap; confirming is not.** Close is honoured from the first frame
   of opening. Accept and the panel's own buttons are honoured only once opened.
7. **A screen above a panel suspends it.** Covered, a panel yields its focus claim and
   its layer, and takes both back on uncover. Pausing stays the game's choice.
8. **A scene runs without a manager.** A panel needs no screen stack, so a scene with
   panels works in GUT and under F6, and its tests drive it with real input.
9. **One mechanism each.** One owner of focus confinement for screens and panels
   alike, one rule for layer precedence, one rule for the debounce.

Requirements behind the goals, with their sources: several exits, among them a click
outside for a panel (modal practice in games and on the web); initial focus inside, on
the least destructive action for a destructive dialog and the most used control for a
continue-only one (WAI-ARIA dialog pattern); focus confined while open and returned to
the invoker on close, or to the next logical element when the invoker is gone
(WAI-ARIA, CommonUI's `auto_restore_focus`); never move focus without the player's
action (Apple HIG); a press held or made just before a dialog appears must not confirm
or dismiss it; input mode restored when a widget deactivates, and the last one standing
leaves a usable state (CommonUI); every UI works with the gameplay's input method and
by digital input alone (Game Accessibility Guidelines, Xbox Accessibility Guidelines
107 and 112).

## Elements

Names are provisional and follow std's rules: `Std` prefix, domain second.

### `StdPanel`

A `Control`, the lifecycle container. It owns a four-phase state machine, closed,
opening, open and closing, plus one pending intent.

- API: `open()`, `close()`, `get_phase()`, `is_open()`, and the signals `opening`,
  `opened`, `closing`, `closed`, and `close_requested(event, cancel)` with
  `StdScreen.close_requested`'s cancel semantics. Status getters pair with signals, so
  a caller checks the getter before awaiting the signal.
- Exports: `transition`, `close_actions`, `click_outside_closes` as a mouse-button mask
  like `StdScreen.overlay_click_to_close`, and `accept_delay`, the minimum time after
  `opened` before its controls accept a press.
- It sets `visible` at the start of opening and the end of closing. It never touches
  `process_mode`.
- Children read its phase for their active predicate; a child under a plain `Control`
  falls back to visibility.
- A call during a transition is recorded as the latest intent. Open during closing
  opens after `closed`. Close during opening closes after `opened`. This is what the
  screen manager's operation queue does for screens; nothing interrupts a transition,
  and `_force_stop` exists there for teardown alone.
- A game that keeps one panel node and reuses it gets the latest-intent rule. A game
  that wants two panels to overlap in time instantiates one per open. The panel has no
  retarget operation; moving an open panel is content, and content is the game's.
- Click outside is an observer, not a catcher. The panel watches `_unhandled_input`
  for the cursor's reveal buttons, tests the point against its rect, and emits
  `close_requested` without marking the event handled, so the world's own handler
  still sees the click. A game that decides itself leaves the mask at zero.
- No scrim. A dimmer that does not block says one thing and does another; the moment a
  scrim is wanted, a screen is wanted.

### `StdPanelTransition`

A `Resource` with `_open(ctx)` and `_close(ctx)`, default instant. The context exposes
`panel`, `create_tween()` and `done()` and nothing else, since nothing stops a panel
transition. One shipped subclass fades the panel's `modulate`. Screens keep
`StdScreenTransition`; the two share conventions, not a base, because a curtain over
the whole screen and a local fade have nothing to reuse, and `stop` has no meaning
here.

### `StdInputFocusScope`

A `Node` child of a `Control`. While active it registers a focus claim for its parent
with the cursor, carrying a `priority`. Active means the parent is a `StdPanel` in
opening or open, or else visible in the tree, and in both cases not covered by a
screen; it handles `NOTIFICATION_SCREEN_COVERED` and `UNCOVERED` as the loader does. An
anchor inside the parent takes focus on activation under a hidden cursor through the
handler path that exists today (`report_focus_handler_visible`).

### `StdInputCursor`

The cursor gains a claimant registry and `set_focus_root` leaves the public API.

- Claimants sort by screen depth, then `priority`, then most recent registration. The
  effective root is the top claimant's control. This is how the slot derives enabled
  layers from loaders since v6.3.0 and how the cursor picks anchors.
- The manager registers each overlay as a claimant on push and pop instead of setting
  the root, so screens and panels share one path. The saved focused control moves from
  the manager's per-scene dictionary to a per-claimant one in the cursor.
- Enforcement moves to the cursor. On `gui_focus_changed`, an owner outside the
  effective root is pulled back to the last focused control inside it, else the
  anchor. Today's confinement runs through `StdInputCursorFocusHandler`, which sets
  outside controls to `FOCUS_NONE`, so a focusable control without a handler is still
  a landing spot for Godot's geometric neighbour search. The handler's treatment stays
  as an optimisation.
- The handler already keeps outside controls clickable while the cursor shows and
  refuses a click outside as a restore target, which is the free-cursor behaviour a
  panel wants.
- Re-enabling a disabled anchor re-evaluates focus the way visibility does (#564).

### `StdInputActionSetLoader` and `StdInputActionSetLayer`

The loader becomes a `Node` watching its parent `CanvasItem` (#562) and reads a
`StdPanel` parent's phase the way the scope does. Precedence lives on the layer as a
`priority`, since "navigation beats options" is a property of the layer, not of where
it is placed. The slot sorts enabled layers by it on every change and after an uncover
(#563); Steam's manifest order may need to follow. The default leaves today's scenes
unchanged. Confinement is two mechanisms that switch together: the scope decides where
navigation may land, the layer decides what the keys mean, and both key off one
predicate.

### Kit

`KitPanel` (kit #84): a `StdPanel` root with the `panel_dialog` variation, a scope, a
loader carrying `menu_navigation.tres`, an optional `KitWorldTracker` with edge
flipping, a slot of rows for the action button from kit #83, and no scrim. The result
dialog is a screen (kit #85) and gets its debounce from the enter transition's input
blocker.

### Test fixtures

The input harness from #559 and the manager fixture from #560. Every panel test runs
with transitions off, so calls settle synchronously, and one test per transition awaits
`opened` and `closed`.

## Behaviour

What each phase does with input is the content of the lifecycle.

| Phase | Focus claim | Layer | Close actions, click outside | Own buttons, accept | Visible |
| --- | --- | --- | --- | --- | --- |
| Closed | no | off | no | no | no |
| Opening | yes | on | yes, recorded as intent | no | yes |
| Open, within `accept_delay` | yes | on | yes | no | yes |
| Open | yes | on | yes | yes | yes |
| Closing | no | off | no | no | yes, fading |

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
the earlier one regains the claim. The loader's shared-layer rule keeps
`menu_navigation.tres` enabled while any active panel lists it. Nothing else about one
panel knows another exists.

## Verification

Sequences the implementation passes, each as a test on the fixtures:

- **Escape closes the innermost thing first.** Panel open, Escape closes it and does
  not pause. Panel closed, Escape pauses. Holds in both tree orders.
- **Two panels.** A opens, B opens later, focus is confined to B. B closes, focus
  returns to A's last focused control. The shared layer stays enabled throughout.
- **Screen over a panel, live scene.** Panel open, pause pushed, the panel yields claim
  and layer. The scene hides the panel while covered. Pop restores focus to the map's
  saved control, not to the hidden panel. (#565's sequence.)
- **Cursor mode switches.** Panel open under a hidden cursor, the mouse moves, focus
  releases and the panel stays open. A click beside it closes it and selects what was
  clicked. Hide again, focus returns to the panel, never to a HUD button.
- **Intents mid-transition.** Open during closing opens after `closed`. Close during
  opening closes after `opened`. Cancel on the first frame of opening closes it. A
  press on a button before `accept_delay` elapses does nothing.
- **Nothing escapes.** A focusable control without a handler behind the panel never
  receives focus while the panel is open.
- **No manager.** The scene with its panels runs in GUT with no `StdScreenManager`,
  and behaves identically when mounted through the fixture.

## Decisions and open questions

Decided here:

- Panels are a node a scene owns, not a resource a stack owns.
- The lifecycle container is thin; confinement and layering are independent child
  nodes, in std's style of `StdInputCursorFocusHandler`, `StdInputActionSetLoader`
  and `StdInputActionTrigger`.
- Focus confinement is enforced in the cursor, once, for screens and panels alike.
- Transitions are not interruptible; the latest intent applies at the next stable
  state.
- No scrim and no click catcher on a panel.
- "Subject gone" closes a panel from the game, which knows what a build spot is.

Open:

- Whether the lifecycle container is the `Control` parent or a child node with a path
  to its control. The parent form lets children find their predicate without wiring.
- Whether the claimant registry is hosted by the cursor or the manager. The cursor is
  the sole owner of focus today, which argues for the cursor.
- The event ordering between a UI sibling observing a click and a node inside the
  map's `SubViewport` handling it, which #559's harness establishes before the click
  outside observer relies on it.
- Whether a screen's scene could later use the same lifecycle container, making the
  overlay a modal flavour of one primitive. Not built now; the predicate and the
  registration stay out of the manager so it is not foreclosed.

## Order of work

1. #559 and #560, since everything above is tested on them.
2. The cursor's claimant registry, with the manager moved onto it; #561 and #564 in the
   same change.
3. #563, then #562.
4. `StdPanel` and `StdPanelTransition`.
5. Kit #83 and #84, then #85.

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
- Xbox Accessibility Guidelines 107 and 112:
  https://devdocs.xbox.com/gaming/accessibility/xbox-accessibility-guidelines/107 and
  https://devdocs.xbox.com/gaming/accessibility/xbox-accessibility-guidelines/112
- Godot, Keyboard/Controller Navigation and Focus:
  https://docs.godotengine.org/en/stable/tutorials/ui/gui_navigation.html
