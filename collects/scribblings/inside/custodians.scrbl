#lang scribble/doc
@(require "utils.ss")

@title{Custodians}

When an extension allocates resources that must be explicitly freed
(in the same way that a port must be explicitly closed), a Scheme
object associated with the resource should be placed into the
management of the current custodian with @cppi{scheme_add_managed}.

Before allocating the resource, call
@cppi{scheme_custodian_check_available} to ensure that the relevant
custodian is not already shut down. If it is,
@cpp{scheme_custodian_check_available} will raise an exception.  If
the custodian is shut down when @cpp{scheme_add_managed} is called,
the close function provided to @cpp{scheme_add_managed} will be called
immediately, and no exception will be reported.

@; ----------------------------------------------------------------------

@function[(Scheme_Custodian* scheme_make_custodian
           [Scheme_Custodian* m])]{

Creates a new custodian as a subordinate of @var{m}. If @var{m} is
 @cpp{NULL}, then the main custodian is used as the new custodian's
 supervisor. Do not use @cpp{NULL} for @var{m} unless you intend to
 create an especially privileged custodian.}

@function[(Scheme_Custodian_Reference* scheme_add_managed
           [Scheme_Custodian* m]
           [Scheme_Object* o]
           [Scheme_Close_Custodian_Client* f]
           [void* data]
           [int strong])]{

Places the value @var{o} into the management of the custodian
 @var{m}. If @var{m} is @cpp{NULL}, the current custodian is used.


The @var{f} function is called by the custodian if it is ever asked to
``shutdown'' its values; @var{o} and @var{data} are passed on to
@var{f}, which has the type

@verbatim[#<<EOS
typedef void (*Scheme_Close_Custodian_Client)(Scheme_Object *o, 
                                              void *data);
EOS
]

If @var{strong} is non-zero, then the newly managed value will
be remembered until either the custodian shuts it down or
@cpp{scheme_remove_managed} is called. If @var{strong} is
zero, the value is allowed to be garbaged collected (and automatically
removed from the custodian).

The return value from @cpp{scheme_add_managed} can be used to refer
to the value's custodian later in a call to
@cpp{scheme_remove_managed}. A value can be registered with at
most one custodian.

If @var{m} (or the current custodian if @var{m} is @cpp{NULL})is shut
down, then @var{f} is called immediately, and the result is
@cpp{NULL}.}

@function[(void scheme_custodian_check_available
           [Scheme_Custodian* m]
           [const-char* name]
           [const-char* resname]
           [Scheme_Custodian_Reference* mref]
           [Scheme_Object* o])]{

Removes @var{o} from the management of its custodian. The @var{mref}
 argument must be a value returned by @cpp{scheme_add_managed} or
 @cpp{NULL}.}

@function[(void scheme_close_managed
           [Scheme_Custodian* m])]{

Instructs the custodian @var{m} to shutdown all of its managed values.}

@function[(void scheme_add_atexit_closer
           [Scheme_Exit_Closer_Func f])]{

Installs a function to be called on each custodian-registered item and
 its closer when MzScheme is about to exit. The registered function
 has the type

@verbatim[#<<EOS
  typedef 
  void (*Scheme_Exit_Closer_Func)(Scheme_Object *o,
                                  Scheme_Close_Custodian_Client *f, 
                                  void *d);
EOS
]

where @var{d} is the second argument for @var{f}.}
