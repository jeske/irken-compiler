;; -*- Mode: llvm -*-

;; --- preamble ---

;; these functions are meant to (roughly) implement the
;;  cps insns, along with some helpers.  The expectation
;;  is that these will all be inlined, resulting in relatively
;;  compact output for compiled functions.

;; XXX consider using llvm.read_register/write_register to keep
;;  lenv or k in %ebp. [especially since llvm doesn't seem to use
;;  it for anything when you -fomit-frame-pointer.

@k	= external global i8**
@lenv	= external global i8**
@result = external global i8**
@top	= external global i8**
@freep	= external global i8**

%struct._string = type { i64, i32, [0 x i8] }

;; with LTO, many/most of these functions could be written in C.

declare void @check_heap()
declare i8** @make_vector (i64 %size, i8** %val)
declare void @vector_range_check (i8** %vec, i64 %index)
declare i8** @record_fetch (i8** %rec, i64 %label)
declare void @record_store (i8** %rec, i64 %label, i8** %val)
declare void @insn_topset (i64 %index, i8** %val)
declare i8** @insn_callocate (i64 %size, i64 %count)
declare void @exit_continuation()
declare void @DO (i8** %ob)
declare void @DENV()
declare i8** @putchar (i64 %ch)
declare void @TRACE(i8* %name)

;; Note: at some point near llvm3/4, they changed the syntax
;;   of some of the insns: at least load/getelementptr. urgh.

define internal i8** @insn_varref(i64 %depth, i64 %index) {
  %1 = load i8**, i8*** @lenv
  %2 = icmp eq i64 %depth, 0
  br i1 %2, label %._crit_edge, label %.lr.ph

.lr.ph:
  %lenv0.02 = phi i8** [ %6, %.lr.ph ], [ %1, %0 ]
  %.01 = phi i64 [ %3, %.lr.ph ], [ %depth, %0 ]
  %3 = add nsw i64 %.01, -1
  %4 = getelementptr inbounds i8*, i8** %lenv0.02, i64 1
  %5 = load i8*, i8** %4
  %6 = bitcast i8* %5 to i8**
  %7 = icmp eq i64 %3, 0
  br i1 %7, label %._crit_edge, label %.lr.ph

._crit_edge:
  %lenv0.0.lcssa = phi i8** [ %1, %0 ], [ %6, %.lr.ph ]
  %8 = add nsw i64 %index, 2
  %9 = getelementptr inbounds i8*, i8** %lenv0.0.lcssa, i64 %8
  %10 = load i8*, i8** %9
  %11 = bitcast i8* %10 to i8**
  ret i8** %11
}

; Function Attrs: nounwind ssp uwtable
define internal void @insn_varset(i64 %depth, i64 %index, i8** %val) {
  %1 = load i8**, i8*** @lenv
  %2 = icmp eq i64 %depth, 0
  br i1 %2, label %._crit_edge, label %.lr.ph

.lr.ph:
  %lenv0.02 = phi i8** [ %6, %.lr.ph ], [ %1, %0 ]
  %.01 = phi i64 [ %3, %.lr.ph ], [ %depth, %0 ]
  %3 = add nsw i64 %.01, -1
  %4 = getelementptr inbounds i8*, i8** %lenv0.02, i64 1
  %5 = load i8*, i8** %4
  %6 = bitcast i8* %5 to i8**
  %7 = icmp eq i64 %3, 0
  br i1 %7, label %._crit_edge, label %.lr.ph

._crit_edge:
  %lenv0.0.lcssa = phi i8** [ %1, %0 ], [ %6, %.lr.ph ]
  %8 = bitcast i8** %val to i8*
  %9 = add nsw i64 %index, 2
  %10 = getelementptr inbounds i8*, i8** %lenv0.0.lcssa, i64 %9
  store i8* %8, i8** %10
  ret void
}

;; consider using llvm.memset to clear allocated space
;;  [and thus remove the need to clear tospace after gc]

define internal i8** @allocate(i64 %tc, i64 %size) {
  %1 = load i8**, i8*** @freep
  %2 = shl i64 %size, 8
  %3 = and i64 %tc, 255
  %4 = or i64 %2, %3
  %5 = inttoptr i64 %4 to i8*
  store i8* %5, i8** %1
  %6 = add nsw i64 %size, 1
  %7 = load i8**, i8*** @freep
  %8 = getelementptr inbounds i8*, i8** %7, i64 %6
  store i8** %8, i8*** @freep
  ret i8** %1
}

define internal i64 @get_case(i8** %ob) {
  %1 = ptrtoint i8** %ob to i64
  %2 = and i64 %1, 3
  %3 = icmp eq i64 %2, 0
  br i1 %3, label %7, label %4

; <label>:4
  %5 = and i64 %1, 1
  %6 = icmp eq i64 %5, 0
  %. = select i1 %6, i64 %1, i64 0
  ret i64 %.

; <label>:7
  %8 = bitcast i8** %ob to i64*
  %9 = load i64, i64* %8
  %10 = and i64 %9, 255
  ret i64 %10
}

define internal void @link_env_with_args (i8** %env, i8** %fun) {
  %1 = getelementptr i8*, i8** %fun, i64 2
  %2 = load i8*, i8** %1
  %3 = getelementptr i8*, i8** %env, i64 1
  store i8* %2, i8** %3
  store i8** %env, i8*** @lenv
  ret void
}

define internal void @link_env_noargs (i8** readonly %fun) {
  %1 = getelementptr inbounds i8*, i8** %fun, i64 2
  %2 = load i8*, i8** %1
  %3 = bitcast i8* %2 to i8**
  store i8** %3, i8*** @lenv
  ret void
}

define internal i8** @fetch (i8*** %src, i64 %off) {
  %1 = load i8**, i8*** %src
  %2 = getelementptr i8*, i8** %1, i64 %off
  %3 = load i8*, i8** %2
  %4 = bitcast i8* %3 to i8**
  ret i8** %4
}

define internal void @push_env (i8** %env)
{
  %1 = load i8**, i8*** @lenv
  %2 = bitcast i8** %1 to i8*
  %3 = getelementptr i8*, i8** %env, i64 1
  store i8* %2, i8** %3
  store i8** %env, i8*** @lenv
  ret void
}

define internal void @pop_env() {
  %1 = load i8**, i8*** @lenv
  %2 = getelementptr inbounds i8*, i8** %1, i64 1
  %3 = load i8*, i8** %2
  %4 = bitcast i8* %3 to i8**
  store i8** %4, i8*** @lenv
  ret void
}

; void
; push_k (object * t, object * fp)
; {
;   t[1] = k;
;   t[2] = lenv;
;   t[3] = fp;
;   k = t;
; }

define internal void @push_k(i8** %t, i8** %fp) {
  %1 = load i8**, i8*** @k
  %2 = bitcast i8** %1 to i8*
  %3 = getelementptr i8*, i8** %t, i64 1
  store i8* %2, i8** %3
  %4 = load i8**, i8*** @lenv
  %5 = bitcast i8** %4 to i8*
  %6 = getelementptr i8*, i8** %t, i64 2
  store i8* %5, i8** %6
  %7 = bitcast i8** %fp to i8*
  %8 = getelementptr i8*, i8** %t, i64 3
  store i8* %7, i8** %8
  store i8** %t, i8*** @k
  ret void
}

; void
; pop_k (void)
; {
;   lenv = k[2];
;   k = k[1];
; }

define internal void @pop_k() {
  %1 = load i8**, i8*** @k
  %2 = getelementptr i8*, i8** %1, i64 2
  %3 = load i8*, i8** %2
  %4 = bitcast i8* %3 to i8**
  store i8** %4, i8*** @lenv
  %5 = getelementptr i8*, i8** %1, i64 1
  %6 = load i8*, i8** %5
  %7 = bitcast i8* %6 to i8**
  store i8** %7, i8*** @k
  ret void
}

define internal i8** @insn_fetch (i8** %ob, i64 %i)
{
  %1 = getelementptr i8*, i8** %ob, i64 %i
  %2 = load i8*, i8** %1
  %3 = bitcast i8* %2 to i8**
  ret i8** %3
}

define internal i8** @insn_topref (i64 %index) {
  %1 = load i8**, i8*** @top
  %2 = add i64 %index, 2 ;; skip lenv:header,next
  %3 = getelementptr i8*, i8** %1, i64 %2
  %4 = load i8*, i8** %3
  %5 = bitcast i8* %4 to i8**
  ret i8** %5
}

define internal i64 @insn_unbox (i8** %val) {
  %1 = ptrtoint i8** %val to i64
  %2 = ashr i64 %1, 1
  ret i64 %2
}

define internal i8** @insn_box (i64 %val) {
  %1 = shl i64 %val, 1
  %2 = or i64 %1, 1
  %3 = inttoptr i64 %2 to i8**
  ret i8** %3
}

define internal i8** @insn_add (i8** %a, i8** %b) {
  %1 = call i64 @insn_unbox (i8** %a)
  %2 = call i64 @insn_unbox (i8** %b)
  %3 = add i64 %1, %2
  %4 = call i8** @insn_box (i64 %3)
  ret i8** %4
}

define internal void @insn_return (i8** %val) {
  store i8** %val, i8*** @result
  %1 = load i8**, i8*** @k
  %2 = getelementptr i8*, i8** %1, i64 3
  %3 = bitcast i8** %2 to void ()**
  %4 = load void ()*, void ()** %3
  tail call void %4()
  ret void
}

define internal void @tail_call (i8** %fun) {
  %1 = getelementptr i8*, i8** %fun, i64 1
  %2 = bitcast i8** %1 to void ()**
  %3 = load void ()*, void ()** %2
  tail call void %3()
  ret void
}

define internal void @insn_store (i8** %dst, i64 %off, i8** %src) {
  %1 = getelementptr i8*, i8** %dst, i64 %off
  %2 = bitcast i8** %src to i8*
  store i8* %2, i8** %1
  ret void
}

define internal i8** @insn_close (void()* %fun) {
  %1 = call i8** @allocate (i64 8, i64 2)
  %2 = getelementptr i8*, i8** %1, i64 1
  %3 = bitcast void()* %fun to i8*
  store i8* %3, i8** %2
  %4 = getelementptr i8*, i8** %1, i64 2
  %5 = load i8**, i8*** @lenv
  %6 = bitcast i8** %5 to i8*
  store i8* %6, i8** %4
  ret i8** %1
}

;; --- generated code follows ---
