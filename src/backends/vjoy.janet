(compwhen
 (= :windows (os/which))

 (import ./win32/vjoy :prefix "" :export true))
