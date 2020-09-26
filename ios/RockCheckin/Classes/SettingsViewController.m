//
//  SettingsViewController.m
//  RockCheckin
//
//  Created by Daniel Hazelbaker on 9/25/18.
//

#import "SettingsViewController.h"
#import "MainViewController.h"
#import "UIColor+HexString.h"
#import <CoreBluetooth/CoreBluetooth.h>

@interface SettingsViewController () <UITableViewDataSource, UITableViewDelegate, CBCentralManagerDelegate>

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomLayoutSpacing;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UITextField *checkinAddress;
@property (weak, nonatomic) IBOutlet UISwitch *enableLabelCaching;
@property (weak, nonatomic) IBOutlet UITextField *cacheDuration;
@property (weak, nonatomic) IBOutlet UISwitch *enableLabelCutting;
@property (weak, nonatomic) IBOutlet UISegmentedControl *cameraPosition;
@property (weak, nonatomic) IBOutlet UISlider *cameraExposure;
@property (weak, nonatomic) IBOutlet UITextField *uiBackgroundColor;
@property (weak, nonatomic) IBOutlet UITextField *uiForegroundColor;
@property (weak, nonatomic) IBOutlet UISwitch *bluetoothPrinting;
@property (weak, nonatomic) IBOutlet UITextField *printerOverride;
@property (weak, nonatomic) IBOutlet UITextField *printerTimeout;
@property (weak, nonatomic) IBOutlet UITableView *bluetoothPrinter;

@property (strong, nonatomic) CBCentralManager  *centralManager;
@property (strong, nonatomic) NSMutableArray *discoveredPrinters;

@end

@implementation SettingsViewController

/**
 Initialize a new Settings view controller and load the data from the NIB

 @return A reference to this view controller
 */
- (id)init
{
    if ((self = [self initWithNibName:@"SettingsViewController" bundle:nil]) == nil) {
        return nil;
    }
    
    self.discoveredPrinters = [NSMutableArray new];
    
    return self;
}


/**
 The view is about to appear on screen, do any lazy load initialization

 @param animated YES if our appearance will be animated
 */
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    //
    // If a printer is specified then add that printer name to our discovered
    // devices so that the user-specified printer is always at the top of
    // the browser list.
    //
    NSString *printer = [NSUserDefaults.standardUserDefaults objectForKey:@"printer_override"];
    if (printer != nil && ![printer isEqualToString:@""]) {
        [self.discoveredPrinters addObject:printer];
        [self.bluetoothPrinter selectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
    }

    //
    // Register for any keyboard related notifications so that we can adjust the
    // view when the keyboard appears.
    //
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(keyboardWillShow:)
                                               name:UIKeyboardWillShowNotification
                                             object:self.view.window];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(keyboardWillHide:)
                                               name:UIKeyboardWillHideNotification
                                             object:self.view.window];

    //
    // Register for notifications about background status.
    //
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(appWillResignActiveNotification:)
                                               name:UIApplicationWillResignActiveNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(appWillEnterForegroundNotification:)
                                               name:UIApplicationWillEnterForegroundNotification
                                             object:nil];
    
    //
    // Monitor for any preference changes, this would indicate the user
    // switched to the Settings app and made changes.
    //
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(defaultsChangedNotification:)
                                               name:NSUserDefaultsDidChangeNotification
                                             object:nil];

    [self setInitialValues];

    //
    // Handle any MDM forced settings so the user can't change them.
    //
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSDictionary *serverConfig = [NSUserDefaults.standardUserDefaults dictionaryForKey:@"com.apple.configuration.managed"];
    if(serverConfig == nil) {
        serverConfig = @{};
    }
    if([serverConfig objectForKey:@"checkin_address"] || [defaults objectIsForcedForKey:@"checkin_address"]) {
        self.checkinAddress.enabled = NO;
        self.checkinAddress.alpha = 0.4;
    }
    if([serverConfig objectForKey:@"enable_caching"] || [defaults objectIsForcedForKey:@"enable_caching"]) {
        self.enableLabelCaching.enabled = NO;
        self.enableLabelCaching.alpha = 0.4;
    }
    if([serverConfig objectForKey:@"cache_duration"] || [defaults objectIsForcedForKey:@"cache_duration"]) {
        self.cacheDuration.enabled = NO;
        self.cacheDuration.alpha = 0.4;
    }
    if([serverConfig objectForKey:@"enable_label_cutting"] || [defaults objectIsForcedForKey:@"enable_label_cutting"]) {
        self.enableLabelCutting.enabled = NO;
        self.enableLabelCutting.alpha = 0.4;
    }
    if([serverConfig objectForKey:@"camera_position"] || [defaults objectIsForcedForKey:@"camera_position"]) {
        self.cameraPosition.enabled = NO;
        self.cameraPosition.alpha = 0.4;
    }
    if([serverConfig objectForKey:@"camera_exposure"] || [defaults objectIsForcedForKey:@"camera_exposure"]) {
        self.cameraExposure.enabled = NO;
        self.cameraExposure.alpha = 0.4;
    }
    if([serverConfig objectForKey:@"ui_background_color"] || [defaults objectIsForcedForKey:@"ui_background_color"]) {
        self.uiBackgroundColor.enabled = NO;
        self.uiBackgroundColor.alpha = 0.4;
    }
    if([serverConfig objectForKey:@"ui_foreground_color"] || [defaults objectIsForcedForKey:@"ui_foreground_color"]) {
        self.uiForegroundColor.enabled = NO;
        self.uiForegroundColor.alpha = 0.4;
    }
    if([serverConfig objectForKey:@"printer_override"] || [defaults objectIsForcedForKey:@"printer_override"]) {
        self.printerOverride.enabled = NO;
        self.printerOverride.alpha = 0.4;
    }
    if([serverConfig objectForKey:@"printer_timeout"] || [defaults objectIsForcedForKey:@"printer_timeout"]) {
        self.printerTimeout.enabled = NO;
        self.printerTimeout.alpha = 0.4;
    }
    if([serverConfig objectForKey:@"bluetooth_printing"] || [defaults objectIsForcedForKey:@"bluetooth_printing"]) {
        self.bluetoothPrinting.enabled = NO;
        self.bluetoothPrinting.alpha = 0.4;
    }

    if (self.bluetoothPrinting.on) {
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
    
    //
    // Set initial color scheme.
    //
    if (@available(iOS 12.0, *)) {
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            self.view.backgroundColor = [UIColor colorWithHexString:@"1a1a1a"];
        }
        else {
            self.view.backgroundColor = [UIColor colorWithHexString:@"#fafafa"];
        }
    }
}


