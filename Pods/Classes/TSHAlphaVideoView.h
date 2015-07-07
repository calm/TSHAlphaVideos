#import <UIKit/UIKit.h>
#import "OpenGLView.h"

@interface TSHAlphaVideoView : OpenGLView

- (void)displayPixelBuffer:(CVImageBufferRef)pixelBuffer;
- (void)prepareForBackground;

@end
