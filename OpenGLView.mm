#import "OpenGLView.h"

@interface OpenGLView ()

- (void)createFramebuffer;

- (void)deleteFramebuffer;

@property (nonatomic, assign) BOOL hasDepthBuffer;

@end

@implementation OpenGLView

- (instancetype)initWithFrame:(CGRect)frame
     andEAGLContext:(EAGLContext *)context
      andParameters:(OpenGLViewParameters)params
{
    self = [super initWithFrame:frame];

    if (self) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];

        self.context = context;

        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;

        CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
        const CGFloat myColor[] = {
                0.0,
                0.0,
                0.0,
                0.0
        };
        CGColorRef bgColor = CGColorCreate(rgb, myColor);
        eaglLayer.backgroundColor = bgColor;
        CGColorSpaceRelease(rgb);
        CGColorRelease(bgColor);

        eaglLayer.opaque = NO;
        eaglLayer.opacity = 1.0;
        eaglLayer.drawableProperties = @{
                kEAGLDrawablePropertyRetainedBacking : @NO,
                kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8
        };
        self.contentScaleFactor = params.resolutionScale;
        self.hasDepthBuffer = params.depthBuffer;
        [self setFramebuffer];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
     andEAGLContext:(EAGLContext *)context
{
    OpenGLViewParameters params;
    params.resolutionScale = 1.5;
    params.depthBuffer = YES;
    return [self initWithFrame:frame
                andEAGLContext:context
                 andParameters:params];
}

- (void)refreshContext
{
    if (![[EAGLContext currentContext] isEqual:self.context]) {
        [EAGLContext setCurrentContext:self.context];
    }
}

- (void)dealloc
{
    [self deleteFramebuffer];
    self.context = nil;
}

// Must implement this to change it from a CALayer to a CAEAGLLayer
+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (void)setContext:(EAGLContext *)context
{
    if ([self.context isEqual:context]) {
        return;
    }

    [self deleteFramebuffer];
    _context = nil;
    _context = context;

    [EAGLContext setCurrentContext:nil];
}

- (void)setFramebuffer
{
    if (self.context) {
        [EAGLContext setCurrentContext:self.context];

        if (!defaultFramebuffer) {
            [self createFramebuffer];
        }

        glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
        glViewport(0, 0, framebufferWidth, framebufferHeight);
    }
}

- (BOOL)presentFramebuffer
{
    BOOL success = FALSE;

    if (self.context) {
        [EAGLContext setCurrentContext:self.context];
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
        success = [self.context presentRenderbuffer:GL_RENDERBUFFER];
    }

    return success;
}

- (void)createFramebuffer
{
    if (self.context && !defaultFramebuffer) {
        [EAGLContext setCurrentContext:self.context];

        // Create default framebuffer object.
        glGenFramebuffers(1, &defaultFramebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);

        // Create color render buffer and allocate backing store.
        glGenRenderbuffers(1, &colorRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);

        [self.context renderbufferStorage:GL_RENDERBUFFER
                             fromDrawable:(CAEAGLLayer *)self.layer];

        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &framebufferWidth);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &framebufferHeight);

        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderbuffer);

        // Create a depth buffer

        if (self.hasDepthBuffer) {
            glGenRenderbuffers(1, &depthRenderbuffer);
            glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
            glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16_OES, framebufferWidth, framebufferHeight);
            glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER, depthRenderbuffer);
        }
        //Create Multisampling buffers

        //glGenFramebuffers(1, &sampleFramebuffer);
        //glBindFramebuffer(GL_FRAMEBUFFER, sampleFramebuffer);

        /*
         // Create Anti-aliasing buffers
         glGenFramebuffers(1, &sampleFramebuffer);
         glBindFramebuffer(GL_FRAMEBUFFER, sampleFramebuffer);

         glGenRenderbuffers(1, &sampleColorRenderbuffer);
         glBindRenderbuffer(GL_RENDERBUFFER, sampleColorRenderbuffer);
         glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER, 2, GL_RGBA8_OES, framebufferWidth, framebufferHeight);
         glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, sampleColorRenderbuffer);

         glGenRenderbuffers(1, &depthRenderbuffer);
         glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
         glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER, 2, GL_DEPTH_COMPONENT16, framebufferWidth, framebufferHeight);
         glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);
         */

        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        }
    }
}

- (void)deleteFramebuffer
{
    if (self.context) {
        [EAGLContext setCurrentContext:self.context];

        if (defaultFramebuffer) {
            glDeleteFramebuffers(1, &defaultFramebuffer);
            defaultFramebuffer = 0;
        }

        if (colorRenderbuffer) {
            glDeleteRenderbuffers(1, &colorRenderbuffer);
            colorRenderbuffer = 0;
        }

        if (depthRenderbuffer) {
            glDeleteRenderbuffers(1, &depthRenderbuffer);
            depthRenderbuffer = 0;
        }
    }
}

@end
