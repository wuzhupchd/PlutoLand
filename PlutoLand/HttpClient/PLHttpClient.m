//
//  PLHttpClient.m
//  PlutoLand
//
//  Created by xu xhan on 7/15/10.
//  Copyright 2010 xu han. All rights reserved.
//

#import "PLHttpClient.h"
#import "PLCore.h"
#import "PLGlobal.h"
#import "PLHttpConfig.h"
#import "PLOG.h"


@interface PLHttpClient ()
- (void)_clean;
- (void)_handleRequestStart;
- (void)_handleRequestStop;
- (void)_cleanTimeInfo;
- (void)_logTimeStarted;
- (void)_logTimeEnded;
@property(nonatomic,retain)NSURL* url;
@end


@implementation PLHttpClient

@synthesize statusCode;
@synthesize userInfo = _userInfo;
@synthesize enableGzipEncoding = _enableGzipEncoding;
@synthesize startImmediately = _startImmediately;
@synthesize response = _response;
@synthesize isForceHandleStatusCode = _isForceHandleStatusCode;
@synthesize requestMethod = _requestMethod;
@synthesize url = _url;
@synthesize isLoading = _isLoading;

static const int timeOutSec = 30;
static NSStringEncoding _gEncoding;


#pragma mark - request time
- (void)_cleanTimeInfo
{    
//    _timeInfo.start = 0;
//    _timeInfo.end = 0;
    _timeInfo.t1 = (struct timeval){0,0};
    _timeInfo.t2 = (struct timeval){0,0};
    
}
- (void)_logTimeStarted
{
//    _timeInfo.start = clock(); -> clock time return system+user time not real time
    gettimeofday(&_timeInfo.t1, NULL);
}
- (void)_logTimeEnded
{
//    _timeInfo.end = clock();
    gettimeofday(&_timeInfo.t2, NULL);
//    PLOG(@"costs %.3fs,%.3f in requesting %@",self.requestTimeCosted, t ,self.url);
}

- (NSTimeInterval) requestTimeCosted
{
//    DBL_MAX
//    if (_timeInfo.end > _timeInfo.start && _timeInfo.start >0) {
//        return (_timeInfo.end - _timeInfo.start)/((double)CLOCKS_PER_SEC);
//    }else{
//        return -1;
//    }

    double t = _timeInfo.t2.tv_sec - _timeInfo.t1.tv_sec;
    t += (_timeInfo.t2.tv_usec - _timeInfo.t1.tv_usec)/((double)1000000);
    if (t > 0) {
        return t;
    }else{
        return 0;
    }
}

#pragma mark -
#pragma mark CLass methods

+ (void)initialize
{
	_gEncoding = NSUTF8StringEncoding;
}

+ (void)setGlobalEncoding:(NSStringEncoding)encoding
{
	_gEncoding = encoding;
}

+ (NSData*)simpleSyncGet:(NSString*)urlStr
{
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
	return [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
}

+ (NSString*)syncGet:(NSURL*)url
{
	NSURLRequest* request = [NSURLRequest requestWithURL:url];
	NSData* responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
	return [[[NSString alloc] initWithData:responseData encoding:_gEncoding] autorelease]; 
}

#pragma mark -
#pragma mark life cycle

//@synthesize url = _url;
@synthesize didFailSelector = _didFailSelector;
@synthesize didFinishSelector = _didFinishSelector;
@synthesize delegate = _delegate;

- (id)init
{
	if (self = [super init]) {
		_receivedData = [[NSMutableData alloc] init];
		_delegate = nil;
		//		isStarted =	isFinished = isCancelled = NO;	
		_didFailSelector = @selector(httpClient:failed:);
		_didFinishSelector = @selector(httpClient:successed:);
		_startImmediately = YES;
		_enableGzipEncoding = NO;
        _isLoading = NO;
        //TODO: move this to configures
        _isForceHandleStatusCode = YES; // return data only if status code is 200
        [self _cleanTimeInfo];
	}
	return self;
}

- (id)initWithDelegate:(id<PLHttpClientDelegate>) delegate
{
    self = [self init];
    self.delegate = delegate;
    return self;
}

- (void)dealloc {

	_delegate = nil;
	[self cancel];
	
	[_userInfo release], _userInfo = nil;
	PLSafeRelease(_url);
	PLSafeRelease(_response);
	PLSafeRelease(_connection);
	PLSafeRelease(_receivedData);
	[super dealloc];
}

- (void)_clean{

    [self cancel];
	PLSafeRelease(_url);
	PLSafeRelease(_response);
	PLSafeRelease(_connection);
	PLSafeRelease(_receivedData);		
	_receivedData = [[NSMutableData alloc] init];
	self.userInfo = nil;
    _requestMethod = PLHttpMethodUndefined;
    [self _cleanTimeInfo];
}

#pragma mark -
#pragma mark public

- (NSMutableURLRequest*)makeRequest:(NSURL*)url_
{
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:url_];	
	[request setTimeoutInterval:timeOutSec];
    NSString* ua = [[PLHttpConfig s] userAgentFormated];
    if (ua) {
        [request setValue:ua forHTTPHeaderField:@"User-Agent"];
    }
	if (_enableGzipEncoding) {
		[request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
	}
    return [request autorelease];
}

- (void)get:(NSURL *)url{
	[self get:url userInfo:nil];
}

- (void)get:(NSURL *)url userInfo:(NSDictionary*)info;
{
    
	[self _clean];
    _requestMethod = PLHttpMethodGet;
	self.userInfo = info;
    self.url = url;
    
	NSMutableURLRequest* request = [self makeRequest:_url];
	[self willRequest:request];
    [self _handleRequestStart];
    PLOGENV(PLOG_ENV_NETWORK,@"GET %@",request.URL);
	_connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:_startImmediately];
}

