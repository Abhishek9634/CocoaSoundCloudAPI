/*
 * Copyright 2010, 2011 nxtbgthng for SoundCloud Ltd.
 * 
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not
 * use this file except in compliance with the License. You may obtain a copy of
 * the License at
 * 
 * http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations under
 * the License.
 *
 * For more information and documentation refer to
 * http://soundcloud.com/api
 * 
 */

#if TARGET_OS_IPHONE

#import "SCSoundCloudAPIAuthentication.h"
#import "SCSoundCloudAPIConfiguration.h"

#import "SCLoginViewController.h"
#import "SCSoundCloud.h"
#import "SCSoundCloud+Private.h"
#import "SCConstants.h"
#import "SCBundle.h"


NSString * const SCLoginViewControllerCancelNotification = @"SCLoginViewControllerCancelNotification";

@interface SCLoginTitleBar: UIView {
}
@end


#pragma mark -

@implementation SCLoginViewController


#pragma mark Lifecycle

- (id)initWithURL:(NSURL *)anURL;
{
    return [self initWithURL:anURL authentication:nil];
}

- (id)initWithURL:(NSURL *)anURL authentication:(SCSoundCloudAPIAuthentication *)anAuthentication;
{
//    if (!anURL) return nil;
    
    self = [super init];
    if (self) {
        
		showReloadButton = NO;
        
        if ([self respondsToSelector:@selector(setModalPresentationStyle:)]){
            [self setModalPresentationStyle:UIModalPresentationFormSheet];
        }
                
        authentication = [anAuthentication retain];
        URL = [anURL retain];
        resourceBundle = [[NSBundle alloc] initWithPath:[[NSBundle mainBundle] pathForResource:@"SoundCloud" ofType:@"bundle"]];
        NSAssert(resourceBundle, @"Please move the SoundCloud.bundle into the Resource Directory of your Application!");
        self.title = SCLocalizedString(@"login_title", @"SoundCloud");
        self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:SCLocalizedString(@"login_close", @"Close")
                                                                                  style:UIBarButtonItemStyleBordered
                                                                                 target:self
                                                                                 action:@selector(close)] autorelease];
    }
    return self;
}

- (void)dealloc;
{
	[titleBarButton release];
    [resourceBundle release];
    [titleBarView release];
    [authentication release];
    [activityIndicator release];
    [URL release];
    [webView release];
    [super dealloc];
}


#pragma mark Accessors

@synthesize showReloadButton;

- (void)setShowReloadButton:(BOOL)value;
{
	showReloadButton = value;
	[self updateInterface];
}


#pragma mark UIViewController

- (void)viewDidLoad;
{
    [super viewDidLoad];
    
    
    // Navigation Bar
    self.navigationController.navigationBarHidden = YES;
    
    // Toolbar
    self.navigationController.toolbar.barStyle = UIBarStyleBlack;
    self.navigationController.toolbarHidden = NO;
    
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithCapacity:1];
    
    [toolbarItems addObject:[[[UIBarButtonItem alloc] initWithTitle:SCLocalizedString(@"cancel", @"Cancel")
                                                              style:UIBarButtonItemStyleBordered
                                                             target:self
                                                             action:@selector(cancel)] autorelease]];
    
    [self setToolbarItems:toolbarItems];
    
    
    self.view.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
//    self.view.backgroundColor = [UIColor colorWithPatternImage:[SCBundle imageFromPNGWithName:@"darkTexturedBackgroundPattern"]];
    
    titleBarView = [[SCLoginTitleBar alloc] initWithFrame:CGRectMake(0.0, 0.0, 320.0, 28.0)];
    titleBarView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin);
    [self.view addSubview:titleBarView];
    
    CGRect logoRect;
    CGRect connectRect;
    CGRect closeRect;
    CGRectDivide(titleBarView.bounds, &logoRect, &connectRect, 40.0, CGRectMinXEdge);
    CGRectDivide(connectRect, &closeRect, &connectRect, connectRect.size.height, CGRectMaxXEdge);
    
    logoRect.origin.x += 6.0;
    logoRect.origin.y += 8.0;
    connectRect.origin.y += 9.0;
    
    UIImageView *cloudImageView = [[UIImageView alloc] initWithFrame:logoRect];
    UIImage *cloudImage = [UIImage imageWithContentsOfFile:[resourceBundle pathForResource:@"cloud" ofType:@"png"]];
    cloudImageView.autoresizingMask = (UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin);
    cloudImageView.image = cloudImage;
    [cloudImageView sizeToFit];
    [titleBarView addSubview:cloudImageView];
    [cloudImageView release];
    
    UIImageView *titleImageView = [[UIImageView alloc] initWithFrame:connectRect];
    UIImage *titleImage = [UIImage imageWithContentsOfFile:[resourceBundle pathForResource:@"cwsc" ofType:@"png"]];
    titleImageView.autoresizingMask = (UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin);
    titleImageView.image = titleImage;
    [titleImageView sizeToFit];
    [titleBarView addSubview:titleImageView];
    [titleImageView release];
    
