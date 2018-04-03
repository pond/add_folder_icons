/******************************************************************************\
 * Utilities: GlobalSempahore.h
 *
 * Global locking semaphore, used for brief moments when otherwise entirely
 * parallel operations need to be run in series.
 *
 * (C) Hipposoft 2009, 2010, 2011 <ahodgkin@rowing.org.uk>
\******************************************************************************/

#include <Cocoa/Cocoa.h>

/******************************************************************************\
 * globalSemaphoreInit()
 *
 * Initialise the global semaphore system. Call this from your application main
 * thread BEFORE invoking ANY multithreaded code which needs the semaphore.
\******************************************************************************/

void globalSemaphoreInit( void );

/******************************************************************************\
 * globalSemaphoreClaim()
 *
 * Get hold of the global semaphore. If someone else has it, this call will
 * block until the semaphore is released. You MUST release a claimed semaphore
 * by calling "globalSemaphoreRelease" (so always use @try...@finally).
 *
 * The application must have called "globalSemaphoreInit" in its main thread
 * prior to starting a thread which runs code which requires this function.
\******************************************************************************/

void globalSemaphoreClaim( void );

/******************************************************************************\
 * globalSemaphoreRelease()
 *
 * Release the global semaphore. Other code using it can then run. See also
 * "globalSemaphoreClaim".
 *
 * The application must have called "globalSemaphoreInit" in its main thread
 * prior to starting a thread which runs code which requires this function.
\******************************************************************************/

void globalSemaphoreRelease( void );
