#if defined(COCOA)

#import <ApplicationServices/ApplicationServices.h>
#import <Cocoa/Cocoa.h>
/*
 * This is a start.  There appears to be only one NSView associated
 * with a frame (whose bounds object fills the frame), hence all
 * OpenGL renders to a small subwindow of the frame.  One possible
 * solution is to create a set of NSOpenGLViews as subviews of the
 * NSView covering the frame.
 */


#define FREEDIUS_GLOBAL(name) FREEDIUS_##name

// Tcl "private" window is an NSView.  In this version, we will create
// an NSOpenGLView for each FREEDIUS pane that we encounter....
//


/* Automatically generated by 'tklaouts' for Tk8.5 as distributed on
   Snow Leopard: */

typedef struct TkWindowProxy {
    char misc1[376];
  struct MacDrawable *privatePtr;
} TkWindowProxy;

#define TKP_TOPLEVEL_OFFSET 64

typedef struct MacDrawable {
    TkWindowProxy *winPtr;
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


struct glRenderingSpec
{
  int RgbaFlag;		/* configuration flags (ala GLX parameters) */
  int ColorBits;
  int DoubleFlag;
  int DepthSize;
  int AccumBits;
  int AlphaSize;
  int StencilSize;
  int OverlayFlag;
  int StereoFlag;
  int AuxNumber;
};


NSOpenGLPixelFormat *
fnsChooseAndSetPixelFormat( struct glRenderingSpec *spec )
{
  NSOpenGLPixelFormatAttribute attr[32];
  NSOpenGLPixelFormat *fmt;
  CGDirectDisplayID displayID = CGMainDisplayID ();

  int i = 0;

  attr[i++] = NSOpenGLPFAColorSize;
  if (spec->RgbaFlag) attr[i++] = 4*8;
  else attr[i++] = 3*8;

  attr[i++] = NSOpenGLPFADepthSize;
  attr[i++] = spec->DepthSize;

  // I think we need to force this no matter what:
  if (spec->DoubleFlag) attr[i++] = NSOpenGLPFADoubleBuffer;
  attr[i++] = NSOpenGLPFAPixelBuffer;
  attr[i++] = NSOpenGLPFANoRecovery;
  attr[i++] = NSOpenGLPFAAccelerated;
  attr[i++] = NSOpenGLPFABackingStore;
  // attr[i++] = NSOpenGLPFAOffScreen;   // Error.  Will not work.

  if (spec->StereoFlag)  attr[i++] = NSOpenGLPFAStereo;

  if (spec->StencilSize) {
    attr[i++] = NSOpenGLPFAStencilSize;
    attr[i++] = spec->StencilSize;
  }

  attr[i++] = NSOpenGLPFAAccumSize;
  attr[i++] = spec->AccumBits;

  attr[i++] = NSOpenGLPFAAccelerated;

  attr[i++] = NSOpenGLPFAScreenMask;
  attr[i++] = CGDisplayIDToOpenGLDisplayMask(displayID);
  attr[i] = 0;

  fmt = [[NSOpenGLPixelFormat alloc] initWithAttributes:attr];

  if (fmt == nil) {
    printf ("Failed creating OpenGL pixel format\n");
    return NULL;
  }
  return fmt;
}


struct glRenderingSpec *
FREEDIUS_GLOBAL(fnsMakeRenderingSpec)()
{ return (struct glRenderingSpec *) malloc(sizeof(struct glRenderingSpec));
}


NSOpenGLContext *
FREEDIUS_GLOBAL(fnsCreateContext) (struct glRenderingSpec *spec)
{
  NSAutoreleasePool *pool;
  NSOpenGLPixelFormat *fmt;
  NSOpenGLContext *context;
  NSOpenGLPixelFormatAttribute attrs[] =
    {
      NSOpenGLPFADoubleBuffer,
      NSOpenGLPFADepthSize, 32,
      0
    };

//  printf("fnsCreateContext\n");
  pool = [[NSAutoreleasePool alloc] init];

  fmt = fnsChooseAndSetPixelFormat(spec);

  if (fmt == nil) {
    printf ("Failed creating OpenGL pixel format\n");
    [pool release];
    return NULL;
  }

  context = [[NSOpenGLContext alloc] initWithFormat:fmt shareContext:nil];

  [fmt release];

  if (context == nil) {
    printf ("Failed creating OpenGL context\n");
    [pool release];
    return NULL;
  }

  /*
   * Wisdom from Apple engineer in reference to UT2003's OpenGL performance:
   *  "You are blowing a couple of the internal OpenGL function caches. This
   *  appears to be happening in the VAO case.  You can tell OpenGL to up
   *  the cache size by issuing the following calls right after you create
   *  the OpenGL context.  The default cache size is 16."    --ryan.
   */

#ifndef GLI_ARRAY_FUNC_CACHE_MAX
#define GLI_ARRAY_FUNC_CACHE_MAX 284
#endif

#ifndef GLI_SUBMIT_FUNC_CACHE_MAX
#define GLI_SUBMIT_FUNC_CACHE_MAX 280
#endif

  {
    const GLint cache_max = 64;
    CGLContextObj ctx = [context CGLContextObj];
    CGLSetParameter (ctx, GLI_SUBMIT_FUNC_CACHE_MAX, &cache_max);
    CGLSetParameter (ctx, GLI_ARRAY_FUNC_CACHE_MAX, &cache_max);
  }

  /* End Wisdom from Apple Engineer section. --ryan. */

  [pool release];

  return context;
}



#if 0
NSView *
FREEDIUS_GLOBAL(fnsGetView) (MacDrawable *win)
{
  NSView * Tk_MacOSXDrawableView( MacDrawable * );

  return Tk_MacOSXDrawableView( win );
}
#endif

//char * Tk_MacOSXDrawableView( char *macWin )


#define TK_EMBEDDED  0x100

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


int
FREEDIUS_GLOBAL(fnsSetViewBounds) (NSView *nsview, double x, double y, double w, double h)
{
  int rc = 1;
  NSRect bounds;

  bounds.origin.x =  x;
  bounds.origin.y =  y;
  bounds.size.width =  w;
  bounds.size.height =  h;

  [nsview setBounds: bounds];

  return rc;
}


int
FREEDIUS_GLOBAL(fnsSetViewFrame) (NSView *nsview, int x, int y, int w, int h)
{
  int rc = 1;
  NSRect bounds;

  bounds.origin.x =  (double)  x;
  bounds.origin.y =  (double) y;
  bounds.size.width =  (double) w;
  bounds.size.height =  (double) h;

  [nsview setFrame: bounds];

  return rc;
}


NSView *
FREEDIUS_GLOBAL(fnsCreateView) (MacDrawable *win)
{
  NSView *parent = TkMacOSXDrawableView(win);
#if 0
  NSRect frameRect;

  printf("fnsCreateView\n");
  HIShapeGetBounds(win->drawRgn, &frameRect);

  frameRect.origin.x += 2.0;
  frameRect.origin.y += 2.0;
  frameRect.size.width -= 4.0;
  frameRect.size.height -= 4.0;

  NSView *newchild = [[NSView alloc] initWithFrame: frameRect];

  [parent addSubview: newchild];

  [newchild viewDidMoveToSuperview];

  /*
  printf("Frame for new view %x: [%f %f %f %f]\n",
	 newchild, frameRect.origin.x, frameRect.origin.y,
	 frameRect.size.width, frameRect.size.height);
  */
  return newchild;
#endif
 return 0;
}


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
    printf ("Failed creating OpenGL pixel format\n");
    [pool release];
    return NULL;
  }

 printf("     setting frame rectangle...(x,y = %d,%d ; xOff,yOff = %d,%d)\n", x, y, win->xOff, win->yOff);
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

  //  printf("     allocating NSOpenGLView...\n");
  NSOpenGLView *newchild = [[NSOpenGLView alloc] initWithFrame: frameRect pixelFormat: fmt];
  //  printf("            returns %lx...\n", (unsigned long) newchild);

  [fmt release];

  if (newchild == nil) {
    [pool release];
    printf("Could not create an NSOpenGLView with this rendering spec.\n");
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



int FREEDIUS_GLOBAL(fnsGetViewBounds) (NSView *nsview, double *bounds)
{
  NSRect r = [nsview bounds];
  /*  printf("Bounds for %x: %f %f %f %f\n",
      nsview, r.origin.x,  r.origin.y,  r.size.height, r.size.width); */
  bounds[0] = r.origin.x;
  bounds[1] = r.origin.y;
  bounds[2] = r.size.width;
  bounds[3] = r.size.height;
  
  return 4;
}


int
FREEDIUS_GLOBAL(fnsUnMakeViewCurrent) (NSOpenGLView *nsview)
{
  NSView *prev = [NSView focusView];

  if (prev) [prev unlockFocus];

  return 1;
}


int
FREEDIUS_GLOBAL(fnsMakeViewCurrent) (MacDrawable *win, NSOpenGLView *nsview, NSOpenGLContext *nscontext)
{
  NSAutoreleasePool *pool;

  pool = [[NSAutoreleasePool alloc] init];

  if (nsview && [nsview canDraw]) {
    // In Cocoa, we must bracket GL drawing within a lockFocus -
    // unlockFocus pair.

    // In case we have not properly bracketed the GL calls, unlock
    // focus if necessary:
						
    NSView *prev = [NSView focusView];

    if (prev) [prev unlockFocus];

    [nsview lockFocus];

    //  printf("fnsMakeViewCurrent: win offsets = %d,%d\n", win->xOff, win->yOff);

    NSRect r = [nsview bounds];
    //    printf("fnsMakeViewCurrent: Bounds for %x: %f %f %f %f\n",
    // nsview, r.origin.x,  r.origin.y,  r.size.height, r.size.width);

    // This only needs to be done once, right?
    //    [nscontext setView: nsview];
    // [nscontext update];
    //    [nscontext makeCurrentContext];

    [[nsview openGLContext] update];
    [[nsview openGLContext] makeCurrentContext];

    [pool release];
    return 1;
  }
  [pool release];
  return 0;
}



int
FREEDIUS_GLOBAL(fnsMakePBufferCurrent) (NSOpenGLPixelBuffer *p, NSOpenGLContext *nscontext)
{
  NSAutoreleasePool *pool;

  pool = [[NSAutoreleasePool alloc] init];
 
  [nscontext setPixelBuffer:p cubeMapFace:0 mipMapLevel:0 currentVirtualScreen:[nscontext currentVirtualScreen]];

  [nscontext update];
  [nscontext makeCurrentContext];

  [pool release];
  return 1;
}



void
FREEDIUS_GLOBAL(fnsSwapBuffers) (NSOpenGLContext *nscontext)
{
  NSAutoreleasePool *pool;

  pool = [[NSAutoreleasePool alloc] init];

  if (nscontext != nil) {
    [nscontext flushBuffer];
  }

  [pool release];
}

int FREEDIUS_GLOBAL(fnsHideCursor)() {
  [NSCursor hide];
  return 1;
}

int FREEDIUS_GLOBAL(fnsShowCursor)() {
  [NSCursor unhide];
  return 1;
}

// The following use CoreGraphics calls and are not really
// Cocoa-specific:


/* CGWarpMouseCursorPosition
 * Warp the mouse cursor to the desired position in global
 * coordinates without generating events
 */

/* CGDisplayMoveCursorToPoint
 * Move the cursor to the specified point relative to the display origin
 * (the upper left corner of the display).  Returns CGDisplayNoErr on success.
 * No events are generated as a result of this move.
 * Points that would lie outside the desktop are clipped to the desktop.
 */

int FREEDIUS_GLOBAL(fnsWarpCursor)(int screenx, int screeny) {
  CGPoint pt;
  CGDirectDisplayID DispID = CGMainDisplayID();
  pt.x = (float) screenx;
  pt.y = (float) screeny;
  return CGDisplayMoveCursorToPoint(DispID, pt);
}

void
FREEDIUS_GLOBAL(fnsActivateMe) ()
{
 [NSApp activateIgnoringOtherApps:YES];
}


NSOpenGLPixelBuffer *
FREEDIUS_GLOBAL(fnsCreatePBuffer)(NSOpenGLContext *ctx, int width, int height)
{
 NSAutoreleasePool *pool;

 pool = [[NSAutoreleasePool alloc] init];

 NSOpenGLPixelBuffer *buf;

 buf =
 [[NSOpenGLPixelBuffer alloc]
  initWithTextureTarget:GL_TEXTURE_2D
  textureInternalFormat:GL_RGBA
  textureMaxMipMapLevel:0
  pixelsWide:width
  pixelsHigh:height];

  printf("fnsCreatePBuffer: PixelBuffer object created at %lx\n", (unsigned long) buf);

 [ctx setPixelBuffer:buf cubeMapFace:0 mipMapLevel:0 currentVirtualScreen:[ctx currentVirtualScreen]];
// [ctx setPixelBuffer:buf];
 
 [pool release];

 return buf;
}


#endif /* COCOA */
