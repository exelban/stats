//
//  CombinedChartViewController.m
//  ChartsDemo
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

#import "CombinedChartViewController.h"
#import "ChartsDemo_iOS-Swift.h"

#define ITEM_COUNT 12

@interface CombinedChartViewController () <ChartViewDelegate, IChartAxisValueFormatter>
{
    NSArray<NSString *> *months;
}

@property (nonatomic, strong) IBOutlet CombinedChartView *chartView;

@end

@implementation CombinedChartViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Combined Chart";
    
    self.options = @[
                     @{@"key": @"toggleLineValues", @"label": @"Toggle Line Values"},
                     @{@"key": @"toggleBarValues", @"label": @"Toggle Bar Values"},
                     @{@"key": @"saveToGallery", @"label": @"Save to Camera Roll"},
                     @{@"key": @"toggleData", @"label": @"Toggle Data"},
                     @{@"key": @"toggleBarBorders", @"label": @"Show Bar Borders"},
                     @{@"key": @"removeDataSet", @"label": @"Remove random set"},
                     ];
    
    months = @[
               @"Jan", @"Feb", @"Mar",
               @"Apr", @"May", @"Jun",
               @"Jul", @"Aug", @"Sep",
               @"Oct", @"Nov", @"Dec"
               ];
    
    _chartView.delegate = self;
    
    _chartView.chartDescription.enabled = NO;
    
    _chartView.drawGridBackgroundEnabled = NO;
    _chartView.drawBarShadowEnabled = NO;
    _chartView.highlightFullBarEnabled = NO;
    
    _chartView.drawOrder = @[
                             @(CombinedChartDrawOrderBar),
                             @(CombinedChartDrawOrderBubble),
                             @(CombinedChartDrawOrderCandle),
                             @(CombinedChartDrawOrderLine),
                             @(CombinedChartDrawOrderScatter)
                             ];
    
    ChartLegend *l = _chartView.legend;
    l.wordWrapEnabled = YES;
    l.horizontalAlignment = ChartLegendHorizontalAlignmentCenter;
    l.verticalAlignment = ChartLegendVerticalAlignmentBottom;
    l.orientation = ChartLegendOrientationHorizontal;
    l.drawInside = NO;
    
    ChartYAxis *rightAxis = _chartView.rightAxis;
    rightAxis.drawGridLinesEnabled = NO;
    rightAxis.axisMinimum = 0.0; // this replaces startAtZero = YES
    
    ChartYAxis *leftAxis = _chartView.leftAxis;
    leftAxis.drawGridLinesEnabled = NO;
    leftAxis.axisMinimum = 0.0; // this replaces startAtZero = YES
    
    ChartXAxis *xAxis = _chartView.xAxis;
    xAxis.labelPosition = XAxisLabelPositionBothSided;
    xAxis.axisMinimum = 0.0;
    xAxis.granularity = 1.0;
    xAxis.valueFormatter = self;
    
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
    CombinedChartData *data = [[CombinedChartData alloc] init];
    data.lineData = [self generateLineData];
    data.barData = [self generateBarData];
    data.bubbleData = [self generateBubbleData];
    data.scatterData = [self generateScatterData];
    data.candleData = [self generateCandleData];
    
    _chartView.xAxis.axisMaximum = data.xMax + 0.25;

    _chartView.data = data;
}

- (void)optionTapped:(NSString *)key
{
    if ([key isEqualToString:@"toggleLineValues"])
    {
        for (NSObject<IChartDataSet> *set in _chartView.data.dataSets)
        {
            if ([set isKindOfClass:LineChartDataSet.class])
            {
                set.drawValuesEnabled = !set.isDrawValuesEnabled;
            }
        }
        
        [_chartView setNeedsDisplay];
        return;
    }
    
    if ([key isEqualToString:@"toggleBarValues"])
    {
        for (NSObject<IChartDataSet> *set in _chartView.data.dataSets)
        {
            if ([set isKindOfClass:BarChartDataSet.class])
            {
                set.drawValuesEnabled = !set.isDrawValuesEnabled;
            }
        }
        
        [_chartView setNeedsDisplay];
        return;
    }
    
    if ([key isEqualToString:@"removeDataSet"])
    {
        int rnd = (int)arc4random_uniform((float)_chartView.data.dataSetCount);
        [_chartView.data removeDataSet:[_chartView.data getDataSetByIndex:rnd]];
        [_chartView.data notifyDataChanged];
        [_chartView notifyDataSetChanged];
    }
    
    [super handleOption:key forChartView:_chartView];
}

- (LineChartData *)generateLineData
{
    LineChartData *d = [[LineChartData alloc] init];
    
    NSMutableArray *entries = [[NSMutableArray alloc] init];
    
    for (int index = 0; index < ITEM_COUNT; index++)
    {
        [entries addObject:[[ChartDataEntry alloc] initWithX:index + 0.5 y:(arc4random_uniform(15) + 5)]];
    }
    
    LineChartDataSet *set = [[LineChartDataSet alloc] initWithEntries:entries label:@"Line DataSet"];
    [set setColor:[UIColor colorWithRed:240/255.f green:238/255.f blue:70/255.f alpha:1.f]];
    set.lineWidth = 2.5;
    [set setCircleColor:[UIColor colorWithRed:240/255.f green:238/255.f blue:70/255.f alpha:1.f]];
    set.circleRadius = 5.0;
    set.circleHoleRadius = 2.5;
    set.fillColor = [UIColor colorWithRed:240/255.f green:238/255.f blue:70/255.f alpha:1.f];
    set.mode = LineChartModeCubicBezier;
    set.drawValuesEnabled = YES;
    set.valueFont = [UIFont systemFontOfSize:10.f];
    set.valueTextColor = [UIColor colorWithRed:240/255.f green:238/255.f blue:70/255.f alpha:1.f];
    
    set.axisDependency = AxisDependencyLeft;
    
    [d addDataSet:set];
    
    return d;
}

