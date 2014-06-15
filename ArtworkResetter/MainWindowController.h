//
//  MainWindowController.h
//  ArtworkReset
//
//  Created by Kohei on 2014/04/19.
//  Copyright (c) 2014年 KoheiKanagu. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#include "id3v2lib.h"

@interface MainWindowController : NSWindowController
{
    IBOutlet NSTextField *urlTextField;
    IBOutlet NSTextField *mp3DirField;
    IBOutlet NSTextField *artworkDirField;
    IBOutlet NSImageView *artworkView;
    IBOutlet NSProgressIndicator *progressBar;
    
    IBOutlet NSButton *stopButton;
    IBOutlet NSButton *restoreButton;
    IBOutlet NSButton *backupButton;
    
    NSMutableArray *restoreImageFilePathArray;
    NSMutableArray *backupFilePathArray;
    
    BOOL stopFlag;
}

@end
