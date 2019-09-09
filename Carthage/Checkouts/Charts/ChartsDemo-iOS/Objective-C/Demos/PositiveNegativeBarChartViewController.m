//
//  PositiveNegativeBarChartViewController.m
//  ChartsDemo
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

#import "PositiveNegativeBarChartViewController.h"
#import "ChartsDemo_iOS-Swift.h"

@interface PositiveNegativeBarChartViewController () <ChartViewDelegate, IChartAxisValueFormatter>
{
    NSArray<NSDictionary *> *dataList;
}

@property (nonatomic, strong) IBOutlet BarChartView *chartView;

@end

@implementation PositiveNegativeBarChartViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Positive/Negative Bar Chart";
    
    self.options = @[
                     @{@"key": @"toggleValues", @"label": @"Toggle Values"},
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
    
    [self setupBarLineChartView:_chartView];
    
    _chartView.delegate = self;
    
    _chartView.extraTopOffset = -30.f;
    _chartView.extraBottomOffset = 10.f;
    _chartView.extraLeftOffset = 70.f;
    _chartView.extraRightOffset = 70.f;
    
    _chartView.drawBarShadowEnabled = NO;
    _chartView.drawValueAboveBarEnabled = YES;
    
    _chartView.chartDescription.enabled = NO;
    
    // scaling can now only be done on x- and y-axis separately
    _chartView.pinchZoomEnabled = NO;
    
    _chartView.drawGridBackgroundEnabled = NO;
    
    ChartXAxis *xAxis = _chartView.xAxis;
    xAxis.labelPosition = XAxisLabelPositionBottom;
    xAxis.labelFont = [UIFont systemFontOfSize:13.f];
    xAxis.drawGridLinesEnabled = NO;
    xAxis.drawAxisLineEnabled = NO;
    xAxis.labelTextColor = [UIColor lightGrayColor];
    xAxis.labelCount = 5;
    xAxis.centerAxisLabelsEnabled = YES;
    xAxis.granularity = 1.0;
    xAxis.valueFormatter = self;
    
    ChartYAxis *leftAxis = _chartView.leftAxis;
    leftAxis.drawLabelsEnabled = NO;
    leftAxis.spaceTop = 0.25;
    leftAxis.spaceBottom = 0.25;
    leftAxis.drawAxisLineEnabled = NO;
    leftAxis.drawGridLinesEnabled = NO;
    leftAxis.drawZeroLineEnabled = YES;
    leftAxis.zeroLineColor = UIColor.grayColor;
    leftAxis.zeroLineWidth = 0.7f;

    _chartView.rightAxis.enabled = NO;
    _chartView.legend.enabled = NO;
    
    [self updateChartData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
    // THIS IS THE ORIGINAL DATA YOU WANT TO PLOT
    dataList = @[
                                          @{@"xValue": @(0),
                                            @"yValue": @(-224.1f),
                                            @"xLabel": @"12-19"},
                                          @{@"xValue": @(1),
                                            @"yValue": @(238.5f),
                                            @"xLabel": @"12-30"},
                                          @{@"xValue": @(2),
                                            @"yValue": @(1280.1f),
                                            @"xLabel": @"12-31"},
                                          @{@"xValue": @(3),
                                            @"yValue": @(-442.3f),
                                            @"xLabel": @"01-01"},
                                          @{@"xValue": @(4),
                                            @"yValue": @(-2280.1f),
                                            @"xLabel": @"01-02"},
                                          ];
    
    NSMutableArray<BarChartDataEntry *> *values = [[NSMutableArray alloc] init];
    NSMutableArray<UIColor *> *colors = [[NSMutableArray alloc] init];
    
    UIColor *green = [UIColor colorWithRed:110/255.f green:190/255.f blue:102/255.f alpha:1.f];
    UIColor *red = [UIColor colorWithRed:211/255.f green:74/255.f blue:88/255.f alpha:1.f];
    
    for (int i = 0; i < dataList.count; i++)
    {
        NSDictionary *d = dataList[i];
        BarChartDataEntry *entry = [[BarChartDataEntry alloc] initWithX:[d[@"xValue"] doubleValue] y:[d[@"yValue"] doubleValue]];
        [values addObject:entry];
        
        // specific colors
        if ([d[@"yValue"] doubleValue] >= 0.f)
        {
            [colors addObject:red];
        }
        else
        {
            [colors addObject:green];
        }
    }
    
    BarChartDataSet *set = set = [[BarChartDataSet alloc] initWithEntries:values label:@"Values"];
    set.colors = colors;
    set.valueColors = colors;
    
    BarChartData *data = [[BarChartData alloc] initWithDataSet:set];
    [data setValueFont:[UIFont systemFontOfSize:13.f]];
    
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.maximumFractionDigits = 1;
    [data setValueFormatter:[[ChartDefaultValueFormatter alloc] initWithFormatter:formatter]];
    
    data.barWidth = 0.8;
    
    _chartView.data = data;
}

- (void)optionTapped:(NSString *)key
{
    [super handleOption:key forChartView:_chartView];
}

#pragma mark - ChartViewDelegate

- (void)chartValueSelected:(ChartViewBase * __nonnull)chartView entry:(ChartDataEntry * __nonnull)entry highlight:(ChartHighlight * __nonnull)highlight
{
    NSLog(@"chartValueSelected");
}

- (void)chartValueNothingSelected:(ChartViewBase * __nonnull)chartView
{
    NSLog(@"chartValueNothingSelected");
}

#pragma mark - IAxisValueFormatter

- (NSString *)stringForValue:(double)value
                        axis:(ChartAxisBase *)axis
{
    return dataList[MIN(MAX((int) value, 0), dataList.count - 1)][@"xLabel"];

}

@end