- (void)post:(NSURL*)url body:(NSString*)body
{
        
	[self _clean];
    _requestMethod = PLHttpMethodPost;
	self.userInfo = nil;
    self.url = url;
    
	NSMutableURLRequest* request = [self makeRequest:_url];	
    [request setHTTPMethod:@"POST"];

	if (body) {
		[request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
	}
    [self willRequest:request];
    [self _handleRequestStart];
    PLOGENV(PLOG_ENV_NETWORK,@"POST %@ \nbody:%@",url,
            [[[NSString alloc] initWithData:request.HTTPBody
                                  encoding:NSUTF8StringEncoding] autorelease]);
	_connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:_startImmediately];
}

- (void)postForm:(NSURL*)url params:(NSDictionary*)params fileName:(NSString*)fileName fileData:(NSData*)data
{    
    [self _clean];
    _requestMethod = PLHttpMethodPost;
	self.userInfo = nil;
    self.url = url;
    
    NSMutableURLRequest* request = [self makeRequest:_url];	
    [request setHTTPMethod:@"POST"];
    
    NSString* boundary = @"ixhan-dot-com";
    NSString *endItemBoundary = [NSString stringWithFormat:@"\r\n--%@\r\n",boundary];
    
    // setup headers 
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];    
    
    
    NSMutableString* postString = [NSMutableString string];
    [postString appendFormat:@"--%@\r\n",boundary];
    
    // add params
    for (id key in [params allKeys]) {
        [postString appendFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n",key];
        [postString appendFormat:@"%@",params[key]];
        [postString appendString:endItemBoundary];
    }
    
    if (fileName && data) {
        // add image flag
        [postString appendFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@.jpg\"\r\n", fileName,fileName];
        [postString appendFormat:@"Content-Type: image/jpg\r\n\r\n"];
    }

    NSMutableData* body = [NSMutableData dataWithData:[postString dataUsingEncoding:NSUTF8StringEncoding]];
    
    if (fileName && data) {
        [body appendData:data];
    }
    
    //end
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [request setHTTPBody:body];
    
    [self willRequest:request];
    [self _handleRequestStart];
    PLOGENV(PLOG_ENV_NETWORK,@"POST(File:%@) %@ \nbody:%@",fileName, url,params);
	_connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:_startImmediately];
}

- (void)put:(NSURL*)url body:(NSString*)body
{
    [self _clean];
    _requestMethod = PLHttpMethodPut;
	self.userInfo = nil;
    self.url = url;
    
	NSMutableURLRequest* request = [self makeRequest:_url];	
    [request setHTTPMethod:@"PUT"];
    
	if (body) {
		[request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
	}
    [self willRequest:request];
    [self _handleRequestStart];
    PLOGENV(PLOG_ENV_NETWORK,@"PUT %@ \nbody:%@",url,body);
	_connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:_startImmediately];
}

