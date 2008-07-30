(module rewrite-side-conditions mzscheme
  (require (lib "list.ss")
           "underscore-allowed.ss")
  (require-for-template mzscheme
                        "term.ss"
                        "matcher.ss")
  
  (provide rewrite-side-conditions/check-errs
           extract-names
           make-language-id
           language-id-nts)
  
  (define-values (language-id make-language-id language-id? language-id-get language-id-set) (make-struct-type 'language-id #f 2 0 #f '() #f 0))
  
  (define (language-id-nts stx id) (language-id-getter stx id 1))
  (define (language-id-getter stx id n)
    (unless (identifier? stx)
      (raise-syntax-error id "expected an identifier defined by define-language" stx))
    (let ([val (syntax-local-value stx (λ () #f))])
      (unless (and (set!-transformer? val)
                   (language-id? (set!-transformer-procedure val)))
        (raise-syntax-error id "expected a identifier defined by define-language" stx))
      (language-id-get (set!-transformer-procedure val) n)))
  
  (define (rewrite-side-conditions/check-errs all-nts what bind-names? orig-stx)
    (define (expected-exact name n stx)
      (raise-syntax-error what (format "~a expected to have ~a arguments" 
                                       name
                                       n)
                          orig-stx 
                          stx))
    (define (expected-arguments name stx)
      (raise-syntax-error what (format "~a expected to have arguments" name) orig-stx stx))
    (let loop ([term orig-stx])
      (syntax-case term (side-condition variable-except variable-prefix hole name in-hole in-named-hole hide-hole side-condition cross)
        [(side-condition pre-pat exp)
         (with-syntax ([pat (loop (syntax pre-pat))])
           (let-values ([(names names/ellipses) (extract-names all-nts what bind-names? (syntax pat))])
             (with-syntax ([(name ...) names]
                           [(name/ellipses ...) names/ellipses])
               (syntax/loc term
                 (side-condition
                  pat
                  ,(lambda (bindings)
                     (term-let ([name/ellipses (lookup-binding bindings 'name)] ...)
                               exp)))))))]
        [(side-condition a ...) (expected-exact 'side-condition 2 term)]
        [side-condition (expected-arguments 'side-condition term)]
        [(variable-except a ...) #`(variable-except #,@(map loop (syntax->list (syntax (a ...)))))]
        [variable-except (expected-arguments 'variable-except term)]
        [(variable-prefix a) #`(variable-prefix #,(loop (syntax a)))]
        [(variable-prefix a ...) (expected-exact 'variable-prefix 1 term)]
        [variable-prefix (expected-arguments 'variable-prefix term)]
        [hole term]
        [(hole a) #`(hole #,(loop #'a))]
        [(hole a ...) (raise-syntax-error what "hole expected to stand alone or to have one argument")]
        [(name x y) #`(name #,(loop #'x) #,(loop #'y))]
        [(name x ...) (expected-exact 'name 2 term)]
        [name (expected-arguments 'name term)]
        [(in-hole a b) #`(in-hole #,(loop #'a) #,(loop #'b))]
        [(in-hole a ...) (expected-exact 'in-hole 2 term)]
        [in-hole (expected-arguments 'in-hole term)]
        [(in-named-hole a b c) #`(in-named-hole #,(loop #'a) #,(loop #'b) #,(loop #'c))]
        [(in-named-hole a ...) (expected-exact 'in-named-hole 3 term)]
        [in-named-hole (expected-arguments 'in-named-hole term)]
        [(hide-hole a) #`(hide-hole #,(loop #'a))]
        [(in-named-hole a ...) (expected-exact 'hide-hole 1 term)]
        [in-named-hole (expected-arguments 'hide-hole term)]
        [(cross a) #`(cross #,(loop #'a))]
        [(cross a ...) (expected-exact 'cross 1 term)]
        [cross (expected-arguments 'cross term)]
        [(terms ...)
         (map loop (syntax->list (syntax (terms ...))))]
        [else
         (when (pair? (syntax-e term))
           (let loop ([term term])
             (cond
               [(syntax? term) (loop (syntax-e term))]
               [(pair? term) (loop (cdr term))]
               [(null? term) (void)]
               [#t
                (raise-syntax-error what "dotted pairs not supported in patterns" orig-stx term)])))
         term])))
  
  (define-struct id/depth (id depth))
  
  ;; extract-names : syntax syntax -> (values (listof syntax) (listof syntax[x | (x ...) | ((x ...) ...) | ...]))
  (define (extract-names all-nts what bind-names? orig-stx)
    (let* ([dups
            (let loop ([stx orig-stx]
                       [names null]
                       [depth 0])
              (syntax-case stx (name in-hole in-named-hole side-condition)
                [(name sym pat)
                 (identifier? (syntax sym))
                 (loop (syntax pat) 
                       (cons (make-id/depth (syntax sym) depth) names)
                       depth)]
                [(in-named-hole hlnm sym pat1 pat2)
                 (identifier? (syntax sym))
                 (loop (syntax pat1)
                       (loop (syntax pat2) names depth)
                       depth)]
                [(in-hole pat1 pat2)
                 (loop (syntax pat1)
                       (loop (syntax pat2) names depth)
                       depth)]
                [(side-condition pat e)
                 (loop (syntax pat) names depth)]
                [(pat ...)
                 (let i-loop ([pats (syntax->list (syntax (pat ...)))]
                              [names names])
                   (cond
                     [(null? pats) names]
                     [else 
                      (if (or (null? (cdr pats))
                              (not (identifier? (cadr pats)))
                              (not (or (module-identifier=? (quote-syntax ...)
                                                            (cadr pats))
                                       (let ([inside (syntax-e (cadr pats))])
                                         (regexp-match #rx"^\\.\\.\\._" (symbol->string inside))))))
                          (i-loop (cdr pats)
                                  (loop (car pats) names depth))
                          (i-loop (cdr pats)
                                  (loop (car pats) names (+ depth 1))))]))]
                [x
                 (and (identifier? (syntax x))
                      (binds-in-right-hand-side? all-nts bind-names? (syntax x)))
                 (cons (make-id/depth (syntax x) depth) names)]
                [else names]))]
           [no-dups (filter-duplicates what orig-stx dups)])
      (values (map id/depth-id no-dups)
              (map build-dots no-dups))))
  
  ;; build-dots : id/depth -> syntax[x | (x ...) | ((x ...) ...) | ...]
  (define (build-dots id/depth)
    (let loop ([depth (id/depth-depth id/depth)])
      (cond
        [(zero? depth) (id/depth-id id/depth)]
        [else (with-syntax ([rest (loop (- depth 1))]
                            [dots (quote-syntax ...)])
                (syntax (rest dots)))])))
  
  
  (define (binds-in-right-hand-side? nts bind-names? x)
    (or (and bind-names? (memq (syntax-e x) nts))
        (and bind-names? (memq (syntax-e x) underscore-allowed))
        (let ([str (symbol->string (syntax-e x))])
          (and (regexp-match #rx"_" str)
               (not (regexp-match #rx"^\\.\\.\\._" str))
               (not (regexp-match #rx"_!_" str))))))
  
  (define (filter-duplicates what orig-stx dups)
    (let loop ([dups dups])
      (cond
        [(null? dups) null]
        [else 
         (cons
          (car dups)
          (filter (lambda (x) 
                    (let ([same-id? (module-identifier=? (id/depth-id x)
                                                         (id/depth-id (car dups)))])
                      (when same-id?
                        (unless (equal? (id/depth-depth x)
                                        (id/depth-depth (car dups)))
                          (raise
                           (make-exn:fail:syntax
                            (format "~a: found the same binder, ~s, at different depths, ~a and ~a"
                                    what
                                    (syntax-object->datum (id/depth-id x))
                                    (id/depth-depth x)
                                    (id/depth-depth (car dups)))
                            (current-continuation-marks)
                            (list (id/depth-id x) (id/depth-id (car dups)))))))
                      (not same-id?)))
                  (loop (cdr dups))))]))))