#ifdef __cplusplus
extern "C" {
#define PERL_NO_GET_CONTEXT /* we want efficiency! */
#include "EXTERN.h"
#include "perl.h"
#include "proto.h"
#include "XSUB.h"
#include "ppport.h"
}
#endif

/* include your class headers here */
#include "tbb.h"
#include "interpreter_pool.h"

HEK* new_hek(const char *str, I32 len, U32 hash) {
	    char *k;
    register HEK *hek;

    Newx(k, HEK_BASESIZE + len + 2, char);
    hek = (HEK*)k;
    Copy(str, HEK_KEY(hek), len, char);
    HEK_KEY(hek)[len] = 0;
    HEK_LEN(hek) = len;
    HEK_HASH(hek) = hash;
    HEK_FLAGS(hek) = (unsigned char)HVhek_UTF8 | HVhek_UNSHARED;

    return hek;
}

MODULE = threads::tbb::concurrent::hash::writer    PACKAGE = threads::tbb::concurrent::hash::writer

SV*
perl_concurrent_hash_writer::get()
  CODE:
	IF_DEBUG_VECTOR("got here, thingy = %x", (*THIS)->second.thingy);
	if ((*THIS)->second.thingy)
		RETVAL = (*THIS)->second.dup( my_perl );
	else
		XSRETURN_UNDEF;
  OUTPUT: RETVAL

SV*
perl_concurrent_hash_writer::clone()
  CODE:
	IF_DEBUG_VECTOR("got here, thingy = %x", (*THIS)->second.thingy);
	if ((*THIS)->second.thingy)
		RETVAL = (*THIS)->second.clone( my_perl );
	else
		XSRETURN_UNDEF;
  OUTPUT: RETVAL

void
perl_concurrent_hash_writer::set( SV* val )
  PREINIT:
	SV* nsv;
	perl_concurrent_slot* slot;
  CODE:
	slot = &(*THIS)->second;
	if (slot->thingy) {
		if (slot->owner == my_perl) {
			if (slot->thingy && slot->thingy != &PL_sv_undef) {
				// just go ahead and REFCNT_dec it!
				IF_DEBUG_FREE("SV %x belongs to me, refcnt => %d", slot->thingy, SvREFCNT(slot->thingy)-1);
				SvREFCNT_dec(slot->thingy);
			}
		}
		else {
			// queue a message to release it on next grab()
			IF_DEBUG_FREE("SV %x belongs to interpreter %x, queueing", slot->thingy, slot->owner);
			tbb_interpreter_freelist.free( *slot );
		}
	}
        nsv = newSV(0);
	SvSetSV_nosteal(nsv, val);
	slot->thingy = nsv;
	slot->owner = my_perl;
	IF_DEBUG_FREE("SV %x now in item, refcnt => %d", slot->thingy, SvREFCNT(slot->thingy));

void
perl_concurrent_hash_writer::DESTROY()
CODE:
	if (THIS != NULL) {
		IF_DEBUG_VECTOR("freeing hash writer %x", THIS);
		delete THIS;
		sv_setiv(SvRV(ST(0)), 0);
	}
	else {
		IF_DEBUG_VECTOR("double free hash writer?");
	}

int
perl_concurrent_hash_writer::CLONE_SKIP()
  CODE:
	RETVAL = 1;
  OUTPUT:
	RETVAL

MODULE = threads::tbb::concurrent::hash::reader    PACKAGE = threads::tbb::concurrent::hash::reader

SV*
perl_concurrent_hash_reader::get()
  CODE:
	RETVAL = (*THIS)->second.dup( my_perl );
  OUTPUT: RETVAL

SV*
perl_concurrent_hash_reader::clone()
  CODE:
	IF_DEBUG_VECTOR("got here, thingy = %x", (*THIS)->second.thingy);
	if ((*THIS)->second.thingy)
		RETVAL = (*THIS)->second.clone( my_perl );
	else
		XSRETURN_UNDEF;
  OUTPUT: RETVAL

void
perl_concurrent_hash_reader::DESTROY()
CODE:
	if (THIS != NULL) {
		IF_DEBUG_VECTOR("freeing hash reader %x", THIS);
		delete THIS;
		sv_setiv(SvRV(ST(0)), 0);
	}
	else {
		IF_DEBUG_VECTOR("double free hash reader?");
	}

int
perl_concurrent_hash_reader::CLONE_SKIP()
  CODE:
	RETVAL = 1;
  OUTPUT:
	RETVAL

MODULE = threads::tbb::concurrent::hash    PACKAGE = threads::tbb::concurrent::hash

PROTOTYPES: DISABLE

perl_concurrent_hash *
perl_concurrent_hash::new()
  CODE:
	RETVAL = new perl_concurrent_hash();
  	RETVAL->refcnt++;
OUTPUT:
  	RETVAL

