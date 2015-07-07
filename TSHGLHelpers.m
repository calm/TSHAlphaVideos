#import "TSHGLHelpers.h"

static EAGLContext *globalContext;

@implementation TSHGLHelpers

+ (GLuint)roundToPowerOf2:(GLuint)v
{
    v--;
    v |= v >> 1;
    v |= v >> 2;
    v |= v >> 4;
    v |= v >> 8;
    v |= v >> 16;
    v++;

    return v;
}

+ (BOOL)loadTexture:(UIImage *)image
{
    if (image == nil) {
        NSLog(@"Error: UIImage == nil...");
        return NO;
    }

    // convert to RGBA
    GLuint width = (unsigned int)CGImageGetWidth(image.CGImage);
    GLuint height = (unsigned int)CGImageGetHeight(image.CGImage);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    GLuint newWidth = [TSHGLHelpers roundToPowerOf2:width];
    GLuint newHeight = [TSHGLHelpers roundToPowerOf2:height];

    void *imageData = malloc(newWidth * newHeight * 4);

    CGContextRef context = CGBitmapContextCreate(imageData, newWidth, newHeight, 8, 4 * newWidth, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);


    CGContextClearRect(context, CGRectMake(0, 0, newWidth, newHeight));
    CGContextTranslateCTM(context, 0, 0);
    CGContextDrawImage(context, CGRectMake(0, 0, newWidth, newHeight), image.CGImage);

    // load the texture
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, newWidth, newHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);

    //glGenerateMipmap(GL_TEXTURE_2D);

    // free resource - OpenGL keeps image internally
    CGContextRelease(context);
    free(imageData);

    return YES;
}

+ (BOOL)checkGLError
{
    GLenum error = glGetError();
    if (error != GL_NO_ERROR) {
        NSLog(@"OpenGL Error: %x", error);
        return YES;
    }
    return NO;
}

+ (void)drawLineFromPoint:(CGPoint)start
                  toPoint:(CGPoint)end
{
    [TSHGLHelpers drawLineFromPoint:start
                           toPoint:end
                         withWidth:5.0];
}

+ (void)drawLineFromPoint:(CGPoint)start
                  toPoint:(CGPoint)end
                withWidth:(float)width
{
    glEnableClientState(GL_VERTEX_ARRAY);

    glLineWidth(width);

    GLfloat lineVertices[4] = {
            start.x,
            start.y,
            end.x,
            end.y
    };

    glPushMatrix();
    glVertexPointer(2, GL_FLOAT, 0, lineVertices);
    glDrawArrays(GL_LINE_STRIP, 0, 2);
    glPopMatrix();
}

+ (EAGLContext *)getOpenGLESContext
{
    if (!globalContext) {
        globalContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
        if (!globalContext) {
            globalContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        }
    }

    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3
                                                 sharegroup:globalContext.sharegroup];
    if (!context) {
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2
                                        sharegroup:globalContext.sharegroup];
    }
    return context;
}

+ (void)releaseSharedContext
{
    globalContext = nil;
}

@end
