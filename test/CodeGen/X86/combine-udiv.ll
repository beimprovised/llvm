; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc < %s -mtriple=x86_64-unknown-unknown -mattr=+sse4.1 | FileCheck %s --check-prefix=SSE
; RUN: llc < %s -mtriple=x86_64-unknown-unknown -mattr=+avx2 | FileCheck %s --check-prefix=AVX

; fold (udiv undef, x) -> 0
define <4 x i32> @combine_vec_udiv_undef0(<4 x i32> %x) {
; SSE-LABEL: combine_vec_udiv_undef0:
; SSE:       # BB#0:
; SSE-NEXT:    retq
;
; AVX-LABEL: combine_vec_udiv_undef0:
; AVX:       # BB#0:
; AVX-NEXT:    retq
  %1 = udiv <4 x i32> undef, %x
  ret <4 x i32> %1
}

; fold (udiv x, undef) -> undef
define <4 x i32> @combine_vec_udiv_undef1(<4 x i32> %x) {
; SSE-LABEL: combine_vec_udiv_undef1:
; SSE:       # BB#0:
; SSE-NEXT:    retq
;
; AVX-LABEL: combine_vec_udiv_undef1:
; AVX:       # BB#0:
; AVX-NEXT:    retq
  %1 = udiv <4 x i32> %x, undef
  ret <4 x i32> %1
}

; fold (udiv x, (1 << c)) -> x >>u c
define <4 x i32> @combine_vec_udiv_by_pow2a(<4 x i32> %x) {
; SSE-LABEL: combine_vec_udiv_by_pow2a:
; SSE:       # BB#0:
; SSE-NEXT:    psrld $2, %xmm0
; SSE-NEXT:    retq
;
; AVX-LABEL: combine_vec_udiv_by_pow2a:
; AVX:       # BB#0:
; AVX-NEXT:    vpsrld $2, %xmm0, %xmm0
; AVX-NEXT:    retq
  %1 = udiv <4 x i32> %x, <i32 4, i32 4, i32 4, i32 4>
  ret <4 x i32> %1
}

define <4 x i32> @combine_vec_udiv_by_pow2b(<4 x i32> %x) {
; SSE-LABEL: combine_vec_udiv_by_pow2b:
; SSE:       # BB#0:
; SSE-NEXT:    pextrd $1, %xmm0, %eax
; SSE-NEXT:    shrl $2, %eax
; SSE-NEXT:    pextrd $2, %xmm0, %ecx
; SSE-NEXT:    pextrd $3, %xmm0, %edx
; SSE-NEXT:    pinsrd $1, %eax, %xmm0
; SSE-NEXT:    shrl $3, %ecx
; SSE-NEXT:    pinsrd $2, %ecx, %xmm0
; SSE-NEXT:    shrl $4, %edx
; SSE-NEXT:    pinsrd $3, %edx, %xmm0
; SSE-NEXT:    retq
;
; AVX-LABEL: combine_vec_udiv_by_pow2b:
; AVX:       # BB#0:
; AVX-NEXT:    vpextrd $1, %xmm0, %eax
; AVX-NEXT:    shrl $2, %eax
; AVX-NEXT:    vpinsrd $1, %eax, %xmm0, %xmm1
; AVX-NEXT:    vpextrd $2, %xmm0, %eax
; AVX-NEXT:    shrl $3, %eax
; AVX-NEXT:    vpinsrd $2, %eax, %xmm1, %xmm1
; AVX-NEXT:    vpextrd $3, %xmm0, %eax
; AVX-NEXT:    shrl $4, %eax
; AVX-NEXT:    vpinsrd $3, %eax, %xmm1, %xmm0
; AVX-NEXT:    retq
  %1 = udiv <4 x i32> %x, <i32 1, i32 4, i32 8, i32 16>
  ret <4 x i32> %1
}