/**
 The view is about to disappear, undo anything we did in viewWillAppear:

 @param animated YES if we are going to use an animation when we disappear
 */
- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if (self.centralManager != nil) {
        [self.centralManager stopScan];
    }
    
    [NSNotificationCenter.defaultCenter removeObserver:self];
}


/**
 The trait collection for our view is about to change. This contains things like if we are in Dark Mode or not.
 
 @param newCollection The new traits that will be applied.
 @param coordinator The animation coordinator for this change.
 */
- (void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    if (@available(iOS 12.0, *)) {
        [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
            if (newCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                self.view.backgroundColor = [UIColor colorWithHexString:@"1a1a1a"];
            }
            else {
                self.view.backgroundColor = [UIColor colorWithHexString:@"#fafafa"];
            }
        } completion:nil];
    }
}


/**
 Indicate that we don't want the status bar to be visible.

 @return YES
 */
- (BOOL)prefersStatusBarHidden
{
    return YES;
}


/**
 Set the initial values of the UI to reflect those stored in the preferences.
 */
- (void)setInitialValues
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    
    self.checkinAddress.text = [defaults objectForKey:@"checkin_address"];
    self.enableLabelCaching.on = [defaults boolForKey:@"enable_caching"];
    self.cacheDuration.text = [defaults objectForKey:@"cache_duration"];
    self.enableLabelCutting.on = [defaults boolForKey:@"enable_label_cutting"];
    self.cameraPosition.selectedSegmentIndex = [[defaults stringForKey:@"camera_position"] isEqualToString:@"front"] ? 0 : 1;
    self.cameraExposure.value = [defaults floatForKey:@"camera_exposure"];
    self.uiBackgroundColor.text = [defaults objectForKey:@"ui_background_color"];
    self.uiForegroundColor.text = [defaults objectForKey:@"ui_foreground_color"];
    self.printerOverride.text = [defaults objectForKey:@"printer_override"];
    self.printerTimeout.text = [defaults objectForKey:@"printer_timeout"];
    self.bluetoothPrinting.on = [defaults boolForKey:@"bluetooth_printing"];
    
    self.bluetoothPrinter.hidden = !self.bluetoothPrinting.on;
}


/**
 One of the preference toggle buttons has been flipped

 @param sender The UIView that had its state changed
 */
