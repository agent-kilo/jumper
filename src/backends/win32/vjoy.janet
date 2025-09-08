(var vjoy-interface nil)
(var vjoy-structs nil)

(defdyn *vjoy-skip-device-check*)


(def VJD_STAT_OWN  0)
(def VJD_STAT_FREE 1)
(def VJD_STAT_BUSY 2)
(def VJD_STAT_MISS 3)
(def VJD_STAT_UNKN 4)

(def HID_USAGE_X           0x30)
(def HID_USAGE_Y           0x31)
(def HID_USAGE_Z           0x32)
(def HID_USAGE_RX          0x33)
(def HID_USAGE_RY          0x34)
(def HID_USAGE_RZ          0x35)
(def HID_USAGE_SL0         0x36)
(def HID_USAGE_SL1         0x37)
(def HID_USAGE_WHL         0x38)
(def HID_USAGE_POV         0x39)
(def HID_USAGE_ACCELERATOR 0xC4)
(def HID_USAGE_BRAKE       0xC5)
(def HID_USAGE_CLUTCH      0xC6)
(def HID_USAGE_STEERING    0xC8)
(def HID_USAGE_AILERON     0xB0)
(def HID_USAGE_RUDDER      0xBA)
(def HID_USAGE_THROTTLE    0xBB)

(def NO_HANDLE_BY_INDEX -1)
(def BAD_PREPARSED_DATA -2)
(def NO_CAPS            -3)
(def BAD_N_BTN_CAPS     -4)
(def BAD_CALLOC         -5)
(def BAD_BTN_CAPS       -6)
(def BAD_BTN_RANGE      -7)
(def BAD_N_VAL_CAPS     -8)
(def BAD_ID_RANGE       -9)
(def NO_SUCH_AXIS      -10)
(def BAD_DEV_STAT      -11)
(def NO_DEV_EXIST      -12)
(def NO_FILE_EXIST     -13)


(def vjoy-signatures
  {'GetvJoyVersion             [:int16]
   'vJoyEnabled                [:int32]
   'GetvJoyProductString       [:ptr]
   'GetvJoyManufacturerString  [:ptr]
   'GetvJoySerialNumberString  [:ptr]
   'DriverMatch                [:int32   :ptr :ptr]             # DllVer, DrvVer
   'GetvJoyMaxDevices          [:int32   :ptr]                  # n
   'GetNumberExistingVJD       [:int32   :ptr]                  # n

   'GetVJDButtonNumber         [:int32   :uint32]               # rID
   'GetVJDDiscPovNumber        [:int32   :uint32]               # rID
   'GetVJDContPovNumber        [:int32   :uint32]               # rID
   'GetVJDAxisExist            [:int32   :uint32 :uint32]       # rID, Axis
   'GetVJDAxisMax              [:int32   :uint32 :uint32 :ptr]  # rID, Axis, Max
   'GetVJDAxisMin              [:int32   :uint32 :uint32 :ptr]  # rID, Axis, Min
   'GetVJDStatus               [:int32   :uint32]               # rID
   'isVJDExists                [:int32   :uint32]               # rID
   'GetOwnerPid                [:int32   :uint32]               # rID

   'AcquireVJD                 [:int32   :uint32]               # rID
   'RelinquishVJD              [:void    :uint32]               # rID
   'UpdateVJD                  [:int32   :uint32 :ptr]          # rID, pData

   'ResetVJD                   [:int32   :uint32]               # rID
   'ResetAll                   [:void]
   'ResetButtons               [:int32   :uint32]               # rID
   'ResetPovs                  [:int32   :uint32]               # rID

   'SetAxis                    [:int32   :int32 :uint32 :uint32]  # Value, rID, Axis
   'SetBtn                     [:int32   :int32 :uint32 :uint8]   # Value, rID, nBtn
   'SetDiscPov                 [:int32   :int32 :uint32 :uint8]   # Value, rID, nPov
   'SetContPov                 [:int32   :uint32 :uint32 :uint8]  # Value, rID, nPov

   'GetPosition                [:uint32  :uint32 :ptr]          # rID, pPosition
  })


