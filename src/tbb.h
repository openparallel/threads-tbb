#ifndef _perl_tbb_h_
#define _perl_tbb_h_

#include "tbb/task_scheduler_init.h"
#include "tbb/blocked_range.h"
#include "tbb/tbb_stddef.h"
#include "tbb/concurrent_queue.h"
#include "tbb/concurrent_vector.h"
#include "tbb/concurrent_hash_map.h"
#include "tbb/parallel_for.h"
#include <iterator>
#include <set>
#include <list>

#include "tbb/spin_mutex.h"
typedef tbb::spin_mutex      mutex_t;

#if _WIN32||_WIN64
#define raw_thread_id DWORD
#define get_raw_thread_id() GetCurrentThreadId()
#else
#define raw_thread_id pthread_t
#define get_raw_thread_id() pthread_self()
#endif

// see this source file for enabling IF_DEBUG_* macros
#include "debug.h"

//**
//*  Perl-mapped classes
//*/

// threads::tbb::blocked_int
class perl_tbb_blocked_int : public tbb::blocked_range<int> {
public:
perl_tbb_blocked_int( int min, int max, int grain ) :
	tbb::blocked_range<int>(min, max, grain)
	{ };
perl_tbb_blocked_int( perl_tbb_blocked_int& oth, tbb::split sp )
	: tbb::blocked_range<int>( oth, sp )
	{ };
};

// a slot in a cross-thread item
class perl_concurrent_slot {
public:
	SV* thingy;
	PerlInterpreter* owner;
        perl_concurrent_slot( ) : thingy(0) {};
	perl_concurrent_slot( PerlInterpreter* owner, SV* thingy )
		: thingy(thingy), owner(owner) {};
	SV* dup( pTHX ) const;    // get if same interpreter, clone otherwise
	SV* clone( pTHX );  // always clone
};

// same as perl_concurrent_slot, but with refcounting (so it can be
// passed between threads) - a "boxed" slot
class perl_concurrent_item : public perl_concurrent_slot {
public:
	int refcnt;
	perl_concurrent_item( ) : refcnt(0), perl_concurrent_slot() {};
	perl_concurrent_item( PerlInterpreter* owner, SV* thingy )
		: refcnt(0), perl_concurrent_slot(owner, thingy) {};
};

// threads::tbb::concurrent::array
class perl_concurrent_vector : public tbb::concurrent_vector<perl_concurrent_slot> {
public:
	int refcnt;
	perl_concurrent_vector() : refcnt(0) {}
};

struct hek_compare_funcs {
	static size_t hash( const HEK& hek ) {
		return hek.hek_hash;
	}
	static bool equal( const HEK& a, const HEK& b ) {
		return ( (a.hek_len == b.hek_len) ||
			 strcmp(a.hek_key, b.hek_key) );
	}
};

// threads::tbb::concurrent::hash - map from the Perl Hash Key to a
// lazy slot
class perl_concurrent_hash : public tbb::concurrent_hash_map<HEK, perl_concurrent_slot, hek_compare_funcs> {
public:
	int refcnt;
	perl_concurrent_hash() : refcnt(0) {}
};

typedef perl_concurrent_hash::const_accessor perl_concurrent_hash_reader;
typedef perl_concurrent_hash::accessor perl_concurrent_hash_writer;

// threads::tbb::init
static int perl_tbb_init_seq = 0;
static mutex_t perl_tbb_init_seq_mutex;
class perl_tbb_init : public tbb::task_scheduler_init {
public:
	std::list<std::string> boot_lib;
	std::list<std::string> boot_use;
	int seq;  // process-unique ID

	perl_tbb_init( int num_thr ) : tbb::task_scheduler_init(num_thr) {
		mark_master_thread_ok();
		mutex_t::scoped_lock lock(perl_tbb_init_seq_mutex);
		seq = perl_tbb_init_seq++;
	}
	~perl_tbb_init() { }
	void mark_master_thread_ok();

	void setup_worker_inc( pTHX );
	void load_modules( pTHX );

private:
	int id;
};

// these are the types passed to parallel_for et al

// threads::tbb::for_int_array_func
// first a very simple one that allows an entry-point function to be called by
// name, with a sub-dividing integer range.

class perl_for_int_array_func {
	const std::string funcname;
	perl_tbb_init* context;
	perl_concurrent_vector* xarray;
public:
        perl_for_int_array_func( perl_tbb_init* context, perl_concurrent_vector* xarray, std::string funcname ) :
	funcname(funcname), context(context), xarray(xarray) { };
	perl_concurrent_vector* get_array() { return xarray; };
	void operator()( const perl_tbb_blocked_int& r ) const;
};

// threads::tbb::for_int_method
// this one allows a SV to be passed
class perl_for_int_method {
	perl_tbb_init* context;
	perl_concurrent_slot invocant;
        perl_concurrent_vector* copied;
public:
	std::string methodname;
perl_for_int_method( pTHX_ perl_tbb_init* context, SV* inv_sv, std::string methodname ) :
	context(context), methodname(methodname) {
		copied = new perl_concurrent_vector();
		SV* newsv = newSV(0);
		SvSetSV_nosteal(newsv, inv_sv);
		IF_DEBUG_PERLCALL("copied %x to %x (refcnt = %d)", inv_sv, newsv, SvREFCNT(newsv));
		invocant = perl_concurrent_slot(my_perl, newsv); 
	};
	SV* get_invocant( pTHX_ int worker );
	void operator()( const perl_tbb_blocked_int& r ) const;
};

// the crazy^Wlazy clone function :)
SV* clone_other_sv(PerlInterpreter* my_perl, SV* sv, PerlInterpreter* other_perl);

#endif