; fold (udiv x, (shl c, y)) -> x >>u (log2(c)+y) iff c is power of 2
define <4 x i32> @combine_vec_udiv_by_shl_pow2a(<4 x i32> %x, <4 x i32> %y) {
; SSE-LABEL: combine_vec_udiv_by_shl_pow2a:
; SSE:       # BB#0:
; SSE-NEXT:    paddd {{.*}}(%rip), %xmm1
; SSE-NEXT:    movdqa %xmm1, %xmm2
; SSE-NEXT:    psrldq {{.*#+}} xmm2 = xmm2[12,13,14,15],zero,zero,zero,zero,zero,zero,zero,zero,zero,zero,zero,zero
; SSE-NEXT:    movdqa %xmm0, %xmm3
; SSE-NEXT:    psrld %xmm2, %xmm3
; SSE-NEXT:    movdqa %xmm1, %xmm2
; SSE-NEXT:    psrlq $32, %xmm2
; SSE-NEXT:    movdqa %xmm0, %xmm4
; SSE-NEXT:    psrld %xmm2, %xmm4
; SSE-NEXT:    pblendw {{.*#+}} xmm4 = xmm4[0,1,2,3],xmm3[4,5,6,7]
; SSE-NEXT:    pxor %xmm2, %xmm2
; SSE-NEXT:    pmovzxdq {{.*#+}} xmm3 = xmm1[0],zero,xmm1[1],zero
; SSE-NEXT:    punpckhdq {{.*#+}} xmm1 = xmm1[2],xmm2[2],xmm1[3],xmm2[3]
; SSE-NEXT:    movdqa %xmm0, %xmm2
; SSE-NEXT:    psrld %xmm1, %xmm2
; SSE-NEXT:    psrld %xmm3, %xmm0
; SSE-NEXT:    pblendw {{.*#+}} xmm0 = xmm0[0,1,2,3],xmm2[4,5,6,7]
; SSE-NEXT:    pblendw {{.*#+}} xmm0 = xmm0[0,1],xmm4[2,3],xmm0[4,5],xmm4[6,7]
; SSE-NEXT:    retq
;
; AVX-LABEL: combine_vec_udiv_by_shl_pow2a:
; AVX:       # BB#0:
; AVX-NEXT:    vpbroadcastd {{.*}}(%rip), %xmm2
; AVX-NEXT:    vpaddd %xmm2, %xmm1, %xmm1
; AVX-NEXT:    vpsrlvd %xmm1, %xmm0, %xmm0
; AVX-NEXT:    retq
  %1 = shl <4 x i32> <i32 4, i32 4, i32 4, i32 4>, %y
  %2 = udiv <4 x i32> %x, %1
  ret <4 x i32> %2
}

define <4 x i32> @combine_vec_udiv_by_shl_pow2b(<4 x i32> %x, <4 x i32> %y) {
; SSE-LABEL: combine_vec_udiv_by_shl_pow2b:
; SSE:       # BB#0:
; SSE-NEXT:    pslld $23, %xmm1
; SSE-NEXT:    paddd {{.*}}(%rip), %xmm1
; SSE-NEXT:    cvttps2dq %xmm1, %xmm2
; SSE-NEXT:    pmulld {{.*}}(%rip), %xmm2
; SSE-NEXT:    pextrd $1, %xmm0, %eax
; SSE-NEXT:    pextrd $1, %xmm2, %ecx
; SSE-NEXT:    xorl %edx, %edx
; SSE-NEXT:    divl %ecx
; SSE-NEXT:    movl %eax, %ecx
; SSE-NEXT:    movd %xmm0, %eax
; SSE-NEXT:    movd %xmm2, %esi
; SSE-NEXT:    xorl %edx, %edx
; SSE-NEXT:    divl %esi
; SSE-NEXT:    movd %eax, %xmm1
; SSE-NEXT:    pinsrd $1, %ecx, %xmm1
; SSE-NEXT:    pextrd $2, %xmm0, %eax
; SSE-NEXT:    pextrd $2, %xmm2, %ecx
; SSE-NEXT:    xorl %edx, %edx
; SSE-NEXT:    divl %ecx
; SSE-NEXT:    pinsrd $2, %eax, %xmm1
; SSE-NEXT:    pextrd $3, %xmm0, %eax
; SSE-NEXT:    pextrd $3, %xmm2, %ecx
; SSE-NEXT:    xorl %edx, %edx
; SSE-NEXT:    divl %ecx
; SSE-NEXT:    pinsrd $3, %eax, %xmm1
; SSE-NEXT:    movdqa %xmm1, %xmm0
; SSE-NEXT:    retq
;
; AVX-LABEL: combine_vec_udiv_by_shl_pow2b:
; AVX:       # BB#0:
; AVX-NEXT:    vmovdqa {{.*#+}} xmm2 = [1,4,8,16]
; AVX-NEXT:    vpsllvd %xmm1, %xmm2, %xmm1
; AVX-NEXT:    vpextrd $1, %xmm1, %ecx
; AVX-NEXT:    vpextrd $1, %xmm0, %eax
; AVX-NEXT:    xorl %edx, %edx
; AVX-NEXT:    divl %ecx
; AVX-NEXT:    movl %eax, %ecx
; AVX-NEXT:    vmovd %xmm1, %esi
; AVX-NEXT:    vmovd %xmm0, %eax
; AVX-NEXT:    xorl %edx, %edx
; AVX-NEXT:    divl %esi
; AVX-NEXT:    vmovd %eax, %xmm2
; AVX-NEXT:    vpinsrd $1, %ecx, %xmm2, %xmm2
; AVX-NEXT:    vpextrd $2, %xmm1, %ecx
; AVX-NEXT:    vpextrd $2, %xmm0, %eax
; AVX-NEXT:    xorl %edx, %edx
; AVX-NEXT:    divl %ecx
; AVX-NEXT:    vpinsrd $2, %eax, %xmm2, %xmm2
; AVX-NEXT:    vpextrd $3, %xmm1, %ecx
; AVX-NEXT:    vpextrd $3, %xmm0, %eax
; AVX-NEXT:    xorl %edx, %edx
; AVX-NEXT:    divl %ecx
; AVX-NEXT:    vpinsrd $3, %eax, %xmm2, %xmm0
; AVX-NEXT:    retq
  %1 = shl <4 x i32> <i32 1, i32 4, i32 8, i32 16>, %y
  %2 = udiv <4 x i32> %x, %1
  ret <4 x i32> %2
}
