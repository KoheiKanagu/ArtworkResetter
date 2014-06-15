//
//  MainWindowController.m
//  ArtworkReset
//
//  Created by Kohei on 2014/04/19.
//  Copyright (c) 2014年 KoheiKanagu. All rights reserved.
//

#import "MainWindowController.h"

@implementation MainWindowController

-(id)init
{
    self = [super initWithWindowNibName:@"MainMenu"];
    if(self){
        // Initialization code here.
        restoreImageFilePathArray = [[NSMutableArray alloc]init];
        backupFilePathArray = [[NSMutableArray alloc]init];
    }
    return self;
}


#pragma mark - restore

-(void)restoreArtwork
{
    if(![restoreImageFilePathArray count]){
        [self searchArtwork];
    }
    
    [progressBar setIndeterminate:NO];
    [stopButton setEnabled:YES];

    NSArray *restoreFilePathArray = [restoreImageFilePathArray copy];
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(3);

    for(int i=0; i<restoreFilePathArray.count; i++){
        NSString *imageFullPath = [NSString stringWithFormat:@"%@/ArtworkResetterBK.app%@", [artworkDirField stringValue], restoreFilePathArray[i]];
        NSString *mp3FullPath = [NSString stringWithFormat:@"%@%@", [mp3DirField stringValue], [[restoreFilePathArray[i] stringByDeletingPathExtension] stringByAppendingPathExtension:@"mp3"]];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^{
            @autoreleasepool{
                if(stopFlag){
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [restoreButton setEnabled:YES];
                        [stopButton setEnabled:NO];
                    });
                    return;
                }
                
                [self addImagePathOf:imageFullPath
                             mp3Path:mp3FullPath];
                
                NSLog(@"%@", restoreFilePathArray[i]);
                [restoreImageFilePathArray removeObject:restoreFilePathArray[i]];
                
                double p = 100-((double)restoreImageFilePathArray.count/(double)restoreFilePathArray.count)*100;
                [progressBar setDoubleValue:p];
            }
            dispatch_semaphore_signal(semaphore);
        });
        
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }
}

-(void)searchArtwork
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *path = [NSString stringWithFormat:@"%@/ArtworkResetterBK.app", [artworkDirField stringValue]];
    
    NSDirectoryEnumerator *dirEnum = [manager enumeratorAtPath:path];
    NSString *name;
    BOOL dir = NO;
    
    [progressBar setIndeterminate:YES];
    [progressBar startAnimation:self];
    
    while(name = [dirEnum nextObject]){
        NSString *fullPath = [NSString stringWithFormat:@"%@/%@", path, name];
        
        [manager fileExistsAtPath:fullPath isDirectory:&dir];
        
        if(!dir){
            if(![fullPath hasSuffix:@".DS_Store"]){
                NSString *imagePath = [fullPath substringFromIndex:[path length]];
                [restoreImageFilePathArray addObject:imagePath];
            }else if([fullPath hasSuffix:@".DS_Store"]){
                NSLog(@"%@", fullPath);
                [[NSFileManager defaultManager] removeItemAtPath:fullPath
                                                           error:nil];
            }
        }
    }

    if(![restoreImageFilePathArray count]){
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAlert *alert = [NSAlert alertWithMessageText:@"確認"
                                             defaultButton:@"閉じる"
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:@"アートワークが１つも存在しませんでした"];
            [alert beginSheetModalForWindow:self.window
                          completionHandler:nil];
        });
    }
    [progressBar stopAnimation:self];
    [progressBar setIndeterminate:NO];
}

