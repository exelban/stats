//
//  NegativeStackedBarChartViewController.m
//  ChartsDemo
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

#import "NegativeStackedBarChartViewController.h"
#import "ChartsDemo_iOS-Swift.h"

@interface NegativeStackedBarChartViewController () <ChartViewDelegate, IChartAxisValueFormatter>

@property (nonatomic, strong) IBOutlet HorizontalBarChartView *chartView;

@end

@implementation NegativeStackedBarChartViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Stacked Bar Chart Negative";
    
    self.options = @[
                     @{@"key": @"toggleValues", @"label": @"Toggle Values"},
                     @{@"key": @"toggleIcons", @"label": @"Toggle Icons"},
                     @{@"key": @"toggleHighlight", @"label": @"Toggle Highlight"},
                     @{@"key": @"animateX", @"label": @"Animate X"},
                     @{@"key": @"animateY", @"label": @"Animate Y"},
                     @{@"key": @"animateXY", @"label": @"Animate XY"},
                     @{@"key": @"saveToGallery", @"label": @"Save to Camera Roll"},
                     @{@"key": @"togglePinchZoom", @"label": @"Toggle PinchZoom"},
                     @{@"key": @"toggleAutoScaleMinMax", @"label": @"Toggle auto scale min/max"},
                     @{@"key": @"toggleData", @"label": @"Toggle Data"},
                     @{@"key": @"toggleBarBorders", @"label": @"Show Bar Borders"},
                     ];
    
    NSNumberFormatter *customFormatter = [[NSNumberFormatter alloc] init];
    customFormatter.negativePrefix = @"";
    customFormatter.positiveSuffix = @"m";
    customFormatter.negativeSuffix = @"m";
    customFormatter.minimumSignificantDigits = 1;
    customFormatter.minimumFractionDigits = 1;
    
    _chartView.delegate = self;
    
    _chartView.chartDescription.enabled = NO;
    
    _chartView.drawBarShadowEnabled = NO;
    _chartView.drawValueAboveBarEnabled = YES;
    _chartView.highlightFullBarEnabled = NO;
    
    // scaling can now only be done on x- and y-axis separately
    _chartView.pinchZoomEnabled = NO;
    
    _chartView.drawBarShadowEnabled = NO;
    
    _chartView.leftAxis.enabled = NO;
    _chartView.rightAxis.axisMaximum = 25.0;
    _chartView.rightAxis.axisMinimum = -25.0;
    _chartView.rightAxis.drawGridLinesEnabled = NO;
    _chartView.rightAxis.drawZeroLineEnabled = YES;
    _chartView.rightAxis.labelCount = 7;
    _chartView.rightAxis.valueFormatter = [[ChartDefaultAxisValueFormatter alloc] initWithFormatter:customFormatter];
    _chartView.rightAxis.labelFont = [UIFont systemFontOfSize:9.f];
    
    ChartXAxis *xAxis = _chartView.xAxis;
    xAxis.labelPosition = XAxisLabelPositionBothSided;
    xAxis.drawGridLinesEnabled = NO;
    xAxis.drawAxisLineEnabled = NO;
    xAxis.axisMinimum = 0.0;
    xAxis.axisMaximum = 110.0;
    xAxis.centerAxisLabelsEnabled = YES;
    xAxis.labelCount = 12;
    xAxis.granularity = 10.0;
    xAxis.valueFormatter = self;
    
    _chartView.rightAxis.labelFont = [UIFont systemFontOfSize:9.f];
    
    ChartLegend *l = _chartView.legend;
    l.horizontalAlignment = ChartLegendHorizontalAlignmentRight;
    l.verticalAlignment = ChartLegendVerticalAlignmentBottom;
    l.orientation = ChartLegendOrientationHorizontal;
    l.drawInside = NO;
    l.formSize = 8.f;
    l.formToTextSpace = 4.f;
    l.xEntrySpace = 6.f;
    
    [self updateChartData];
}

- (void)updateChartData
{
    if (self.shouldHideData)
    {
        _chartView.data = nil;
        return;
    }
    
    [self setChartData];
}

