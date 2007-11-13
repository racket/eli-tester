;;----------------------------------------------------------------------
;; mzscheme: provide everything

(module mzscheme '#%kernel
  (#%require "private/more-scheme.ss"
             "private/misc.ss"
             "private/letstx-scheme.ss"
             "private/stxcase-scheme.ss"
             "private/stx.ss"
             "private/stxmz-body.ss"
             "private/qqstx.ss"
             "private/define.ss"
             "private/old-ds.ss"
             "private/old-rp.ss"
             "private/old-if.ss"
             "private/old-procs.ss"
             "tcp.ss"
             "udp.ss"
             '#%builtin) ; so it's attached

  (#%provide require require-for-syntax require-for-template require-for-label
             provide provide-for-syntax provide-for-label
             (all-from "private/more-scheme.ss")
             (all-from "private/misc.ss")
             (all-from-except "private/stxcase-scheme.ss" _)
             (all-from-except "private/letstx-scheme.ss" -define -define-syntax -define-struct)
             define-struct let-struct
             identifier? ;; from "private/stx.ss"
             (all-from "private/qqstx.ss")
             (all-from "private/define.ss")
             (all-from-except '#%kernel #%module-begin #%datum 
                              if make-namespace
                              syntax->datum datum->syntax
                              free-identifier=?
                              free-transformer-identifier=?
                              free-template-identifier=?
                              free-label-identifier=?)
             (rename syntax->datum syntax-object->datum)
             (rename datum->syntax datum->syntax-object)
             (rename free-identifier=? module-identifier=?)
             (rename free-transformer-identifier=? module-transformer-identifier=?)
             (rename free-template-identifier=? module-template-identifier=?)
             (rename free-label-identifier=? module-label-identifier=?)
             (rename free-identifier=?* free-identifier=?)
             namespace-transformer-require
             (rename cleanse-path expand-path)
             (rename if* if)
             (rename make-namespace* make-namespace)
             #%top-interaction
             (rename datum #%datum)
             (rename mzscheme-in-stx-module-begin #%module-begin)
             (rename #%module-begin #%plain-module-begin)
             (rename lambda #%plain-lambda)
             (rename #%app #%plain-app)
             (all-from "tcp.ss")
             (all-from "udp.ss")))