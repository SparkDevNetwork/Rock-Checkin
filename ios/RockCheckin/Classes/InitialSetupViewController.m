//
//  InitialSetupViewController.m
//  RockCheckin
//
//  Created by Daniel Hazelbaker on 2/1/20.
//

#import "InitialSetupViewController.h"
#import "MainViewController.h"
#import "SettingsHelper.h"

@interface InitialSetupViewController () <MainReadyDelegate>

@property (weak, nonatomic) IBOutlet UIView *configView;
@property (weak, nonatomic) IBOutlet UIView *loadingView;
@property (weak, nonatomic) IBOutlet UIView *loadErrorView;

@property (weak, nonatomic) IBOutlet UITextField *urlField;
@property (weak, nonatomic) IBOutlet UILabel *alertJustInCase;
@property (weak, nonatomic) IBOutlet UIButton *saveButton;

@property (weak, nonatomic) IBOutlet UILabel *loadingFromUrl;
@property (weak, nonatomic) IBOutlet UIView *loadingRect1;
@property (weak, nonatomic) IBOutlet UIView *loadingRect2;
@property (weak, nonatomic) IBOutlet UIView *loadingRect3;
@property (weak, nonatomic) IBOutlet UIView *loadingRect4;
@property (weak, nonatomic) IBOutlet UIView *loadingRect5;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *loadingRect1Height;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *loadingRect2Height;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *loadingRect3Height;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *loadingRect4Height;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *loadingRect5Height;

@property (weak, nonatomic) IBOutlet UILabel *loadErrorUrl;
@property (weak, nonatomic) IBOutlet UIButton *loadErrorRetry;

@property (strong, nonatomic) MainViewController *mainViewController;
@property (strong, nonatomic) NSTimer *loadingTimeoutTimer;

@property (assign, nonatomic) BOOL isFirstDisplay;
@end

@implementation InitialSetupViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    __auto_type alertText = [[NSMutableAttributedString alloc] initWithString:@"Just In Case. You can change this address later by using your device's Settings application."];
    [alertText addAttribute:NSFontAttributeName
                      value:[UIFont fontWithName:@"OpenSans-Semibold" size:self.alertJustInCase.font.pointSize]
                      range:NSMakeRange(0, 13)];
    self.alertJustInCase.attributedText = alertText;

    self.isFirstDisplay = YES;
}


- (void)viewWillAppear:(BOOL)animated
{
    if (self.isFirstDisplay) {
        self.isFirstDisplay = NO;

        NSString *url = [SettingsHelper stringForKey:@"checkin_address"];
        if (url != nil && url.length > 0) {
            [self showLoadingView];
        }
        else {
            [self showConfigView];
        }
    }
}


/**
 Indicate to the system that we want the status bar to be hidden.
 */
- (BOOL)prefersStatusBarHidden
{
    return YES;
}


/**
 User has tapped on the Save Changes button.
 */
- (IBAction)btnSaveChanges:(id)sender
{
    if (self.urlField.text.length == 0) {
        return;
    }
    
    [NSUserDefaults.standardUserDefaults setObject:self.urlField.text forKey:@"checkin_address"];

    [self showLoadingView];
}


/**
 User wants to retry the load operation.
 */
- (IBAction)btnRetry:(id)sender
{
    [self showLoadingView];
}


- (void)showConfigView
{
    NSString *url = [SettingsHelper stringForKey:@"checkin_address"];
    self.urlField.text = url;
    
    self.loadingView.hidden = YES;
    self.loadErrorView.hidden = YES;
    self.configView.hidden = NO;
}


- (void)showLoadingView
{
    NSString *url = [SettingsHelper stringForKey:@"checkin_address"];
    __auto_type text = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"Loading check-in from\n%@", url]];
    [text addAttribute:NSFontAttributeName
                 value:[UIFont fontWithName:@"OpenSans-Semibold" size:self.loadingFromUrl.font.pointSize]
                 range:NSMakeRange(0, 21)];
    self.loadingFromUrl.attributedText = text;

    [self.configView endEditing:YES];
    self.configView.hidden = YES;
    self.loadErrorView.hidden = YES;
    self.loadingView.hidden = NO;
    
    [self startLoadingAnimation];
    
    self.mainViewController = [MainViewController new];
    self.mainViewController.readyDelegate = self;
    [self.mainViewController reloadCheckinAddress];
    
    self.loadingTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:10
                                                               repeats:NO
                                                                 block:^(NSTimer * _Nonnull timer) {
        self.mainViewController.readyDelegate = nil;
        self.mainViewController = nil;
        self.loadingTimeoutTimer = nil;
        [self showLoadingError];
    }];
}


/**
 Shows an error message about a load error.
 */
