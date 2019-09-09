//
//  DemoListViewController.swift
//  ChartsDemo-iOS
//
//  Created by Jacob Christie on 2017-07-09.
//  Copyright © 2017 jc. All rights reserved.
//

import UIKit

private struct ItemDef {
    let title: String
    let subtitle: String
    let `class`: AnyClass
}

class DemoListViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    private var itemDefs = [ItemDef(title: "Line Chart",
                            subtitle: "A simple demonstration of the linechart.",
                            class: LineChart1ViewController.self),
                    ItemDef(title: "Line Chart (Dual YAxis)",
                            subtitle: "Demonstration of the linechart with dual y-axis.",
                            class: LineChart2ViewController.self),
                    ItemDef(title: "Bar Chart",
                            subtitle: "A simple demonstration of the bar chart.",
                            class: BarChartViewController.self),
                    ItemDef(title: "Horizontal Bar Chart",
                            subtitle: "A simple demonstration of the horizontal bar chart.",
                            class: HorizontalBarChartViewController.self),
                    ItemDef(title: "Combined Chart",
                            subtitle: "Demonstrates how to create a combined chart (bar and line in this case).",
                            class: CombinedChartViewController.self),
                    ItemDef(title: "Pie Chart",
                            subtitle: "A simple demonstration of the pie chart.",
                            class: PieChartViewController.self),
                    ItemDef(title: "Pie Chart with value lines",
                            subtitle: "A simple demonstration of the pie chart with polyline notes.",
                            class: PiePolylineChartViewController.self),
                    ItemDef(title: "Scatter Chart",
                            subtitle: "A simple demonstration of the scatter chart.",
                            class: ScatterChartViewController.self),
                    ItemDef(title: "Bubble Chart",
                            subtitle: "A simple demonstration of the bubble chart.",
                            class: BubbleChartViewController.self),
                    ItemDef(title: "Stacked Bar Chart",
                            subtitle: "A simple demonstration of a bar chart with stacked bars.",
                            class: StackedBarChartViewController.self),
                    ItemDef(title: "Stacked Bar Chart Negative",
                            subtitle: "A simple demonstration of stacked bars with negative and positive values.",
                            class: NegativeStackedBarChartViewController.self),
                    ItemDef(title: "Another Bar Chart",
                            subtitle: "Implementation of a BarChart that only shows values at the bottom.",
                            class: AnotherBarChartViewController.self),
                    ItemDef(title: "Multiple Lines Chart",
                            subtitle: "A line chart with multiple DataSet objects. One color per DataSet.",
                            class: MultipleLinesChartViewController.self),
                    ItemDef(title: "Multiple Bars Chart",
                            subtitle: "A bar chart with multiple DataSet objects. One multiple colors per DataSet.",
                            class: MultipleBarChartViewController.self),
                    ItemDef(title: "Candle Stick Chart",
                            subtitle: "Demonstrates usage of the CandleStickChart.",
                            class: CandleStickChartViewController.self),
                    ItemDef(title: "Cubic Line Chart",
                            subtitle: "Demonstrates cubic lines in a LineChart.",
                            class: CubicLineChartViewController.self),
                    ItemDef(title: "Radar Chart",
                            subtitle: "Demonstrates the use of a spider-web like (net) chart.",
                            class: RadarChartViewController.self),
                    ItemDef(title: "Colored Line Chart",
                            subtitle: "Shows a LineChart with different background and line color.",
                            class: ColoredLineChartViewController.self),
                    ItemDef(title: "Sinus Bar Chart",
                            subtitle: "A Bar Chart plotting the sinus function with 8.000 values.",
                            class: SinusBarChartViewController.self),
                    ItemDef(title: "BarChart positive / negative",
                            subtitle: "This demonstrates how to create a BarChart with positive and negative values in different colors.",
                            class: PositiveNegativeBarChartViewController.self),
                    ItemDef(title: "Time Line Chart",
                            subtitle: "Simple demonstration of a time-chart. This chart draws one line entry per hour originating from the current time in milliseconds.",
                            class: LineChartTimeViewController.self),
                    ItemDef(title: "Filled Line Chart",
                            subtitle: "This demonstrates how to fill an area between two LineDataSets.",
                            class: LineChartFilledViewController.self),
                    ItemDef(title: "Half Pie Chart",
                            subtitle: "This demonstrates how to create a 180 degree PieChart.",
                            class: HalfPieChartViewController.self)
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Charts Demonstration"
        self.tableView.rowHeight = 70
        //FIXME: Add TimeLineChart
        
    }
}

extension DemoListViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.itemDefs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let def = self.itemDefs[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
        cell.textLabel?.text = def.title
        cell.detailTextLabel?.text = def.subtitle
        cell.detailTextLabel?.numberOfLines = 0
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let def = self.itemDefs[indexPath.row]
        
        let vcClass = def.class as! UIViewController.Type
        let vc = vcClass.init()
        
        self.navigationController?.pushViewController(vc, animated: true)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
