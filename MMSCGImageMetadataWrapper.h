//
//  MMSCGImageMetadataWrapper
//
//  Created by Mahyar McDonald on 7/4/16.
//  Copyright © 2016 Mahyar McDonald. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CLLocation.h>
#import <CoreFoundation/CFDictionary.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MMSLocationToTimezoneProvider
- (nullable NSTimeZone*) timeZoneFromLatitude:(double)latitude longitude:(double)longitude;
@end

/** 
 Class that wraps the CGImage metadata dictionary.  Only deals with the TIFF,GPS & Exif sub-dictionaries & their dates & locations.
 */
@interface MMSCGImageMetadataWrapper : NSObject

/// If the metadata set has GPS coordinates, then it will set the date with that location's timezone
@property (nonatomic,nullable,readonly) id<MMSLocationToTimezoneProvider> timezoneProvider;

/// Get: Most recent date from the dict set
/// Set: Sets the date for all existing dict sets (except GPS)
/// Uses timezoneProvider to help set the date if location != nil
@property (nonatomic,nullable) NSDate* date;
/// The date&time in the GPS dict.  Won't set the GPS date if it doesn't have one.
@property (nonatomic,nullable) NSDate* gpsDate;
/// The list of all the dates from the dict set.  You can get dates from the image's TIFF metadata, or from two date values in EXIF.  You can also get a date from the GPS location.
@property (nonatomic,readonly) NSArray<NSDate*> *dates;

/// Calls [self setLocation:location withAssumptions:NO]; Creates a CLLocation object from the internal GPS metadata dictionary.
@property (nonatomic,nullable) CLLocation *location;

/// Lets you get/set the lat/lng of the GPS metadata dict.
@property (nonatomic) CLLocationCoordinate2D coordinates;
/// The timezone of the gps coordinates. Returns nil if timezoneProvider is not set or some other failure.
@property (nonatomic,readonly,nullable) NSTimeZone* coordinateTimezone;

/// The mutable dictionary representation of the CGImage metadata CFDictionary
@property (nonatomic,readonly) NSMutableDictionary *rawDict;
/// A smaller dictionary repsentation than rawDict
@property (nonatomic, readonly) NSDictionary* smallDictionaryRepresentation;
/// NSString version of smallDictionaryRepresentation
@property (nonatomic, readonly) NSString* smallDescription;

/**
 Create the wrapper.

 @param rawDict          The CGImage metadata CFDictionary
 @param timezoneProvider An optional object that translates locations to timezones.

 @return an instance.
 */
- (instancetype) initWithCFDictionary:(CFDictionaryRef)rawDict timezoneProvider:(nullable id<MMSLocationToTimezoneProvider>) timezoneProvider;


/**
 Create the wrapper.
 
 @param rawDict          The CGImage metadata dictionary
 @param timezoneProvider An optional object that translates locations to timezones.
 
 @return an instance.
 */
- (instancetype) initWithDictionary:(NSDictionary*)rawDict timezoneProvider:(nullable id<MMSLocationToTimezoneProvider>) timezoneProvider NS_DESIGNATED_INITIALIZER;

- (instancetype) init NS_UNAVAILABLE;

/**
 Lets you set the gps metadata dict with a CLLocation object.  If the metadata dict doesn't have a GPS dict, it will create one.
 
 @param location    The locaiton object you want to set.
 @param assumptions If you want to bake in assumptions about CLLocaiton objects: directions are in degress based off a magnetic north.
 */
- (void) setLocation:(CLLocation * _Nullable)location withAssumptions:(BOOL)assumptions;

@end

NS_ASSUME_NONNULL_END
