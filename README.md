## About ##

*Jumper* is a simple server for [DroidPad](https://github.com/umer0586/DroidPad), that can convert DroidPad messages
into actual input events on your PC. It can be used alongside DroidPad, to emulate joysticks/keyboards/mouses, and
is scriptable using [Janet](https://janet-lang.org/).

Jumper currently only runs on x64 Windows.


## Dependencies ##

To build from source:

* Janet
* JPM
* MSVC toolchain (comes with Community version of Visual Studio)

To run it:

* vJoy (Optional, if you don't need joystick/gamepad support. Jumper is specifically tested with [this version of vJoy](https://github.com/BrunnerInnovation/vJoy/releases/tag/v2.2.2.0).) 


## Quickstart ##

Note that steps 1 and 3 can be skipped if you don't need joystick/gamepad support.

1. Download and install [vJoy](https://github.com/BrunnerInnovation/vJoy/releases/tag/v2.2.2.0). You'll also need `SDK.zip`.
2. Download `jumper.exe` from releases.
3. Place `vJoyInterface.dll` from `SDK.zip` in the same directory where `jumper.exe` resides.
4. If you have a Jumper config file, drag-and-drop it to `jumper.exe`. Otherwise, just launch `jumper.exe` directly.
5. Configure DroidPad and connect to Jumper's listening address. (Default: `<your ip>:9876`, UDP).


## Simple Configuration ##

Although Jumper can be scripted to do some advanced stuff, it comes with several default handlers that can be simply
configured by setting special DroidPad component *item identifiers*. For example, if you set a button's item identifier
to `kbd:ctrl+enter` in DroidPad, Jumper would emulate `Ctrl+Enter` key combo when that button's pressed. Keep
reading for the complete list of supported identifier formats for all components.

`ACCELEROMETER` and `GYROSCOPE` messages don't have identifiers, so no default handlers for them. You'll need to write
some Janet script to handle these messages. See the `example` directory for some sample code.

Identifier parts in angle brackets (`<>`) are parameters provided by the user, and parts in square brackets (`[]`) can
be omitted.

### Joystick ###

Map to relative mouse movement, `<speed>` defaults to 1000:

```
ms[:rel[:<speed>]]
```

Map to absolute mouse movement:

```
ms:abs
```

Map to `<axis1>` and `<axis2>` of the vJoy device with `<dev-id>` (valid axis names are `x`, `y`, `z`, `rx`, `ry`, `rz`, `slidenr0`, `slider1`, `wheel`, `accelerator`, `brake`, `clutch`, `steering`, `aileron`, `rudder`, `throttle`, and `none`):

```
vjoy:<dev-id>:axes:<axis1>,<axis2>
```

Map to the continuous POV switch with `<pov-id>` of the vJoy device with `<dev-id>` (you need to enable continuous POV switches in vJoy config first):

```
vjoy:<dev-id>:pov:<pov-id>
```


### Slider and Steering Wheel ###

Map to `<axis>` of the vJoy device with `<dev-id>`:

```
vjoy:<dev-id>:axis:<axis>
```


### Button and Switch ###

Map to a key combo (`<combo>` is in the form of `<key1>[+<key2>[+<key3>...]]`, see the source in `kbd.janet` for a complete list of valid key names):

```
kbd:<combo>
```

Map to a mouse `<button>` (valid button names are `left`, `right`, `middle`, `x1`, and `x2`):

```
ms:btn:<button>
```

Map to mouse wheel movement, `<dir>` is the direction of movement (`up`, `down`, `left` or `right`), and `<steps`> is the amount of movement (defaults to 120):

```
ms:wheel:<dir>[:<steps>]
```

Map to the button with `<btn-id>` of the vJoy device with `<dev-id>`:

```
vjoy:<dev-id>:btn:<btn-id>
```


### DPad ###

Map to the (discrete or continuous) POV switch with `<pov-id>` of the vJoy device with `<dev-id>` (you need to enable POV switches in vJoy config firest):

```
vjoy:<dev-id>:pov:<pov-id>
```

Map up, right, down, left dpad buttons to keyboard <combo1..4>, respectively:

```
kbd:<combo1>[,<combo2>[,<combo3>[,combo4]]]
```


## License ##

Jumper's source code is MIT-licensed. All rights to other assets (logos etc.) are reserved by the author.
