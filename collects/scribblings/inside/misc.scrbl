#lang scribble/doc
@(require "utils.ss")

@title{Miscellaneous Utilities}

The @cppi{MZSCHEME_VERSION} preprocessor macro is defined as a string
describing the version of Scheme. The @cppi{MZSCHEME_VERSION_MAJOR}
and @cppi{MZSCHEME_VERSION_MINOR} macros are defined as the major and
minor version numbers, respectively.

@function[(int scheme_eq
           [Scheme_Object* obj1]
           [Scheme_Object* obj2])]{

Returns 1 if the Scheme values are @scheme[eq?].}

@function[(int scheme_eqv
           [Scheme_Object* obj1]
           [Scheme_Object* obj2])]{

Returns 1 if the Scheme values are @scheme[eqv?].}

@function[(int scheme_equal
           [Scheme_Object* obj1]
           [Scheme_Object* obj2])]{

Returns 1 if the Scheme values are @scheme[equal?].}

@function[(long scheme_equal_hash_key
           [Scheme_Object* obj]
           [Scheme_Object* obj]
           [int c]
           [Scheme_Object** elems])]{

Creates and returns a list of length @var{c} with the elements
@var{elems}.}

@function[(int scheme_list_length
           [Scheme_Object* list])]{

Returns the length of the list. If @var{list} is not a proper list,
then the last @scheme[cdr] counts as an item. If there is a cycle in
@var{list} (involving only @scheme[cdr]s), this procedure will not
terminate.}

@function[(int scheme_proper_list_length
           [Scheme_Object* list])]{

Returns the length of the list, or -1 if it is not a proper list.  If
there is a cycle in @var{list} (involving only @scheme[cdr]s), this 
procedure returns -1.}

@function[(Scheme_Object* scheme_car
           [Scheme_Object* pair])]{

Returns the @scheme[car] of the pair.}

@function[(Scheme_Object* scheme_cdr
           [Scheme_Object* pair])]{

Returns the @scheme[cdr] of the pair.}

@function[(Scheme_Object* scheme_cadr
           [Scheme_Object* pair])]{

Returns the @scheme[cadr] of the pair.}

@function[(Scheme_Object* scheme_caddr
           [Scheme_Object* pair])]{

Returns the @scheme[caddr] of the pair.}

@function[(Scheme_Object* scheme_vector_to_list
           [Scheme_Object* vec])]{

Creates a list with the same elements as the given vector.}

@function[(Scheme_Object* scheme_list_to_vector
           [Scheme_Object* list])]{

Creates a vector with the same elements as the given list.}

@function[(Scheme_Object* scheme_append
           [Scheme_Object* lstx]
           [Scheme_Object* lsty])]{

Non-destructively appends the given lists.}

@function[(Scheme_Object* scheme_unbox
           [Scheme_Object* obj])]{

Returns the contents of the given box.}

@function[(void scheme_set_box
           [Scheme_Object* b]
           [Scheme_Object* v])]{

Sets the contents of the given box.}

@function[(Scheme_Object* scheme_load
           [char* file])]{

Loads the specified Scheme file, returning the value of the last
expression loaded, or @cpp{NULL} if the load fails.}