//	titleBarButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
//	titleBarButton.frame = closeRect;
//	titleBarButton.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin);
//	titleBarButton.showsTouchWhenHighlighted = YES;
//	[titleBarButton addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
//	UIImage *closeImage = [UIImage imageWithContentsOfFile:[resourceBundle pathForResource:@"close" ofType:@"png"]];
//	[titleBarButton setImage:closeImage forState:UIControlStateNormal];
//	titleBarButton.imageView.contentMode = UIViewContentModeCenter;
//	[titleBarView addSubview:titleBarButton];
	
	activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
	activityIndicator.center = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
	activityIndicator.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |UIViewAutoresizingFlexibleBottomMargin);
	activityIndicator.hidesWhenStopped = YES;
	[self.view addSubview:activityIndicator];
    
    webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
    webView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    webView.backgroundColor = nil;
    webView.opaque = NO;
    webView.delegate = self;

    if (URL) {
        NSURL *URLToOpen = [NSURL URLWithString:[[URL absoluteString] stringByAppendingString:@"&display_bar=false"]];
        [webView loadRequest:[NSURLRequest requestWithURL:URLToOpen]];
    }
    [self.view addSubview:webView];
    
    [self updateInterface];
}

- (void)viewDidUnload;
{
    [titleBarView release]; titleBarView = nil;
    [activityIndicator release]; activityIndicator = nil;
    [webView release]; webView = nil;
}

- (void)updateInterface;
{    
    CGRect contentRect;
    
    CGRect titleBarRect;
    CGRectDivide(self.view.bounds, &titleBarRect, &contentRect, 27.0, CGRectMinYEdge);
    titleBarView.frame = titleBarRect;
    webView.frame = contentRect;
    	
	[titleBarButton removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
	if (!showReloadButton) {
		[titleBarButton addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
		UIImage *closeImage = [UIImage imageWithContentsOfFile:[resourceBundle pathForResource:@"close" ofType:@"png"]];
		[titleBarButton setImage:closeImage forState:UIControlStateNormal];
	} else {
		[titleBarButton addTarget:self action:@selector(reload) forControlEvents:UIControlEventTouchUpInside];
		UIImage *reloadImage = [UIImage imageWithContentsOfFile:[resourceBundle pathForResource:@"reload" ofType:@"png"]];
		[titleBarButton setImage:reloadImage forState:UIControlStateNormal];
	}
    
}

#pragma mark WebView Delegate

- (void)webViewDidStartLoad:(UIWebView *)webView;
{
    [activityIndicator startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView;
{
    [activityIndicator stopAnimating];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType;
{
    // Use either the authentication delegate if present
    // or the shared sound cloud singleton (SCSoundCLoud).
    
    if (![request.URL isEqual:URL]) {
		BOOL hasBeenHandled = NO;
        
        NSURL *callbackURL = nil;
        if (authentication) {
            callbackURL = authentication.configuration.redirectURL;
        } else {
            callbackURL = [[SCSoundCloud configuration] objectForKey:kSCConfigurationRedirectURL];
        }
        
        if ([[request.URL absoluteString] hasPrefix:[callbackURL absoluteString]]) {
            
            if (authentication) {
                hasBeenHandled = [authentication handleRedirectURL:request.URL];
            } else {
                hasBeenHandled = [SCSoundCloud handleRedirectURL:request.URL];
            }
            
//            if (hasBeenHandled) {
//                [self close];
//            }
            return NO;
        }
	}
    
    NSURL *authURL = nil;
    if (authentication) {
        authURL = authentication.configuration.authURL;
    } else {
        authURL = [[SCSoundCloud configuration] objectForKey:kSCConfigurationAuthorizeURL];
    }
    
    if (![[request.URL absoluteString] hasPrefix:[authURL absoluteString]]) {
        [[UIApplication sharedApplication] openURL:request.URL];
        return NO;
    }
	
	return YES;
}

#pragma mark Private

- (IBAction)cancel;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SCLoginViewControllerCancelNotification object:self];
}

- (IBAction)close;
{
    if (authentication) {
        [authentication performSelector:@selector(dismissLoginViewController:) withObject:self];
    } else {
        [self.parentViewController dismissModalViewControllerAnimated:YES];
    }
}

- (IBAction)reload;
{
    [webView reload];
}

@end


#pragma mark -

@implementation SCLoginTitleBar

- (void)drawRect:(CGRect)rect;
{
    CGRect topLineRect;
    CGRect gradientRect;
    CGRect bottomLineRect;
    CGRectDivide(self.bounds, &topLineRect, &gradientRect, 0.0, CGRectMinYEdge);
    CGRectDivide(gradientRect, &bottomLineRect, &gradientRect, 1.0, CGRectMaxYEdge);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace,
                                                                 (CGFloat[]){1.0,0.40,0.0,1.0,  1.0,0.21,0.0,1.0},
                                                                 (CGFloat[]){0.0, 1.0},
                                                                 2);
    CGContextDrawLinearGradient(context, gradient, gradientRect.origin, CGPointMake(gradientRect.origin.x, CGRectGetMaxY(gradientRect)), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    
    CGContextSetFillColor(context, (CGFloat[]){0.0,0.0,0.0,1.0});
    CGContextFillRect(context, topLineRect);
    
    CGContextSetFillColor(context, (CGFloat[]){0.52,0.53,0.54,1.0});
    CGContextFillRect(context, bottomLineRect);
}

@end

#endif
