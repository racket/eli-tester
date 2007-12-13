#lang scribble/doc
@(require "utils.ss")

@title{Overview}

@section{CGC versus 3m}

Before mixing any C code with MzScheme, first decide whether to use
the @bold{3m} variant of PLT Scheme, the @bold{CGC} variant of PLT
Scheme, or both:

@itemize{

@item{@bold{@as-index{3m}} : the main variant of PLT Scheme, which
  uses @defterm{precise} garbage collection instead of conservative
  garbage collection, and it may move objects in memory during a
  collection.}

@item{@bold{@as-index{CGC}} : the original variant of PLT Scheme,
  where memory management depends on a @defterm{conservative} garbage
  collector. The conservative garbage collector can automatically find
  references to managed values from C local variables and (on some
  platforms) static variables.}

}

At the C level, working with CGC can be much easier than working with
3m, but overall system performance is typically better with 3m.

@; ----------------------------------------------------------------------

@section{Writing MzScheme Extensions}

@section-index["extending MzScheme"]

The process of creating an extension for 3m or CGC is essentially the
same, but the process for 3m is most easily understood as a variant of
the process for CGC.

@subsection{CGC Extensions}


To write a C/C++-based extension for PLT Scheme CGC, follow these
steps:

@itemize{

 @item{@index['("header files")]{For} each C/C++ file that uses PLT
 Scheme library functions, @cpp{#include} the file
 @as-index{@filepath{escheme.h}}.

 This file is distributed with the PLT software in an
 @filepath{include} directory, but if @|mzc| is used to compile, this
 path is found automatically.}


 @item{Define the C function @cppi{scheme_initialize}, which takes a
 @cpp{Scheme_Env*} namespace (see @secref["im:env"]) and returns a
 @cpp{Scheme_Object*} Scheme value.
 
 This initialization function can install new global primitive
 procedures or other values into the namespace, or it can simply
 return a Scheme value. The initialization function is called when the
 extension is loaded with @scheme[load-extension] (the first time);
 the return value from @cpp{scheme_initialize} is used as the return
 value for @scheme[load-extension]. The namespace provided to
 @cpp{scheme_initialize} is the current namespace when
 @scheme[load-extension] is called.}


 @item{Define the C function @cppi{scheme_reload}, which has the same
 arguments and return type as @cpp{scheme_initialize}.

 This function is called if @scheme[load-extension] is called a second
 time (or more times) for an extension. Like @cpp{scheme_initialize},
 the return value from this function is the return value for
 @scheme[load-extension].}


 @item{Define the C function @cppi{scheme_module_name}, which takes
 no arguments and returns a @cpp{Scheme_Object*} value, either a
 symbol or @cpp{scheme_false}.

 The function should return a symbol when the effect of calling
 @cpp{scheme_initialize} and @cpp{scheme_reload} is only to declare
 a module with the returned name. This function is called when the
 extension is loaded to satisfy a @scheme[require] declaration.

 The @cpp{scheme_module_name} function may be called before
 @cpp{scheme_initialize} and @cpp{scheme_reload}, after those
 functions, or both before and after, depending on how the extension
 is loaded and re-loaded.}


 @item{Compile the extension C/C++ files to create platform-specific
 object files.

 The @as-index{@|mzc|} compiler, which is distributed with PLT Scheme,
 compiles plain C files when the @as-index{@DFlag{cc}} flag is
 specified. More precisely, @|mzc| does not compile the files itself,
 but it locates a C compiler on the system and launches it with the
 appropriate compilation flags.  If the platform is a relatively
 standard Unix system, a Windows system with either Microsoft's C
 compiler or @exec{gcc} in the path, or a Mac OS X system with Apple's
 developer tools installed, then using @|mzc| is typically easier than
 working with the C compiler directly. Use the @as-index{@DFlag{cgc}}
 flag to indicate that the build is for use with PLT Scheme CGC.}


 @item{Link the extension C/C++ files with
 @as-index{@filepath{mzdyn.o}} (Unix, Mac OS X) or
 @as-index{@filepath{mzdyn.obj}} (Windows) to create a shared object. The
 resulting shared object should use the extension @filepath{.so} (Unix),
 @filepath{.dll} (Windows), or @filepath{.dylib} (Mac OS X).

 The @filepath{mzdyn} object file is distributed in the installation's
 @filepath{lib} directory. For Windows, the object file is in a
 compiler-specific sub-directory of @filepath{plt\lib}.

 The @|mzc| compiler links object files into an extension when the
 @as-index{@DFlag{ld}} flag is specified, automatically locating
 @filepath{mzdyn}. Again, use the @DFlag{cgc} flag with @|mzc|.}

 @item{Load the shared object within Scheme using
 @scheme[(load-extension _path)], where @scheme[_path] is the name of
 the extension file generated in the previous step.

 Alternately, if the extension defines a module (i.e.,
 @cpp{scheme_module_name} returns a symbol), then place the shared
 object in a special directory so that it is detected by the module
 loader when @scheme[require] is used. The special directory is a
 platform-specific path that can be obtained by evaluating
 @scheme[(build-path "compiled" "native" (system-library-subpath))];
 see @scheme[load/use-compiled] for more information.  For example, if
 the shared object's name is @filepath{example.dll}, then
 @scheme[(require "example.ss")] will be redirected to
 @filepath{example.dll} if the latter is placed in the sub-directory
 @scheme[(build-path "compiled" "native" (system-library-subpath))]
 and if @filepath{example.ss} does not exist or has an earlier
 timestamp.

 Note that @scheme[(load-extension _path)] within a @scheme[module]
 does @italic{not} introduce the extension's definitions into the
 module, because @scheme[load-extension] is a run-time operation. To
 introduce an extension's bindings into a module, make sure that the
 extension defines a module, put the extension in the
 platform-specific location as described above, and use
 @scheme[require].}

}

@index['("allocation")]{@bold{IMPORTANT:}} With PLT Scheme CGC, Scheme
values are garbage collected using a conservative garbage collector,
so pointers to Scheme objects can be kept in registers, stack
variables, or structures allocated with @cppi{scheme_malloc}. However,
static variables that contain pointers to collectable memory must be
registered using @cppi{scheme_register_extension_global} (see
@secref["im:memoryalloc"]).

As an example, the following C code defines an extension that returns
@scheme["hello world"] when it is loaded:

@verbatim[#<<EOS
 #include "escheme.h"
 Scheme_Object *scheme_initialize(Scheme_Env *env) {
   return scheme_make_utf8_string("hello world");
 }
 Scheme_Object *scheme_reload(Scheme_Env *env) {
   return scheme_initialize(env); /* Nothing special for reload */
 }
 Scheme_Object *scheme_module_name() {
   return scheme_false;
 }
EOS
]

Assuming that this code is in the file @filepath{hw.c}, the extension
is compiled under Unix with the following two commands:

@commandline{mzc --cgc --cc hw.c}
@commandline{mzc --cgc --ld hw.so hw.o}

(Note that the @DFlag{cgc}, @DFlag{cc}, and @DFlag{ld} flags are each
prefixed by two dashes, not one.)

The @filepath{collects/mzscheme/examples} directory in the PLT
distribution contains additional examples.

@subsection{3m Extensions}

To build an extension to work with PLT Scheme 3m, the CGC instructions
must be extended as follows:

@itemize{

 @item{Adjust code to cooperate with the garbage collector as
 described in @secref["im:3m"]. Using @|mzc| with the
 @as-index{@DFlag{xform}} might convert your code to implement part of
 the conversion, as described in @secref["im:3m:mzc"].}

 @item{In either your source in the in compiler command line,
 @cpp{#define} @cpp{MZ_PRECISE_GC} before including
 @filepath{escheme.h}. When using @|mzc| with the @DFlag{cc} and
 @as-index{@DFlag{3m}} flags, @cpp{MZ_PRECISE_GC} is automatically
 defined.}

 @item{Link with @as-index{@filepath{mzdyn3m.o}} (Unix, Mac OS X) or
 @as-index{@filepath{mzdyn3m.obj}} (Windows) to create a shared
 object.  When using @|mzc|, use the @DFlag{ld} and @DFlag{3m} flags
 to link to these libraries.}

}

For a relatively simple extension @filepath{hw.c}, the extension is
compiled under Unix for 3m with the following three commands:

@commandline{mzc --xform --cc hw.c}
@commandline{mzc --3m --cc hw.3m.c}
@commandline{mzc --3m --ld hw.so hw.o}

Some examples in @filepath{collects/mzscheme/examples} work with
MzScheme3m in this way. A few examples are manually instrumented, in
which case the @DFlag{xform} step should be skipped.

@; ----------------------------------------------------------------------

@section{Embedding MzScheme into a Program}

@section-index["embedding MzScheme"]

Like creating extensions, the embedding process for PLT Scheme CGC or
PLT Scheme 3m is essentially the same, but the process for PLT Scheme
3m is most easily understood as a variant of the process for
PLT Scheme CGC.

@subsection{CGC Embedding}

To embed PLT Scheme CGC in a program, follow these steps:

@itemize{

 @item{Locate or build the PLT Scheme CGC libraries. Since the
  standard distribution provides 3m libraries, only, you will most
  likely have to build from source.

  Under Unix, the libraries are @as-index{@filepath{libmzscheme.a}}
  and @as-index{@filepath{libmzgc.a}} (or
  @as-index{@filepath{libmzscheme.so}} and
  @as-index{@filepath{libmzgc.so}} for a dynamic-library build, with
  @as-index{@filepath{libmzscheme.la}} and
  @as-index{@filepath{libmzgc.la}} files for use with
  @exec{libtool}). Building from source and installing places the
  libraries into the installation's @filepath{lib} directory. Be sure
  to build the CGC variant, since the default is 3m.

  Under Windows, stub libraries for use with Microsoft tools are
  @filepath{libmzsch@italic{x}.lib} and
  @filepath{libmzgc@italic{x}.lib} (where @italic{x} represents the
  version number) are in a compiler-specific directory in
  @filepath{plt\lib}. These libraries identify the bindings that are
  provided by @filepath{libmzsch@italic{x}.dll} and
  @filepath{libmzgc@italic{x}.dll} --- which are typically installed
  in @filepath{plt\lib}. When linking with Cygwin, link to
  @filepath{libmzsch@italic{x}.dll} and
  @filepath{libmzgc@italic{x}.dll} directly.  At run time, either
  @filepath{libmzsch@italic{x}.dll} and
  @filepath{libmzgc@italic{x}.dll} must be moved to a location in the
  standard DLL search path, or your embedding application must
  ``delayload'' link the DLLs and explicitly load them before
  use. (@filepath{MzScheme.exe} and @filepath{MrEd.exe} use the latter
  strategy.)

  Under Mac OS X, dynamic libraries are provided by the
  @filepath{PLT_MzScheme} framework, which is typically installed in
  @filepath{lib} sub-directory of the installation. Supply
  @exec{-framework PLT_MzScheme} to @exec{gcc} when linking, along
  with @exec{-F} and a path to the @filepath{lib} directory. Beware
  that CGC and 3m libraries are installed as different versions within
  a single framework, and installation marks one version or the other
  as the default (by setting symbolic links); install only CGC to
  simplify accessing the CGC version within the framework.  At run
  time, either @filepath{PLT_MzScheme.framework} must be moved to a
  location in the standard framework search path, or your embedding
  executable must provide a specific path to the framework (possibly
  an executable-relative path using the Mach-O @tt["@executable_path"]
  prefix).}

 @item{For each C/C++ file that uses MzScheme library functions,
  @cpp{#include} the file @as-index{@filepath{scheme.h}}.

  The C preprocessor symbol @cppi{SCHEME_DIRECT_EMBEDDED} is defined
  as @cpp{1} when @filepath{scheme.h} is @cpp{#include}d, or as
  @cpp{0} when @filepath{escheme.h} is @cpp{#include}d.

  The @filepath{scheme.h} file is distributed with the PLT software in
  the installation's @filepath{include} directory. Building and
  installing from source also places this file in the installation's
  @filepath{include} directory.}

 @item{In your main program, obtain a global MzScheme environment
  @cpp{Scheme_Env*} by calling @cppi{scheme_basic_env}. This function
  must be called before any other function in the MzScheme library
  (except @cpp{scheme_make_param}).}

 @item{Access MzScheme through @cppi{scheme_load},
  @cppi{scheme_eval}, and/or other top-level MzScheme functions
  described in this manual.}

 @item{Compile the program and link it with the MzScheme libraries.}

}

@index['("allocation")]{With} PLT Scheme CGC, Scheme values are
garbage collected using a conservative garbage collector, so pointers
to Scheme objects can be kept in registers, stack variables, or
structures allocated with @cppi{scheme_malloc}. In an embedding
application on some platforms, static variables are also automatically
registered as roots for garbage collection (but see notes below
specific to Mac OS X and Windows).

For example, the following is a simple embedding program which
evaluates all expressions provided on the command line and displays
the results, then runs a @scheme[read]-@scheme[eval]-@scheme[print]
loop:

@verbatim[#<<EOS
#include "scheme.h"

int main(int argc, char *argv[])
{
  Scheme_Env *e;
  Scheme_Object *curout;
  int i;
  mz_jmp_buf * volatile save, fresh;

  scheme_set_stack_base(NULL, 1); /* required for OS X, only */

  e = scheme_basic_env();

  curout = scheme_get_param(scheme_current_config(), 
                            MZCONFIG_OUTPUT_PORT);

  for (i = 1; i < argc; i++) {
    save = scheme_current_thread->error_buf;
    scheme_current_thread->error_buf = &fresh;
    if (scheme_setjmp(scheme_error_buf)) {
      scheme_current_thread->error_buf = save;
      return -1; /* There was an error */
    } else {
      Scheme_Object *v = scheme_eval_string(argv[i], e);
      scheme_display(v, curout);
      scheme_display(scheme_make_character('\n'), curout);
      /* read-eval-print loop, uses initial Scheme_Env: */
      scheme_apply(scheme_builtin_value("read-eval-print-loop"), 
                   0, NULL);
      scheme_current_thread->error_buf = save;
    }
  }
  return 0;
}
EOS
]

Under Mac OS X, or under Windows when MzScheme is compiled to a DLL
using Cygwin, the garbage collector cannot find static variables
automatically. In that case, @cppi{scheme_set_stack_base} must be
called with a non-zero second argument before calling any
@cpp{scheme_} function.

Under Windows (for any other build mode), the garbage collector finds
static variables in an embedding program by examining all memory
pages. This strategy fails if a program contains multiple Windows
threads; a page may get unmapped by a thread while the collector is
examining the page, causing the collector to crash. To avoid this
problem, call @cpp{scheme_set_stack_base} with a non-zero second
argument before calling any @cpp{scheme_} function.

When an embedding application calls @cpp{scheme_set_stack_base} with a
non-zero second argument, it must register each of its static
variables with @cppi{MZ_REGISTER_STATIC} if the variable can contain a
GCable pointer. For example, if @cpp{e} above is made @cpp{static},
then @cpp{MZ_REGISTER_STATIC(e)} should be inserted before the call to
@cpp{scheme_basic_env}.

When building an embedded MzSchemeCGC to use SenoraGC (SGC) instead of
the default collector, @cpp{scheme_set_stack_base} must be called both
with a non-zero second argument and with a stack-base pointer in the
first argument.  See @secref["im:memoryalloc"] for more information.


@subsection{3m Embedding}

MzScheme3m can be embedded mostly the same as MzScheme, as long as the
embedding program cooperates with the precise garbage collector as
described in @secref["im:3m"].

In either your source in the in compiler command line, @cpp{#define}
@cpp{MZ_PRECISE_GC} before including @filepath{scheme.h}. When using
@|mzc| with the @DFlag{cc} and @DFlag{3m} flags, @cpp{MZ_PRECISE_GC}
is automatically defined.

In addition, some library details are different:

@itemize{

 @item{Under Unix, the library is just
  @as-index{@filepath{libmzscheme3m.a}} (or
  @as-index{@filepath{libmzscheme3m.so}} for a dynamic-library build,
  with @as-index{@filepath{libmzscheme3m.la}} for use with
  @exec{libtool}). There is no separate library for 3m analogous to
  CGC's @filepath{libmzgc.a}.}

 @item{Under Windows, the stub library for use with Microsoft tools is
  @filepath{libmzsch3m@italic{x}.lib} (where @italic{x} represents the
  version number). This library identifies the bindings that are
  provided by @filepath{libmzsch3m@italic{x}.dll}.  There is no
  separate library for 3m analogous to CGC's
  @filepath{libmzgc@italic{x}.lib}.}

  @item{Under Mac OS X, 3m dynamic libraries are provided by the
  @filepath{PLT_MzScheme} framework, just as for CGC, but as a version
  suffixed with @filepath{_3m}.}

}

For MzScheme3m, an embedding application must call
@cpp{scheme_set_stack_base} with non-zero arguments. Furthermore, the
first argument must be @cpp{&__gc_var_stack__}, where
@cpp{__gc_var_stack__} is bound by a @cpp{MZ_GC_DECL_REG}.

The simple embedding program from the previous section can be
extended to work with either CGC or 3m, dependong on whether
@cpp{MZ_PRECISE_GC} is specified on the compiler's command line:

@verbatim[#<<EOS
#include "scheme.h"

int main(int argc, char *argv[])
{
  Scheme_Env *e = NULL;
  Scheme_Object *curout = NULL, *v = NULL;
  Scheme_Config *config = NULL;
  int i;
  mz_jmp_buf * volatile save = NULL, fresh;

  MZ_GC_DECL_REG(5);
  MZ_GC_VAR_IN_REG(0, e);
  MZ_GC_VAR_IN_REG(1, curout);
  MZ_GC_VAR_IN_REG(2, save);
  MZ_GC_VAR_IN_REG(3, config);
  MZ_GC_VAR_IN_REG(4, v);

# ifdef MZ_PRECISE_GC
#  define STACK_BASE &__gc_var_stack__
# else
#  define STACK_BASE NULL
# endif

  scheme_set_stack_base(STACK_BASE, 1);

  MZ_GC_REG();

  e = scheme_basic_env();

  config = scheme_current_config();
  curout = scheme_get_param(config, MZCONFIG_OUTPUT_PORT);

  for (i = 1; i < argc; i++) {
    save = scheme_current_thread->error_buf;
    scheme_current_thread->error_buf = &fresh;
    if (scheme_setjmp(scheme_error_buf)) {
      scheme_current_thread->error_buf = save;
      return -1; /* There was an error */
    } else {
      v = scheme_eval_string(argv[i], e);
      scheme_display(v, curout);
      v = scheme_make_character('\n');
      scheme_display(v, curout);
      /* read-eval-print loop, uses initial Scheme_Env: */
      v = scheme_builtin_value("read-eval-print-loop");
      scheme_apply(v, 0, NULL);
      scheme_current_thread->error_buf = save;
    }
  }

  MZ_GC_UNREG();

  return 0;
}
EOS
]

Strictly speaking, the @cpp{config} and @cpp{v} variables above need not be
registered with the garbage collector, since their values are not needed
across function calls that allocate. That is, the original example could have
been left alone starting with the @cpp{scheme_base_env} call, except for the
addition of @cpp{MZ_GC_UNREG}. The code is much easier to maintain, however,
when all local variables are regsistered and when all temporary values are
put into variables.

@; ----------------------------------------------------------------------

@section{MzScheme and Threads}

MzScheme implements threads for Scheme programs without aid from the
operating system, so that MzScheme threads are cooperative from the
perspective of C code. Under Unix, stand-alone MzScheme uses a single
OS-implemented thread. Under Windows and Mac OS X, stand-alone
MzScheme uses a few private OS-implemented threads for background
tasks, but these OS-implemented threads are never exposed by the
MzScheme API.

In an embedding application, MzScheme can co-exist with additional
OS-implemented threads, but the additional OS threads must not call
any @cpp{scheme_} function.  Only the OS thread that originally calls
@cpp{scheme_basic_env} can call @cpp{scheme_} functions. (This
restriction is stronger than saying all calls must be serialized
across threads. MzScheme relies on properties of specific threads to
avoid stack overflow and garbage collection.) When
@cpp{scheme_basic_env} is called a second time to reset the
interpreter, it can be called in an OS thread that is different from
the original call to @cpp{scheme_basic_env}. Thereafter, all calls to
@cpp{scheme_} functions must originate from the new thread.

See @secref["threads"] for more information about threads, including
the possible effects of MzScheme's thread implementation on extension
and embedding C code.

@; ----------------------------------------------------------------------

@section[#:tag "im:unicode"]{MzScheme, Unicode, Characters, and Strings}

A character in MzScheme is a Unicode code point. In C, a character
value has type @cppi{mzchar}, which is an alias for @cpp{unsigned} ---
which is, in turn, 4 bytes for a properly compiled MzScheme. Thus, a
@cpp{mzchar*} string is effectively a UCS-4 string.

Only a few MzScheme functions use @cpp{mzchar*}. Instead, most
functions accept @cpp{char*} strings. When such byte strings are to be
used as a character strings, they are interpreted as UTF-8
encodings. A plain ASCII string is always acceptable in such cases,
since the UTF-8 encoding of an ASCII string is itself.

See also @secref["im:strings"] and @secref["im:encodings"].

@; ----------------------------------------------------------------------

@section[#:tag "im:intsize"]{Integers}

MzScheme expects to be compiled in a mode where @cppi{short} is a
16-bit integer, @cppi{int} is a 32-bit integer, and @cppi{long} has
the same number of bits as @cpp{void*}. The @cppi{mzlonglong} type has
64 bits for compilers that support a 64-bit integer type, otherwise it
is the same as @cpp{long}; thus, @cpp{mzlonglong} tends to match
@cpp{long long}. The @cppi{umzlonglong} type is the unsigned version
of @cpp{mzlonglong}.