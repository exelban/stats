//
//  MyCustomXValueFormatter.m
//  ChartsDemo
//
//  Created by Daniel Cohen Gindi on 21/9/15.
//  Copyright © 2015 dcg. All rights reserved.
//

#import "MyCustomXValueFormatter.h"

@implementation MyCustomXValueFormatter

- (NSString *)stringForXValue:(NSInteger)index
                     original:(NSString *)original
              viewPortHandler:(ChartViewPortHandler *)viewPortHandler
{
    // e.g. adjust the x-axis values depending on scale / zoom level
    if (viewPortHandler.scaleX > 5.f)
    {
        return @"4";
    }
    else if (viewPortHandler.scaleX > 3.f)
    {
        return @"3";
    }
    else if (viewPortHandler.scaleX > 1.f)
    {
        return @"2";
    }
    else
    {
        return original;
    }
}

@end
