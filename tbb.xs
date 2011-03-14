#ifdef __cplusplus
extern "C" {
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
}
#endif

/* include your class headers here */
#include "tbb.h"

/* We need one MODULE... line to start the actual XS section of the file.
 * The XS++ preprocessor will output its own MODULE and PACKAGE lines */
MODULE = threads::tbb::init		PACKAGE = threads::tbb::init

## The include line executes xspp with the supplied typemap and the
## xsp interface code for our class.
## It will include the output of the xsubplusplus run.
## INCLUDE_COMMAND: $^X -MExtUtils::XSpp::Cmd -e xspp -- --typemap=typemap.xsp task_scheduler_init.xsp

PROTOTYPES: DISABLE

perl_tbb_init*
perl_tbb_init::new()

void
perl_tbb_init::initialize( nthr )
      int nthr;

void
perl_tbb_init::DESTROY()

void
perl_tbb_init::terminate()


MODULE = threads::tbb::blocked_int		PACKAGE = threads::tbb::blocked_int

perl_tbb_blocked_int*
perl_tbb_blocked_int::new( low, high, grain )
	      int low;
	      int high;
	      int grain;

int
perl_tbb_blocked_int::size( )

int
perl_tbb_blocked_int::grainsize( )

int
perl_tbb_blocked_int::begin( )

int
perl_tbb_blocked_int::end( )

bool
perl_tbb_blocked_int::empty( )

bool
perl_tbb_blocked_int::is_divisible( )

MODULE = threads::tbb::concurrent::array	PACKAGE = threads::tbb::concurrent::array

perl_concurrent_vector *
perl_concurrent_vector::new()

SV *
perl_concurrent_vector::FETCH(i)
		     int i;

void
perl_concurrent_vector::STORE(i, v)
		     int i;
		     SV* v;

int
perl_concurrent_vector::FETCHSIZE()

int
perl_concurrent_vector::size()

void
perl_concurrent_vector::PUSH(...)
  PREINIT:
	int i;
	perl_concurrent_vector::iterator idx;
  PPCODE:
	if (items == 2) {
		THIS->push_back( ST(0) );
	}
        else {
		idx = (THIS->grow_by( items ));
		for (i = 0; i < items; i++) {
			*idx = ST(i);
			idx++;
		}
	}

static perl_concurrent_vector *
TIEARRAY(classname)
	char* classname;
  CODE:
	RETVAL = new perl_concurrent_vector();
        ST(0) = sv_newmortal();
        sv_setref_pv( ST(0), classname, (void*)RETVAL );
	

MODULE = threads::tbb		PACKAGE = threads::tbb

