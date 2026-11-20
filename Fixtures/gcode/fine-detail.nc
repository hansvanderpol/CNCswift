; CNCswift 1.0
; profile: twotrees-ttc450-pro 1.0.0
; dialect: grbl1_1
; units: mm  origin: stock front-left top
; model: fine-detail.stl
; cutter: 8f3c1d2a-0b7e-4c55-9a1f-2d6e7c8b9a10
; cutter-name: 6mm flat
; cutter-type: flat
; cutting-diameter: 6.000
; shank-diameter: 6.000
; cutting-length: 20.000
; flutes: 2
; cutter-feed: 750.000
; cutter-spindle: 8000
; material: Hardwood (oak/maple)
; material-feed-band: 400.000-600.000
; material-spindle-band: 7000-8000
; feed: 600.000
; spindle: 8000
; rapid-rate: controller 800 (see $110-$112)
; stock: 200.000 x 150.000 x 30.000
; stepover: 2.400
; max-depth: 2.000
; allowance: 0.500
; scale: 1.000
; generated: 2026-11-17T09:12:44Z
;
G21
G90
G94
G00 Z10.0
M3 S8000
G0 X10.000 Y10.000
G1 Z-1.000 F600.000
X12.400
X14.800 Z-1.180
G0 Z10.000
G0 X14.800 Y12.400
G1 Z-1.420 F600.000
X17.200
G0 Z10.000
G90
G00 Z15.0
M5
G00 X0 Y0
M30
