//
//  main.m
//  hotkeyd
//
//  Created by Samantha Marshall on 11/14/15.
//  Copyright © 2015 Samantha Marshall. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

#pragma mark -
#pragma mark Variables

static UInt32 hotKeyId;
static NSMapTable *hotKeyInternalMap;
static NSMapTable *keyTranslationMap;
static NSHashTable *hotKeyRefs;

#pragma mark -
#pragma mark Functions

NSArray * PerformSetup(NSString *path) {
	NSArray *settings = @[];
	if ([[NSFileManager defaultManager] fileExistsAtPath:path] == NO) {
		[[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
		
		NSArray *defaultSettings = @[
										@{
											@"key": @"grave",
											@"modifiers": @[ @"control" ],
											@"script": @"tell application \"Terminal\" to activate",
										 },
										];
		NSData *serializedSettingsData = [NSPropertyListSerialization dataWithPropertyList:defaultSettings format:NSPropertyListXMLFormat_v1_0 options:0 error:nil];
		
		BOOL fileCreated = [[NSFileManager defaultManager] createFileAtPath:path contents:serializedSettingsData attributes:nil];
		
		if (fileCreated == NO) {
			NSLog(@"Error in writing default settings!");
		}
	}
	
	NSData *settingsData = [NSData dataWithContentsOfFile:path];
		
	settings = [NSPropertyListSerialization propertyListWithData:settingsData options:0 format:nil error:nil];
	
	return settings;
}

OSStatus hotkeydHandler(EventHandlerCallRef nextHandler, EventRef theEvent, void *userData) {
	@autoreleasepool {
		EventHotKeyID hotKeyID;
		GetEventParameter(theEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(hotKeyID), NULL, &hotKeyID);
		
		uintptr_t keyID = (hotKeyID.id & 0xffffffff);
		void *value;
		NSMapMember(hotKeyInternalMap, (void *)keyID, NULL, &value);
		NSString *command = (__bridge id)value;
		
		if (command) {
			NSAppleScript *commandScript = [[NSAppleScript alloc] initWithSource:command];
			[commandScript executeAndReturnError:nil];
		}
	}
	
	return noErr;
}

void SetupKeyTranslation(void) {
	keyTranslationMap = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsObjectPersonality | NSPointerFunctionsStrongMemory) valueOptions:(NSPointerFunctionsIntegerPersonality | NSPointerFunctionsOpaqueMemory)];
	NSMapInsert(keyTranslationMap, @"return", (void *)kVK_Return);
	NSMapInsert(keyTranslationMap, @"tab", (void*)kVK_Tab);
	NSMapInsert(keyTranslationMap, @"space", (void*)kVK_Space);
	NSMapInsert(keyTranslationMap, @"delete", (void*)kVK_Delete);
	NSMapInsert(keyTranslationMap, @"grave", (void*)kVK_ANSI_Grave);
}


void RegisterHandler(void) {
	hotKeyId = 1; // identifier of the hotkey
	hotKeyInternalMap = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsIntegerPersonality | NSPointerFunctionsOpaqueMemory) valueOptions:(NSPointerFunctionsObjectPersonality | NSPointerFunctionsStrongMemory)];
	
	hotKeyRefs = [[NSHashTable alloc] initWithOptions:(NSPointerFunctionsOpaquePersonality | NSPointerFunctionsOpaqueMemory) capacity:0];
	
	SetupKeyTranslation();
	
	EventTypeSpec eventSpec = {
		.eventClass = kEventClassKeyboard,
		.eventKind = kEventHotKeyReleased
	};
	
	InstallApplicationEventHandler(&hotkeydHandler, 1, &eventSpec, NULL, NULL);
}

UInt32 ConvertModifiersToFlag(NSArray *modifiers) {
	UInt32 newFlags = 0;
	
	if ([modifiers containsObject:@"control"]) {
		newFlags |= controlKey;
	}
	
	if ([modifiers containsObject:@"cmd"]) {
		newFlags |= cmdKey;
	}
	
	if ([modifiers containsObject:@"shift"]) {
		newFlags |= shiftKey;
	}
	
	if ([modifiers containsObject:@"option"]) {
		newFlags |= optionKey;
	}
	
	if ([modifiers containsObject:@"caps"]) {
		newFlags |= alphaLock;
	}
	
	return newFlags;
}

UInt32 ConvertKeyToCode(NSString *key) {
	UInt32 keyCode = 0;
	
	void *value;
	NSMapMember(keyTranslationMap, (__bridge void *)key, NULL, &value);
	keyCode = ((uintptr_t)value & 0xffffffff);
	
	return keyCode;
}

void RegisterKey(NSDictionary *command) {
	UInt32 modifiers = ConvertModifiersToFlag(command[@"modifiers"]);
	
	EventHotKeyID keyID = {
		.signature = 'htk1',
		.id = hotKeyId
	};
	
	UInt32 keyCode = ConvertKeyToCode(command[@"key"]);
	
	EventHotKeyRef carbonHotKey;
	OSStatus err = RegisterEventHotKey(keyCode, modifiers, keyID, GetEventDispatcherTarget(), 0, &carbonHotKey);
	
	if (err == 0) {
		uintptr_t keyID = (hotKeyId & 0xffffffff);
		NSMapInsert(hotKeyInternalMap, (void *)keyID, (__bridge const void * _Nullable)(command[@"script"]));
		NSHashInsert(hotKeyRefs, (void *)carbonHotKey);
		hotKeyId += 1;
	}
}

#pragma mark -
#pragma mark Main

int main(int argc, const char * argv[]) {
	@autoreleasepool {
		NSString *defaultSearchPath = [@"~/Library/Application Support/hotkeyd/keys.plist" stringByExpandingTildeInPath];
		NSArray *keys = PerformSetup(defaultSearchPath);
		
		RegisterHandler();
		
		for (NSDictionary *command in keys) {
			RegisterKey(command);
		}
	}
    return NSApplicationMain(argc,  (const char **) argv);
}
