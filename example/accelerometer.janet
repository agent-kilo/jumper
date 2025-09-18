#
# This is an example config for Jumper. It maps angles between accelerometer axes
# and gravity to vJoy axis inputs. In other words, it allows you to use your phone's
# accelerometer as a joystick/wheel/whatever.
#
# With the settings below, you can hold your phone horizontally (in landscape mode).
#
# To try it out, you need to have a DroidPad config with the accelerometer attached.
#

#
# Which accelerometer axis to map to longitudinal input.
#
(def ACCEL-LONG-AXIS "y")
#
# Which accelerometer axis to map to latitudinal input.
#
(def ACCEL-LAT-AXIS  "x")
#
# The angle between the longitudinal axis and gravity, when the phone is in the
# rest position.
#
(def ACCEL-LONG-REST-ANGLE 90)
#
# The angle between the latitudinal axis and gravity, when the phone is in the
# rest position.
#
(def ACCEL-LAT-REST-ANGLE  90)
#
# The angle where longitudinal and latitudinal inputs reach their min/max limits.
# Relative to the rest position.
#
(def ACCEL-LIMIT-ANGLE     30)
#
# Which vJoy device to send inputs to.
#
(def ACCEL-VJOY-DEV-ID     1)


#
# Our handler function for DroidPad ACCELEROMETER messages.
#
(defn handle-accelerometer [msg matched route]
  (log/debug "msg = %n" msg)

  # Extract accelerometer data from DroidPad
  (def {"x" x
        "y" y
        "z" z}
    msg)

  # Calculate gravity
  (def G (math/sqrt ($$ x ** 2 + y ** 2 + z ** 2)))

  # Calculate longitudinal and latitudinal angles, relative to gravity.
  (def long-angle ($$ ,(math/acos ($$ msg[ACCEL-LONG-AXIS] / G)) / math/pi * 180))
  (def lat-angle  ($$ ,(math/acos ($$ msg[ACCEL-LAT-AXIS] / G)) / math/pi * 180))

  (log/debug "G = %n, long-angle = %n, lat-angle = %n" G long-angle lat-angle)

  # Adjust for rest position.
  (def long ($$ long-angle - ACCEL-LONG-REST-ANGLE))
  (def lat  ($$ lat-angle - ACCEL-LAT-REST-ANGLE))

  (log/debug "long = %n, lat = %n" long lat)

  # Obtain info from vJoy axes.
  (def dev (vjoy/get-device ACCEL-VJOY-DEV-ID))
  (def [ax-min ax-max] (get-in dev [:controls :axes :x]))
  (def [ay-min ay-max] (get-in dev [:controls :axes :y]))
  (def ax-half-range   (math/floor ($$ (ax-max - ax-min) / 2)))
  (def ax-middle-point (math/round ($$ (ax-max + ax-min) / 2)))
  (def ay-half-range   (math/floor ($$ (ay-max - ay-min) / 2)))
  (def ay-middle-point (math/round ($$ (ay-max + ay-min) / 2)))

  # Convert to vJoy axis inputs.
  (def vjx
    (math/round (- ax-middle-point
                   ($$ ,(cond
                          (< long (- ACCEL-LIMIT-ANGLE)) (- ACCEL-LIMIT-ANGLE)
                          (> long ACCEL-LIMIT-ANGLE)     ACCEL-LIMIT-ANGLE
                          true long) / ACCEL-LIMIT-ANGLE * ax-half-range))))
  (def vjy
    (math/round (- ay-middle-point
                   ($$ ,(cond
                          (< lat (- ACCEL-LIMIT-ANGLE)) (- ACCEL-LIMIT-ANGLE)
                          (> lat ACCEL-LIMIT-ANGLE) ACCEL-LIMIT-ANGLE
                          true lat) / ACCEL-LIMIT-ANGLE * ay-half-range))))

  # Actually update the vJoy device.
  (vjoy/set-axis dev :x vjx)
  (vjoy/set-axis dev :y vjy)
  (vjoy/update dev))


#
# Custom rules for matching DroidPad messages.
#
(def user-routes
  @[
    @{:type    "ACCELEROMETER"
      :handler handle-accelerometer
      # Filters are functions that take a DroidPad message and return a new one.
      # We're using a simple moving average filter function here to smooth out
      # the jitter.
      :filters [(jumper/make-simple-moving-average-filter 4 ["x" "y" "z"])]}
   ])


(def jumper-config
  {:user-routes user-routes})