-(void)addImagePathOf:(NSString *)imagePath mp3Path:(NSString *)mp3Path
{
    ID3v2_tag *tag = load_tag([mp3Path UTF8String]);

    if(tag == NULL)
    {
        tag = new_tag();
    }
    
    ID3v2_frame *frame = tag_get_album_cover(tag);
    if(frame){
        NSLog(@"Skip : %@", imagePath);
        NSString *owner = [NSString stringWithFormat:@"%@/ArtworkResetterBK.app", [artworkDirField stringValue]];
        NSString *path = [imagePath substringFromIndex:[owner length]];
        NSString *newFullPath = [NSString stringWithFormat:@"%@/ArtworkResetterBK_Done.app%@", [artworkDirField stringValue], path];
        NSString *newDir = [newFullPath stringByDeletingLastPathComponent];
        
        NSError *error;
        BOOL result = [[NSFileManager defaultManager] createDirectoryAtPath:newDir
                                               withIntermediateDirectories:YES
                                                                attributes:nil
                                                                     error:&error];
        if(!result){
            NSLog(@"error");
        }
        
        result = [[NSFileManager defaultManager] moveItemAtPath:imagePath
                                                         toPath:newFullPath
                                                          error:&error];
        if(!result){
            NSLog(@"error");
        }
        
        return;
    }
    
    NSData *imageData = [NSData dataWithContentsOfFile:imagePath];
    char *minetype = get_mime_type_from_filename([imagePath UTF8String]);
    
    tag_set_album_cover_from_bytes((char *)[imageData bytes], minetype, (int)[imageData length], tag);

    dispatch_async(dispatch_get_main_queue(), ^{
        [artworkView setImage:[[NSImage alloc] initWithData:imageData]];
        [urlTextField setStringValue:[mp3Path lastPathComponent]];
    });

    set_tag([mp3Path UTF8String], tag);
}







#pragma mark - Backup

-(void)backupArtwork
{
    if(![backupFilePathArray count]){
        [self searchMusics];
    }
    if([backupFilePathArray count]){
        [stopButton setEnabled:YES];
        if([self exportArtwork]){
            return;
        }
    }
    
    [artworkDirField setEnabled:YES];
    [mp3DirField setEnabled:YES];
    [backupButton setEnabled:YES];
    [restoreButton setEnabled:YES];
    [stopButton setEnabled:NO];
}

-(BOOL)checkMusic:(NSString *)path
{
    NSArray *array = @[@".mp3",
                       @".MP3"
                       ];
    for(NSString *string in array){
        if([path hasSuffix:string]){
            return YES;
        }
    }
    return NO;
}

-(void)searchMusics
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *dirEnum = [manager enumeratorAtPath:[mp3DirField stringValue]];
    NSString *name;
    BOOL dir = NO;
    
    [progressBar setIndeterminate:YES];
    [progressBar startAnimation:self];
    
    while(name = [dirEnum nextObject]){
        NSString *mp3FullPath = [NSString stringWithFormat:@"%@/%@", [mp3DirField stringValue], name];
        [manager fileExistsAtPath:mp3FullPath isDirectory:&dir];
        
        if(!dir){
            if([self checkMusic:mp3FullPath]){
                [urlTextField setStringValue:[name lastPathComponent]];
                
                NSString *savedArtDir = [NSString stringWithFormat:@"%@/ArtworkResetterBK.app/%@", [artworkDirField stringValue], name];
                
                NSDirectoryEnumerator *artDirEnum = [manager enumeratorAtPath:savedArtDir];
                NSString *artName;
                BOOL saved = NO;
                
                while(artName = [artDirEnum nextObject]){
                    artName = [artName stringByDeletingPathExtension];
                    NSString *savedFileName = [[mp3FullPath lastPathComponent] stringByDeletingPathExtension];
                    if([artName isEqualToString:savedFileName]){
                        NSLog(@"haved : %@", [mp3FullPath lastPathComponent]);
                        saved = YES;
                        break;
                    }
                }
                if(!saved){
                    [backupFilePathArray addObject:name];
                }
                
                
                
            }else{
                if(![mp3FullPath hasSuffix:@".DS_Store"]){
                    NSLog(@"Non Supported File : %@", [mp3FullPath lastPathComponent]);
                }else if([mp3FullPath hasSuffix:@".DS_Store"]){
                    NSLog(@"%@", mp3FullPath);
                    [[NSFileManager defaultManager] removeItemAtPath:mp3FullPath
                                                               error:nil];
                    
                }
            }
        }
    }
    if(![backupFilePathArray count]){
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAlert *alert = [NSAlert alertWithMessageText:@"確認"
                                             defaultButton:@"閉じる"
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:@"mp3が１つも存在しませんでした"];
            [alert beginSheetModalForWindow:self.window
                          completionHandler:nil];
        });
    }
    
    
    [progressBar stopAnimation:self];
    [progressBar setIndeterminate:NO];
}

