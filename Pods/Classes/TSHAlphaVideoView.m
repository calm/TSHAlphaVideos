#import "TSHAlphaVideoView.h"
#import "TSHGLHelpers.h"
#import "OpenGLShaderUtilities.h"

#define STRINGIZE(x) #x
#define SHADER_STRING(text) @ STRINGIZE(text)

// OpenGL fragment shader to set the color and alpha
NSString *const kAlphaVideoFragmentShaderString = SHADER_STRING
(
        varying highp vec2 textureCoordinateRGB;
        varying highp vec2 textureCoordinateAlpha;

        uniform sampler2D inputImageTexture;

        void main() {
            highp vec4 rgbColor = texture2D(inputImageTexture, textureCoordinateRGB);
            highp vec4 alphaColor = texture2D(inputImageTexture, textureCoordinateAlpha);
            gl_FragColor = vec4(rgbColor.r, rgbColor.g, rgbColor.b, alphaColor.r);
        }
);

// OpenGL vertex shader to define the points to read the color and alpha values
NSString *const kAlphaVideoVertexShaderString = SHADER_STRING
(
        attribute vec4 position;
        attribute vec4 textureCoordinate;

        varying vec2 textureCoordinateRGB;
        varying vec2 textureCoordinateAlpha;

        void main() {
            gl_Position = position;
            textureCoordinateRGB = vec2(textureCoordinate.x, textureCoordinate.y);
            textureCoordinateAlpha = vec2(textureCoordinate.x + 0.5, textureCoordinate.y);
        }
);

// matches the attributes defined in the vertex shader
typedef NS_ENUM(NSInteger, ShaderAttribute) {
    ShaderAttributePosition,
    ShaderAttributeTextureCoordinate,
    NumShaderAttributes
};

@interface TSHAlphaVideoView ()
{
    // use old-school ivars so we can pass their addresses along to OpenGL calls
    CVOpenGLESTextureCacheRef videoTextureCache;
    GLuint displayProgram;
}
@end

@implementation TSHAlphaVideoView

- (void)dealloc
{
    if (displayProgram) {
        [self setCurrentGLContext];
        glDeleteProgram(displayProgram);
        displayProgram = 0;
    }

    CVOpenGLESTextureCacheFlush(videoTextureCache, 0);

    if (videoTextureCache) {
        CFRelease(videoTextureCache);
        videoTextureCache = 0;
    }
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame
                 andEAGLContext:[TSHGLHelpers getOpenGLESContext]];

    if (self != nil) {
        [self initializeVideoCache];
        [self initializeDisplayProgram];
    }

    return self;
}

// the openGL "program" compiles the vertex and fragment shaders so we can use
// them on the rendered pixels.
- (void)initializeDisplayProgram
{
    // Load OpenGL vertex and fragment shaders
    const GLchar *vertSrc = (GLchar *)[kAlphaVideoVertexShaderString UTF8String];
    const GLchar *fragSrc = (GLchar *)[kAlphaVideoFragmentShaderString UTF8String];

    // attributes found in the shaders
    GLint attribLocation[NumShaderAttributes] = {
            ShaderAttributePosition, ShaderAttributeTextureCoordinate,
    };
    GLchar *attribName[NumShaderAttributes] = {
            "position", "textureCoordinate",
    };
    
    [self setCurrentGLContext];
    
    // create the program, specifying which attributes and uniform variables are used in
    // the shaders.
    openGlCreateProgram(vertSrc, fragSrc,
                        NumShaderAttributes, (const GLchar **)&attribName[0], attribLocation,
                        0, 0, 0, // no uniform variables for now
                        &displayProgram);
}

- (void)initializeVideoCache
{
    [self setCurrentGLContext];
    
    //  Create a new CVOpenGLESTexture cache
    CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault,
                                                NULL,
                                                self.context,
                                                NULL,
                                                &videoTextureCache);
    if (err != kCVReturnSuccess) {
#if defined(DEBUG)
        NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
#endif
    }
}

- (void)renderWithSquareVertices:(const GLfloat *)squareVertices
                 textureVertices:(const GLfloat *)textureVertices
{
    [self setCurrentGLContext];
    
    // Use shader program.
    glUseProgram(displayProgram);

    // blend using the alpha of the frame
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    // Update attribute values.
    glVertexAttribPointer(ShaderAttributePosition, 2, GL_FLOAT, 0, 0, squareVertices);
    glEnableVertexAttribArray(ShaderAttributePosition);
    glVertexAttribPointer(ShaderAttributeTextureCoordinate, 2, GL_FLOAT, 0, 0, textureVertices);
    glEnableVertexAttribArray(ShaderAttributeTextureCoordinate);

    // Update uniform values if there are any (none for now).

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    // Present the buffer to be rendered on the screen.
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    [self.context presentRenderbuffer:GL_RENDERBUFFER];

    glDisable(GL_BLEND);
}

