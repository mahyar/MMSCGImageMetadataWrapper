//
//  MMSCGImageMetadataWrapper
//
//  Created by Mahyar McDonald on 7/4/16.
//  Copyright © 2016 Mahyar McDonald. All rights reserved.
//

#import "MMSCGImageMetadataWrapper.h"

@interface MMSCGImageMetadataWrapper ()
@property (nonatomic) NSDateFormatter *formatter;
@end

@implementation MMSCGImageMetadataWrapper

@synthesize coordinateTimezone = _coordinateTimezone;

#pragma mark - Init

- (instancetype) initWithCFDictionary:(CFDictionaryRef)rawDict timezoneProvider:(nullable id<MMSLocationToTimezoneProvider>)timezoneProvider {
    NSDictionary *cast = (__bridge NSDictionary*)rawDict;
    return [self initWithDictionary:cast timezoneProvider:timezoneProvider];
}

- (instancetype) initWithDictionary:(NSDictionary*)rawDict timezoneProvider:(nullable id<MMSLocationToTimezoneProvider>)timezoneProvider {
    if (self = [super init]) {
        _rawDict = [rawDict mutableCopy];
        _timezoneProvider = timezoneProvider;
        
        NSMutableDictionary *replacement = [[NSMutableDictionary alloc] init];
        for (NSString *key in _rawDict) {
            id value = _rawDict[key];
            if ([value respondsToSelector:@selector(mutableCopy)] && [value respondsToSelector:@selector(mutableCopyWithZone:)]) {
                replacement[key] = [value mutableCopy];
            }
        }
        for (NSString *key in replacement) {
            _rawDict[key] = replacement[key];
        }
        
        [self coordinateTimezone];
    }
    return self;
}

#pragma mark - Formatting

- (NSDateFormatter*)formatter {
    if (!_formatter) {
        _formatter = [[NSDateFormatter alloc] init];
        _formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        _formatter.dateFormat = @"yyyy:MM:dd HH:mm:ss";
    }
    //This is important to avoid an infinite loop. Dont do self.coordinateTimezone
    _formatter.timeZone = _coordinateTimezone ?: [NSTimeZone timeZoneForSecondsFromGMT:0];
    return _formatter;
}

+ (NSDateFormatter*)sharedGPSFormatter {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy:MM:dd HH:mm:ss";
        formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    });
    return formatter;
}

- (NSString*)description {
    return _rawDict.description;
}

- (NSDictionary*)smallDictionaryRepresentation {
    
    return @{
      @"date":                 self.date ?: [NSNull null],
      @"gpsDate":              self.gpsDate ?: [NSNull null],
      @"dates":                self.dates ?: [NSNull null],
      @"location":             self.location ?: [NSNull null],
      @"coordinateTimeZone":   self.coordinateTimezone ?: [NSNull null],
      };
}

- (NSString*)smallDescription {
    return self.smallDictionaryRepresentation.description;
}

#pragma mark - Dates

- (NSDate*) date {
    return (NSDate*)[self.dates valueForKeyPath:@"@max.self"];
}

- (void) setDate:(NSDate *)date {
    NSString *formatted = date ? [self.formatter stringFromDate:date] : nil;
    self.rawDict[(NSString*)kCGImagePropertyTIFFDictionary][(NSString*)kCGImagePropertyTIFFDateTime] = formatted;
    self.rawDict[(NSString*)kCGImagePropertyExifDictionary][(NSString*)kCGImagePropertyExifDateTimeOriginal] = formatted;
    self.rawDict[(NSString*)kCGImagePropertyExifDictionary][(NSString*)kCGImagePropertyExifDateTimeDigitized] = formatted;
    self.gpsDate = date;
}

- (NSArray<NSDate*> *) dates {
    NSMutableArray *output = [[NSMutableArray alloc] init];
    
    NSString* tiffDateStr = self.rawDict[(NSString*)kCGImagePropertyTIFFDictionary][(NSString*)kCGImagePropertyTIFFDateTime] ?: @"";
    NSString* exifDateOriginalStr = self.rawDict[(NSString*)kCGImagePropertyExifDictionary][(NSString*)kCGImagePropertyExifDateTimeOriginal] ?: @"";
    NSString* exifDateDigiStr = self.rawDict[(NSString*)kCGImagePropertyExifDictionary][(NSString*)kCGImagePropertyExifDateTimeDigitized] ?: @"";
    
    for (NSString* dateStr in @[tiffDateStr,exifDateDigiStr,exifDateOriginalStr]) {
        if (dateStr.length > 0) {
            NSDate *date = [self.formatter dateFromString:dateStr];
            if (date) {
                [output addObject:date];
            }
        }
    }
    
    NSDate *gpsDate = self.gpsDate;
    if (gpsDate) {
        [output addObject:gpsDate];
    }
    
    return output;
}