- (IBAction)toggleStateChanged:(id)sender
{
    if (sender == self.bluetoothPrinting) {
        self.bluetoothPrinter.hidden = !self.bluetoothPrinting.on;
        if (self.bluetoothPrinting.on && self.centralManager == nil) {
            self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        }
        [NSUserDefaults.standardUserDefaults setBool:self.bluetoothPrinting.on forKey:@"bluetooth_printing"];
    }
    else if (sender == self.enableLabelCaching) {
        [NSUserDefaults.standardUserDefaults setBool:self.enableLabelCaching.on forKey:@"enable_caching"];
    }
    else if (sender ==  self.enableLabelCutting) {
        [NSUserDefaults.standardUserDefaults setBool:self.enableLabelCutting.on forKey:@"enable_label_cutting"];
    }
}


/**
 One of the preference segmented controls has been changed.

 @param sender The UIView that had its state changed
*/
- (IBAction)segmentedControlChanged:(id)sender
{
    if (sender == self.cameraPosition) {
        NSString *value = self.cameraPosition.selectedSegmentIndex == 0 ? @"front" : @"back";
        [NSUserDefaults.standardUserDefaults setObject:value forKey:@"camera_position"];
    }
}


/**
 One of the preference slider controls has been changed.

 @param sender The UIView that had its value changed
*/
- (IBAction)sliderValueChanged:(id)sender
{
    if (sender == self.cameraExposure) {
        [NSUserDefaults.standardUserDefaults setFloat:self.cameraExposure.value forKey:@"camera_exposure"];
    }
}


/**
 One of the preference text fields has had it's value change

 @param sender The UIView that had its value changed
 */
- (IBAction)textFieldChanged:(id)sender
{
    if (sender == self.checkinAddress) {
        [NSUserDefaults.standardUserDefaults setObject:self.checkinAddress.text forKey:@"checkin_address"];
    }
    else if (sender == self.cacheDuration) {
        [NSUserDefaults.standardUserDefaults setObject:self.cacheDuration.text forKey:@"cache_duration"];
    }
    else if (sender == self.uiBackgroundColor) {
        [NSUserDefaults.standardUserDefaults setObject:self.uiBackgroundColor.text forKey:@"ui_background_color"];
    }
    else if (sender == self.uiForegroundColor) {
        [NSUserDefaults.standardUserDefaults setObject:self.uiForegroundColor.text forKey:@"ui_foreground_color"];
    }
    else if (sender == self.printerOverride) {
        [NSUserDefaults.standardUserDefaults setObject:self.printerOverride.text forKey:@"printer_override"];
    }
    else if (sender == self.printerTimeout) {
        [NSUserDefaults.standardUserDefaults setObject:self.printerTimeout.text forKey:@"printer_timeout"];
    }
}


/**
 User tapped the Close button, return to the check-in view

 @param sender The button that was tapped
 */
- (IBAction)btnClose:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}


/**
 User tapped the Reload button, return to the check-in view and reload check-in
 with the original URL

 @param sender The button that was tapped
 */
- (IBAction)btnReloadCheckin:(id)sender
{
    [self.view endEditing:YES];

    [(MainViewController *)self.navigationController.viewControllers.firstObject reloadCheckinAddress];
    [self.navigationController popToRootViewControllerAnimated:YES];
}



#pragma mark -- Notification methods

/**
 Application is about to go into the background, turn off Bluetooth

 @param notificiation The notification that describes this event
 */
- (void)appWillResignActiveNotification:(NSNotification *)notificiation
{
    if (self.centralManager != nil) {
        [self.centralManager stopScan];
    }
}


/**
 Application is returning to the foreground, turn on Bluetooth

 @param notificiation The notification that describes this event
 */
- (void)appWillEnterForegroundNotification:(NSNotification *)notificiation
{
    if (self.centralManager != nil && self.centralManager.state == CBManagerStatePoweredOn) {
        [self.centralManager scanForPeripheralsWithServices:nil options:nil];
    }
}


/**
 User defaults have changed, check update our on-screen values

 @param notification The notification that describes this event
 */
- (void)defaultsChangedNotification:(NSNotification *)notification
{
    [self setInitialValues];
}


#pragma mark -- Methods for dealing with keyboard.

/**
 Keyboard is about to become invisible

 @param notification The notification that describes this event
 */
- (void)keyboardWillHide:(NSNotification *)notification
{
    [self updateBottomLayoutConstraintWithNotification:notification];
}


/**
 Keyboard is about to become visible

 @param notification The notification that describes this event
 */