- (CGRect)textureSamplingRectForCroppingTextureWithAspectRatio:(CGSize)textureAspectRatio
                                                 toAspectRatio:(CGSize)croppingAspectRatio
{
    CGRect normalizedSamplingRect = CGRectZero;
    CGSize cropScaleAmount = CGSizeMake(croppingAspectRatio.width / textureAspectRatio.width,
                                        croppingAspectRatio.height / textureAspectRatio.height);
    CGFloat maxScale = fmax(cropScaleAmount.width, cropScaleAmount.height);
    CGSize scaledTextureSize = CGSizeMake(textureAspectRatio.width * maxScale,
                                          textureAspectRatio.height * maxScale);

    if (cropScaleAmount.height > cropScaleAmount.width) {
        normalizedSamplingRect.size.width = croppingAspectRatio.width / scaledTextureSize.width;
        normalizedSamplingRect.size.height = 1.0;
    }
    else {
        normalizedSamplingRect.size.height = croppingAspectRatio.height / scaledTextureSize.height;
        normalizedSamplingRect.size.width = 1.0;
    }
    // Center crop (not needed yet).
    // normalizedSamplingRect.origin.x = (1.0 - normalizedSamplingRect.size.width)/2.0;
    // normalizedSamplingRect.origin.y = (1.0 - normalizedSamplingRect.size.height)/2.0;

    return normalizedSamplingRect;
}

- (void)displayPixelBuffer:(CVImageBufferRef)pixelBuffer
{
    [self setCurrentGLContext];

    // remove the last frame from the buffer each time you render the frame
    // so you don't see any ghosting between frames.
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    if (defaultFramebuffer == 0) {
        [self setFramebuffer];
    }

    if (videoTextureCache == NULL) {
        [self initializeVideoCache];
    }

    // the pixelBuffer contains all the pixel data for the frame we want
    // to display for the video, so make sure it is valid, and then
    // render the frame to the screen using OpenGL
    if (pixelBuffer != NULL) {

        // Create a CVOpenGLESTexture from the CVImageBuffer
        int frameWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
        int frameHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
        CVOpenGLESTextureRef texture = NULL;
        CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                    videoTextureCache,
                                                                    pixelBuffer,
                                                                    NULL,
                                                                    GL_TEXTURE_2D,
                                                                    GL_RGBA,
                                                                    frameWidth,
                                                                    frameHeight,
                                                                    GL_BGRA,
                                                                    GL_UNSIGNED_BYTE,
                                                                    0,
                                                                    &texture);

        if (!texture || err) {
#if defined(DEBUG)
            NSLog(@"CVOpenGLESTextureCacheCreateTextureFromImage failed (error: %d)", err);
#endif
            return;
        }

        glBindTexture(CVOpenGLESTextureGetTarget(texture), CVOpenGLESTextureGetName(texture));

        // Set texture parameters
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_TSHAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_TSHAMP_TO_EDGE);

        glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);

        // Set the view port to the entire view
        glViewport(0, 0, framebufferWidth, framebufferHeight);

        // set up the texture verticies for the frame texture
        static const GLfloat squareVertices[] = {
                -1.0f, -1.0f,
                1.0f, -1.0f,
                -1.0f, 1.0f,
                1.0f, 1.0f,
        };

        // The texture vertices are set up such that we flip the texture vertically.
        // This is so that our top left origin buffers match OpenGL's bottom left texture coordinate system.
        CGRect textureSamplingRect = [self textureSamplingRectForCroppingTextureWithAspectRatio:CGSizeMake(frameWidth, frameHeight)
                                                                                  toAspectRatio:self.bounds.size];
        GLfloat textureVertices[] = {
                CGRectGetMinX(textureSamplingRect), CGRectGetMaxY(textureSamplingRect),
                CGRectGetMaxX(textureSamplingRect), CGRectGetMaxY(textureSamplingRect),
                CGRectGetMinX(textureSamplingRect), CGRectGetMinY(textureSamplingRect),
                CGRectGetMaxX(textureSamplingRect), CGRectGetMinY(textureSamplingRect),
        };

        // Draw the texture on the screen with OpenGL ES 2
        [self renderWithSquareVertices:squareVertices
                       textureVertices:textureVertices];

        glBindTexture(CVOpenGLESTextureGetTarget(texture), 0);

        // release the memory of the texture
        CFRelease(texture);
    }

    // make sure the video texture cache is flushed after each frame.
    CVOpenGLESTextureCacheFlush(videoTextureCache, 0);
}

- (void)prepareForBackground
{
    // call glFinish if the app is going into background mode to make sure no OpenGL
    // commands are run while in the background.
    [self setCurrentGLContext];
    glFinish();
}

- (void)setCurrentGLContext
{
    if (![[EAGLContext currentContext] isEqual:self.context]) {
        [EAGLContext setCurrentContext:self.context];
    }
}

@end
