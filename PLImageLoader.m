//
//  PLImageClient.m
//  PlutoLand
//
//  Created by xu xhan on 7/15/10.
//  Copyright 2010 xu han. All rights reserved.
//

//TODO: add cache function at fetch method and store method(succeeded on fetching img data)

#import "PLImageLoader.h"
#import "PLImageCache.h"

@implementation PLImageLoader

@synthesize info = _info;

- (id)init
{
	if (self = [super init]) {
		self.delegate = self;
		_imageView = nil;
		_isCacheEnable = YES;
		_isFreshOnSucceed = YES;
	}
	return self;
}

- (void)fetchForImageView:(UIImageView*)imageView URL:(NSString*)url cacheEnable:(BOOL)cacheEnable userInfo:(NSDictionary*)info;
{
	_imageView = imageView;
	_isCacheEnable = cacheEnable;

	self.info = info;
	[super requestGet:url];
}


- (void)fetchForImageView:(UIImageView *)imageView URL:(NSString *)url  freshOnSucceed:(BOOL)isFresh cacheEnable:(BOOL)cacheEnable userInfo:(NSDictionary *)info
{
	_imageView = imageView;
	_isCacheEnable = cacheEnable;
	_isFreshOnSucceed = isFresh;
	
	self.info = info;
	[super requestGet:url];
	
}

#pragma mark -
#pragma mark PLImageRequestDelegate
- (void)imageRequestFailed:(PLImageRequest*)request withError:(NSError*)error
{
//	PLLOG_STR(@"error on fetch image: ",self.url);
}

- (void)imageRequestSucceeded:(PLImageRequest*)request
{
//	NSLog(@"image getted");
	UIImage* img = [UIImage imageWithData:request.imageData];
	if (_isFreshOnSucceed && _imageView) {
		_imageView.image = img;
	}
	
	//TODO: add more condition here
	[[PLImageCache sharedCache] storeData:request.imageData forURL:[self.url absoluteString]];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:NOTICE_IMAGE_LOADER_SUCCEEDED object:_imageView userInfo:_info];
}


- (void)dealloc {
	[_info release], _info = nil;
	[super dealloc];
}
@end
