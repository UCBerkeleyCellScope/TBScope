//
//  SlidesTests.m
//  TBScope
//
//  Created by Jason Ardell on 11/12/15.
//  Copyright © 2015 UC Berkeley Fletcher Lab. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "Slides.h"
#import "TBScopeData.h"
#import "GoogleDriveService.h"
#import "CoreDataJSONHelper.h"
#import "TBScopeImageAsset.h"
#import "NSData+MD5.h"
#import "PMKPromise+NoopPromise.h"
#import "PMKPromise+RejectedPromise.h"

@interface SlidesTests : XCTestCase
@property (strong, nonatomic) Slides *slide;
@property (strong, nonatomic) NSManagedObjectContext *moc;
@property (strong, nonatomic) GoogleDriveService *googleDriveService;
@end

@implementation SlidesTests

- (void)setUp
{
    [super setUp];
    
    // Set up the managedObjectContext
    self.moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    self.moc.parentContext = [[TBScopeData sharedData] managedObjectContext];

    // Inject GoogleDriveService
    GoogleDriveService *mockGds = OCMPartialMock([[GoogleDriveService alloc] init]);
    self.googleDriveService = mockGds;

    [self.moc performBlockAndWait:^{
        // Create a slide
        self.slide = (Slides*)[NSEntityDescription insertNewObjectForEntityForName:@"Slides" inManagedObjectContext:self.moc];
        self.slide.exam = (Exams*)[NSEntityDescription insertNewObjectForEntityForName:@"Exams" inManagedObjectContext:self.moc];
    }];
}

- (void)tearDown
{
    self.moc = nil;
}

- (void)setSlideRoiSpritePath
{
    [self.moc performBlockAndWait:^{
        self.slide.roiSpritePath = @"test-file-id";
    }];
}

- (void)setSlideRoiSpriteGoogleDriveFileID
{
    [self.moc performBlockAndWait:^{
        self.slide.roiSpriteGoogleDriveFileID = @"test-file-id";
    }];
}

- (void)stubOutRemoteFileTime:(NSString *)remoteTime md5:(NSString *)md5
{
    PMKPromise *promise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        GTLDriveFile *remoteFile = [[GTLDriveFile alloc] init];
        
        // Stub out remote file time to newer than local modification time
        remoteFile.modifiedDate = [GTLDateTime dateTimeWithRFC3339String:remoteTime];
        
        // Stub out remote md5 to be different from local
        remoteFile.md5Checksum = md5;
        
        resolve(remoteFile);
    }];
    OCMStub([self.googleDriveService getMetadataForFileId:[OCMArg any]])
        .andReturn(promise);
}

- (void)stubOutGetImageAtPath
{
    id mock = [OCMockObject mockForClass:[TBScopeImageAsset class]];
    PMKPromise *promise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        NSString *imageName = @"fl_01_01";
        NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:imageName ofType:@"jpg"];
        UIImage *image = [UIImage imageWithContentsOfFile:filePath];
        resolve(image);
    }];
    [[[mock stub] andReturn:promise] getImageAtPath:[OCMArg any]];
}

#pragma allImagesAreLocal tests

- (void)testThatAllImagesAreLocalReturnsTrueIfThereAreNoImages
{
    [self.moc performBlockAndWait:^{
        XCTAssertTrue([self.slide allImagesAreLocal]);
    }];
}

- (void)testThatAllImagesAreLocalReturnsTrueIfAllImagesAreLocal
{
    // Add an image with a local path
    [self.moc performBlockAndWait:^{
        Images *image = [NSEntityDescription insertNewObjectForEntityForName:@"Images" inManagedObjectContext:self.moc];
        image.path = @"asset-library://path/to/image.jpg";
        [self.slide addSlideImagesObject:image];
        XCTAssertTrue([self.slide allImagesAreLocal]);
    }];
}

- (void)testThatAllImagesAreLocalReturnsTrueIfASingleImageIsNotLocal
{
    // Add an image without a local path
    [self.moc performBlockAndWait:^{
        Images *image = [NSEntityDescription insertNewObjectForEntityForName:@"Images" inManagedObjectContext:self.moc];
        image.path = nil;
        [self.slide addSlideImagesObject:image];
        XCTAssertFalse([self.slide allImagesAreLocal]);
    }];
}

