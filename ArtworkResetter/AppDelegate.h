//
//  AppDelegate.h
//  ArtworkReset
//
//  Created by Kohei on 2014/04/19.
//  Copyright (c) 2014年 KoheiKanagu. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MainWindowController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    MainWindowController *myMainWindow;
}

@property (assign) IBOutlet NSWindow *window;

@end
