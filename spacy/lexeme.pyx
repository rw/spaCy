from cpython.ref cimport Py_INCREF
from cymem.cymem cimport Pool
from murmurhash.mrmr cimport hash64

from libc.string cimport memset

import orth

from .utf8string cimport Utf8Str

OOV_DIST_FLAGS = 0

memset(&EMPTY_LEXEME, 0, sizeof(Lexeme))


def get_flags(unicode string, float upper_pc, float title_pc, float lower_pc):
    cdef flag_t flags = 0
    flags |= orth.is_alpha(string) << IS_ALPHA
    flags |= orth.is_ascii(string) << IS_ASCII
    flags |= orth.is_digit(string) << IS_DIGIT
    flags |= orth.is_lower(string) << IS_LOWER
    flags |= orth.is_punct(string) << IS_PUNCT
    flags |= orth.is_space(string) << IS_SPACE
    flags |= orth.is_title(string) << IS_TITLE
    flags |= orth.is_upper(string) << IS_UPPER

    flags |= orth.like_url(string) << LIKE_URL
    flags |= orth.like_number(string) << LIKE_NUMBER
    return flags


cpdef Lexeme init(id_t i, unicode string, hash_t hashed,
                  StringStore store, dict props) except *:
    cdef Lexeme lex
    lex.id = i
    lex.length = len(string)
    lex.sic = get_string_id(string, store)
    
    lex.cluster = props.get('cluster', 0)
    lex.postype = props.get('postype', 0)
    lex.supersense = props.get('supersense', 0)
    lex.prob = props.get('prob', 0)

    cdef float upper_pc = props.get('upper_pc', 0.0)
    cdef float lower_pc = props.get('lower_pc', 0.0)
    cdef float title_pc = props.get('title_pc', 0.0)

    lex.prefix = get_string_id(string[0], store)
    lex.suffix = get_string_id(string[-3:], store)
    if upper_pc or lower_pc or title_pc:
        canon_cased = orth.canon_case(string, upper_pc, title_pc, lower_pc)
        lex.norm = get_string_id(canon_cased, store)
    else:
        lex.norm = lex.sic
    lex.shape = get_string_id(orth.word_shape(string), store)
    lex.asciied = get_string_id(orth.asciied(string), store)
    lex.flags = get_flags(string, upper_pc, title_pc, lower_pc)
    
    lex.flags |= props.get('in_males', 0) << IN_MALES
    lex.flags |= props.get('in_females', 0) << IN_FEMALES
    lex.flags |= props.get('in_surnames', 0) << IN_SURNAMES
    lex.flags |= props.get('in_places', 0) << IN_PLACES
    lex.flags |= props.get('in_celebs', 0) << IN_CELEBS
    lex.flags |= props.get('in_games', 0) << IN_GAMES
    lex.flags |= props.get('in_names', 0) << IN_NAMES
    return lex


cdef id_t get_string_id(unicode string, StringStore store) except 0:
    cdef bytes byte_string = string.encode('utf8')
    cdef Utf8Str* orig_str = store.intern(<char*>byte_string, len(byte_string))
    return orig_str.i