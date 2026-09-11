//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<integration_test/IntegrationTestPlugin.h>)
#import <integration_test/IntegrationTestPlugin.h>
#else
@import integration_test;
#endif

#if __has_include(<interactive_3d/Interactive3dPlugin.h>)
#import <interactive_3d/Interactive3dPlugin.h>
#else
@import interactive_3d;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [IntegrationTestPlugin registerWithRegistrar:[registry registrarForPlugin:@"IntegrationTestPlugin"]];
  [Interactive3dPlugin registerWithRegistrar:[registry registrarForPlugin:@"Interactive3dPlugin"]];
}

@end
