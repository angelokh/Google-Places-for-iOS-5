//
//  GooglePlacesConnection.m
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

#import "GooglePlacesConnection.h"
#import "GTMNSString+URLArguments.h"
#import "ASIHTTPRequest.h"
#import "SBJsonParser.h"

@implementation GooglePlacesConnection

@synthesize delegate;
@synthesize connectionIsActive;
@synthesize minAccuracyValue;
@synthesize pageToken = _pageToken;

@synthesize userLocation;
@synthesize reqQueue = _reqQueue;

- (id)initWithDelegate:(id <GooglePlacesConnectionDelegate>)del
{
	self = [super init];
	
	if (!self)
		return nil;
	[self setDelegate:del];	
	return self;
}

- (id)init
{
	SHWarn(@"need a delegate!! use initWithDelegate!");
	return nil;
}

- (void)dealloc
{
    [_reqQueue cancelAllOperations];
}

//Method is called to load initial search
-(void)getGoogleObjectsRankByDistance:(CLLocationCoordinate2D)coords andTypes:(NSString *)types
{	
    if (connectionIsActive) {
        return;
    }
    
    if (!_reqQueue) {
        _reqQueue = [[NSOperationQueue alloc] init];
        [_reqQueue setMaxConcurrentOperationCount:1];
    }

    //NEW setting userlocation to the coords passed in for later use
    userLocation = coords;
    
    double centerLat = coords.latitude;
	double centerLng = coords.longitude;
    
    types = [types gtm_stringByEscapingForURLArgument];
    
    NSString* gurl;
    if ([_pageToken length] > 0) {
        gurl = [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/place/search/json?key=%@&sensor=true&pagetoken=%@", kGOOGLE_API_KEY, _pageToken];        
    } else {
        gurl = [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/place/search/json?location=%f,%f&rankby=distance&types=%@&sensor=true&key=%@",centerLat, centerLng, types, kGOOGLE_API_KEY];
    }
    
    NSURL * url = [NSURL URLWithString:gurl];
    ASIHTTPRequest * request = [ASIHTTPRequest requestWithURL:url];
    request.delegate = self;
    [request setDidFinishSelector:@selector(requestGooglePlaceFinished:)];
    [_reqQueue addOperation:request];

    connectionIsActive = YES;
}

//Method is called to get details of place
-(void)getGoogleObjectDetails:(NSString *)reference
{	
    if (connectionIsActive) {
        return;
    }

    if (!_reqQueue) {
        _reqQueue = [[NSOperationQueue alloc] init];
        [_reqQueue setMaxConcurrentOperationCount:1];
    }

    NSString* gurl  = [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/place/details/json?reference=%@&sensor=true&key=%@",
                       reference, kGOOGLE_API_KEY];
    
	NSURL * url = [NSURL URLWithString:gurl];
    ASIHTTPRequest * request = [ASIHTTPRequest requestWithURL:url];
    request.delegate = self;
    [request setDidFinishSelector:@selector(requestGooglePlaceFinished:)];
    [_reqQueue addOperation:request];
    
    connectionIsActive = YES;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - ASIHTTPRequest
-(void)requestGooglePlaceFinished:(ASIHTTPRequest *)request
{
    connectionIsActive = NO;

    SBJsonParser *json          = [[SBJsonParser alloc] init];
    NSError *jsonError          = nil;
    NSDictionary *parsedJSON    = [json objectWithString:[request responseString] error:&jsonError];
    
	if ([jsonError code]==0) 
    {
        NSString *responseStatus = [NSString stringWithFormat:@"%@",[parsedJSON objectForKey:@"status"]];
        
        if ([responseStatus isEqualToString:@"OK"]) 
        {
            if ([parsedJSON objectForKey: @"results"] == nil) {
                //Perform Place Details results
                NSDictionary *gResponseDetailData = [parsedJSON objectForKey: @"result"];
                NSMutableArray *googlePlacesDetailObject = [NSMutableArray arrayWithCapacity:1];  //Hard code since ONLY 1 result will be coming back
                
                GooglePlacesObject *detailObject = [[GooglePlacesObject alloc] initWithJsonResultDict:gResponseDetailData andUserCoordinates:userLocation];
                [googlePlacesDetailObject addObject:detailObject];
                
                if (delegate && [delegate respondsToSelector:@selector(googlePlacesConnection:didFinishLoadingWithGooglePlacesObjects:)]) {
                    [delegate performSelector:@selector(googlePlacesConnection:didFinishLoadingWithGooglePlacesObjects:) withObject:self withObject:googlePlacesDetailObject];
                }

            } else {
                //Perform Place Search results
                NSDictionary *gResponseData  = [parsedJSON objectForKey: @"results"];
                NSMutableArray *googlePlacesObjects = [NSMutableArray arrayWithCapacity:[[parsedJSON objectForKey:@"results"] count]]; 
                
                for (NSDictionary *result in gResponseData) 
                {
                    [googlePlacesObjects addObject:result];
                }
                
                for (int x=0; x<[googlePlacesObjects count]; x++) 
                {                
                    GooglePlacesObject *object = [[GooglePlacesObject alloc] initWithJsonResultDict:[googlePlacesObjects objectAtIndex:x] andUserCoordinates:userLocation];
                    [googlePlacesObjects replaceObjectAtIndex:x withObject:object];
                }
                
//                _pageToken = [NSString stringWithFormat:@"%@",[parsedJSON objectForKey:@"next_page_token"]];
                _pageToken = [parsedJSON objectForKey:@"next_page_token"];
                
                if (delegate && [delegate respondsToSelector:@selector(googlePlacesConnection:didFinishLoadingWithGooglePlacesObjects:)]) {
                    [delegate performSelector:@selector(googlePlacesConnection:didFinishLoadingWithGooglePlacesObjects:) withObject:self withObject:googlePlacesObjects];
                }

            }
            
        }
        else if ([responseStatus isEqualToString:@"ZERO_RESULTS"]) 
        {
            NSString *description = nil;
            int errCode;
            
            description = NSLocalizedString(@"No locations were found.", @"");
            errCode = 404;
            
            // Make underlying error.
            NSError *underlyingError = [[NSError alloc] initWithDomain:NSPOSIXErrorDomain
                                                                  code:errno userInfo:nil];
            // Make and return custom domain error.
            NSArray *objArray = [NSArray arrayWithObjects:description, underlyingError, nil];
            NSArray *keyArray = [NSArray arrayWithObjects:NSLocalizedDescriptionKey,
                                 NSUnderlyingErrorKey, nil];
            NSDictionary *eDict = [NSDictionary dictionaryWithObjects:objArray
                                                              forKeys:keyArray];
            
            NSError *responseError = [NSError errorWithDomain:@"GoogleLocalObjectDomain" 
                                                         code:errCode 
                                                     userInfo:eDict];
            
            if (delegate && [delegate respondsToSelector:@selector(googlePlacesConnection:didFailWithError:)]) {
                [delegate performSelector:@selector(googlePlacesConnection:didFailWithError:) withObject:self withObject:responseError];
            }
        } else {
            // no results
            NSString *responseDetails = [NSString stringWithFormat:@"%@",[parsedJSON objectForKey:@"status"]];
            NSError *responseError = [NSError errorWithDomain:@"GoogleLocalObjectDomain" 
                                                         code:500 
                                                     userInfo:[NSDictionary dictionaryWithObjectsAndKeys:responseDetails,@"NSLocalizedDescriptionKey",nil]];
            if (delegate && [delegate respondsToSelector:@selector(googlePlacesConnection:didFailWithError:)]) {
                [delegate performSelector:@selector(googlePlacesConnection:didFailWithError:) withObject:self withObject:responseError];
            }
        }
	}
	else 
    {
        if (delegate && [delegate respondsToSelector:@selector(googlePlacesConnection:didFailWithError:)]) {
            [delegate performSelector:@selector(googlePlacesConnection:didFailWithError:) withObject:self withObject:jsonError];
        }
	}
}

@end
