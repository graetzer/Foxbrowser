//
//  DEURLProtocol.m
//  DE Mail
//
//  Created by Simon Grätzer on 20.08.12.
//  Copyright (c) 2012 Simon Grätzer. All rights reserved.
//

#import "SGURLProtocol.h"
#import "SGCredentialsPrompt.h"

#ifdef DEBUG
#   define DLog(fmt, ...) {NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);}
#   define ELog(err) {if(err) DLog(@"%@", err)}
#else
#   define DLog(...)
#   define ELog(err)
#endif

static BOOL							TrustSelfSignedCertificates  = NO;
static NSURLCredentialPersistence	DefaultCredentialPersistence = NSURLCredentialPersistenceForSession;
static NSString*					SGURLHeader                 = @"X-SGURLProtocol";
static NSInteger					RegisterCount				 = 0;
static NSLock*                      VariableLock                 = nil;

@interface SGURLProtocol ()
@property (nonatomic, strong) SGCredentialsPrompt *credPrompt;
@end

@implementation SGURLProtocol
+ (void)registerProtocol {
	if (!VariableLock)
	{
		VariableLock = [[NSLock alloc] init];
	}
	[VariableLock lock];
	if (RegisterCount==0)
	{
		[NSURLProtocol registerClass:[self class]];
	}
	RegisterCount++;
	[VariableLock unlock];
}

+ (void)unregisterProtocol {
	[VariableLock lock];
	RegisterCount--;
	if (RegisterCount==0)
	{
		[NSURLProtocol unregisterClass:[self class]];
	}
	[VariableLock unlock];
}

+ (void) setTrustSelfSignedCertificates:(BOOL)Trust{
	[VariableLock lock];
	TrustSelfSignedCertificates = Trust;
	[VariableLock unlock];
}

+ (BOOL) getTrustSelfSignedCertificates{
	[VariableLock lock];
	return TrustSelfSignedCertificates;
	[VariableLock unlock];
}

