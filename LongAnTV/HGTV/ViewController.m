//
//  ViewController.m
//  HGTV
//
//  Created by Truong Tan Trung on 5/12/15.
//  Copyright (c) 2015 hdisoft. All rights reserved.
//

#import "ViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import "AFNetworking/AFNetworking.h"
#import "MBProgressHUD.h"


#include <netdb.h>
#include <arpa/inet.h>
#import <QuartzCore/QuartzCore.h>

#define CHANEL_ID 54

@interface ViewController (){
    
    MPMoviePlayerViewController * playerController;
    NSString *urlString;
    NSArray *arrChanel;
    BOOL restartChanel;
    
     MBProgressHUD *HUD;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.imvIcon.layer.cornerRadius = 5;
    // Do any additional setup after loading the view, typically from a nib.
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        
        NSLog(@"Reachability changed: %@", AFStringFromNetworkReachabilityStatus(status));
        
        
        switch (status) {
                
            case AFNetworkReachabilityStatusReachableViaWWAN:
            case AFNetworkReachabilityStatusReachableViaWiFi:
                // -- Reachable -- //
                NSLog(@"Reachable");
                break;
            case AFNetworkReachabilityStatusNotReachable:
            default:
                // -- Not reachable -- //
                NSLog(@"Not Reachable");
                break;
        }
        
    }];
    [self requestUrl];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onNotify:)
                                                 name:MPMoviePlayerPlaybackStateDidChangeNotification
                                               object:nil];
    
//    [self showLoading];
}


-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)onNotify:(NSNotification *)nofity{
    NSNumber* reason = [[nofity userInfo] objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
    switch ([reason intValue]) {
        case MPMovieFinishReasonPlaybackEnded:
            NSLog(@"Playback Ended");
            break;
        case MPMovieFinishReasonPlaybackError:
            NSLog(@"Playback Error"); //// this include Bad URL
            restartChanel = YES;
            [self requestUrl];
            
            break;
        case MPMovieFinishReasonUserExited:
            NSLog(@"User Exited");
            break;
        default:
            break;
    }
}

- (IBAction)onTapPlay:(id)sender {
    if (![self hasAvailableNetwork]) {
        [self showAlert:@"Vui lòng kiểm tra lại đường truyền Internet"];
        return;
    }
    NSURL *url = [NSURL URLWithString: urlString];
    playerController = [[MPMoviePlayerViewController alloc] initWithContentURL:url];
    [self presentMoviePlayerViewControllerAnimated:playerController];
    NSLog(@"playvideo");
    
}

- (void) requestUrl{
    if (![self hasAvailableNetwork]) {
        [self showAlert:@"Vui lòng kiểm tra lại đường truyền Internet"];
        return;
    }

    [self showLoading];
    NSURL *url = [NSURL URLWithString:@"http://api.htvonline.com.vn/tv_channels"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData  timeoutInterval:10];
    
    [request setHTTPMethod:@"POST"];
    NSString *body = @"request={\"category_id\":\"-1\",\"startIndex\":\"0\",\"pageCount\":\"100\"}";
    
    [request setHTTPBody: [body dataUsingEncoding:NSUTF8StringEncoding]];
    
    AFHTTPRequestOperation *op = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    op.responseSerializer = [AFJSONResponseSerializer serializer];
    [op setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        [self hideLoading];
        
        NSLog(@"JSON responseObject: %@ ",responseObject);
        arrChanel = [responseObject objectForKey:@"data"];
        for(NSDictionary *row in arrChanel){
            NSInteger chanelId = [[row objectForKey:@"id"] integerValue];
            if(chanelId == CHANEL_ID){
                NSArray *linkPlay = [row objectForKey:@"link_play"];
                if(linkPlay.count >0){
                    NSDictionary *info = [linkPlay objectAtIndex:0];
                    urlString = [info objectForKey:@"mp3u8_link"];
                }
                break;
            }
        }
        if(restartChanel){
            [self onTapPlay:nil];
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self hideLoading];
        [self showAlert:@"Vui lòng kiểm tra lại đường truyền Internet"];
        NSLog(@"Error: %@", [error localizedDescription]);
        restartChanel = NO;
        
    }];
    [op start];}


-(BOOL)hasAvailableNetwork{
//    return [AFNetworkReachabilityManager sharedManager].reachable;
//    return YES;
    BOOL	ret;
    
    // Part 1 - Create Internet socket addr of zero
    struct sockaddr_in	zeroAddr;
    bzero(&zeroAddr, sizeof(zeroAddr));
    zeroAddr.sin_len = sizeof(zeroAddr);
    zeroAddr.sin_family = AF_INET;
    
    // Part 2 - Create target in format need by SCNetwork
    SCNetworkReachabilityRef	target = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *) &zeroAddr);
    
    // Part 3 - Get the flags
    SCNetworkReachabilityFlags	flags;
    
    @try {
        SCNetworkReachabilityGetFlags(target, &flags);	//	try catch....
    }
    @catch (NSException *exception) {
        NSLog(@"isNetworkAvailable: Caught %@: %@", [exception name], [exception reason]);
        ret = NO;
        return FALSE;
    }
    @finally {
        
    }
    
    // Part 4 - Create output
    NSString	*sNetworkReachable;
    if (flags & kSCNetworkFlagsReachable) {
        sNetworkReachable = @"YES";
        ret = YES;
    } else {
        sNetworkReachable = @"NO";
        ret = NO;
    }
    return ret;
    

}

-(void)showAlert:(NSString *)message{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Thông Báo"
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:@"Đóng"
                                          otherButtonTitles:nil];
    [alert show];
}

-(void)showLoading{
    HUD = [[MBProgressHUD alloc] initWithView:self.view];
    HUD.labelText = @"Đang xử lý.";
    [self.view addSubview:HUD];
    HUD.minSize = CGSizeMake(150.f, 150.f);
    [HUD show:YES];
}

-(void)hideLoading{
    
    [HUD show:NO];
    [HUD removeFromSuperview];
}

//
//- (BOOL)shouldAutorotate {
//    return YES;
//}
//
////- (NSUInteger)supportedInterfaceOrientations {
////    return UIInterfaceOrientationMaskPortrait;
////}
//// pre-iOS 6 support
//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
//    NSLog(@"rotate..");
//    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
//    return (toInterfaceOrientation == UIInterfaceOrientationPortrait);
//}

@end