(defn get-vjoy-structs []
  (if vjoy-structs
    vjoy-structs
    (set vjoy-structs
         {'JOYSTICK_POSITION (ffi/struct
                              :uint8   # bDevice

                              :int32   # wThrottle
                              :int32   # wRudder
                              :int32   # wAileron

                              :int32   # wAxisX
                              :int32   # wAxisY
                              :int32   # wAxisZ
                              :int32   # wAxisXRot
                              :int32   # wAxisYRot
                              :int32   # wAxisZRot
                              :int32   # wSlider
                              :int32   # wDial

                              :int32   # wWheel
                              :int32   # wAccelerator
                              :int32   # wBrake
                              :int32   # wClutch
                              :int32   # wSteering

                              :int32   # wAxisVX
                              :int32   # wAxisVY

                              :int32   # lButtons

                              :int32  # bHats
                              :int32  # bHatsEx1
                              :int32  # bHatsEx2
                              :int32  # bHatsEx3

                              :int32   # lButtonsEx1
                              :int32   # lButtonsEx2
                              :int32   # lButtonsEx3

                              :int32   # wAxisVZ
                              :int32   # wAxisVBRX
                              :int32   # wAxisVBRY
                              :int32   # wAxisVBRZ
                              )})))


(defn load-vjoy-interface [path]
  (if vjoy-interface
    vjoy-interface
    (set vjoy-interface (ffi/native path))))


(defn call-vjoy-interface [name & args]
  (def vjoy-interface (load-vjoy-interface "vJoyInterface.dll"))
  (def sym (ffi/lookup vjoy-interface (string name)))
  (def sig (ffi/signature :default ;(in vjoy-signatures (symbol name))))
  (ffi/call sym sig ;args))


######### Helpers #########

(def joystick-position-idx
  {:dev 0
   :throttle 1
   :rudder   2
   :aileron  3
   :x  4
   :y  5
   :z  6
   :rx 7
   :ry 8
   :rz 9
   :slider0 10
   :slider1 11
   :wheel   12
   :accelerator 13
   :brake   14
   :clutch  15
   :steering 16
   :vx 17
   :vy 18
   :buttons0 19
   :hats0 20
   :hats1 21
   :hats2 22
   :hats3 23
   :buttons1 24
   :buttons2 25
   :buttons3 26
   :vz 27
   :vbrx 28
   :vbry 29
   :vbrz 30})


(def axis-id-to-name
  {HID_USAGE_X   :x
   HID_USAGE_Y   :y
   HID_USAGE_Z   :z
   HID_USAGE_RX  :rx
   HID_USAGE_RY  :ry
   HID_USAGE_RZ  :rz
   HID_USAGE_SL0 :slider0
   HID_USAGE_SL1 :slider1
   HID_USAGE_WHL :wheel
#   HID_USAGE_POV :pov
   HID_USAGE_ACCELERATOR :accelerator
   HID_USAGE_BRAKE       :brake
   HID_USAGE_CLUTCH      :clutch
   HID_USAGE_STEERING    :steering
   HID_USAGE_AILERON     :aileron
   HID_USAGE_RUDDER      :rudder
   HID_USAGE_THROTTLE    :throttle})


(def axis-name-to-id @{})
(eachp [id name] axis-id-to-name
  (put axis-name-to-id name id))


(defn calc-axis-middle-point [[amin amax]]
  (math/round (/ (+ amin amax) 2)))


(def axis-default-values
  {:x calc-axis-middle-point
   :y calc-axis-middle-point
   :z calc-axis-middle-point
   :rx calc-axis-middle-point
   :ry calc-axis-middle-point
   :rz calc-axis-middle-point
   :slider0 0
   :slider1 0
   :wheel 0
   :accelerator 0
   :brake 0
   :clutch 0
   :steering 0
   :aileron 0
   :rudder calc-axis-middle-point
   :throttle 0
  })


(defn get-axis-default-value [name axes]
  (def val (in axis-default-values name))
  (def axis-setting (in axes name))
  (cond
    (nil? axis-setting)
    0

    (function? val)
    (val axis-setting)

    true
    val))


