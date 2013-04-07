/**
 * benCoding.Zip Project
 * Copyright (c) 2009-2013 by Ben Bahrenburg. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#import "BencodingZipModule.h"
#import "TiBase.h"
#import "TiHost.h"
#import "TiUtils.h"
#import "ZipArchive.h"

// Define the interval at which the autorelease pool will be drained. This value can be tuned to accommodate
// optimal memory usage. If memory needs to be released more frequently then set to a lower value; less
// frequently then set to a higher value;
static const int kAutoReleaseInterval = 100;

@implementation BencodingZipModule

#pragma mark Internal

// this is generated for your module, please do not change it
-(id)moduleGUID
{
	return @"e8911ad6-4453-4e77-b8cd-8c6e72f52212";
}

// this is generated for your module, please do not change it
-(NSString*)moduleId
{
	return @"bencoding.zip";
}

#pragma mark Lifecycle

-(void)startup
{
	// this method is called when the module is first loaded
	// you *must* call the superclass
	[super startup];
	
	//NSLog(@"[INFO] %@ loaded",self);
}

-(void)shutdown:(id)sender
{
	// this method is called when the module is being unloaded
	// typically this is during shutdown. make sure you don't do too
	// much processing here or the app will be quit forceably
	
	// you *must* call the superclass
	[super shutdown:sender];
}

#pragma mark Cleanup 

-(void)dealloc
{
	// release any resources that have been retained by the module
	[super dealloc];
}

#pragma mark Internal Memory Management

-(void)didReceiveMemoryWarning:(NSNotification*)notification
{
	// optionally release any resources that can be dynamically
	// reloaded once memory is available - such as caches
	[super didReceiveMemoryWarning:notification];
}

#pragma Public APIs

-(NSString*)getNormalizedPath:(NSString*)source
{
	// NOTE: File paths may contain URL prefix as of release 1.7 of the SDK
	if ([source hasPrefix:@"file:/"]) {
		NSURL* url = [NSURL URLWithString:source];
		return [url path];
	}
    
	// NOTE: Here is where you can perform any other processing needed to
	// convert the source path. For example, if you need to handle
	// tilde, then add the call to stringByExpandingTildeInPath
    
	return source;
}

#pragma mark Public APIs

-(void)unzip:(id)args
{
    ENSURE_SINGLE_ARG(args,NSDictionary);
    ENSURE_UI_THREAD(unzip,args);
    
    BOOL hasPassword = NO;
    BOOL success = NO;
    NSString *statusDetails = @"none";
    NSString *password =@"blank";
    NSString* folderLocationIn = [args objectForKey:@"outputDirectory"];
	NSString* folderLocation = [self getNormalizedPath:folderLocationIn];
	if (folderLocation == nil) {
		NSLog(@"[ERROR] %@",[NSString stringWithFormat:@"Invalid folder location [%@]", folderLocationIn]);
		return;
	}
    
    if (![args objectForKey:@"completed"]) {
		NSLog(@"[ERROR] completed callback method is required");
		return;
	}

    // Get and validate the zip file name
	NSString* zipFileNameIn = [args objectForKey:@"zip"];
	NSString* zipFileName = [self getNormalizedPath:zipFileNameIn];
	if (zipFileName == nil) {
		NSLog(@"[ERROR] %@",[NSString stringWithFormat:@"Invalid archive file name [%@]", zipFileNameIn]);
		return;
	}
    
	BOOL overWrite = [TiUtils boolValue:[args objectForKey:@"overwrite"] def:NO];

    if ([args objectForKey:@"password"]) {
        password = [args objectForKey:@"password"];
        hasPassword = YES;
	}
    
    KrollCallback *callback = [[args objectForKey:@"completed"] retain];
	ENSURE_TYPE(callback,KrollCallback);
        
	ZipArchive* zip = [[ZipArchive alloc] init];

    if(hasPassword)
    {
        success = [zip UnzipOpenFile:zipFileName Password:password];
    }
    else
    {
        success = [zip UnzipOpenFile:zipFileName];
    }
    
	if (success)
    {
		// We have successfully opened the zip file
		if ([zip UnzipFileTo:folderLocation overWrite:overWrite])
        {
            statusDetails = [NSString stringWithFormat:@"File [%@] successfully extracted", zipFileName];
		}
		else
        {
            success = NO;
			statusDetails = [NSString stringWithFormat:@"Failed to extract archive file [%@]", zipFileName];
		}
        
		[zip UnzipCloseFile];
	}
	else {
		statusDetails = [NSString stringWithFormat:@"Unable to open archive file [%@]", zipFileName];
	}
    
    NSLog(@"[INFO] %@",statusDetails);
    
	[zip release];

    if(callback != nil ){
        NSMutableDictionary *event = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                               NUMBOOL(success),@"success",
                               statusDetails,@"message",
                               zipFileName,@"zip",
                               nil];
        
        //If successful, include the output directory
        if(success){
            [event setObject:folderLocation forKey:@"outputDirectory"];
        }
        
        //outputDirectory
        [self _fireEventToListener:@"completed" withObject:event listener:callback thisObject:nil];
        
        [callback autorelease];
    }
    
}


// Create a zip file
-(void)zip:(id)args
{
    
    ENSURE_SINGLE_ARG(args,NSDictionary);
    ENSURE_UI_THREAD(zip,args);
        
    BOOL hasPassword = NO;
    BOOL success = NO;
    NSString *statusDetails = @"none";
    NSString *password =@"blank";
    NSString* zipFileNameIn = [args objectForKey:@"zip"];
	NSString* zipFileName = [self getNormalizedPath:zipFileNameIn];
	if (zipFileName == nil) {
		NSLog(@"[ERROR] %@", [NSString stringWithFormat:@"Invalid archive file name [%@]", zipFileNameIn]);
		return;
	}
    
    // Get the array of files to add to the zip archive
    NSArray* fileArray = [args objectForKey:@"files"];
    ENSURE_ARRAY(fileArray);
    
    if ([fileArray count]==0) {
		NSLog(@"[ERROR] at least 1 file is needed to add to the zip file");
		return;
	}
    
    if (![args objectForKey:@"completed"]) {
		NSLog(@"[ERROR] completed callback method is required");
		return;
	}
    
    KrollCallback *callback = [[args objectForKey:@"completed"] retain];
	ENSURE_TYPE(callback,KrollCallback);
    
    if ([args objectForKey:@"password"]) {
        password = [args objectForKey:@"password"];
        hasPassword = YES;
	}

    //If file exists, remove it
    if([[NSFileManager defaultManager] fileExistsAtPath:zipFileName])
    {
        NSLog(@"File already exists, removing");
        NSError *error;
        BOOL deleted = [[NSFileManager defaultManager] removeItemAtPath:zipFileName error:&error];
        if (!deleted) NSLog(@"Error: %@", [error localizedDescription]);
    }
    
    ZipArchive* zip = [[ZipArchive alloc] init];
    if(hasPassword)
    {
        success = [zip CreateZipFile2:zipFileName Password:password];
    }
    else
    {
        success = [zip CreateZipFile2:zipFileName];
    }
	if ([zip CreateZipFile2:zipFileName])
    {
		int n, cnt, successCount=0;
		NSAutoreleasePool* pool = nil;
		for (n=0,cnt=[fileArray count]; n<cnt; ++n) {
			if ((n % kAutoReleaseInterval) == 0) {
				[pool drain];
				pool = [[NSAutoreleasePool alloc] init];
			}
			
			// Get and validate the next file to add
			NSString* filePathIn = [fileArray objectAtIndex:n];
			NSString* filePath = [self getNormalizedPath:filePathIn];
			if (filePath == nil) {
				NSLog(@"[ERROR] File path [%@] is invalid", filePathIn);
			}
			else if ([zip addFileToZip:filePath newname:[filePath lastPathComponent]]) {
				successCount++;
			}
			else {
				NSLog(@"[ERROR] Failed to add file [%@] to archive", filePath);
			}
		}
		[pool drain];
		[zip CloseZipFile2];
        
        statusDetails = [NSString stringWithFormat:@"zip file: %@ created with %d/%d files", zipFileName, successCount, cnt];
		NSLog(@"[INFO] %@",statusDetails);
	}
	else
    {
		statusDetails = [NSString stringWithFormat:@"Unable to create archive file [%@]", zipFileName];
		NSLog(@"[ERROR] %@", statusDetails);
	}
	
    if(callback != nil ){
        NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                               NUMBOOL(success),@"success",
                               statusDetails,@"message",
                               zipFileName,@"zip",
                               nil];
        [self _fireEventToListener:@"completed" withObject:event listener:callback thisObject:nil];
        [callback autorelease];
    }
    
    [zip autorelease];
}
@end
