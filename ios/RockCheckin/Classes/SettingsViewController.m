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
#import "SettingsHelper.h"
#import "ZebraPrint.h"

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
@property (weak, nonatomic) IBOutlet UIButton *printTestLabel;

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
    NSString *printer = [SettingsHelper objectForKey:@"printer_override"];
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
    // switched to the Settings app and made changes, or pushed an updated
    // config from the MDM server.
    //
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(defaultsChangedNotification:)
                                               name:NSUserDefaultsDidChangeNotification
                                             object:nil];

    [self setInitialValues];

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
    self.checkinAddress.text = [SettingsHelper objectForKey:@"checkin_address"];
    self.enableLabelCaching.on = [SettingsHelper boolForKey:@"enable_caching"];
    self.cacheDuration.text = [SettingsHelper objectForKey:@"cache_duration"];
    self.enableLabelCutting.on = [SettingsHelper boolForKey:@"enable_label_cutting"];
    self.cameraPosition.selectedSegmentIndex = [[SettingsHelper stringForKey:@"camera_position"] isEqualToString:@"front"] ? 0 : 1;
    self.cameraExposure.value = [SettingsHelper floatForKey:@"camera_exposure"];
    self.uiBackgroundColor.text = [SettingsHelper objectForKey:@"ui_background_color"];
    self.uiForegroundColor.text = [SettingsHelper objectForKey:@"ui_foreground_color"];
    self.printerOverride.text = [SettingsHelper objectForKey:@"printer_override"];
    self.printerTimeout.text = [SettingsHelper objectForKey:@"printer_timeout"];
    self.bluetoothPrinting.on = [SettingsHelper boolForKey:@"bluetooth_printing"];
    
    self.bluetoothPrinter.hidden = !self.bluetoothPrinting.on;
    self.printTestLabel.enabled = self.printerOverride.text != nil && self.printerOverride.text.length > 0;
    
    //
    // Disable any MDM forced settings so the user can't change them.
    //
    if([SettingsHelper objectIsForcedForKey:@"checkin_address"]) {
        self.checkinAddress.enabled = NO;
        self.checkinAddress.alpha = 0.4;
    }
    else {
        self.checkinAddress.enabled = YES;
        self.checkinAddress.alpha = 1.0;
    }
    if([SettingsHelper objectIsForcedForKey:@"enable_caching"]) {
        self.enableLabelCaching.enabled = NO;
        self.enableLabelCaching.alpha = 0.4;
    }
    else {
        self.enableLabelCaching.enabled = YES;
        self.enableLabelCaching.alpha = 1.0;
    }
    if([SettingsHelper objectIsForcedForKey:@"cache_duration"]) {
        self.cacheDuration.enabled = NO;
        self.cacheDuration.alpha = 0.4;
    }
    else {
        self.cacheDuration.enabled = YES;
        self.cacheDuration.alpha = 1.0;
    }
    if([SettingsHelper objectIsForcedForKey:@"enable_label_cutting"]) {
        self.enableLabelCutting.enabled = NO;
        self.enableLabelCutting.alpha = 0.4;
    }
    else {
        self.enableLabelCutting.enabled = YES;
        self.enableLabelCutting.alpha = 1.0;
    }
    if([SettingsHelper objectIsForcedForKey:@"camera_position"]) {
        self.cameraPosition.enabled = NO;
        self.cameraPosition.alpha = 0.4;
    }
    else {
        self.cameraPosition.enabled = YES;
        self.cameraPosition.alpha = 1.0;
    }
    if([SettingsHelper objectIsForcedForKey:@"camera_exposure"]) {
        self.cameraExposure.enabled = NO;
        self.cameraExposure.alpha = 0.4;
    }
    else {
        self.cameraExposure.enabled = YES;
        self.cameraExposure.alpha = 1.0;
    }
    if([SettingsHelper objectIsForcedForKey:@"ui_background_color"]) {
        self.uiBackgroundColor.enabled = NO;
        self.uiBackgroundColor.alpha = 0.4;
    }
    else {
        self.uiBackgroundColor.enabled = YES;
        self.uiBackgroundColor.alpha = 1.0;
    }
    if([SettingsHelper objectIsForcedForKey:@"ui_foreground_color"]) {
        self.uiForegroundColor.enabled = NO;
        self.uiForegroundColor.alpha = 0.4;
    }
    else {
        self.uiForegroundColor.enabled = YES;
        self.uiForegroundColor.alpha = 1.0;
    }
    if([SettingsHelper objectIsForcedForKey:@"printer_override"]) {
        self.printerOverride.enabled = NO;
        self.printerOverride.alpha = 0.4;
    }
    else {
        self.printerOverride.enabled = YES;
        self.printerOverride.alpha = 1.0;
    }
    if([SettingsHelper objectIsForcedForKey:@"printer_timeout"]) {
        self.printerTimeout.enabled = NO;
        self.printerTimeout.alpha = 0.4;
    }
    else {
        self.printerTimeout.enabled = YES;
        self.printerTimeout.alpha = 1.0;
    }
    if([SettingsHelper objectIsForcedForKey:@"bluetooth_printing"]) {
        self.bluetoothPrinting.enabled = NO;
        self.bluetoothPrinting.alpha = 0.4;
    }
    else {
        self.bluetoothPrinting.enabled = YES;
        self.bluetoothPrinting.alpha = 1.0;
    }

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
        self.printTestLabel.enabled = self.printerOverride.text != nil && self.printerOverride.text.length > 0;
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


