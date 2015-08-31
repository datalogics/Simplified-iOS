#import "NYPLReaderContainerDelegate.h"
#import "NYPLLOG.h"

#if defined(FEATURE_DRM_CONNECTOR)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wno-all"
#import <adept_filter.h>
#pragma clang diagnostic pop
#endif

@implementation NYPLReaderContainerDelegate

- (BOOL)container:(__attribute__((unused)) RDContainer *)container
   handleSdkError:(NSString * const)message
isSevereEpubError:(const BOOL)isSevereEpubError
{
  NYPLLOG_F(@"(Readium) %@ %@", isSevereEpubError ? @"(SEVERE)" : @"", message);

  // Ignore the error and continue.
  return YES;
}

#if defined(FEATURE_DRM_CONNECTOR)
- (void)containerRegisterFilters:(__attribute__((unused)) RDContainer *)container
{
  ePub3::AdeptFilter::Register();
}
#endif

@end