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

-(bool)insertMany:(NSDictionary<NSString *, NSString *> *)values {
    leveldb::WriteBatch batch;
    for (NSString *key in values) {
        NSString *value = values[key];
        batch.Put(leveldb::Slice(key.UTF8String), leveldb::Slice(value.UTF8String));
    }
    
    leveldb::WriteOptions writeOptions;
    writeOptions.sync = true;
    leveldb::Status s = self->db->Write(writeOptions, &batch);
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

-(NSDictionary<NSString *, NSString *> *)findRange:(NSString *)prefix from:(NSString *)start to:(NSString *)end {
    leveldb::ReadOptions readOptions;
    leveldb::Iterator *it = db->NewIterator(readOptions);
    leveldb::Slice prefixSlice = leveldb::Slice(prefix.UTF8String);
    leveldb::Slice endSlice = leveldb::Slice(end.UTF8String);
    NSMutableDictionary *values = [[NSMutableDictionary alloc] init];
    
    for (it->Seek(leveldb::Slice(start.UTF8String)); it->Valid() && it->key().starts_with(prefixSlice) && it->key().compare(endSlice) < 0; it->Next()) {
        NSString *key = [[NSString alloc] initWithCString:it->key().ToString().c_str() encoding:NSUTF8StringEncoding];
        NSString *value = [[NSString alloc] initWithCString:it->value().ToString().c_str() encoding:NSUTF8StringEncoding];
        if (key == nil || value == nil) {
            delete it;
            return nil;
        }
        values[key] = value;
    }
    bool success = it->status().ok();
    delete it;
    
    return success ? values : nil;
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

-(bool)deleteBefore:(NSString *)prefix timestamp:(NSString *)timestamp {
    leveldb::ReadOptions readOptions;
    leveldb::Iterator *it = db->NewIterator(readOptions);
    leveldb::Slice prefixSlice = leveldb::Slice(prefix.UTF8String);
    string cutoff = timestamp.UTF8String;
    leveldb::WriteBatch batch;
    int count = 0;
    
    for (it->Seek(prefixSlice); it->Valid() && it->key().starts_with(prefixSlice); it->Next()) {
        string key = it->key().ToString();
        size_t separator = key.rfind('@');
        if (separator == string::npos || key.substr(separator+1).compare(cutoff) >= 0) {
            continue;
        }
        batch.Delete(it->key());
        count++;
        
        if (count == 512) {
            leveldb::Status s = self->db->Write(leveldb::WriteOptions(), &batch);
            if (!s.ok()) {
                delete it;
                return false;
            }
            batch.Clear();
            count = 0;
        }
    }
    bool success = it->status().ok();
    delete it;
    if (!success) {
        return false;
    }
    
    return count == 0 || self->db->Write(leveldb::WriteOptions(), &batch).ok();
}

-(void)close {
    delete self->db;
}

@end
