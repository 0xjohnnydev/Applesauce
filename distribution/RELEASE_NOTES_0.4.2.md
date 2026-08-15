# Applesauce 0.4.2

Five fixes, mostly found by pushing Blade Dash and Talking Tom until they
broke. Nothing about installing or your library changes — pick the same IPA
you used for 0.4.0.

Applesauce is an unaffiliated fork. The emulation is the work of
[touchHLE](https://github.com/touchHLE/touchHLE) and its fork
[HyperHLE](https://github.com/HyperHLE/HyperHLE); neither project is connected
to this one or endorses it. Please report problems here rather than to them.

## The on-screen keyboard now appears in games that use text fields

Games that focus a text field — The Sims Medieval naming your Sim or kingdom,
Peggle's profile certificate, Blokus, Spore — loaded the iOS keyboard
subsystem but no keyboard ever came up, so those names could not be entered.
The cause was run-loop starvation: the emulator holds the main thread and only
let iOS service its run loop for microseconds per frame, far too little for the
asynchronous keyboard-presentation handshake to finish, so iOS invalidated the
keyboard service connection. The emulator now services the run loop generously
while a text field is focused, which is not performance-sensitive because those
are name-entry screens.

## Talking-character apps can use the microphone

Apps like Talking Tom sat silent because input audio queues were created but
never delivered any audio. They now capture through the microphone, and iOS
shows its normal microphone-permission prompt the first time a game records.
Along the way this also fixes two things that made Talking Tom unusable:

- **It no longer freezes after a couple of taps.** Its recorder treated a
  buffer that reported zero packets as empty and re-enqueued it without ever
  looking at the audio, so it waited forever for speech that had already
  arrived. The real sample count is reported now.
- **Opening the upgrade screen no longer crashes.** That screen loads a
  UTF-16 text file, the format Apple recommended for older apps, and the
  loader used to abort on it. It reads UTF-16 in either byte order now.

## Games that crashed on launch now start

Blade Dash — and other games built on Google's protobuf/Tag Manager runtime —
crashed immediately with a stack overflow or an infinite loop. Three separate
causes:

- The old-toolchain `[super …]` call was unbound, turning every super-call
  into infinite recursion on the object itself.
- `NSAllocateObject` was implemented by re-sending `alloc`, which recursed
  forever whenever an app allocates with a computed size.
- Legitimately deep start-up chains (protobuf nests initialisation through
  hundreds of classes) overflowed the small per-thread host stack before the
  recursion guard could catch it; threads get a much larger stack now.

## Notes

These fixes are in the HyperHLE core and the shared iOS layer. As always, JIT
must be enabled before starting a game, and gameplay behaviour on a physical
device can differ from the simulator — please report anything that still
misbehaves, with the log from **On My iPhone → Applesauce → touchhle-host.log**.