- (void)showLoadingError
{
    NSString *url = [SettingsHelper stringForKey:@"checkin_address"];
    __auto_type text = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"Could not load check-in from\n%@", url]];
    [text addAttribute:NSFontAttributeName
                 value:[UIFont fontWithName:@"OpenSans-Semibold" size:self.loadErrorUrl.font.pointSize]
                 range:NSMakeRange(0, 28)];
    self.loadErrorUrl.attributedText = text;

    text = [[NSMutableAttributedString alloc] initWithString:@"\uf021 Try Again"];
    [text addAttribute:NSFontAttributeName
                 value:[UIFont fontWithName:@"FontAwesome" size:self.loadErrorUrl.font.pointSize]
                 range:NSMakeRange(0, 1)];
    [text addAttribute:NSForegroundColorAttributeName
                 value:UIColor.whiteColor
                 range:NSMakeRange(0, text.length)];
    [self.loadErrorRetry setAttributedTitle:text
                                   forState:UIControlStateNormal];

    self.loadErrorView.hidden = NO;
    self.loadingView.hidden = YES;
}

/**
 Starts the loading view animating.
 */
- (void)startLoadingAnimation
{
    [UIView animateKeyframesWithDuration:1.6
                                   delay:0
                                 options:UIViewKeyframeAnimationOptionRepeat
                              animations:^{
        //
        // Rect 1
        //
        [UIView addKeyframeWithRelativeStartTime:0.2
                                relativeDuration:0.2
                                      animations:^{
            self.loadingRect1Height.constant = 64;
            [self.loadingView layoutIfNeeded];
        }];
        [UIView addKeyframeWithRelativeStartTime:0.4
                                relativeDuration:0.2
                                      animations:^{
            self.loadingRect1Height.constant = 32;
            [self.loadingView layoutIfNeeded];
        }];

        //
        // Rect 2
        //
        [UIView addKeyframeWithRelativeStartTime:0.3
                                relativeDuration:0.2
                                      animations:^{
            self.loadingRect2Height.constant = 64;
            [self.loadingView layoutIfNeeded];
        }];
        [UIView addKeyframeWithRelativeStartTime:0.5
                                relativeDuration:0.2
                                      animations:^{
            self.loadingRect2Height.constant = 32;
            [self.loadingView layoutIfNeeded];
        }];
        
        //
        // Rect 3
        //
        [UIView addKeyframeWithRelativeStartTime:0.4
                                relativeDuration:0.2
                                      animations:^{
            self.loadingRect3Height.constant = 64;
            [self.loadingView layoutIfNeeded];
        }];
        [UIView addKeyframeWithRelativeStartTime:0.6
                                relativeDuration:0.2
                                      animations:^{
            self.loadingRect3Height.constant = 32;
            [self.loadingView layoutIfNeeded];
        }];
        
        //
        // Rect 4
        //
        [UIView addKeyframeWithRelativeStartTime:0.5
                                relativeDuration:0.2
                                      animations:^{
            self.loadingRect4Height.constant = 64;
            [self.loadingView layoutIfNeeded];
        }];
        [UIView addKeyframeWithRelativeStartTime:0.7
                                relativeDuration:0.2
                                      animations:^{
            self.loadingRect4Height.constant = 32;
            [self.loadingView layoutIfNeeded];
        }];
        
        //
        // Rect 5
        //
        [UIView addKeyframeWithRelativeStartTime:0.6
                                relativeDuration:0.2
                                      animations:^{
            self.loadingRect5Height.constant = 64;
            [self.loadingView layoutIfNeeded];
        }];
        [UIView addKeyframeWithRelativeStartTime:0.8
                                relativeDuration:0.2
                                      animations:^{
            self.loadingRect5Height.constant = 32;
            [self.loadingView layoutIfNeeded];
        }];
    } completion:^(BOOL finished) {
        ;
    }];
}


/**
 Stop the loading spinner animation.
 */
- (void)stopLoadingAnimation
{
    [self.loadingRect1.layer removeAllAnimations];
    [self.loadingRect2.layer removeAllAnimations];
    [self.loadingRect3.layer removeAllAnimations];
    [self.loadingRect4.layer removeAllAnimations];
    [self.loadingRect5.layer removeAllAnimations];

    self.loadingRect1Height.constant = 32;
    self.loadingRect2Height.constant = 32;
    self.loadingRect3Height.constant = 32;
    self.loadingRect4Height.constant = 32;
    self.loadingRect5Height.constant = 32;

    [self.loadingView layoutIfNeeded];
}


#pragma MainReadyDelegate implementation

- (void)mainViewControllerIsReady
{
    [self.loadingTimeoutTimer invalidate];
    self.loadingTimeoutTimer = nil;

    [self.navigationController setViewControllers:@[self.mainViewController] animated:YES];
}

@end
