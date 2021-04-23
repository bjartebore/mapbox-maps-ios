import UIKit

public enum OrnamentPosition: String, Equatable {
    // Clockwise from top left
    case topLeft
    case topRight
    case bottomRight
    case bottomLeft
}

public enum OrnamentVisibility: String, Equatable {
    case adaptive
    case hidden
    case visible
}

internal class OrnamentsManager: NSObject {

    /// The `OrnamentOptions` that is used to set up the required ornaments on the map
    internal var options: OrnamentOptions {
        didSet {
            assert(options.isValid, "More than one ornament in a single position.")
            updateOrnaments()
        }
    }

    private let logoView: LogoView
    private let scalebarView: MapboxScaleBarOrnamentView
    private let compassView: MapboxCompassOrnamentView
    private let attributionButton: MapboxInfoButtonOrnament

    private var constraints = [NSLayoutConstraint]()

    internal init(view: OrnamentSupportableView, options: OrnamentOptions) {
        self.options = options

        // Logo View
        logoView = LogoView(logoSize: .regular)
        logoView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoView)

        // Scalebar View
        scalebarView = MapboxScaleBarOrnamentView()
        scalebarView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scalebarView)

        // Compass View
        compassView = MapboxCompassOrnamentView(visibility: options.compassVisibility)
        compassView.translatesAutoresizingMaskIntoConstraints = false
        compassView.tapAction = { [weak view] in
            view?.compassTapped()
        }
        view.addSubview(compassView)

        // Info Button
        attributionButton = MapboxInfoButtonOrnament()
        attributionButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(attributionButton)

        super.init()

        updateOrnaments()

        // Subscribe to updates for scalebar and compass
        view.subscribeCameraChangeHandler { [scalebarView, compassView] (cameraOptions) in
            if let zoom = cameraOptions.zoom,
               let center = cameraOptions.center {
                scalebarView.metersPerPoint = Projection.getMetersPerPixelAtLatitude(
                    forLatitude: center.latitude,
                    zoom: Double(zoom))
            }

            if let bearing = cameraOptions.bearing {
                compassView.currentBearing = Double(bearing)
            }
        }
    }

    internal func updateOrnaments() {
        // Remove previously-added constraints
        NSLayoutConstraint.deactivate(constraints)
        constraints.removeAll()

        // Update the position for the ornaments
        let logoViewConstraints = constraints(with: logoView, position: options.logoViewPosition, margins: options.logoViewMargins)
        constraints.append(contentsOf: logoViewConstraints)

        let compassViewConstraints = constraints(with: compassView, position: options.compassViewPosition, margins: options.compassViewMargins)
        constraints.append(contentsOf: compassViewConstraints)

        let scaleBarViewConstraints = constraints(with: scalebarView, position: options.scaleBarPosition, margins: options.scaleBarMargins)
        constraints.append(contentsOf: scaleBarViewConstraints)

        let attributionButtonConstraints = constraints(with: attributionButton, position: options.attributionButtonPosition, margins: options.attributionButtonMargins)
        constraints.append(contentsOf: attributionButtonConstraints)

        // Activate new constraints
        NSLayoutConstraint.activate(constraints)

        logoView.isHidden = !options._logoViewIsVisible
        scalebarView.isHidden = options.scaleBarVisibility == .hidden
        compassView.isHidden = options.compassVisibility == .hidden
        attributionButton.isHidden = !options._attributionButtonIsVisible
    }

    func constraints(with view: UIView, position: OrnamentPosition, margins: CGPoint) -> [NSLayoutConstraint] {
        let universalLayoutGuide = layoutGuide(for: view)

        switch position {
        case .topLeft:
            return [
                view.leftAnchor.constraint(equalTo: universalLayoutGuide.leftAnchor,
                                           constant: margins.x),
                view.topAnchor.constraint(equalTo: universalLayoutGuide.topAnchor,
                                          constant: margins.y)
            ]
        case .topRight:
            return  [
                view.rightAnchor.constraint(equalTo: universalLayoutGuide.rightAnchor,
                                            constant: -margins.x),
                view.topAnchor.constraint(equalTo: universalLayoutGuide.topAnchor,
                                          constant: margins.y)
            ]
        case .bottomLeft:
            return [
                view.leftAnchor.constraint(equalTo: universalLayoutGuide.leftAnchor,
                                           constant: margins.x),
                view.bottomAnchor.constraint(equalTo: universalLayoutGuide.bottomAnchor,
                                             constant: -margins.y)
            ]
        case .bottomRight:
            return [
                view.rightAnchor.constraint(equalTo: universalLayoutGuide.rightAnchor,
                                            constant: -margins.x),
                view.bottomAnchor.constraint(equalTo: universalLayoutGuide.bottomAnchor,
                                             constant: -margins.y)
            ]
        }
    }

    func layoutGuide(for view: UIView) -> UILayoutGuide {
        let superview = view.superview!
        if #available(iOS 11.0, *) {
            return superview.safeAreaLayoutGuide
        } else {
            let layoutGuideIdentifier = "mapboxSafeAreaLayoutGuide"
            // If there's already a generated layout guide, return it
            if let layoutGuide = superview.layoutGuides.filter({ $0.identifier == layoutGuideIdentifier }).first {
                return layoutGuide
            } else {
                // If not, then make a new one based off the view's edges.
                let layoutGuide = UILayoutGuide()
                layoutGuide.identifier = layoutGuideIdentifier
                superview.addLayoutGuide(layoutGuide)

                NSLayoutConstraint.activate([
                    layoutGuide.leftAnchor.constraint(equalTo: superview.leftAnchor),
                    layoutGuide.rightAnchor.constraint(equalTo: superview.rightAnchor),
                    layoutGuide.topAnchor.constraint(equalTo: superview.topAnchor),
                    layoutGuide.bottomAnchor.constraint(equalTo: superview.bottomAnchor)
                ])

                return layoutGuide
            }
        }
    }
}