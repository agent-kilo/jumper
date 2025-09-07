(compwhen
 (= :windows (os/which))

 (import ./win32/ms :prefix "" :export true))
