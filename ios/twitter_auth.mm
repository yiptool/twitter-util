/* vim: set ai noet ts=4 sw=4 tw=115: */
//
// Copyright (c) 2014 Nikolay Zapolnov (zapolnov@gmail.com).
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
#import "twitter_auth.h"
#import <yip-imports/ios/i18n.h>

@interface NZTwitterAuthHelper : NSObject<UIActionSheetDelegate>
@property (nonatomic, copy, readonly) void (^ callback)(TwitterAuthResult, NSDictionary *);
@property (nonatomic, retain, readonly) NSArray * accounts;
@property (nonatomic, retain, readonly) TWAPIManager * twitterManager;
@end

@implementation NZTwitterAuthHelper

@synthesize callback;
@synthesize accounts;
@synthesize twitterManager;

-(id)initWithAccounts:(NSArray *)accountArray twitterManager:(TWAPIManager *)manager
	callback:(void (^)(TwitterAuthResult, NSDictionary *))cb
{
	self = [super init];
	if (self)
	{
		accounts = [accountArray retain];
		twitterManager = [manager retain];
		callback = [cb copy];
	}
	return self;
}

-(void)dealloc
{
	[accounts release];
	accounts = nil;

	[twitterManager release];
	twitterManager = nil;

	[callback release];
	callback = nil;

	[super dealloc];
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(int)index
{
	actionSheet.delegate = nil;
	[self autorelease];

	if (actionSheet && index == actionSheet.cancelButtonIndex)
	{
		if (callback)
			callback(TWITTER_AUTH_CANCELLED, nil);
		return;
	}

	ACAccount * account = accounts[index];
	[twitterManager performReverseAuthForAccount:account withHandler:^(NSData * data, NSError * error) {
		if (!data)
		{
			NSLog(@"Unable to perform twitter auth: %@", error);
			if (callback)
				callback(TWITTER_AUTH_FAILED, nil);
			return;
		}

		NSString * response = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];

		NSMutableDictionary * params = [[[NSMutableDictionary alloc] init] autorelease];
		for (NSString * line in [response componentsSeparatedByString:@"&"])
		{
			NSArray * keyValue = [line componentsSeparatedByString:@"="];
			[params setObject:keyValue[1] forKey:keyValue[0]];
		}

		if (callback)
			callback(TWITTER_AUTH_SUCCESS, params);
	}];
}

@end

void twitterAuth(UIView * parentView, TWAPIManager * manager, ACAccountStore * accStore,
	void (^ callback)(TwitterAuthResult, NSDictionary *))
{
	ACAccountType * twitterType = [accStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
	[accStore requestAccessToAccountsWithType:twitterType options:NULL completion:^(BOOL ok, NSError * error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			if (!ok)
			{
				NSLog(@"Unable to get access to twitter accounts: %@", error);
				if (callback)
					callback(TWITTER_AUTH_DENIED, nil);
				return;
			}

			NSArray * accounts = [accStore accountsWithAccountType:twitterType];
			if (accounts.count == 0)
			{
				if (callback)
					callback(TWITTER_AUTH_NO_ACCOUNTS, nil);
				return;
			}

			NZTwitterAuthHelper * helper = [[NZTwitterAuthHelper alloc]
				initWithAccounts:accounts twitterManager:manager callback:callback];

			if (!helper)
			{
				if (callback)
					callback(TWITTER_AUTH_FAILED, nil);
				return;
			}

			if (accounts.count == 1)
			{
				[helper actionSheet:nil clickedButtonAtIndex:0];
				return;
			}

			UIActionSheet * actionSheet = [[[UIActionSheet alloc] init] autorelease];
			if (!actionSheet)
			{
				[helper release];
				if (callback)
					callback(TWITTER_AUTH_FAILED, nil);
				return;
			}

			for (ACAccount * account in accounts)
				[actionSheet addButtonWithTitle:account.accountDescription];

			actionSheet.cancelButtonIndex = [actionSheet addButtonWithTitle:iosTranslationForCancel()];

			actionSheet.delegate = helper;
			[actionSheet showFromRect:parentView.bounds inView:parentView animated:YES];
		});
	}];
}
