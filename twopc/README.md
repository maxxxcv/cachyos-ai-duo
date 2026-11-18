# Two-computer setup (A = i7-8700, B = i7 11th gen)

1. Install CachyOS from the USB on each computer (or just on A first).
2. Connect the two computers with a network cable (to the same router, or directly to each other).
3. In a terminal on each computer, from this folder:
   - computer A: `bash setup-pair.sh a`
   - computer B: `bash setup-pair.sh b`
4. Check: `bash pair-status.sh`.

What this does: installs the needed packages, names the computers pc-a / pc-b, lets them find each other
automatically (no IP numbers to type), and restricts the pairing ports to the wired network.

What this does NOT do yet: split AI/video work across both CPUs. That part (ggml RPC worker) depends on the
measurements of the `video-gen` session and will be added after it reports (see video-gen/).