- (NSDate*) gpsDate {
    NSString* gpsDate = self.rawDict[(NSString*)kCGImagePropertyGPSDictionary][(NSString*)kCGImagePropertyGPSDateStamp] ?: @"";
    NSString* gpsTime = self.rawDict[(NSString*)kCGImagePropertyGPSDictionary][(NSString*)kCGImagePropertyGPSTimeStamp] ?: @"";
    NSString* gpsCombined = gpsDate && gpsTime ? [NSString stringWithFormat:@"%@ %@",gpsDate,gpsTime] : @"";
    NSDate* date = [self.class.sharedGPSFormatter dateFromString:gpsCombined];
    return date;
}

- (void)setGpsDate:(NSDate *)gpsDate {
    NSMutableDictionary *gps = self.rawDict[(NSString*)kCGImagePropertyGPSDictionary];

    if (gpsDate && gps) {
        NSString *dateStr = [self.class.sharedGPSFormatter stringFromDate:gpsDate];
        NSArray *split = [dateStr componentsSeparatedByString:@" "];
        
        if (split.count == 2) {
            gps[(NSString*)kCGImagePropertyGPSDateStamp] = split[0];
            gps[(NSString*)kCGImagePropertyGPSTimeStamp] = split[1];
        }
    }
    else {
        gps[(NSString*)kCGImagePropertyGPSDateStamp] = nil;
        gps[(NSString*)kCGImagePropertyGPSTimeStamp] = nil;
    }

}

#pragma mark - GPS Location

- (NSTimeZone*) coordinateTimezone {
    if (!_coordinateTimezone && self.timezoneProvider) {
        CLLocationCoordinate2D coord = self.coordinates;
        if (CLLocationCoordinate2DIsValid(coord)) {
            _coordinateTimezone = [self.timezoneProvider timeZoneFromLatitude:coord.latitude longitude:coord.longitude];
            self.formatter.timeZone = _coordinateTimezone;
        }
    }
    return _coordinateTimezone;
}

- (CLLocationCoordinate2D)coordinates {
    NSMutableDictionary *gps = self.rawDict[(NSString*)kCGImagePropertyGPSDictionary];
    if (gps) {
        NSString *lat =         gps[(NSString*) kCGImagePropertyGPSLatitude];
        NSString *latRef =      gps[(NSString*) kCGImagePropertyGPSLatitudeRef];
        NSString *lon =         gps[(NSString*) kCGImagePropertyGPSLongitude];
        NSString *lonRef =      gps[(NSString*) kCGImagePropertyGPSLongitudeRef];
        
        double latRefMult = [latRef isEqualToString:@"S"] ? -1 : 1;
        double longRefMult = [lonRef isEqualToString:@"W"] ? -1 : 1;
        CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(latRefMult*[lat doubleValue], longRefMult*[lon doubleValue]);
        return coord;
    }
    return kCLLocationCoordinate2DInvalid;
}

- (void)setCoordinates:(CLLocationCoordinate2D)coordinates {
    _coordinateTimezone = nil;
    NSMutableDictionary *gps = nil;
    if (CLLocationCoordinate2DIsValid(coordinates)) {
        gps = self.rawDict[(NSString*)kCGImagePropertyGPSDictionary] ?: [NSMutableDictionary dictionary];
        gps[(NSString*) kCGImagePropertyGPSLatitude]  = [@(ABS(coordinates.latitude)) stringValue];
        gps[(NSString*) kCGImagePropertyGPSLongitude] = [@(ABS(coordinates.longitude)) stringValue];
        gps[(NSString*) kCGImagePropertyGPSLatitudeRef] = coordinates.latitude > 0 ? @"N" : @"S";
        gps[(NSString*) kCGImagePropertyGPSLongitudeRef] = coordinates.longitude > 0 ? @"E" : @"W";
    }
    self.rawDict[(NSString*)kCGImagePropertyGPSDictionary] = gps;
}

