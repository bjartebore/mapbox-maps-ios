import UIKit
import MapboxMaps

@objc(ThirdPartyExample)
public class ThirdPartyExample: UIViewController, ExampleProtocol {

    internal var mapView: MapView!
    internal let sourceIdentifier = "route-source-identifier"
    internal var routeLineSource: GeoJSONSource!
    var currentIndex = 0

    public var geoJSONLine = (identifier: "routeLine", source: GeoJSONSource())

    override public func viewDidLoad() {
        super.viewDidLoad()

        let centerCoordinate = CLLocationCoordinate2D(latitude: 41.878781, longitude: -87.622088)
        let options = MapInitOptions(
            cameraOptions: CameraOptions(center: centerCoordinate, zoom: 12.0),
            styleURI: StyleURI(rawValue: "mapbox://styles/mapbox/light-v10")
        )

        mapView = MapView(frame: view.bounds, mapInitOptions: options)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapView)

        // Wait for the map to load its style before adding data.
        mapView.mapboxMap.onNext(.mapLoaded) { [self] _ in
            
            var source = VectorSource()
            source.tiles = [
                "https://tiles.mapillary.com/maps/vtp/mly1_public/2/{z}/{x}/{y}?access_token=MLY%7C4142433049200173%7C72206abe5035850d6743b23a49c41333"
            ]
            source.minzoom = 6
            source.maxzoom = 14
            
            
            var layer = LineLayer(id: "mapillary")
            layer.source = "mapillary"
            layer.sourceLayer = "sequence"
            layer.lineCap = .constant(LineCap.round)
            layer.lineJoin = .constant(LineJoin.round)
            layer.lineOpacity = .constant(0.6)
            layer.lineColor = .constant(StyleColor.init(UIColor.green))
            layer.lineWidth = .constant(2)
            

            if let style = self.mapView.mapboxMap.style as? Style {
                try? style.addSource(source, id: "mapillary")
                try? style.addLayer(layer, layerPosition: .below("road-label"))
                
            }

            // The below line is used for internal testing purposes only.
            self.finish()
        }
    }

    
}