(defn buf-to-integer [buf]
  (var res 0)
  (eachp [n byte] buf
    (set res (bor res (blshift byte (* 8 n)))))
  res)


######### High-Level Interface #########

(defn check-device
  ```Checks whether the vJoy environment is correct, and the device
  with the specified ID is available. Returns true when the device
  is available. Otherwise, errors will be raised.```
  [id]

  (unless (int? id)
    (errorf "invalid vjoy device id: %n" id))

  (when (>= 0 (call-vjoy-interface 'vJoyEnabled))
    (error "vjoy disabled"))

  (def dll-ver-buf (buffer/new-filled (ffi/size :uint16)))
  (def drv-ver-buf (buffer/new-filled (ffi/size :uint16)))
  (when (>= 0 (call-vjoy-interface 'DriverMatch dll-ver-buf drv-ver-buf))
    (errorf "driver version 0x%04x does not match dll version 0x%04x"
            (buf-to-integer drv-ver-buf)
            (buf-to-integer dll-ver-buf)))

  (def dev-num-buf (buffer/new-filled (ffi/size :int32)))
  (when (>= 0 (call-vjoy-interface 'GetNumberExistingVJD dev-num-buf))
    (error "failed to get vjoy device count"))
  (when (or (>= 0 id)
            (> id (buf-to-integer dev-num-buf)))
    (errorf "vjoy device #%n does not exist" id))

  true)


(defn get-controls
  ```Retrieves info on available controls for the vJoy device with
  the specified ID. Returns a struct containing these keys:

  :buttons:         Number of available buttons.
  :discrete-povs:   Number of available discrete POV switches.
  :continuous-povs: Number of available continuous POV switches.
  :axes:            A table containing names and min/max values of available axes.```
  [id]

  (unless (dyn *vjoy-skip-device-check*)
    (check-device id))

  (def button-num (call-vjoy-interface 'GetVJDButtonNumber id))
  (def disc-pov-num (call-vjoy-interface 'GetVJDDiscPovNumber id))
  (def cont-pov-num (call-vjoy-interface 'GetVJDContPovNumber id))

  (def axes @{})
  (eachp [aid aname] axis-id-to-name
    (if (< 0 (call-vjoy-interface 'GetVJDAxisExist id aid))
      (do
        (def min-buf (buffer/new-filled (ffi/size :int32)))
        (when (>= 0 (call-vjoy-interface 'GetVJDAxisMin id aid min-buf))
          (errorf "failed to get min %n value for vjoy device #%n" aname id))
        (def max-buf (buffer/new-filled (ffi/size :int32)))
        (when (>= 0 (call-vjoy-interface 'GetVJDAxisMax id aid max-buf))
          (errorf "failed to get max %n value for vjoy device #%n" aname id))
        (put axes aname [(buf-to-integer min-buf) (buf-to-integer max-buf)]))
      # else, the axis is not enabled
      (put axes aname nil)))

  {:buttons button-num
   :discrete-povs disc-pov-num
   :continuous-povs cont-pov-num
   :axes axes})


(defn update
  ```Updates the actual vJoy device, to reflect the control states
  stored in dev. Use set-axis, set-button, set-discrete-pov or
  set-continuous-pov functions to change the stored states, then
  use this function to feed/commit the changes to the vJoy device.

  An optional buffer can be specified to avoid ad-hoc buffer creation.```
  [dev &opt buf]

  (def id (in dev :id))
  (def state (in dev :state))
  (def pos-struct (in (get-vjoy-structs) 'JOYSTICK_POSITION))
  (when (>= 0 (call-vjoy-interface 'UpdateVJD id (ffi/write pos-struct state buf 0)))
    (errorf "failed to update vjoy device #%n" id)))


(defn reset
  ```Resets the specified vJoy device object. See axis-default-values
  for default axis values. All other controls are reset to released
  or neutral states.```
  [dev]

  (def id (in dev :id))
  (def controls (in dev :controls))
  (def axes (in controls :axes))
  (def state (in dev :state))

  (when (>= 0 (call-vjoy-interface 'ResetVJD id))
    (errorf "failed to reset vjoy device #%n" id))

  (put state
       (joystick-position-idx :throttle)
       (get-axis-default-value :throttle axes))
  (put state
       (joystick-position-idx :rudder)
       (get-axis-default-value :rudder axes))
  (put state
       (joystick-position-idx :aileron)
       (get-axis-default-value :aileron axes))
  (put state
       (joystick-position-idx :x)
       (get-axis-default-value :x axes))
  (put state
       (joystick-position-idx :y)
       (get-axis-default-value :y axes))
  (put state
       (joystick-position-idx :z)
       (get-axis-default-value :z axes))
  (put state
       (joystick-position-idx :rx)
       (get-axis-default-value :rx axes))
  (put state
       (joystick-position-idx :ry)
       (get-axis-default-value :ry axes))
  (put state
       (joystick-position-idx :rz)
       (get-axis-default-value :rz axes))
  (put state
       (joystick-position-idx :slider0)
       (get-axis-default-value :slider0 axes))
  (put state
       (joystick-position-idx :slider1)
       (get-axis-default-value :slider1 axes))
  (put state
       (joystick-position-idx :wheel)
       (get-axis-default-value :wheel axes))
  (put state
       (joystick-position-idx :accelerator)
       (get-axis-default-value :accelerator axes))
  (put state
       (joystick-position-idx :brake)
       (get-axis-default-value :brake axes))
  (put state
       (joystick-position-idx :clutch)
       (get-axis-default-value :clutch axes))
  (put state
       (joystick-position-idx :steering)
       (get-axis-default-value :steering axes))

  (put state (joystick-position-idx :vx) 0)
  (put state (joystick-position-idx :vy) 0)

  (put state (joystick-position-idx :buttons0) 0)

  (put state (joystick-position-idx :hats0) -1)
  (put state (joystick-position-idx :hats1) -1)
  (put state (joystick-position-idx :hats2) -1)
  (put state (joystick-position-idx :hats3) -1)

  (put state (joystick-position-idx :buttons1) 0)
  (put state (joystick-position-idx :buttons2) 0)
  (put state (joystick-position-idx :buttons3) 0)

  (put state (joystick-position-idx :vz) 0)
  
  (put state (joystick-position-idx :vbrx) 0)
  (put state (joystick-position-idx :vbry) 0)
  (put state (joystick-position-idx :vbrz) 0)

  (update dev))


(defn acquire
  ```Tries to acquire the vJoy device with the specified ID. If
  reset? argument is truthy (the default), also resets the device.
  Returns a device object containing these keys:

  :id:       The device ID.
  :controls: Info of available controls, as returned by get-controls.
  :state:    The current control states to feed to the underlying vJoy device.```
  [id &opt reset?]

  (default reset? true)

  (unless (dyn *vjoy-skip-device-check*)
    (check-device id))

  (def stat (call-vjoy-interface 'GetVJDStatus id))
  (unless (or (= stat VJD_STAT_OWN)
              (= stat VJD_STAT_FREE))
    (errorf "bad vjoy device status: %n" stat))

  (when (>= 0 (call-vjoy-interface 'AcquireVJD id))
    (errorf "failed to acquire vjoy device #%n" id))

  (def controls
    (with-dyns [*vjoy-skip-device-check* true]
      (get-controls id)))

  (def dev
    @{:id id
      :controls controls
      # See JOYSTICK_POSITION
      :state (array/new-filled 31 0)})
  (put (in dev :state) 0 id)

  (when reset?
    (reset dev))

  (def pos-struct (in (get-vjoy-structs) 'JOYSTICK_POSITION))
  (def pos-buf (buffer/new-filled (ffi/size pos-struct)))
  (call-vjoy-interface 'GetPosition id pos-buf)
  (put dev :state (array ;(ffi/read pos-struct pos-buf)))

  dev)


(defn relinquish
  ```Releases the specified vJoy device object.```
  [dev]

  (def id (in dev :id))
  (call-vjoy-interface 'RelinquishVJD id))


(defn set-button
  ```Changes the state of the button specified by btn-id. The button
  will be pressed down when value is truthy, and released otherwise.```
  [dev btn-id value]

  (unless (and (int? btn-id)
               (< 0 btn-id)
               (>= 128 btn-id))
    (errorf "invalid button #%n for vjoy device #%n" btn-id (in dev :id)))

  (def [field bits]
    (cond
      (>= 32 btn-id)
      [:buttons0 (- btn-id 1)]

      (>= 64 btn-id)
      [:buttons1 (- btn-id 33)]

      (>= 96 btn-id)
      [:buttons2 (- btn-id 65)]

      true
      [:buttons3 (- btn-id 97)]))

  (def state (in dev :state))
  (def idx (joystick-position-idx field))
  (def field-val (in state idx))

  (if value
    (put state idx (bor field-val (blshift 1 bits)))
    (put state idx (band field-val (bnot (blshift 1 bits))))))


(defn set-axis
  ```Changes the reported value of the axis specified by axis-name.
  Value should be an integer within the range specified by the
  :controls property in dev object. These axis names are available:

  :x
  :y
  :z
  :rx
  :ry
  :rz
  :slider0
  :slider1
  :wheel
  :accelerator
  :brake
  :clutch
  :steering
  :aileron
  :rudder
  :throttle
  ```
  [dev axis-name value]

  (def controls (in dev :controls))
  (def axes (in controls :axes))
  (def axis-setting (in axes axis-name))

  (unless axis-setting
    (errorf "invalid %n axis for vjoy device #%n" axis-name (in dev :id)))

  (def [amin amax] axis-setting)
  (unless (and (int? value)
               (<= amin value)
               (>= amax value))
    (errorf "invalid value %n for %n axis of vjoy device #%n" value axis-name (in dev :id)))

  (def state (in dev :state))
  (def idx (joystick-position-idx axis-name))
  (put state idx value))


(defn set-discrete-pov
  ```Changes the state of the discrete POV switch specified by
  pov-id. Value can be :north, :east, :south, :west or :neutral.```
  [dev pov-id value]

  (def controls (in dev :controls))
  (def pov-num (in controls :discrete-povs))

  (unless (and (int? pov-id)
               (< 0 pov-id)
               (<= pov-id pov-num))
    (errorf "invalid discrete pov switch #%n for vjoy device #%n" pov-id (in dev :id)))

  (def [field bits]
    (cond
      (>= 8 pov-id)
      [:hats0 (* 4 (- pov-id 1))]

      (>= 16 pov-id)
      [:hats1 (* 4 (- pov-id 9))]

      (>= 24 pov-id)
      [:hats2 (* 4 (- pov-id 17))]

      true
      [:hats3 (* 4 (- pov-id 25))]))

  (def state (in dev :state))
  (def idx (joystick-position-idx field))
  (def field-val (in state idx))
  (def num-val
    (case value
      :north 0
      :east  1
      :south 2
      :west  3
      :neutral 0xf
      (errorf "invalid value %n for discrete pov switch #%n of vjoy device %n" value pov-id (in dev :id))))
  (put state idx (bor (blshift num-val bits)
                      (band field-val (bnot (blshift 0xf bits))))))


(defn set-continuous-pov
  ```Changes the state of the continuous POV switch specified by
  pov-id. Value can be :neutral or an integer between 0 and 35999
  (in 1/100 degrees).```
  [dev pov-id value]

  (def controls (in dev :controls))
  (def pov-num (in controls :continuous-povs))

  (unless (and (int? pov-id)
               (< 0 pov-id)
               (<= pov-id pov-num))
    (errorf "invalid continuous pov switch #%n for vjoy device #%n" pov-id (in dev :id)))

  (def field
    (case pov-id
      1 :hats0
      2 :hats1
      3 :hats2
      4 :hats3
      (errorf "invalid continuous pov switch #%n for vjoy device #%n" pov-id (in dev :id))))

  (def state (in dev :state))
  (def idx (joystick-position-idx field))
  (def to-set
    (if (= value :neutral)
      -1
      value))
  (put state idx to-set))


(def device-cache @{})

(defn get-device [id]
  (if-let [dev (in device-cache id)]
    dev
    (do
      (def dev (acquire id))
      (put device-cache id dev)
      dev)))
