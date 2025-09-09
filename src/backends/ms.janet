(import ../log)


(compwhen
 (= :windows (os/which))

 (import ./win32/ms :prefix "" :export true))


(compwhen
 (= :linux (os/which))

 (import ./evdev/ms :prefix "" :export true))


(var relative-movement-chan nil)

(def RELATIVE-MOVEMENT-INTERVAL 0.01)

(defn get-relative-movement-chan []
  (if relative-movement-chan
    relative-movement-chan
    (do
      (def chan (ev/chan))
      (ev/spawn
       (log/debug "Relative movement fiber started")
       (var msg nil)
       (var last-ts (os/clock :monotonic))
       (var x-speed 0)
       (var y-speed 0)
       (while (set msg
                   (try
                     (ev/with-deadline RELATIVE-MOVEMENT-INTERVAL(ev/take chan))
                     ((err fib)
                      (if (= err "deadline expired")
                        :timeout
                        (propagate err fib)))))
         (match msg
           [:set-speed x-spd y-spd]
           (do
             (set x-speed x-spd)
             (set y-speed y-spd)))
         (def now (os/clock :monotonic))
         (def dt (- now last-ts))
         (when (> dt RELATIVE-MOVEMENT-INTERVAL)
           (set last-ts now)
           (when (and (not= 0 x-speed)
                      (not= 0 y-speed))
             (send-movement (math/round (* x-speed dt))
                            (math/round (* y-speed dt))))))
       (log/debug "last msg = %n" msg)
       (log/debug "Relative movement fiber stopped"))
      (set relative-movement-chan chan))))


(defn start-relative-movement [x-speed y-speed]
  (ev/give (get-relative-movement-chan)
           [:set-speed x-speed y-speed]))


(defn stop-relative-movement []
  (when relative-movement-chan
    (ev/give relative-movement-chan false)
    (set relative-movement-chan nil)))
