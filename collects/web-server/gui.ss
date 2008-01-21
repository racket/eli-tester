#lang scheme/base
(require (lib "class.ss")
         (lib "mred.ss" "mred"))
(require "private/launch.ss")

(define shutdown (serve))

(when (current-eventspace-has-menu-root?) 
  (let ([mb (make-object menu-bar% 'root)])
    (unless (current-eventspace-has-standard-menus?)
      (make-object menu-item%
        "Quit"
        (make-object menu% "File" mb)
        (lambda (i e)
          (shutdown)
          (exit))))))
(application-quit-handler (lambda ()
                            (shutdown)
                            (exit)))

(yield (make-semaphore))