/**
 User tapped the Print Test Label button. Generate a simple test label to send to the
 printer so they can verify that the printer connection works.
 */
- (IBAction)btnPrintTestLabel:(id)sender
{
    [self.view endEditing:YES];

    NSString *testLabel = @"^XA\
\
^CI28\
^CF0,60\
^FO20,20^FDTest Label^FS\
^CF0,30\
^FO20,95^FDFrom: #DEVICE#^FS\
\
^FO20,150^GFA,1300,1300,13,P01IF8,O03KFC,N01MF8,N0OF,M07OFE,M0QF,L03QFC,L0SF,K03SFC,K07JFE3MFE,K0KF80NF,J03JFE003MFC,J07JFE003MFE,J0KFC001NF,I01KF8I0NF8,I03KFJ07MFC,I07JFEJ03MFE,I0KFCJ01NF,001KF8K0NF8,:003KFL07MFC,007JFEL03MFE,00KFCL01NF,00KF8M0NF,01KFN07MF8,01JFEN03MF8,03JFEN03MFC,03JFCJ08I01MFC,07JF8I01CJ0MFE,0KFJ03EJ07MF,0JFEJ07FJ03MF,0JFCJ0FF8I01MF,1JF8J0FF8J0MF8,1JF8I01FFCJ0MF8,1JFJ03FFEJ07LF8,3IFEJ07IFJ03LFC,3IFCJ0JF8I01LFC,3IF8I01JFCJ0LFC,7IFJ01JFEJ07KFE,7IFJ03JFEJ03KFE,7FFEJ07KFJ03KFE,7FFCJ0LF8I01KFE,7FF8I01LFCJ0KFE,IFJ03LFEJ07KF,FFEJ07MFJ03KF,FFCJ07MF8I01KF,FFCJ0NF8I01KF,PFEO0KF,PFCO07JF,PF8O03JF,PFP01JF,::OFEP01JF,PFP01JF,::7OF8O03IFE,7OF8O07IFE,7OFCO0JFE,7OFEN07JFE,7PFJ03NFE,3PF8I01NFC,3PFCJ0NFC,3PFEJ07MFC,1PFEJ03MF8,1QFJ03MF8,1QF8I01MF8,0QFCJ0MF,0QFEJ07LF,0RFJ03LF,07QFJ01KFE,03QF8I01KFC,03QFCJ0KFC,01QFEJ07JF8,01RFJ03JF8,00RF8I01JF,00RFCJ0JF,007QFCJ07FFE,003QFEJ07FFC,001RFJ03FF8,001RF8I01FF8,I0RFCJ0FF,I07QFEJ07E,I03RFJ07C,I01WF8,J0WF,J07UFE,J03UFC,K0UF,K07SFE,K03SFC,L0SF,L03QFC,M0QF,M07OFE,N0OF,N01MF8,O03KFC,P01IF8,^FS\
\
    ^MMC^XZ";
    
    testLabel = [testLabel stringByReplacingOccurrencesOfString:@"#DEVICE#" withString:UIDevice.currentDevice.name];
    
    if (![SettingsHelper boolForKey:@"enable_label_cutting"])
    {
        testLabel = [testLabel stringByReplacingOccurrencesOfString:@"^MMC" withString:@""];
    }
    
    ZebraPrint *printer = [ZebraPrint new];
    NSString *printerAddress = [SettingsHelper stringForKey:@"printer_override"];
    NSString *errorMessage = nil;
    
    BOOL success = [printer printLabelContent:testLabel toPrinter:printerAddress error:&errorMessage];

    //
    // Display an alert telling the user if it worked or not.
    //
    UIAlertController *alert = nil;
    if (success) {
        alert = [UIAlertController alertControllerWithTitle:@"Label Printed" message:@"The test label was printed." preferredStyle:UIAlertControllerStyleAlert];
    }
    else {
        alert = [UIAlertController alertControllerWithTitle:@"Print Failed" message:errorMessage preferredStyle:UIAlertControllerStyleAlert];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
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
    if (![SettingsHelper objectIsForcedForKey:@"printer_override"]) {
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
