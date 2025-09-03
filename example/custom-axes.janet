#
# This is an example config for Jumper. It uses custom code to calculate
# vJoy axis inputs, based on joystick offsets (distance between the neutral
# position and the current position).
#
# To try it out, you need to add two joysticks to your DroidPad config, and
# set their item identifiers to "throttle" and "brake" respectively.
#

#
# The vJoy device we'll make use of.
#
(def VJOY-DEV-ID   1)
#
# The vJoy axis mapped to "throttle" joystick
#
(def THROTTLE-AXIS :slider0)
#
# The vJoy axis mapped to "brake" joystick
#
(def BRAKE-AXIS    :slider1)


#
# Extracts the DroidPad joystick data and updates the specified vJoy axis
# accordingly.
#
(defn joystick-offset-to-axis [msg dev axis-name]
  (def {"x" x
        "y" y}
    msg)
  (def offset (math/sqrt (+ (* x x) (* y y))))
  # Obtain vJoy axis range.
  (def [amin amax] (get-in dev [:controls :axes axis-name]))
  (def arange (- amax amin))
  # Convert DroidPad joystick offset to vJoy axis input.
  (def aval (math/round (+ amin (* offset arange))))
  (vjoy/set-axis dev axis-name aval)
  (vjoy/update dev))


#
# "throttle" joystick handler
#
(defn handle-throttle [msg matched route]
  (joystick-offset-to-axis msg (vjoy/get-device VJOY-DEV-ID) THROTTLE-AXIS))


#
# "brake" joystick handler
#
(defn handle-brake [msg matched route]
  (joystick-offset-to-axis msg (vjoy/get-device VJOY-DEV-ID) BRAKE-AXIS))


#
# Custom rules for matching DroidPad messages.
#
(def user-routes
  @[
    @{:type    "JOYSTICK"
      :id      "throttle"
      :handler handle-throttle}
    @{:type    "JOYSTICK"
      :id      "brake"
      :handler handle-brake}
   ])


(def jumper-config
  {:user-routes user-routes})
