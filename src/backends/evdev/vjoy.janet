(import ./evdev)
(import ../../log)


######### Helpers #########

(def axis-id-to-name
  @{evdev/ABS_X        :x
    evdev/ABS_Y        :y
    evdev/ABS_Z        :z
    evdev/ABS_RX       :rx
    evdev/ABS_RY       :ry
    evdev/ABS_RZ       :rz
    evdev/ABS_THROTTLE :throttle
    evdev/ABS_RUDDER   :rudder
    evdev/ABS_WHEEL    :wheel
    evdev/ABS_GAS      :gas
    evdev/ABS_BRAKE    :brake
    evdev/ABS_HAT0X    :hat0x
    evdev/ABS_HAT0Y    :hat0y
    evdev/ABS_HAT1X    :hat1x
    evdev/ABS_HAT1Y    :hat1y
    evdev/ABS_HAT2X    :hat2x
    evdev/ABS_HAT2Y    :hat2y
    evdev/ABS_HAT3X    :hat3x
    evdev/ABS_HAT3Y    :hat3y
    evdev/ABS_PRESSURE :pressure
    evdev/ABS_DISTANCE :distance
    evdev/ABS_TILT_X   :tilt-x
    evdev/ABS_TILT_Y   :tilt-y
    evdev/ABS_TOOL_WIDTH :tool-width
    evdev/ABS_VOLUME   :volume
    evdev/ABS_PROFILE  :profile
    evdev/ABS_MISC     :misc
    evdev/ABS_RESERVED :reserved})


(def axis-name-to-id @{})
(eachp [id name] axis-id-to-name
  (put axis-name-to-id name id))


(def button-id-to-name
  @{evdev/BTN_TRIGGER :trigger
    evdev/BTN_THUMB   :thumb
    evdev/BTN_THUMB2  :thumb2
    evdev/BTN_TOP     :top
    evdev/BTN_TOP2    :top2
    evdev/BTN_PINKIE  :pinkie
    evdev/BTN_BASE    :base
    evdev/BTN_BASE2   :base2
    evdev/BTN_BASE3   :base3
    evdev/BTN_BASE4   :base4
    evdev/BTN_BASE5   :base5
    evdev/BTN_BASE6   :base6
    evdev/BTN_DEAD    :dead
    evdev/BTN_SOUTH   :south
    evdev/BTN_A       :a
    evdev/BTN_EAST    :east
    evdev/BTN_B       :b
    evdev/BTN_C       :c
    evdev/BTN_NORTH   :north
    evdev/BTN_X       :x
    evdev/BTN_WEST    :west
    evdev/BTN_Y       :y
    evdev/BTN_Z       :z
    evdev/BTN_TL      :tl
    evdev/BTN_TR      :tr
    evdev/BTN_TL2     :tl2
    evdev/BTN_TR2     :tr2
    evdev/BTN_SELECT  :select
    evdev/BTN_START   :start
    evdev/BTN_MODE    :mode
    evdev/BTN_THUMBL  :thumbl
    evdev/BTN_THUMBR  :thumbr})


(def button-name-to-id @{})
(eachp [id name] button-id-to-name
  (put button-name-to-id name id))


(defn get-controls [uinput-dev]
  (def devnode (evdev/call-interface 'uinput_get_devnode uinput-dev))
  (log/debug "devnode = %n" devnode)
  (when (nil? devnode)
    (error "failed to locate devnode"))

  (with [dev-fd
         (evdev/open-rd-nonblock devnode)
         evdev/close]
    (def buf (buffer/new-filled (ffi/size :ptr)))
    (def ret (evdev/call-interface 'new_from_fd dev-fd buf))
    (when (< ret 0)
      (errorf "failed to create evdev from devnode %n: %n" devnode ret))

    (def evd (ffi/read :ptr buf))
    (def absinfo-struct (in (evdev/get-structs) 'input_absinfo))
    (def axes @{})
    (for ac evdev/JS-ABS-AXIS-MIN evdev/JS-ABS-AXIS-MAX
      (when (< 0 (evdev/call-interface 'has_event_code evd evdev/EV_ABS ac))
        (def info-ptr (evdev/call-interface 'get_abs_info evd ac))
        (unless (nil? info-ptr)
          (def absinfo (ffi/read absinfo-struct info-ptr))
          (log/debug "absinfo = %n" absinfo)
          (def [_value minimum maximum _fuzz _flat _resolution] absinfo)
          (put axes (in axis-id-to-name ac) [minimum maximum]))))

    (def buttons @[])
    (for bc evdev/JS-BTN-MIN evdev/JS-BTN-MAX
      (def btn-name (in button-id-to-name bc))
      (when (and btn-name
                 (< 0 (evdev/call-interface 'has_event_code evd evdev/EV_KEY bc)))
        (array/push buttons btn-name)))

    {:buttons (length buttons)
     :button-names buttons
     :discrete-povs 0
     :continuous-povs 0
     :axes axes}))


######### High-Level Interface #########

(defn update [dev &opt buf]
  # TODO
  )


(defn reset [dev]
  # TODO
  )


(var vjoy-devs @{})

(defn acquire [id &opt reset?]
  (default reset? true)

  (def dev
    (if-let [dev (in vjoy-devs id)]
      dev
      # else
      (do
        (def uinput-dev (evdev/create-uinput-device :joystick))
        (def dev
          @{:id id
            :dev uinput-dev
            :controls (get-controls uinput-dev)
            :pending-events @[]})
        (put vjoy-devs id dev)
        dev)))

  (when reset?
    (reset dev))

  dev)


(defn relinquish [dev]
  (def id (in dev :id))
  (put vjoy-devs id nil)
  (evdev/call-interface 'uinput_destroy (in dev :dev)))


(defn set-button [dev btn-id value]
  # TODO
  )


(defn set-axis [dev axis-name value]
  # TODO
  )


(defn set-discrete-pov [dev pov-id value]
  # TODO
  )


(defn set-continuous-pov [dev pov-id value]
  # TODO
  )


(defn get-device [id]
  # (acquire id) always resets the device. Here we don't want to reset
  # it when it already exists.
  (if-let [dev (in vjoy-devs id)]
    dev
    (acquire id)))
