; Focus Test — EasyGRBL
; 9 horizontal lines × 9 mm long
; Spacing: 1.0 mm
; Z step: 0.10 mm
; Power: 60%  (S153 / S255)
; Speed: 3000 mm/min

G21 ; metric
G90 ; absolute
M5 S0 ; laser off
G0 X0 Y0 ; HOME

; line Y=0  Z=-0.40
G0 X0 Y0
G0 Z-0.40
M4 S153
G1 X9 F3000
M5

; line Y=1  Z=-0.30
G0 X0 Y1
G0 Z-0.30
M4 S153
G1 X9 F3000
M5

; line Y=2  Z=-0.20
G0 X0 Y2
G0 Z-0.20
M4 S153
G1 X9 F3000
M5

; line Y=3  Z=-0.10
G0 X0 Y3
G0 Z-0.10
M4 S153
G1 X9 F3000
M5

; line Y=4  Z=0.00
G0 X0 Y4
G0 Z0.00
M4 S153
G1 X9 F3000
M5

; line Y=5  Z=0.10
G0 X0 Y5
G0 Z0.10
M4 S153
G1 X9 F3000
M5

; line Y=6  Z=0.20
G0 X0 Y6
G0 Z0.20
M4 S153
G1 X9 F3000
M5

; line Y=7  Z=0.30
G0 X0 Y7
G0 Z0.30
M4 S153
G1 X9 F3000
M5

; line Y=8  Z=0.40
G0 X0 Y8
G0 Z0.40
M4 S153
G1 X9 F3000
M5

G0 X0 Y0 Z0 ; HOME
M5 S0
; End of Focus Test
