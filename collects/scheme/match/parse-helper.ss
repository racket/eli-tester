#lang scheme/base

(require (for-template scheme/base)
         syntax/boundmap
         syntax/stx
         scheme/struct-info
         "patterns.ss"
         "compiler.ss"
         (only-in srfi/1 delete-duplicates))

(provide ddk? parse-literal all-vars pattern-var? match:syntax-err 
         match-expander-transform matchable? trans-match parse-struct
         dd-parse parse-quote parse-id)

;; parse x as a match variable
;; x : identifier
(define (parse-id x)  
  (cond [(eq? '_ (syntax-e x))
         (make-Dummy x)]
        [(ddk? x) (raise-syntax-error 'match "incorrect use of ... in pattern" #'x)]
        [else (make-Var x)]))

;; stx : syntax of pattern, starting with quote
;; parse : the parse function
(define (parse-quote stx parse)
  (syntax-case stx (quote)
    [(quote ())
     (make-Null (make-Dummy stx))]
    [(quote (a . b))
     (make-Pair (parse (syntax/loc stx (quote a)))
                (parse (syntax/loc stx (quote b))))]
    [(quote vec)
     (vector? (syntax-e #'vec))
     (make-Vector (for/list ([e (vector->list (syntax-e #'vec))])
                            (parse (quasisyntax/loc stx (quote #,e)))))]
    [(quote bx)
     (vector? (syntax-e #'bx))
     (make-Box (parse (quasisyntax/loc stx (quote #,(syntax-e #'bx)))))]
    [(quote v)
     (or (parse-literal (syntax-e #'v))
         (raise-syntax-error 'match "non-literal in quote pattern" stx #'v))]
    [_
     (raise-syntax-error 'match "syntax error in quote pattern" stx)]))

;; parse : the parse fn
;; p : the repeated pattern
;; dd : the ... stx
;; rest : the syntax for the rest
(define (dd-parse parse p dd rest)
  (let* ([count (ddk? dd)]
         [min (if (number? count) count #f)])
    (make-GSeq 
     (parameterize ([match-...-nesting (add1 (match-...-nesting))])
       (list (list (parse p))))
     (list min)
     ;; no upper bound
     (list #f)
     ;; patterns in p get bound to lists
     (list #f)
     (parse rest))))

;; stx : the syntax object for the whole pattern
;; cert : the certifier
;; parse : the pattern parser
;; struct-name : identifier
;; pats : syntax representing the member patterns
;; returns a pattern
(define (parse-struct stx cert parse struct-name pats)
  (let* ([fail (lambda () 
                 (raise-syntax-error 'match (format "~a does not refer to a structure definition" (syntax->datum struct-name)) stx struct-name))]
         [v (syntax-local-value (cert struct-name) fail)])
    (unless (struct-info? v)
      (fail))
    (let-values ([(id _1 pred acc _2 super) (apply values (extract-struct-info v))])
      ;; this produces a list of all the super-types of this struct
      ;; ending when it reaches the top of the hierarchy, or a struct that we can't access
      (define (get-lineage struct-name)
        (let ([super (list-ref 
                      (extract-struct-info (syntax-local-value struct-name))
                      5)])
          (cond [(equal? super #t) '()] ;; no super type exists
                [(equal? super #f) '()] ;; super type is unknown
                [else (cons super (get-lineage super))])))
      (let* (;; the accessors come in reverse order
             [acc (reverse acc)]
             ;; remove the first element, if it's #f
             [acc (cond [(null? acc) acc] [(not (car acc)) (cdr acc)] [else acc])])
        (make-Struct id pred (get-lineage (cert struct-name)) acc 
                     (if (eq? '_ (syntax-e pats))
                         (map make-Dummy acc)
                         (let* ([ps (syntax->list pats)])
                           (unless (= (length ps) (length acc))
                             (raise-syntax-error 'match (format "wrong number for fields for structure ~a: expected ~a but got ~a"
                                                                (syntax->datum struct-name) (length acc) (length ps))
                                                 stx pats))
                           (map parse ps))))))))

(define (trans-match pred transformer pat)
  (make-And (list (make-Pred pred) (make-App transformer pat))))

;; transform a match-expander application
;; parse/cert : stx certifier -> pattern
;; cert : certifier
;; expander : identifier
;; stx : the syntax of the match-expander application
;; accessor : match-expander -> syntax transformer/#f
;; error-msg : string
;; produces a parsed pattern
(define (match-expander-transform parse/cert cert expander stx accessor error-msg)  
  (let* ([expander (syntax-local-value (cert expander))]
         [transformer (accessor expander)])   
    (unless transformer (raise-syntax-error #f error-msg #'expander))
    (let* ([introducer (make-syntax-introducer)]
           [certifier (match-expander-certifier expander)]
           [mstx (introducer (syntax-local-introduce stx))]
           [mresult (transformer mstx)]
           [result (syntax-local-introduce (introducer mresult))]
           [cert* (lambda (id) (certifier (cert id) #f introducer))])
      (parse/cert result cert*))))

;; can we pass this value to regexp-match?
(define (matchable? e)
  (or (string? e) (bytes? e)))


;; raise an error, blaming stx
(define (match:syntax-err stx msg)
  (raise-syntax-error #f msg stx))

;; pattern-var? : syntax -> bool
;; is p an identifier representing a pattern variable?
(define (pattern-var? p)
  (and (identifier? p)
       (not (ddk? p))))

;; ddk? : syntax -> number or boolean
;; if #f is returned, was not a ddk identifier
;; if #t is returned, no minimum
;; if a number is returned, that's the minimum
(define (ddk? s*)
  (define (./_ c)
    (or (equal? c #\.)
        (equal? c #\_)))
  (let ([s (syntax->datum s*)])
    (and (symbol? s)
         (if (memq s '(... ___)) #t
             (let* ((s (symbol->string s)))                    
               (and (3 . <= . (string-length s))
                    (./_ (string-ref s 0))
                    (./_ (string-ref s 1))                    
                    (let ([n (string->number (substring s 2))])
                      (cond 
                        [(not n) #f]
                        [(zero? n) #t]
                        [(exact-nonnegative-integer? n) n]
                        [else (raise-syntax-error 'match "invalid number for ..k pattern" s*)]))))))))


;; parse-literal : scheme-val -> pat option
;; is v is a literal, return a pattern matching it
;; otherwise, return #f
(define (parse-literal v)
  (if (or (number? v) 
          (string? v) 
          (keyword? v)
          (symbol? v) 
          (bytes? v) 
          (regexp? v)
          (boolean? v)
          (char? v))
      (make-Exact v)
      #f))

;; (listof pat) syntax -> void
;; check that all the ps bind the same set of variables
(define (all-vars ps stx)
  (when (null? ps)
    (error 'bad))
  (let* ([first-vars (bound-vars (car ps))]
         [l (length ps)]
         [ht (make-free-identifier-mapping)])
    (for-each (lambda (v) (free-identifier-mapping-put! ht v 1)) first-vars)
    (for-each (lambda (p) 
                (for-each (lambda (v) 
                            (cond [(free-identifier-mapping-get ht v (lambda () #f)) 
                                   =>
                                   (lambda (n)
                                     (free-identifier-mapping-put! ht v (add1 n)))]
                                  [else (raise-syntax-error 'match "variable not bound in all or patterns" stx v)]))
                          (bound-vars p)))
              (cdr ps))
    (free-identifier-mapping-for-each
     ht
     (lambda (v n)
       (unless (= n l)
         (raise-syntax-error 'match "variable not bound in all or patterns" stx v))))))