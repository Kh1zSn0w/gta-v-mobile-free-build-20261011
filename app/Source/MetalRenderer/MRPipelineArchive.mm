#include "MRPipelineArchive.h"
#include "MRInternal.h"
#import <Foundation/Foundation.h>

namespace mr {
static id<MTLBinaryArchive> loadedArchive, collectingArchive;
static NSURL *archiveURL;
static dispatch_queue_t archiveQueue;
static bool saveScheduled;

void pipelineArchiveConfigure(id<MTLDevice> device) {
    NSURL *cache = [NSFileManager.defaultManager URLForDirectory:NSCachesDirectory
        inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    NSURL *directory = [cache URLByAppendingPathComponent:@"MetalPipelineCache" isDirectory:YES];
    if (!directory || ![NSFileManager.defaultManager createDirectoryAtURL:directory
        withIntermediateDirectories:YES attributes:nil error:nil]) return;
    // Driver/build changes invalidate only this disposable shader cache.
    NSString *build = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"dev";
    NSString *version = [NSString stringWithFormat:@"%@-%@-%llu.metalarc", build,
        NSProcessInfo.processInfo.operatingSystemVersionString, (unsigned long long)device.registryID];
    archiveURL = [directory URLByAppendingPathComponent:version];
    MTLBinaryArchiveDescriptor *d = [MTLBinaryArchiveDescriptor new];
    d.url = archiveURL;
    NSError *error = nil;
    loadedArchive = [device newBinaryArchiveWithDescriptor:d error:&error];
    // Keep the loaded lookup archive immutable while compiler threads read it.
    collectingArchive = [device newBinaryArchiveWithDescriptor:d error:&error];
    if (!collectingArchive) {
        d.url = nil;
        collectingArchive = [device newBinaryArchiveWithDescriptor:d error:&error];
    }
    if (!collectingArchive) { logf("Metal pipeline cache unavailable: %s", error.localizedDescription.UTF8String); return; }
    archiveQueue = dispatch_queue_create("gta5port.pipeline-cache", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0));
    logf("Metal pipeline cache: %s", loadedArchive ? "reusing compiled pipelines" : "warming for next launch");
}

void pipelineArchiveApply(MTLRenderPipelineDescriptor *descriptor) {
    if (loadedArchive) descriptor.binaryArchives = @[loadedArchive];
}

void pipelineArchiveRecord(MTLRenderPipelineDescriptor *descriptor) {
    if (!archiveQueue) return;
    MTLRenderPipelineDescriptor *copy = [descriptor copy];
    copy.binaryArchives = nil;
    dispatch_async(archiveQueue, ^{
        @autoreleasepool {
            NSError *error = nil;
            if (![collectingArchive addRenderPipelineFunctionsWithDescriptor:copy error:&error]) return;
            if (saveScheduled) return;
            saveScheduled = true;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), archiveQueue, ^{
                @autoreleasepool {
                    // Atomic replacement keeps a killed app from corrupting the previous archive.
                    NSURL *temporary = [archiveURL URLByAppendingPathExtension:@"tmp"];
                    NSError *saveError = nil;
                    if ([collectingArchive serializeToURL:temporary error:&saveError]) {
                        if ([NSFileManager.defaultManager fileExistsAtPath:archiveURL.path]) {
                            [NSFileManager.defaultManager replaceItemAtURL:archiveURL withItemAtURL:temporary
                                backupItemName:nil options:0 resultingItemURL:nil error:&saveError];
                        } else [NSFileManager.defaultManager moveItemAtURL:temporary toURL:archiveURL error:&saveError];
                    }
                    if (saveError) logf("Metal pipeline cache save failed: %s", saveError.localizedDescription.UTF8String);
                    saveScheduled = false;
                }
            });
        }
    });
}
}
