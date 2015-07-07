#import <Foundation/Foundation.h>

@interface TSHAlphaVideosManager : NSObject

+ (BOOL)canPlayVideoOfName:(NSString *)name;
+ (NSURL *)urlForAlphaVideoOfName:(NSString *)name;

@end
