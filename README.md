To implement a hardware-efficient CORDIC engine to compute sine and cosine from an 
angle input expressed in fixed-point arithmetic format. The goal is a fully synthesizable 
Verilog design that accepts angles across an extended range (−2π … +4π) using a small 
lookup table and only shifters/adders — so it fits well on FPGAs where multipliers are 
costly. A quadrant mapper normalizes input angles into the CORDIC’s convergence range 
and supplies sign flags, so the CORDIC core always works on a small angle.
