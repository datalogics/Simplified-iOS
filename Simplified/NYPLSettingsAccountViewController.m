#import "NYPLAccount.h"
#import "NYPLBookCoverRegistry.h"
#import "NYPLBookRegistry.h"
#import "NYPLConfiguration.h"
#import "NYPLLinearView.h"
#import "NYPLMyBooksDownloadCenter.h"
#import "NYPLRootTabBarController.h"
#import "UIView+NYPLViewAdditions.h"

#import "NYPLSettingsAccountViewController.h"

typedef NS_ENUM(NSInteger, CellKind) {
  CellKindBarcode,
  CellKindPIN,
  CellKindLogInSignOut
};

static CellKind CellKindFromIndexPath(NSIndexPath *const indexPath)
{
  switch(indexPath.section) {
    case 0:
      switch(indexPath.row) {
        case 0:
          return CellKindBarcode;
        case 1:
          return CellKindPIN;
        default:
          @throw NSInvalidArgumentException;
      }
    case 1:
      switch(indexPath.row) {
        case 0:
          return CellKindLogInSignOut;
        default:
          @throw NSInvalidArgumentException;
      }
    default:
      @throw NSInvalidArgumentException;
  }
}

@interface NYPLSettingsAccountViewController () <NSURLSessionDelegate>

@property (nonatomic) UITextField *barcodeTextField;
@property (nonatomic, copy) void (^completionHandler)();
@property (nonatomic) BOOL hiddenPIN;
@property (nonatomic) UITableViewCell *logInSignOutCell;
@property (nonatomic) UITextField *PINTextField;
@property (nonatomic) NSURLSession *session;
@property (nonatomic) UIView *shieldView;

@end

@implementation NYPLSettingsAccountViewController

#pragma mark NSObject

- (instancetype)init
{
  self = [super initWithStyle:UITableViewStyleGrouped];
  if(!self) return nil;
  
  self.title = NSLocalizedString(@"LibraryCard", nil);
  
  [[NSNotificationCenter defaultCenter]
   addObserver:self
   selector:@selector(accountDidChange)
   name:NYPLAccountDidChangeNotification
   object:nil];
  
  [[NSNotificationCenter defaultCenter]
   addObserver:self
   selector:@selector(keyboardDidShow:)
   name:UIKeyboardWillShowNotification
   object:nil];
  
  NSURLSessionConfiguration *const configuration =
    [NSURLSessionConfiguration ephemeralSessionConfiguration];
  
  configuration.timeoutIntervalForResource = 10.0;
  
  self.session = [NSURLSession
                  sessionWithConfiguration:configuration
                  delegate:self
                  delegateQueue:[NSOperationQueue mainQueue]];
  
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark UIViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.view.backgroundColor = [NYPLConfiguration backgroundColor];
  
  self.barcodeTextField = [[UITextField alloc] initWithFrame:CGRectZero];
  self.barcodeTextField.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                            UIViewAutoresizingFlexibleHeight);
  self.barcodeTextField.font = [UIFont systemFontOfSize:17];
  self.barcodeTextField.placeholder = NSLocalizedString(@"Barcode", nil);
  self.barcodeTextField.keyboardType = UIKeyboardTypeNumberPad;
  [self.barcodeTextField
   addTarget:self
   action:@selector(textFieldsDidChange)
   forControlEvents:UIControlEventEditingChanged];
  
  self.PINTextField = [[UITextField alloc] initWithFrame:CGRectZero];
  self.PINTextField.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                        UIViewAutoresizingFlexibleHeight);
  self.PINTextField.font = [UIFont systemFontOfSize:17];
  self.PINTextField.placeholder = NSLocalizedString(@"PIN", nil);
  self.PINTextField.keyboardType = UIKeyboardTypeNumberPad;
  [self.PINTextField
   addTarget:self
   action:@selector(textFieldsDidChange)
   forControlEvents:UIControlEventEditingChanged];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  
  self.hiddenPIN = YES;
  
  [self accountDidChange];
  
  [self.tableView reloadData];
}

#pragma mark UITableViewDelegate

