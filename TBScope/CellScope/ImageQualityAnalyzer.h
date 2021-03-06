//
//  ImageQualityAnalyzer.h
//  TBScope
//
//  Created by Frankie Myers on 6/18/14.
//  Copyright (c) 2014 UC Berkeley Fletcher Lab. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "cv.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#define CROP_WINDOW_SIZE 500  // Had to reduce this (from 700) to improve frame rate

typedef struct
    {
        double normalizedGraylevelVariance;
        double varianceOfLaplacian;
        double modifiedLaplacian;
        double tenengrad1;
        double tenengrad3;
        double tenengrad9;
        double movingAverageSharpness;
        double movingAverageContrast;
        double entropy;
        double maxVal;
        double contrast;
        double greenContrast;
        double boundaryScore;
        double contentScore;
        bool isBoundary;
        bool isEmpty;
    } ImageQuality;

@interface ImageQualityAnalyzer : NSObject

+ (IplImage *)createIplImageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer;

+ (ImageQuality) calculateFocusMetricFromIplImage:(IplImage *)iplImage;

+ (UIImage *)cropImage:(UIImage*)image withBounds:(CGRect)rect;

@end
