; Kerf Test — EasyGRBL
; 6 horizontal lines × 10 mm long
; Spacing: 2 mm
; Power ramp: 10%, 30%, 50%, 70%, 90%, 100%  (max 100%)
; Speed: 3000 mm/min

G21 ; metric
G90 ; absolute
M5 S0 ; laser off
G0 X0 Y0 ; HOME

; 10% power  (S100)
G0 X0 Y0
G0 Z0
M3 S100
G1 X10 F3000
M5

; 30% power  (S300)
G0 X0 Y2
G0 Z0
M3 S300
G1 X10 F3000
M5

; 50% power  (S500)
G0 X0 Y4
G0 Z0
M3 S500
G1 X10 F3000
M5

; 70% power  (S700)
G0 X0 Y6
G0 Z0
M3 S700
G1 X10 F3000
M5

; 90% power  (S900)
G0 X0 Y8
G0 Z0
M3 S900
G1 X10 F3000
M5

; 100% power  (S1000)
G0 X0 Y10
G0 Z0
M3 S1000
G1 X10 F3000
M5

G0 X0 Y0 Z0 ; HOME
M5 S0
; End of Kerf Test
