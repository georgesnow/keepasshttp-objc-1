//
//  KPHSetLoginHandler.m
//  keepasshttp-objc
//
//  Created by Tim Kretschmer on 4/5/14.
//  Copyright (c) 2014 xbigtk13x. All rights reserved.
//

#import "KPHSetLoginHandler.h"

@implementation KPHSetLoginHandler
- (void) handle: (KPHRequest*)request response:(KPHResponse*)response aes:(KPHAes*)aes
{
    NSString* url = [KPHCore cryptoTransform:request.Url base64in:true base64out:false aes:aes encrypt:false];
    NSString* urlHost = [KPHUtil getHost:url];
    
    
    NSString* username = [KPHCore cryptoTransform:request.Login base64in:true base64out:false aes:aes encrypt:false];
    NSString* password = [KPHCore cryptoTransform:request.Password base64in:true base64out:false aes:aes encrypt:false];
    
    if (request.Uuid != nil)
    {
        NSString* decryptedUuid = [KPHCore cryptoTransform:request.Uuid base64in:true base64out:false aes:aes encrypt:false];
        NSData* uuidData = [KPHSystemConvert fromUTF8String:decryptedUuid];
        NSUUID* uuid = [[NSUUID alloc] initWithUUIDBytes:uuidData.bytes];
        [self updateEntry:uuid username:username password:password formHost:urlHost requestId:request.Id];
    }
    else
    {
        [self createEntry:username password:password urlHost:urlHost url:url request:request aes:aes];
    }
    
    response.Success = true;
    response.Id = request.Id;
    [KPHProtocol setResponseVerifier:response aes:aes];
}
- (BOOL) updateEntry:(NSUUID*) uuid username:(NSString*) username password:(NSString*) password formHost:(NSString*) formHost requestId:(NSString*) requestId
{
    KPHPwEntry* entry = nil;
    
    KPHConfigOpt* configOpt = [KPHUtil globalVars].ConfigOpt;
    if (configOpt.SearchInAllOpenedDatabases)
    {
        entry = [[KPHUtil client] findEntryInAnyDatabase:uuid searchRecursive:true];
    }
    else
    {
        entry = [[[KPHUtil client] rootGroup] findEntry:uuid searchRecursive:true];
    }
    
    if (entry == nil)
    {
        return false;
    }
    
    NSArray* up = [KPHCore getUserPass:entry];
    NSString* u = [up objectAtIndex:0];
    NSString* p = [up objectAtIndex:1];
    
    if (![u isEqual: username] || ![p isEqual:password])
    {
        bool allowUpdate = configOpt.AlwaysAllowUpdates;
        
        if (!allowUpdate)
        {
            NSString* message = [[NSString alloc] initWithFormat:@"Do you want to update the information in %@ - %@?", formHost, u ];
            allowUpdate = [[KPHUtil client] promptUserForEntryUpdate:message title:@"Update Entry"];
        }
        
        if (allowUpdate)
        {
            //PwObjectList<PwEntry> m_vHistory = entry.History.CloneDeep();
            //entry.History = m_vHistory;
            //entry.CreateBackup(null);
            
            entry.Strings[[KPHUtil globalVars].PwDefs.UserNameField] = username;
            entry.Strings[[KPHUtil globalVars].PwDefs.PasswordField] = password;
            [[KPHUtil client] createOrUpdateEntry:entry];
            [[KPHUtil client] refreshUI];
            
            return true;
        }
    }
    
    return false;
}

- (BOOL) createEntry: (NSString*) username password:(NSString*) password urlHost:(NSString*) urlHost url:(NSString*) url request:(KPHRequest*) request aes:(KPHAes*) aes
{
    NSString* realm = nil;
    if (request.Realm != nil)
    {
        realm = [KPHCore cryptoTransform:request.Realm base64in:true base64out:false aes:aes encrypt:false];
    }
    
    KPHPwGroup* root = [[KPHUtil client] rootGroup];
    KPHPwGroup* group = [[KPHUtil client] findGroup:[KPHUtil globalVars].KEEPASSHTTP_GROUP_NAME];
    if (group == nil)
    {
        group = [[KPHPwGroup alloc] initWithParams:true setTimes:true name:[KPHUtil globalVars].KEEPASSHTTP_GROUP_NAME pwIcon:[KPHUtil globalVars].KEEPASSHTTP_GROUP_ICON];
        [root addGroup:group takeOwnership:true];
        [[KPHUtil client] refreshUI];
    }
    
    NSString* submithost = nil;
    if (request.SubmitUrl != nil)
    {
        submithost = [KPHCore cryptoTransform:request.SubmitUrl base64in:true base64out:false aes:aes encrypt:false];
    }
    NSString* baseUrl = url;
    // index bigger than https:// <-- this slash
    NSUInteger lastSlashLocation = [baseUrl rangeOfString:@"/" options:NSBackwardsSearch].location;
    if (lastSlashLocation > 9)
    {
        baseUrl = [baseUrl substringWithRange:NSMakeRange(0, lastSlashLocation+1)];
    }
    
    KPHPwEntry* entry = [[KPHPwEntry alloc] init:true setTimes:true];
    entry.Strings[[KPHUtil globalVars].PwDefs.TitleField] = urlHost;
    entry.Strings[[KPHUtil globalVars].PwDefs.UserNameField] = username;
    entry.Strings[[KPHUtil globalVars].PwDefs.PasswordField] = password;
    entry.Strings[[KPHUtil globalVars].PwDefs.UrlField] = baseUrl;
    
    if ((submithost != nil && ![urlHost isEqual:submithost]) || realm != nil)
    {
        KPHEntryConfig* config = [KPHEntryConfig new];
        if (submithost != nil)
            [config.Allow addObject:submithost];
        if (realm != nil)
            config.Realm = realm;
        
        entry.Strings[[KPHUtil globalVars].KEEPASSHTTP_NAME] = [config toJson];
    }
    
    [group addEntry:entry takeOwnership:true];
    [[KPHUtil client] createOrUpdateGroup:root];
    [[KPHUtil client] refreshUI];
    
    return true;
}
@end