#pragma hasLocalImages tests

- (void)testThatHasLocalImagesReturnsFalseIfSlideHasNoImages
{
    [self.moc performBlockAndWait:^{
        XCTAssertFalse([self.slide hasLocalImages]);
    }];
}

- (void)testThatHasLocalImagesReturnsFalseIfSlideHasOnlyRemoteImages
{
    // Add an image with only a remote path
    [self.moc performBlockAndWait:^{
        Images *image = [NSEntityDescription insertNewObjectForEntityForName:@"Images" inManagedObjectContext:self.moc];
        image.googleDriveFileID = @"remote-id";
        image.path = nil;
        [self.slide addSlideImagesObject:image];
        XCTAssertFalse([self.slide hasLocalImages]);
    }];
}

- (void)testThatHasLocalImagesReturnsFalseIfSlideHasASingleLocalImage
{
    // Add an image with only a remote path
    [self.moc performBlockAndWait:^{
        Images *image = [NSEntityDescription insertNewObjectForEntityForName:@"Images" inManagedObjectContext:self.moc];
        image.googleDriveFileID = @"remote-id";
        image.path = @"asset-library://path/to/image.jpg";
        [self.slide addSlideImagesObject:image];
        XCTAssertTrue([self.slide hasLocalImages]);
    }];
}

#pragma imagesToUpload tests

- (void)testThatImagesToUploadIncludesAnImageWithoutROIsIfNumberOfSlidesIsLessThanMaxUploadsPerSlide
{
    [self _stubMaxUploadsPerSlide:5];
    [self.moc performBlockAndWait:^{
        // Add an image without ROIs to the slide
        Images *image = (Images*)[NSEntityDescription insertNewObjectForEntityForName:@"Images" inManagedObjectContext:self.moc];
        [self.slide addSlideImagesObject:image];

        // Make sure image is included in results
        NSArray *actual = [self.slide imagesToUpload];
        XCTAssertEqual(image, [actual firstObject]);
    }];
}

- (void)testThatImagesToUploadDoesNotExceedMaxUploadsPerSlide
{
    [self _stubMaxUploadsPerSlide:1];
    [self.moc performBlockAndWait:^{
        // Add 2 images to the slide
        for (int i=0; i<2; i++) {
            Images *image = (Images*)[NSEntityDescription insertNewObjectForEntityForName:@"Images" inManagedObjectContext:self.moc];
            [self.slide addSlideImagesObject:image];
        }

        // Make sure result only contains one object
        NSArray *actual = [self.slide imagesToUpload];
        XCTAssertEqual(1, [actual count]);
    }];
}

- (void)testThatImagesToUploadIncludesImagesWithHighScoresOverThoseWithLowScores
{
    [self _stubMaxUploadsPerSlide:1];
    [self.moc performBlockAndWait:^{
        // Add an image with ROI with score 0.75
        Images *image1 = (Images*)[NSEntityDescription insertNewObjectForEntityForName:@"Images" inManagedObjectContext:self.moc];
        ImageAnalysisResults *results1 = (ImageAnalysisResults*)[NSEntityDescription insertNewObjectForEntityForName:@"ImageAnalysisResults" inManagedObjectContext:self.moc];
        image1.imageAnalysisResults = results1;
        ROIs *roi1 = (ROIs*)[NSEntityDescription insertNewObjectForEntityForName:@"ROIs" inManagedObjectContext:self.moc];
        roi1.score = 0.75;
        [results1 addImageROIsObject:roi1];
        [self.slide addSlideImagesObject:image1];

        // Add an image with ROI with score 0.25
        Images *image2 = (Images*)[NSEntityDescription insertNewObjectForEntityForName:@"Images" inManagedObjectContext:self.moc];
        ImageAnalysisResults *results2 = (ImageAnalysisResults*)[NSEntityDescription insertNewObjectForEntityForName:@"ImageAnalysisResults" inManagedObjectContext:self.moc];
        image2.imageAnalysisResults = results2;
        ROIs *roi2 = (ROIs*)[NSEntityDescription insertNewObjectForEntityForName:@"ROIs" inManagedObjectContext:self.moc];
        roi2.score = 0.25;
        [results2 addImageROIsObject:roi2];
        [self.slide addSlideImagesObject:image2];

        // Make sure the image with ROI of 0.75 is in results
        NSArray *actual = [self.slide imagesToUpload];
        XCTAssertEqual(image1, [actual firstObject]);
    }];
}

