//
//  GooglePlacesConnection.h
// 
// Copyright 2011 Joshua Drew
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
// http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <CoreLocation/CoreLocation.h>
#import "GooglePlacesObject.h"
#import "ASIHTTPRequest.h"

@protocol GooglePlacesConnectionDelegate;

@interface GooglePlacesConnection : NSObject <ASIHTTPRequestDelegate>
{
    BOOL                connectionIsActive;
    int                 minAccuracyValue;

    CLLocationCoordinate2D userLocation;
}

@property (nonatomic, assign) id <GooglePlacesConnectionDelegate> delegate;
@property (nonatomic, assign) BOOL              connectionIsActive;
@property (nonatomic, assign) int               minAccuracyValue;

@property (nonatomic, strong) NSString* pageToken;

@property (nonatomic, assign) CLLocationCoordinate2D userLocation;

@property (nonatomic, strong) NSOperationQueue* reqQueue;

// useful functions
-(id)initWithDelegate:(id)del;

-(void)getGoogleObjectsRankByDistance:(CLLocationCoordinate2D)coords 
                             andTypes:(NSString *)types;

-(void)getGoogleObjectDetails:(NSString*)reference;

@end

@protocol GooglePlacesConnectionDelegate<NSObject>

- (void) googlePlacesConnection:(GooglePlacesConnection *)conn didFinishLoadingWithGooglePlacesObjects:(NSMutableArray *)objects;
- (void) googlePlacesConnection:(GooglePlacesConnection *)conn didFailWithError:(NSError *)error;

@end
