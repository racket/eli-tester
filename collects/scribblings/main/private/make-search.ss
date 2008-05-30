#reader scribble/reader
#lang scheme/base

(require scribble/decode
         scribble/struct
         scribble/manual-struct
         scheme/list
         scheme/string
         scheme/match
         net/url
         (only-in scheme/class send)
         (only-in xml xexpr->string)
         (only-in setup/dirs find-doc-dir)
         "utils.ss")

(provide make-search)

(define (cadr-string-lists<? a b)
  (let loop ([a (cadr a)] [b (cadr b)])
    (cond [(null? b) #f]
          [(null? a) #t]
          [(string-ci=? (car a) (car b))
           (or (loop (cdr a) (cdr b))
               ;; Try string<? so "Foo" still precedes "foo"
               (string<? (car a) (car b)))]
          [else (string-ci<? (car a) (car b))])))

(define (make-script user-dir? renderer sec ri)
  (define l null)
  (define span-classes null)
  ;; To make the index smaller, html contents is represented as one of these:
  ;; - a string
  ;; - an array of contents to be concatenated
  ;; - a two-item array [idx, content], where idx is an index into the
  ;;   span-classes table holding a class name.
  ;; In addition, a "file:/main-doc.../path..." url is saved as ">path..."
  ;; This function does the url compacting.
  (define main-url ; (make sure that it teminates with a slash)
    (if user-dir?
      (regexp-replace #rx"/*$" (url->string (path->url (find-doc-dir))) "/")
      "../"))
  (define compact-url
    (let ([rx (regexp (string-append "^" (regexp-quote main-url)))])
      (lambda (url) (regexp-replace rx url ">"))))
  ;; This function does the html compacting.
  (define (compact-body xexprs)
    (define (compact xexprs)
      (match xexprs
        [`() xexprs]
        [`("" . ,r) (compact r)]
        [`(,(? string? s1) ,(? string? s2) . ,r)
         (compact `(,(string-append s1 s2) . ,r))]
        [`((span ([class ,c]) . ,b1) (span ([class ,c]) . ,b2) . ,r)
         (compact `((span ([class ,c]) ,@b1 ,@b2) . ,r))]
        [`((span ([class ,c]) . ,b) . ,r)
         (let ([c (cond [(assoc c span-classes) => cdr]
                        [else (let ([n (length span-classes)])
                                (set! span-classes
                                      (cons (cons c n) span-classes))
                                n)])])
           (cons `(,c . ,(compact-body b)) (compact r)))]
        [`(,x . ,r) (cons (xexpr->string x) (compact r))]))
    ;; generate javascript array code
    (let loop ([body (compact xexprs)])
      (if (andmap string? body)
        (format "~s" (string-append* body))
        (let ([body (map (lambda (x)
                           (if (string? x)
                             (format "~s" x)
                             (format "[~a,~a]" (car x) (cdr x))))
                         body)])
          (if (= 1 (length body))
            (car body)
            (string-append* `("[" ,@(add-between body ",") "]")))))))
  (hash-for-each
   (let ([parent (collected-info-parent (part-collected-info sec ri))])
     (if parent
       (collected-info-info (part-collected-info parent ri))
       (collect-info-ext-ht (resolve-info-ci ri))))
   (lambda (k v)
     (when (and (pair? k) (eq? 'index-entry (car k)))
       (set! l (cons (cons (cadr k) v) l)))))
  (set! l (sort l cadr-string-lists<?))
  (set! l
    (for/list ([i l])
      ;; i is (list tag (text ...) (element ...) index-desc)
      (define-values (tag texts elts desc) (apply values i))
      (define text (string-downcase (string-join texts " ")))
      (define-values (href html)
        (let* ([e (add-between elts ", ")]
               [e (make-link-element "indexlink" e tag)]
               [e (send renderer render-element e sec ri)])
          (match e ; should always render to a single `a'
            [`((a ([href ,href] [class "indexlink"]) . ,body))
             (let (;; throw away tooltips, we don't need them
                   [body (match body
                           [`((span ((title ,label)) . ,body))
                            (if (regexp-match? #rx"^Provided from: " label)
                              body
                              ;; if this happens, this code should be updated
                              (error "internal error: unexpected tooltip"))]
                           [else body])])
               (values (compact-url href) (compact-body body)))]
            [else (error "something bad happened")])))
      (define from-libs
        (cond
          [(exported-index-desc? desc)
           (string-append*
            `("["
              ,@(add-between
                 (map (lambda (x)
                        (format "~s"
                                (match x
                                  [(? symbol?) (symbol->string x)]
                                  [`',(? symbol? x)
                                   (string-append "'" (symbol->string x))])))
                      (exported-index-desc-from-libs desc))
                 ",")
              "]"))]
          [(module-path-index-desc? desc) "\"module\""]
          [else "false"]))
      ;; Note: using ~s to have javascript-quoted strings
      (format "[~s,~s,~a,~a]" text href html from-libs)))
  (set! l (add-between l ",\n"))

  @script[#:noscript @list{Sorry, you must have JavaScript to use this page.}]{
    // the url of the main doc tree, for compact url
    // representation (see also the UncompactUrl function)
    plt_main_url = @(format "~s" main-url);
    // classes to be used for compact representation of html strings in
    // plt_search_data below (see also the UncompactHtml function)
    plt_span_classes = [
      @(add-between (map (lambda (x) (format "~s" (car x)))
                         (reverse span-classes))
                    ",\n  ")];
    // this array has an entry for each index link: [text, url, html, from-lib]
    // - text is a string holding the indexed text
    // - url holds the link (">" prefix means relative to plt_main_url)
    // - html holds either a string, or [idx, html] where idx is an
    //   index into plt_span_classes (note: this is recursive)
    plt_search_data = [
    @l];

    // Globally visible bindings
    var key_handler;

    (function(){

    // Configuration options
    var results_num = 20;

    var query, status, results_container, result_links,
        prev_page_link, next_page_link;

    function InitializeSearch() {
      var n;
      n = document.getElementById("plt_search_container").parentNode;
      // hack the table in
      n.innerHTML = ''
        +'<table width="100%" cellspacing="0" cellpadding="1">'
        +'<tr><td align="center" colspan="3">'
          +'<input type="text" id="search_box" style="width: 100%;"'
                +' onkeyup="key_handler(\'\');"'
                +' onkeypress="return key_handler(event);" />'
        +'</td></tr>'
        +'<tr><td align="left">'
          +'<a href="#" title="Previous Page" id="prev_page_link"'
            +' style="text-decoration: none; font-weight: bold;"'
            +' onclick="key_handler(\'PgUp\'); return false;"'
            +'><tt><b>&lt;&lt;</b></tt></a>'
        +'</td><td align="center">'
          +'<span id="search_status" style="color: #601515; font-weight: bold;">'
            +'&nbsp;'
          +'</span>'
        +'</td><td align="right">'
          +'<a href="#" title="Next Page" id="next_page_link"'
            +' style="text-decoration: none; font-weight: bold;"'
            +' onclick="key_handler(\'PgDn\'); return false;"'
            +'><tt><b>&gt;&gt;</b></tt></a>'
        +'</td></tr>'
        +'<tr><td colspan="3" bgcolor="#ffffff">'
          +'<span id="search_result"'
               +' style="display: none;'
               +' margin: 0.1em 0em; padding: 0.25em 1em;"></span>'
        +'</td></tr>'
        +'</table>';
      // get the widgets we use
      query = document.getElementById("search_box");
      status = document.getElementById("search_status");
      prev_page_link = document.getElementById("prev_page_link");
      next_page_link = document.getElementById("next_page_link");
      // result_links is the array of result link <container,link> pairs
      result_links = new Array();
      n = document.getElementById("search_result");
      results_container = n.parentNode;
      results_container.normalize();
      result_links.push(n);
      AdjustResultsNum();
      // get search string
      if (location.search.length > 0) {
        var paramstrs = location.search.substring(1).split(/[@";"&]/);
        for (var i=0@";" i<paramstrs.length@";" i++) {
          var param = paramstrs[i].split(/=/);
          if (param.length == 2 && param[0] == "q") {
            query.value = unescape(param[1]).replace(/\+/g," ");
            break;
          }
        }
      }
      DoSearch();
      query.focus();
      query.select();
    }

    function AdjustResultsNum() {
      if (result_links.length == results_num) return;
      if (results_num <= 0) results_num = 1; // should have at least one template
      while (result_links.length > results_num)
        results_container.removeChild(result_links.pop());
      while (result_links.length < results_num) {
        var n = result_links[0].cloneNode(true);
        result_links.push(n);
        results_container.appendChild(n);
      }
    }

    var last_search_term, last_search_term_raw;
    var search_results = [], first_search_result, exact_results_num;
    function DoSearch() {
      var term = query.value;
      if (term == last_search_term_raw) return;
      last_search_term_raw = term;
      term = term.toLowerCase()
                 .replace(/\s\s*/g," ")                  // single spaces
                 .replace(/^\s/g,"").replace(/\s$/g,""); // trim edge spaces
      if (term == last_search_term) return;
      last_search_term = term;
      status.innerHTML = "Searching " + plt_search_data.length + " entries";
      var terms = (term=="") ? [] : term.split(/ /);
      if (terms.length == 0) {
        search_results = [];
      } else {
        search_results = new Array();
        exact_results = new Array();
        for (var i=0@";" i<plt_search_data.length@";" i++) {
          var show = true, curtext = plt_search_data[i][0];
          if (plt_search_data[i][3] && (term == curtext)) {
            exact_results.push(plt_search_data[i]);
          } else {
            for (var j=0@";" j<terms.length@";" j++) {
              if (curtext.indexOf(terms[j]) < 0) {
                show = false;
                break;
              }
            }
            if (show) search_results.push(plt_search_data[i]);
          }
        }
        exact_results_num = exact_results.length;
        while (exact_results.length > 0)
          search_results.unshift(exact_results.pop());
      }
      first_search_result = 0;
      status.innerHTML = "" + search_results.length + " entries found";
      query.style.backgroundColor =
        ((search_results.length == 0) && (term != "")) ? "#ffe0e0" : "white";
      UpdateResults();
    }

    function UncompactUrl(url) {
      return url.replace(/^>/, plt_main_url);
    }

    function UncompactHtml(x) {
      if (typeof x == "string") {
        return x;
      } else if (! (x instanceof Array)) {
        alert("Internal error in PLT docs");
      } else if ((x.length == 2) && (typeof(x[0]) == "number")) {
        return '<span class="' + plt_span_classes[x[0]]
               + '">' + UncompactHtml(x[1]) + '</span>';
      } else {
        var s = "";
        for (var i=0@";" i<x.length@";" i++) s = s.concat(UncompactHtml(x[i]));
        return s;
      }
    }

    function UpdateResults() {
      if (first_search_result < 0 ||
          first_search_result >= search_results.length)
        first_search_result = 0;
      for (var i=0@";" i<result_links.length@";" i++) {
        var n = i + first_search_result;
        if (n < search_results.length) {
          var note = false, desc = search_results[n][3];
          if ((desc instanceof Array) && (desc.length > 0)) {
            note = '<span class="smaller">provided from</span> ';
            for (var j=0@";" j<desc.length@";" j++)
              note += (j==0 ? "" : ", " )
                      + '<span class="schememod">' + desc[j] + '</span>';
          } else if (desc == "module") {
            note = '<span class="smaller">module</span>';
          }
          if (note)
            note = '&nbsp;&nbsp;<span class="smaller">' + note + '</span>';
          result_links[i].innerHTML =
            '<a href="'
            + UncompactUrl(search_results[n][1]) + '" class="indexlink">'
            + UncompactHtml(search_results[n][2]) + '</a>' + (note || "");
          result_links[i].style.backgroundColor =
            (n < exact_results_num) ? "#ffffe0" : "#f8f8f8";
          result_links[i].style.display = "block";
        } else {
          result_links[i].style.display = "none";
        }
      }
      if (search_results.length == 0)
        status.innerHTML = ((last_search_term=="") ? "" : "No matches found");
      else if (search_results.length <= results_num)
        status.innerHTML = "Showing all matches";
      else
        status.innerHTML =
          "Showing "
          + (first_search_result+1) + "-"
          + Math.min(first_search_result+results_num,search_results.length)
          + " of " + search_results.length
          + ((search_results.length==plt_search_data.length) ? "" : " matches");
      if (exact_results_num > 0)
        status.innerHTML +=
          " (<span style=\"background-color: #ffffc0;\">"
          + ((exact_results_num == search_results.length)
               ? "all" : exact_results_num)
          + " exact</span>)";
      prev_page_link.style.color =
        (first_search_result-results_num >= 0) ? "black" : "#e8e8e8";
      next_page_link.style.color =
        (first_search_result+results_num < search_results.length)
        ? "black" : "#e0e0e0";
    }

    var search_timer = null;
    function HandleKeyEvent(event) {
      if (search_timer != null) {
        var t = search_timer;
        search_timer = null;
        clearTimeout(t);
      }
      var key = event;
      if (typeof event != "string") {
        switch (event.which || event.keyCode) {
          case 13: key = "Enter"; break;
          case 33: key = "PgUp"; break;
          case 34: key = "PgDn"; break;
        }
      }
      switch (key) {
        case "Enter": // enter with no change scrolls
          if (query.value == last_search_term_raw) {
            first_search_result += results_num;
            UpdateResults();
          } else {
            DoSearch();
          }
          return false;
        case "PgUp":
          DoSearch(); // in case we didn't update it yet
          first_search_result -= results_num;
          UpdateResults();
          return false;
        case "PgDn":
          DoSearch(); // in case we didn't update it yet
          if (first_search_result + results_num < search_results.length) {
            first_search_result += results_num;
            UpdateResults();
          }
          return false;
      }
      search_timer = setTimeout(DoSearch, 300);
      return true;
    }

    key_handler = HandleKeyEvent;

    window.onload = InitializeSearch;

    })();
  })

(define (make-search user-dir?)
  (make-splice
   (list
    (make-delayed-block
     (lambda (r s i) (make-paragraph (list (make-script user-dir? r s i)))))
    (make-element (make-with-attributes #f '((id . "plt_search_container")))
                  null))))