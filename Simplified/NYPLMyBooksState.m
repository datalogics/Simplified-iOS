#import "NYPLMyBooksState.h"

static NSString *const Downloading = @"downloading";
static NSString *const DownloadFailed = @"download-failed";
static NSString *const DownloadNeeded = @"download-needed";
static NSString *const DownloadSuccessful = @"download-successful";
static NSString *const Unregistered = @"unregistered";
static NSString *const Used = @"used";

NYPLMyBooksState NYPLMyBooksStateFromString(NSString *const string)
{
  if([string isEqualToString:Downloading]) return NYPLMyBooksStateDownloading;
  if([string isEqualToString:DownloadFailed]) return NYPLMyBooksStateDownloadFailed;
  if([string isEqualToString:DownloadNeeded]) return NYPLMyBooksStateDownloadNeeded;
  if([string isEqualToString:DownloadSuccessful]) return NYPLMyBooksStateDownloadSuccessful;
  if([string isEqualToString:Unregistered]) return NYPLMyBooksStateUnregistered;
  if([string isEqualToString:Used]) return NYPLMYBooksStateUsed;
  
  @throw NSInvalidArgumentException;
}

NSString *NYPLMyBooksStateToString(NYPLMyBooksState state)
{
  switch(state) {
    case NYPLMyBooksStateDownloading:
      return Downloading;
    case NYPLMyBooksStateDownloadFailed:
      return DownloadFailed;
    case NYPLMyBooksStateDownloadNeeded:
      return DownloadNeeded;
    case NYPLMyBooksStateDownloadSuccessful:
      return DownloadSuccessful;
    case NYPLMyBooksStateUnregistered:
      return Unregistered;
    case NYPLMYBooksStateUsed:
      return Used;
  }
}