- (void)testThatImagesToUploadIncludesImagesROIsOverThoseWithoutROIs
{
    [self _stubMaxUploadsPerSlide:1];
    [self.moc performBlockAndWait:^{
        // Add image with ROI with score 0.5
        Images *image1 = (Images*)[NSEntityDescription insertNewObjectForEntityForName:@"Images" inManagedObjectContext:self.moc];
        ImageAnalysisResults *results1 = (ImageAnalysisResults*)[NSEntityDescription insertNewObjectForEntityForName:@"ImageAnalysisResults" inManagedObjectContext:self.moc];
        image1.imageAnalysisResults = results1;
        ROIs *roi1 = (ROIs*)[NSEntityDescription insertNewObjectForEntityForName:@"ROIs" inManagedObjectContext:self.moc];
        roi1.score = 0.5;
        [results1 addImageROIsObject:roi1];
        [self.slide addSlideImagesObject:image1];

        // Add image without any ROIs
        Images *image2 = (Images*)[NSEntityDescription insertNewObjectForEntityForName:@"Images" inManagedObjectContext:self.moc];
        [self.slide addSlideImagesObject:image2];

        // Make sure the image with ROI of 0.5 is in results
        NSArray *actual = [self.slide imagesToUpload];
        XCTAssertEqual(image1, [actual firstObject]);
    }];
}

#pragma uploadToGoogleDrive tests