- (void)setChartData
{
    NSMutableArray *yValues = [NSMutableArray array];
    [yValues addObject:[[BarChartDataEntry alloc] initWithX:5 yValues:@[ @-10, @10 ]]];
    [yValues addObject:[[BarChartDataEntry alloc] initWithX:15 yValues:@[ @-12, @13 ]]];
    [yValues addObject:[[BarChartDataEntry alloc] initWithX:25 yValues:@[ @-15, @15 ]]];
    [yValues addObject:[[BarChartDataEntry alloc] initWithX:35 yValues:@[ @-17, @17 ]]];
    [yValues addObject:[[BarChartDataEntry alloc] initWithX:45 yValues:@[ @-19, @20 ] icon: [UIImage imageNamed:@"icon"]]];
    [yValues addObject:[[BarChartDataEntry alloc] initWithX:55 yValues:@[ @-19, @19 ]]];
    [yValues addObject:[[BarChartDataEntry alloc] initWithX:65 yValues:@[ @-16, @16 ]]];
    [yValues addObject:[[BarChartDataEntry alloc] initWithX:75 yValues:@[ @-13, @14 ]]];
    [yValues addObject:[[BarChartDataEntry alloc] initWithX:85 yValues:@[ @-10, @11 ]]];
    [yValues addObject:[[BarChartDataEntry alloc] initWithX:95 yValues:@[ @-5, @6 ]]];
    [yValues addObject:[[BarChartDataEntry alloc] initWithX:105 yValues:@[ @-1, @2 ]]];
    
    BarChartDataSet *set = nil;
    if (_chartView.data.dataSetCount > 0)
    {
        set = (BarChartDataSet *)_chartView.data.dataSets[0];
        [set replaceEntries: yValues];
        [_chartView.data notifyDataChanged];
        [_chartView notifyDataSetChanged];
    }
    else
    {
        NSNumberFormatter *customFormatter = [[NSNumberFormatter alloc] init];
        customFormatter.negativePrefix = @"";
        customFormatter.positiveSuffix = @"m";
        customFormatter.negativeSuffix = @"m";
        customFormatter.minimumSignificantDigits = 1;
        customFormatter.minimumFractionDigits = 1;
        
        set = [[BarChartDataSet alloc] initWithEntries:yValues label:@"Age Distribution"];
        
        set.drawIconsEnabled = NO;
        
        set.valueFormatter = [[ChartDefaultValueFormatter alloc] initWithFormatter:customFormatter];
        set.valueFont = [UIFont systemFontOfSize:7.f];
        set.axisDependency = AxisDependencyRight;
        set.colors = @[
                       [UIColor colorWithRed:67/255.f green:67/255.f blue:72/255.f alpha:1.f],
                       [UIColor colorWithRed:124/255.f green:181/255.f blue:236/255.f alpha:1.f]
                       ];
        set.stackLabels = @[
                            @"Men", @"Women"
                            ];
        
        BarChartData *data = [[BarChartData alloc] initWithDataSet:set];
        
        data.barWidth = 8.5;
        
        _chartView.data = data;
        [_chartView setNeedsDisplay];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)optionTapped:(NSString *)key
{
    [super handleOption:key forChartView:_chartView];
}

#pragma mark - ChartViewDelegate

- (void)chartValueSelected:(ChartViewBase * __nonnull)chartView entry:(ChartDataEntry * __nonnull)entry highlight:(ChartHighlight * __nonnull)highlight
{
    NSLog(@"chartValueSelected, stack-index %ld", (long)highlight.stackIndex);
}

- (void)chartValueNothingSelected:(ChartViewBase * __nonnull)chartView
{
    NSLog(@"chartValueNothingSelected");
}

#pragma mark - IAxisValueFormatter

- (NSString *)stringForValue:(double)value
                        axis:(ChartAxisBase *)axis
{
    return [NSString stringWithFormat:@"%03.0f-%03.0f", value, value + 10.0];
}

@end
