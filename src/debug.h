
// set to "IF_DEBUG(e) e" to allow debugging messages,
#define IF_DEBUG(e)

#define IF_DEBUG_THR(msg, e...) IF_DEBUG(_warn("thr %x: " msg "\n", get_raw_thread_id(), ##e))
#if _WIN32||_WIN64
#define raw_thread_id DWORD
#define get_raw_thread_id() GetCurrentThreadId()
#else
#define raw_thread_id pthread_t
#define get_raw_thread_id() pthread_self()
#endif

// then uncomment these to to enable a type of debug message
//#define DEBUG_PERLCALL
//#define DEBUG_VECTOR
//#define DEBUG_INIT
//#define DEBUG_CLONE
//#define DEBUG_FREE
//#define DEBUG_LEAK

// this one is likely to break everything
//#define DEBUG_PERLCALL_PEEK

#ifdef DEBUG_PERLCALL
#define IF_DEBUG_PERLCALL(msg, e...) IF_DEBUG_THR("[PERLCALL] " msg, ##e)
#else
#define IF_DEBUG_PERLCALL(msg, e...)
#endif

#ifdef DEBUG_VECTOR
#define IF_DEBUG_VECTOR(msg, e...) IF_DEBUG_THR("[VECTOR] " msg, ##e)
#else
#define IF_DEBUG_VECTOR(msg, e...)
#endif

#ifdef DEBUG_INIT
#define IF_DEBUG_INIT(msg, e...) IF_DEBUG_THR("[INIT] " msg, ##e)
#else
#define IF_DEBUG_INIT(msg, e...)
#endif

#ifdef DEBUG_CLONE
#define IF_DEBUG_CLONE(msg, e...) IF_DEBUG_THR("[CLONE] " msg, ##e)
#else
#define IF_DEBUG_CLONE(msg, e...)
#endif

#ifdef DEBUG_FREE
#define IF_DEBUG_FREE(msg, e...) IF_DEBUG_THR("[FREE] " msg, ##e)
#else
#define IF_DEBUG_FREE(msg, e...)
#endif

#ifdef DEBUG_LEAK
#define IF_DEBUG_LEAK(msg, e...) IF_DEBUG_THR("[LEAK] " msg, ##e)
#else
#define IF_DEBUG_LEAK(msg, e...)
#endif
