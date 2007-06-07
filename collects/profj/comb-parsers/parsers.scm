(module parsers mzscheme
  (require "parser-units.scm"
           (only (lib "force.ss" "lazy") !!!)
           (only (lib "combinator-unit.ss" "combinator-parser") err^)
           (lib "unit.ss")
           #;(lib "lex.ss" "parser-tools")
           #;(prefix re: (lib "lex-sre.ss" "parser-tools")))
  
  (provide parse-beginner parse-intermediate parse-intermediate+access parse-advanced
           parse-beginner-interact parse-intermediate-interact parse-advanced-interact)
  (define (trim-string s f l)
    (substring s f (- (string-length s) l)))
  
;  (define-lex-abbrevs
;   ;; 3.4
;   (CR #\015)
;   (LF #\012)
;   (LineTerminator (re:or CR 
;                          LF 
;                          (re:: CR LF)))
;   (InputCharacter (re:~ CR LF))
;   
;   ;; 3.6
;   (FF #\014)
;   (TAB #\011)
;   (WhiteSpace (re:or #\space 
;                      TAB
;                      FF
;                      LineTerminator))
;   
;   ;; 3.7 (Had to transform CommentTail and CommentTailStar into one RE)
;   ;;     (DocumentationComment only appears in version 1 of the spec)
;   (Comment (re:or TraditionalComment 
;                   EndOfLineComment
;                   DocumentationComment))
;   (TraditionalComment (re:: "/*" NotStar CommentTail))
;   (EndOfLineComment (re:: "//" (re:* InputCharacter)))
;   (DocumentationComment (re:: "/**" CommentTailStar))
;   (CommentTail (re:: (re:* (re:: (re:* NotStar) (re:+ "*") NotStarNotSlash))
;                      (re:* NotStar)
;                      (re:+ "*")
;                      "/"))
;   (CommentTailStar (re:: (re:* (re:: (re:* "*") NotStarNotSlash (re:* NotStar) "*"))
;                          (re:* "*")
;                          "/"))
;   (NotStar (re:~ "*"))
;   (NotStarNotSlash (re:~ "*" "/"))
;   
;   (SyntaxComment (re:or TraditionalCommentEOF
;                         EndOfLineComment))
;   (TraditionalCommentEOF (re:: "/*" CommentTailEOF))
;   (CommentTailEOF (re:or (re:: (re:* (re:: (re:* NotStar) (re:+ "*") NotStarNotSlash))
;                                (re:* NotStar)
;                                (re:+ "*")
;                                "/")
;                          (re:: (re:* (re:: (re:* NotStar) (re:+ "*") NotStarNotSlash))
;                                (re:* NotStar)
;                                (re:* "*"))))
;   
;   ;; 3.8 (No need to worry about excluding keywords and such.  They will
;   ;;      appear first in the lexer spec)
;   ;Not UNICODE compliant
;   (Identifier (re:: JavaLetter (re:* JavaLetterOrDigit)))
;   (JavaLetter (re:or (re:/ "AZ" "az") "_" "$"))
;   (JavaLetterOrDigit (re:or JavaLetter (re:/ "09")))
;    
;   (KnownTypes (re:or "boolean" "byte" "char" "double" "float" "int" "long" "short"
;                      "String" "Object"))
;   
;   ;; 3.9
;   (Keyword (re:or "abstract"    "default"    "if"            "private"      "this"
;                   "boolean"     "do"         "implements"    "protected"    "throw"
;                   "break"       "double"     "import"        "public"       "throws"
;                   "byte"        "else"       "instanceof"    "return"       "transient"
;                   "case"        "extends"    "int"           "short"        "try"
;                   "catch"       "final"      "interface"     "static"       "void"
;                   "char"        "finally"    "long"          "strictfp"     "volatile"
;                   "class"       "float"      "native"        "super"        "while"
;                   "const"       "for"        "new"           "switch"
;                   "continue"    "goto"       "package"       "synchronized"))
;   
;   ;; 3.10.1
;   (Digits (re:+ (re:/ "09")))
;   (DigitsOpt (re:* (re:/ "09")))
;   
;   (IntegerTypeSuffix (char-set "lL"))
;   (DecimalNumeral (re:or #\0
;                          (re:: (re:/ "19") (re:* (re:/ "09")))))
;   (HexDigit (re:/ "09" "af" "AF"))
;   (HexNumeral (re:: #\0 (char-set "xX") (re:+ HexDigit)))
;   (OctalNumeral (re:: #\0 (re:+ (re:/ "07"))))
;   
;   ;; 3.10.2
;   (FloatTypeSuffix (char-set "fF"))
;   (DoubleTypeSuffix (char-set "dD"))
;   
;   (FloatA (re:: Digits #\. DigitsOpt (re:? ExponentPart)))
;   (FloatB (re:: #\. Digits (re:? ExponentPart)))
;   (FloatC (re:: Digits ExponentPart))
;   (FloatD (re:: Digits (re:? ExponentPart)))
;   
;   (ExponentPart (re:: (char-set "eE") (re:? (char-set "+-")) Digits))
;   
;   ;; MORE
;   
;   ;; 3.10.6
;   (EscapeSequence (re:or "\\b" "\\t" "\\n" "\\f" "\\r" "\\\"" "\\'" "\\\\"
;                          (re:: #\\ (re:? (re:/ "03")) (re:/ "07") (re:/ "07"))
;                          (re:: #\\ (re:/ "07"))))
;   
;   ;; 3.12
;   (Operator (re:or "="	">" "<" "!"	"~"	"?"	":"
;                    "=="	"<="	">="	"!="	"&&" "||"	"++"	"--"
;                    "+"	"-"	"*"	"/"	"&" "|"	"^"	"%"	"<<" ">>" ">>>"
;                    "+="	"-="	"*="	"/="	"&="	"|="	"^="	"%="	"<<="	">>="	">>>=")))
;  
;  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  ;;Comment lexers
;  
;  (define read-line-comment
;    (lexer
;     [(re:~ #\newline) (read-line-comment input-port)]
;     [#\newline end-pos]
;     [(eof) end-pos]
;     [(special) (read-line-comment input-port)]
;     [(special-comment) (read-line-comment input-port)]
;     ))
;  
;  (define read-block-comment
;    (lexer
;     ["*/" end-pos]
;     [(eof) end-pos]
;     [(re:or "*" "/" (complement (re:: any-string (re:or "*" "/") any-string))) (read-block-comment input-port)]
;     [(special) (read-block-comment input-port)]
;     [(special-comment) (read-block-comment input-port)]
;     ))
;  
;  #;(define read-document-comment
;      (lexer
;       ["**/" end-pos]
;       [(eof) end-pos]
;       [(re:or "*" "/" (~ (any-string))) (read-document-comment input-port)]
;       [(special) (read-document-comment input-port)]
;       [(special-comment) (read-document-comment input-port)]
;       [(special-error) (read-document-comment input-port)]))
;  
;  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  ;String lexer
;  
;  ;get-string: input-port -> (U STRING_LIT STRING_ERROR tokens)
;  (define (get-string input-port)
;    (letrec ((tokens (get-string-tokens input-port))
;             (last-token (list-ref tokens (sub1 (length tokens))))
;             (tokens->string
;              (lambda (toks)
;                ;Stops before the last element, which does not have a string
;                (if (null? (cdr toks))
;                    ""
;                    (string-append (string (token-value (position-token-token (car toks))))
;                                   (tokens->string (cdr toks)))))))
;      (if (eq? 'STRING_END (token-name (position-token-token last-token)))
;          (token-STRING_LIT (list (tokens->string tokens) (position-token-end-pos last-token)))
;          (token-STRING_ERROR 
;           (list (tokens->string tokens) 
;                 (position-token-end-pos last-token) 
;                 (position-token-token last-token))))))
;  
;  ;get-string-tokens: input-port -> (list position-token)
;  (define (get-string-tokens input-port)
;    (let ((tok (get-str-tok input-port)))
;      (case (token-name (position-token-token tok))
;        ((STRING_EOF STRING_END STRING_NEWLINE) (list tok))
;        (else (cons tok (get-string-tokens input-port))))))
;    
;  (define-tokens str-tok (STRING_CHAR))
;  (define-empty-tokens err (STRING_END STRING_EOF STRING_NEWLINE))
;  
;  (define get-str-tok
;    (lexer-src-pos
;     (#\" (token-STRING_END))
;     (EscapeSequence (token-STRING_CHAR (EscapeSequence->char lexeme)))
;     (InputCharacter (token-STRING_CHAR (string-ref lexeme 0)))
;     ((re:or CR LF) (token-STRING_NEWLINE))
;     (#\032 (token-STRING_EOF))
;     ((eof) (token-STRING_EOF))))
;  
;  ;; 3.10.6
;  (define (EscapeSequence->char es)
;    (cond
;      ((string=? es "\\b") #\010)
;      ((string=? es "\\t") #\011)
;      ((string=? es "\\n") #\012)
;      ((string=? es "\\f") #\014)
;      ((string=? es "\\r") #\015)
;      ((string=? es "\\\"") #\")
;      ((string=? es "\\'") #\')
;      ((string=? es "\\\\") #\\)
;      (else (integer->char (string->number (trim-string es 1 0) 8)))))
;  
;  (define get-token
;    (lexer-src-pos
;     ;; 3.12
;     (Operator (let ((l lexeme))
;                 (cond
;                   ((string=? l "|") (token-PIPE))
;                   ((string=? l "||") (token-OR))
;                   ((string=? l "|=") (token-OREQUAL))
;                   ((string=? l "=") (token-EQUAL))
;                   ((string=? l "<") (token-LT))
;                   ((string=? l ">") (token-GT))
;                   ((string=? l "<=") (token-LTEQ))
;                   ((string=? l ">=") (token-GTEQ))
;                   ((string=? l "+") (token-PLUS))
;                   ((string=? l "-") (token-MINUS))
;                   ((string=? l "*") (token-TIMES))
;                   ((string=? l "/") (token-DIVIDE))
;                   ((string=? l "^") (token-^T))
;                   (else (string->symbol l)))))
;
;     ("->" (string->symbol lexeme))
;     ("->>" (string->symbol lexeme))
;     ("->>>" (string->symbol lexeme))
;     
;     ;; 3.11
;     ("(" (token-O_PAREN))
;     (")" (token-C_PAREN))
;     ("{" (token-O_BRACE))
;     ("}" (token-C_BRACE))
;     ("[" (token-O_BRACKET))
;     ("]" (token-C_BRACKET))
;     (";" (token-SEMI_COLON))
;     ("," (token-COMMA))
;     ("." (token-PERIOD))
;     
;     ;; 3.10.7
;     ("null" (token-NULL_LIT))
;     
;     ;; 3.10.5
;     (#\" (get-string input-port))
;     ;(token-STRING_LIT (list->string (get-string input-port))))
;     
;     ;; 3.10.4
;     ((re:: #\' (re:~ CR LF #\' #\\) #\')
;      (token-CHAR_LIT (string-ref lexeme 1)))
;     ((re:: #\' EscapeSequence #\') 
;      (token-CHAR_LIT (EscapeSequence->char 
;                       (trim-string lexeme 1 1))))
;     
;     ;; 3.10.3
;     ("true" (token-TRUE_LIT))
;     ("false" (token-FALSE_LIT))
;     
;     ;; 3.10.2
;     ((re:or FloatA FloatB FloatC)
;      (token-DOUBLE_LIT (string->number lexeme)))
;     ((re:: (re:or FloatA FloatB FloatC FloatD) FloatTypeSuffix)
;      (token-FLOAT_LIT (string->number (trim-string lexeme 0 1))))
;     ((re:: (re:or FloatA FloatB FloatC FloatD) DoubleTypeSuffix)
;      (token-DOUBLE_LIT (string->number (trim-string lexeme 0 1))))
;     
;     
;     ;; 3.10.1
;     (DecimalNumeral
;      (token-INTEGER_LIT (string->number lexeme 10)))
;     ((re:: DecimalNumeral IntegerTypeSuffix)
;      (token-LONG_LIT (string->number (trim-string lexeme 0 1) 10)))
;     ((re:: HexNumeral IntegerTypeSuffix)
;      (token-HEXL_LIT (string->number (trim-string lexeme 2 1) 16)))
;     (HexNumeral
;      (token-HEX_LIT (string->number (trim-string lexeme 2 0) 16)))
;     (OctalNumeral
;      (token-OCT_LIT (string->number (trim-string lexeme 1 0) 8)))
;     ((re:: OctalNumeral IntegerTypeSuffix)
;      (token-OCTL_LIT (string->number (trim-string lexeme 1 1) 8)))
;     
;     #;("dynamic" 
;      (cond
;        ((dynamic?) (string->symbol lexeme))
;        (else (token-IDENTIFIER lexeme))))
;     
;     #;((re:or "check" "expect" "within")
;      (cond
;        ((test-ext?) (string->symbol lexeme))
;        (else (token-IDENTIFIER lexeme))))
;     
;     #;((re:or "test" "tests" "testcase")
;      (cond
;        ((testcase-ext?) (string->symbol lexeme))
;        (else (token-IDENTIFIER lexeme))))
;     
;     ;; 3.9
;     (Keyword (string->symbol lexeme))
;     
;     ;; 3.8
;     (Identifier (token-IDENTIFIER lexeme))
;     
;     ;; 3.7
;     ("//" (begin (read-line-comment input-port) (return-without-pos (get-token input-port))))
;     ("/*" (begin (read-block-comment input-port) (return-without-pos (get-token input-port))))
;     #;("/**" (begin (read-document-comment input-port) (return-without-pos (get-token input-port))))
;       
;     #;((special)
;      (cond
;        ((and (syntax? lexeme) (syntax-property lexeme 'test-case-box))
;         (token-TEST_SUITE (make-test-case lexeme)))
;        ((and (syntax? lexeme) (syntax-property lexeme 'example-box))
;         (syntax-case lexeme ()
;           ((parse-example-box examples) (token-EXAMPLE (make-example-box (syntax examples))))))
;        ((is-a? lexeme (image-snip%))
;         (token-IMAGE_SPECIAL lexeme))
;        (else
;         (token-OTHER_SPECIAL (list lexeme start-pos end-pos)))))
;            
;     ;; 3.6
;     ((re:+ WhiteSpace) (return-without-pos (get-token input-port)))
;       
;     ;; 3.5
;     (#\032 'EOF)
;     ((eof) 'EOF)
;       
;     ((re:+ (re:/ "09" "az" "AZ")) (token-NUMBER_ERROR lexeme))
;     
;     ))
;  

  (define-values/invoke-unit java-definitions-parsers@
    (import)
    (export (prefix def: parsers^) (prefix def: err^) token-proc^))
  
  (define-values/invoke-unit java-interactions-parsers@
    (import)
    (export (prefix int: parsers^) (prefix int: err^)))
  
  (define (parse parser err? err-src err-msg)
    (lambda (program-stream location)
      (let ([output 
             ;(with-handlers ((exn? 
             ;                 (lambda (e)
             ;                   (string-append "parse function failed with this internal exception:"
             ;                                  (exn-message e)))))
               (!!! ((!!! parser) (old-tokens->new program-stream) location))]);)])
        (if (err? output) (list (err-msg output) (!!! (err-src output)))))))
  
  (define parse-beginner (parse def:parse-beginner def:err? def:err-msg def:err-src))
  (define parse-intermediate (parse def:parse-intermediate def:err? def:err-msg def:err-src))
  (define parse-intermediate+access (parse def:parse-intermediate+access def:err? def:err-msg def:err-src))
  (define parse-advanced (parse def:parse-advanced def:err? def:err-msg def:err-src))
  (define parse-beginner-interact (parse int:parse-beginner int:err? int:err-msg int:err-src))
  (define parse-intermediate-interact (parse int:parse-intermediate int:err? int:err-msg int:err-src))
  (define parse-advanced-interact (parse int:parse-advanced int:err? int:err-msg int:err-src))

  
  
  
  )