- (void)testThatUploadRoiSpriteSheetToGoogleDriveDoesNotUploadIfPathIsNil
{
    [self.moc performBlockAndWait:^{
        self.slide.roiSpritePath = nil;
    }];

    // Stub out [GoogleDriveService uploadFile:withData:] to fail
    OCMStub([self.googleDriveService uploadFile:[OCMArg any] withData:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            XCTFail(@"Did not expect uploadFile:withData: to be called");
        });

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    // Call uploadToGoogleDrive
    [self.slide uploadRoiSpriteSheetToGoogleDrive:self.googleDriveService]
        .then(^(GTLDriveFile *file) { [expectation fulfill]; })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatUploadRoiSpriteSheetToGoogleDriveUploadsIfGetMetadataForFileIdReturnsNil
{
    [self setSlideRoiSpritePath];

    // Stub out getMetadataForFileId to return nil
    OCMStub([self.googleDriveService getMetadataForFileId:[OCMArg any]])
        .andReturn([PMKPromise noopPromise]);

    // Stub out remote file time to be newer
    NSString *md5 = @"abc123";
    [self stubOutRemoteFileTime:@"2014-11-10T12:00:00.00Z" md5:md5];
    [self.moc performBlockAndWait:^{
        self.slide.exam.dateModified = @"2015-11-10T12:00:00.00Z";
    }];

    // Stub out [TBScopeImageAsset getImageAtPath:] to succeed
    [self stubOutGetImageAtPath];

    // Stub out [GoogleDriveService uploadFile:withData:] to succeed
    OCMStub([self.googleDriveService uploadFile:[OCMArg any] withData:[OCMArg any]])
        .andReturn([PMKPromise noopPromise]);

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    // Call uploadToGoogleDrive
    [self.slide uploadRoiSpriteSheetToGoogleDrive:self.googleDriveService]
        .then(^(GTLDriveFile *file) { [expectation fulfill]; })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatUploadRoiSpriteSheetToGoogleDriveSetsParentDirectory
{
    [self setSlideRoiSpritePath];

    // Set parent directory identifier in NSUserDefaults
    NSString *remoteDirIdentifier = @"remote-directory-identifier";
    id userDefaultsMock = OCMClassMock([NSUserDefaults class]);
    OCMStub([userDefaultsMock valueForKey:@"RemoteDirectoryIdentifier"])
        .andReturn(remoteDirIdentifier);
    OCMStub([userDefaultsMock standardUserDefaults])
        .andReturn(userDefaultsMock);

    // Stub out getMetadataForFileId to return nil
    OCMStub([self.googleDriveService getMetadataForFileId:[OCMArg any]])
        .andReturn([PMKPromise noopPromise]);

    // Stub out remote file time to be newer
    NSString *md5 = @"abc123";
    [self stubOutRemoteFileTime:@"2014-11-10T12:00:00.00Z" md5:md5];
    [self.moc performBlockAndWait:^{
        self.slide.exam.dateModified = @"2015-11-10T12:00:00.00Z";
    }];

    // Stub out [TBScopeImageAsset getImageAtPath:] to succeed
    [self stubOutGetImageAtPath];

    // Stub out [GoogleDriveService uploadFile:withData:] to succeed
    GTLDriveFile *fileArg = [OCMArg checkWithBlock:^BOOL(GTLDriveFile *file) {
        GTLDriveFile *actualRemoteDir = [file.parents objectAtIndex:0];
        return [actualRemoteDir.identifier isEqualToString:remoteDirIdentifier];
    }];
    OCMStub([self.googleDriveService uploadFile:fileArg
                                             withData:[OCMArg any]])
        .andReturn([PMKPromise noopPromise]);

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    // Call uploadToGoogleDrive
    [self.slide uploadRoiSpriteSheetToGoogleDrive:self.googleDriveService]
        .then(^(GTLDriveFile *file) { [expectation fulfill]; })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatUploadRoiSpriteSheetToGoogleDriveDoesNotSetParentsWhenRemoteDirectoryIdentifierIsNil
{
    [self setSlideRoiSpritePath];

    // Set parent directory identifier in NSUserDefaults
    id userDefaultsMock = OCMClassMock([NSUserDefaults class]);
    OCMStub([userDefaultsMock valueForKey:@"RemoteDirectoryIdentifier"])
        .andReturn(nil);
    OCMStub([userDefaultsMock standardUserDefaults])
        .andReturn(userDefaultsMock);

    // Stub out getMetadataForFileId to return nil
    OCMStub([self.googleDriveService getMetadataForFileId:[OCMArg any]])
        .andReturn([PMKPromise noopPromise]);

    // Stub out remote file time to be newer
    NSString *md5 = @"abc123";
    [self stubOutRemoteFileTime:@"2014-11-10T12:00:00.00Z" md5:md5];
    [self.moc performBlockAndWait:^{
        self.slide.exam.dateModified = @"2015-11-10T12:00:00.00Z";
    }];

    // Stub out [TBScopeImageAsset getImageAtPath:] to succeed
    [self stubOutGetImageAtPath];

    // Stub out [GoogleDriveService uploadFile:withData:] to succeed
    GTLDriveFile *fileArg = [OCMArg checkWithBlock:^BOOL(GTLDriveFile *file) {
        return (file.parents == nil);
    }];
    OCMStub([self.googleDriveService uploadFile:fileArg
                                             withData:[OCMArg any]])
        .andReturn([PMKPromise noopPromise]);

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    // Call uploadToGoogleDrive
    [self.slide uploadRoiSpriteSheetToGoogleDrive:self.googleDriveService]
        .then(^(GTLDriveFile *file) { [expectation fulfill]; })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatUploadRoiSpriteSheetToGoogleDriveDoesNotUploadIfRemoteFileIsNewerThanLocalFile
{
    [self setSlideRoiSpritePath];
    [self.moc performBlockAndWait:^{
        self.slide.exam.dateModified = @"2014-11-10T12:00:00.00Z";
    }];

    // Stub out remote file time to be newer
    NSString *md5 = @"abc123";
    [self stubOutRemoteFileTime:@"2015-11-10T12:00:00.00Z" md5:md5];

    // Stub out [TBScopeImageAsset getImageAtPath:] to succeed
    [self stubOutGetImageAtPath];

    // Stub out [GoogleDriveService uploadFile:withData:] to fail
    OCMStub([self.googleDriveService uploadFile:[OCMArg any] withData:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            XCTFail(@"Did not expect uploadFile:withData: to be called");
        });

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    // Call uploadToGoogleDrive
    [self.slide uploadRoiSpriteSheetToGoogleDrive:self.googleDriveService]
        .then(^(GTLDriveFile *file) { [expectation fulfill]; })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatUploadRoiSpriteSheetToGoogleDriveDoesNotUploadIfRemoteFileHasSameMd5AsLocalFile
{
    [self setSlideRoiSpritePath];

    // Stub out local metadata
    [self.moc performBlockAndWait:^{
        self.slide.exam.dateModified = @"2015-11-10T12:00:00.00Z";
    }];
    
    // Stub out [TBScopeImageAsset getImageAtPath:] to succeed
    [self stubOutGetImageAtPath];

    // Stub out [GoogleDriveService uploadFile:withData:] to fail
    OCMStub([self.googleDriveService uploadFile:[OCMArg any] withData:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            XCTFail(@"Did not expect uploadFile:withData: to be called");
        });

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    // Get local image at path
    [TBScopeImageAsset getImageAtPath:@"some-path"]
        .then(^(UIImage *image) {
            // Calculate md5 of local file
            NSData *localData = UIImageJPEGRepresentation((UIImage *)image, 1.0);
            NSString *localMd5 = [localData MD5];

            // Stub remote metadata
            [self stubOutRemoteFileTime:@"2014-11-10T12:00:00.00Z" md5:localMd5];

            // Call uploadToGoogleDrive
            [self.slide uploadRoiSpriteSheetToGoogleDrive:self.googleDriveService]
                .then(^(GTLDriveFile *file) { [expectation fulfill]; })
                .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });
        });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatUploadToGoogleDriveUploadsROISpriteSheet
{
    [self setSlideRoiSpritePath];
    [self.moc performBlockAndWait:^{
        self.slide.exam.dateModified = @"2015-11-10T12:00:00.00Z";
    }];

    // Stub out remote file time to be newer
    NSString *md5 = @"abc123";
    [self stubOutRemoteFileTime:@"2014-11-10T12:00:00.00Z" md5:md5];

    // Stub out [TBScopeImageAsset getImageAtPath:] to succeed
    [self stubOutGetImageAtPath];

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    // Stub out [GoogleDriveService uploadFile:withData:] to succeed
    OCMStub([self.googleDriveService uploadFile:[OCMArg any] withData:[OCMArg any]])
        .andReturn([PMKPromise noopPromise]);

    // Call uploadToGoogleDrive
    [self.slide uploadRoiSpriteSheetToGoogleDrive:self.googleDriveService]
        .then(^(GTLDriveFile *file) { [expectation fulfill]; })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatUploadToGoogleDriveRejectsPromiseIfROISpriteSheetUploadFails
{
    [self setSlideRoiSpritePath];
    [self.moc performBlockAndWait:^{
        self.slide.exam.dateModified = @"2015-11-10T12:00:00.00Z";
    }];

    // Stub out remote file time to be newer
    NSString *md5 = @"abc123";
    [self stubOutRemoteFileTime:@"2014-11-10T12:00:00.00Z" md5:md5];

    // Stub out [TBScopeImageAsset getImageAtPath:] to succeed
    [self stubOutGetImageAtPath];

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    // Stub out [GoogleDriveService uploadFile:withData:] to fail
    OCMStub([self.googleDriveService uploadFile:[OCMArg any] withData:[OCMArg any]])
        .andReturn([PMKPromise rejectedPromise]);

    // Call uploadToGoogleDrive
    [self.slide uploadRoiSpriteSheetToGoogleDrive:self.googleDriveService]
        .then(^(NSError *error) { XCTFail(@"Expected promise to reject"); })
        .catch(^(GTLDriveFile *file) { [expectation fulfill]; });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatUploadToGoogleDriveUpdatesROISpriteSheetGoogleDriveIdAfterUploading
{
    [self setSlideRoiSpritePath];
    [self.moc performBlockAndWait:^{
        self.slide.exam.dateModified = @"2015-11-10T12:00:00.00Z";
    }];

    // Stub out remote file time to be newer
    NSString *md5 = @"abc123";
    [self stubOutRemoteFileTime:@"2014-11-10T12:00:00.00Z" md5:md5];

    // Stub out [TBScopeImageAsset getImageAtPath:] to succeed
    [self stubOutGetImageAtPath];

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];
    
    // Stub out [GoogleDriveService uploadFile:withData:] to fail
    NSString *remoteFileId = @"some-file-id";
    PMKPromise *promise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        GTLDriveFile *file = [[GTLDriveFile alloc] init];
        file.identifier = remoteFileId;
        resolve(file);
    }];
    OCMStub([self.googleDriveService uploadFile:[OCMArg any] withData:[OCMArg any]])
        .andReturn(promise);

    // Call uploadToGoogleDrive
    [self.slide uploadRoiSpriteSheetToGoogleDrive:self.googleDriveService]
        .then(^{
            [self.moc performBlock:^{
                NSString *localFileId = self.slide.roiSpriteGoogleDriveFileID;
                XCTAssert([localFileId isEqualToString:remoteFileId]);
                [expectation fulfill];
            }];
        })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

#pragma downloadFromGoogleDrive tests

- (void)testThatDownloadFromGoogleDriveDoesNotDownloadIfRoiSpriteGoogleDriveIdIsNil
{
    [self.moc performBlockAndWait:^{
        self.slide.roiSpriteGoogleDriveFileID = nil;
    }];
    
    // Stub out [GoogleDriveService getFile:] to fail
    OCMStub([self.googleDriveService getFile:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            XCTFail(@"Did not expect downloadFileWithId to be called");
        });

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    // Call download
    [self.slide downloadRoiSpriteSheetFromGoogleDrive:self.googleDriveService]
        .then(^{ [expectation fulfill]; })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatDownloadFromGoogleDriveDoesNotDownloadIfGetMetadataForFileIdReturnsNil
{
    // Stub out [googleDriveService getMetadataForFileId] to return nil
    OCMStub([self.googleDriveService getMetadataForFileId:[OCMArg any]])
        .andReturn([PMKPromise noopPromise]);

    // Fail if getFile is called
    OCMStub([self.googleDriveService getFile:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            XCTFail(@"Did not expect [googleDriveService getFile] to be called.");
        });

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    [self.slide downloadRoiSpriteSheetFromGoogleDrive:self.googleDriveService]
        .then(^{ [expectation fulfill]; })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve."); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatDownloadFromGoogleDriveDoesNotDownloadIfLocalFileIsNewerThanRemoteFile
{
    // Stub out file times and md5s
    NSString *md5 = @"abc123";
    [self stubOutRemoteFileTime:@"2014-11-10T12:00:00.00Z" md5:md5];
    [self.moc performBlockAndWait:^{
        self.slide.exam.dateModified = @"2015-11-10T12:00:00.00Z";
    }];

    // Fail if getFile is called
    OCMStub([self.googleDriveService getFile:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            XCTFail(@"Did not expect [googleDriveService getFile] to be called.");
        });

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    [self.slide downloadRoiSpriteSheetFromGoogleDrive:self.googleDriveService]
        .then(^{ [expectation fulfill]; })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve."); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatDownloadFromGoogleDriveFetchesSpriteSheetFromServer
{
    [self setSlideRoiSpriteGoogleDriveFileID];

    // Stub out getMetadataForFile to return a file
    PMKPromise *promise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        GTLDriveFile *file = [[GTLDriveFile alloc] init];
        resolve(file);
    }];
    OCMStub([self.googleDriveService getMetadataForFileId:[OCMArg any]])
        .andReturn(promise);

    // Stub out getFile to return NSData
    PMKPromise *getFilePromise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        NSData *data = [@"hello world" dataUsingEncoding:NSUTF8StringEncoding];
        resolve(data);
    }];
    OCMStub([self.googleDriveService getFile:[OCMArg any]])
        .andReturn(getFilePromise);

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];
    
    // Call download
    [self.slide downloadRoiSpriteSheetFromGoogleDrive:self.googleDriveService]
        .then(^(GTLDriveFile *file) {
            OCMVerify([self.googleDriveService getFile:[OCMArg any]]);
            [expectation fulfill];
        })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatDownloadFromGoogleDriveSavesFileToAssetLibrary
{
    [self setSlideRoiSpriteGoogleDriveFileID];

    // Stub out getMetadataForFile to return a file
    PMKPromise *getMetadataPromise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        GTLDriveFile *file = [[GTLDriveFile alloc] init];
        resolve(file);
    }];
    OCMStub([self.googleDriveService getMetadataForFileId:[OCMArg any]])
        .andReturn(getMetadataPromise);

    // Stub out getFile to return NSData
    PMKPromise *getFilePromise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        NSData *data = [@"hello world" dataUsingEncoding:NSUTF8StringEncoding];
        resolve(data);
    }];
    OCMStub([self.googleDriveService getFile:[OCMArg any]])
        .andReturn(getFilePromise);

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];
    
    // Stub out saveImage
    id saveImageMock = [OCMockObject mockForClass:[TBScopeImageAsset class]];

    // Call download
    [self.slide downloadRoiSpriteSheetFromGoogleDrive:self.googleDriveService]
        .then(^{
            OCMVerify([saveImageMock saveImage:[OCMArg any]]);
            [expectation fulfill];
        })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatDownloadFromGoogleDriveUpdatesRoiSpriteSheetPathAfterDownloading
{
    [self setSlideRoiSpriteGoogleDriveFileID];

    // Stub out getMetadataForFile to return a file
    PMKPromise *getMetadataPromise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        GTLDriveFile *file = [[GTLDriveFile alloc] init];
        resolve(file);
    }];
    OCMStub([self.googleDriveService getMetadataForFileId:[OCMArg any]])
        .andReturn(getMetadataPromise);

    // Stub out getFile to return NSData
    PMKPromise *getFilePromise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        NSString *imageName = @"fl_01_01";
        NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:imageName ofType:@"jpg"];
        UIImage *image = [UIImage imageWithContentsOfFile:filePath];
        NSData *data = UIImageJPEGRepresentation(image, 1.0);
        resolve(data);
    }];
    OCMStub([self.googleDriveService getFile:[OCMArg any]])
        .andReturn(getFilePromise);

    // Stub out [TBScopeImageAsset saveImage:] to return a given path
    id mock = [OCMockObject mockForClass:[TBScopeImageAsset class]];
    NSString *path = @"asset-library://path/to/image.jpg";
    PMKPromise *saveImagePromise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        resolve([NSURL URLWithString:path]);
    }];
    [[[mock stub] andReturn:saveImagePromise] saveImage:[OCMArg any]];

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];
    
    // Call download
    [self.slide downloadRoiSpriteSheetFromGoogleDrive:self.googleDriveService]
        .then(^(GTLDriveFile *file) {
            [self.moc performBlock:^{
                // Verify that slide.roiSpritePath was set
                XCTAssert([self.slide.roiSpritePath isEqualToString:path]);
                [expectation fulfill];
            }];
        })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatDownloadFromGoogleDriveReplacesExistingROISpriteSheetWithNewerOneFromServer
{
    // Set up existing local file
    [self setSlideRoiSpritePath];

    // Set up existing remote file
    [self setSlideRoiSpriteGoogleDriveFileID];
    [self stubOutRemoteFileTime:@"2014-11-10T12:00:00.00Z" md5:@"abc123"];

    // Stub out getFile to return NSData
    PMKPromise *getFilePromise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        NSString *imageName = @"fl_01_01";
        NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:imageName ofType:@"jpg"];
        UIImage *image = [UIImage imageWithContentsOfFile:filePath];
        NSData *data = UIImageJPEGRepresentation(image, 1.0);
        resolve(data);
    }];
    OCMStub([self.googleDriveService getFile:[OCMArg any]])
        .andReturn(getFilePromise);

    // Stub out [TBScopeImageAsset saveImage:] to return a given path
    NSString *path = @"asset-library://path/to/image.jpg";
    PMKPromise *saveImagePromise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        resolve([NSURL URLWithString:path]);
    }];
    id mock = [OCMockObject mockForClass:[TBScopeImageAsset class]];
    [[[mock stub] andReturn:saveImagePromise] saveImage:[OCMArg any]];

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];
    
    // Call download
    [self.slide downloadRoiSpriteSheetFromGoogleDrive:self.googleDriveService]
        .then(^(GTLDriveFile *file) {
            [self.moc performBlock:^{
                // Verify that slide.roiSpritePath was set
                XCTAssert([self.slide.roiSpritePath isEqualToString:path]);
                [expectation fulfill];
            }];
        })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

#pragma private helper methods

- (void)_stubMaxUploadsPerSlide:(int)newValue
{
    id udMock = OCMPartialMock([NSUserDefaults standardUserDefaults]);
    id udClassMock = OCMClassMock([NSUserDefaults class]);
    NSInteger value = (NSInteger)newValue;
    OCMStub([udMock integerForKey:@"MaxUploadsPerSlide"])
        .andReturn(value);
    OCMStub([udClassMock standardUserDefaults])
        .andReturn(udMock);
}

@end
