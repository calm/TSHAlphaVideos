#import <UIKit/UIKit.h>

#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

@interface OpenGLView : UIView
{
    // must use old-school ivars so we can pass their addresses along to OpenGL calls
    GLint framebufferWidth;
    GLint framebufferHeight;

    GLuint defaultFramebuffer;
    GLuint colorRenderbuffer;
    GLuint depthRenderbuffer;

    GLuint sampleFramebuffer;
    GLuint sampleColorRenderbuffer;
}

typedef struct OpenGlViewParameters
{
    BOOL depthBuffer;
    CGFloat resolutionScale;
} OpenGLViewParameters;

@property (nonatomic, strong) EAGLContext *context;

- (instancetype)initWithFrame:(CGRect)frame
               andEAGLContext:(EAGLContext *)context
                andParameters:(OpenGLViewParameters)params;

- (instancetype)initWithFrame:(CGRect)frame
               andEAGLContext:(EAGLContext *)context;

- (void)setFramebuffer;

- (BOOL)presentFramebuffer;

@end