@function[(Scheme_Object* scheme_load_extension
           [char* filename])]{

Loads the specified Scheme extension file, returning the value provided
by the extension's initialization function.}

@function[(Scheme_Hash_Table* scheme_make_hash_table
           [int type])]{

Creates a hash table. The @var{type} argument must be either
@cppi{SCHEME_hash_ptr} or @cppi{SCHEME_hash_string}, which determines
how keys are compared (unless the hash and compare functions are
modified in the hash table record; see below). A @cpp{SCHEME_hash_ptr}
table hashes on a key's pointer address, while
@cpp{SCHEME_hash_string} uses a key as a @cpp{char*} and hashes on the
null-terminated string content. Since a hash table created with
@cpp{SCHEME_hash_string} (instead of @cpp{SCHEME_hash_ptr}) does not
use a key as a Scheme value, it cannot be used from Scheme code.

Although the hash table interface uses the type @cpp{Scheme_Object*}
for both keys and values, the table functions never inspect values,
and they inspect keys only for @cpp{SCHEME_hash_string} hashing. Thus,
the actual types of the values (and keys, for @cpp{SCHEME_hash_ptr}
tables) can be anything.

The public portion of the @cppi{Scheme_Hash_Table} type is defined
roughly as follows:

@verbatim[#<<EOS
  typedef struct Scheme_Hash_Table {
    Scheme_Object so; /* so.type == scheme_hash_table_type */
    /* ... */
    int size;  /* size of keys and vals arrays */
    int count; /* number of mapped keys */
    Scheme_Object **keys;
    Scheme_Object **vals;
    void (*make_hash_indices)(void *v, long *h1, long *h2);
    int (*compare)(void *v1, void *v2);
    /* ... */
  } Scheme_Hash_Table;
EOS
]

The @cpp{make_hash_indices} and @cpp{compare} function pointers can be
set to arbitrary hashing and comparison functions (before any mapping
is installed into the table). A hash function should fill @var{h1}
with a primary hash value and @var{h2} with a secondary hash value;
the values are for double-hashing, where the caller takes appropriate
modulos.

To traverse the hash table content, iterate over @var{keys} and
@var{vals} in parallel from @cpp{0} to @cpp{size-1}, and ignore
@var{keys} where the corresponding @var{vals} entry is @cpp{NULL}.
The @cpp{count} field indicates the number of non-@cpp{NULL} values
that will be encountered.}

@function[(Scheme_Hash_Table* scheme_make_hash_table_equal)]{

Like @cpp{scheme_make_hash_table}, except that keys are treated as
Scheme values and hashed based on @scheme[equal?]\ instead of
@scheme[eq?].}

@function[(void scheme_hash_set
           [Scheme_Hash_Table* table]
           [Scheme_Object* key]
           [Scheme_Object* val])]{

Sets the current value for @var{key} in @var{table} to @var{val}. If
@var{val} is @cpp{NULL}, the @var{key} is unmapped in @var{table}.}

@function[(Scheme_Object* scheme_hash_get
           [Scheme_Hash_Table* table]
           [Scheme_Object* key])]{

Returns the current value for @var{key} in @var{table}, or @cpp{NULL}
if @var{key} has no value.}


@function[(Scheme_Bucket_Table* scheme_make_bucket_table
           [int size_hint]
           [int type])]{

Like @cpp{make_hash_table}, but bucket tables are somewhat more
flexible, in that hash buckets are accessible and weak keys are
supported. (They also consume more space than hash tables.)

The @var{type} argument must be either @cppi{SCHEME_hash_ptr},
@cppi{SCHEME_hash_string}, or @cppi{SCHEME_hash_weak_ptr}. The first
two are the same as for hash tables. The last is like
@cpp{SCHEME_hash_ptr}, but the keys are weakly held.

The public portion of the @cppi{Scheme_Bucket_Table} type is defined
roughly as follows:

@verbatim[#<<EOS
  typedef struct Scheme_Bucket_Table {
    Scheme_Object so; /* so.type == scheme_variable_type */
    /* ... */
    int size;  /* size of buckets array */
    int count; /* number of buckets, >= number of mapped keys */
    Scheme_Bucket **buckets;
    void (*make_hash_indices)(void *v, long *h1, long *h2);
    int (*compare)(void *v1, void *v2);
    /* ... */
  } Scheme_Bucket_Table;
EOS
]

The @cpp{make_hash_indices} and @cpp{compare} functions are used as
for hash tables. Note that @cppi{SCHEME_hash_weak_ptr} supplied as the
initial type makes keys weak even if the hash and comparison functions
are changed.

See @cpp{scheme_bucket_from_table} for information on buckets.}

@function[(void scheme_add_to_table
           [Scheme_Bucket_Table* table]
           [const-char* key]
           [void* val]
           [int const])]{

Sets the current value for @var{key} in @var{table} to @var{val}. If
@var{const} is non-zero, the value for @var{key} must never be
changed.}

@function[(void scheme_change_in_table
           [Scheme_Bucket_Table* table]
           [const-char* key]
           [void* val])]{

Sets the current value for @var{key} in @var{table} to @var{val}, but
 only if @var{key} is already mapped in the table.}

@function[(void* scheme_lookup_in_table
           [Scheme_Bucket_Table* table]
           [const-char* key])]{

Returns the current value for @var{key} in @var{table}, or @cpp{NULL}
 if @var{key} has no value.}

@function[(Scheme_Bucket* scheme_bucket_from_table
           [Scheme_Bucket_Table* table]
           [const-char* key])]{

Returns the bucket for @var{key} in @var{table}. The
@cppi{Scheme_Bucket} structure is defined as:

@verbatim[#<<EOS
  typedef struct Scheme_Bucket {
    Scheme_Object so; /* so.type == scheme_bucket_type */
    /* ... */
    void *key;
    void *val;
  } Scheme_Bucket;
EOS
]

Setting @var{val} to @cpp{NULL} unmaps the bucket's key, and @var{key}
can be @cpp{NULL} in that case as well.  If the table holds keys
weakly, then @var{key} points to a (weak) pointer to the actual key,
and the weak pointer's value can be @cpp{NULL}.}


@function[(long scheme_double_to_int
           [char* where]
           [double d])]{

Returns a fixnum value for the given floating-point number @var{d}. If @var{d}
is not an integer or if it is too large, then an error message is
reported; @var{name} is used for error-reporting.}

@function[(long scheme_get_milliseconds)]{

Returns the current ``time'' in milliseconds, just like
@scheme[current-milliseconds].}

@function[(long scheme_get_process_milliseconds)]{

Returns the current process ``time'' in milliseconds, just like
@scheme[current-process-milliseconds].}

@function[(char* scheme_banner)]{

Returns the string that is used as the Scheme startup banner.}

@function[(char* scheme_version)]{

Returns a string for the executing version of Scheme.}