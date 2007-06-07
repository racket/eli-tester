#reader(lib "docreader.ss" "scribble")
@require[(lib "manual.ss" "scribble")]
@require[(lib "eval.ss" "scribble")]
@require["guide-utils.ss"]

@title{Definitions: @scheme[define] and @scheme[define-values]}

A definition can have the form

@specform[(define _id _expr)]