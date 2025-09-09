(compwhen
 (= :windows (os/which))

 (import ./win32/kbd :prefix "" :export true))


(compwhen
 (= :linux (os/which))

 (import ./evdev/kbd :prefix "" :export true))
