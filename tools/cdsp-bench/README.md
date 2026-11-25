# Joyeuse CDSP comparison

`bench_common.h` supplies the same scalar SAD and dot-product kernels to the
A76 executable and the Hexagon shared object. The test reports median A76
compute time, median CDSP RPC time, and median empty-RPC latency for each
kernel. It checks the output before reporting timings.

Build only through the `CDSP benchmark` GitHub Actions workflow. Download its
artifact, put `libarmada_bench_skel.so` under `dsp/cdsp/` in a writable
HexagonFS root, then run the ARM executable as a client of `hexagonrpcd -c`
with the Joyeuse CDSP shell. The device needs the corrected `0x1081` through
`0x1086` context banks before the test can run.