- (void)tableView:(__attribute__((unused)) UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *const)indexPath
{
  switch(CellKindFromIndexPath(indexPath)) {
    case CellKindBarcode:
      [self.barcodeTextField becomeFirstResponder];
      return;
    case CellKindPIN:
      [self.PINTextField becomeFirstResponder];
      return;
    case CellKindLogInSignOut:
      [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
      if([[NYPLAccount sharedAccount] hasBarcodeAndPIN]) {
        UIAlertController *const alertController =
          (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad
           ? [UIAlertController
              alertControllerWithTitle:NSLocalizedString(@"SignOut", nil)
              message:NSLocalizedString(@"SettingsAccountViewControllerLogoutMessage", nil)
              preferredStyle:UIAlertControllerStyleAlert]
           : [UIAlertController
              alertControllerWithTitle:
                NSLocalizedString(@"SettingsAccountViewControllerLogoutMessage", nil)
              message:nil
              preferredStyle:UIAlertControllerStyleActionSheet]);
        [alertController addAction:[UIAlertAction
                                    actionWithTitle:NSLocalizedString(@"SignOut", nil)
                                    style:UIAlertActionStyleDestructive
                                    handler:^(__attribute__((unused)) UIAlertAction *action) {
                                      [[NYPLMyBooksDownloadCenter sharedDownloadCenter] reset];
                                      [[NYPLBookRegistry sharedRegistry] reset];
                                      [[NYPLAccount sharedAccount] removeBarcodeAndPIN];
                                      [self.tableView reloadData];
                                    }]];
        [alertController addAction:[UIAlertAction
                                    actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                    style:UIAlertActionStyleCancel
                                    handler:nil]];
        [self presentViewController:alertController animated:YES completion:nil];
      } else {
        [self logIn];
      }
  }
}

#pragma mark UITableViewDataSource

- (UITableViewCell *)tableView:(__attribute__((unused)) UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *const)indexPath
{
  // This is the amount of horizontal padding Apple uses around the titles in cells by default.
  CGFloat const padding = 16;
  
  switch(CellKindFromIndexPath(indexPath)) {
    case CellKindBarcode: {
      UITableViewCell *const cell = [[UITableViewCell alloc]
                                     initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:nil];
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
      {
        CGRect frame = cell.contentView.bounds;
        frame.origin.x += padding;
        frame.size.width -= padding * 2;
        self.barcodeTextField.frame = frame;
        [cell.contentView addSubview:self.barcodeTextField];
      }
      return cell;
    }
    case CellKindPIN: {
      UITableViewCell *const cell = [[UITableViewCell alloc]
                                     initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:nil];
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
      {
        CGRect frame = cell.contentView.bounds;
        frame.origin.x += padding;
        frame.size.width -= padding * 2;
        self.PINTextField.frame = frame;
        [cell.contentView addSubview:self.PINTextField];
      }
      return cell;
    }
    case CellKindLogInSignOut: {
      if(!self.logInSignOutCell) {
        self.logInSignOutCell = [[UITableViewCell alloc]
                                initWithStyle:UITableViewCellStyleDefault
                                reuseIdentifier:nil];
        self.logInSignOutCell.textLabel.font = [UIFont systemFontOfSize:17];
      }
      [self updateLoginLogoutCellAppearance];
      return self.logInSignOutCell;
    }
  }
}

- (NSInteger)numberOfSectionsInTableView:(__attribute__((unused)) UITableView *)tableView
{
  return 2;
}

- (NSInteger)tableView:(__attribute__((unused)) UITableView *)tableView
 numberOfRowsInSection:(NSInteger const)section
{
  switch(section) {
    case 0:
      return 2;
    case 1:
      return 1;
    default:
      @throw NSInternalInconsistencyException;
  }
}

#pragma mark NSURLSessionDelegate

- (void)URLSession:(__attribute__((unused)) NSURLSession *)session
              task:(__attribute__((unused)) NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *const)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition,
                             NSURLCredential *credential))completionHandler
{
  if(challenge.previousFailureCount) {
    completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
  } else {
    completionHandler(NSURLSessionAuthChallengeUseCredential,
                      [NSURLCredential
                       credentialWithUser:self.barcodeTextField.text
                       password:self.PINTextField.text
                       persistence:NSURLCredentialPersistenceNone]);
  }
}

#pragma mark -

- (void)didSelectReveal
{
  self.hiddenPIN = NO;
  [self.tableView reloadData];
}

