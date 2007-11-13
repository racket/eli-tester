
;; Based on
;;  (planet "struct.ss" ("ryanc" "macros.plt" 1 0)))

(module define-struct '#%kernel
  (#%require "more-scheme.ss" "small-scheme.ss" "define.ss" "../stxparam.ss"
             (for-syntax '#%kernel "define.ss"
                         "stx.ss" "stxcase-scheme.ss" "small-scheme.ss" 
                         "stxloc.ss" "qqstx.ss"
                         "struct-info.ss"))

  (#%provide define-struct*
             struct-field-index)

  (define-syntax-parameter struct-field-index
    (lambda (stx)
      (raise-syntax-error #f "allowed only within a structure type definition" stx)))

  (define (check-struct-type name what)
    (when what
      (unless (struct-type? what)
        (raise-type-error name "struct-type or #f" what)))
    what)

  (define (check-inspector name what)
    (when what
      (unless (inspector? what)
        (raise-type-error name "inspector or #f" what)))
    what)

  (define-syntax (define-struct* stx)
    (define make-field list)
    (define field-id car)
    (define field-default-value cadr)
    (define field-auto? caddr)
    (define field-mutable? cadddr)

    (define (build-name id . parts)
      (datum->syntax
       id
       (string->symbol
        (apply string-append
               (map (lambda (p)
                      (if (syntax? p)
                          (symbol->string (syntax-e p))
                          p))
                    parts)))
       id))

    (define (bad why kw where)
      (raise-syntax-error
       #f
       (format "~a ~a specification~a"
               why
               (syntax-e kw)
               where)
       stx
       kw))

    (define (check-exprs orig-n ps)
      (let loop ([nps (cdr ps)][n orig-n])
        (unless (zero? n)
          (unless (and (pair? nps)
                       (not (keyword? (syntax-e (car nps)))))
            (raise-syntax-error
             #f
             (format "expected ~a expression~a after keyword~a"
                     orig-n
                     (if (= orig-n 1) "" "s")
                     (if (pair? nps)
                         ", found a keyword"
                         ""))
             stx
             (car ps)))
          (loop (cdr nps) (sub1 n)))))
    
    ;; Parse one field with a sequence of keyword-based specs:
    (define (parse-field f)
      (syntax-case f ()
        [id
         (identifier? #'id)
         (make-field #'id #f #f #f)]
        [(id p ...)
         (identifier? #'id)
         (let loop ([ps (syntax->list #'(p ...))]
                    [def-val #f]
                    [auto? #f]
                    [mutable? #f])
           (cond
            [(null? ps) (make-field #'id def-val auto? mutable?)]
            [(eq? '#:mutable (syntax-e (car ps)))
             (when mutable?
               (bad "redundant" (car ps) " for field"))
             (loop (cdr ps) def-val auto? #t)]
            #;
            [(eq? #:default (syntax-e (car ps)))
             (check-exprs 1 ps)
             (when def-val
               (bad "multiple" (car ps) " for field"))
             (loop (cddr ps) (cadr ps) auto? mutable?)]
            [(eq? '#:auto (syntax-e (car ps)))
             (when auto?
               (bad "redundant" (car ps) " for field"))
             (loop (cdr ps) def-val #t mutable?)]
            [else
             (raise-syntax-error
              #f
              (if (keyword? (syntax-e (car ps)))
                  "unrecognized field-specification keyword"
                  "expected a field-spefication keyword")
              stx
              (car ps))]))]
        [_else
         (raise-syntax-error
          #f
          "expected a field identifier or a parenthesized identifier and field-specification sequence"
          stx
          f)]))

    (define (lookup config s)
      (cdr (assq s config)))

    (define (extend-config config s val)
      (cond
       [(null? config) (error 'struct "internal error: can't find config element: ~s" s)]
       [(eq? (caar config) s) (cons (cons s val) (cdr config))]
       [else (cons (car config) (extend-config (cdr config) s val))]))

    ;; Parse sequence of keyword-based struct specs
    (define (parse-props p super-id)
      (let loop ([p p]
                 [config '((#:super . #f)
                           (#:inspector . #f)
                           (#:auto-value . #f)
                           (#:props . ())
                           (#:mutable . #f)
                           (#:guard . #f)
                           (#:omit-define-values . #f)
                           (#:omit-define-syntaxes . #f))])
        (cond
         [(null? p) config]
         [(eq? '#:super (syntax-e (car p)))
          (check-exprs 1 p)
          (when (lookup config '#:super)
            (bad "multiple" (car p) ""))
          (when super-id
            (raise-syntax-error
             #f
             (string-append
              "#:super specification disallowed because a struct supertype id"
              " was supplied with the struct type id")
             stx
             (car p)))
          (loop (cddr p)
                (extend-config config '#:super (cadr p)))]
         [(memq (syntax-e (car p))
                '(#:inspector #:guard #:auto-value))
          (let ([key (syntax-e (car p))])
            (check-exprs 1 p)
            (when (lookup config key)
              (bad "multiple" (car p) ""))
            (loop (cddr p)
                  (extend-config config key (cadr p))))]
         [(eq? '#:property (syntax-e (car p)))
          (check-exprs 2 p)
          (loop (cdddr p)
                (extend-config config
                               '#:props
                               (cons (cons (cadr p) (caddr p))
                                     (lookup config '#:props))))]
         [(memq (syntax-e (car p))
                '(#:mutable #:omit-define-values #:omit-define-syntaxes))
          (let ([key (syntax-e (car p))])
            (when (lookup config key)
              (bad "redundant" (car p) ""))
            (loop (cdr p)
                  (extend-config config key #t)))]
         [else
          (raise-syntax-error
           #f
           (if (keyword? (syntax-e (car p)))
               "unrecognized struct-specification keyword"
               "expected a struct-spefication keyword")
           stx
           (car p))])))
    
    (syntax-case stx ()
      [(fm id (field ...) prop ...)
       (let-values ([(id super-id)
                     (if (identifier? #'id)
                         (values #'id #f)
                         (syntax-case #'id ()
                           [(id super-id) 
                            (and (identifier? #'id)
                                 (identifier? #'super-id))
                            (values #'id #'super-id)]
                           [else
                            (raise-syntax-error 
                             #f
                             (string-append
                              "expected an identifier for the struct type name, or a parenthesized sequence"
                              " with an identifier followed by the struct supertype identifier")
                             stx)]))])
         (let ([super-info 
                (and super-id
                     (let ([v (syntax-local-value super-id (lambda () #f))])
                       (if (struct-info? v)
                           (extract-struct-info v)
                           (raise-syntax-error
                            #f
                            (format "parent struct type not defined~a"
                                    (if v
                                        (format " (~a does not name struct type information)"
                                                (syntax-e super-id))
                                        ""))
                            stx
                            super-id))))])
           (when (and super-info
                      (not (car super-info)))
             (raise-syntax-error
              #f
              "no structure type descriptor available for supertype"
              stx
              super-id))
           (let* ([field-stxes (syntax->list #'(field ...))]
                  [fields (map parse-field field-stxes)]
                  [dup (check-duplicate-identifier (map field-id fields))])
             (when dup
               (raise-syntax-error
                #f
                "duplicate field identifier"
                stx
                dup))
             (let ([auto-count
                    (let loop ([fields fields] [field-stxes field-stxes] [auto? #f])
                      (cond
                       [(null? fields) 0]
                       [(field-auto? (car fields))
                        (+ 1 (loop (cdr fields) (cdr field-stxes) #t))]
                       [auto?
                        (raise-syntax-error
                         #f
                         "non-auto field after an auto field disallowed"
                         stx
                         (car field-stxes))]
                       [else
                        (loop (cdr fields) (cdr field-stxes) #f)]))])
               (let-values ([(inspector super-expr props auto-val guard mutable?
                                        omit-define-values? omit-define-syntaxes?)
                             (let ([config (parse-props (syntax->list #'(prop ...)) super-id)])
                               (values (lookup config '#:inspector)
                                       (lookup config '#:super)
                                       (lookup config '#:props)
                                       (lookup config '#:auto-value)
                                       (lookup config '#:guard)
                                       (lookup config '#:mutable)
                                       (lookup config '#:omit-define-values)
                                       (lookup config '#:omit-define-syntaxes)))])
                 (when mutable?
                   (for-each (lambda (f f-stx)
                               (when (field-mutable? f)
                                 (raise-syntax-error
                                  #f
                                  "redundant #:mutable specification in field"
                                  stx
                                  f-stx)))
                             fields field-stxes))
                 (let ([struct: (build-name id "struct:" id)]
                       [make- (build-name id "make-" id)]
                       [? (build-name id id "?")]
                       [sels (map (lambda (f)
                                    (build-name id ; (field-id f) 
                                                id "-" (field-id f)))
                                  fields)]
                       [sets (let loop ([fields fields])
                               (cond
                                [(null? fields) null]
                                [(not (or mutable? (field-mutable? (car fields))))
                                 (loop (cdr fields))]
                                [else
                                 (cons (build-name id ; (field-id (car fields))
                                                   "set-"
                                                   id
                                                   "-"
                                                   (field-id (car fields))
                                                   "!")
                                       (loop (cdr fields)))]))]
                       [super-struct: (if super-info
                                          (or (car super-info)
                                              (raise-syntax-error
                                               #f
                                               "no structure type descriptor available for supertype"
                                               stx
                                               super-id))
                                          (and super-expr
                                               #`(check-struct-type 'fm #,super-expr)))])
                   (let ([run-time-defns
                          (lambda ()
                            (quasisyntax/loc stx
                              (define-values (#,struct: #,make- #,? #,@sels #,@sets)
                                (let-values ([(struct: make- ? -ref -set!)
                                              (syntax-parameterize ([struct-field-index
                                                                     (lambda (stx)
                                                                       (syntax-case stx #,(map field-id fields)
                                                                         #,@(let loop ([fields fields][pos 0])
                                                                              (cond
                                                                               [(null? fields) null]
                                                                               [else (cons #`[(_ #,(field-id (car fields))) #'#,pos]
                                                                                           (loop (cdr fields) (add1 pos)))]))
                                                                         [(_ name) (raise-syntax-error #f "no such field" stx #'name)]))])
                                                (make-struct-type '#,id
                                                                  #,super-struct:
                                                                  #,(- (length fields) auto-count)
                                                                  #,auto-count
                                                                  #,auto-val
                                                                  #,(if (null? props)
                                                                        #'null
                                                                        #`(list #,@(map (lambda (p)
                                                                                          #`(cons #,(car p) #,(cdr p)))
                                                                                        props)))
                                                                  #,(if inspector
                                                                        #`(check-inspector 'fm #,inspector)
                                                                        #`(current-inspector))
                                                                  #f
                                                                  '#,(let loop ([i 0]
                                                                                [fields fields])
                                                                       (cond
                                                                        [(null? fields) null]
                                                                        [(field-auto? (car fields)) null]
                                                                        [(not (or mutable? (field-mutable? (car fields))))
                                                                         (cons i (loop (add1 i) (cdr fields)))]
                                                                        [else (loop (add1 i) (cdr fields))]))
                                                                  #,guard))])
                                  (values struct: make- ?
                                          #,@(let loop ([i 0][fields fields])
                                               (if (null? fields)
                                                   null
                                                   (cons #`(make-struct-field-accessor -ref #,i '#,(field-id (car fields)))
                                                         (loop (add1 i) (cdr fields)))))
                                          #,@(let loop ([i 0][fields fields])
                                               (if (null? fields)
                                                   null
                                                   (if (not (or mutable? (field-mutable? (car fields))))
                                                       (loop (add1 i) (cdr fields))
                                                       (cons #`(make-struct-field-mutator -set! #,i '#,(field-id (car fields)))
                                                             (loop (add1 i) (cdr fields)))))))))))]
                         [compile-time-defns
                          (lambda ()
                            (let ([protect (lambda (sel)
                                             (and sel
                                                  (if (syntax-e sel)
                                                      #`(c (quote-syntax #,sel))
                                                      sel)))])
                              (quasisyntax/loc stx
                                (define-syntaxes (#,id)
                                  (let ([c (syntax-local-certifier)])
                                    (make-struct-info
                                     (lambda ()
                                       (list
                                        (c (quote-syntax #,struct:))
                                        (c (quote-syntax #,make-))
                                        (c (quote-syntax #,?))
                                        (list
                                         #,@(map protect (reverse sels))
                                         #,@(if super-info
                                                (map protect (list-ref super-info 3))
                                                (if super-expr
                                                    '(#f)
                                                    null)))
                                        (list
                                         #,@(reverse
                                             (let loop ([fields fields][sets sets])
                                               (cond
                                                [(null? fields) null]
                                                [(not (or mutable? (field-mutable? (car fields))))
                                                 (cons #f (loop (cdr fields) sets))]
                                                [else
                                                 (cons (protect (car sets))
                                                       (loop (cdr fields) (cdr sets)))])))
                                         #,@(if super-info
                                                (map protect (list-ref super-info 4))
                                                (if super-expr
                                                    '(#f)
                                                    null)))
                                        #,(if super-id
                                              (protect super-id)
                                              (if super-expr
                                                  #f
                                                  #t))))))))))])
                     (let ([result
                            (cond
                             [(and (not omit-define-values?) (not omit-define-syntaxes?))
                              #`(begin #,(run-time-defns) #,(compile-time-defns))]
                             [omit-define-syntaxes?
                              (run-time-defns)]
                             [omit-define-values?
                              (compile-time-defns)]
                             [else #'(begin)])])
                       (if super-id
                           (syntax-property result 
                                            'disappeared-use 
                                            (syntax-local-introduce super-id))
                           result)))))))))])))
      