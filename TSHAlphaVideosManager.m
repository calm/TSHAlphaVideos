#import "TSHAlphaVideosManager.h"
#import "TSHAlphaVideoController.h"

@interface TSHAlphaVideosManager ()
calm_declare_singleton(TSHAlphaVideosManager)
@end

@implementation TSHAlphaVideosManager
calm_synthesize_singleton(TSHAlphaVideosManager)

#pragma mark - url
+ (BOOL)canPlayVideoOfName:(NSString *)name
{
    NSURL *url = [self urlForAlphaVideoOfName:name];
    return url != nil;
}

+ (NSURL *)urlForAlphaVideoOfName:(NSString *)name
{
    return [[NSBundle mainBundle] URLForResource:name
                                   withExtension:kDefaultAlphaVideoFileExtension];
}

@end
