//
//  lldb.m
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 03/02/2024
//  Using Swift 5.0
//  Running on macOS 14.3
//
//  Copyright © 2024 Serhiy Mytrovtsiy. All rights reserved.
//

#import "lldb.h"

#include <iostream>
#include <sstream>
#include <string>

#import <db.h>
#import <write_batch.h>

using namespace std;

@implementation LLDB {
    leveldb::DB *db;
}

- (instancetype) init:(NSString *) name {
    self = [super init];
    if (self) {
        bool status = [self createDB:name];
        if (!status) {
            return nil;
        }
    }
    return self;
}

-(bool)createDB:(NSString *) path {
    leveldb::Options options;
    options.create_if_missing = true;
    leveldb::Status status = leveldb::DB::Open(options, [path UTF8String], &self->db);
    if (false == status.ok()) {
        NSLog(@"ERROR: Unable to open/create database: %s", status.ToString().c_str());
        return false;
    }
    return true;
}

-(NSArray *)keys:(NSString *)key {
    leveldb::ReadOptions readOptions;
    leveldb::Iterator *it = db->NewIterator(readOptions);
    leveldb::Slice slice = leveldb::Slice(key.UTF8String);
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    for (it->Seek(slice); it->Valid() && it->key().starts_with(slice); it->Next()) {
        NSString *value = [[NSString alloc] initWithCString:it->key().ToString().c_str() encoding: NSUTF8StringEncoding];
        [array addObject:value];
    }
    delete it;
    
    return array;
}

-(bool)insert:(NSString *)key value:(NSString *)value {
    ostringstream keyStream;
    keyStream << key.UTF8String;
    
    ostringstream valueStream;
    valueStream << value.UTF8String;
    
    leveldb::WriteOptions writeOptions;
    leveldb::Status s = self->db->Put(writeOptions, keyStream.str(), valueStream.str());
    
    return s.ok();
}

-(NSString *)findOne:(NSString *)key {
    ostringstream keyStream;
    keyStream << key.UTF8String;
    
    leveldb::ReadOptions readOptions;
    string value;
    leveldb::Status s = self->db->Get(readOptions, keyStream.str(), &value);
    
    NSString *nsstr = [[NSString alloc] initWithUTF8String:value.c_str()];
    
    return [nsstr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

-(NSString *)findLast:(NSString *)prefix {
    leveldb::ReadOptions readOptions;
    leveldb::Iterator *it = db->NewIterator(readOptions);
    leveldb::Slice slice = leveldb::Slice(prefix.UTF8String);
    NSString *value;
    
    it->SeekToLast();
    
    for (it->SeekToLast(); it->Valid() && it->key().starts_with(slice);) {
        value = [[NSString alloc] initWithCString:it->value().ToString().c_str() encoding:[NSString defaultCStringEncoding]];
        break;
    }
    delete it;
    
    return value;
}

-(NSArray *)findMany:(NSString *)prefix {
    leveldb::ReadOptions readOptions;
    leveldb::Iterator *it = db->NewIterator(readOptions);
    leveldb::Slice slice = leveldb::Slice(prefix.UTF8String);
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    for (it->Seek(slice); it->Valid() && it->key().starts_with(slice); it->Next()) {
        NSString *value = [[NSString alloc] initWithCString:it->value().ToString().c_str() encoding:[NSString defaultCStringEncoding]];
        [array addObject:value];
    }
    delete it;
    
    return array;
}

-(bool)deleteOne:(NSString *)key {
    ostringstream keySream;
    keySream << key.UTF8String;
    
    leveldb::WriteOptions writeOptions;
    leveldb::Status s = self->db->Delete(writeOptions, keySream.str());
    
    return s.ok();
}

-(bool)deleteMany:(NSArray*)keys {
    leveldb::WriteBatch batch;
    
    for (int i=0; i <[keys count]; i++) {
        NSString *key = [keys objectAtIndex:i];
        leveldb::Slice slice = leveldb::Slice(key.UTF8String);
        batch.Delete(slice);
    }
    
    leveldb::Status s = self->db->Write(leveldb::WriteOptions(), &batch);
    return s.ok();
}

-(void)close {
    delete self->db;
}

@end
