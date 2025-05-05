//
//  LocationManager.swift
//  imjaDNS
//
//  Created by Petros Dhespollari on 05/05/2025.
//

import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        print("[LocationManager] Requesting location authorization...")
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("[LocationManager] Location authorized: \(manager.authorizationStatus.rawValue)")
        case .denied, .restricted:
            print("[LocationManager] Location access denied or restricted.")
        case .notDetermined:
            print("[LocationManager] Location authorization not determined, requesting...")
            manager.requestWhenInUseAuthorization()
        @unknown default:
            print("[LocationManager] Unknown authorization status: \(manager.authorizationStatus.rawValue)")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            print("[LocationManager] Updated location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        } else {
            print("[LocationManager] Received location update but no locations available.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[LocationManager] Failed to update location: \(error.localizedDescription)")
    }
}
