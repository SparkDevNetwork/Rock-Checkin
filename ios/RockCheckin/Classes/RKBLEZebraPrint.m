//
//  RKBLEZebraPrint.m
//  RockCheckin
//
//  Created by Daniel Hazelbaker on 9/24/18.
//

#import "RKBLEZebraPrint.h"
#import <CoreBluetooth/CoreBluetooth.h>

#define ZPRINTER_SERVICE_UUID                   @"38EB4A80-C570-11E3-9507-0002A5D5C51B"
#define WRITE_TO_ZPRINTER_CHARACTERISTIC_UUID   @"38EB4A82-C570-11E3-9507-0002A5D5C51B"
#define READ_FROM_ZPRINTER_CHARACTERISTIC_UUID  @"38EB4A81-C570-11E3-9507-0002A5D5C51B"

@interface RKBLEZebraPrint () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (strong, nonatomic) NSString          *printerName;
@property (strong, nonatomic) CBUUID            *zprinterUuid;
@property (strong, nonatomic) CBUUID            *writePrinterUuid;
@property (strong, nonatomic) CBCentralManager  *centralManager;
@property (strong, nonatomic) CBPeripheral      *printer;
@property (strong, nonatomic) CBCharacteristic  *writePrinterCharacteristic;

@end


@implementation RKBLEZebraPrint

//
// Initialize the bluetooth low energy zebra printing system.
//
- (id)init
{
    if ((self = [super init]) == nil) {
        return nil;
    }

    self.zprinterUuid = [CBUUID UUIDWithString:ZPRINTER_SERVICE_UUID];
    self.writePrinterUuid = [CBUUID UUIDWithString:WRITE_TO_ZPRINTER_CHARACTERISTIC_UUID];
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    
    return self;
}


//
// Set the name of the printer to be connected to. If printerName is nil then we
// turn off the bluetooth radio and save power.
//
- (void)setPrinterName:(NSString *)printerName
{
    _printerName = printerName;
    if (self.printer != nil) {
        [self.centralManager cancelPeripheralConnection:self.printer];
        self.printer = nil;
        self.writePrinterCharacteristic = nil;
    }
    
    if (self.printerName == nil) {
        [self.centralManager stopScan];
    }
    else {
        [self startScan];
    }
}


//
// Send the ZPL data to the printer in chunks.
//
- (void)sendZPLToPrinter:(NSString *)zpl
{
    const char *bytes = [zpl UTF8String];
    size_t length = [zpl length];
    NSUInteger maxLength = [self.printer maximumWriteValueLengthForType:CBCharacteristicWriteWithResponse];

    for (NSUInteger i = 0; i < length;) {
        NSUInteger len = MIN(length - i, maxLength);
        NSData *payload = [NSData dataWithBytes:bytes+i length:len];
        [self.printer writeValue:payload
               forCharacteristic:self.writePrinterCharacteristic
                            type:CBCharacteristicWriteWithResponse];
        i += len;
    }
}


//
// Prin the label data. Returns YES if the label as printed or NO if an error occurred.
//
- (BOOL)print:(NSString *)zpl
{
    if (self.writePrinterCharacteristic == nil) {
        return NO;
    }
    
    [self sendZPLToPrinter:zpl];
    
    return YES;
}


//
// Start scanning for the printer.
//
- (void)startScan
{
    if (self.centralManager.state == CBManagerStatePoweredOn && self.printerName != nil) {
        //
        // We can't scan for the specific service (as is recommended) because Zebra is stupid
        // and doesn't broadcast the service until you connect to the printer.
        //
        [self.centralManager scanForPeripheralsWithServices:nil
                                                    options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
    }
}



#pragma mark -- CBCentralManagerDelegate methods

//
// The BLE Central Manager has updated its state. If we are now powered on
// then begin scanning for peripherals.
//
- (void)centralManagerDidUpdateState:(nonnull CBCentralManager *)central
{
    [self startScan];
}


//
// A peripheral has been discovered. Check if it is the one we are interested in.
//
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    // Ok, it's in the range. Let's add the device name to bleDeviceNames array
    if (peripheral.name.length) {
        // Remove leading & trailing whitespace in peripheral.name
        NSString *peripheralName = [peripheral.name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *printerName = [self.printerName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        if ([printerName compare:peripheralName options:NSCaseInsensitiveSearch] == NSOrderedSame) {
            NSLog(@"Found printer %@", peripheralName);
            self.printer = peripheral;
            [self.centralManager stopScan];
            [self.centralManager connectPeripheral:peripheral options:nil];
        }
    }
}


//
// If the connection fails for whatever reason, we need to deal with it.
//
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    [self startScan];
}


//
// We've connected to the peripheral, now we need to discover the services and characteristics.
//
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    // Stop scanning
    [self.centralManager stopScan];
    
    peripheral.delegate = self;
    [peripheral discoverServices:@[self.zprinterUuid]];
}


//
// The printer has disconnected (probably turned off), start scanning again.
//
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    self.printer = nil;
    self.writePrinterCharacteristic = nil;
    [self startScan];
}


#pragma mark -- CBPeripheralDelegate methods

//
// The Zebra Printer Service was discovered, discover the characteristics.
//
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error != nil) {
        return;
    }
    
    for (CBService *service in peripheral.services) {
        // Discover the characteristics of write to printer
        if ([service.UUID isEqual:self.zprinterUuid]) {
            [peripheral discoverCharacteristics:@[self.writePrinterUuid] forService:service];
            return;
        }
    }
}


//
// The characteristics of Zebra Printer Service was discovered.
//
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (error != nil) {
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        // And check if it's the right one
        if ([characteristic.UUID isEqual:self.writePrinterUuid]) {
            self.writePrinterCharacteristic = characteristic;
            return;
        }
    }
}

//
// The services for a peripheral have changed. If we lost the zebra printer then mark
// it as lost and try to rediscover the services on the device.
//
- (void)peripheral:(CBPeripheral *)peripheral didModifyServices:(NSArray<CBService *> *)invalidatedServices
{
    for (CBService *service in invalidatedServices) {
        if ([service.UUID isEqual:self.zprinterUuid]) {
            self.writePrinterCharacteristic = nil;
        }
    }
    
    if (self.writePrinterCharacteristic == nil) {
        [peripheral discoverServices:@[self.zprinterUuid]];
    }
}

@end
