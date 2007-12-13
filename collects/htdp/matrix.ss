#lang scheme

;; 4. integrate with snips

(require (lib "matrix-sig.ss" "htdp")
         (lib "matrix-unit.ss" "htdp")
         (lib "matrix-render.ss" "htdp"))

(require (lib "class.ss")
         (lib "string.ss")
         (lib "mred.ss" "mred")
         (lib "cache-image-snip.ss" "mrlib"))

(provide (rename-out (matrix-snip-class snip-class))
         matrix-snip-class%)

;; ---------------------------------------------------------------------------
;(define matrix-snip-class 'missing)
;(define matrix-snip-class% 'missing)

(define (v-m VM) (send VM get-M))
(define (v? VM) (is-a? VM visible-matrix%))

(printf "loading module matrix.ss @ visible-matrix\n")
;; representing a matrix that renders itself as an image, as in image.ss
(define visible-matrix%
  (class cache-image-snip%
    (inherit set-snipclass get-argb)
    (inherit-field dc-proc argb-proc width height argb px py)
    
    (init-field M)
    (define/public (get-M) M)
        
    ;; create a matrix from this instance 
    (define/override (copy)
      (new visible-matrix%
	(M M)
	(width width) (height height) (px px) (py py) (argb argb)
	(dc-proc dc-proc)
	(argb-proc argb-proc)))
        
    (define/override (write f)
      (let ([str (string->bytes/utf-8
		   (format "~s"
		     (list (matrix->rectangle M)
		       (list (argb-vector (get-argb))
			 width
			 px 
			 py))))])
	(send f put str)))
        
    (super-new)
    (set-snipclass matrix-snip-class)))

;; the snip class for matricies 
(define matrix-snip-class% 
  (class cache-image-snip-class% 
    (super-new)
    (define/override (read f)
      (data->snip (read-from-string (send f get-bytes) (lambda () #f))))
    (define/override (data->snip data) 
      (define _ (unless data (error 'read "in matrix-snip-class% failed")))
      (define new-cache-image-snip (super data->snip (cadr data)))
      (define-values (w h) (send new-cache-image-snip get-size))
      (define M (rectangle->matrix (car data)))
      ;; .. but we need to produce a visible-matrix% instead
      M
      #;
      (new visible-matrix% 
	(M M)
	(dc-proc (send new-cache-image-snip get-dc-proc))
	(argb-proc (send new-cache-image-snip get-argb-proc))
	(width w)
	(height h)
	(argb (get-argb new-cache-image-snip))
	(px (get-px new-cache-image-snip))
	(py (get-py new-cache-image-snip))))))
(define get-argb (class-field-accessor cache-image-snip% argb))
(define get-px (class-field-accessor cache-image-snip% px))
(define get-py (class-field-accessor cache-image-snip% py))
    
;; setting up the 'snip class' 
(define matrix-snip-class (new matrix-snip-class%))
(send matrix-snip-class set-version 1)
(send matrix-snip-class set-classname (format "~s" `(lib "matrix.ss" "htdp")))
(send the-drscheme-snip-class #;(get-the-snip-class-list) add matrix-snip-class)

;; ---------------------------------------------------------------------------

(define render@
  (unit 
    (import matrix^)
    (export matrix-render^)
    (define visible? v?)
    (define visible-matrix v-m)

    ;; the graphical stuff follows  .. it is code based on image.ss 
    ;; Matrix -> VisibleMatrix
    (define (make-visible M)
      (define S (matrix-render M))
      (define indent 3)
      (define xspan 3)
      (define-values (row-heights col-widths) (text-sizes S))
      (define th ;; total height of matrix: 2 lines plus the text height
        (+ 2 (apply + row-heights)))
      (define tw ;; total width of matrix: 2 identations, n xspans
        (+ 1 (* 2 indent) (apply + col-widths) (* (length col-widths) xspan)))
      ;; 
      (define (draw-proc mode dc dx dy)
        [define old-mode (send dc get-text-mode)]
        [define old-fore (send dc get-text-foreground)]
        [define old-font (send dc get-font)]
        (send dc set-text-mode mode)
        (send dc set-text-foreground COLOR)
        (send dc set-font (get-font SIZE))
        ;; --- left bracket 
        (send dc draw-line dx dy (+ dx indent) dy)
        (send dc draw-line dx (+ dy th -1) (+ dx indent) (+ dy th -1))
        (send dc draw-line dx dy dx (+ dy th -1))
        ;; --- right bracket 
        (send dc draw-line (+ dx tw (- indent) -1) dy (+ dx tw -1) dy)
        (send dc draw-line (+ dx tw (- indent) -1) (+ dy th -1) (+ dx tw -1) (+ dy th -1))
        (send dc draw-line (+ dx tw -1) dy (+ dx tw -1) (+ dy th -1))
        ;; --- draw all matrix cells 
        (draw-matrix S dc dx dy indent xspan col-widths row-heights)
        (send dc set-text-mode old-mode)
        (send dc set-text-foreground old-fore)
        (send dc set-font old-font))
      ;; 
      (define (argb-proc argb dx dy)
        (define (bm-color-builder dc)
          (define p (send the-pen-list find-or-create-pen "black" 1 'transparent))
          (define b (send the-brush-list find-or-create-brush COLOR 'solid))
          (send dc set-pen p)
          (send dc set-brush b)
          (send dc draw-rectangle 0 0 tw th))
        (define bm-color (build-bitmap bm-color-builder tw th))
        (define(bm-mask-builder dc) (draw-proc 'solid dc 0 0))
        (define bm-mask (build-bitmap bm-mask-builder tw th))
        (overlay-bitmap argb dx dy bm-color bm-mask))
      (new visible-matrix%
           [M M]
           [width tw] [height th] [px 0] [py 0]
           [dc-proc (lambda (dc dx dy) (draw-proc 'transparent dc dx dy))]
           [argb-proc argb-proc]))
    
    ;; [Rectangle String] DC Nat Nat Nat Nat [Listof Nat] [Listof Nat] -> Void
    (define (draw-matrix S dc dx dy indent xspan col-widths row-heights)
      (define dx0 dx)
      (for-each (lambda (row deltay)
                  (set! dx (+ dx0 2 indent))
                  (for-each (lambda (str deltax)
                              (draw-centrally dc str dx dy deltax deltay)
                              (set! dx (+ deltax xspan dx)))
                            row col-widths)
                  (set! dy (+ 2 deltay dy)))
                S row-heights))
    
    ;; basic constants 
    (define SIZE 12)
    (define COLOR (send the-color-database find-color "black"))
    
    ;; String Nat Nat Nat Nat -> Void
    ;; draw str centrally into a (deltax x deltay) rectangle of dc 
    ;; whose upper-left position is (dx,dy)
    (define (draw-centrally dc str dx dy deltax deltay)
      (define-values (w h) (get-text-size SIZE str))
      (define dx* (+ dx (quotient (- deltax w) 2)))
      (define dy* (+ dy (quotient (- deltay h) 2)))
      (send dc draw-text str dx* dy*))
    
    ;; [Rectangle String] ->* [Listof Nat] [Listof Nat]
    ;; determine the height of each row and the width of each column
    (define (text-sizes S)
      (define S-sizes 
        (map (lambda (row)
               (map (lambda (cell) 
                      (define-values (tw th) (get-text-size SIZE cell))
                      (list tw th))
                    row))
             S))
      (define row-heights (map (lambda (r) (apply max (map cadr r))) S-sizes))
      (define col-widths
        (let loop ([S-sizes S-sizes])
          (if (andmap null? S-sizes)
              '()
              (cons (apply max (map car (map car S-sizes)))
                    (loop (map cdr S-sizes))))))
      (values row-heights col-widths))
    
    ;; --- copied from image.ss --- needs refactoring
    (define (get-text-size size string)
      (unless (thread-cell-ref cached-bdc-for-text-size)
        (let* ([bm (make-object bitmap% 1 1)]
               [dc (make-object bitmap-dc% bm)])
          (thread-cell-set! cached-bdc-for-text-size dc)))
      (let ([dc (thread-cell-ref cached-bdc-for-text-size)])
        (let-values ([(w h _1 _2) (send dc get-text-extent string (get-font size))])
          (values (inexact->exact (ceiling w)) 
                  (inexact->exact (ceiling h))))))
    
    (define (get-font size)
      (send the-font-list find-or-create-font size
            'default 'normal 'normal #f
            (case (system-type)
              [(macosx) 'partly-smoothed]
              [else 'smoothed])))
    
    (define cached-bdc-for-text-size (make-thread-cell #f))))

(define invisible-matrix@
  (compound-unit
    (import)
    (export m r)
    (link (((r : matrix-render^)) render@ m)
          (((m : matrix^)) matrix@ r))))

(define-values/invoke-unit invisible-matrix@ (import) (export matrix^))

(provide-signature-elements matrix^)