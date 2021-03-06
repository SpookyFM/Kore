#include "pch.h"
#include "Http.h"
#import <Foundation/Foundation.h>

@interface Connection : NSObject<NSURLConnectionDelegate> {
	NSMutableData* responseData;
	Kore::HttpCallback callback;
	int statusCode;
}

@end

@implementation Connection

- (id)initWithCallback:(Kore::HttpCallback)aCallback {
	if (self = [super init]) {
		callback = aCallback;
		statusCode = 0;
		return self;
	}
	else {
		return nil;
	}
}

- (void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response {
	responseData = [[NSMutableData alloc] init];
	NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
	statusCode = (int)[httpResponse statusCode];
}

- (void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data {
	[responseData appendData:data];
	[responseData appendBytes:"\0" length:1];
}

- (NSCachedURLResponse *)connection:(NSURLConnection*)connection willCacheResponse:(NSCachedURLResponse*)cachedResponse {
	return nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection*)connection {
	callback(0, statusCode, (const char*)[responseData bytes]);
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error {
	callback(1, statusCode, 0);
}

@end

using namespace Kore;

void Kore::httpRequest(const char* url, const char* path, const char* data, int port, bool secure, HttpMethod method, HttpCallback callback) {
	NSString* urlstring = secure ? @"https://" : @"http://";
	urlstring = [urlstring stringByAppendingString:[NSString stringWithUTF8String:url]];
	urlstring = [urlstring stringByAppendingString:@":"];
	urlstring = [urlstring stringByAppendingString:[[NSNumber numberWithInt:port] stringValue]];
	urlstring = [urlstring stringByAppendingString:[NSString stringWithUTF8String:path]];
	
	NSURL* aUrl = [NSURL URLWithString:urlstring];
	NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:aUrl
														   cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
	
	switch (method) {
		case GET:
			[request setHTTPMethod:@"GET"];
			break;
		case POST:
			[request setHTTPMethod:@"POST"];
			break;
		case PUT:
			[request setHTTPMethod:@"PUT"];
			break;
		case DELETE:
			[request setHTTPMethod:@"DELETE"];
			break;
	}
	
	if (data != 0) {
		NSString* datastring = [NSString stringWithUTF8String:data];
		[request setHTTPBody:[datastring dataUsingEncoding:NSUTF8StringEncoding]];
	}
	
	Connection* connection = [[Connection alloc] initWithCallback:callback];
	[[NSURLConnection alloc] initWithRequest:request delegate:connection];
}