- (BarChartData *)generateBarData
{
    NSMutableArray<BarChartDataEntry *> *entries1 = [[NSMutableArray alloc] init];
    NSMutableArray<BarChartDataEntry *> *entries2 = [[NSMutableArray alloc] init];
    
    for (int index = 0; index < ITEM_COUNT; index++)
    {
        [entries1 addObject:[[BarChartDataEntry alloc] initWithX:0.0 y:(arc4random_uniform(25) + 25)]];
        
        // stacked
        [entries2 addObject:[[BarChartDataEntry alloc] initWithX:0.0 yValues:@[@(arc4random_uniform(13) + 12), @(arc4random_uniform(13) + 12)]]];
    }

    BarChartDataSet *set1 = [[BarChartDataSet alloc] initWithEntries:entries1 label:@"Bar 1"];
    [set1 setColor:[UIColor colorWithRed:60/255.f green:220/255.f blue:78/255.f alpha:1.f]];
    set1.valueTextColor = [UIColor colorWithRed:60/255.f green:220/255.f blue:78/255.f alpha:1.f];
    set1.valueFont = [UIFont systemFontOfSize:10.f];
    set1.axisDependency = AxisDependencyRight;
    
    BarChartDataSet *set2 = [[BarChartDataSet alloc] initWithEntries:entries2 label:@""];
    set2.stackLabels = @[@"Stack 1", @"Stack 2"];
    set2.colors = @[
                    [UIColor colorWithRed:61/255.f green:165/255.f blue:255/255.f alpha:1.f],
                    [UIColor colorWithRed:23/255.f green:197/255.f blue:255/255.f alpha:1.f]
                    ];
    set2.valueTextColor = [UIColor colorWithRed:61/255.f green:165/255.f blue:255/255.f alpha:1.f];
    set2.valueFont = [UIFont systemFontOfSize:10.f];
    set2.axisDependency = AxisDependencyRight;

    float groupSpace = 0.06f;
    float barSpace = 0.02f; // x2 dataset
    float barWidth = 0.45f; // x2 dataset
    // (0.45 + 0.02) * 2 + 0.06 = 1.00 -> interval per "group"
    
    BarChartData *d = [[BarChartData alloc] initWithDataSets:@[set1, set2]];
    d.barWidth = barWidth;
    
    // make this BarData object grouped
    [d groupBarsFromX:0.0 groupSpace:groupSpace barSpace:barSpace]; // start at x = 0
    
    return d;
}

- (ScatterChartData *)generateScatterData
{
    ScatterChartData *d = [[ScatterChartData alloc] init];
    
    NSMutableArray *entries = [[NSMutableArray alloc] init];
    
    for (double index = 0; index < ITEM_COUNT; index += 0.5)
    {
        [entries addObject:[[ChartDataEntry alloc] initWithX:index + 0.25 y:(arc4random_uniform(10) + 55)]];
    }
    
    ScatterChartDataSet *set = [[ScatterChartDataSet alloc] initWithEntries:entries label:@"Scatter DataSet"];
    set.colors = ChartColorTemplates.material;
    set.scatterShapeSize = 4.5;
    [set setDrawValuesEnabled:NO];
    set.valueFont = [UIFont systemFontOfSize:10.f];
    
    [d addDataSet:set];
    
    return d;
}

- (CandleChartData *)generateCandleData
{
    CandleChartData *d = [[CandleChartData alloc] init];
    
    NSMutableArray *entries = [[NSMutableArray alloc] init];
    
    for (int index = 0; index < ITEM_COUNT; index += 2)
    {
        [entries addObject:[[CandleChartDataEntry alloc] initWithX:index + 1 shadowH:90.0 shadowL:70.0 open:85.0 close:75.0]];
    }
    
    CandleChartDataSet *set = [[CandleChartDataSet alloc] initWithEntries:entries label:@"Candle DataSet"];
    [set setColor:[UIColor colorWithRed:80/255.f green:80/255.f blue:80/255.f alpha:1.f]];
    set.decreasingColor = [UIColor colorWithRed:142/255.0 green:150/255.0 blue:175/255.0 alpha:1.0];
    set.shadowColor = UIColor.darkGrayColor;
    set.valueFont = [UIFont systemFontOfSize:10.f];
    [set setDrawValuesEnabled:NO];
    
    [d addDataSet:set];
    
    return d;
}

- (BubbleChartData *)generateBubbleData
{
    BubbleChartData *bd = [[BubbleChartData alloc] init];
    
    NSMutableArray *entries = [[NSMutableArray alloc] init];
    
    for (int index = 0; index < ITEM_COUNT; index++)
    {
        double y = arc4random_uniform(10) + 105.0;
        double size = arc4random_uniform(50) + 105.0;
        [entries addObject:[[BubbleChartDataEntry alloc] initWithX:index + 0.5 y:y size:size]];
    }
    
    BubbleChartDataSet *set = [[BubbleChartDataSet alloc] initWithEntries:entries label:@"Bubble DataSet"];
    [set setColors:ChartColorTemplates.vordiplom];
    set.valueTextColor = UIColor.whiteColor;
    set.valueFont = [UIFont systemFontOfSize:10.f];
    [set setDrawValuesEnabled:YES];
    
    [bd addDataSet:set];
    
    return bd;
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
    return months[(int)value % months.count];
}

@end
