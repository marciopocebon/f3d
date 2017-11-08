#include <tkInt.h>                      /* Use TkWindow */
#include <tkMacOSXInt.h>                /* Use MacDrawable */

/* The '1' here should be changed to something that detects the Tk
 *   version.  This change occurs in 8.6, I think:
 */
#if 1
#define NSOPENGLVIEW(x) (x->grafPtr)
#else
#define NSOPENGLVIEW(x) (x->view)
#endif

// Tcl "private" window is an NSView (??).  In this version, we will
// create an NSOpenGLView for each FREEDIUS pane that we encounter....



/* Automatically generated by 'tklaouts' for Tk8.5 as distributed on
   Snow Leopard: */

#if 0
// Evil - 
typedef struct TkWindowProxy {
    char misc1[376];
  struct MacDrawable *privatePtr;
} TkWindowProxy;

// #define TKP_TOPLEVEL_OFFSET 64

typedef struct MacDrawable {
    TkWindow *winPtr;
    NSView *view;
    CGContextRef context;
    int xOff;                  /* X offset from toplevel window */
    int yOff;                  /* Y offset from toplevel window */
    CGSize size;
    HIShapeRef visRgn;         /* Visible region of window */
    HIShapeRef aboveVisRgn;    /* Visible region of window & its children */
    HIShapeRef drawRgn;        /* Clipped drawing region */
    int referenceCount;        /* Don't delete toplevel until children are
                                * gone. */
    struct MacDrawable *toplevel;
                               /* Pointer to the toplevel datastruct. */
    int flags;                 /* Various state see defines below. */
} MacDrawable;
#endif

#define TK_EMBEDDED  0x100

#if 1
static NSView*
TkMacOSXDrawableView( MacDrawable *macWin )
{
    NSView *result = nil;
    TkWindow * TkpGetOtherWindow(TkWindow *);

    if (!macWin) {
	result = nil;
    } else if (!macWin->toplevel) {
      result = NSOPENGLVIEW(macWin);
    } else if (!(macWin->toplevel->flags & TK_EMBEDDED)) {
      result = NSOPENGLVIEW(macWin->toplevel);
    } else {
      TkWindow *contWinPtr = (TkWindow *) TkpGetOtherWindow( macWin->toplevel->winPtr);
      if (contWinPtr) {
	result = TkMacOSXDrawableView(contWinPtr->privatePtr);
      }
    }
    return result;
}

#else

static NSView*
TkMacOSXDrawableView(
    MacDrawable *macWin)
{
    NSView *result = nil;
    TkWindowProxy * TkpGetOtherWindow(TkWindowProxy *);

    if (!macWin) {
	result = nil;
    } else if (!macWin->toplevel) {
	result = macWin->view;
    } else if (!(macWin->toplevel->flags & TK_EMBEDDED)) {
	result = macWin->toplevel->view;
    } else {
      TkWindowProxy *contWinPtr = (TkWindowProxy *) TkpGetOtherWindow( macWin->toplevel->winPtr);
      if (contWinPtr) {
	result = TkMacOSXDrawableView(contWinPtr->privatePtr);
      }
    }
    return result;
}
#endif


#if 0
int
FREEDIUS_GLOBAL(fnsMakeCurrent) (MacDrawable *win, NSOpenGLContext *nscontext)
{
  NSAutoreleasePool *pool;

  pool = [[NSAutoreleasePool alloc] init];

  if (nscontext) {
    NSView *nsview = TkMacOSXDrawableView(win);

    // This only needs to be done once, right?
    [nscontext setView: nsview];
    //    [nscontext update];
    [nscontext makeCurrentContext];
    
    // For Cocoa, you MUST call glViewport to set up the proper
    // rendering box within the parent window.  This is done in the
    // glMakeCurrent method of the tk-cocoa window definition.

//    printf("in fnsMakeCurrent:  xoff,yoff = %d,%d\n", win->xOff, win->yOff);

    [pool release];

    return 1;
  }
  [pool release];

  return 0;
}

#else

int
FREEDIUS_GLOBAL(fnsMakeCurrent) (NSView *nsview, NSOpenGLContext *nscontext)
{
  NSAutoreleasePool *pool;

  pool = [[NSAutoreleasePool alloc] init];

  // This only needs to be done once, right?
  [nscontext setView: nsview];
  //    [nscontext update];
  [nscontext makeCurrentContext];
    
  // For Cocoa, you MUST call glViewport to set up the proper
  // rendering box within the parent window.  This is done in the
  // glMakeCurrent method of the tk-cocoa window definition.
  
  //    printf("in fnsMakeCurrent:  xoff,yoff = %d,%d\n", win->xOff, win->yOff);

  [pool release];

  return 1;
}

#endif

/*
 * This should be placed with Tk-dependent code (lisptk):
 */
NSOpenGLView *
FREEDIUS_GLOBAL(fnsCreateOpenGLView) (MacDrawable *win, struct glRenderingSpec *spec, int x, int y, int w, int h)
{
  NSAutoreleasePool *pool;
  NSOpenGLPixelFormat *fmt;
  NSRect frameRect;

  //  printf("fnsCreateOpenGLView\n");
  pool = [[NSAutoreleasePool alloc] init];

  //  printf("     fnsChooseAndSetPixelFormat (spec = %lx)...\n", (unsigned long) spec);
  fmt = fnsChooseAndSetPixelFormat(spec);
  //  printf("            returns %lx...\n", (unsigned long) fmt);

  if (fmt == nil) {
    printf ("fnsCreateOpenGLView: Failed creating OpenGL pixel format\n");
    [pool release];
    return NULL;
  }

  printf("fnsCreateOpenGLView: setting frame rectangle...(x,y = %d,%d ; xOff,yOff = %d,%d)\n", x, y, win->xOff, win->yOff);
  frameRect.origin.x = (double) win->xOff;
  frameRect.origin.y = (double) win->yOff;

  frameRect.size.width = (double) w;
  frameRect.size.height = (double) h;

  /*
  printf("drawRgn: [%f %f %f %f]\n",
	 frameRect.origin.x, frameRect.origin.y,
	 frameRect.size.width, frameRect.size.height);
  */

  if (frameRect.size.width <= 0.0 || frameRect.size.height <= 0.0) {
    printf("Null region.  Can't create a view yet.\n");
    [pool release];
    return NULL;
  }

  printf("fnsCreateOpenGLView: allocating NSOpenGLView.\n");
  NSOpenGLView *newchild = [[NSOpenGLView alloc] initWithFrame: frameRect pixelFormat: fmt];
  //  printf("            returns %lx...\n", (unsigned long) newchild);

  [fmt release];

  if (newchild == nil) {
    [pool release];
    printf("fnsCreateOpenGLView: Could not create an NSOpenGLView with this rendering spec.\n");
  }

  NSView *parent = TkMacOSXDrawableView(win);

  [parent addSubview: newchild];

#if 0
  printf("fnsCreateOpenGLView: Frame for new view %x: [%f %f %f %f]\n",
	 newchild, frameRect.origin.x, frameRect.origin.y,
	 frameRect.size.width, frameRect.size.height);
#endif

  [pool release];

  return newchild;
}
