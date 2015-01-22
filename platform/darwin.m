#import <Foundation/NSArray.h>
#import <Foundation/Foundation.h>
#import <SystemConfiguration/SCPreferences.h>
#import <SystemConfiguration/SCNetworkConfiguration.h>

void togglePac(int onOff, const char* cPacUrl)
{
  NSString* pacUrl = [[NSString alloc] initWithCString: cPacUrl encoding:NSUTF8StringEncoding];
  BOOL success = FALSE;

  SCNetworkSetRef networkSetRef;
  CFArrayRef networkServicesArrayRef;
  SCNetworkServiceRef networkServiceRef;
  SCNetworkProtocolRef proxyProtocolRef;
  NSDictionary *oldPreferences;
  NSMutableDictionary *newPreferences;
  NSString *wantedHost;


  // Get System Preferences Lock
  SCPreferencesRef prefsRef = SCPreferencesCreate(NULL, CFSTR("org.getlantern.lantern"), NULL);

  if(prefsRef==NULL) {
    NSLog(@"Fail to obtain Preferences Ref!!");
    goto freePrefsRef;
  }

  success = SCPreferencesLock(prefsRef, TRUE);
  if (!success) {
    NSLog(@"Fail to obtain PreferencesLock");
    goto freePrefsRef;
  }

  // Get available network services
  networkSetRef = SCNetworkSetCopyCurrent(prefsRef);
  if(networkSetRef == NULL) {
    NSLog(@"Fail to get available network services");
    goto freeNetworkSetRef;
  }

  //Look up interface entry
  networkServicesArrayRef = SCNetworkSetCopyServices(networkSetRef);
  networkServiceRef = NULL;
  for (long i = 0; i < CFArrayGetCount(networkServicesArrayRef); i++) {
    networkServiceRef = CFArrayGetValueAtIndex(networkServicesArrayRef, i);

    // Get proxy protocol
    proxyProtocolRef = SCNetworkServiceCopyProtocol(networkServiceRef, kSCNetworkProtocolTypeProxies);
    if(proxyProtocolRef == NULL) {
      NSLog(@"Couldn't acquire copy of proxyProtocol");
      goto freeProxyProtocolRef;
    }

    oldPreferences = (__bridge NSDictionary*)SCNetworkProtocolGetConfiguration(proxyProtocolRef);
    newPreferences = [NSMutableDictionary dictionaryWithDictionary: oldPreferences];
    wantedHost = @"localhost";

    if(onOff == PAC_ON) {//Turn proxy configuration ON
      [newPreferences setValue: wantedHost forKey:(NSString*)kSCPropNetProxiesHTTPProxy];
      [newPreferences setValue:[NSNumber numberWithInt:1] forKey:(NSString*)kSCPropNetProxiesProxyAutoConfigEnable];
      [newPreferences setValue:pacUrl forKey:(NSString*)kSCPropNetProxiesProxyAutoConfigURLString];
      NSLog(@"Setting pac ON for device %@ with: %@",
          SCNetworkServiceGetName(networkServiceRef), newPreferences);
    } else {//Turn proxy configuration OFF
      [newPreferences setValue:[NSNumber numberWithInt:0] forKey:(NSString*)kSCPropNetProxiesProxyAutoConfigEnable];
      NSLog(@"Setting pac OFF for device %@", SCNetworkServiceGetName(networkServiceRef));
    }

    success = SCNetworkProtocolSetConfiguration(proxyProtocolRef, (__bridge CFDictionaryRef)newPreferences);
    if(!success) {
      NSLog(@"Failed to set Protocol Configuration");
      goto freeProxyProtocolRef;
    }

freeProxyProtocolRef:
    CFRelease(proxyProtocolRef);
  }

  success = SCPreferencesCommitChanges(prefsRef);
  if(!success) {
    NSLog(@"Failed to Commit Changes");
    goto freeNetworkServicesArrayRef;
  }

  success = SCPreferencesApplyChanges(prefsRef);
  if(!success) {
    NSLog(@"Failed to Apply Changes");
    goto freeNetworkServicesArrayRef;
  }
  //Free Resources
freeNetworkServicesArrayRef:
  CFRelease(networkServicesArrayRef);
freeNetworkSetRef:
  CFRelease(networkSetRef);
freePrefsRef:
  SCPreferencesUnlock(prefsRef);
  CFRelease(prefsRef);

  return;
}
