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

/**
 Initialize the bluetooth low energy zebra printing system

 @return A reference to the new object
 */
- (id)init
{
    if ((self = [super init]) == nil) {
        return nil;
    }

    self.zprinterUuid = [CBUUID UUIDWithString:ZPRINTER_SERVICE_UUID];
    self.writePrinterUuid = [CBUUID UUIDWithString:WRITE_TO_ZPRINTER_CHARACTERISTIC_UUID];
    
    return self;
}


/**
 Set the name of the printer and begin scanning for this device name
 
 @param printerName The name of the printer to be connected to
 */
- (void)setPrinterName:(NSString *)printerName
{
    _printerName = printerName;
    if (self.printer != nil) {
        [self.centralManager cancelPeripheralConnection:self.printer];
        self.printer = nil;
        self.writePrinterCharacteristic = nil;
    }
    
    if (self.printerName == nil || self.printerName.length == 0) {
        if (self.centralManager != nil) {
            [self.centralManager stopScan];
            self.centralManager = nil;
        }
    }
    else {
        if (self.centralManager == nil) {
            self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        }

        [self startScan];
    }
}


/**
 Send the ZPL data to the printer in chunks that are smaller than the MTU

 @param data The full ZPL data to be sent
 */
- (void)sendZPLToPrinter:(NSData *)data
{
    const char *bytes = data.bytes;
    size_t length = data.length;
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


/**
 Print the specified ZPL code to the connected printer
 
 @param data The ZPL data to be sent to the printer
 @return YES if the label was printed or NO if an error occurred
 */
- (BOOL)print:(NSData *)data
{
    if (self.writePrinterCharacteristic == nil) {
        return NO;
    }
    
    [self sendZPLToPrinter:data];
    
    return YES;
}


/**
 Start scanning for the printer
 */
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

/**
 The BLE Central MAnager has updated its state, begin scanning

 @param central The central manager whose state has changed
 */
- (void)centralManagerDidUpdateState:(nonnull CBCentralManager *)central
{
    if ( central.state == CBManagerStateUnauthorized )
    {
        return;
    }

    [self startScan];
}


//
// A peripheral has been discovered. Check if it is the one we are interested in.
//
/**
 A peripheral has been discovered, we need to check if it is the one we are
 interested in and if so begin connecting

 @param central The central that has discovered the peripheral
 @param peripheral The peripheral that was discovered
 @param advertisementData Any advertisement data that was broadcasted
 @param RSSI The RSSI value of the peripheral
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    if (peripheral.name.length) {
        //
        // Remove leading & trailing whitespace in peripheral.name
        //
        NSString *peripheralName = [peripheral.name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *printerName = [self.printerName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        if ([printerName compare:peripheralName options:NSCaseInsensitiveSearch] == NSOrderedSame) {
            self.printer = peripheral;
            [self.centralManager stopScan];
            [self.centralManager connectPeripheral:peripheral options:nil];
        }
    }
}


/**
 If the connection fails, start scanning again. In the future we may want to
 introduce a pause before starting the next scan.

 @param central The central manager that failed to connect
 @param peripheral The peripheral that we attempted to connect to
 @param error The error that occurred during connection
 */
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    [self startScan];
}


/**
 We have connected to a peripheral, stop scanning and attempt to discover the
 services that are offered

 @param central The central manager that successfully connected
 @param peripheral The peripheral that we connected to
 */
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    [self.centralManager stopScan];
    
    peripheral.delegate = self;
    [peripheral discoverServices:@[self.zprinterUuid]];
}


/**
 The peripheral has disconnected, start scanning again so we see it when it
 comes back.

 @param central The central manager that lost connection
 @param peripheral The peripheral that disconnected from us
 @param error The error that describes why we disconnected
 */
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

/**
 The services have been discovered. Look to see if it's the one we need and
 then start scanning for the characteristics of the service.

 @param peripheral The peripheral whose services we have discovered
 @param error Any error that occurred while discovering these services
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error != nil) {
        return;
    }
    
    for (CBService *service in peripheral.services) {
        if ([service.UUID isEqual:self.zprinterUuid]) {
            [peripheral discoverCharacteristics:@[self.writePrinterUuid] forService:service];
            return;
        }
    }
}


//
// The characteristics of Zebra Printer Service was discovered.
//

/**
 The characteristics of the Zebra Printer Service have been discovered so we are
 ready to start printing

 @param peripheral The peripheral whose characteristics have been discovered
 @param service The service whose characteristics have been discovered
 @param error Any error that occurred while trying to discover the characteristics
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (error != nil) {
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:self.writePrinterUuid]) {
            self.writePrinterCharacteristic = characteristic;
            return;
        }
    }
}


/**
 The services for a peripheral have changed. If we lost the zebra printer then
 mark it as lost and try to rediscover the services on the device.

 @param peripheral The peripheral whose services changed
 @param invalidatedServices The services that are no longer valid
 */
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