- (CLLocation*) location {
    NSMutableDictionary *gps = self.rawDict[(NSString*)kCGImagePropertyGPSDictionary];
    
    if (gps) {
        NSString *alt =         gps[(NSString*) kCGImagePropertyGPSAltitude];
        NSNumber *altRef =      gps[(NSString*) kCGImagePropertyGPSAltitudeRef];
        NSString *horizAcc =    gps[(NSString*) kCGImagePropertyGPSHPositioningError];
        NSString *course =      gps[(NSString*) kCGImagePropertyGPSDestBearing];
        NSString *speed =       gps[(NSString*) kCGImagePropertyGPSSpeed];
        NSString *speedRef =    gps[(NSString*) kCGImagePropertyGPSSpeedRef];
        
        double altMult = [altRef integerValue] == 1 ? -1 : 1;
        double speedVal = [self _speedInMetersPerSecond:[speed doubleValue] withCode:speedRef];
        
        CLLocation *ret = [[CLLocation alloc] initWithCoordinate:self.coordinates
                                                        altitude:[alt doubleValue]*altMult
                                              horizontalAccuracy:[horizAcc doubleValue]
                                                verticalAccuracy:0
                                                          course:[course doubleValue]
                                                           speed:speedVal
                                                       timestamp:self.gpsDate];
        return ret;
    }

    return nil;
}

- (double) _speedFromMetersPerSecondToKmh:(double)speed {
    return speed * 3.6;
}

- (double) _speedInMetersPerSecond:(double)speed withCode:(NSString*)code {
    if (code == nil) {
        return 0;
    } else if ([code isEqualToString:@"K"]) { // km/h
        return speed/3.6;
    } else if ([code isEqualToString:@"M"]) { //mph
        return 0.44704 * speed;
    } else if ([code isEqualToString:@"N"]) { // knots / hr (aka knot)
        return 0.514444 * speed;
    }
    
    NSAssert(false, @"bad code value");
    return speed;
}

- (void) setLocation:(CLLocation *)location {
    [self setLocation:location withAssumptions:NO];
}

- (void) setLocation:(CLLocation *)location withAssumptions:(BOOL)assumptions {
    _coordinateTimezone = nil;
    NSMutableDictionary *gps = nil;
    if (location) {
        gps = self.rawDict[(NSString*)kCGImagePropertyGPSDictionary] ?: [NSMutableDictionary dictionary];
        
        if (assumptions) {
            // http://www.kanzaki.com/ns/exif is helpful
            gps[(NSString*) kCGImagePropertyGPSImgDirectionRef] = @"M"; //assumed to be based off magnetic north vs. true (M or T)
            gps[(NSString*) kCGImagePropertyGPSDestBearingRef] = @"M"; //assumed to be based off magnetic north vs. true (M or T)
        }
        
        gps[(NSString*) kCGImagePropertyGPSLatitude] = [@(location.coordinate.latitude) stringValue];
        gps[(NSString*) kCGImagePropertyGPSLongitude] = [@(location.coordinate.longitude) stringValue];
        gps[(NSString*) kCGImagePropertyGPSAltitude] = [@(ABS(location.altitude)) stringValue];
        gps[(NSString*) kCGImagePropertyGPSAltitudeRef] = location.altitude < 0 ? @(1) : @(0);
        gps[(NSString*) kCGImagePropertyGPSHPositioningError] = [@(location.horizontalAccuracy) stringValue];
        gps[(NSString*) kCGImagePropertyGPSDestBearing] = [@(location.course) stringValue];
        gps[(NSString*) kCGImagePropertyGPSImgDirection] = [@(location.course) stringValue];
        
        double speed = [self _speedFromMetersPerSecondToKmh:location.speed];
        gps[(NSString*) kCGImagePropertyGPSSpeed] = [@(speed) stringValue];
        gps[(NSString*) kCGImagePropertyGPSSpeedRef] = @"K";
        
        self.gpsDate = location.timestamp;
    }
    self.rawDict[(NSString*)kCGImagePropertyGPSDictionary] = gps;
}


@end
