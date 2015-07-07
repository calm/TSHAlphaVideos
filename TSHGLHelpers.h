#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

@interface TSHGLHelpers : NSObject

+ (BOOL)loadTexture:(UIImage *)image;

+ (void)drawLineFromPoint:(CGPoint)start
                  toPoint:(CGPoint)end;

+ (void)drawLineFromPoint:(CGPoint)start
                  toPoint:(CGPoint)end
                withWidth:(float)width;

+ (EAGLContext *)getOpenGLESContext;

+ (BOOL)checkGLError;

+ (void)releaseSharedContext;

@end