-(BOOL)exportArtwork
{
    int doned = 0;
    int count = (int)[backupFilePathArray count];
    
    [progressBar setIndeterminate:NO];
    
    NSArray *mp3FilePathArray = [backupFilePathArray copy];
    
    for(int i=0; i<[mp3FilePathArray count]; i++){
        NSString *mp3FilePath = [NSString stringWithFormat:@"%@/%@", [mp3DirField stringValue], mp3FilePathArray[i]];
        
        if(stopFlag){
            dispatch_async(dispatch_get_main_queue(), ^{
                [backupButton setEnabled:YES];
                [stopButton setEnabled:NO];
            });
            return YES;
        }
        double p = ((double)doned/(double)count)*100;
        [progressBar setDoubleValue:p];
        
        NSString *artworkPath = [NSString stringWithFormat:@"%@/ArtworkResetterBK.app/%@", [artworkDirField stringValue], mp3FilePathArray[i]];
        
        if([[NSFileManager defaultManager] fileExistsAtPath:mp3FilePath]){
            @autoreleasepool{
                [self exportImageTo:artworkPath sourceFilePath:mp3FilePath];
                [backupFilePathArray removeObject:mp3FilePath];
            }
            doned++;
            
        }else{
            NSLog(@"Non File : %@", [mp3FilePathArray[i] lastPathComponent]);
        }
    }
    [progressBar setDoubleValue:100];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [NSAlert alertWithMessageText:@"確認"
                                         defaultButton:@"閉じる"
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"バックアップが完了しました"];
        [alert beginSheetModalForWindow:self.window
                      completionHandler:nil];
    });
    return NO;
}





-(void)exportImageTo:(NSString *)exportPath sourceFilePath:(NSString *)filePath
{
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:filePath]
                                            options:nil];
    NSArray *artworks = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata
                                                       withKey:AVMetadataCommonKeyArtwork
                                                      keySpace:AVMetadataKeySpaceCommon];
    for(AVMetadataItem *item in artworks){
        if([item.keySpace isEqualToString:AVMetadataKeySpaceID3]){
            NSDictionary *dic = [item.value copyWithZone:nil];
            NSImage *image = [[NSImage alloc]initWithData:[dic objectForKey:@"data"]];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [artworkView setImage:image];
                [urlTextField setStringValue:[filePath lastPathComponent]];
            });
        
            NSString *extension;
            NSData *data = [self convertImageToData:image
                                               MIME:[dic objectForKey:@"MIME"]
                                           filePath:filePath
                                          extension:&extension];
            
            exportPath = [[exportPath stringByDeletingPathExtension] stringByAppendingPathExtension:extension];
            
            if([[NSFileManager defaultManager] fileExistsAtPath:exportPath]){
                NSLog(@"スキップ : %@", exportPath);
                return;
            }
            
            NSString *saveDir = [exportPath stringByDeletingLastPathComponent];
            if (![[NSFileManager defaultManager] fileExistsAtPath:saveDir isDirectory:nil]){
                NSError *error;
                    BOOL makeDir = [[NSFileManager defaultManager] createDirectoryAtPath:saveDir
                                                             withIntermediateDirectories:YES
                                                                              attributes:nil
                                                                                   error:&error];
                    if(!makeDir){
                        NSLog(@"%@", error.description);
                        stopFlag = YES;
                        return;
                    }
            }
            [data writeToFile:exportPath
                   atomically:YES];
        }
    }
}


