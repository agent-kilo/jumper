(compwhen
 (= :windows (os/which))

 (import ./win32/vjoy :prefix "" :export true))


(compwhen
 (= :linux (os/which))

 (import ./evdev/vjoy :prefix "" :export true))