- (void)keyboardWillShow:(NSNotification *)notification
{
    [self updateBottomLayoutConstraintWithNotification:notification];
}


/**
 Update the bottom layout constraint to reflect the keyboard position so that
 the user can still scroll around and get to all the screen content

 @param notification The notification that describes this event
 */
- (void)updateBottomLayoutConstraintWithNotification:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    double animationDuration = ((NSNumber *)userInfo[UIKeyboardAnimationDurationUserInfoKey]).doubleValue;
    CGRect keyboardEndFrame = ((NSValue *)userInfo[UIKeyboardFrameEndUserInfoKey]).CGRectValue;
    CGRect convertedKeyboardEndFrame = [self.view convertRect:keyboardEndFrame fromView:self.view.window];
    unsigned int rawAnimationCurve = ((NSNumber *)userInfo[UIKeyboardAnimationCurveUserInfoKey]).unsignedIntValue << 16;
    [UIView animateWithDuration:animationDuration delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | rawAnimationCurve animations:^{
        self.bottomLayoutSpacing.constant = (CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(convertedKeyboardEndFrame));
        [self.scrollView layoutIfNeeded];
    } completion:nil];
}


#pragma mark -- UITableViewDelegate methods

/**
 User selected an bluetooth device in the table view

 @param tableView The table view that was tapped in
 @param indexPath The path to the item that was tapped
 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (![NSUserDefaults.standardUserDefaults objectIsForcedForKey:@"printer_override"]) {
        self.printerOverride.text = self.discoveredPrinters[indexPath.row];
        [self textFieldChanged:self.printerOverride];
    }
}

#pragma mark -- UITableViewDataSource methods

/**
 Get the number of rows in the table view

 @param tableView The table view that needs the row count
 @param section The section in a multi-section table view whose row count we need
 @return The number of rows that exist in the section
 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.discoveredPrinters.count;
}


/**
 Get the cell to be displayed for the item specified in the indexPath

 @param tableView The table view that needs the cell
 @param indexPath The path to the item to be displayed
 @return A table view cell object that will be used to display the object
 */
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"DeviceNameTableItem";
    NSString *title = [self.discoveredPrinters objectAtIndex:indexPath.item];
    
    if ([title rangeOfString:@"**"].location == 0) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];

        cell.textLabel.text = @"Error";
        cell.detailTextLabel.text = [title substringFromIndex:2];
        
        return cell;
    }
    else {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
            cell.selectedBackgroundView = [UIView new];
            cell.selectedBackgroundView.backgroundColor = [UIColor colorWithRed:(188 / 255.0f) green:(217 / 255.0f) blue:(234 / 255.0f) alpha:1];
        }

        cell.textLabel.text = [self.discoveredPrinters objectAtIndex:indexPath.item];
    
        return cell;
    }
}


#pragma mark -- CBCentralManagerDelegate methods

/**
 The BLE Central Manager has updated its state. If we are now powered on
 then begin scanning for peripherals.

 @param central The central manager whose power state changed
 */
- (void)centralManagerDidUpdateState:(nonnull CBCentralManager *)central
{
    if (central.state == CBManagerStatePoweredOn) {
        [self.centralManager scanForPeripheralsWithServices:nil options:nil];
    }
    else if (central.state == CBManagerStateUnsupported) {
        [self.discoveredPrinters removeAllObjects];
        [self.discoveredPrinters addObject:@"**Bluetooth Low Energy is not supported on this device"];
        [self.bluetoothPrinter reloadData];
        [self.bluetoothPrinter selectRowAtIndexPath:nil animated:NO scrollPosition:UITableViewScrollPositionTop];
        self.bluetoothPrinter.allowsSelection = NO;
        self.bluetoothPrinter.userInteractionEnabled = NO;
    }
}


/**
 A peripheral has been discovered. Check if it is the one we are interested in.

 @param central The central manager that discovered the peripheral
 @param peripheral The peripheral that was discovered
 @param advertisementData Any data advertised by the peripheral
 @param RSSI The RSSI value of the peripheral
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    if (peripheral.name.length) {
        //
        // Remove leading & trailing whitespace in peripheral.name
        //
        NSString *peripheralName = [peripheral.name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        if (![self.discoveredPrinters containsObject:peripheralName]) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.discoveredPrinters.count inSection:0];
            [self.discoveredPrinters addObject:peripheralName];
            [self.bluetoothPrinter insertRowsAtIndexPaths:@[indexPath]
                                         withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
}

@end
