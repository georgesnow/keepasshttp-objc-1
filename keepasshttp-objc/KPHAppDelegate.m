//
//  KPHAppDelegate.m
//  keepasshttp-objc
//
//  Created by Tim Kretschmer on 4/1/14.
//  Copyright (c) 2014 xbigtk13x. All rights reserved.
//

#import "KPHAppDelegate.h"

@implementation KPHAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.kphServer = [KPHServer new];
    [self.kphServer startWithClient:[KPHKeePassClientMock new]];
}

@end
