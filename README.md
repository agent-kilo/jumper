<p align="center">
  <img width="25%" src="https://raw.githubusercontent.com/agent-kilo/jumper/refs/heads/master/res/jumper.png" alt="Jumper Logo">
</p>

## About ##

*Jumper* is a simple server that converts [DroidPad](https://github.com/umer0586/DroidPad) messages into actual input
events on your PC. It can be used, alongside DroidPad, to emulate joysticks/keyboards/mouses, and is scriptable using
[Janet](https://janet-lang.org/).

It currently only runs on x86-64 Windows and Linux.


## Dependencies ##

To build from source:

* Janet
* JPM
* MSVC toolchain on Windows, or GCC toolchain on Linux

To run it on **Windows**:

* vJoy (Optional, if you don't need joystick/gamepad support. Jumper is specifically tested with [this version of vJoy](https://github.com/BrunnerInnovation/vJoy/releases/tag/v2.2.2.0).)

To run it on **Linux**:

* [libevdev](https://gitlab.freedesktop.org/libevdev/libevdev) (Jumper is specifically tested with libevdev v1.13.3)


## Quickstart ##

**Windows:**

1. Download and install [vJoy](https://github.com/BrunnerInnovation/vJoy/releases/tag/v2.2.2.0). You'll also need `SDK.zip`.
2. Download `jumper.exe` from [Releases](https://github.com/agent-kilo/jumper/releases).
3. Place `vJoyInterface.dll` from `SDK.zip` in the same directory where `jumper.exe` resides.
4. If you have a Jumper config file, drag-and-drop it to `jumper.exe`. Otherwise, just launch `jumper.exe` directly.
5. Configure DroidPad and connect to Jumper's listening address. (Default: `<your ip>:9876`, UDP).

**Note** that steps 1 and 3 can be skipped if you don't need joystick/gamepad support.

---

**Linux:**

There's currently no pre-built binaries for Linux, you'll need to either run it from source, or build it yourself.

Prerequisites:

1. Install libevdev using your distro's package manager.
2. Install Janet and JPM.
3. Run `jpm -l deps` in Jumper's source tree.
4. (Optional) Run `jpm -l run vcs-version` in Jumper's source tree.

To run directly from source, invoke `jpm -l janet ./src/main.janet [path/to/config/file.janet]`.

To build the binary, install GCC, then do `jpm -l build` instead.

Jumper loads libevdev dynamically. You may need to specify the `LD_LIBRARY_PATH` environment variable to help it locate
the library.

Creating virtual input devices is a privileged operation in Linux. You may run Jumper as root, but the best practice is
to assign a dedicated group for accessing `/dev/uinput` (needs udev):

1. Create a group named `uinput` (or any other name that's not already taken).
2. Create the file `/etc/udev/rules.d/99-uinput-group.rules`, containing only this line: `KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"`. Note that `GROUP` should be set to the group name you had chosen in step 1.

From here on, you can either:

3.a. Change the Jumper executable's owner group to the one you chose, then enable the `setgid` flag. This would grant access to everyone that can launch Jumper.

Or:

3.b. Add your user to the group you chose. This would grant access to every process launched by your user.


## About DroidPad Sensor Sampling Rate ##

DroidPad's default sensor sampling rate is quite low, if you intend to use accelerometer and gyroscope, it's recommended
to change the sampling rate setting to a smaller number (50000 μs works great for me, but YMMV).


## Simple Configuration ##

Although Jumper can be scripted to do some advanced stuff, it comes with several default handlers that can be configured
by setting special DroidPad component *item identifiers*. For example, if you set a button's item identifier to
`kbd:ctrl+enter` in DroidPad, Jumper would emulate `Ctrl+Enter` key combo when that button's pressed. Supported identifier
formats for all components are listed below. The parts in angle brackets (`<>`) are parameters provided by the user, and
the parts in square brackets (`[]`) can be omitted.

(`ACCELEROMETER` and `GYROSCOPE` messages don't have identifiers, so no default handlers for them. You'll need to write
some Janet script to handle these messages. See the `example` directory for some sample code. Simply drag-and-drop one of
the examples to `jumper.exe` to try it out.)

---

### Joystick Component ###

**Map to relative mouse movement** (`<speed>` defaults to 1000):

```
ms[:rel[:<speed>]]
```

**Map to absolute mouse movement**:

```
ms:abs
```

**Map to mouse movement, in "trackball" mode** (`<speed>` defaults to 1000):

```
ms:track[:<speed>]
```

**Map to `<axis1>` and `<axis2>` of the vJoy device with `<dev-id>`** (See the **Axis Names** section below):

```
vjoy:<dev-id>:axes:<axis1>,<axis2>
```

**Map to the continuous POV switch with `<pov-id>` of the vJoy device with `<dev-id>`** (you need to enable continuous POV switches in vJoy config first, **not supported** on Linux):

```
vjoy:<dev-id>:pov:<pov-id>
```

---

### Slider and Steering Wheel Components ###

**Map to `<axis>` of the vJoy device with `<dev-id>`** (See the **Axis Names** section below):

```
vjoy:<dev-id>:axis:<axis>
```

---

### Button and Switch Components ###

**Map to a key combo** (`<combo>` is in the form of `<key1>[+<key2>[+<key3>...]]`, see the source in `backends/*/kbd.janet` for a complete list of valid key names):

```
kbd:<combo>
```

**Map to a mouse `<button>`** (valid button names are `left`, `right`, `middle`, `x1`, and `x2`):

```
ms:btn:<button>
```

**Map to mouse wheel movement** (`<dir>` is the direction, which can be `up`, `down`, `left` or `right`, and `<steps`> is the amount of movement which defaults to 120):

```
ms:wheel:<dir>[:<steps>]
```

**Map to the button with the name `<btn>` of the vJoy device with `<dev-id>`** (See the **Button Names** section below):

```
vjoy:<dev-id>:btn:<btn>
```

---

### DPad Component ###

**Map to the (discrete or continuous) POV switch with `<pov-id>` of the vJoy device with `<dev-id>`** (you need to enable POV switches in vJoy config first, **not supported** on Linux):

```
vjoy:<dev-id>:pov:<pov-id>
```

**Map up, right, down, left dpad buttons to vJoy buttons `<btn1>`..`<btn4>`, respectively** (See the **Button Names** section below):

```
vjoy:<dev-id>:btn:<btn1>[,<btn2>[,<btn3>[,btn4]]]
```

**Map up, right, down, left dpad buttons to keyboard `<combo1>`..`<combo4>`, respectively**:

```
kbd:<combo1>[,<combo2>[,<combo3>[,combo4]]]
```

**Map up, right, down, left dpad buttons to mouse wheel movement** (`<steps>` is the amount of movement in each direction, which defaults to 120):

```
ms:wheel[:<steps>]
```

---


## Sending Component States to DroidPad ##

You can call these functions in a handler, or in a fiber spawned by a handler, to update component states:

* `jumper/send`
* `jumper/send-switch`
* `jumper/send-slider`
* `jumper/send-led`
* `jumper/send-gauge`
* `jumper/send-log`
* `jumper/broadcast`
* `jumper/broadcast-switch`
* `jumper/broadcast-slider`
* `jumper/broadcast-led`
* `jumper/broadcast-gauge`
* `jumper/broadcast-log`

Please see `src/main.janet` and `example/sync-states.janet` for detailed usage info.


## Axis Names ##

For Windows (need to be enabled in vJoy config first): `x`, `y`, `z`, `rx`, `ry`, `rz`, `slidenr0`, `slider1`, `wheel`, `accelerator`, `brake`, `clutch`, `steering`, `aileron`, `rudder`, `throttle`, `none`

For Linux: `x`, `y`, `z`, `rx`, `ry`, `rz`, `throttle`, `rudder`, `wheel`, `gas`, `brake`, `hat0x`, `hat0y`, `hat1x`, `hat1y`, `hat2x`, `hat2y`, `hat3x`, `hat3y`, `pressure`, `distance`, `tilt-x`, `tilt-y`, `tool-width`, `volume`, `profile`, `misc`, `none`


## Button Names ##

You can generally use an interger to reference the nth button that's available, but note that Windows button indices start from `1`, and Linux button indices start from `0` instead.

Additionally, you can also specify button names in place of indices on Linux. Valid button names are: `trigger`, `thumb`, `thumb2`, `top`, `top2`, `pinkie`, `base`, `base2`, `base3`, `base4`, `base5`, `base6`, `dead`, `south`, `a`, `east`, `b`, `c`, `north`, `x`, `west`, `y`, `z`, `tl`, `tr`, `tl2`, `tr2`, `select`, `start`, `mode`, `thumbl`, `thumbr`.


## Available on Itch.io ##

If you find Jumper useful, please consider donating on itch.io:

<p>
  <a href="https://agentkilo.itch.io/jumper">
    <img height="60" src="https://raw.githubusercontent.com/agent-kilo/jumper/refs/heads/master/res/available-on-itch-io.svg" alt="Available on itch.io">
  </a>
</p>


## License ##

Jumper's source code is MIT-licensed. All rights to other assets (logos etc.) are reserved by the author.