SV *
perl_concurrent_hash::FETCH(key)
	SV* key;
  PREINIT:
	SV* mysv;
	char* hek_char;
	const HEK* hek;
	const char* sv_pv;
	STRLEN len;
	U32 hash;
	perl_concurrent_hash_reader lock;

  CODE:
	sv_pv = SvPVutf8( key, len );
	PERL_HASH(hash, sv_pv, len );
	hek = new_hek( sv_pv, len, hash );

	if ( THIS->find( lock, *hek ) ) {
		Safefree(hek);
		RETVAL = (*lock).second.clone( my_perl );
		IF_DEBUG_VECTOR("FETCH{%s}: returning %x: copied to %x (refcnt = %d)", SvPV_nolen(key), (*lock).second.thingy, RETVAL, SvREFCNT(RETVAL));
	}
	else {
		Safefree(hek);
		IF_DEBUG_VECTOR("FETCH{%s}: returning undef", SvPV_nolen(key));
		XSRETURN_UNDEF;
	}

  OUTPUT:
	RETVAL

void
perl_concurrent_hash::STORE(key, v)
	SV* key;
	SV* v;
  PREINIT:
	const HEK* hek;
	const char* sv_pv;
	STRLEN len;
	U32 hash;
	perl_concurrent_hash_writer lock;
	perl_concurrent_slot* slot;
	SV* nsv;
	
  PPCODE:
	sv_pv = SvPVutf8( key, len );
	PERL_HASH(hash, sv_pv, len );
	hek = new_hek( sv_pv, len, hash );

	IF_DEBUG_VECTOR("STORE (%s, %x) (refcnt = %d)", sv_pv, v, SvREFCNT(v));
	
	if (THIS->find( lock, *hek )) {
		Safefree(hek);
		slot = &(*lock).second;
		SV* o = slot->thingy;
		if (o) {
			IF_DEBUG_VECTOR("old = %x", o);
			if (my_perl == slot->owner && slot->thingy != &PL_sv_undef) {
				IF_DEBUG_VECTOR("SvREFCNT_dec(%x) (refcnt = %d)", o, SvREFCNT(o));
				SvREFCNT_dec(o);
			}
			else {
				IF_DEBUG_FREE("SV %x belongs to interpreter %x, queueing", slot->thingy, slot->owner);
				tbb_interpreter_freelist.free( *slot );
			}
		}
	}
	else {
		THIS->insert( lock, *hek );
		
		slot = &(*lock).second;
	}

	nsv = newSV(0);
	SvSetSV_nosteal(nsv, v);
	IF_DEBUG_VECTOR("new = %x (refcnt = %d)", nsv, SvREFCNT(nsv));
	slot->owner = my_perl;
	slot->thingy = nsv;
	

perl_concurrent_hash *
TIEHASH(classname)
	char* classname;
  CODE:
	RETVAL = new perl_concurrent_hash();
	RETVAL->refcnt++;
        ST(0) = sv_newmortal();
        sv_setref_pv( ST(0), classname, (void*)RETVAL );
	
void
perl_concurrent_hash::DESTROY()
CODE:
	if (THIS != NULL) {
		if (--THIS->refcnt > 0) {
			IF_DEBUG_LEAK("perl_concurrent_hash::DESTROY; %x => refcnt=%d", THIS, THIS->refcnt);
		}
		else {
			IF_DEBUG_LEAK("perl_concurrent_hash::DESTROY; delete %x", THIS);
			delete THIS;
			// XXX - temporary workaround
			sv_setiv(SvRV(ST(0)), 0);
		}
	}

int
perl_concurrent_hash::CLONE_REFCNT_inc()
  CODE:
	THIS->refcnt++;
	IF_DEBUG_LEAK("perl_concurrent_hash::CLONE_REFCNT_inc; %x => %d", THIS, THIS->refcnt);
	RETVAL = 42;
  OUTPUT:
	RETVAL

SV*
perl_concurrent_hash::reader(key)
	SV* key;
  PREINIT:
	const HEK* hek;
	const char* sv_pv;
	STRLEN len;
	U32 hash;
	perl_concurrent_hash_reader* lock;
	perl_concurrent_slot* slot;
	SV* nsv;
  CODE:
	sv_pv = SvPVutf8( key, len );
	PERL_HASH(hash, sv_pv, len );
	hek = new_hek( sv_pv, len, hash );

	IF_DEBUG_VECTOR("new reader for {%s} (HASH=%x)", SvPV_nolen(key), hash);
	lock = new perl_concurrent_hash_reader();
	IF_DEBUG_VECTOR("find");
	if (THIS->find( *lock, *hek )) {
		IF_DEBUG_VECTOR("found");
		RETVAL = newSV(0);
		sv_setref_pv( RETVAL, "threads::tbb::concurrent::hash::reader", (void*) lock);
		Safefree(hek);
	}
	else {
		IF_DEBUG_VECTOR("not found");
		delete lock;
		Safefree(hek);
		XSRETURN_UNDEF;
	}
  OUTPUT:
	RETVAL

perl_concurrent_hash_writer*
perl_concurrent_hash::writer(key)
	SV* key;
  PREINIT:
	const HEK* hek;
	const char* sv_pv;
	STRLEN len;
	U32 hash;
	perl_concurrent_hash_writer* lock;
	perl_concurrent_slot* slot;
	SV* nsv;
  CODE:
	sv_pv = SvPVutf8( key, len );
	PERL_HASH(hash, sv_pv, len );
	hek = new_hek( sv_pv, len, hash );

	IF_DEBUG_VECTOR("new writer for {%s} (HASH=%x)", SvPV_nolen(key), hash);
	lock = new perl_concurrent_hash_writer();
	THIS->insert( *lock, *hek );
	Safefree(hek);
	RETVAL = lock;
  OUTPUT:
	RETVAL


