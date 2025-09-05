<p align="center">
  <img width="25%" src="https://raw.githubusercontent.com/agent-kilo/jumper/refs/heads/master/res/jumper.png" alt="Jwno Logo">
</p>

## About ##

*Jumper* is a simple server that converts [DroidPad](https://github.com/umer0586/DroidPad) messages into actual input
events on your PC. It can be used, alongside DroidPad, to emulate joysticks/keyboards/mouses, and is scriptable using
[Janet](https://janet-lang.org/).

It currently only runs on x64 Windows.


## Dependencies ##

To build from source:

* Janet
* JPM
* MSVC toolchain (comes with Community version of Visual Studio)

To run it:

* vJoy (Optional, if you don't need joystick/gamepad support. Jumper is specifically tested with [this version of vJoy](https://github.com/BrunnerInnovation/vJoy/releases/tag/v2.2.2.0).)


## Quickstart ##

1. Download and install [vJoy](https://github.com/BrunnerInnovation/vJoy/releases/tag/v2.2.2.0). You'll also need `SDK.zip`.
2. Download `jumper.exe` from [Releases](https://github.com/agent-kilo/jumper/releases).
3. Place `vJoyInterface.dll` from `SDK.zip` in the same directory where `jumper.exe` resides.
4. If you have a Jumper config file, drag-and-drop it to `jumper.exe`. Otherwise, just launch `jumper.exe` directly.
5. Configure DroidPad and connect to Jumper's listening address. (Default: `<your ip>:9876`, UDP).

**Note** that steps 1 and 3 can be skipped if you don't need joystick/gamepad support. And DroidPad's default sensor sampling
rate is quite low, if you intend to use accelerometer and gyroscope, it's recommended to change the sampling rate setting to
a smaller number (50000 μs works great for me, but YMMV).


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

**Map to `<axis1>` and `<axis2>` of the vJoy device with `<dev-id>`** (valid axis names are `x`, `y`, `z`, `rx`, `ry`, `rz`, `slidenr0`, `slider1`, `wheel`, `accelerator`, `brake`, `clutch`, `steering`, `aileron`, `rudder`, `throttle`, and `none`):

```
vjoy:<dev-id>:axes:<axis1>,<axis2>
```

**Map to the continuous POV switch with `<pov-id>` of the vJoy device with `<dev-id>`** (you need to enable continuous POV switches in vJoy config first):

```
vjoy:<dev-id>:pov:<pov-id>
```

---

### Slider and Steering Wheel Components ###

**Map to `<axis>` of the vJoy device with `<dev-id>`**:

```
vjoy:<dev-id>:axis:<axis>
```

---

### Button and Switch Components ###

**Map to a key combo** (`<combo>` is in the form of `<key1>[+<key2>[+<key3>...]]`, see the source in `kbd.janet` for a complete list of valid key names):

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

**Map to the button with `<btn-id>` of the vJoy device with `<dev-id>`**:

```
vjoy:<dev-id>:btn:<btn-id>
```

---

### DPad Component ###

**Map to the (discrete or continuous) POV switch with `<pov-id>` of the vJoy device with `<dev-id>`** (you need to enable POV switches in vJoy config first):

```
vjoy:<dev-id>:pov:<pov-id>
```

**Map up, right, down, left dpad buttons to keyboard `<combo1>`..`<combo4>`, respectively**:

```
kbd:<combo1>[,<combo2>[,<combo3>[,combo4]]]
```

---


## License ##

Jumper's source code is MIT-licensed. All rights to other assets (logos etc.) are reserved by the author.