-(NSData *)convertImageToData:(NSImage *)image MIME:(NSString *)mime filePath:(NSString *)filePath extension:(NSString **)extension
{
    NSData *data;
    NSBitmapImageRep *imgRep = [[image representations] objectAtIndex:0];
    
    if([mime isEqualToString:@"image/jpeg"] || [mime isEqualToString:@"JPG"] || [mime isEqualToString:@"image/jpg"]){
    }else{
        NSLog(@"%@ : %@", mime, filePath);
    }
    
    if([mime isEqualToString:@"image/jpeg"] || [mime isEqualToString:@"JPG"] || [mime isEqualToString:@"image/jpg"]){
        data = [imgRep representationUsingType:NSJPEGFileType
                                    properties:nil];
        *extension = @"jpg";
    }else if([mime isEqualToString:@"image/png"] || [mime isEqualToString:@"PNG"]){
        data = [imgRep representationUsingType:NSPNGFileType
                                    properties:nil];
        *extension = @"png";
        
    }else if([mime isEqualToString:@"image/bmp"] || [mime isEqualToString:@"BMP"]){
        data = [imgRep representationUsingType:NSBMPFileType
                                    properties:nil];
        *extension = @"bmp";
        
    }else if([mime isEqualToString:@"image/gif"] || [mime isEqualToString:@"GIF"]){
        data = [imgRep representationUsingType:NSGIFFileType
                                    properties:nil];
        *extension = @"gif";
        
    }else if([mime isEqualToString:@"image/tiff"] || [mime isEqualToString:@"TIF"] || [mime isEqualToString:@"TIFF"]){
        data = [imgRep representationUsingType:NSTIFFCompressionNone
                                    properties:nil];
        *extension = @"tif";
    }
    return data;
}








#pragma mark - Action


-(BOOL)dirCheck
{
    BOOL check;
    NSString *newPath = [self makeNewDir:[mp3DirField stringValue]
                                   check:&check];
    if(check){
        [mp3DirField setStringValue:newPath];
    }else{
        return NO;
    }
    
    newPath = [self makeNewDir:[artworkDirField stringValue]
                         check:&check];
    if(check){
        [artworkDirField setStringValue:newPath];
    }else{
        return NO;
    }
    [artworkDirField setEnabled:NO];
    [mp3DirField setEnabled:NO];
    [backupButton setEnabled:NO];
    [restoreButton setEnabled:NO];
    [stopButton setEnabled:NO];
    
    stopFlag = NO;
    return YES;
}

-(NSString *)makeNewDir:(NSString *)dirPath check:(BOOL *)check
{
    NSArray *path = [dirPath pathComponents];
    
    if([path count]){
        NSString *newFilePath = @"";
        for(int i=0; i<[path count]; i++){
            if(![path[i] hasSuffix:@"/"]){
                newFilePath = [NSString stringWithFormat:@"%@/%@", newFilePath, path[i]];
            }
        }
        if(![[newFilePath pathExtension] length]){
            *check = YES;
            return newFilePath;
        }
    }
    *check = NO;
    return nil;
}



-(IBAction)stopButtonAction:(id)sender
{
    if(!stopFlag){
        stopFlag = YES;
    }
}

-(IBAction)restoreButtonAction:(id)sender
{
    if([self dirCheck]){
        [NSThread detachNewThreadSelector:@selector(restoreArtwork)
                                 toTarget:self
                               withObject:nil];
    }else{
        NSAlert *alert = [NSAlert alertWithMessageText:@"確認"
                                         defaultButton:@"閉じる"
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"内容に不備あり"];
        
        [alert beginSheetModalForWindow:self.window
                      completionHandler:^(NSModalResponse returnCode) {
                          NSLog(@"%ld", (long)returnCode);
                      }];
    }
}

-(IBAction)backupButtonAction:(id)sender
{
    if([self dirCheck]){
        [NSThread detachNewThreadSelector:@selector(backupArtwork)
                                 toTarget:self
                               withObject:nil];
    }else{
        NSAlert *alert = [NSAlert alertWithMessageText:@"確認"
                                         defaultButton:@"閉じる"
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"内容に不備あり"];
        
        [alert beginSheetModalForWindow:self.window
                      completionHandler:^(NSModalResponse returnCode) {
                          NSLog(@"%ld", (long)returnCode);
                      }];
    }
}

@end
