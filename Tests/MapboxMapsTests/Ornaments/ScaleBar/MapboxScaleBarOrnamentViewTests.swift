import XCTest
@testable import MapboxMaps

class MapboxScaleBarOrnamentViewTests: MapViewIntegrationTestCase {
    
    func testImperialScaleBar() throws {
        let scaleBar = MockMapboxScaleBarOrnamentView()
        
        let rows = MapboxScaleBarOrnamentView.Constants.imperialTable
        for row in rows {
            // Add 0.01 so that the converted distance is slightly greater than the distance we are comparing.
            scaleBar.metersPerPoint =  scaleBar.metersFromFeet(row.distance + 0.01)
            
            XCTAssertEqual(scaleBar.preferredRow().numberOfBars, row.numberOfBars, "The number of scale bars should be equal when the value for metersPerPoint is \(scaleBar.metersPerPoint). distance \(row.distance / Double(scaleBar.maximumWidth))")

            let visibleBars = scaleBar._bars?.filter { $0.isHidden == false }
            let visibleLabels = scaleBar.labelViews.filter { $0.isHidden == false }
            
            XCTAssertEqual(visibleLabels.count, Int(scaleBar.preferredRow().numberOfBars) + 1)
            }
    }

    func testMetricScaleBar() throws {
        let scaleBar = MockMapboxScaleBarOrnamentView()
        scaleBar._isMetricLocale = false

        let rows = MapboxScaleBarOrnamentView.Constants.metricTable
        for row in rows {
            // Add 0.01 so that the converted distance is slightly greater than the distance we are comparing.
            let distance = (row.distance + 0.01) / Double(scaleBar.maximumWidth)
            scaleBar.metersPerPoint = distance

            XCTAssertEqual(scaleBar.preferredRow().numberOfBars, row.numberOfBars, "The number of scale bars should be equal when the value for metersPerPoint is \(scaleBar.metersPerPoint)")
        }
    }
}

final class MockMapboxScaleBarOrnamentView: MapboxScaleBarOrnamentView {
    override var maximumWidth: CGFloat {
        return 195
    }
    
    internal var _isMetricLocale: Bool = true
    
    override var isMetricLocale: Bool {
        return _isMetricLocale
    }
    
    // Reverses the conversions we do to get the distance in feet for the scale bar.
    func metersFromFeet(_ distance: Double) -> Double {
        let dividedByWidth = distance / Double(maximumWidth)
        let inMeters = dividedByWidth / Constants.feetPerMeter
        return inMeters
    }
}