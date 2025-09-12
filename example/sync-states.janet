#
# This is an example config for Jumper. It shows how to change DroidPad component
# states from the server. To try it out,
#
# 1. Launch Jumper with this config.
# 2. Create a new control pad in DroidPad.
# 3. Add these components to the new pad:
#     * A SWITCH with default identifier "switch"
#     * An LED with default identifier "led"
# 4. Connect to Jumper, and check that the LED responds to switch actions.
# 5. If you have DroidPad installed on more than one device, connect another
#    device to Jumper, and check that the LED and switch states are synchronized
#    between different devices.
#

#
# Our global state, that are synchronized between clients.
#
(var switch-state false)


#
# SWITCH handler
#
(defn handle-switch [msg matched route]
  (set switch-state (in msg "state"))
  (def led-state
    (case switch-state
      true  :on
      false :off))
  #
  # These functions broadcast state update messages. They can only be called
  # inside message handlers, the on-connection handler (see below), or any
  # fiber that's spawned by these handlers.
  #
  # The last boolean argument means whether we should also send the update to
  # the peer that sent the msg we're currently processing (can be omitted,
  # defaults to true).
  #
  # We want to update all LEDs, so the last argument is true.
  (jumper/broadcast-led    "led"    led-state    true)
  # The SWITCH that generated this msg is already updated by user action, so
  # we set the last argument to false (no need to update the current peer).
  (jumper/broadcast-switch "switch" switch-state false))


(def jumper-config
  @{:user-routes   @[
                     @{:id      "switch"
                       :type    "SWITCH"
                       :handler handle-switch}
                    ]
    #
    # This is a user-specified function, to be run when a new connection is
    # established, and before any message processing.
    #
    # Note that the UDP server don't really handle "connections", so this
    # handler will be run right before a client's first message got processed
    # instead. This means UDP clients won't get updated until they sent their
    # first message.
    #
    # Here we simply update the new peer according to our saved state. Instead
    # of broadcasting, jumper/send-* functions only update the current peer.
    :on-connection (fn []
                     (jumper/send-led    "led"    (if switch-state :on :off))
                     (jumper/send-switch "switch" switch-state))})
