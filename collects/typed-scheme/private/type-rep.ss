#lang scheme/base
  
  (require (lib "plt-match.ss"))
  (require (lib "etc.ss") (lib "list.ss"))
  (require "planet-requires.ss" "rep-utils.ss" "effect-rep.ss" "tc-utils.ss"
           "free-variance.ss")
  (require (prefix-in 1: (lib "list.ss" "srfi" "1"))
           (lib "trace.ss")
           (for-syntax scheme/base))
  
  (define name-table (make-hash-table 'weak))
  
  ;; Name = Symbol
  
  ;; Type is defined in rep-utils.ss
  
  ;; t must be a Type
  (dt Scope (t))
  
  ;; i is an nat
  (dt B (i)
      [#:frees empty-hash-table (make-immutable-hash-table (list (cons i Covariant)))]
      [#:fold-rhs #:base])
  
  ;; n is a Name
  (dt F (n) [#:frees (make-immutable-hash-table (list (cons n Covariant))) empty-hash-table] [#:fold-rhs #:base])
  
  ;; id is an Identifier
  (dt Name (id) [#:intern (hash-id id)] [#:frees #f] [#:fold-rhs #:base])
    
  ;; rator is a type
  ;; rands is a list of types
  ;; stx is the syntax of the pair of parens
  (dt App (rator rands stx)
      [#:intern (list rator rands)]
      [#:frees (combine-frees (map free-vars* (cons rator rands)))
               (combine-frees (map free-idxs* (cons rator rands)))]
      [#:fold-rhs (*App (type-rec-id rator)
                        (map type-rec-id rands)
                        stx)])
  
  ;; left and right are Types
  (dt Pair (left right))
  
  ;; elem is a Type
  (dt Vector (elem) [#:frees (make-invariant (free-vars* elem)) (make-invariant (free-idxs* elem))])
  
  ;; elem is a Type
  (dt Box (elem) [#:frees (make-invariant (free-vars* elem)) (make-invariant (free-idxs* elem))])  
  
  ;; name is a Symbol (not a Name)
  (dt Base (name) [#:frees #f] [#:fold-rhs #:base])
  
  ;; body is a Scope
  (dt Mu (body) #:no-provide [#:frees (free-vars* body) (without-below 1 (free-idxs* body))]
      [#:fold-rhs (*Mu (*Scope (type-rec-id (Scope-t body))))])    
  
  ;; n is how many variables are bound here
  ;; body is a Scope
  (dt Poly (n body) #:no-provide [#:frees (free-vars* body) (without-below n (free-idxs* body))]
      [#:fold-rhs (let ([body* (remove-scopes n body)])
                    (*Poly n (add-scopes n (type-rec-id body*))))])
  
  ;; pred : identifier
  ;; cert : syntax certifier
  (dt Opaque (pred cert) [#:intern (hash-id pred)] [#:frees #f] [#:fold-rhs #:base])
  
  ;; name : symbol
  ;; parent : Struct
  ;; flds : Listof[Type]
  ;; proc : Function Type
  (dt Struct (name parent flds proc) 
      [#:frees (combine-frees (map free-vars* (append (if proc (list proc) null) (if parent (list parent) null) flds)))
               (combine-frees (map free-idxs* (append (if proc (list proc) null) (if parent (list parent) null) flds)))]
      [#:fold-rhs (*Struct name 
                           (and parent (type-rec-id parent))
                           (map type-rec-id flds)
                           (and proc (type-rec-id proc)))])
  
  ;; dom : Listof[Type]
  ;; rng : Type
  ;; rest : Type
  ;; thn-eff : Effect
  ;; els-eff : Effect
  ;; arr is NOT a Type
  (dt arr (dom rng rest thn-eff els-eff)
      [#:frees (combine-frees (append (map flip-variances (map free-vars* dom)) 
                                      (map free-vars* (append (list rng) 
                                                              (if rest (list rest) null)
                                                              thn-eff
                                                              els-eff))))
               (combine-frees (append (map flip-variances (map free-idxs* dom))
                                      (map free-idxs* (append (list rng) 
                                                              (if rest (list rest) null)
                                                              thn-eff
                                                              els-eff))))]
      [#:fold-rhs (*arr (map type-rec-id dom)
                        (type-rec-id rng)
                        (and rest (type-rec-id rest))
                        (map effect-rec-id thn-eff)
                        (map effect-rec-id els-eff))])
  
  ;; top-arr is the supertype of all function types
  (dt top-arr ()
      [#:frees #f] [#:fold-rhs #:base])
  
  ;; arities : Listof[arr]
  (dt Function (arities) [#:frees (combine-frees (map free-vars* arities))
                                  (combine-frees (map free-idxs* arities))]
      [#:fold-rhs (*Function (map type-rec-id arities))])
  
  ;; v : Scheme Value
  (dt Value (v) [#:frees #f] [#:fold-rhs #:base])
  
  ;; elems : Listof[Type]
  (dt Union (elems) [#:frees (combine-frees (map free-vars* elems))
                             (combine-frees (map free-idxs* elems))]
      [#:fold-rhs ((unbox union-maker) (map type-rec-id elems))])
  
  (dt Univ () [#:frees #f] [#:fold-rhs #:base])
  
  ;; types : Listof[Type]
  (dt Values (types) [#:frees (combine-frees (map free-vars* types))
                              (combine-frees (map free-idxs* types))]
      [#:fold-rhs (*Values (map type-rec-id types))])
  
  ;; in : Type
  ;; out : Type
  (dt Param (in out))
  
  ;; key : Type
  ;; value : Type
  (dt Hashtable (key value))
  
  ;; t : Type
  (dt Syntax (t))
  
  ;; pos-flds  : (Listof Type)
  ;; name-flds : (Listof (Tuple Symbol Type Boolean))
  ;; methods   : (Listof (Tuple Symbol Function))
  (dt Class (pos-flds name-flds methods)
      [#:frees (combine-frees
                (map free-vars* (append pos-flds 
                                        (map cadr name-flds)
                                        (map cadr methods))))
               (combine-frees
                (map free-idxs* (append pos-flds 
                                        (map cadr name-flds)
                                        (map cadr methods))))]
      
      [#:fold-rhs (match (list pos-flds name-flds methods)
                    [(list
                      pos-tys 
                      (list (list init-names init-tys) ___)
                      (list (list mname mty) ___))
                     (*Class
                      (map type-rec-id pos-tys)
                      (map list
                           init-names
                           (map type-rec-id init-tys))
                      (map list mname (map type-rec-id mty)))])])
  
  ;; cls : Class
  (dt Instance (cls))
  
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  
  ;; Ugly hack - should use units
  
  (define union-maker (box #f))
  
  (define (set-union-maker! v) (set-box! union-maker v))
  
  (provide set-union-maker!)
  
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  
  ;; remove-dups: List[Type] -> List[Type]
  ;; removes duplicate types from a SORTED list
  (define (remove-dups types)
    (cond [(null? types) types]
          [(null? (cdr types)) types]
          [(type-equal? (car types) (cadr types)) (remove-dups (cdr types))]
          [else (cons (car types) (remove-dups (cdr types)))]))
  
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; type/effect fold

(define-syntaxes (type-case effect-case)
  (let ()
    (define (mk ht)
      (lambda (stx)
        (let ([ht (hash-table-copy ht)])
          (define (mk-matcher kw) 
            (datum->syntax stx (string->symbol (string-append (keyword->string kw) ":"))))
          (define (add-clause cl)
            (syntax-case cl ()
              [(kw #:matcher mtch pats ... expr)
               (hash-table-put! ht (syntax-e #'kw) (list #'mtch 
                                                         (syntax/loc cl (pats ...))
                                                         (lambda (tr er) #'expr)))]
              [(kw pats ... expr) 
               (hash-table-put! ht (syntax-e #'kw) (list (mk-matcher (syntax-e #'kw)) 
                                                         (syntax/loc cl (pats ...))
                                                         (lambda (tr er) #'expr)))]))
          (define rid #'type-rec-id)
          (define erid #'effect-rec-id)
          (define (gen-clause k v)
            (define match-ex (car v))
            (define pats (cadr v))
            (define body-f (caddr v))
            (define pat (quasisyntax/loc pats (#,match-ex  . #,pats)))
            (define cl (quasisyntax/loc match-ex (#,pat #,(body-f rid erid))))
            cl)
          (syntax-case stx ()
            [(tc rec-id ty [kw pats ... es] ...)
             #;(andmap (lambda (k) (keyword? (syntax-e k))) (syntax->list #'(kw ...)))
             (syntax/loc stx (tc rec-id (lambda (e) (sub-eff rec-id e)) ty [kw pats ... es] ...))]
            [(tc rec-id e-rec-id ty clauses  ...)
             (begin 
               (map add-clause (syntax->list #'(clauses ...)))
               (with-syntax ([old-rec-id type-rec-id])
                 #`(let ([#,rid rec-id]
                         [#,erid e-rec-id]
                         [#,fold-target ty])
                     ;; then generate the fold
                     #,(quasisyntax/loc stx
                         (match #,fold-target
                           #,@(hash-table-map ht gen-clause))))))]))))
    (values (mk type-name-ht) (mk effect-name-ht))))

(provide type-case effect-case)
  
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    
  
  ;; sub-eff : (Type -> Type) Eff -> Eff
  (define (sub-eff sb eff)
    (effect-case sb eff))  
  
  (define (add-scopes n t)
    (if (zero? n) t
        (add-scopes (sub1 n) (*Scope t))))
  
  (define (remove-scopes n sc)
    (if (zero? n) 
        sc
        (match sc
          [(Scope: sc*) (remove-scopes (sub1 n) sc*)]
          [_ (int-err "Tried to remove too many scopes: ~a" sc)])))
  
  ;; abstract-many : Names Type -> Scope^n 
  ;; where n is the length of names  
  (define (abstract-many names ty)
    (define (nameTo name count type)
      (let loop ([outer 0] [ty type])
        (define (sb t) (loop outer t))
        (type-case 
         sb ty
         [#:F name* (if (eq? name name*) (*B (+ count outer)) ty)]
         ;; necessary to avoid infinite loops
         [#:Union elems (*Union (remove-dups (sort (map sb elems) type<?)))]
         [#:Mu (Scope: body) (*Mu (*Scope (loop (add1 outer) body)))]
         [#:Poly n body* 
                 (let ([body (remove-scopes n body*)])
                   (*Poly n (*Scope (loop (+ n outer) body))))])))
    (let ([n (length names)])
      (let loop ([ty ty] [names names] [count (sub1 n)])
        (if (zero? count)
            (add-scopes n (nameTo (car names) 0 ty))
            (loop (nameTo (car names) count ty)
                  (cdr names)
                  (sub1 count))))))
  
  ;; instantiate-many : List[Type] Scope^n -> Type 
  ;; where n is the length of types  
  (define (instantiate-many images sc)
    (define (replace image count type)
      (let loop ([outer 0] [ty type])
        (define (sb t) (loop outer t))
        (type-case 
         sb ty
         [#:B idx (if (= (+ count outer) idx)
                      image
                      ty)]      
         ;; necessary to avoid infinite loops
         [#:Union elems (*Union (remove-dups (sort (map sb elems) type<?)))]
         [#:Mu (Scope: body) (*Mu (*Scope (loop (add1 outer) body)))]
         [#:Poly n body* 
                 (let ([body (remove-scopes n body*)])
                   (*Poly n (*Scope (loop (+ n outer) body))))])))
    (let ([n (length images)])
      (let loop ([ty (remove-scopes n sc)] [images images] [count (sub1 n)])
        (if (zero? count)
            (replace (car images) 0 ty)
            (loop (replace (car images) count ty)
                  (cdr images)
                  (sub1 count))))))
  
  (define (abstract name ty)
    (abstract-many (list name) ty))
  
  (define (instantiate type sc)
    (instantiate-many (list type) sc))
  
  #;(trace instantiate-many abstract-many)
  
  ;; the 'smart' constructor
  (define (Mu* name body)    
    (let ([v (*Mu (abstract name body))])
      (hash-table-put! name-table v name)
      v))
  
  ;; the 'smart' destructor
  (define (Mu-body* name t)
    (match t
      [(Mu: scope)
       (instantiate (*F name) scope)]))
  
  ;; the 'smart' constructor
  (define (Poly* names body)
    (if (null? names) body
        (let ([v (*Poly (length names) (abstract-many names body))])
          (hash-table-put! name-table v names)
          v)))
  
  ;; the 'smart' destructor
  (define (Poly-body* names t)
    (match t
      [(Poly: n scope)
       (unless (= (length names) n)
         (error "Wrong number of names"))
       (instantiate-many (map *F names) scope)]))
  
  (print-struct #t)
  
  (define-match-expander Mu-unsafe:
    (lambda (stx)
      (syntax-case stx ()
        [(_ bp) #'(? Mu? (app (lambda (t) (Scope-t (Mu-body t))) bp))])))
  
  (define-match-expander Poly-unsafe:
    (lambda (stx)
      (syntax-case stx ()
        [(_ n bp) #'(? Poly? (app (lambda (t) (list (Poly-n t) (Poly-body t))) (list n bp)))])))
  
  (define-match-expander Mu:*
    (lambda (stx)
      (syntax-case stx ()
        [(_ np bp)
         #'(? Mu?
              (app (lambda (t) (let ([sym (gensym)])
                                 (list sym (Mu-body* sym t))))
                   (list np bp)))])))
  
  (define-match-expander Mu-name:
    (lambda (stx)
      (syntax-case stx ()
        [(_ np bp)
         #'(? Mu?
              (app (lambda (t) (let ([sym (hash-table-get name-table t (lambda _ (gensym)))])
                                 (list sym (Mu-body* sym t))))
                   (list np bp)))])))
  
  ;; This match expander wraps the smart constructor
  ;; names are generated with gensym
  (define-match-expander Poly:*
    (lambda (stx)
      (syntax-case stx ()
        [(_ nps bp)
         #'(? Poly?
              (app (lambda (t) 
                     (let* ([n (Poly-n t)]
                            [syms (build-list n (lambda _ (gensym)))])
                       (list syms (Poly-body* syms t))))
                   (list nps bp)))])))
  
  ;; This match expander uses the names from the hashtable  
  (define-match-expander Poly-names:
    (lambda (stx)
      (syntax-case stx ()
        [(_ nps bp)
         #'(? Poly?
              (app (lambda (t) 
                     (let* ([n (Poly-n t)]
                            [syms (hash-table-get name-table t)])
                       (list syms (Poly-body* syms t))))
                   (list nps bp)))])))
  
  ;; unfold : Type -> Type
  ;; must be applied to a Mu
  (define (unfold t)
    (match t
      [(Mu: sc) (instantiate t sc)]
      [_ (int-err "unfold: requires Mu type, got ~a" t)]))
  
  ;; type equality
  (define type-equal? eq?)

  ;; inequality - good
  
  (define (type<? s t)
    (< (Type-seq s) (Type-seq t)))
  
  (define (type-compare s t)
    (cond [(eq? s t) 0]
          [(type<? s t) 1]
          [else -1]))
  
  ;(trace subst subst-all)
  
  (provide
   unfold
   Mu-name: Poly-names:
   Type-seq Effect-seq  
   Mu-unsafe: Poly-unsafe:
   Mu? Poly?
   arr
   Type? Effect?
   Poly-n
   free-vars*
   type-equal? type-compare type<?
   remove-dups
   (rename-out [Mu:* Mu:]               
               [Poly:* Poly:]
               [Mu* make-Mu]
               [Poly* make-Poly]
               [Mu-body* Mu-body]
               [Poly-body* Poly-body]))
  
  ;(trace unfold)