#pragma mark - NSProtocol 
+ (BOOL)canInitWithRequest:(NSURLRequest *)request{
    if (
        (
         ([[[[request URL] scheme] lowercaseString] isEqualToString:@"http"])
         || ([[[[request URL] scheme] lowercaseString] isEqualToString:@"https"])
		 )
        && ([request valueForHTTPHeaderField:SGURLHeader] == nil)
        )
    {
        return YES;
    }
    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

-(id)initWithRequest:(NSURLRequest *)request
      cachedResponse:(NSCachedURLResponse *)cachedResponse
              client:(id <NSURLProtocolClient>)client
{

    NSMutableURLRequest *mRequest = [request mutableCopy];
    [mRequest setValue:@"" forHTTPHeaderField:SGURLHeader];

    if (self = [super initWithRequest:mRequest
                   cachedResponse:cachedResponse
                           client:client])
	{
        self.URLRequest = mRequest;
        DialogLock = [[NSLock alloc] init];
		[VariableLock lock];
		CredentialsPresistance = DefaultCredentialPersistence;
		[VariableLock unlock];
    }
    return self;
}

- (void)startLoading {
    self.URLConnection = [NSURLConnection connectionWithRequest:[self request] delegate:self];
}

- (void)stopLoading {
	[self.URLConnection cancel];
    self.URLConnection = nil;
}

#pragma mark - NSURLRequestDelegate
//***************************************************************************
- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse{    
	NSMutableURLRequest* Request = [request mutableCopy];
	if (redirectResponse)
	{
		[Request setValue:nil forHTTPHeaderField:SGURLHeader];
		[[self client] URLProtocol:self wasRedirectedToRequest:Request redirectResponse:redirectResponse];
	}
	self.URLRequest  = Request;
	return Request;

}


- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace{
	return YES;
}


- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection{
	return YES;
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
        if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust)
        {
            SecTrustRef serverTrust = [[challenge protectionSpace] serverTrust];
            SecTrustResultType result;
            SecTrustEvaluate(serverTrust, &result);
            
            if(result == kSecTrustResultProceed) {
                [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
            } else{
                [challenge.sender performDefaultHandlingForAuthenticationChallenge:challenge];
            }
        }
        else if(challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic
                || challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest
                || challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodNTLM)
        {
            NSString *proposedName;
            if (challenge.proposedCredential) {
                if (challenge.proposedCredential.hasPassword && challenge.previousFailureCount == 0) {
                    [challenge.sender useCredential:challenge.proposedCredential forAuthenticationChallenge:challenge];
                    return;
                } else {
                    proposedName = challenge.proposedCredential.user;
                }
            }
            [DialogLock lock];
            DialogResult = -1;
            [self performSelectorOnMainThread:@selector(presentPromptWithName:) withObject:proposedName waitUntilDone:YES];
            [self performSelectorOnMainThread:@selector(WaitForCredentialDialog) withObject:nil waitUntilDone:YES];
            switch (DialogResult)
            {
                case 1:
                {
                    NSString *user = [self.credPrompt.usernameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    NSString *pass = [self.credPrompt.passwordField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    
                    NSURLCredential *credential = [NSURLCredential credentialWithUser:user
                                                                             password:pass
                                                                          persistence:CredentialsPresistance];
                    [challenge.sender useCredential:credential forAuthenticationChallenge:challenge];
                    break;
                }
                    
                default: 
                {
                    [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
                    break; 
                }
            }
            [DialogLock unlock];
        } else {
            [challenge.sender cancelAuthenticationChallenge:challenge];
        }
}

- (void)connection:(NSURLConnection *)connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [self.client URLProtocol:self didCancelAuthenticationChallenge:challenge];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse{
	if (cachedResponse)
	{
		[[self client] URLProtocol:self cachedResponseIsValid:cachedResponse];
	}
	return cachedResponse;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    if (self.URLConnection != connection)
        return;
    
    [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (self.URLConnection != connection)
        return;
    [[self client] URLProtocol:self didLoadData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    if (self.URLConnection != connection)
        return;
    [self.client URLProtocol:self didFailWithError:error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    if (self.URLConnection != connection)
        return;
    [self.client URLProtocolDidFinishLoading:self];
}

#pragma mark - UI

- (void)promptForCert {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Untrusted server certificate", @"The cert the server provided is not trusted")
                                                    message:NSLocalizedString(@"Caution: use at own risk", @"Caution: use at own risk")
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Cancel", @"cancel")
                                          otherButtonTitles:NSLocalizedString(@"OK", @"ok"), nil];
    [alert show];
}

- (void) presentPromptWithName:(NSString *)username{
	self.credPrompt = [[SGCredentialsPrompt alloc] initWithUsername:username persistence:CredentialsPresistance];
    self.credPrompt.delegate = self;
    [self.credPrompt show];
}

- (void) WaitForCredentialDialog{
	NSDate*               LoopUntil;
	//****************************************************************************
	LoopUntil = [NSDate dateWithTimeIntervalSinceNow:0.1];
	while ((DialogResult==-1) && ([[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode beforeDate:LoopUntil]))
	{
		LoopUntil = [NSDate dateWithTimeIntervalSinceNow:0.1];
	}
	//****************************************************************************
}

//***************************************************************************
//
//                     UIAlertView Delegate
//
//***************************************************************************

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex{
	if (buttonIndex==1)
	{
		switch (self.credPrompt.rememberCredentials.selectedSegmentIndex) {
			case 0:
				CredentialsPresistance = NSURLCredentialPersistenceNone;
				break;
			case 1:
				CredentialsPresistance = NSURLCredentialPersistenceForSession;
				break;
			case 2:
				CredentialsPresistance = NSURLCredentialPersistencePermanent;
				break;
			default:
				CredentialsPresistance = NSURLCredentialPersistenceForSession;
				break;
		}
		[VariableLock lock];
		DefaultCredentialPersistence = CredentialsPresistance;
		[VariableLock unlock];
		DialogResult  = 1;
	}
	if (buttonIndex==0)
	{
		DialogResult = 0;
	}
	
}

@end
