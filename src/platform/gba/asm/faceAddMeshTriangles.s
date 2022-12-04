#include "common_asm.inc"

polys       .req r0     // arg
count       .req r1     // arg
vp          .req r2
vg0         .req r3
vg1         .req r4
vg2         .req r5
vg3         .req r6
// FIQ regs
flags       .req r8
vp0         .req r9
vp1         .req r10
vp2         .req r11
vertices    .req r12
ot          .req r13
face        .req r14

vx0         .req vg0
vy0         .req vg1
vx1         .req vg2
vy1         .req vg3
vx2         .req vg2
vy2         .req vg2

depth       .req vg0

tmp         .req flags
next        .req vp0

.global faceAddMeshTriangles_asm
faceAddMeshTriangles_asm:
    stmfd sp!, {r4-r6}
    fiq_on

    ldr vp, =gVerticesBase
    ldr vp, [vp]

    ldr face, =gFacesBase
    ldr face, [face]

    ldr ot, =gOT
    ldr vertices, =gVertices
    lsr vertices, #3

    add polys, #2   // skip flags

.loop:
    ldrh vp0, [polys], #2
    ldrh vp2, [polys], #4   // + flags

    lsr vp1, vp0, #8
    and vp0, #0xFF
    and vp2, #0xFF

    add vp0, vp, vp0, lsl #3
    add vp1, vp, vp1, lsl #3
    add vp2, vp, vp2, lsl #3

    CCW .skip

    // fetch [c, g, zz]
    ldr vg0, [vp0, #VERTEX_Z]
    ldr vg1, [vp1, #VERTEX_Z]
    ldr vg2, [vp2, #VERTEX_Z]

    // check clipping
    and tmp, vg0, vg1
    and tmp, vg2
    tst tmp, #(CLIP_DISCARD << 16)
    bne .skip

    // mark if should be clipped by viewport
    orr tmp, vg0, vg1
    orr tmp, vg2
    tst tmp, #(CLIP_FRAME << 16)
    ldrh flags, [polys, #-8]
    orrne flags, #FACE_CLIPPED

    // depth = AVG_Z3
    lsl vg0, #16                    // clip g part (high half)
    add depth, vg0, vg1, lsl #16    // depth = vz0 + vz1
    add depth, vg2, lsl #17         // depth += vz2 * 2
    lsr depth, #(16 + 2)            // depth /= 4

    // faceAdd
    rsb vp0, vertices, vp0, lsr #3
    rsb vp1, vertices, vp1, lsr #3
    rsb vp2, vertices, vp2, lsr #3

    orr vp1, vp0, vp1, lsl #16

    orr flags, #FACE_TRIANGLE

    ldr next, [ot, depth, lsl #2]
    str face, [ot, depth, lsl #2]
    stmia face!, {flags, next, vp1, vp2}
.skip:
    subs count, #1
    bne .loop

    ldr tmp, =gFacesBase
    str face, [tmp]

    fiq_off
    ldmfd sp!, {r4-r6}
    bx lr