- (void)accountDidChange
{
  if([NYPLAccount sharedAccount].hasBarcodeAndPIN) {
    self.barcodeTextField.text = [NYPLAccount sharedAccount].barcode;
    self.barcodeTextField.enabled = NO;
    self.barcodeTextField.textColor = [UIColor grayColor];
    self.PINTextField.text = [NYPLAccount sharedAccount].PIN;
    self.PINTextField.enabled = NO;
    self.PINTextField.textColor = [UIColor grayColor];
  } else {
    self.barcodeTextField.text = nil;
    self.barcodeTextField.enabled = YES;
    self.barcodeTextField.textColor = [UIColor blackColor];
    self.PINTextField.text = nil;
    self.PINTextField.enabled = YES;
    self.PINTextField.textColor = [UIColor blackColor];
  }
  
  [self updateLoginLogoutCellAppearance];
}

- (void)updateLoginLogoutCellAppearance
{
  if([[NYPLAccount sharedAccount] hasBarcodeAndPIN]) {
    self.logInSignOutCell.textLabel.text = NSLocalizedString(@"SignOut", nil);
    self.logInSignOutCell.textLabel.textAlignment = NSTextAlignmentCenter;
    self.logInSignOutCell.textLabel.textColor = [UIColor redColor];
    self.logInSignOutCell.userInteractionEnabled = YES;
  } else {
    self.logInSignOutCell.textLabel.text = NSLocalizedString(@"LogIn", nil);
    self.logInSignOutCell.textLabel.textAlignment = NSTextAlignmentNatural;
    BOOL const canLogIn =
      ([self.barcodeTextField.text
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length &&
       [self.PINTextField.text
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length);
    if(canLogIn) {
      self.logInSignOutCell.userInteractionEnabled = YES;
      self.logInSignOutCell.textLabel.textColor = [NYPLConfiguration mainColor];
    } else {
      self.logInSignOutCell.userInteractionEnabled = NO;
      self.logInSignOutCell.textLabel.textColor = [UIColor lightGrayColor];
    }
  }
}

- (void)logIn
{
  assert(self.barcodeTextField.text.length > 0);
  assert(self.PINTextField.text.length > 0);
  
  [self.barcodeTextField resignFirstResponder];
  [self.PINTextField resignFirstResponder];

  {
    UIActivityIndicatorView *const activityIndicatorView =
      [[UIActivityIndicatorView alloc]
       initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    
    [activityIndicatorView startAnimating];
    
    UILabel *const titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    titleLabel.text = NSLocalizedString(@"Verifying", nil);
    titleLabel.font = [UIFont systemFontOfSize:17];
    [titleLabel sizeToFit];
    
    // This view is used to keep the title label centered as in Apple's Settings application.
    UIView *const rightPaddingView = [[UIView alloc] initWithFrame:activityIndicatorView.bounds];
    
    NYPLLinearView *const linearView = [[NYPLLinearView alloc] init];
    linearView.contentVerticalAlignment = NYPLLinearViewContentVerticalAlignmentMiddle;
    linearView.padding = 5.0;
    [linearView addSubview:activityIndicatorView];
    [linearView addSubview:titleLabel];
    [linearView addSubview:rightPaddingView];
    [linearView sizeToFit];
    
    self.navigationItem.titleView = linearView;
  }
  
  [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
  
  [self validateCredentials];
}

- (void)validateCredentials
{
  NSMutableURLRequest *const request =
    [NSMutableURLRequest requestWithURL:[NYPLConfiguration loanURL]];
  
  request.HTTPMethod = @"HEAD";
  
  NSURLSessionDataTask *const task =
    [self.session
     dataTaskWithRequest:request
     completionHandler:^(__attribute__((unused)) NSData *data,
                         NSURLResponse *const response,
                         NSError *const error) {
     
       self.navigationItem.titleView = nil;
       [[UIApplication sharedApplication] endIgnoringInteractionEvents];
       
       if(error.code == NSURLErrorNotConnectedToInternet) {
         [[[UIAlertView alloc]
           initWithTitle:NSLocalizedString(@"SettingsAccountViewControllerLoginFailed", nil)
           message:NSLocalizedString(@"NotConnected", nil)
           delegate:nil
           cancelButtonTitle:nil
           otherButtonTitles:NSLocalizedString(@"OK", nil), nil]
          show];
         return;
       }
       
       if(error.code == NSURLErrorCancelled) {
         // We cancelled the request when asked to answer the server's challenge a second time
         // because we don't have valid credentials.
         [[[UIAlertView alloc]
           initWithTitle:NSLocalizedString(@"SettingsAccountViewControllerLoginFailed", nil)
           message:NSLocalizedString(@"SettingsAccountViewControllerInvalidCredentials", nil)
           delegate:nil
           cancelButtonTitle:nil
           otherButtonTitles:NSLocalizedString(@"OK", nil), nil]
          show];
         self.PINTextField.text = @"";
         [self textFieldsDidChange];
         [self.PINTextField becomeFirstResponder];
         return;
       }
       
       if(error.code == NSURLErrorTimedOut) {
         [[[UIAlertView alloc]
           initWithTitle:NSLocalizedString(@"SettingsAccountViewControllerLoginFailed", nil)
           message:NSLocalizedString(@"TimedOut", nil)
           delegate:nil
           cancelButtonTitle:nil
           otherButtonTitles:NSLocalizedString(@"OK", nil), nil]
          show];
         return;
       }
       
       // This cast is always valid according to Apple's documentation for NSHTTPURLResponse.
       NSInteger statusCode = ((NSHTTPURLResponse *) response).statusCode;
       
       if(statusCode == 200) {
         [[NYPLAccount sharedAccount] setBarcode:self.barcodeTextField.text
                                             PIN:self.PINTextField.text];
         [self dismissViewControllerAnimated:YES completion:^{}];
         void (^handler)() = self.completionHandler;
         self.completionHandler = nil;
         if(handler) handler();
         [[NYPLBookRegistry sharedRegistry] syncWithCompletionHandler:nil];
         return;
       }
       
       NYPLLOG(@"Encountered unexpected error after authenticating.");
       
       [[[UIAlertView alloc]
         initWithTitle:NSLocalizedString(@"SettingsAccountViewControllerLoginFailed", nil)
         message:NSLocalizedString(@"UnknownRequestError", nil)
         delegate:nil
         cancelButtonTitle:nil
         otherButtonTitles:NSLocalizedString(@"OK", nil), nil]
        show];
     }];
  
  [task resume];
}

- (void)textFieldsDidChange
{
  [self updateLoginLogoutCellAppearance];
}

- (void)keyboardDidShow:(NSNotification *const)notification
{
  // This nudges the scroll view up slightly so that the log in button is clearly visible even on
  // older 3:2 iPhone displays. I wish there were a more general way to do this, but this does at
  // least work very well.
  
  if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
    CGSize const keyboardSize =
      [[notification userInfo][UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    CGRect visibleRect = self.view.frame;
    visibleRect.size.height -= keyboardSize.height + self.tableView.contentInset.top;
    if(!CGRectContainsPoint(visibleRect,
                            CGPointMake(0, CGRectGetMaxY(self.logInSignOutCell.frame)))) {
      // We use an explicit animation block here because |setContentOffset:animated:| does not seem
      // to work at all.
      [UIView animateWithDuration:0.25 animations:^{
        [self.tableView setContentOffset:CGPointMake(0, -self.tableView.contentInset.top + 20)];
      }];
    }
  }
}

+ (void)
requestCredentialsUsingExistingBarcode:(BOOL const)useExistingBarcode
completionHandler:(void (^)())handler
{
  NYPLSettingsAccountViewController *const accountViewController = [[self alloc] init];
  
  accountViewController.completionHandler = handler;
  
  // Tell |accountViewController| to create its text fields so we can set their properties.
  [accountViewController view];
  
  if(useExistingBarcode) {
    NSString *const barcode = [NYPLAccount sharedAccount].barcode;
    if(!barcode) {
      @throw NSInvalidArgumentException;
    }
    accountViewController.barcodeTextField.text = barcode;
  } else {
    accountViewController.barcodeTextField.text = @"";
  }
  
  accountViewController.PINTextField.text = @"";
  
  UIBarButtonItem *const cancelBarButtonItem =
    [[UIBarButtonItem alloc]
     initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
     target:accountViewController
     action:@selector(didSelectCancel)];
  
  accountViewController.navigationItem.leftBarButtonItem = cancelBarButtonItem;
  
  UIViewController *const viewController = [[UINavigationController alloc]
                                            initWithRootViewController:accountViewController];
  viewController.modalPresentationStyle = UIModalPresentationFormSheet;
  
  [[NYPLRootTabBarController sharedController]
   safelyPresentViewController:viewController 
   animated:YES
   completion:nil];
}

- (void)didSelectCancel
{
  [self.navigationController.presentingViewController
   dismissViewControllerAnimated:YES
   completion:nil];
}

@end