- (void)delete:(NSURL*)url
{
	[self _clean];
    _requestMethod = PLHttpMethodDelete;
    self.userInfo = nil;
    self.url = url;
    
	NSMutableURLRequest* request = [self makeRequest:_url];
    [request setHTTPMethod:@"DELETE"];
    
    [self willRequest:request];
    [self _handleRequestStart];
    PLOGENV(PLOG_ENV_NETWORK,@"DELETE %@",url);
	_connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:_startImmediately];
}


- (void)willRequest:(NSMutableURLRequest*)request
{
    
}

- (void)cancel
{
    if (_fileDownloadStream) {
        [_fileDownloadStream close];
        PLSafeRelease(_fileDownloadStream);
    }
    
	[_connection cancel];
	PLSafeRelease(_connection);
    PLSafeRelease(_receivedData);
    [self _handleRequestStop];
    [self _cleanTimeInfo];
}

- (void)start
{
	if(_connection && _startImmediately == NO){
        _isLoading = YES;
        [self _logTimeStarted];
        [[PLHttpConfig s] requestStarted];
		[_connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
		[_connection start];		
	}
}

- (NSString*)stringValue
{
	if (_receivedData) {
		return [[[NSString alloc] initWithData:_receivedData encoding:_gEncoding] autorelease];
	}
	return nil;
}

- (id)responseHeaderForKey:(NSString*)key
{
	return [_response allHeaderFields][key];
}

- (void)cleanBeforeRelease
{
	_delegate = nil;
	[self cancel];
}

- (void)_handleRequestStart
{
    if(_startImmediately){        
        _isLoading = YES;
        [self _logTimeStarted];
        [[PLHttpConfig s] requestStarted];
    }                    
}

- (void)_handleRequestStop
{
    if (_fileDownloadStream) {
        [_fileDownloadStream close];
        PLSafeRelease(_fileDownloadStream);
    }
    
    if (_isLoading) {
        [self _logTimeEnded];
        [[PLHttpConfig s] requestStoped];
        _isLoading = NO;
    }
}
#pragma mark -
#pragma mark Delegate for NSURLRequest

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self _handleRequestStop];
    
	if ([self.delegate respondsToSelector:self.didFailSelector] ) {
		[self.delegate performSelector:self.didFailSelector withObject:self withObject:error];
	}
	//	PLLOG_STR(@"failed",nil);
	//	isFinished = YES;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self _handleRequestStop];
	if ([self.delegate respondsToSelector:self.didFinishSelector] ) {
		[self.delegate performSelector:self.didFinishSelector withObject:self withObject:_receivedData];
	}	
	//	PLLOG_STR(@"finished",nil);
	
	//	self.isFinished = YES;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)aresponse {
	_response = [(NSHTTPURLResponse*)aresponse retain];
	statusCode = (int)[_response statusCode];
    if (_isForceHandleStatusCode) {
        if (statusCode != 200) {
            [self _clean];
            NSError* error = [NSError errorWithDomain:PLHttpClientErrorDomain
                                                 code:statusCode
                                             userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"http response code %d failed",statusCode]}];
            statusCode = 0;
            [self connection:nil didFailWithError:error];
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (_downloadDestinationPath) {
        if (!_fileDownloadStream) {
            //TODO: append support
            _fileDownloadStream = [[NSOutputStream alloc] initToFileAtPath:_downloadDestinationPath
                                                                    append:NO];
            [_fileDownloadStream open];
        }
        NSUInteger length = [data length] , writedLength = 0;
        do {
            writedLength = [_fileDownloadStream write:[data bytes]
                                            maxLength:length];
            if (-1 == writedLength) {
                //TODO: parse error
                NSLog(@"%@", [_fileDownloadStream streamError]);
                break;
            }
            length -= writedLength;
        } while (length > 0 );
        
    }else{
        [_receivedData appendData:data];
    }
	
}

@end






@implementation PLHttpClient (Helper)
+ (NSString*)paramsFromDict:(NSDictionary*)dict
{
    NSMutableArray *pairs = [NSMutableArray array];
	for (NSString *key in [dict keyEnumerator])
	{
		if (!([[dict valueForKey:key] isKindOfClass:[NSString class]]))
		{
			continue;
		}
		
		[pairs addObject:[NSString stringWithFormat:@"%@=%@", key, [dict[key] URLEscaped]]];
	}
	
	return [pairs componentsJoinedByString:@"&"];   
}
@end