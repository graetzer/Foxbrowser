# SGShareKit

iOS sharing view. Supporting for iOS 6 Social.framework, Twitter.framework, MessageUI.framework

Heavily based on https://github.com/levey/LeveyPopListView

### Example Usage

SGActivityView works like an UIAlertView. For each instance, a new UIWindow is created on top of the main window
SGActivityView does not interfere with your view hierarchy. Just make sure the rootViewController is properly set.
The API itself is inspired by UIActivityViewController, but works on iOS 5+ 

In some cases you should be able to reuse your existing UIActivity subclasses by replacing the superclass with SGActivity.

	#import "SGActivityView.h"
	
	// ...
	NSString *text = @"Hello world";
	NSURL *url = [NSURL URLWithString:@"http://google.com"];
	NSURL *mail = [NSURL URLWithString:@"mailto:simon@graetzer.org"];
	SGActivityView *activity = [[SGActivityView alloc] initWithActivityItems:@[text, url, mail]
	                                                   applicationActivities:nil];
	[activity show];
	

![Logo](https://raw.github.com/graetzer/SGShareKit/master/Demo/screenshot.png)

### License

	Copyright 2013 Simon Peter Grätzer
	
	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at
	
		http://www.apache.org/licenses/LICENSE-2.0
		
	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.
	